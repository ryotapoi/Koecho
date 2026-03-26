import SwiftUI
import KoechoCore

struct ReplacementRuleEditView: View {
    @Binding var rule: ReplacementRule

    private var patternValidationError: String? { rule.validate() }

    var body: some View {
        Form {
            if rule.usesRegularExpression {
                regexPatternSection
            } else {
                plainPatternSection
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

    // MARK: - Regex mode: single pattern

    private var regexPatternSection: some View {
        Group {
            TextField("Pattern", text: $rule.pattern)
            if let error = patternValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Plain text mode: multiple patterns

    @ViewBuilder
    private var plainPatternSection: some View {
        Section("Patterns") {
            ForEach(rule.patterns.indices, id: \.self) { index in
                HStack {
                    TextField(
                        "Pattern",
                        text: Binding(
                            get: { rule.patterns[index] },
                            set: { rule.patterns[index] = $0 }
                        )
                    )
                    Button {
                        rule.patterns.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .disabled(rule.patterns.count <= 1)
                    .accessibilityLabel("Remove pattern")
                }
            }
            Button {
                rule.patterns.append("")
            } label: {
                Label("Add Pattern", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Previews

#Preview("Plain Text") {
    @Previewable @State var rule = ReplacementRule(
        patterns: ["GitHブ", "ギットHub"],
        replacement: "GitHub"
    )
    ReplacementRuleEditView(rule: $rule)
        .frame(width: 400, height: 300)
}

#Preview("Regex") {
    @Previewable @State var rule = ReplacementRule(
        pattern: "\\b(\\d{4})-(\\d{2})-(\\d{2})\\b",
        replacement: "$2/$3/$1",
        usesRegularExpression: true
    )
    ReplacementRuleEditView(rule: $rule)
        .frame(width: 400, height: 300)
}

#Preview("Empty") {
    @Previewable @State var rule = ReplacementRule(pattern: "")
    ReplacementRuleEditView(rule: $rule)
        .frame(width: 400, height: 300)
}
