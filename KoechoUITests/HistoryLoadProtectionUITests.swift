import XCTest

@MainActor
final class HistoryLoadProtectionUITests: XCTestCase {
  private var fixtureHome: URL!
  private var app: XCUIApplication!

  private var historyURL: URL {
    fixtureHome.appendingPathComponent(
      "Library/Application Support/com.ryotapoi.koecho/history.json"
    )
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    fixtureHome = FileManager.default.temporaryDirectory
      .appendingPathComponent("koecho-history-ui-test-\(UUID().uuidString)")
    let historyDirectory = fixtureHome
      .appendingPathComponent("Library/Application Support/com.ryotapoi.koecho")
    try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
    try Data("invalid history".utf8).write(
      to: historyURL,
      options: .atomic
    )

    app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launchEnvironment["CFFIXED_USER_HOME"] = fixtureHome.path
    app.launch()
  }

  override func tearDownWithError() throws {
    app.terminate()
    try? FileManager.default.removeItem(at: fixtureHome)
  }

  func testHistoryLoadFailureShowsOneAlert() {
    dismissLoadAlert(containing: ["History could not be loaded"])
  }

  func testHistoryResetRequiresConfirmationAndRestoresNormalHistory() throws {
    dismissLoadAlert(containing: ["History could not be loaded"])
    openHistorySettings()

    let resetButton = app.buttons["Reset History"]
    XCTAssertTrue(resetButton.waitForExistence(timeout: 5))
    resetButton.click()

    let resetDialog = app.sheets["alert"]
    if !resetDialog.waitForExistence(timeout: 2) {
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "Missing reset confirmation UI hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      addScreenshot(named: "Missing reset confirmation")
      XCTFail("The reset confirmation did not appear as a sheet")
      return
    }
    resetDialog.buttons["Cancel"].click()
    XCTAssertEqual(try Data(contentsOf: historyURL), Data("invalid history".utf8))

    resetButton.click()
    XCTAssertTrue(resetDialog.waitForExistence(timeout: 2))
    resetDialog.buttons["Reset History"].click()

    let clearedHistory = try Data(contentsOf: historyURL)
    XCTAssertEqual(try JSONDecoder().decode([String].self, from: clearedHistory), [])

    app.terminate()
    app.launch()
    XCTAssertFalse(app.dialogs["alert"].waitForExistence(timeout: 2))
  }

  func testHistoryAndSettingsFailuresAreCombinedInOneDialog() {
    app.terminate()
    app.launchArguments += ["-scripts", "invalid"]
    app.launch()

    dismissLoadAlert(containing: ["Scripts", "History could not be loaded"])
  }

  private func dismissLoadAlert(containing descriptions: [String]) {
    let alert = app.dialogs["alert"]
    if !alert.waitForExistence(timeout: 5) {
      let hierarchy = XCTAttachment(string: app.debugDescription)
      hierarchy.name = "Missing alert UI hierarchy"
      hierarchy.lifetime = .keepAlways
      add(hierarchy)
      addScreenshot(named: "Missing history load alert")
      XCTFail("The history load alert did not appear")
      return
    }
    for description in descriptions {
      let text = alert.staticTexts.matching(
        NSPredicate(format: "value CONTAINS %@", description)
      ).firstMatch
      XCTAssertTrue(text.exists)
    }
    addScreenshot(named: "History load alert")

    app.activate()
    alert.buttons["OK"].click()
    let dialogs = app.dialogs.matching(NSPredicate(format: "label == %@", "alert"))
    let dismissed = expectation(
      for: NSPredicate(format: "count == 0"),
      evaluatedWith: dialogs
    )
    wait(for: [dismissed], timeout: 2)
    addScreenshot(named: "History load alert dismissed")
  }

  private func addScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func openHistorySettings() {
    app.statusItems["MenuBarIcon"].click()
    let settingsItem = app.menuItems["Settings..."]
    XCTAssertTrue(settingsItem.waitForExistence(timeout: 2))
    settingsItem.click()

    let settingsWindow = app.windows["Settings"]
    XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
    settingsWindow.outlines["Sidebar"].staticTexts["History"].click()
  }
}
