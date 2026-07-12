import AppKit
import KoechoCore
import os

@MainActor
final class DictationEngine: VoiceInputEngine {
  typealias StartDictationActionSender = (Selector) -> Bool
  typealias StartDelay = () async throws -> Void
  typealias RetryTaskClearObserver = () -> Void

  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "DictationEngine")
  private let startDictationActionSender: StartDictationActionSender
  private let startDelay: StartDelay
  private let retryTaskClearObserver: RetryTaskClearObserver
  private(set) var state: VoiceInputState = .idle
  weak var delegate: (any VoiceInputDelegate)?
  private weak var panel: InputPanel?
  private weak var textView: VoiceInputTextView?
  private var retryTask: Task<Void, Never>?
  private var retryTaskID: UUID?

  init(
    startDictationActionSender: @escaping StartDictationActionSender = {
      NSApp.sendAction($0, to: nil, from: nil)
    },
    startDelay: @escaping StartDelay = {
      try await Task.sleep(for: .milliseconds(300))
    },
    retryTaskClearObserver: @escaping RetryTaskClearObserver = {}
  ) {
    self.startDictationActionSender = startDictationActionSender
    self.startDelay = startDelay
    self.retryTaskClearObserver = retryTaskClearObserver
  }

  /// Configure with panel and textView references.
  /// Called when textView is created and when panel is shown.
  func configure(panel: InputPanel, textView: VoiceInputTextView?) {
    self.panel = panel
    self.textView = textView
  }

  func start() {
    guard state == .idle, retryTask == nil else { return }
    guard panel != nil else { return }

    let retryTaskID = UUID()
    self.retryTaskID = retryTaskID
    retryTask = Task {
      do {
        try await startDelay()
        try Task.checkCancellation()
        sendStartDictation()
      } catch is CancellationError {
        // Normal when cancel(), stop(), or restart() supersedes the pending start.
      } catch {
        logger.error("Dictation start delay failed: \(String(describing: error), privacy: .public)")
        clearRetryTaskIfCurrent(retryTaskID)
      }
    }
  }

  /// Reset state and start again. Used after focus transitions
  /// where macOS stops the Dictation session.
  func restart() {
    retryTask?.cancel()
    retryTask = nil
    retryTaskID = nil
    state = .idle
    start()
  }

  func stop() async {
    retryTask?.cancel()
    retryTask = nil
    retryTaskID = nil
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
    retryTaskID = nil
    if let textView {
      textView.inputContext?.discardMarkedText()
    }
    panel?.makeFirstResponder(nil)
    state = .idle
  }

  private func sendStartDictation() {
    retryTask = nil
    retryTaskID = nil
    guard let panel else { return }
    guard state == .idle else { return }

    if let textView, panel.firstResponder !== textView {
      panel.makeFirstResponder(textView)
    }

    let selector = Selector(("startDictation:"))
    if !startDictationActionSender(selector) {
      textView?.perform(selector, with: nil)
    }
    state = .listening
    logger.debug("startDictation sent")
  }

  private func clearRetryTaskIfCurrent(_ taskID: UUID) {
    guard retryTaskID == taskID else { return }
    retryTask = nil
    retryTaskID = nil
    retryTaskClearObserver()
  }
}
