import Foundation

enum VoiceInputState: Equatable {
    case idle
    case listening
    case stopping
    case error(String)
}

@MainActor
protocol VoiceInputEngine: AnyObject {
    var state: VoiceInputState { get }
    var delegate: (any VoiceInputDelegate)? { get set }
    func start()
    func stop() async
    func cancel()
}

@MainActor
protocol VoiceInputDelegate: AnyObject {
    func voiceInput(didFinalize text: String)
    func voiceInput(didUpdateVolatile text: String)
    func voiceInput(didEncounterError message: String)
    func voiceInput(didUpdateStatus status: String?)
}
