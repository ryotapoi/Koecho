import AppKit
import os

@MainActor
final class DictationEngine: VoiceInputEngine {
    private let logger = Logger(subsystem: "com.ryotapoi.koecho", category: "DictationEngine")
    private(set) var state: VoiceInputState = .idle
    weak var delegate: (any VoiceInputDelegate)?
    private weak var panel: InputPanel?
    private weak var textView: VoiceInputTextView?
    private var retryWorkItem: DispatchWorkItem?

    /// Configure with panel and textView references.
    /// Called when textView is created and when panel is shown.
    func configure(panel: InputPanel, textView: VoiceInputTextView?) {
        self.panel = panel
        self.textView = textView
    }

    func start() {
        guard state == .idle, retryWorkItem == nil else { return }
        guard panel != nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.sendStartDictation()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    /// Reset state and start again. Used after focus transitions
    /// where macOS stops the Dictation session.
    func restart() {
        retryWorkItem?.cancel()
        retryWorkItem = nil
        state = .idle
        start()
    }

    func stop() async {
        retryWorkItem?.cancel()
        retryWorkItem = nil
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
        retryWorkItem?.cancel()
        retryWorkItem = nil
        if let textView {
            textView.inputContext?.discardMarkedText()
        }
        panel?.makeFirstResponder(nil)
        state = .idle
    }

    private func sendStartDictation() {
        retryWorkItem = nil
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
