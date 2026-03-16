---
name: review-plan-koecho
description: Koecho 固有の設計制約に基づくプランレビュー。通常はチェーンスキルから呼ばれる。
argument-hint: <plan-file-path>
allowed-tools: Read, Glob, Grep, Task
context: fork
---

# Self Plan Review — Koecho Project

グローバルの `/review-plan` + `/review-plan-swift` の後に追加実行する Koecho プロジェクト固有のプランレビュー。
1つの Plan サブエージェントで実行する。

**重要な制約:**
- 使用できるツール: Read, Glob, Grep, Task **のみ**
- レビューは Task ツール（subagent_type: Plan）で実行する。自分で直接レビューしない
- **結果はファイルに書き出さない。テキストとして返すだけにすること。/tmp やプロジェクト配下へのファイル作成は行わない**

## 手順

### 1. プランファイルのパスを決定する

- `$ARGUMENTS` が空でなければ、その値をプランファイルパス `PLAN_PATH` とする
- `$ARGUMENTS` が空なら:
  1. Glob で `tmp/plans/*.md` を検索する
  2. 最も新しいファイル（Glob 結果の先頭）を `PLAN_PATH` とする
  3. ファイルが見つからなければ「tmp/plans/ にプランファイルが見つかりません」と返して終了する

### 2. プランファイルを読む

- Read で `PLAN_PATH` を読み込む
- プラン内で参照されているファイル（仕様書・対象コード）のパスを抽出する

### 3. Plan サブエージェントを起動する

Task ツールで `subagent_type: Plan, model: "sonnet"` を使う。

エージェントには以下を渡す:
- プランの全文
- 参照ファイルのパス一覧
- 「コードや仕様書は自分で Read/Grep/Glob して確認すること」という指示

#### Agent 1: Koecho 固有の設計制約チェック

プロンプト:

```
あなたはコードレビュアーです。以下の実装計画を「Koecho プロジェクト固有の設計制約」と照合し、違反がないか検証してください。

## 実装計画
{PLAN_CONTENT}

## 検証手順
1. プラン内で参照されている対象コードを Read で読む
2. 以下の設計制約リストとプランを照合する
3. 違反があれば指摘する

## Koecho 設計制約

以下はこのプロジェクトで繰り返し発見された設計上の落とし穴です。プランがこれらに抵触していないか検証してください。

1. **volatile テキストと他機能の整合性を確認する**: volatile テキストが textView.string に実挿入される設計のため、スクリプト実行・置換ルールプレビュー・UI 表示で NSRange 座標不整合が起きやすい。volatile 中の操作は finalizedString ベースか textView.string ベースかを明確にすること
2. **プログラム由来のテキスト変更では `isSuppressingCallbacks` で囲む**: textStorage 直接編集や setString() でも didChangeText → onTextChanged/onTextCommitted が発火する。意図しない状態変更を防ぐため isSuppressingCallbacks ガードが必要
3. **UserDefaults の nil 永続化パターンを既存方式に統一する**: `removeObject` 方式と `Data()` センチネル方式が混在すると事故りやすい。同種データは既存パターン（`Data()` センチネル）に合わせること
4. **ADR・設計文書との整合性を維持する**: 新機能で既存 ADR を置き換える場合、supersede の明記・Status 更新・scope.md やスクリプト例コメントの更新を忘れないこと
5. **テスト計画が実設計パターンと合っているか確認する**: Mock/Fake の前提が実装と乖離していないか、テスト対象スコープ（KoechoTests だけでなく KoechoPlatformTests, KoechoCoreTests も）が網羅されているか
6. **stopDictation() のテキストクリアと後続処理の干渉を考慮する**: stopDictation() はリーク防止のため textView をクリアする。auto-run 等で後続処理がある場合、テキスト復元が必要
7. **SPM モジュール分離時の import / dependency / public 漏れ**: ファイル移動時に import 追加（`import Observation` 等）、Package.swift の dependency 追加、型の `public` 化を全件確認すること
8. **プラン内のファイルパスと検証コマンドのスコープを正確にする**: ファイルパスはリポジトリルートからの正確なパスを使う。検証コマンド（test_macos 等）が全パッケージテストをカバーしているか確認する
9. **モジュール配置は依存方向 `Koecho → KoechoPlatform → KoechoCore` に従う**: 新しいコードの配置先が rules/architecture.md の責務定義と合っているか。定義された方向に違反する依存がないか
10. **共通化は依存方向に沿って配置する**: KoechoPlatform と Koecho (App) 間で共有するコードは KoechoCore に置く。片方だけ変更したくなったとき分離できるか検討されているか
11. **リファクタリングと機能実装を同一ステップに混ぜない**: 既存コードの構造改善が必要なら、機能実装の前ステップとして分離されているか

上記に該当しないが Koecho 固有の設計判断に関わる問題も自由に指摘してよい。

## 出力形式
- 日本語で出力
- 指摘事項は箇条書きで、該当するコード・計画の箇所を引用する
- 指摘ごとに重要度を付ける: 🔴 MUST / 🟡 SHOULD / 🔵 NIT
- 問題がなければ「Koecho 固有の指摘なし」と記載する
```

### 4. 結果を出力する

エージェントの結果を以下の形式でユーザーに表示する:

```
## 自己レビュー結果（Koecho 固有）

### Koecho 設計制約チェック
{Agent 1 の結果}
```

スキル側ではプランの修正は行わない（呼び出し元に判断を委ねる）。

### 差分チェック（2回目以降の実行時）

このスキルがループ内で繰り返し呼ばれる場合、エージェントに以下の追加指示を含めること:

```
## 差分チェック指示
プランの記述に「対処済み」「明記済み」「トレードオフとして認識」等と読み取れる内容がある場合、その論点を再度指摘しないこと。
報告するのは **新規の指摘のみ**。既出の論点の言い換え・補足・「もっと明示的に書け」は NIT としても報告しない。
```
