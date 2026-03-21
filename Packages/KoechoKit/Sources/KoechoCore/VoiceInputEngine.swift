import Foundation

public enum VoiceInputState: Equatable, Sendable {
    case idle
    case listening
    case stopping
    case error(String)
}

public enum VoiceInputEngineStatus: Sendable, Equatable {
    case requestingMicrophoneAccess
    case downloadingModel
}

public enum VoiceInputEngineError: Error, Sendable, Equatable {
    case microphoneAccessDenied
    case modelDownloadFailed(description: String)
    case noAudioInputDevice
    case noCompatibleAudioFormat
    case audioFormatConversionNotSupported
    case audioEngineStartFailed(description: String)
    case recognitionError(description: String)
}

@MainActor
public protocol VoiceInputEngine: AnyObject {
    var state: VoiceInputState { get }
    var delegate: (any VoiceInputDelegate)? { get set }
    func start()
    func stop() async
    func cancel()
}

@MainActor
public protocol VoiceInputDelegate: AnyObject {
    func voiceInput(didFinalize text: String)
    func voiceInput(didUpdateVolatile text: String)
    func voiceInput(didEncounterError error: VoiceInputEngineError)
    func voiceInput(didUpdateStatus status: VoiceInputEngineStatus?)
}
