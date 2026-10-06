import AppKit
import KoechoCore
import KoechoPlatform

@MainActor
final class ReplacementService {
  var textView: (any TextViewOperating)?

  private let appState: AppState
  private let voiceCoordinator: VoiceInputCoordinator

  init(
    appState: AppState,
    voiceCoordinator: VoiceInputCoordinator
  ) {
    self.appState = appState
    self.voiceCoordinator = voiceCoordinator
  }

  func applyOrPreview() {
    guard appState.isInputPanelVisible,
      !appState.isRunningScript
    else { return }
    let rules = appState.settings.replacement.replacementRules
    guard !rules.isEmpty else { return }

    if let textView, textView.volatileRange != nil {
      textView.clearReplacementPreviews()
    } else if let textView, textView.hasMarkedText() {
      showPreview(rules: rules)
    } else {
      applyNow(rules: rules)
    }
  }

  private func applyNow(rules: [ReplacementRule]) {
    textView?.clearReplacementPreviews()
    let currentText = appState.inputText
    let application = applyReplacementRules(
      rules, to: currentText, insertionPoint: voiceCoordinator.voiceInsertionPoint)
    let result = application.text
    if result != currentText {
      let voiceInsertionPoint = application.insertionPoint
      voiceCoordinator.moveVoiceInsertionPoint(to: voiceInsertionPoint, in: result)

      appState.setInputText(result)
      appState.errorMessage = nil
      textView?.replaceText(
        result, selecting: NSRange(location: voiceInsertionPoint, length: 0))
    }
  }

  func applyRules(to text: String) -> String {
    let rules = appState.settings.replacement.replacementRules
    guard !rules.isEmpty else { return text }
    return applyReplacementRules(rules, to: text)
  }

  func clearPreviews() {
    textView?.clearReplacementPreviews()
  }

  func addRule(_ rule: ReplacementRule) {
    appState.settings.replacement.addReplacementRule(rule)
    appState.pendingReplacementPattern = nil
    applyOrPreview()
  }

  private func showPreview(rules: [ReplacementRule]) {
    let currentText = textView?.string ?? ""
    guard !currentText.isEmpty else {
      textView?.clearReplacementPreviews()
      return
    }
    let matches = findReplacementMatches(rules, in: currentText)
    if matches.isEmpty {
      textView?.clearReplacementPreviews()
    } else {
      textView?.showReplacementPreviews(matches)
    }
  }
}
