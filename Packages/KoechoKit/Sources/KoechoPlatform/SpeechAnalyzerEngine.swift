@preconcurrency import AVFoundation
import KoechoCore
import Speech
import os

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
  private(set) var startTask: Task<Void, Never>?
  private var owner: UUID?
  private let dependencies: Dependencies
  private var resultTask: Task<Void, Never>?
  private var transcriber: DictationTranscriber?
  private var audioInputAcquisitionID: UUID?
  private var analyzerFormat: AVAudioFormat?
  private var isRestarting = false
  private var hasAudioTap = false

  // Keep the OS suspension points injectable without replacing the engine lifecycle.
  struct Dependencies {
    var permissionAction: @MainActor () -> MicrophonePermissionRule.Action = {
      MicrophonePermissionRule.action(for: AVCaptureDevice.authorizationStatus(for: .audio))
    }
    var requestAccess: @MainActor () async -> Bool = { await AVCaptureDevice.requestAccess(for: .audio) }
    var installationRequest: @MainActor (DictationTranscriber) async throws -> (() async throws -> Void)? = {
      transcriber in
      guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
      else { return nil }
      return { try await request.downloadAndInstall() }
    }
    var audioInput: @MainActor (AVAudioEngine, String?) throws -> AudioInputConfiguration = configureAudioInput
    var bestFormat: @MainActor (DictationTranscriber, AVAudioFormat) async -> AVAudioFormat? = {
      await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [$0], considering: $1)
    }
  }

  struct AudioInputConfiguration {
    let format: AVAudioFormat
    let notice: VoiceInputEngineNotice?
  }

  private struct RecognitionSession {
    let transcriber: DictationTranscriber
    let analyzerFormat: AVAudioFormat
    let inputContinuation: AsyncStream<AnalyzerInput>.Continuation
    let analyzer: SpeechAnalyzer
  }

  private enum RecognitionSessionFormat {
    case determine(from: AVAudioFormat)
    case reuse(AVAudioFormat)
  }

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
    audioInputExclusiveAccess: AudioInputExclusiveAccess,
    dependencies: Dependencies = Dependencies()
  ) {
    self.dependencies = dependencies
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
    let owner = UUID()
    self.owner = owner
    state = .listening
    delegate?.voiceInput(didUpdateNotice: nil)
    logger.info("Starting SpeechAnalyzer with locale: \(self.locale.identifier, privacy: .public)")

    startTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.startRecognition(owner: owner)
      if self.owner == owner { self.startTask = nil }
    }
  }

  public func stop() async {
    guard state != .idle, state != .stopping else { return }
    guard let owner else {
      state = .idle
      return
    }
    state = .stopping
    // Preparation has no audio to finalize. Do not wait for non-cooperative OS calls.
    startTask?.cancel()
    if analyzer == nil {
      tearDown()
      state = .idle
      delegate?.voiceInput(didUpdateStatus: nil)
      return
    }
    logger.debug("Stopping SpeechAnalyzer")

    if let audioEngine {
      removeAudioTap(from: audioEngine)
      audioEngine.stop()
    }
    inputContinuation?.finish()

    if let analyzer {
      let finalizeTask = Task {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
      }
      switch await TaskTimeout.wait(finalizeTask, seconds: 1) {
      case .completed(.success):
        logger.info("finalizeAndFinishThroughEndOfInput succeeded")
      case .completed(.failure(let error)) where error is CancellationError:
        logger.info("finalizeAndFinishThroughEndOfInput cancelled")
      case .completed(.failure(let error)):
        let nsError = error as NSError
        logger.error(
          "finalizeAndFinishThroughEndOfInput failed: domain=\(nsError.domain, privacy: .public) code=\(nsError.code) error=\(String(describing: error))"
        )
      case .timedOut:
        logger.warning("finalizeAndFinishThroughEndOfInput timed out")
        finalizeTask.cancel()
      }
    }

    guard self.owner == owner else { return }

    if let resultTask {
      if case .timedOut = await TaskTimeout.wait(resultTask, seconds: 1) {
        logger.warning("Result task timed out during stop, cancelling")
        resultTask.cancel()
      }
    }

    guard self.owner == owner else { return }
    tearDown()
    state = .idle
    delegate?.voiceInput(didUpdateStatus: nil)
    logger.info("SpeechAnalyzer stopped")
  }

  public func cancel() {
    logger.debug("Cancelling SpeechAnalyzer")
    startTask?.cancel()
    inputContinuation?.finish()
    resultTask?.cancel()
    if let audioEngine {
      removeAudioTap(from: audioEngine)
      audioEngine.stop()
    }
    tearDown()
    state = .idle
    delegate?.voiceInput(didUpdateStatus: nil)
  }

  // MARK: - Private

  private static func configureAudioInput(
    _ audioEngine: AVAudioEngine, _ deviceUID: String?
  ) throws -> AudioInputConfiguration {
    var notice: VoiceInputEngineNotice?
    let logger = Logger(subsystem: Logger.koechoSubsystem, category: "SpeechAnalyzerEngine")
    if let deviceUID {
      let resolvedID = AudioDeviceListing.resolveDeviceID(forUID: deviceUID)
      audioEngine.inputNode.withAudioUnit { audioUnit in
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
            notice = .microphoneFallback
            logger.warning("Failed to set audio device (status: \(status)), using system default")
          }
        } else {
          notice = .microphoneFallback
          logger.warning(
            "Audio device UID '\(deviceUID, privacy: .public)' not found or audioUnit unavailable, using system default"
          )
        }
      }
    }

    let inputNode = audioEngine.inputNode
    let format = try SpeechAudioCaptureFormat.make(hardware: inputNode.inputFormat(forBus: 0))
    return AudioInputConfiguration(format: format, notice: notice)
  }

  private func canStart(owner: UUID) -> Bool {
    self.owner == owner && state == .listening && !Task.isCancelled
  }

  private func startRecognition(owner: UUID) async {
    guard canStart(owner: owner) else { return }
    switch dependencies.permissionAction() {
    case .requestAccess:
      delegate?.voiceInput(didUpdateStatus: .requestingMicrophoneAccess)
      guard canStart(owner: owner) else { return }
      let granted = await dependencies.requestAccess()
      guard canStart(owner: owner) else { return }
      delegate?.voiceInput(didUpdateStatus: nil)
      guard canStart(owner: owner) else { return }
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

    guard canStart(owner: owner) else { return }

    let preset = Self.defaultPreset
    logger.info(
      "Preset reportingOptions: \(String(describing: preset.reportingOptions), privacy: .public)")
    logger.info(
      "Preset transcriptionOptions: \(String(describing: preset.transcriptionOptions), privacy: .public)"
    )
    let transcriber = makeTranscriber(preset: preset)

    let localeKey = SpeechLocale.normalizationKey(locale)
    let modelError: VoiceInputEngineError?
    do {
      modelError = try await SpeechModelPreparation.ensureModelAvailable(
        localeKey: localeKey,
        isVerified: verificationCache.isVerified(localeKey:),
        markVerified: verificationCache.markVerified(localeKey:),
        installationRequest: { [dependencies] in
          try await dependencies.installationRequest(transcriber)
        },
        updateStatus: { [weak self] status in
          guard let self, self.canStart(owner: owner) else { return }
          self.delegate?.voiceInput(didUpdateStatus: status)
        }
      )
    } catch {
      return // Model preparation only throws cancellation.
    }
    guard canStart(owner: owner) else { return }
    if let modelError {
      reportError(modelError)
      return
    }

    let audioEngine = AVAudioEngine()
    self.audioEngine = audioEngine

    let audioInput: AudioInputConfiguration
    do {
      audioInput = try dependencies.audioInput(audioEngine, deviceUID)
    } catch {
      reportAudioInputError(error)
      return
    }
    let inputFormat = audioInput.format

    guard canStart(owner: owner) else { return }
    guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
      reportError(.noAudioInputDevice)
      return
    }

    delegate?.voiceInput(didUpdateNotice: audioInput.notice)

    let session = await makeRecognitionSession(
      transcriber: transcriber,
      format: .determine(from: inputFormat),
      owner: owner
    )
    guard canStart(owner: owner) else {
      if let session {
        session.inputContinuation.finish()
        await session.analyzer.cancelAndFinishNow()
      }
      return
    }
    guard let session else {
      reportError(.noCompatibleAudioFormat)
      return
    }

    activate(session)

    let acquisitionID = audioInputExclusiveAccess.acquire()
    guard canStart(owner: owner) else {
      audioInputExclusiveAccess.release(acquisitionID)
      return
    }
    audioInputAcquisitionID = acquisitionID

    do {
      try installAudioTap(format: inputFormat)
      guard canStart(owner: owner) else { return }
      try audioEngine.start()
      logger.info("Audio engine started, listening...")
    } catch {
      reportAudioInputError(error)
    }
  }

  private func startResultTask(transcriber: DictationTranscriber, owner: UUID) {
    let resultsTask = Task { @MainActor [weak self] in
      do {
        for try await result in transcriber.results {
          guard let self, self.owner == owner, !Task.isCancelled,
            self.state == .listening || self.state == .stopping else { break }
          let text = String(result.text.characters)
          self.logger.debug("Result: isFinal=\(result.isFinal)")
          if result.isFinal {
            self.delegate?.voiceInput(didFinalize: text)
          } else {
            self.delegate?.voiceInput(didUpdateVolatile: text)
          }
        }
      } catch is CancellationError {
        // Normal during stop/cancel
      } catch {
        guard let self, self.owner == owner, !Task.isCancelled, self.state != .stopping, self.state != .idle else { return }
        self.reportError(.recognitionError(description: error.localizedDescription))
      }
    }
    self.resultTask = resultsTask
  }

  private func makeRecognitionSession(
    transcriber: DictationTranscriber,
    format: RecognitionSessionFormat,
    owner: UUID
  ) async -> RecognitionSession? {
    let analyzerFormat: AVAudioFormat

    switch format {
    case let .determine(inputFormat):
      guard let bestFormat = await dependencies.bestFormat(transcriber, inputFormat) else {
        return nil
      }
      analyzerFormat = bestFormat
    case let .reuse(existingFormat):
      analyzerFormat = existingFormat
    }

    guard canStart(owner: owner) else { return nil }
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    let analyzer = SpeechAnalyzer(inputSequence: stream, modules: [transcriber])
    return RecognitionSession(
      transcriber: transcriber,
      analyzerFormat: analyzerFormat,
      inputContinuation: continuation,
      analyzer: analyzer
    )
  }

  private func activate(_ session: RecognitionSession) {
    transcriber = session.transcriber
    analyzerFormat = session.analyzerFormat
    inputContinuation = session.inputContinuation
    analyzer = session.analyzer
    if let owner { startResultTask(transcriber: session.transcriber, owner: owner) }
  }

  private func makeTranscriber(
    preset: DictationTranscriber.Preset
  ) -> DictationTranscriber {
    DictationTranscriber(locale: locale, preset: preset)
  }

  private func removeAudioTap(from audioEngine: AVAudioEngine) {
    guard hasAudioTap else { return }
    audioEngine.inputNode.removeTap(onBus: 0)
    hasAudioTap = false
  }

  private func installAudioTap(format inputFormat: AVAudioFormat) throws {
    guard let audioEngine, let analyzerFormat,
      let localContinuation = inputContinuation
    else { return }
    let converter = try SpeechAudioConverter(input: inputFormat, output: analyzerFormat)
    let inputNode = audioEngine.inputNode
    // A nonnil tap format applies the client format through the engine's node API.
    try inputNode.installAudioTap(
      onBus: 0, bufferSize: 4096, format: inputFormat
    ) { @Sendable buffer, _ in
      // The converter and continuation belong to this tap, never another session.
      let copiedBuffer = AVAudioPCMBuffer(copying: buffer)
      guard let input = converter.convert(copiedBuffer) else { return }
      localContinuation.yield(AnalyzerInput(buffer: input))
    }
    hasAudioTap = true
    guard inputNode.outputFormat(forBus: 0) == inputFormat else {
      throw VoiceInputEngineError.audioFormatConversionNotSupported
    }
  }

  /// Restart the transcriber to clear segment buffer.
  /// Returns `true` if restart was actually performed.
  @discardableResult
  public func restartTranscriber() async -> Bool {
    guard state == .listening, !isRestarting, let audioEngine, let owner else { return false }
    isRestarting = true
    defer { if self.owner == owner { isRestarting = false } }
    logger.info("Restarting transcriber to clear segment buffer")

    removeAudioTap(from: audioEngine)
    audioEngine.stop()
    inputContinuation?.finish()
    let oldResultTask = resultTask
    if let analyzer {
      await analyzer.cancelAndFinishNow()
    }
    oldResultTask?.cancel()
    if let oldResultTask {
      if case .timedOut = await TaskTimeout.wait(oldResultTask, seconds: 1) {
        logger.warning("Result task timed out during restart, cancelling")
        oldResultTask.cancel()
      }
    }

    // Stop or cancel may have run during the preceding await.
    guard canStart(owner: owner) else { return false }

    // Reuse the original analyzer format across restarts.
    guard let analyzerFormat else { return false }
    guard let session = await makeRecognitionSession(
      transcriber: makeTranscriber(preset: Self.defaultPreset),
      format: .reuse(analyzerFormat),
      owner: owner
    ) else {
      return false
    }
    guard canStart(owner: owner) else {
      session.inputContinuation.finish()
      await session.analyzer.cancelAndFinishNow()
      return false
    }
    activate(session)

    do {
      let audioInput = try dependencies.audioInput(audioEngine, deviceUID)
      delegate?.voiceInput(didUpdateNotice: audioInput.notice)
      guard canStart(owner: owner) else { return false }
      try installAudioTap(format: audioInput.format)
      guard canStart(owner: owner) else { return false }
      try audioEngine.start()
    } catch {
      resultTask?.cancel()
      reportAudioInputError(error)
      return false
    }

    logger.info("Transcriber restarted")
    return true
  }

  private func reportAudioInputError(_ error: Error) {
    reportError(
      (error as? VoiceInputEngineError)
        ?? .audioEngineStartFailed(description: error.localizedDescription))
  }

  private func reportError(_ error: VoiceInputEngineError) {
    let description = String(describing: error)
    logger.error("\(description, privacy: .public)")
    tearDown()
    state = .error(description)
    delegate?.voiceInput(didUpdateNotice: nil)
    delegate?.voiceInput(didEncounterError: error)
  }

  private func tearDown() {
    owner = nil
    startTask?.cancel()
    startTask = nil
    resultTask?.cancel()
    inputContinuation?.finish()
    if let analyzer {
      Task { await analyzer.cancelAndFinishNow() }
    }
    isRestarting = false
    if let audioEngine {
      removeAudioTap(from: audioEngine)
      audioEngine.stop()
    }
    audioEngine = nil
    analyzer = nil
    transcriber = nil
    inputContinuation = nil
    resultTask = nil
    analyzerFormat = nil
    if let acquisitionID = audioInputAcquisitionID {
      audioInputAcquisitionID = nil
      audioInputExclusiveAccess.release(acquisitionID)
    }
  }
}
