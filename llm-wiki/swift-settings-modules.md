---
regen: compiled
sources:
  - Packages/KoechoKit/Sources/KoechoCore/Settings.swift
  - Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/HotkeySettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/Array+Move.swift
  - Packages/KoechoKit/Sources/KoechoCore/HotkeyConfig.swift
  - Packages/KoechoKit/Sources/KoechoCore/ShortcutKey.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift
  - docs/decisions/0018-spm-module-separation.md
---

# Swift / Settings / Modules

## Observation / Settings

- `@Observable` な設定型は stored property の didSet と永続化の入口が増えやすい。既存の backing-store pattern に合わせる。
- Observation を使うファイルは `import Observation` が必要。SwiftUI import だけに頼らない。
- SwiftUI の `Settings` scene と Koecho の `Settings` model は名前が衝突しやすい。曖昧になる場所では `KoechoCore.Settings` と明示する。
- `@MainActor` initializer の default argument は actor isolation と衝突することがある。必要なら default 値生成を呼び出し側や static factory に分ける。

## Collection / Hotkey

- Swift 6 の `Array.move(fromOffsets:toOffset:)` は SwiftUI 依存の拡張として扱われることがある。Core では `Packages/KoechoKit/Sources/KoechoCore/Array+Move.swift` のローカル実装を使う。
- hotkey 表現は Core の値型に閉じる。Carbon / AppKit 由来の key code 変換は Platform または App 側で扱う。

## モジュール境界

- 依存方向は `Koecho -> KoechoPlatform -> KoechoCore`。
- `KoechoCore` に AppKit、Carbon、CoreAudio、Speech などの macOS 固有 API を入れない。
- `KoechoPlatform` は AppState、音声認識、オーディオ、ペースト、ホットキー、選択テキスト取得などの platform integration を持つ。
- App target は SwiftUI / AppKit UI、`NSTextView` 依存、InputPanel 周辺を持つ。
- module separation は後方互換 shim を増やす理由にしない。古い入口を残すより、呼び出し側を新しい境界に合わせて更新する。
