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
    guard !rules.isEmpty else {
      clearPreviews()
      return
    }

    if let textView, textView.volatileRange != nil {
      textView.clearReplacementPreviews()
    } else if let textView, textView.hasMarkedText() {
      showPreview(rules: rules)
    } else {
      applyNow(rules: rules)
    }
  }

  /// Ordinary input honors Auto-replace; explicit Replace keeps applying all rules.
  func handleInput() {
    if appState.settings.replacement.isAutoReplacementEnabled {
      applyOrPreview()
    } else {
      refreshCandidates()
    }
  }

  func refreshCandidates() {
    guard let textView else { return }
    guard appState.isInputPanelVisible, !appState.isRunningScript,
      textView.volatileRange == nil
    else {
      clearPreviews()
      return
    }
    let rules = appState.settings.replacement.replacementRules
    if appState.settings.replacement.isAutoReplacementEnabled {
      if textView.hasMarkedText() { showPreview(rules: rules) }
      else { clearPreviews() }
      return
    }
    let text = textView.string
    let matches = findReplacementCandidates(rules, in: text)
    if textView.hasMarkedText() {
      textView.showReplacementPreviews(matches)
    } else {
      textView.showReplacementCandidates(matches) { [weak self] match in
        self?.replaceOccurrence(match, in: text, rules: rules)
      }
    }
  }

  private func replaceOccurrence(_ match: ReplacementMatch, in text: String, rules: [ReplacementRule]) {
    guard let textView,
      appState.isInputPanelVisible, !appState.isRunningScript,
      !appState.settings.replacement.isAutoReplacementEnabled,
      !textView.hasMarkedText(), textView.volatileRange == nil,
      textView.string == text, appState.inputText == text,
      appState.settings.replacement.replacementRules == rules,
      findReplacementCandidates(rules, in: text).contains(match)
    else {
      refreshCandidates()
      return
    }
    let application = applyReplacementMatch(
      match, to: text, insertionPoint: voiceCoordinator.voiceInsertionPoint)
    let selection = textView.selectedRange()
    let start = applyReplacementMatch(match, to: text, insertionPoint: selection.location).insertionPoint
    let end = applyReplacementMatch(match, to: text, insertionPoint: NSMaxRange(selection)).insertionPoint
    voiceCoordinator.moveVoiceInsertionPoint(to: application.insertionPoint, in: application.text)
    appState.setInputText(application.text)
    appState.errorMessage = nil
    textView.replaceText(application.text, selecting: NSRange(location: start, length: end - start))
    refreshCandidates()
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
    refreshCandidates()
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
