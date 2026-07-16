import Foundation
import KoechoCore
import Testing

@testable import Koecho

@MainActor
struct InputPanelScriptReorderTests {
  private func scripts() -> [Script] {
    [
      Script(name: "A", scriptPath: "/bin/a"),
      Script(name: "B", scriptPath: "/bin/b"),
      Script(name: "C", scriptPath: "/bin/c"),
      Script(name: "D", scriptPath: "/bin/d"),
    ]
  }

  private func names(_ scripts: [Script]) -> [String] {
    scripts.map(\.name)
  }

  @Test func promptKeepsItsSelectedScriptButtonEnabled() {
    let selectedScript = Script(name: "Selected", scriptPath: "/bin/selected")
    let otherScript = Script(name: "Other", scriptPath: "/bin/other")

    #expect(
      !InputPanelScriptStrip.isExecutionDisabled(
        isRunningScript: false,
        hasPromptScript: true,
        selectedScriptID: selectedScript.id,
        scriptID: selectedScript.id
      )
    )
    #expect(
      InputPanelScriptStrip.isExecutionDisabled(
        isRunningScript: false,
        hasPromptScript: true,
        selectedScriptID: selectedScript.id,
        scriptID: otherScript.id
      )
    )
    #expect(
      InputPanelScriptStrip.isExecutionDisabled(
        isRunningScript: true,
        hasPromptScript: true,
        selectedScriptID: selectedScript.id,
        scriptID: selectedScript.id
      )
    )
  }

  @Test func movesFirstItemBeforeMiddleItem() {
    let scripts = scripts()

    let reordered = InputPanelScriptReorder.reordered(
      scripts: scripts,
      sourceIDs: [scripts[0].id],
      destination: .before(scripts[2].id)
    )

    #expect(names(reordered) == ["B", "A", "C", "D"])
  }

  @Test func movesMiddleItemBeforeFirstItem() {
    let scripts = scripts()

    let reordered = InputPanelScriptReorder.reordered(
      scripts: scripts,
      sourceIDs: [scripts[2].id],
      destination: .before(scripts[0].id)
    )

    #expect(names(reordered) == ["C", "A", "B", "D"])
  }

  @Test func movesItemToEnd() {
    let scripts = scripts()

    let reordered = InputPanelScriptReorder.reordered(
      scripts: scripts,
      sourceIDs: [scripts[0].id],
      destination: .end
    )

    #expect(names(reordered) == ["B", "C", "D", "A"])
  }

  @Test func preservesCurrentOrderForMultipleSources() {
    let scripts = scripts()

    let reordered = InputPanelScriptReorder.reordered(
      scripts: scripts,
      sourceIDs: [scripts[2].id, scripts[0].id],
      destination: .end
    )

    #expect(names(reordered) == ["B", "D", "A", "C"])
  }

  @Test func missingDestinationAppendsMovedScripts() {
    let scripts = scripts()

    let reordered = InputPanelScriptReorder.reordered(
      scripts: scripts,
      sourceIDs: [scripts[1].id],
      destination: .before(UUID())
    )

    #expect(names(reordered) == ["A", "C", "D", "B"])
  }

  @Test func emptySourcesLeaveScriptsUnchanged() {
    let scripts = scripts()

    let reordered = InputPanelScriptReorder.reordered(
      scripts: scripts,
      sourceIDs: [],
      destination: .end
    )

    #expect(reordered == scripts)
  }

  @Test func reorderedScriptsPersistThroughSettingsReloadAndKeepBuiltinNormalization() {
    let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    let settings = ScriptSettings(defaults: defaults)
    let builtin = Script.defaultBuiltins[0]
    let duplicateBuiltin = Script.defaultBuiltins[0]
    let custom = Script(name: "Custom", scriptPath: "/bin/custom")

    settings.scripts = [builtin, duplicateBuiltin, custom]
    let reordered = InputPanelScriptReorder.reordered(
      scripts: settings.scripts,
      sourceIDs: [custom.id],
      destination: .before(builtin.id)
    )

    settings.scripts = reordered

    let reloaded = ScriptSettings(defaults: defaults)
    #expect(names(reloaded.scripts) == ["Custom", "Decrease Indent"])
    #expect(reloaded.scripts.map(\.id) == [custom.id, builtin.id])
  }
}
