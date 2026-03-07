# Backlog

- [ ] T7: メニューバーから音声認識言語を切り替え（SpeechAnalyzer モード）
- [ ] B2: Release Download Model 後に言語一覧のステータスが更新されない
- [ ] A1: View からロジック抽出 + Client Protocol 導入 → [Phase 1](architecture-improvement.md#phase-1-view-からロジック抽出--client-protocol-導入)
- [ ] A2: InputPanelController 分割 → [Phase 2](architecture-improvement.md#phase-2-inputpanelcontroller-分割)
- [ ] A3: Settings 分割 → [Phase 3](architecture-improvement.md#phase-3-settings-分割)
- [ ] A4: SPM モジュール分離 → [Phase 4](architecture-improvement.md#phase-4-spm-モジュール分離)

## 詳細

### T7: メニューバーから音声認識言語を切り替え
- メニューバーアイコンから SpeechAnalyzer の認識言語を簡易に切り替えられる
- mid-session での言語変更（transcriber 入れ替え）

### B2: Release Download Model 後に言語一覧のステータスが更新されない
- 再現手順: 設定画面で Italian を選択 → Release Download Model を押す → Japanese を選択する → その後、言語一覧を見ても Italian に「Download required」が表示されない
- アプリ再起動後も表示は変わらない。実際にはモデルが解放されていない、またはステータス表示が更新されていない可能性がある
