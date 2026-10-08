# Custom Script の手動実行

## Sub-features

- Settings の `Scripts` で `Custom Script` を追加し、`Display Name` と `Script Command` を設定する。
- 音声を off にした入力パネルで本文を入力し、`SCRIPTS` 行のスクリプトボタンで結果をその場に反映する。
- 任意で `Undo Script` により実行直前の本文に戻す。

## How to get to it (user POV)

1. メニューバーの Koecho メニューから `Settings...` を開き、左側の `General` で `Enable voice input` を off にし、実画面で確認する。検証中の履歴を残したくない場合は `Enable History` も off にする。
2. 左側の `Scripts` を開く。リスト下の `Add Script`（+）から `Custom Script` を選ぶ。新しい項目が選択され、右側に編集欄が出る。
3. `Display Name` を `Verification Uppercase`、`Script Command` を `tr a-z A-Z` にする。`Requires Prompt` は off のままにする。編集内容はこの画面で設定される。
4. メニューバーの `Open Input Panel` を選び、本文に `original` と入力する。`SCRIPTS` 行の `Verification Uppercase` ボタンを押し、本文が `ORIGINAL` に置き換わることを確認する。
5. 任意で `Undo Script` を押し、`original` に戻ることを確認する。変換と Undo はそれぞれ結果を記録する。最後は後片付けとして `Escape` でパネルを閉じる。

## Driving it with CUA・本人操作

- CUA の初回呼び出しは [README](README.md) の `getApp` 絶対パス。返された documentation と live state に従い、メニュー、Settings、入力パネルの順に操作する。固定した座標・要素 ID は置かない。
- 初回起動時の Accessibility / Input Monitoring 許可は本人の操作が必要な場合がある。許可後に再ビルド・再起動し、同じ検証アプリの許可が維持されるか確認する。
- パネルの本文、スクリプト実行後、任意の Undo 後の状態を `.tmp/verification/verify-koecho/<run>` に記録する。Finder / desktop は取得しない。

## Gotchas

- 実装の入口: `Koecho/ScriptManagementView.swift`、`ScriptEditView.swift`、`InputPanelScriptStrip.swift`、`ScriptExecutionService.swift`。

- この項目の観測対象はパネル内のスクリプト変換。最後の Escape は後片付けであり、「貼り付けずにキャンセル」の検証として数えない。キャンセルは [panel-cancel](panel-cancel.md) のフォーカス条件と観測点で別に確認する。
- `Add Script` はアイコンのみの表示でもアクセシビリティラベルがある。操作前に live state の名称を確認する。
- `Requires Prompt` が on だと、ボタン押下後に追加の入力欄が開く。この基本導線では off にする。
- 手動スクリプトの Undo は成功直後の一回だけ。本文を編集したり、確定・キャンセルしたりすると失効する。[回帰テスト](../../../../KoechoTests/InputPanelControllerScriptTests.swift)を参照。
- 外部 script の実行を含む変更の必須 gate は[検証の正本](../../../../docs/verification.md)を参照。
