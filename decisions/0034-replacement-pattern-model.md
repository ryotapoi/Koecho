---
status: current
---

# 一つの置換ルールに複数の plain text pattern を持たせる

## 判断

plain text の一つの置換ルールは複数の入力 pattern を持てる。適用時は長い pattern を先に並べ、一つの正規表現へまとめて一回の照合で置換する。regex ルールは単一 pattern とする。

編集 UI の pattern 行は `ReplacementRulePattern` の一時的な ID で識別する。永続化形式では行 ID を保存せず、`patterns` キーの文字列配列だけを保存する。読込時に UI 用 ID を作り直し、ルールの等価性にも行 ID を含めない。旧単数 `pattern` キーは decode しない。

## 理由

一つの置換先へ複数の表記揺れを登録する際、ルールを複製せずに管理できる。順番に pattern を適用すると先の置換結果が後の pattern に再一致するため、同じルール内では一回の照合にまとめる。短い pattern が長い pattern の先頭を取らないように、長さ順にする。

UI 行を配列 index で識別すると、途中行の削除で別行の focus や編集状態へ identity が移り得る。文字列自体を ID にすると編集中に変わり、重複入力も識別できない。永続化は文字列だけにして UI identity を分ければ、保存形式を行管理に引きずられない。

## 採らなかった案

- pattern ごとに順次置換する: 同じルール内で置換結果が次の pattern に干渉する。
- UI 行を index または pattern 文字列で識別する: 行の挿入・削除・編集と identity が連動する。
- UI 用 UUID を保存する: 置換契約に不要な表示上の識別子を保存形式へ持ち込む。
- 旧単数 `pattern` キーを読み続ける: 移行期間は終了しており、現在の形式を `patterns` に限定する。
