# Koecho（こえこ）

macOS 向けの音声入力+キーボード入力アプリ。
ホットキーで呼び出し、入力したテキストをシェルスクリプトで加工してペーストする。

<img src="derived/screenshot.png" alt="Koecho のフローティングウィンドウ" width="600">

## 特徴

- 音声入力+キーボード: 音声で入力しながらキーボードで修正できる。認識結果はリアルタイムに反映
- オンデバイス音声認識: 句読点や改行も音声で入力できる
- 内蔵テキスト操作: 外部スクリプトを設定せずに、選択行のインデント増減や引用化ができる
- スクリプト連携: 入力テキストをシェルスクリプトで加工。Apple Foundation Models を使う音声書き起こし整形の例も利用できる

## 動作環境

- macOS 27.0 以上

## インストール

### GitHub Release から

1. [Releases](https://github.com/ryotapoi/Koecho/releases) から最新の zip をダウンロード
2. 解凍して `Koecho.app` を `/Applications` に移動
3. `Koecho.app` を起動。Release 成果物は Apple Developer ID で署名され、Apple の公証を取得済みです。

### ソースからビルド

```bash
git clone https://github.com/ryotapoi/Koecho.git
cd Koecho
open Koecho.xcodeproj
```

Xcode でビルドしてください。

## 必要な権限

初回起動時にシステムから権限の許可を求められます。

- **アクセシビリティ** — テキストのペースト、フォアグラウンドアプリの選択テキスト取得に必要
- **Input Monitoring** — グローバルホットキーの検知に必要
- **マイク** — オンデバイス音声認識に必要

## 使い方

### 基本フロー

1. ホットキー（デフォルト: Fn キー）でフローティングウィンドウを表示
2. 音声またはキーボードでテキストを入力
3. 必要に応じてスクリプトを実行（テキストがその場で置き換わる）
4. ホットキー再押下で確定 → フォアグラウンドアプリにペースト
5. Escape でキャンセル

### スクリプト連携

入出力・環境変数・中断の契約は[外部スクリプトとの契約](docs/script-interface.md)を参照してください。

設定画面でシェルスクリプトを登録できます。スクリプトは `/bin/sh -c` で実行され、stdin にテキスト全文を受け取り、stdout に加工結果を返します。

手動実行時は、環境変数でコンテキスト情報も渡されます:

| 環境変数 | 内容 |
|---------|------|
| `KOECHO_SELECTION` | 実行時の入力パネル内の選択テキスト（未選択時は空文字列） |
| `KOECHO_PROMPT` | スクリプト実行時の追加入力 |
| `KOECHO_SELECTION_START` | パネル本文先頭を 0 とする UTF-16 code unit 単位の選択開始位置 |
| `KOECHO_SELECTION_END` | 同じ本文の UTF-16 code unit 単位の選択終了位置（exclusive: 終端を含まない） |

未選択時の START と END は、ともにキャレット位置になります。外部アプリの選択を取得できた場合、そのテキストはパネル本文に取り込まれ、キャレットは末尾に置かれます。そのままスクリプトを実行すると `KOECHO_SELECTION` は空文字列です。選択テキストとして渡すには、パネル内で選択し直してください。

たとえば `😀abc` の `b` を選択すると、`KOECHO_SELECTION=b`、START=3、END=4 になります。`😀` が UTF-16 code unit 2個分だからです。Python `str` の添字は Unicode code point 単位なので、このオフセットをそのまま slice に使えません。

確定時の自動実行（auto-run）では、選択に関する3変数はすべて空文字列です。

動作確認には `examples/echo-env.sh` を使ってください。登録して実行すると、stdin の内容と環境変数の値が表示されます。

### Apple Foundation Models による音声認識テキストの校正

`examples/fm-textfmt.sh` は、macOS 27 の `/usr/bin/fm` で音声認識の誤変換を校正するサンプルスクリプトです。stdin からテキストを読み、校正した本文を stdout に返します。

```bash
printf '%s\n' '来週の会議は木用日です。' | examples/fm-textfmt.sh
```

校正指示は `examples/fm-textfmt-prompt.md` で編集できます。出力形式は `examples/fm-textfmt.schema.json` で定義しています。初回のライセンス手順はスクリプト冒頭のコメントを参照してください。

## ライセンス

[MIT License](LICENSE)
