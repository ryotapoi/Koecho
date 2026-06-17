# Verify

## Intent

変更が要求を満たし、既存挙動を壊していないことを、適切な証拠で確認する。

## Inputs

- 変更差分（`git diff`, `git diff --cached`）
- plan または要求
- 関連テスト、ビルド設定、Preview / アプリ起動による確認手段

## Decision Criteria

- 自動検証を優先する。ビルド・テスト・静的チェックで確認できるものは先に通す
- テスト可能な振る舞い変更や bug fix に unit test / regression test がない場合、検証未完了として扱う。例外は理由を明記する
- UI / 権限依存 / システム連携（ディクテーション、ホットキー、ペースト）/ 外部スクリプト / 時間・非同期の挙動は、まず自力で取れる証拠（ビルド・テスト・`RenderPreview`・ログ等）で確認する
- それでもユーザーの観察・操作なしに確定できない挙動が残るなら、Stop Condition または残存リスクとして報告する
- 検証不能な High-risk 変更は完了扱いにしない

## Koecho Verification

- ビルド: `build_macos`（XcodeBuildMCP）
- テスト（アプリ）: `test_macos`（`-only-testing:KoechoTests` で UITests を除外）
- テスト（KoechoKit）: `swift test --package-path Packages/KoechoKit`
- Preview 確認: Apple Xcode MCP の `RenderPreview`（使い方は `docs/rules/xcode-mcp.md`）
- 実画面確認: `build_run_macos` でアプリを起動する

## Acceptance

- 実行した検証と結果を説明できる
- 追加・更新した unit test / regression test、または追加しなかった理由を説明できる
- 検証しなかった項目がある場合、その理由が説明できる
- ユーザー確認が必要な場合は通過している

## Stop Conditions

- 必須の検証が環境要因で実行できない
- UI / 挙動確認が必要だがユーザー確認が未完了
- 検証結果が要求または仕様と矛盾する
