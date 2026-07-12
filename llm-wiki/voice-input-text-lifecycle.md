---
regen: compiled
sources:
  - Koecho/VoiceInputTextView.swift
  - Koecho/ReplacementPreviewTooltip.swift
  - Koecho/VoiceInputTextEditor.swift
  - Koecho/VoiceInputCoordinator.swift
  - Koecho/InputPanelController.swift
  - Koecho/DictationEngine.swift
  - Koecho/ReplacementService.swift
  - Koecho/ScriptExecutionService.swift
  - docs/decisions/0001-auto-start-dictation-via-startdictation-selector.md
  - docs/decisions/0005-becomekey-trigger-with-retry-for-dictation-start.md
  - docs/decisions/0010-nstextview-subclass-replacing-swiftui-texteditor.md
  - docs/decisions/0017-split-inputpanelcontroller-into-services.md
  - docs/decisions/0021-replay-suppression-state-as-enum.md
  - docs/decisions/0022-finalized-input-text-ownership.md
---

# 音声入力テキストライフサイクル

## NSTextView / NSViewRepresentable

- `VoiceInputTextView` は `NSTextView` subclass として確定テキスト、marked text、volatile テキストを扱う。
- 確定テキストの正本は `AppState.inputText`、`VoiceInputTextView` は marked / volatile text を含む表示・編集バッファ。所有権と同期境界は ADR 0022 を参照する。
- `NSViewRepresentable.updateNSView` から `textView.string` を直接同期すると、入力中の IME composition や dictation の marked text を壊しやすい。同期の入口は `VoiceInputTextView` 側に寄せる。
- プログラム由来の textStorage 変更でも `didChangeText` が発火する。storage 編集と callback suppression は `VoiceInputTextView` の操作へ閉じ、外部からフラグや storage を制御しない。
- レイアウトと overlay 位置計算は `layoutManager` の glyph rect と `textContainerOrigin` を基準にする。文字列 index と画面座標を直接結びつけない。
- replacement preview の tracking area と下線 geometry は `VoiceInputTextView`、hover tooltip の floating window・描画・画面端調整・show/hide lifecycle は `ReplacementPreviewTooltip` が所有する。TextView には tooltip subview を追加しない。
- `wantsUpdateLayer` を `true` にすると `draw(_:)` が呼ばれない。背景や下線を `draw(_:)` で描く view では使わない。

## Dictation / focus

- macOS の `startDictation:` は focus が完全に移ってから送る必要がある。`DictationEngine` は start 直後に短い delay を入れる。
- 入力パネル表示直後の focus 遷移では、OS dictation が TextEditor の text change と重なりやすい。エンジン開始、focus、テキスト同期の順番を変える変更は regression test の対象にする。
- OS dictation 由来の interim text は finalized text と分けて扱う。volatile text は実際には `textView.string` に挿入されるため、NSRange を扱う機能は「表示文字列」基準か「確定文字列」基準かを明確にする。

## 置換・スクリプト・履歴

- 置換ルールの replay は、置換後のプログラム変更が再度 commit として解釈されないように suppression を使う。
- スクリプト実行時の prompt 由来 volatile text は履歴や final text と混ざりやすい。処理対象を `finalizedString` にするのか、`textView.string` にするのかを入口で決める。
- Off モードでも UI 都合で voice input engine が init されることがある。これは許容された設計であり、動作モードの有効化とは区別する。

## InputPanelController 分割

- `InputPanelController` は UI 制御の中心で、置換やスクリプト実行の詳細は service に分離されている。
- 音声入力 engine の delegate と認識 callback の処理は `VoiceInputCoordinator` が所有し、engine の生成・再生成時に Coordinator へ直接接続する。`InputPanelController` は delegate callback を forwarding しない。
- Controller に機能を戻すと、volatile text、履歴、focus、スクリプト実行の責務が再び絡まりやすい。新しい振る舞いは既存 service の責務に沿って置く。
