---
regen: compiled
sources:
  - Koecho/InputPanelController.swift
  - Koecho/ScriptExecutionService.swift
  - Koecho/ReplacementService.swift
  - Koecho/InputPanelScriptStrip.swift
  - Koecho/PromptInputView.swift
  - Koecho/ScriptManagementView.swift
  - Koecho/ReplacementRuleManagementView.swift
  - Packages/KoechoKit/Sources/KoechoCore/Script.swift
  - Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift
  - Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift
  - Packages/KoechoKit/Sources/KoechoCore/ReplacementRule.swift
  - Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift
  - Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift
  - Packages/KoechoKit/Sources/KoechoCore/HistoryEntry.swift
  - Packages/KoechoKit/Sources/KoechoCore/HistorySettings.swift
  - docs/decisions/0003-manual-trigger-for-replacement-rules.md
  - docs/decisions/0004-history-storage-as-json-file.md
  - docs/decisions/0006-script-path-as-shell-command-string.md
  - docs/decisions/0017-split-inputpanelcontroller-into-services.md
  - docs/decisions/0020-multiple-patterns-per-replacement-rule.md
---

# Scripts / Replacements / History

## 実行フロー

- 手動スクリプトは `ScriptExecutionService.execute(_:)` が入口。prompt が必要な script は一度 `appState.promptScript` を立て、次回実行で `KOECHO_PROMPT` を渡す。
- auto-run は `InputPanelController.confirm()` の中で、置換ルール適用・trim 後、paste 前に `applyAutoRunScript(to:)` から `ScriptExecutionService.runAutoScript` を呼ぶ。
- `Script` は custom と builtin を kind / feature ID で保存する。builtin は command/name を保存値として使わず、indent feature は 2 / 4 spaces を保存する。`ScriptSettings` は専用 flag により default builtin を一度だけ既存 scripts の後ろへ追加するため、削除後に復元しない。builtin は prompt 不可かつ auto-run 候補外。実行時は `ScriptExecutionService` が builtin を `BuiltinTextOperation` へ dispatch し、volatile を確定してから UTF-16 の全文・selection を変換する。builtin は `ScriptRunner` を通らず、App target が suppression 下で text view / AppState / voice insertion point を同じ結果へ同期する。
- `ScriptRunner` は Core にあり、`/bin/sh -c`、stdin、stdout/stderr、timeout、`KOECHO_*` env を扱う。TCC と cwd の罠は [macOS / AppKit](macos-appkit.md)。
- script 失敗時、手動実行は元テキストに戻して errorMessage を出す。auto-run は panel を閉じず、trim 済み置換後テキストへ fallback する。

## 置換ルール

- `ReplacementRule` は Core の pure logic。plain text mode は複数 `patterns` を持ち、regex mode は single `pattern` を使う。保存形式の decode は `patterns` のみを受け付け、旧 `pattern` 単数形式は移行しない。
- `applyReplacementRules` は確定時や手動適用で使う。`findReplacementMatches` は preview overlay 用で、元テキスト座標へ range を戻す。
- `ReplacementService.applyOrPreview()` は panel 表示中・script 非実行中だけ動く。marked text 中は preview、通常時は apply、volatile range 中は preview clear。
- voice insertion point は `VoiceInputCoordinator` が所有するため、置換後は `ReplacementService.applyNow()` が replacement delta を反映して移動させる。

## 履歴

- `HistoryStore` は paste 成功後に `InputPanelController.pasteAndRecord(_:)` から `add(text:settings:)` される。
- 履歴本体は Application Support の `history.json`。保存理由は docs/decisions/0004-history-storage-as-json-file.md。
- history settings は UserDefaults、履歴データは JSON file。設定リセットと履歴削除は別物。
- `HistoryView` と menu の "Copy Last History" は `HistoryStore` 経由で pasteboard にコピーする。

## 変更時の注意

- script / replacement / history は `InputPanelController.confirm()` の順序に直結する。confirm 順序を変えるなら `InputPanelControllerConfirmTests` と service tests を見る。
- prompt の volatile text は `appState.volatilePromptText` として分かれている。本文側 volatile text とは別系統なので [音声入力テキストライフサイクル](voice-input-text-lifecycle.md) を併読する。
- replacement data model を変える場合は `ReplacementRule` の Codable 契約（`patterns` のみ）と docs/decisions/0020-multiple-patterns-per-replacement-rule.md を確認する。
