# 入力パネルのキャンセル

## Sub-features

- メニューバーの `Open Input Panel` でパネルを開く。
- `Escape` で本文の確定・ペーストをせずパネルを閉じる。
- `Requires Prompt` のスクリプトが選択中なら、最初の `Escape` はプロンプトを閉じる。

## How to get to it (user POV)

1. TextEdit に検証用の新規文書を用意し、比較用の本文（例: `unchanged`）を入力して記録する。音声と履歴は off、プロンプトは非表示にする。この項目ではスクリプトを実行しない。
2. **TextEdit を最前面にし、編集欄をクリックして、文字の選択がない挿入カーソルの状態を確認する。** この状態から Koecho メニューの `Open Input Panel` でパネルを開く。Settings など別のウィンドウにフォーカスを移してから開かない。
3. パネルに `cancel me` と入力して `Escape` を押す。パネルが閉じ、TextEdit の本文が手順1のままで、`cancel me` が貼り付けられていないことを確認する。これを「Escape によるキャンセル」の結果として記録する。
4. 再び TextEdit の編集欄にフォーカスを置き、選択なしの状態からパネルを開く。前回の `cancel me` が残っていないことを確認し、「再表示時の本文リセット」の結果として別に記録する。最後は `Escape` で閉じる。

## Driving it with CUA・本人操作

- CUA は [README](README.md) の絶対パスによる `getApp` で開始し、続きは documentation と live state で決める。貼り付け先の選択と入力欄の確認は、そのアプリを明示的に対象として行う。
- 権限ダイアログが出る場合は本人操作を記録する。初回許可の後、再ビルド・再起動で許可が維持されるかも確認する。
- キャンセル前後のパネルと貼り付け先の状態を `tmp/verification/verify-koecho/<run>` に残す。Finder / desktop は取得しない。
- 本人操作では、パネル表示直前の TextEdit のフォーカス・選択状態と、Escape 後の本文を報告に含める。表示直前のフォーカスが不明なら、この前提は未確認として記録する。

## Gotchas

- 実装の入口: `Koecho/MenuBarContent.swift`、`InputPanelController.swift`、`PanelLifecycleManager.swift`。

- `PanelLifecycleManager.show()` は表示時の最前面アプリを貼り付け先として記録し、選択テキストを初期本文へ取り込む。比較用本文を入力したことだけでは貼り付け先の前提を満たさない。再表示時も選択なしにして、選択テキストの取り込みと前回本文の残留を区別する。
- この結果はスクリプト変換や、確定時のペーストが成功する証拠にはならない。ペーストの成功・OS 権限は [hotkey-paste](hotkey-paste.md) で別に確認する。
- メニューの `Close Input Panel` は表示中のトグルで、本文の確定・ペーストにつながる。キャンセルには `Escape` を使う。
- 本文が空のまま確定した場合もキャンセル扱いになるが、この導線は非空本文で `Escape` の効果を確認する。
- プロンプト表示中の `Escape` はまずプロンプトをキャンセルする。パネル自体のキャンセルは次の `Escape`。
- ウィンドウ lifecycle と操作フローの必須 gate は[検証の正本](../../../../docs/rules/verification.md)を参照。
