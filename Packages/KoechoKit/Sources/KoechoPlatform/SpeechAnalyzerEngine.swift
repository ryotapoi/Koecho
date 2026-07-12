@preconcurrency import AVFoundation
import KoechoCore
import Speech
import os

@available(macOS 26, *)
@MainActor
public final class SpeechAnalyzerEngine: VoiceInputEngine, TranscriberRestartable {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "SpeechAnalyzerEngine")
  private let locale: Locale
  private let deviceUID: String?
  private let verificationCache: SpeechModelVerificationCache
  private let audioInputExclusiveAccess: AudioInputExclusiveAccess
  public private(set) var state: VoiceInputState = .idle
  public weak var delegate: (any VoiceInputDelegate)?

  private var analyzer: SpeechAnalyzer?
  private var audioEngine: AVAudioEngine?
  private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
  private var resultTask: Task<Void, Never>?
  private var transcriber: DictationTranscriber?
  private var acquiredAudioInput = false
  private var converter: AVAudioConverter?
  private var analyzerFormat: AVAudioFormat?
  private var isRestarting = false

  /// Shared preset used for both recognition and model download.
  public static var defaultPreset: DictationTranscriber.Preset {
    var preset = DictationTranscriber.Preset.progressiveLongDictation
    preset.transcriptionOptions.insert(.punctuation)
    preset.reportingOptions.insert(.frequentFinalization)
    return preset
  }

  public convenience init(locale: Locale = .current, deviceUID: String? = nil) {
    self.init(
      locale: locale,
      deviceUID: deviceUID,
      verificationCache: .shared,
      audioInputExclusiveAccess: .shared
    )
  }

  init(
    locale: Locale,
    deviceUID: String?,
    verificationCache: SpeechModelVerificationCache,
    audioInputExclusiveAccess: AudioInputExclusiveAccess
  ) {
    self.locale = locale
    self.deviceUID = deviceUID
    self.verificationCache = verificationCache
    self.audioInputExclusiveAccess = audioInputExclusiveAccess
  }

  public func start() {
    switch state {
    case .listening, .stopping: return
    case .idle, .error: break
    }
    state = .listening
    logger.info("Starting SpeechAnalyzer with locale: \(self.locale.identifier, privacy: .public)")

    resultTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.startRecognition()
    }
  }

  public func stop() async {
    guard state != .idle, state != .stopping else { return }
    state = .stopping
    logger.debug("Stopping SpeechAnalyzer")

    // Stop audio input
    if let audioEngine {
      audioEngine.inputNode.removeTap(onBus: 0)
      audioEngine.stop()
    }
    inputContinuation?.finish()

    // Ask analyzer to finalize remaining audio, with timeout
    if let analyzer {
      let finalizeTask = Task {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
      }
      if await TaskTimeout.hasTimedOut(finalizeTask, seconds: 1) {
        logger.warning("finalizeAndFinishThroughEndOfInput timed out")
        finalizeTask.cancel()
      }
    }

    // Wait for result task with timeout
    if let resultTask {
      if await TaskTimeout.hasTimedOut(resultTask, seconds: 1) {
        logger.warning("Result task timed out during stop, cancelling")
        resultTask.cancel()
      }
    }

    tearDown()
    state = .idle
    logger.info("SpeechAnalyzer stopped")
  }

  public func cancel() {
    logger.debug("Cancelling SpeechAnalyzer")
    inputContinuation?.finish()
    resultTask?.cancel()
    if let audioEngine {
      audioEngine.inputNode.removeTap(onBus: 0)
      audioEngine.stop()
    }
    if let analyzer {
      Task { [analyzer] in
        await analyzer.cancelAndFinishNow()
      }
    }
    tearDown()
    state = .idle
  }

  // MARK: - Private

  private func startRecognition() async {
    // 1. Check microphone permission
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    switch MicrophonePermissionRule.action(for: status) {
    case .requestAccess:
      delegate?.voiceInput(didUpdateStatus: .requestingMicrophoneAccess)
      let granted = await AVCaptureDevice.requestAccess(for: .audio)
      delegate?.voiceInput(didUpdateStatus: nil)
      if !granted {
        reportError(.microphoneAccessDenied)
        return
      }
    case .deny:
      reportError(.microphoneAccessDenied)
      return
    case .proceed:
      break
    }

    // 2. Create transcriber
    let preset = Self.defaultPreset
    logger.info(
      "Preset reportingOptions: \(String(describing: preset.reportingOptions), privacy: .public)")
    logger.info(
      "Preset transcriptionOptions: \(String(describing: preset.transcriptionOptions), privacy: .public)"
    )
    let transcriber = DictationTranscriber(locale: locale, preset: preset)
    self.transcriber = transcriber

    // 3. Check / download model (skip if already verified this session)
    let localeKey = SpeechLocale.normalizationKey(locale)
    let modelError = await SpeechModelPreparation.ensureModelAvailable(
      localeKey: localeKey,
      isVerified: verificationCache.isVerified(localeKey:),
      markVerified: verificationCache.markVerified(localeKey:),
      installationRequest: { [transcriber, logger] in
        if let request = try await AssetInventory.assetInstallationRequest(
          supporting: [transcriber]
        ) {
          logger.info("Downloading speech model...")
          return {
            try await request.downloadAndInstall()
            logger.info("Speech model downloaded")
          }
        }
        return nil
      },
      updateStatus: { [delegate] status in
        delegate?.voiceInput(didUpdateStatus: status)
      }
    )
    if let modelError {
      reportError(modelError)
      return
    }

    // 4. Setup audio engine
    let audioEngine = AVAudioEngine()
    self.audioEngine = audioEngine

    if let deviceUID {
      let resolvedID = AudioDeviceListing.resolveDeviceID(forUID: deviceUID)
      let audioUnit = audioEngine.inputNode.audioUnit
      if let deviceID = AudioDeviceSelection.engineDeviceID(
        requestedUID: deviceUID,
        resolvedID: resolvedID,
        hasAudioUnit: audioUnit != nil
      ), let audioUnit {
        var id = deviceID
        let status = AudioUnitSetProperty(
          audioUnit,
          kAudioOutputUnitProperty_CurrentDevice,
          kAudioUnitScope_Global, 0,
          &id, UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
          logger.warning("Failed to set audio device (status: \(status)), using system default")
        }
      } else {
        logger.warning(
          "Audio device UID '\(deviceUID, privacy: .public)' not found or audioUnit unavailable, using system default"
        )
      }
    }

    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    guard inputFormat.channelCount > 0 else {
      reportError(.noAudioInputDevice)
      return
    }

    // 5. Get best format for analyzer
    guard
      let bestFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
        compatibleWith: [transcriber],
        considering: inputFormat
      )
    else {
      reportError(.noCompatibleAudioFormat)
      return
    }
    self.analyzerFormat = bestFormat

    // 6. Create format converter if needed
    let needsConversion = inputFormat != bestFormat
    if needsConversion {
      guard let conv = AVAudioConverter(from: inputFormat, to: bestFormat) else {
        reportError(.audioFormatConversionNotSupported)
        return
      }
      self.converter = conv
    } else {
      self.converter = nil
    }

    // 7. Create async stream for audio input
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    self.inputContinuation = continuation

    // 8. Create SpeechAnalyzer with input sequence
    let analyzer = SpeechAnalyzer(
      inputSequence: stream,
      modules: [transcriber]
    )
    self.analyzer = analyzer

    // 9. Start consuming results
    startResultTask(transcriber: transcriber)

    // 10. Install audio tap and start
    audioInputExclusiveAccess.acquire()
    acquiredAudioInput = true

    installAudioTap()

    do {
      try audioEngine.start()
      logger.info("Audio engine started, listening...")
    } catch {
      reportError(.audioEngineStartFailed(description: error.localizedDescription))
      tearDown()
    }
  }

  private func startResultTask(transcriber: DictationTranscriber) {
    let resultsTask = Task { @MainActor [weak self] in
      do {
        for try await result in transcriber.results {
          guard let self, self.state == .listening || self.state == .stopping else { break }
          let text = String(result.text.characters)
          self.logger.debug("Result: isFinal=\(result.isFinal) text=\"\(text, privacy: .public)\"")
          if result.isFinal {
            self.delegate?.voiceInput(didFinalize: text)
          } else {
            self.delegate?.voiceInput(didUpdateVolatile: text)
          }
        }
      } catch is CancellationError {
        // Normal during stop/cancel
      } catch {
        guard let self, self.state != .stopping, self.state != .idle else { return }
        self.reportError(.recognitionError(description: error.localizedDescription))
      }
    }
    self.resultTask = resultsTask
  }

  private func installAudioTap() {
    guard let audioEngine, let analyzerFormat,
      let localContinuation = inputContinuation
    else { return }
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    // Recreate converter if input format changed (e.g. during restart)
    let needsConversion = inputFormat != analyzerFormat
    if needsConversion {
      if converter == nil || converter?.inputFormat != inputFormat {
        guard let conv = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
          reportError(.audioFormatConversionNotSupported)
          return
        }
        converter = conv
      }
    } else {
      converter = nil
    }

    let localConverter = converter
    let localAnalyzerFormat = analyzerFormat
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { @Sendable buffer, _ in
      // This runs on the audio thread — do not access self
      let inputBuffer: AVAudioPCMBuffer
      if let localConverter {
        let frameCapacity = AVAudioFrameCount(
          Double(buffer.frameLength) * localAnalyzerFormat.sampleRate / inputFormat.sampleRate
        )
        guard
          let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: localAnalyzerFormat,
            frameCapacity: frameCapacity
          )
        else { return }
        var error: NSError?
        localConverter.convert(to: convertedBuffer, error: &error) { _, outStatus in
          outStatus.pointee = .haveData
          return buffer
        }
        if error != nil { return }
        inputBuffer = convertedBuffer
      } else {
        inputBuffer = buffer
      }
      localContinuation.yield(AnalyzerInput(buffer: inputBuffer))
    }
  }

  /// Restart the transcriber to clear segment buffer.
  /// Returns `true` if restart was actually performed.
  @discardableResult
  public func restartTranscriber() async -> Bool {
    guard state == .listening, !isRestarting, let audioEngine else { return false }
    isRestarting = true
    defer { isRestarting = false }
    logger.info("Restarting transcriber to clear segment buffer")

    // 1. Stop old: remove tap, stop audio engine, finish stream, cancel analyzer
    audioEngine.inputNode.removeTap(onBus: 0)
    audioEngine.stop()
    inputContinuation?.finish()
    if let analyzer {
      await analyzer.cancelAndFinishNow()
    }
    let oldResultTask = resultTask
    oldResultTask?.cancel()
    if let oldResultTask {
      if await TaskTimeout.hasTimedOut(oldResultTask, seconds: 1) {
        logger.warning("Result task timed out during restart, cancelling")
        oldResultTask.cancel()
      }
    }

    // 2. Re-check state (stop/cancel may have run during await)
    guard state == .listening else { return false }

    // 3. Create new transcriber/stream/analyzer
    let preset = Self.defaultPreset
    let newTranscriber = DictationTranscriber(locale: locale, preset: preset)
    self.transcriber = newTranscriber
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    self.inputContinuation = continuation
    self.analyzer = SpeechAnalyzer(inputSequence: stream, modules: [newTranscriber])
    startResultTask(transcriber: newTranscriber)

    // 4. Re-install audio tap and restart audio engine
    installAudioTap()
    guard state == .listening else { return false }

    do {
      try audioEngine.start()
    } catch {
      resultTask?.cancel()
      reportError(.audioEngineStartFailed(description: error.localizedDescription))
      return false
    }

    logger.info("Transcriber restarted")
    return true
  }

  private func reportError(_ error: VoiceInputEngineError) {
    let description = String(describing: error)
    logger.error("\(description, privacy: .public)")
    tearDown()
    state = .error(description)
    delegate?.voiceInput(didEncounterError: error)
  }

  private func tearDown() {
    if let audioEngine {
      audioEngine.inputNode.removeTap(onBus: 0)
      audioEngine.stop()
    }
    audioEngine = nil
    analyzer = nil
    transcriber = nil
    inputContinuation = nil
    resultTask = nil
    converter = nil
    analyzerFormat = nil
    if acquiredAudioInput {
      audioInputExclusiveAccess.release()
      acquiredAudioInput = false
    }
  }
}
