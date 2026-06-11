# Backlog

## v1.4.2（バグ修正）

- [ ] 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新する（再挑戦）
  - 現状: Settings で言語をダウンロード/リリースしても、Settings ウィンドウを閉じるまでメニューバーの Recognition Language サブメニューに反映されない
  - 方針案: NotificationCenter か AppState にプロパティを追加し、LanguageManagementSheet のダウンロード完了を KoechoApp に通知する
  - 以前の挑戦（Opus）では解決できなかった。なぜ前回の方法で更新されなかったかの原因調査から再着手する

## v1.6 以降

- [ ] ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー decode フォールバック）を撤去する
  - v1.4.0 で patterns 複数化と同時に導入。v1.3.0 以前からの直接更新で置換ルールが decode 失敗→全損するのを防ぐための移行コード
  - 2026-06-11 ユーザー判断: v1.4.x / v1.5.x の移行期間を確保し、v1.6 以降で撤去する
