# Backlog

## v1.5.0

- [x] AppIcon を変更する
- [x] AppIcon 切り替え機能を追加する
- [ ] アプリデザインをブラッシュアップする

## v1.6 以降

- [ ] ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー decode フォールバック）を撤去する
  - v1.4.0 で patterns 複数化と同時に導入。v1.3.0 以前からの直接更新で置換ルールが decode 失敗→全損するのを防ぐための移行コード
  - 2026-06-11 ユーザー判断: v1.4.x / v1.5.x の移行期間を確保し、v1.6 以降で撤去する
