# Investigate Workflow

## ICAR

- **Intent**: 計画や実装に入る前に、必要な事実・不明点・判断材料を揃える。
- **Constraints**:
  - 何が分かれば plan / direct implement / stop に進めるかを先に定義する。
  - 机上で分からない挙動はコード読みを続けず、計測・確認手段に切り替える。
    <!-- slot: コード確認以外に使いたい確認手段があれば記載する（例: Preview / アプリ起動 / 公式ドキュメント、CLI なら実行して挙動を見る、実機・外部連携はユーザー確認）。 -->
    - UI / Preview / 実アプリ挙動は XcodeBuildMCP の `build_run_macos`、使える場合は Apple Xcode MCP の `RenderPreview` で確認する。
    - Apple API 仕様は Apple Xcode MCP の `DocumentationSearch` を優先し、使えない場合は Apple 公式ドキュメントで確認する。
    - 権限ダイアログ、実際のディクテーション操作、外部アプリ連携などユーザー環境依存の挙動は、自力で取れるビルド・ログ・スクリーンショットを先に集め、確定できない場合だけユーザー確認に回す。
    <!-- /slot -->
  - subagent は、複数ファイル横断・広域 grep・独立した仮説検証を並列化できる場合に使う。
  - 調査中の一時コードは、残す理由がなければ最終成果に含めない。
- **Acceptance**:
  - 判明した事実と残った不明点が説明できる。
  - 次に plan / direct implement / stop のどれに進むか判断できる。
  - 永続化が必要な知見・要求変更が適切な場所に記録されている。
- **Relevant**:
  - ユーザー依頼
  - `backlog/backlog.md` の該当項目
  - 関連する `docs/rules/`, `docs/specs/`, `docs/decisions/`, `llm-wiki/`（作業地図）
  - 既存コード、ログ、再現手順

## Use When

- 原因不明のバグ
- 仕様や期待挙動が曖昧
- 技術検証が必要
- UI / 実機 / 外部 API など、コードだけでは確定できない挙動がある

## Recording

- 調査結果が将来も効くなら、特定ソースに紐づく罠はそのコードのコメントへ、横断的な挙動・設計理解は `llm-wiki/` の該当地図へ残す。
- 要求や粒度が変わるなら `backlog/backlog.md` に残す。
- ユーザーに聞いた方が早い UI / 挙動は遠慮せず確認する。

## Stop Conditions

- ユーザーの観察・判断なしに確定できない UI / 挙動がある。
- 調査結果により、元の要求やスコープが変わった。
- 検証のための一時変更を残すか戻すか判断が必要。
