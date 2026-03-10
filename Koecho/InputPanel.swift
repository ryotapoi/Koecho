import AppKit
import KoechoCore
import KoechoPlatform

final class InputPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onShortcutKey: ((ShortcutKey) -> Bool)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        contentMinSize = NSSize(width: 200, height: 150)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func close() {
        onEscape?()
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              !characters.isEmpty,
              ShortcutKey.isPrintableASCII(characters) else {
            return super.performKeyEquivalent(with: event)
        }

        let mods = ShortcutKey.modifiers(from: event.modifierFlags)
        guard ShortcutKey.hasRequiredModifier(mods) else {
            return super.performKeyEquivalent(with: event)
        }

        let shortcut = ShortcutKey(modifiers: mods, character: characters)
        if onShortcutKey?(shortcut) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}
