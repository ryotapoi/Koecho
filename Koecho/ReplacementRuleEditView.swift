import KoechoCore
import SwiftUI

struct ReplacementRuleEditView: View {
  @Binding var rule: ReplacementRule

  private var patternValidationError: String? { rule.validate() }

  var body: some View {
    Form {
      Section {
        Picker("Replacement Method", selection: $rule.usesRegularExpression) {
          Text("Plain Text").tag(false)
          Text("Regular Expression").tag(true)
        }
        .pickerStyle(.menu)
      }

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
    Section {
      // Removing an empty row in onChange can discard uncommitted Japanese input.
      // Keep row removal explicit while a TextField is being edited.
      ForEach($rule.patterns) { $pattern in
        HStack {
          TextField(
            .textToReplace,
            text: $pattern.text
          )
          Button {
            rule.patterns.removeAll { $0.id == pattern.id }
          } label: {
            Image(systemName: "minus.circle")
          }
          .buttonStyle(.borderless)
          .disabled(rule.patterns.count <= 1)
          .accessibilityLabel("Remove pattern")
        }
      }
      Button {
        rule.patterns.append(ReplacementRulePattern(text: ""))
      } label: {
        Label(.addText, systemImage: "plus")
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
