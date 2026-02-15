import AppKit
import os

@MainActor @Observable
final class AppState {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "AppState")

    let settings: Settings

    var inputText: String = ""
    var isInputPanelVisible: Bool = false
    var frontmostApplication: NSRunningApplication?
    var errorMessage: String?

    init(settings: Settings) {
        self.settings = settings
    }

    convenience init() {
        self.init(settings: Settings())
    }
}
