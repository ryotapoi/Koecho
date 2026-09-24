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
