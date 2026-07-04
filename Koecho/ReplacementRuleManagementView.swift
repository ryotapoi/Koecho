import KoechoCore
import SwiftUI

struct ReplacementRuleManagementView: View {
  @Bindable var settings: ReplacementSettings
  @State private var selection: UUID?
  @State private var duplicatePatterns: Set<String>

  init(settings: ReplacementSettings) {
    self.settings = settings
    _duplicatePatterns = State(
      initialValue: ReplacementRuleManagementViewLogic.duplicatePatterns(
        in: settings.replacementRules
      )
    )
  }

  var body: some View {
    HStack(spacing: 0) {
      ruleList
        .frame(width: 200)
      Divider()
      ruleDetail
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear(perform: updateDuplicatePatterns)
    .onChange(of: settings.replacementRules) {
      updateDuplicatePatterns()
    }
  }

  private var ruleList: some View {
    List(selection: $selection) {
      let duplicates = duplicatePatterns
      ForEach(settings.replacementRules) { rule in
        HStack {
          Text(localizedDisplayName(for: rule))
          if rule.usesRegularExpression
            ? duplicates.contains(rule.pattern)
            : rule.patternTexts.contains(where: { duplicates.contains($0) })
          {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.yellow)
              .font(.caption)
              .help("Duplicate pattern: another rule uses the same pattern")
          }
        }
        .tag(rule.id)
      }
      .onMove { source, destination in
        settings.moveReplacementRules(from: source, to: destination)
      }
    }
    .safeAreaInset(edge: .bottom) {
      HStack {
        Button(action: addRule) {
          Label("Add Rule", systemImage: "plus")
            .frame(width: 16, height: 16)
        }
        Button(action: deleteSelectedRule) {
          Label("Delete Rule", systemImage: "minus")
            .frame(width: 16, height: 16)
        }
        .disabled(selection == nil)
        Spacer()
      }
      .labelStyle(.iconOnly)
      .padding(8)
    }
  }

  private func updateDuplicatePatterns() {
    duplicatePatterns = ReplacementRuleManagementViewLogic.duplicatePatterns(
      in: settings.replacementRules
    )
  }

  @ViewBuilder
  private var ruleDetail: some View {
    if let id = selection, let binding = ruleBinding(for: id) {
      ReplacementRuleEditView(rule: binding)
    } else {
      Text("Select a rule to edit")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func ruleBinding(for id: UUID) -> Binding<ReplacementRule>? {
    guard let index = settings.replacementRules.firstIndex(where: { $0.id == id }) else {
      return nil
    }
    return $settings.replacementRules[index]
  }

  private func addRule() {
    let rule = ReplacementRule(pattern: "")
    settings.addReplacementRule(rule)
    selection = rule.id
  }

  private func deleteSelectedRule() {
    guard let id = selection else { return }
    selection = nil
    settings.deleteReplacementRule(id: id)
  }

  private func localizedDisplayName(for rule: ReplacementRule) -> String {
    rule.displayName ?? String(localized: "New Rule")
  }
}

enum ReplacementRuleManagementViewLogic {
  static func duplicatePatterns(in rules: [ReplacementRule]) -> Set<String> {
    var seen: [String: Int] = [:]
    for rule in rules {
      let unique: Set<String>
      if rule.usesRegularExpression {
        unique = rule.pattern.isEmpty ? [] : [rule.pattern]
      } else {
        unique = Set(rule.patternTexts.filter { !$0.isEmpty })
      }
      for p in unique {
        seen[p, default: 0] += 1
      }
    }
    return Set(seen.filter { $0.value > 1 }.keys)
  }
}

// MARK: - Previews

#Preview("With Rules") {
  let defaults = UserDefaults(suiteName: "preview-replacementMgmt-withRules")!
  let settings = ReplacementSettings(defaults: defaults)
  settings.replacementRules = [
    ReplacementRule(patterns: ["GitHブ", "ギットHub"], replacement: "GitHub"),
    ReplacementRule(pattern: "えーと", replacement: ""),
  ]
  return ReplacementRuleManagementView(settings: settings)
    .frame(width: 600, height: 400)
}

#Preview("Empty") {
  let defaults = UserDefaults(suiteName: "preview-replacementMgmt-empty")!
  let settings = ReplacementSettings(defaults: defaults)
  settings.replacementRules = []
  return ReplacementRuleManagementView(settings: settings)
    .frame(width: 600, height: 400)
}
