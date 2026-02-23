import AVFoundation
import os
import Speech

@available(macOS 26, *)
@MainActor
final class SpeechAnalyzerEngine: VoiceInputEngine {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "SpeechAnalyzerEngine")
    private let locale: Locale
    private(set) var state: VoiceInputState = .idle
    weak var delegate: (any VoiceInputDelegate)?

    private var analyzer: SpeechAnalyzer?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var transcriber: DictationTranscriber?

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func start() {
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

    func stop() async {
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
            let timedOut = await withTaskGroup(of: Bool.self) { group in
                group.addTask { try? await finalizeTask.value; return false }
                group.addTask { try? await Task.sleep(for: .seconds(1)); return true }
                let first = await group.next()!
                group.cancelAll()
                return first
            }
            if timedOut {
                logger.warning("finalizeAndFinishThroughEndOfInput timed out")
                finalizeTask.cancel()
            }
        }

        // Wait for result task with timeout
        if let resultTask {
            let timedOut = await withTaskGroup(of: Bool.self) { group in
                group.addTask { await resultTask.value; return false }
                group.addTask { try? await Task.sleep(for: .seconds(1)); return true }
                let first = await group.next()!
                group.cancelAll()
                return first
            }
            if timedOut {
                logger.warning("Result task timed out during stop, cancelling")
                resultTask.cancel()
            }
        }

        tearDown()
        state = .idle
        logger.info("SpeechAnalyzer stopped")
    }

    func cancel() {
        logger.debug("Cancelling SpeechAnalyzer")
        inputContinuation?.finish()
        resultTask?.cancel()
        if let audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        if let analyzer {
            let logger = self.logger
            Task { [analyzer] in
                do {
                    try await analyzer.cancelAndFinishNow()
                } catch {
                    logger.warning("cancelAndFinishNow error: \(error)")
                }
            }
        }
        tearDown()
        state = .idle
    }

    // MARK: - Private

    private func startRecognition() async {
        // 1. Check microphone permission
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .notDetermined:
            delegate?.voiceInput(didUpdateStatus: "Requesting microphone access...")
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            delegate?.voiceInput(didUpdateStatus: nil)
            if !granted {
                reportError("Microphone access denied. Open System Settings > Privacy & Security > Microphone.")
                return
            }
        case .denied, .restricted:
            reportError("Microphone access denied. Open System Settings > Privacy & Security > Microphone.")
            return
        case .authorized:
            break
        @unknown default:
            break
        }

        // 2. Create transcriber
        // Use progressiveLongDictation as base (volatile results + long session)
        // and add punctuation for automatic 。、etc.
        var preset = DictationTranscriber.Preset.progressiveLongDictation
        preset.transcriptionOptions.insert(.punctuation)
        preset.reportingOptions.insert(.frequentFinalization)
        logger.info("Preset reportingOptions: \(String(describing: preset.reportingOptions), privacy: .public)")
        logger.info("Preset transcriptionOptions: \(String(describing: preset.transcriptionOptions), privacy: .public)")
        let transcriber = DictationTranscriber(locale: locale, preset: preset)
        self.transcriber = transcriber

        // 3. Check / download model
        do {
            if let request = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) {
                logger.info("Downloading speech model...")
                delegate?.voiceInput(didUpdateStatus: "Downloading speech model...")
                try await request.downloadAndInstall()
                logger.info("Speech model downloaded")
                delegate?.voiceInput(didUpdateStatus: nil)
            }
        } catch {
            delegate?.voiceInput(didUpdateStatus: nil)
            reportError("Failed to download speech model: \(error.localizedDescription)")
            return
        }

        // 4. Setup audio engine
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.channelCount > 0 else {
            reportError("No audio input device available.")
            return
        }

        // 5. Get best format for analyzer
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber],
            considering: inputFormat
        ) else {
            reportError("No compatible audio format available.")
            return
        }

        // 6. Create format converter if needed
        let needsConversion = inputFormat != analyzerFormat
        var converter: AVAudioConverter?
        if needsConversion {
            guard let conv = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
                reportError("Audio format conversion not supported.")
                return
            }
            converter = conv
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
        let resultsTask = Task { [weak self] in
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
                self.delegate?.voiceInput(didEncounterError: "Speech recognition error: \(error.localizedDescription)")
            }
        }
        self.resultTask = resultsTask

        // 10. Install audio tap and start
        // Capture continuation and converter as local variables to avoid
        // accessing @MainActor self from audio thread.
        let localContinuation = continuation
        let localConverter = converter
        let localAnalyzerFormat = analyzerFormat

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            // This runs on the audio thread — do not access self
            let inputBuffer: AVAudioPCMBuffer
            if let localConverter {
                let frameCapacity = AVAudioFrameCount(
                    Double(buffer.frameLength) * localAnalyzerFormat.sampleRate / inputFormat.sampleRate
                )
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: localAnalyzerFormat,
                    frameCapacity: frameCapacity
                ) else { return }
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

        do {
            try audioEngine.start()
            logger.info("Audio engine started, listening...")
        } catch {
            reportError("Failed to start audio engine: \(error.localizedDescription)")
            tearDown()
        }
    }

    private func reportError(_ message: String) {
        logger.error("\(message, privacy: .public)")
        tearDown()
        state = .error(message)
        delegate?.voiceInput(didEncounterError: message)
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
    }
}
