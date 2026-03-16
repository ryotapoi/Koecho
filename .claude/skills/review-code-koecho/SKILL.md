---
name: review-code-koecho
description: Koecho 固有の設計制約に基づく実装レビュー。通常はチェーンスキルから呼ばれる。
argument-hint: <plan-file-path>
allowed-tools: Read, Glob, Grep, Bash(git diff *), Bash(git log *), Bash(git status *), Task
context: fork
---

# Self Implementation Review — Koecho Project

グローバルの `/review-code` + `/review-code-swift` の後に追加実行する Koecho プロジェクト固有の実装レビュー。
1つの Plan サブエージェントで実行する。

**重要な制約:**
- 使用できるツール: Read, Glob, Grep, Bash(git diff/log/status), Task **のみ**
- レビューは Task ツール（subagent_type: Plan）で実行する。自分で直接レビューしない
- **結果はファイルに書き出さない。テキストとして返すだけにすること。/tmp やプロジェクト配下へのファイル作成は行わない**

## 手順

### 1. レビュー対象の差分を取得する

- `git diff` と `git diff --cached` で未コミットの変更差分を取得する
- `git status` で変更ファイル一覧を取得する
- 差分がなければ「レビュー対象の変更がありません」と返して終了する
- 変更ファイルに `.swift` ファイルが含まれていなければ「Swift ファイルの変更がないためスキップします」と返して終了する

### 2. Plan サブエージェントを起動する

Task ツールで `subagent_type: Plan, model: "sonnet"` を使う。

エージェントのプロンプトには、手順1で取得済みの以下の値を埋め込む:
- `{GIT_DIFF}`: 手順1で取得した変更差分（git diff + git diff --cached の結合出力）
- `{FILE_LIST}`: 手順1で取得した変更ファイル一覧（git status の出力）

加えて、「変更されたファイルの全文は自分で Read/Grep/Glob して確認すること」という指示を含める。

#### Agent 1: Koecho 固有の設計制約チェック

プロンプト:

```
あなたはコードレビュアーです。以下の実装変更を「Koecho プロジェクト固有の設計制約」と照合し、違反がないか検証してください。

## 変更差分
{GIT_DIFF}

## 変更ファイル一覧
{FILE_LIST}

## 検証手順
1. 変更されたファイルを Read で読み、変更の全体像を把握する
2. 以下の設計制約リストと実装を照合する
3. 違反があれば指摘する

## Koecho 設計制約

以下はこのプロジェクトで繰り返し発見された設計上の落とし穴です。実装がこれらに抵触していないか検証してください。

1. **volatile テキストと他機能の整合性を確認する**: volatile テキストが textView.string に実挿入される設計のため、スクリプト実行・置換ルールプレビュー・UI 表示で NSRange 座標不整合が起きやすい。volatile 中の操作は finalizedString ベースか textView.string ベースかを明確にすること
2. **プログラム由来のテキスト変更では `isSuppressingCallbacks` で囲む**: textStorage 直接編集や setString() でも didChangeText → onTextChanged/onTextCommitted が発火する。意図しない状態変更を防ぐため isSuppressingCallbacks ガードが必要
3. **UserDefaults の nil 永続化パターンを既存方式に統一する**: `removeObject` 方式と `Data()` センチネル方式が混在すると事故りやすい。同種データは既存パターン（`Data()` センチネル）に合わせること
4. **ADR・設計文書との整合性を維持する**: 新機能で既存 ADR を置き換える場合、supersede の明記・Status 更新・scope.md やスクリプト例コメントの更新を忘れないこと
5. **テストが実設計パターンと合っているか確認する**: Mock/Fake の前提が実装と乖離していないか、テスト対象スコープ（KoechoTests だけでなく KoechoPlatformTests, KoechoCoreTests も）が網羅されているか
6. **stopDictation() のテキストクリアと後続処理の干渉を考慮する**: stopDictation() はリーク防止のため textView をクリアする。auto-run 等で後続処理がある場合、テキスト復元が必要
7. **SPM モジュール分離時の import / dependency / public 漏れ**: ファイル移動時に import 追加（`import Observation` 等）、Package.swift の dependency 追加、型の `public` 化を全件確認すること
8. **プラン内のファイルパスと検証コマンドのスコープを正確にする**: ファイルパスはリポジトリルートからの正確なパスを使う。検証コマンド（test_macos 等）が全パッケージテストをカバーしているか確認する

### 実装レビュー追加観点
9. **旧 UserDefaults キーの削除処理を忘れない**: 設定キーをリネーム・統合した場合、Settings.init() / save() に旧キーの removeObject(forKey:) を入れること
10. **startDictation: の冪等性を保つ**: start() は state != .idle のとき no-op にする。listening 中の再呼び出しでトグル停止しないこと
11. **モジュール配置と依存方向の遵守**: 新しい import が `Koecho → KoechoPlatform → KoechoCore` の方向に従っているか。KoechoCore に macOS 固有 API (Carbon, CoreAudio, AppKit 等) の import が漏れていないか（rules/architecture.md 参照）
12. **共通化の妥当性**: KoechoPlatform と Koecho (App) 間で共有するコードが KoechoCore に正しく配置されているか。ローカルなヘルパーが本来 KoechoCore に属する概念を扱っていないか
13. **リファクタリングと機能実装のコミット分離**: diff にリファクタリング（rename、ファイル移動、構造変更）と機能実装（新しいビジネスロジック）が混在していないか

上記に該当しないが Koecho 固有の設計判断に関わる問題も自由に指摘してよい。

## 出力形式
- 日本語で出力
- 指摘事項は箇条書きで、該当するコードの箇所を引用する
- 指摘ごとに重要度を付ける: 🔴 MUST / 🟡 SHOULD / 🔵 NIT
- 問題がなければ「Koecho 固有の指摘なし」と記載する
```

### 3. 結果を出力する

エージェントの結果を以下の形式でユーザーに表示する:

```
## 自己レビュー結果（Koecho 固有）

### Koecho 設計制約チェック
{Agent 1 の結果}
```

スキル側ではコードの修正は行わない（呼び出し元に判断を委ねる）。

### 差分チェック（2回目以降の実行時）

このスキルがループ内で繰り返し呼ばれる場合、エージェントに以下の追加指示を含めること:

```
## 差分チェック指示
実装に「対処済み」「意図的な判断」と読み取れるコード・コメントがある場合、その論点を再度指摘しないこと。
報告するのは **新規の指摘のみ**。既出の論点の言い換え・補足・「もっと明示的に書け」は NIT としても報告しない。
```
