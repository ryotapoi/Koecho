# ホットキーとペースト

## Sub-features

- `Shortcuts` の `Hotkey` で `Modifier Key` と `Tap Mode` を確認する。
- グローバルホットキーで入力パネルを開き、再操作で確定する。
- 対象アプリへのペーストと元のクリップボードの復元を確認する。

## How to get to it (user POV)

1. メニューバーの `Settings...` → `Shortcuts` → `Hotkey` で `Modifier Key` と `Tap Mode` を確認し、今回使う操作を記録する。
2. 貼り付け先アプリの編集欄を選び、既存本文とクリップボードの内容を記録する。
3. 設定したグローバルホットキーで入力パネルを開き、`paste check` と入力する。
4. 同じホットキーの確定操作、またはパネルの `Confirm` を使う。貼り付け先に `paste check` が入り、パネルが閉じることを確認する。
5. クリップボードの元の内容が復元されたことを確認する。

## Driving it with CUA・本人操作

- CUA は [README](README.md) の絶対パスによる `getApp` で開始する。設定表示、貼り付け先アプリ、パネルを live state で識別する。ホットキー送信の API は返された documentation に従う。
- Accessibility / Input Monitoring の初回許可が必要なら本人が操作する。再ビルド・再起動後に許可が維持されるかを確認する。
- 確定前のパネル、貼り付け先、クリップボードの前後結果を `.tmp/verification/verify-koecho/<run>` に記録する。Finder / desktop は取得しない。

## Gotchas

- 実装の入口: `Koecho/HotkeySettingsView.swift`、`InputPanelController.swift`、`Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift`、`ClipboardPaster.swift`。

- `Tap Mode` が一回のトグルと二回押し表示のどちらかで、開き方・確定の仕方が変わる。表示中の `Close Input Panel` も確定操作になる。
- `Confirm` は `⌘ Return` のショートカットを持つ。ボタンの表示上の修飾キー印は現在のホットキー設定に従う。
- ペースト先はパネル表示前に前面だったアプリ。Settings や権限画面が割り込んだ後は、対象アプリを前面にしてから新しいセッションを始める。
- 権限、global hotkey、ペーストの必須 gate は[検証の正本](../../../../docs/verification.md)を参照。
