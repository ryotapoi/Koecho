import AppKit
import KoechoCore
import Observation
import os

@MainActor @Observable
public final class AppState {
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "AppState")

    public let settings: Settings

    public var inputText: String = ""
    public var isInputPanelVisible: Bool = false
    public var frontmostApplication: NSRunningApplication?
    public var errorMessage: String?
    public var isRunningScript: Bool = false
    public var promptText: String = ""
    public var promptScript: Script? = nil
    public var pendingReplacementPattern: String?
    public var voiceEngineStatus: String?

    public init(settings: Settings) {
        self.settings = settings
    }

    public convenience init() {
        self.init(settings: Settings())
    }
}
