# Koecho 実画面検証の機能導線

ここは実画面で辿る導線の draft。画面の見え方、権限ダイアログ、操作対象は毎回 live state で確認する。Bundle ID の変更だけで CUA の対象が解決すると仮定しない。

| 機能 | ファイル | 主な観測点 |
| --- | --- | --- |
| Custom Script の手動実行 | [custom-script.md](custom-script.md) | `original` → `ORIGINAL`、任意で `Undo Script` |
| 入力パネルのキャンセル | [panel-cancel.md](panel-cancel.md) | TextEdit の編集欄にフォーカスを置いて開き、`Escape` 後の本文不変と再表示時のリセットを別に確認 |
| 音声入力 | [voice-input.md](voice-input.md) | 音声設定、権限、パネルへの転記 |
| ホットキーとペースト | [hotkey-paste.md](hotkey-paste.md) | パネル表示、確定、対象アプリへの貼り付け |

表の項目は個別の機能確認であり、順に操作しただけで一連の操作全体の検証済みとはしない。スクリプト変換の成功と、Escape で貼り付けないことは別の結果として記録する。

検証専用アプリは `com.ryotapoi.Koecho.Verification` / 表示名 `Koecho Verification`。実行済み bundle の固定パスは `tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app`。補助 script `../scripts/session.py` は `plan`、`prepare`、`adopt`、`doctor`、`cleanup` を提供し、`prepare` → `build_launch.py build` → `build_launch.py launch` → `doctor`（launch が adopt） → `cleanup` の順に使う。証拠は `tmp/verification/verify-koecho/<run>`、作業用 scratch は `tmp/verify-koecho` に置く。

CUA は対象アプリの絶対パスで `await cua.getApp("/Users/ryota/Sources/ryotapoi/Koecho/tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app")` を最初の呼び出しとする。その後の API と操作対象は返された documentation と live state で判断する。Finder や desktop の取得はこの導線に含めない。初回の Accessibility、Input Monitoring、Microphone 権限と、再ビルド・再起動後も許可が維持されるかを記録する。

変更条件ごとの必須 build / test / 実行確認は [検証の正本](../../../../docs/rules/verification.md) に従う。この機能導線は必須 gate の代替ではない。

起動前に [SKILL.md](../SKILL.md) の隔離制約を読む。履歴は通常版と共有され、起動時の purge は履歴 off でも動く。入力パネルで確定する前に Settings → General の `Enable History` を off にし、実画面で確認する。メニューバー名は Koecho のままで、表示名変更のみで操作対象を識別できるとは限らない。共有履歴が存在する場合、専用 macOS ユーザーか本人の了解なしには起動しない。2026-10-06 の専用署名 build・起動・doctor・PID 限定ログは実測済み。CUA は timeoutReached で blocked。実画面は本人の操作結果も含め、run ごとに確認した機能だけ記録する。署名・プロセスの成功から4機能の成功を推測しない。証拠は `tmp/verification/mcp-migration-20261006/` と `tmp/verification/verify-koecho/migration-ui-first/`。

固定 Bundle ID は複数 worktree の検証版で共有する。scratch の owner marker を守り、同時に操作しない。通常版との hotkey 競合がある状態で確定・ペーストを試さない。実行した機能、本人報告、再許可の有無、未確認範囲を evidence に保存し、scratch 削除後も残す。
