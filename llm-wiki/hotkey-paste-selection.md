---
regen: compiled
sources:
  - Packages/KoechoKit/Sources/KoechoCore/ModifierTapDetector.swift
  - Packages/KoechoKit/Sources/KoechoCore/HotkeyConfig.swift
  - Packages/KoechoKit/Sources/KoechoCore/HotkeySettings.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/HotkeyConfig+Platform.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/ShortcutKey+Platform.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/CGEventClient.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/SelectedTextReader.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AccessibilityClient.swift
  - Koecho/KoechoApp.swift
  - Koecho/InputPanelController.swift
  - Koecho/ShortcutKeyRecorder.swift
  - docs/decisions/0007-double-tap-detection-with-pure-state-machine.md
  - docs/decisions/0008-nsview-based-shortcut-key-recorder.md
---

# Hotkey / Paste / Selection

## Hotkey

- `HotkeyService` は `NSEvent.addGlobalMonitorForEvents` と local monitor で `.flagsChanged` / `.keyDown` を見る。
- raw event は nonisolated `handleEvent` で受け、`DispatchQueue.main.async` で `processEvent` へ渡す。
- tap 判定は Core の `ModifierTapDetector`。single toggle と double tap の分岐は `HotkeyService.processEvent` と `HotkeyConfig.tapMode`。
- key code / modifier flag 変換は Platform extensions（`Packages/KoechoKit/Sources/KoechoPlatform/HotkeyConfig+Platform.swift`, `Packages/KoechoKit/Sources/KoechoPlatform/ShortcutKey+Platform.swift`）に閉じる。Core へ Carbon / AppKit を入れない。

## Selection

- panel 表示前に `PanelLifecycleManager` が frontmost app を記録し、`SelectedTextReader.read(from:)` で選択テキストを取る。
- `SelectedTextReader` は Accessibility trust、focused UI element、selected text の順に失敗を nil で返す。失敗は panel 空文字開始として扱う。
- Accessibility API の mock は `AccessibilityClient`。テストは `SelectedTextReaderTests`。

## Paste

- paste は `InputPanelController.pasteAndRecord(_:)` から `ClipboardPaster.paste(text:to:using:)`。
- `ClipboardPaster` は Accessibility trust を確認し、target app が終了していないことを見てから pasteboard を保存・文字列セット・target activate・Cmd+V CGEvent を送る。
- restore は遅延 task で行う。cancel / paste failure / empty confirm では `restoreClipboard()` を明示的に呼ぶ。
- pasteboard は複数 item / 複数 type を保存して戻す。`ClipboardPasterTests` はここを直接検証する。

## 変更時の注意

- Hotkey は Input Monitoring / Accessibility 権限に依存する。monitor 登録失敗はクラッシュではなく warning に留める。
- ClipboardPaster の失敗は panel 復帰と errorMessage に繋がる。confirm 中の状態遷移を変えるなら `InputPanelControllerConfirmTests` と `ClipboardPasterTests` を見る。
- Shortcut recorder UI は App target の `Koecho/ShortcutKeyRecorder.swift`。設定 model は Core、key capture は AppKit view、key code mapping は Platform の役割。
