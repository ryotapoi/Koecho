# Investigate Workflow

## ICAR

- **Intent**: 計画や実装に入る前に、必要な事実・不明点・判断材料を揃える。
- **Constraints**:
  - 何が分かれば plan / direct implement / stop に進めるかを先に定義する。
  - 机上で分からない挙動はコード読みを続けず、ビルド・テスト・Preview 代替・アプリ起動・公式ドキュメント確認へ切り替える。
  - 複数ファイル横断や広域 grep は subagent に委譲してよい。ファイル 1〜2 個で済むなら main で読む。
  - ユーザーの観察・判断なしに確定できない UI / 挙動は Stop Conditions として報告する。
  - 調査結果が将来も効くなら `references/knowledge.md`、要求や粒度が変わるなら `backlog/backlog.md` に記録する。
  - 調査用の一時コードは、残す理由がなければ最終成果に含めない。
- **Acceptance**:
  - 判明した事実と残った不明点が説明できる。
  - 次に plan / direct implement / stop のどれに進むか判断できる。
  - 永続化が必要な知見・要求変更が適切な場所に記録されている。
- **Relevant**:
  - ユーザー依頼
  - `backlog/backlog.md` の該当項目
  - 関連する `rules/`, `specs/`（あれば）, `decisions/`, `references/knowledge.md`
  - 既存コード、ログ、再現手順

## Use When

- 原因不明のバグ
- 仕様や期待挙動が曖昧
- 技術検証が必要
- UI / 権限 / システム連携（ディクテーション、ホットキー、ペースト）/ 外部スクリプトなど、コードだけでは確定できない挙動がある

## Tooling Notes

- XcodeBuildMCP が使える場合は `build_macos`, `test_macos`, `build_run_macos` を優先する。
- Apple Xcode MCP の `RenderPreview` / `DocumentationSearch` が使えない場合は、ビルド、実行、公式ドキュメント確認など利用可能な手段で代替し、代替したことを報告する。
- KoechoKit の SPM テストは `swift test --package-path Packages/KoechoKit` を使う。

## Stop Conditions

- ユーザーの観察・判断なしに確定できない UI / 挙動がある。
- 調査結果により元の要求やスコープが変わった。
- 検証用の一時変更を残すか戻すか判断が必要。
