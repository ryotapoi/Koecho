# Principles

## コード規約

- SwiftUI + Model/Service パターン（AppState が中核状態を保持、ロジックは Services に分離）
- @MainActor でUIスレッド安全性を確保
- async/await ベースの非同期処理
- ロギングは os.Logger（サブシステム: com.ryotapoi.koecho）
- UserDefaults で設定保存（SwiftData 不使用）
- エラーは用途別のカスタム enum

## テスト方針

- ScriptRunner: タイムアウト / 空出力 / 非ゼロ終了のフォールバック
- ClipboardPaster: ペースト後のクリップボード復元
- SelectedTextReader: 権限なし・選択なし時の失敗ハンドリング

## 言語

- コミットメッセージは英語（Conventional Commits）
- ドキュメントは日本語の場合がある
- コード（変数名、コメント）は英語で書く
