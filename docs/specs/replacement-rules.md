# 置換ルール

## 目的

置換ルールは、音声入力や手入力を含む入力パネルのテキストを、ユーザーが定義した表記へ整える機能である。主要機能としての位置付けは[スコープ](../rules/scope.md#置換ルール)を正とし、この文書はその振る舞いを定める。

入力中に結果を見せることと、音声認識が管理する未確定テキストを壊さないことを両立するため、テキストの確定状態に応じて直接置換と preview を使い分ける。この方針の経緯は [ADR 0011](../decisions/0011-debounced-auto-replacement.md) を参照する。手動適用を導入した経緯は [ADR 0003](../decisions/0003-manual-trigger-for-replacement-rules.md) に残る。

## ルールモデルと照合

- 1 つのルールは、置換元と置換先の組である。置換先は空文字列にでき、該当箇所を削除できる。
- 通常の文字列モードでは、1 つの置換先に複数の置換元 pattern を登録できる。空の pattern は照合しない。pattern 中の正規表現メタ文字は文字どおりに扱う。
- 通常の文字列モードでは `Match Whole Word` を選べる。オンの場合は単語全体だけを照合し、オフの場合は単語内の一致も置換する。大文字・小文字を区別しない設定は提供しない。
- 正規表現モードでは先頭の 1 pattern だけを使用し、複数 pattern と `Match Whole Word` は適用しない。置換先では `$1`、`$2` などの capture group を参照できる。無効な正規表現と空の pattern はそのルールを適用せず、入力テキストを保つ。
- 通常の文字列モードの複数 pattern は、長い pattern を先に照合する。これにより、短い pattern が長い pattern の一部を先に消費しない。ルール一覧は登録順に順次適用し、先行するルールの置換結果は後続ルールの入力になる。この複数 pattern の契約と理由は [ADR 0020](../decisions/0020-multiple-patterns-per-replacement-rule.md) を参照する。

## 適用契機

### 自動適用

設定の `Auto-replace` は既定でオンであり、入力パネルが表示中でスクリプト実行中でなければ、通常のテキスト変更および音声認識で確定したテキストに即時適用する。オフにすると、通常の入力や音声認識の確定による、この入力中の自動適用だけを停止する。

### 手動適用

`Auto-replace` がオフでも、置換ルールがある場合は入力パネルの `Replace` ボタンで適用できる。ショートカットも設定でき、既定は Control-R である。ショートカットを無効にした場合は、そのキーを置換ルール用には消費しない。新規ルールの追加も明示操作として、追加直後に適用する。これらの明示操作は自動適用と同じ安全分岐を通る。

### 確定時の適用

Confirm は `Auto-replace` の設定にかかわらず、音声入力を finalize した後に必ず置換ルールを適用する。置換後のテキストは前後の空白・改行を trim し、空になった場合はペーストせずキャンセル相当としてパネルを閉じる。auto-run script を選択している場合も、置換と trim が先に完了したテキストをスクリプトへ渡す。

これは、入力中に直接置換できない状態でも、最終的に貼り付けるテキストへルールを反映するためである。`Auto-replace` が confirm 時の適用を制御しないことは [ADR 0003](../decisions/0003-manual-trigger-for-replacement-rules.md) と [ADR 0011](../decisions/0011-debounced-auto-replacement.md) の implementation sync にも記録されている。

## 入力中の安全分岐と preview

- macOS Dictation の marked text が存在する間は、テキストを直接変更しない。代わりに一致箇所へ下線を描き、ポインタを重ねると置換後の文字列を tooltip で表示する。marked text が確定した後は、通常どおり直接置換する。
- SpeechAnalyzer の volatile（未確定）テキストが存在する間は、置換も preview も行わない。既存の preview があれば消去する。
- preview は表示専用であり、入力テキストを変更しない。Confirm で volatile テキストを finalize した後は、前節の確定時適用により置換される。

この非破壊性は、marked text や volatile text の管理中に入力テキストを変更して認識状態を壊さないためのものである。実装上の安全なテキストライフサイクルは [ADR 0011](../decisions/0011-debounced-auto-replacement.md) を判断根拠とする。
