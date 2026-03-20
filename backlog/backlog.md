# Backlog

## v1.2 — リファクタリング + UI 改善

### 1. Swift Concurrency 移行
- [x] DispatchQueue.main.async → Task { @MainActor in } に移行（KoechoApp, InputPanelController, HistoryView）
- [x] DictationEngine の DispatchWorkItem → Task.sleep(for:) + cancellation に移行

### 2. View 構造の整理
- [x] View body 内の computed property を別 View struct に抽出（InputPanelContent, GeneralSettingsView）
- [x] 1ファイル複数型の分割（GeneralSettingsView.swift, KoechoApp.swift, HotkeySettingsView.swift）

### 3. データフロー改善
- [x] Binding(get:set:) を削減 — 見送り: 4箇所すべて代替策が複雑度を増すため現状が最適
- [x] showsIndicators: false → .scrollIndicators(.hidden)
- [x] localizedCaseInsensitiveContains → localizedStandardContains
- [x] replacingOccurrences(of:with:) → replacing(_:with:)
- [x] GeometryReader → containerRelativeFrame — 見送り: macOS 15+ API でデプロイメントターゲット（14.0+）と不整合

### 4. アクセシビリティ改善
- [x] HistoryRow の onTapGesture → Button に変更
- [x] アイコンのみボタンにテキストラベル追加（ScriptManagementView, ReplacementRuleManagementView, PromptInputView）

### 5. InputPanelController の責務分割
- [x] init の巨大コールバック配線を整理

### 6. UI 改善（History）
- [x] Show Full Text popover のサイズを大きくする（現状スクロールしないと全文が見えない）

### 7. UI 改善（InputPanel）
- [ ] スクリプトボタンと Replace ボタンを統合ツールバーにまとめる
- [ ] ボタンサイズの統一（名前の長さで幅がガタつく問題の解消）
- [ ] 情報の階層を整理（テキストエリア主役、コントロール群はコンパクトに）
- [ ] On confirm 行の扱い再検討（常時表示の必要性）
- [ ] 余白・spacing のリズム改善

## Later

- [ ] 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新

---

## 詳細

### 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新
- 現状: Settings で言語をダウンロード/リリースした後、Settings ウィンドウを閉じないとメニューバーの Recognition Language サブメニューに反映されない
- 理想: Settings 内でダウンロード完了した時点で即反映
- 方針: NotificationCenter か AppState にプロパティを追加し、LanguageManagementSheet のダウンロード完了を KoechoApp に通知する
