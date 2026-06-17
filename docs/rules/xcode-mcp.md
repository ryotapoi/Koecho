# Xcode 操作: MCP ツール使い分け

ビルド・テスト・ドキュメント検索など Xcode 関連の操作は、2つの MCP サーバーを併用する。Bash で `xcodebuild` を直接叩かない。

## XcodeBuildMCP（優先）

ビルド・テストはすべて XcodeBuildMCP のツールを使う。
構造化レスポンスでエラーがファイル名・行番号付きで返るため、生ログのパースが不要。

- ビルド: `build_macos`
- テスト: `test_macos`（`-only-testing:KoechoTests` で UITests を除外）

## Apple Xcode MCP（補助）

Xcode の内部状態にアクセスする必要があるときに使う（Xcode 起動が必要）。

- Apple ドキュメント検索: `DocumentationSearch`（WebSearch より優先）
- Swift REPL 実行: `ExecuteSnippet`（Bash の `swift` より優先）
- SwiftUI プレビュー: `RenderPreview`
  - `sourceFilePath`: Xcode プロジェクト内の相対パス（例: `Koecho/ReplacementRuleEditView.swift`）
  - `previewDefinitionIndexInFile`: ファイル内の `#Preview` の 0-based index
  - `tabIdentifier`: `XcodeListWindows` で取得
  - SPM モジュールを使うファイルは事前に `BuildProject` が必要
  - 結果の PNG パスを `Read` で表示して確認
- ライブ診断: `XcodeRefreshCodeIssuesInFile`
