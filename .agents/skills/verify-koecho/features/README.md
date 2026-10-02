# Koecho 実画面検証の機能導線

ここは実画面で辿る導線の draft。画面の見え方、権限ダイアログ、操作対象は毎回 live state で確認する。Bundle ID の変更だけで CUA の対象が解決すると仮定しない。

| 機能 | ファイル | 主な観測点 |
| --- | --- | --- |
| Custom Script の手動実行 | [custom-script.md](custom-script.md) | `original` → `ORIGINAL`、任意で `Undo Script` |
| 入力パネルのキャンセル | [panel-cancel.md](panel-cancel.md) | `Escape` で閉じ、ペーストしない |
| 音声入力 | [voice-input.md](voice-input.md) | 音声設定、権限、パネルへの転記 |
| ホットキーとペースト | [hotkey-paste.md](hotkey-paste.md) | パネル表示、確定、対象アプリへの貼り付け |

検証専用アプリは `com.ryotapoi.Koecho.Verification` / 表示名 `Koecho Verification`。実行済み bundle の固定パスは `tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app`。補助 script `../scripts/session.py` は `plan`、`prepare`、`adopt`、`doctor`、`cleanup` を提供し、`prepare` → XcodeBuildMCP `build_run_macos` → `adopt` → `doctor` → `cleanup` の順に使う。証拠は `tmp/verification/verify-koecho/<run>`、作業用 scratch は `tmp/verify-koecho` に置く。

CUA は対象アプリの絶対パスで `await cua.getApp("/Users/ryota/Sources/ryotapoi/Koecho/tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app")` を最初の呼び出しとする。その後の API と操作対象は返された documentation と live state で判断する。Finder や desktop の取得はこの導線に含めない。初回の Accessibility、Input Monitoring、Microphone 権限と、再ビルド・再起動後も許可が維持されるかを記録する。

変更条件ごとの必須 build / test / 実行確認は [検証の正本](../../../../docs/rules/verification.md) に従う。この機能導線は必須 gate の代替ではない。

起動前に [SKILL.md](../SKILL.md) の隔離制約を読む。履歴は通常版と共有され、起動時の purge は履歴 off でも動く。入力パネルで確定する前に Settings → General の `Enable History` を off にし、実画面で確認する。メニューバー名は Koecho のままで、表示名変更のみで操作対象を識別できるとは限らない。共有履歴が存在する場合、専用 macOS ユーザーか本人の了解なしには起動しない。起動・doctor・停止は実行済みだが、CUA timeout のため最初の script 実画面導線は blocked、他は draft。証拠は `tmp/verification/verify-koecho/20261002-initial/`。
