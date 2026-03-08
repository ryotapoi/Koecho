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
- ライブ診断: `XcodeRefreshCodeIssuesInFile`
