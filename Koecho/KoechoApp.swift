import AppKit
import SwiftUI
import os

@main
struct KoechoApp: App {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "App")

    init() {
        logger.info("Koecho launched")
    }

    var body: some Scene {
        MenuBarExtra("Koecho", systemImage: "mic.fill") {
            Button("Quit Koecho") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
