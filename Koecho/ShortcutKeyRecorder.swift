import AppKit
import KoechoCore
import KoechoPlatform
import SwiftUI

nonisolated enum ShortcutKeyRecorderEventDecision: Equatable {
  case cancel
  case ignore
  case record(ShortcutKey)

  static func decide(
    keyCode: UInt16,
    characters: String?,
    modifiers: Set<Modifier>
  ) -> Self {
    guard keyCode != 53 else { return .cancel }
    guard let characters = characters?.lowercased(),
      ShortcutKey.isPrintableASCII(characters),
      ShortcutKey.hasRequiredModifier(modifiers)
    else {
      return .ignore
    }
    return .record(ShortcutKey(modifiers: modifiers, character: characters))
  }
}

struct ShortcutKeyRecorder: NSViewRepresentable {
  @Binding var shortcutKey: ShortcutKey?

  func makeNSView(context: Context) -> ShortcutKeyRecorderView {
    let view = ShortcutKeyRecorderView()
    view.shortcutKey = shortcutKey
    view.onShortcutKeyChanged = { newValue in
      shortcutKey = newValue
    }
    return view
  }

  func updateNSView(_ nsView: ShortcutKeyRecorderView, context: Context) {
    nsView.shortcutKey = shortcutKey
    nsView.needsDisplay = true
  }
}

final class ShortcutKeyRecorderView: NSView {
  var shortcutKey: ShortcutKey?
  var onShortcutKeyChanged: ((ShortcutKey?) -> Void)?

  private var isRecording = false
  private let clearButton = NSButton()

  override var acceptsFirstResponder: Bool { true }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateLayerColors()
    needsDisplay = true
  }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    wantsLayer = true
    layer?.cornerRadius = 6
    layer?.borderWidth = 1

    clearButton.bezelStyle = .inline
    clearButton.title = "\u{00D7}"  // ×
    clearButton.font = .systemFont(ofSize: 11)
    clearButton.isBordered = false
    clearButton.target = self
    clearButton.action = #selector(clearShortcut)
    clearButton.translatesAutoresizingMaskIntoConstraints = false
    addSubview(clearButton)

    NSLayoutConstraint.activate([
      clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
      clearButton.widthAnchor.constraint(equalToConstant: 16),
      clearButton.heightAnchor.constraint(equalToConstant: 16),
    ])

    updateAppearance()
  }

  override var intrinsicContentSize: NSSize {
    NSSize(width: 120, height: 22)
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    let text: String
    let color: NSColor
    if isRecording {
      text = String(localized: "Press shortcut...")
      color = .secondaryLabelColor
    } else if let key = shortcutKey {
      text = key.displayName
      color = .labelColor
    } else {
      text = String(localized: "None")
      color = .tertiaryLabelColor
    }

    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12),
      .foregroundColor: color,
    ]
    let attrString = NSAttributedString(string: text, attributes: attributes)
    let size = attrString.size()
    let point = NSPoint(
      x: 8,
      y: (bounds.height - size.height) / 2
    )
    attrString.draw(at: point)
  }

  override func mouseDown(with event: NSEvent) {
    if !isRecording {
      startRecording()
    }
  }

  // Capture key events during recording via performKeyEquivalent.
  // This fires before keyDown and catches modifier+key combos that
  // other views (e.g. NavigationSplitView) would otherwise consume.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard isRecording else { return super.performKeyEquivalent(with: event) }
    return handleKeyEvent(event)
  }

  override func keyDown(with event: NSEvent) {
    guard isRecording else {
      super.keyDown(with: event)
      return
    }
    // Fallback for keys not routed through performKeyEquivalent
    _ = handleKeyEvent(event)
  }

  override func resignFirstResponder() -> Bool {
    if isRecording {
      stopRecording()
    }
    return super.resignFirstResponder()
  }

  private func handleKeyEvent(_ event: NSEvent) -> Bool {
    let decision = ShortcutKeyRecorderEventDecision.decide(
      keyCode: event.keyCode,
      characters: event.charactersIgnoringModifiers,
      modifiers: ShortcutKey.modifiers(from: event.modifierFlags)
    )

    switch decision {
    case .cancel:
      stopRecording()
    case .ignore:
      break
    case .record(let shortcut):
      shortcutKey = shortcut
      onShortcutKeyChanged?(shortcut)
      stopRecording()
    }
    return true
  }

  private func startRecording() {
    isRecording = true
    window?.makeFirstResponder(self)
    updateAppearance()
  }

  private func stopRecording() {
    isRecording = false
    updateAppearance()
  }

  @objc private func clearShortcut() {
    shortcutKey = nil
    onShortcutKeyChanged?(nil)
    updateAppearance()
  }

  private func updateAppearance() {
    updateLayerColors()
    clearButton.isHidden = shortcutKey == nil && !isRecording
    needsDisplay = true
  }

  private func updateLayerColors() {
    layer?.borderColor =
      isRecording
      ? NSColor.controlAccentColor.cgColor
      : NSColor.separatorColor.cgColor
    layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
  }
}
