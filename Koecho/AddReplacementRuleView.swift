import SwiftUI

struct AddReplacementRuleView: View {
    let pattern: String
    var onAdd: (ReplacementRule) -> Void
    var onCancel: () -> Void

    @State private var replacement = ""
    @State private var usesRegularExpression = false
    @State private var matchesWholeWord = false
    @FocusState private var isReplacementFocused: Bool

    private var patternValidationError: String? {
        guard usesRegularExpression else { return nil }
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private var isValid: Bool {
        patternValidationError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Replacement Rule")
                .font(.headline)

            TextField("Pattern", text: .constant(pattern))
                .disabled(true)

            TextField("Replacement", text: $replacement)
                .focused($isReplacementFocused)

            if let error = patternValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("Use Regular Expression", isOn: $usesRegularExpression)

            if !usesRegularExpression {
                Toggle("Match Whole Word", isOn: $matchesWholeWord)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add") {
                    let rule = ReplacementRule(
                        pattern: pattern,
                        replacement: replacement,
                        usesRegularExpression: usesRegularExpression,
                        matchesWholeWord: matchesWholeWord
                    )
                    onAdd(rule)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(width: 260)
        .onAppear {
            isReplacementFocused = true
        }
    }
}
