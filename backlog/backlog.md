# Backlog

## v1.4.1（メンテナンス）

2026-06-11 のメンテナンス監査（thermo-nuclear-code-quality-review）より。変更容易性・メンテナンス性重視。

- [x] rules/workflow.md の存在しない `/refactor-guard` スキル参照を解消する
  - 2026-06-11 のワークフロー刷新で rules/workflow.md ごと廃止（`.claude/workflow/` へ移行）。先行リファクタ判定は `.claude/workflow/plan.md` の「先行リファクタ判定」（design-decision / module-boundary）に置き換え
- [x] ドキュメントの古い記述を現状に同期する
  - references/knowledge.md「CoreAudio」: `AudioDeviceManager.isAudioInputInUse` static フラグの記述 → 実装は `AudioInputExclusiveAccess` enum に移行済み
  - references/knowledge.md「Swift / @Observable」: scripts の「init 内代入 + didSet { save() }」の記述 → 現在は全 *Settings が backing store + save() パターン
  - rules/principles.md「テスト方針」: 3 クラスのみ記載 → 実態（20+ スイート）に合わせて書き直す
- [x] InputPanelController のテスト専用 forwarding プロパティを撤去する
  - `isLocallyFinalized` / `localFinalizedText` / `replaySuppressionDeadline`（InputPanelController.swift:278-291）はプロダクション未使用で InputPanelControllerTests のみが使用。テストを VoiceInputCoordinator 直アクセスに変えて削除する
- [x] VoiceInputCoordinator の replay 抑制状態（フラグ 6 個の暗黙の組み合わせ）を enum に集約する
  - `isLocallyFinalized` / `localFinalizedText` / `replaySuppressionDeadline` / `transcriberAlreadyRestarted` / `accumulatedFinalizedText` / `isStoppingEngine`。「isLocallyFinalized + deadline nil = restart 進行中」のような暗黙状態を `enum ReplayState`（idle / restartInProgress / suppressing）で型に起こし、不正な組み合わせを排除する
  - 既存テスト（VoiceInputCoordinatorTests + InputPanelControllerTests の Replay セクション）が動作を固定している。着手時に design-decision 推奨
- [x] 言語選択の補正ロジック（同型処理が 3 箇所）を SpeechAnalyzerLocaleManager に一本化する
  - KoechoApp.refreshDownloadedLocales の stale selection correction / SpeechAnalyzerLocaleManager.correctSelection / 同 refreshReservedList 内の補正。canonical メソッドを 1 つにして KoechoApp はそれを呼ぶだけにする
- [x] locale 正規化キーと verifiedLocales キャッシュを SpeechAnalyzerEngine の static から分離する
  - `localeNormalizationKey` は純粋な Locale ユーティリティなのに、KoechoApp / MenuBarContent / LocaleManager が UI 層からエンジン型を参照する結合を生んでいる。正規化キーは独立ユーティリティへ、`verifiedLocales`（global mutable static）は SpeechAnalyzerLocaleManager か専用キャッシュ型へ。配置は module-boundary で判断
- [x] InputPanelController.clearTextView の sync/async 二重実装を統合する
  - InputPanelController.swift:403-427。setString → makeFirstResponder → setSelectedRange → scrollRangeToVisible → startEngine の同一シーケンスが if（即時）/ else（Task で 1 サイクル遅延、textView.window が nil 対策）に重複。共通 helper に畳む
- [x] InputPanelController.confirm()（76 行）をフェーズごとの private メソッドに分割する
  - テキスト確定 / 置換適用 / auto-run script / ペースト / 履歴追加 / エラー復帰が直列に混在し、`guard appState.isInputPanelVisible` の再チェックが 4 回散在。途中キャンセルの扱いを各フェーズの戻り値で明示する
- [ ] レガシー migration コードを撤去する（要ユーザー判断）
  - ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー）と VoiceInputSettings.swift の `isVoiceInputEnabled` → `.off` migration。rules/mission.md の非目標「旧フォーマットへのフォールバック分岐は入れない」と矛盾。移行済みと判断できれば消す、残すなら撤去バージョンをここに明記する
- [x] InputPanelControllerTests（1557 行・92 テスト・14 セクション）を分割する
  - MARK 境界に沿ってファイル分割し、TestContext / makeController helper は共有ファイルへ。Replay / Overlap 系は coordinator 単体テストへの移管も検討（forwarding 撤去タスクと連動）
- [x] voiceInsertionPoint の closure 渡しをやめ、所有者（VoiceInputCoordinator）の名前付きメソッドに集約する
  - ReplacementService が get/set closure、ScriptExecutionService が set closure で書き換えており、挿入位置の不変条件（テキスト長以下等）がどこにも集約されていない。replay 状態 enum 化と同時に着手すると効率的
- [x] MenuBarContent の Settings ウィンドウ前面化ハックを名前付き helper に抽出する
  - MenuBarContent.swift:33-44 の「100ms sleep + `identifier?.rawValue.contains("settings")` + window level 昇降」が View body にインライン。`bringSettingsWindowToFront()` 等に抽出し、knowledge.md「LSUIElement + ウィンドウ前面化」への参照を 1 行付ける

## v1.4.2（バグ修正）

- [ ] 言語ダウンロード時にメニューバーの言語一覧をリアルタイム更新する（再挑戦）
  - 現状: Settings で言語をダウンロード/リリースしても、Settings ウィンドウを閉じるまでメニューバーの Recognition Language サブメニューに反映されない
  - 方針案: NotificationCenter か AppState にプロパティを追加し、LanguageManagementSheet のダウンロード完了を KoechoApp に通知する
  - 以前の挑戦（Opus）では解決できなかった。なぜ前回の方法で更新されなかったかの原因調査から再着手する
