# Backlog

- [ ] T7: 音声認識言語の簡易切り替え（SpeechAnalyzer モード）
- [ ] モデルダウンロード中の UX 改善（SpeechAnalyzer）
- [x] アイコン変更
- [ ] テスト失敗の調査（`test_macos -only-testing:KoechoTests` が既存のまま失敗）
- [x] B1: 初回パネル表示時の Dictation 自動開始失敗（改善済み、完全解消困難。ADR 0005）

## 詳細

### T7: 音声認識言語の簡易切り替え
- 現状より簡単に音声認識言語を切り替えられる仕組み
- mid-session での言語変更（transcriber 入れ替え）

### モデルダウンロード中の UX 改善
- パネル表示のたびに AssetInventory チェックが走り "Downloading speech model..." が毎回表示される
- アプリ起動後1回で十分なはず（2回目以降はスキップ可能）
- ダウンロード中はテキスト入力できないのに、カーソルが表示されて入力できそうに見える
  - ダウンロード中は入力不可な見た目にする
