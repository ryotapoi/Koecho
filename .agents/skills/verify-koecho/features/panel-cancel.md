# 入力パネルのキャンセル

## Sub-features

- メニューバーの `Open Input Panel` でパネルを開く。
- `Escape` で本文の確定・ペーストをせずパネルを閉じる。
- `Requires Prompt` のスクリプトが選択中なら、最初の `Escape` はプロンプトを閉じる。

## How to get to it (user POV)

1. 貼り付け先アプリの編集欄を表示し、元の本文を記録する。
2. Koecho メニューの `Open Input Panel` を選び、パネルに `cancel me` と入力する。
3. `Escape` を押す。パネルが閉じ、貼り付け先の本文が変わっていないことを確認する。
4. 再度 `Open Input Panel` を選び、前回の `cancel me` が引き継がれていないことを確認する。

## Driving it with CUA・本人操作

- CUA は [README](README.md) の絶対パスによる `getApp` で開始し、続きは documentation と live state で決める。貼り付け先の選択と入力欄の確認は、そのアプリを明示的に対象として行う。
- 権限ダイアログが出る場合は本人操作を記録する。初回許可の後、再ビルド・再起動で許可が維持されるかも確認する。
- キャンセル前後のパネルと貼り付け先の状態を `tmp/verification/verify-koecho/<run>` に残す。Finder / desktop は取得しない。

## Gotchas

- メニューの `Close Input Panel` は表示中のトグルで、本文の確定・ペーストにつながる。キャンセルには `Escape` を使う。
- 本文が空のまま確定した場合もキャンセル扱いになるが、この導線は非空本文で `Escape` の効果を確認する。
- プロンプト表示中の `Escape` はまずプロンプトをキャンセルする。パネル自体のキャンセルは次の `Escape`。
- ウィンドウ lifecycle と操作フローの必須 gate は[検証の正本](../../../../docs/rules/verification.md)を参照。
