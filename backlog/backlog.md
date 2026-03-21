# Backlog

## v1.3 — ローカライズ + UI 修正

### 1. ローカライズ・文字列調整
- [x] 日本語ローカライズ
- [x] Settings ウィンドウの最小サイズ制限（Engine「Off」やサイドバーラベルが切れない幅を確保）
- [ ] サイドバー「Replacement Rules」の名前 — ローカライズ後にサイドバー幅を見て短縮要否を判断（目視確認では英語「Replacement Rules」も日本語「置換ルール」も180ptサイドバーに収まる。変更不要の可能性が高い）
- [x] locale 表示ロジックの重複解消（MenuLocaleItem を LocaleItem に統合、refreshMenuLocales() に集約）

### 2. メニューバー ⌘, / ⌘Q ショートカット表示の修正
- [ ] LSUIElement アプリで動作しない ⌘, ⌘Q がグレーアウト表示されている。動作しないなら表示しないのが Mac 慣習

### 3. Settings ウィンドウが最前面に出てこないバグ
- [ ] 設定を開いたとき最前面に出てこないことがある。一度最前面にして閉じてまた開くと最前面になる。条件不明、要調査

## Later

- [ ] 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新

---

## 詳細

### 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新
- 現状: Settings で言語をダウンロード/リリースした後、Settings ウィンドウを閉じないとメニューバーの Recognition Language サブメニューに反映されない
- 理想: Settings 内でダウンロード完了した時点で即反映
- 方針: NotificationCenter か AppState にプロパティを追加し、LanguageManagementSheet のダウンロード完了を KoechoApp に通知する
