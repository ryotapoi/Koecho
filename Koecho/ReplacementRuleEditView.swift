import SwiftUI

struct ReplacementRuleEditView: View {
    @Binding var rule: ReplacementRule

    private var patternValidationError: String? { rule.validate() }

    var body: some View {
        Form {
            TextField("Pattern", text: $rule.pattern)
            if let error = patternValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            TextField("Replacement", text: $rule.replacement)
            if rule.usesRegularExpression {
                Text("Use $1, $2 to reference capture groups")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Use Regular Expression", isOn: $rule.usesRegularExpression)

            if !rule.usesRegularExpression {
                Toggle("Match Whole Word", isOn: $rule.matchesWholeWord)
            }
        }
        .formStyle(.grouped)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
