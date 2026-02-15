# Knowledge Base

このファイルはプロジェクト固有の技術的な知見・ハマりどころを蓄積する場所。

## このファイルの使い方

- **いつ読むか**: 新しい機能の実装前、バグ調査時に関連セクションを確認する
- **何を書くか**: 特定の状況で役立つ知見（罠、回避策、仕様の癖など）
- **CLAUDE.md との違い**: CLAUDE.md は毎回読み込まれる「常に守るルール」。ここは「該当する実装のときだけ必要な知見」
- **書き方**: セクション見出しでテーマ分け。各項目は簡潔に。症状・原因・対処がわかるように書く

---

## macOS / Process

- 子プロセス（Process）に `ProcessInfo.processInfo.environment` をそのまま渡さない。macOS の内部環境変数（`__CF_*` 等）経由で TCC 保護フォルダ（Photos, Music, iCloud）へのアクセスが発生し、許可ダイアログが出る
- `currentDirectoryURL` 未設定だと親の CWD を継承し、TCC 保護パスに当たりうる
- 対策: `PATH` と `HOME` のみ渡す + `currentDirectoryURL` を `FileManager.default.temporaryDirectory` に設定
- Process を使う箇所すべてに適用すること（ScriptRunner 等）
- 子プロセスのアクセスは親プロセス（Koecho）の権限として扱われる
