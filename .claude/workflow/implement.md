# Implement

## Intent

承認済み plan、または plan を省略できる軽微な変更の明確な要求を、既存設計と情報源に整合する形で実装する。

## Inputs

- 承認済み plan、または Small 変更（`default.md` の Intake 分類）の明確な要求
- 関連する `rules/`, `specs/`（あれば）, `references/knowledge.md`
- 変更対象と周辺コード

## Decision Criteria

- 既存の局所パターンに従う。変える場合は理由を説明可能にする
- 型定義・API・依存方向は実物で確認（推測しない）
- 振る舞い変更や bug fix では、同じ commit に unit test / regression test を追加または更新する。テストできない場合は理由を明記する
- TDD でやる場合は `tdd` スキルに従う（Normal / High-risk の振る舞い変更は基本 TDD。Small は省略可）
- SwiftUI View 層を触るなら `swiftui-pro` スキルに従う
- 振る舞いが変わるなら `specs/`（あれば）の該当箇所を同期する
- backlog に積んでいた項目を実装完了したら `backlog/backlog.md` の該当行を `[x]` 等で更新する
- 実装中に見つかった別タスクは、今やる理由がなければ `backlog/backlog.md` に逃がす
- 構造の悪さが実装を歪める場合は、同じ変更で直すか、別リファクタ plan に切るかを判断する
- ループ内で時刻を扱う場合は各反復で取得する（ループ外で 1 回だけ取得しない）

## Apple Tooling

- Xcode のビルド・テストは XcodeBuildMCP を優先する。Bash で `xcodebuild` を直接叩かない（使い分けの詳細は `rules/xcode-mcp.md`）
- KoechoKit（KoechoCore / KoechoPlatform）の SPM テストは `swift test --package-path Packages/KoechoKit`
- Apple API の仕様確認は Apple Xcode MCP の `DocumentationSearch` を Web 検索より優先する

## Acceptance

- 要求された振る舞いが実装されている
- 必要な `specs/`（あれば） / tests / `backlog/backlog.md` の同期が済んでいる
- 余計なスコープ拡張がない

## Stop Conditions

- plan と実装上の事実が食い違う
- 実装中に仕様判断が必要になった
- リファクタなしでは変更が不自然または危険になる
