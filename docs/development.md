# 開発時の規則

## 実装

- SwiftUI View 層を変更するときは `swiftui-specialist` を使う。
- SwiftUI の View、状態を持つ Model、処理を担う Service に責務を分ける。UI 状態の安全性が必要な箇所は `@MainActor` を使い、非同期処理は async/await を基本とする。
- 設定は UserDefaults に保存し、SwiftData へ置き換えない。新しい設定を追加するときは、該当する `*Settings` の読み込み・保存・既定値・不正値の扱い、Settings 画面、実行時の反映箇所を一続きで確認する。nil と未設定の区別には、既存の各設定が採る保存形式を確認し、`Data()` sentinel と `removeObject` を不用意に混在させない。
- 設定を追加・変更した場合は、既定値、保存後の再読み込み、破損値、nil の扱いを該当する Settings のテストで確認する。
- ログには `os.Logger` を使い、用途別のエラーは適切な enum で表す。音声認識本文の診断ログへの出力禁止は [要件](requirements.md) に従う。

## High-risk として扱う変更

次の変更では [verification.md](verification.md) の必須 gate を確認する。

- ディクテーション制御・テキストコミットの lifecycle、volatile テキスト、`isSuppressingCallbacks`、NSTextView / textStorage の直接操作。
- UserDefaults の永続化パターン変更・設定マイグレーション、権限依存機能（Accessibility / Input Monitoring）、CGEvent ペースト、グローバルホットキー（NSEvent）、外部スクリプト実行（Process + Pipe）、並行性（`@MainActor` 境界、async/await、AVAudioEngine callback）。

## 言語と変更履歴

- コード、コードコメント、コミットメッセージは英語、ドキュメントは日本語で書く。
- コミットの形式は共通の `~/.agents/skills/commit/commit.md` に従う（Conventional Commits）。
- コミットでは hook を `--no-verify` でスキップしない。明示指示なしに force push しない。

変更に応じた必須の確認は [verification.md](verification.md)、Xcode の実行手順は [xcode.md](xcode.md) に従う。
