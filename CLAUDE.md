# CLAUDE.md

## プロジェクト概要

Koecho（こえこ / Ko-echo）はmacOS 14.0+向けの軽量音声入力ラッパーアプリ。
macOS標準のDictation機能を利用し、フローティングウィンドウで音声テキストを受け取り、
シェルスクリプトで加工してフォアグラウンドアプリにペーストする。

読み: こえこ / Ko-echo
由来: Koe（声）+ chotto（ちょっと）。echo（反響）の意味も掛かっている。

## ビルド・テスト

xcodebuild -project Koecho.xcodeproj -scheme Koecho -configuration Debug build   # ビルド
xcodebuild -project Koecho.xcodeproj -scheme Koecho -configuration Debug \
  -only-testing:KoechoTests test                                                  # テスト実行

テストはSwift Testing（@Test マクロ）。テストファイルは KoechoTests/ 配下。

## アーキテクチャ

ユーザー音声 → macOS Dictation → TextEditor (InputPanel)
  → スクリプト実行（その場でテキスト置換、何度でも可）
  → ホットキー再押下で確定 → ClipboardPaster (CGEvent Cmd+V) → フォアグラウンドアプリ

詳細仕様: docs/spec.md

## コード規約

- SwiftUI + Model/Service パターン（AppState が中核状態を保持、ロジックは Services に分離）
- @MainActor でUIスレッド安全性を確保
- async/await ベースの非同期処理
- ロギングは os.Logger（サブシステム: com.ryotapoi.koecho）
- UserDefaults で設定保存（SwiftData 不使用）
- エラーは用途別のカスタム enum
- 後方互換性は維持しない。旧シンボルのリネーム保持・re-export・deprecated コメント・旧フォーマットへのフォールバック分岐は入れない。互換性維持が必要な場合はユーザーが明示する
- 実装完了後のコミットは /commit スキルを使う

## 技術スタック

- Swift / SwiftUI / macOS 14.0+
- NSPanel（フローティングウィンドウ）
- NSEvent（グローバルホットキー）
- Process + Pipe（シェルスクリプト実行）
- CGEvent（ペースト）
- Accessibility API（選択テキスト取得）
- MenuBarExtra（メニューバー常駐）
- UserDefaults（設定保存）
- os.Logger（ロギング）

## 前提条件

- App Sandbox は無効（CGEvent / Process / グローバルホットキー / Accessibility API のため）
- アクセシビリティ権限が必要（ペースト・選択テキスト取得）
- Input Monitoring 権限が必要（NSEvent.addGlobalMonitorForEvents）。macOS バージョンによりアクセシビリティ権限と別途必要になるケースがある
- macOS Dictation がユーザーにより有効化されている必要がある（無効の場合はキーボード入力のみ）
- Mac App Store 配布は対象外

## テスト方針

- ScriptRunner: タイムアウト / 空出力 / 非ゼロ終了のフォールバック
- ClipboardPaster: ペースト後のクリップボード復元
- SelectedTextReader: 権限なし・選択なし時の失敗ハンドリング

## プランレビュー

プランモードで実装計画を書き終えたら、ExitPlanMode の前にレビューループを実行する。
**各ステップは前のステップの完了を待ってから実行すること。同時実行は禁止。**

1. `/self-plan-review` を実行する（5観点並列レビュー）
2. 🔴 MUST / 🟡 SHOULD の指摘をプランに反映する
3. 指摘があった場合 → 手順1に戻る（指摘なしになるまでループ）
4. `/codex-plan-review` を実行する（Codex セカンドオピニオン）
5. 指摘があれば反映し、手順1に戻る
6. 指摘なし → ExitPlanMode する

レビュー結果の処理:
- 解決可能な指摘（🔴 MUST / 🟡 SHOULD）はプランに反映する
- 判断が必要な指摘は AskUserQuestion でユーザーに確認する

## 実装レビュー

実装・テストが完了したら、コミット前にレビューループを実行する。
**各ステップは前のステップの完了を待ってから実行すること。同時実行は禁止。**

0. ビルドとテストを通す（`xcodebuild build` → `xcodebuild test`）。失敗したら修正してから次へ進む
1. `/self-impl-review` を実行する（5観点並列レビュー）
2. 🔴 MUST / 🟡 SHOULD の指摘を実装に反映する
3. 指摘があった場合 → 手順1に戻る（指摘なしになるまでループ）
4. `/codex-impl-review` を実行する（Codex セカンドオピニオン）
5. 指摘があれば反映し、手順1に戻る
6. 指摘なし → `/commit` する

判断が必要な指摘は AskUserQuestion でユーザーに確認する。

## ドキュメント管理

- 同じ情報を複数のドキュメントに書かない。各情報の置き場所は1箇所に限定する
- 新しいスキルやファイルを作成したら、同じステップで settings.json 等への登録も行う

技術的な知見・ハマりどころは以下の基準で振り分ける:

- **CLAUDE.md**: 常に意識すべきルール・制約（毎回読み込まれる）
- **docs/knowledge.md**: 特定の状況で役立つ知見（該当する実装のときに読みに行く）

実装前やバグ調査時は `docs/knowledge.md` を確認すること。

