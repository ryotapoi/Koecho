# 内蔵テキスト操作

## 変換契約

内蔵テキスト操作は、全文、UTF-16 座標の選択範囲、内蔵機能の ID と設定を受け取り、変換後の全文と UTF-16 座標の選択範囲を返す。KoechoCore の変換は Foundation のみへ依存し、AppKit のテキストビューには依存しない。

- `Increase Indent` は対象行の先頭へ設定幅（2 または 4）の spaces を追加する。
- `Decrease Indent` は対象行の先頭から、設定幅を上限に既存の spaces だけを削除する。幅未満なら存在する分だけを削除する。
- `Block Quote` は空行と既存の quote 行を含む各対象行へ、実行ごとに `> ` を追加する。
- 非空選択は交差する各行を対象にする。ただし選択の終端（exclusive）が次行の先頭なら、その次行を含めない。空選択はカーソルのある行を対象にする。
- 変換後の選択範囲は対象行全体であり、最後の行末改行は含めない。よって同じ操作を連続実行できる。
- 文書先頭・末尾、空行、末尾改行、先頭/末尾 spaces、Unicode を含む UTF-16 座標でもこの契約を維持する。

## 実行フロー

内蔵操作は既存のスクリプト実行導線で `Script.kind` により dispatch される。実行前に volatile text を削除せず確定し、その時点の全文と選択範囲を変換する。変換後は App target が callback suppression 下で NSTextView の全文、選択、スクロールを更新し、同じ全文を AppState と音声入力位置へ同期する。

custom script は従来どおり ScriptRunner を通る。内蔵操作は Process/ScriptRunner を通らず、custom script の stdout trim、空出力、失敗時の契約を変更しない。
