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

## Worktree Check

Primary working directory が `.claude/worktrees/` 配下のときだけ:

- 環境変数や git status から実際の作業先（CWD）を確認する
- Primary working directory と CWD が一致していなければ、作業を中断してユーザーに「Primary working directory と CWD が乖離しています（primary: <パス>, cwd: <パス>）。`claude -w` で再起動してください」と報告する
- チェック結果をユーザーに出力する: 「primary_working_directory: <パス>, cwd: <パス>, check: ok/ng/skip」

## Koecho Verification

- ビルド: `build_macos`（XcodeBuildMCP）
- テスト（アプリ）: `test_macos`（`-only-testing:KoechoTests` で UITests を除外）
- テスト（KoechoKit）: `swift test --package-path Packages/KoechoKit`
- Preview 確認: Apple Xcode MCP の `RenderPreview`（使い方は `rules/xcode-mcp.md`）。View 層に変更がある場合は、表示に影響しない変更でも該当 View の `#Preview` をレンダリングして確認する。確認観点: レイアウト崩れ（テキスト切れ・要素の重なり・意図しない余白）、状態バリエーションの網羅（空状態・通常・エッジケース）、フレームサイズの適切さ
- アプリ起動確認: 新しい操作フローや UI 挙動は `build_run_macos` で起動して確認する。ユーザーの観察・操作なしに確定できない場合（権限ダイアログ、実際のディクテーション操作等）は、起動した状態でユーザーに動作確認を依頼するか、残存リスクとして報告する

## Acceptance

- 実行した検証と結果を説明できる
- 追加・更新した unit test / regression test、または追加しなかった理由を説明できる
- 検証しなかった項目がある場合、その理由が説明できる
- ユーザー確認が必要な場合は通過している

## Stop Conditions

- 必須の検証が環境要因で実行できない
- UI / 挙動確認が必要だがユーザー確認が未完了
- 検証結果が要求または仕様と矛盾する
