import AppKit
import os
import KoechoCore

@MainActor
final class DictationEngine: VoiceInputEngine {
    private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "DictationEngine")
    private(set) var state: VoiceInputState = .idle
    weak var delegate: (any VoiceInputDelegate)?
    private weak var panel: InputPanel?
    private weak var textView: VoiceInputTextView?
    private var retryTask: Task<Void, Never>?

    /// Configure with panel and textView references.
    /// Called when textView is created and when panel is shown.
    func configure(panel: InputPanel, textView: VoiceInputTextView?) {
        self.panel = panel
        self.textView = textView
    }

    func start() {
        guard state == .idle, retryTask == nil else { return }
        guard panel != nil else { return }

        retryTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                sendStartDictation()
            } catch {}
        }
    }

    /// Reset state and start again. Used after focus transitions
    /// where macOS stops the Dictation session.
    func restart() {
        retryTask?.cancel()
        retryTask = nil
        state = .idle
        start()
    }

    func stop() async {
        retryTask?.cancel()
        retryTask = nil
        guard state == .listening || state == .idle else { return }
        state = .stopping
        if let textView {
            textView.inputContext?.discardMarkedText()
        }
        panel?.makeFirstResponder(nil)
        try? await Task.sleep(for: .milliseconds(100))
        state = .idle
    }

    func cancel() {
        retryTask?.cancel()
        retryTask = nil
        if let textView {
            textView.inputContext?.discardMarkedText()
        }
        panel?.makeFirstResponder(nil)
        state = .idle
    }

    private func sendStartDictation() {
        retryTask = nil
        guard let panel else { return }
        guard state == .idle else { return }

        if let textView, panel.firstResponder !== textView {
            panel.makeFirstResponder(textView)
        }

        let selector = Selector(("startDictation:"))
        if !NSApp.sendAction(selector, to: nil, from: nil) {
            textView?.perform(selector, with: nil)
        }
        state = .listening
        logger.debug("startDictation sent")
    }
}
