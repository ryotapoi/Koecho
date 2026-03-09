import AppKit

@MainActor
final class ReplacementService {
    var textView: (any TextViewOperating)?

    private let appState: AppState
    private let getVoiceInsertionPoint: () -> Int
    private let setVoiceInsertionPoint: (Int) -> Void

    init(
        appState: AppState,
        getVoiceInsertionPoint: @escaping () -> Int,
        setVoiceInsertionPoint: @escaping (Int) -> Void
    ) {
        self.appState = appState
        self.getVoiceInsertionPoint = getVoiceInsertionPoint
        self.setVoiceInsertionPoint = setVoiceInsertionPoint
    }

    func applyOrPreview() {
        guard appState.isInputPanelVisible,
              !appState.isRunningScript else { return }
        let rules = appState.settings.replacementRules
        guard !rules.isEmpty else { return }

        if let textView, textView.volatileRange != nil {
            textView.clearReplacementPreviews()
        } else if let textView, textView.hasMarkedText() {
            showPreview(rules: rules)
        } else {
            applyNow()
        }
    }

    func applyNow() {
        guard appState.isInputPanelVisible,
              !appState.isRunningScript else { return }
        let rules = appState.settings.replacementRules
        guard !rules.isEmpty else { return }
        textView?.clearReplacementPreviews()
        let currentText = appState.inputText
        let result = applyReplacementRules(rules, to: currentText)
        if result != currentText {
            let currentNSLength = (currentText as NSString).length
            let matches = findReplacementMatches(rules, in: currentText)
                .filter { $0.range.location >= 0 && $0.range.location + $0.range.length <= currentNSLength }
                .sorted { $0.range.location < $1.range.location }
            var voiceInsertionPoint = getVoiceInsertionPoint()
            var offset = 0
            for match in matches {
                let adjustedLocation = match.range.location + offset
                if adjustedLocation < voiceInsertionPoint {
                    let delta = (match.replacement as NSString).length - match.range.length
                    voiceInsertionPoint += delta
                    offset += delta
                }
            }
            voiceInsertionPoint = max(0, min(voiceInsertionPoint, (result as NSString).length))
            setVoiceInsertionPoint(voiceInsertionPoint)

            appState.inputText = result
            appState.errorMessage = nil
            textView?.setString(result, suppressingCallbacks: true)
        }
    }

    func applyRules(to text: String) -> String {
        let rules = appState.settings.replacementRules
        guard !rules.isEmpty else { return text }
        return applyReplacementRules(rules, to: text)
    }

    func clearPreviews() {
        textView?.clearReplacementPreviews()
    }

    func addRule(_ rule: ReplacementRule) {
        appState.settings.addReplacementRule(rule)
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
