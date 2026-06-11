# Verify Workflow

## ICAR

- **Intent**: 変更が要求を満たし、既存挙動を壊していないことを、適切な証拠で確認する。
- **Constraints**:
  - 自動検証を優先する。ビルド・テスト・静的チェックで確認できるものは先に通す。
  - テスト可能な振る舞い変更や bug fix に unit test / regression test がない場合、検証未完了として扱う。例外は理由を明記する。
  - UI / 権限依存 / システム連携（ディクテーション、ホットキー、ペースト）/ 外部スクリプト / 時間・非同期の挙動は、まず自力で取れる証拠（ビルド・テスト・アプリ起動・ログ等）で確認する。
  - それでもユーザーの観察・操作なしに確定できない挙動が残るなら、Stop Condition または残存リスクとして報告する。
  - 検証不能な High-risk 変更は完了扱いにしない。
- **Acceptance**:
  - 実行した検証と結果を説明できる。
  - 追加・更新した unit test / regression test、または追加しなかった理由を説明できる。
  - 検証しなかった項目がある場合、その理由が説明できる。
  - ユーザー確認が必要な場合は通過している。
- **Relevant**:
  - 変更差分（`git diff`, `git diff --cached`）
  - plan または要求
  - 関連テスト、ビルド設定、Preview / アプリ起動による確認手段

## Koecho Verification

- ビルド（XcodeBuildMCP）: `build_macos`
- テスト（アプリ、XcodeBuildMCP）: `test_macos`（`-only-testing:KoechoTests` で UITests を除外）
- 実画面確認（XcodeBuildMCP）: `build_run_macos`
- テスト（KoechoKit）: `swift test --package-path Packages/KoechoKit`
- XcodeBuildMCP が使えない場合のビルド: `xcodebuild -project Koecho.xcodeproj -scheme Koecho -configuration Debug build`
- XcodeBuildMCP が使えない場合のテスト: `xcodebuild test -project Koecho.xcodeproj -scheme Koecho -only-testing:KoechoTests`
- Preview 確認: Apple Xcode MCP の `RenderPreview` が使える場合は利用する。使えない場合はビルド、実アプリ起動、スクリーンショット、該当 View の局所確認で代替し、代替したことを報告する。

## User Check

- docs / テストのみ / 内部ロジックのみの変更では不要。
- 権限ダイアログ、実際のディクテーション操作、ユーザー環境のアプリ状態、期待 UI 判断が必要な場合だけ依頼する。

## Stop Conditions

- 必須の検証が環境要因で実行できない。
- UI / 挙動確認が必要だがユーザー確認が未完了。
- 検証結果が要求または仕様と矛盾する。
