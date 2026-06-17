# Implement Workflow

## ICAR

- **Intent**: 承認済み plan、または plan を省略できる軽微な変更の明確な要求を、既存設計と情報源に整合する形で実装する。
- **Constraints**:
  - 既存の局所パターンに従う。変える場合は理由を説明可能にする。
  - 型定義・API・依存方向は実物で確認し、推測しない。
  - 構造の悪さが実装を歪める場合は、同じ変更で直すか、別リファクタ plan に切るかを判断する。
  - ループ内で時刻を扱う場合は各反復で取得する（ループ外で 1 回だけ取得しない）。
- **Acceptance**:
  - 要求された振る舞いが実装されている。
  - 必要な tests / `docs/specs/`（あれば） / `backlog/backlog.md` / `llm-wiki/` の同期が済んでいる。
  - 余計なスコープ拡張がない。
- **Relevant**:
  - 承認済み plan、または Small 変更（`default.md` の Intake 分類）の明確な要求
  - 関連する `docs/rules/`, `docs/specs/`（あれば）, `llm-wiki/`
  - 変更対象と周辺コード

## Flow ICAR

### Code Change

- **Intent**: 要求された変更を、既存設計を壊さない最小十分な差分として実装する。
- **Constraints**:
  - 振る舞い変更や bug fix では、同じ commit に unit test / regression test を追加または更新する。テストできない場合は理由を明記する。
  - TDD でやる場合は `tdd` スキルに従う。Normal / High-risk の振る舞い変更は基本 TDD とし、Small は省略可。
  - SwiftUI View 層を触るなら `swiftui-pro` スキルに従う。
- **Acceptance**:
  - 要求された振る舞いがコード上で実装されている。
  - テスト追加・更新の要否を説明できる。

### Documentation Sync

- **Intent**: 実装差分で古くなる情報源を、同じ commit 内で同期する。
- **Constraints**:
  - 振る舞いが変わるなら `docs/specs/`（あれば）の該当箇所を同期する。
  - 今回の変更で `llm-wiki/` が古くなっていないか確認し、必要なら同じ差分で追従する（commit 待ちにせず、review で差分の一部として見る）。判断基準の正本は `docs/rules/information-management.md` とし、ここでは運用だけを書く。
  - `regen: full` の索引・地図（例: `llm-wiki/index.md`）は、手で本文を辻褄合わせしない。frontmatter `sources:` を読み直し、古くなった節をソースから再生成する。
  - `regen: compiled` の概念・ガイド（例: `llm-wiki/voice-input-text-lifecycle.md`）は、読む順序・経路・注意点が古くなっていないか見て、`sources:` を読み直して該当箇所を再編纂する。
  - `regen: none` の外部知見（例: `llm-wiki/speechanalyzer-external-notes.md`）は手で育ててよい。特定ソースの罠はコードコメントへ、横断的な挙動・設計理解だけを `llm-wiki/` の地図へ分配し、単一の集約ファイルは作らない。仕様や判断を拘束し始めたら docs へ昇格する。
  - backlog に積んでいた項目を実装完了したら `backlog/backlog.md` の該当行を `[x]` 等で更新する。
  - 実装中に見つかった別タスクは、今やる理由がなければ `backlog/backlog.md` に逃がす。
- **Acceptance**:
  - 必要な情報源が現在の差分に追従している。
  - 追従不要と判断した情報源について理由を説明できる。

### Apple Tooling

- **Intent**: Apple platform 依存の実装や確認を、Koecho の標準 tooling に沿って扱う。
- **Constraints**:
  - Xcode のビルド・テストは XcodeBuildMCP を優先する。Bash で `xcodebuild` を直接叩かない（使い分けの詳細は `docs/rules/xcode-mcp.md`）。
  - KoechoKit（KoechoCore / KoechoPlatform）の SPM テストは `swift test --package-path Packages/KoechoKit`。
  - Apple API の仕様確認は Apple Xcode MCP の `DocumentationSearch` を Web 検索より優先する。
- **Acceptance**:
  - 選んだ Apple tooling と代替有無を説明できる。

## Stop Conditions

- plan と実装上の事実が食い違う。
- 実装中に仕様判断が必要になった。
- リファクタなしでは変更が不自然または危険になる。
