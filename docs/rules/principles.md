# Principles

## コード規約

- SwiftUI + Model/Service パターン（AppState が中核状態を保持、ロジックは Services に分離）
- @MainActor でUIスレッド安全性を確保
- async/await ベースの非同期処理
- ロギングは os.Logger（サブシステム: com.ryotapoi.koecho）
- UserDefaults で設定保存（SwiftData 不使用）
- エラーは用途別のカスタム enum

## テスト方針

- Swift Testing（`@Test` / `#expect`）を使用。テストは 3 ターゲットに分かれる
  - `Packages/KoechoKit/Tests/KoechoCoreTests`: 設定（*Settings）・モデル・ルール等の純ロジック
  - `Packages/KoechoKit/Tests/KoechoPlatformTests`: AppState・オーディオ・ペースト・ホットキー・選択テキスト取得等のプラットフォーム層
  - `KoechoTests`（TEST_HOST = Koecho.app）: InputPanelController・VoiceInputCoordinator・VoiceInputTextView 等の UI 近傍
- 外部依存（マイク・権限・子プロセス・クリップボード）は、モック注入（`MockVoiceInputEngine` 等）またはフォールバック挙動の検証で扱う
- テストランナー固有の罠（TEST_HOST のライフサイクル隔離、UserDefaults 分離）は `llm-wiki/testing.md` に従う

## 言語

- コミットメッセージは英語（Conventional Commits）
- ドキュメントは日本語の場合がある
- コード（変数名、コメント）は英語で書く
