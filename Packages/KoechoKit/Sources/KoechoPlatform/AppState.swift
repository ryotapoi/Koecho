import AppKit
import KoechoCore
import Observation
import os

@MainActor @Observable
public final class AppState {
  private let logger = Logger(subsystem: Logger.koechoSubsystem, category: "AppState")

  public let settings: Settings

  public private(set) var inputText: String = ""
  public private(set) var scriptUndoText: String?
  public private(set) var lastContent: String?
  public var isInputPanelVisible: Bool = false
  public var frontmostApplication: NSRunningApplication?
  public var errorMessage: String?
  public var isRunningScript: Bool = false
  public var promptText: String = ""
  public var volatilePromptText: String = ""
  public var promptScript: Script? = nil
  public var pendingReplacementPattern: String?
  public var voiceEngineStatus: String?

  public init(settings: Settings) {
    self.settings = settings
  }

  public convenience init() {
    self.init(settings: Settings())
  }

  public func setInputText(_ text: String) {
    if text != inputText {
      scriptUndoText = nil
    }
    inputText = text
  }

  public func retainLastContent(_ text: String) {
    // Closing an empty panel must not discard the previous recoverable content.
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    lastContent = text
  }

  @discardableResult
  public func copyLastContentToClipboard(using pasteboard: NSPasteboard = .general) -> Bool {
    guard let lastContent else { return false }
    pasteboard.clearContents()
    return pasteboard.setString(lastContent, forType: .string)
  }

  public func offerScriptUndo(restoring text: String) {
    scriptUndoText = text
  }

  public func discardScriptUndo() {
    scriptUndoText = nil
  }

  public func consumeScriptUndo() -> String? {
    guard let text = scriptUndoText else { return nil }
    scriptUndoText = nil
    inputText = text
    return text
  }
}
