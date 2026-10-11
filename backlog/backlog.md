# Backlog

## 運用ルール

- Backlog には、今後着手でき、完了を判定できる作業を `- [ ]` 形式のタスクとして置く。
- 完了したタスクは `- [x]` にし、版を切る変更（バージョンを上げてタグを打つ変更）で消す。取りやめたタスクは消す。
- 対応要否を決める調査もタスクにできる。観察事実だけを残さず、判断したい問いと、判断をもって完了とすることを明示する。
- 粗いメモで起票してよいが、着手前に目的と受け入れ条件を読める粒度へ詰める。
- タスクの行には短い作業名を書き、説明は空行を挟んだ字下げ段落に分ける。
- バージョン番号を付ける場合は SemVer に従う。
- タスクは `###` 見出しでグループに分ける。バージョンが確定したグループだけ、`### v0.1.0 名前` のように見出しへ番号を付ける。
- グループが大きい場合は、`####` 見出しでさらに分割してよい。

## タスク

### v2.0.0 macOS 27 専用化・信頼性改善

- バージョン: v1.8.0 を macOS 14 を対応下限とする最終リリースとし、本グループは macOS 27 以降向けの v2.0.0 とする。

#### macOS 27 専用化

[macOS 27 専用化](v2.0.0-macos27.md)

#### 信頼性改善

[信頼性改善](v2.0.0-reliability.md)

- [x] 音声の off→on で停止中の処理が新セッションを消去しないようにする

  問題: 音声を off にした停止処理の完了前に on へ戻すと、停止中の処理と新エンジンが同じ lifecycle ID を共有する。停止中の処理の復帰後に新セッションの volatile テキストとローカル確定状態が消去される経路がある。実機での発生頻度と恒久的な本文欠落は未確認。対象: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift)、[`InputPanelController.swift`](../Koecho/InputPanelController.swift)。

  完了条件: 音声エンジンの停止中に再有効化し、新セッションが認識結果を受け取った後に先行する停止処理が完了しても、新セッションの本文・状態が保持されることを確認する。

  検証: 旧停止完了後の本文・未確定範囲・ローカル確定状態の保持を回帰テストで確認。通常 build、App tests、専用署名 build は成功。2026-10-11 に本人が専用検証版でショートカットによる連続 off→on を操作し、再有効化後の認識本文の保持と後続入力の反映を確認。実際の OS 停止順序は本人操作から推定せず、回帰テストで検証した。

- [ ] 停止中の音声エンジンの解放で新エンジンのマイク排他を解除しないようにする

  問題: Settings のメーターが要求されている状態で音声を素早く off→on にすると、新エンジンの取得後に停止中のエンジンが共有 Bool を解除し、認識中にメーターの録音を再開できる。実機の発生頻度とハードウェア依存の認識失敗は未確認。対象: [`AudioInputExclusiveAccess.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputExclusiveAccess.swift)、[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)、[`AudioInputLevelMonitor.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputLevelMonitor.swift)。

  完了条件: 新エンジンの取得後に停止中のエンジンを解放しても認識中のメーター取得を抑止し、認識側の取得が終了した時点で要求中のメーターを再開できることを確認する。

- [x] フォーカス復帰テストの NSHostingView 警告を解消する

  対応: [`InputPanelControllerConfirmTests.swift`](../KoechoTests/InputPanelControllerConfirmTests.swift) の `accessibilityFailureRehydratesEditorForImmediateRetryWithoutRestartingVoiceInput()` で、表示前に通常の NSView を共通の親として NSHostingView と focusSink を配置した。貼り付け試行中は view 構成を変更せず、フォーカス移動だけを模擬する。本文・選択・フォーカスの復帰と音声エンジン非再起動の既存検証を維持し、製品コードは変更していない。

  検証: 全 app tests 成功（226 tests / 269 cases、失敗・skip 0）。対象テストの成功と、build.log 全文および runtimeWarnings に該当警告がないことを確認した。証拠: `.tmp/verification/cli/focus-warning-app-tests-20261011-02/`。

#### 機能改善

[機能改善](v2.0.0-features.md)

#### 実行結果のフォローアップ

[実行結果のフォローアップ](v2.0.0-followups.md)

#### 置換 UI の見直し

[置換 UI の見直し](v2.0.0-replacement-ui.md)

#### 不具合修正・検証

[不具合修正・検証](v2.0.0-bugfixes.md)

- [ ] 置換後の音声挿入位置を Unicode 境界に保つ

  問題: Auto-replace off で `ab → 😀` を登録し、`a` と `b` の間から局所置換すると、音声挿入位置が置換後も UTF-16 の位置 1 に残る。次の音声入力が絵文字のサロゲートペア内部を編集する経路がある。実 AppKit の描画・貼り付け結果は未確認。対象: [`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift)、[`ReplacementService.swift`](../Koecho/ReplacementService.swift)。

  完了条件: 局所置換と全文置換の挿入位置補正で Unicode 境界を保ち、置換直後の音声入力で絵文字・複合文字を分断しないことを確認する。

- [ ] 選択範囲の置換検証で全文候補を繰り返し構築しないようにする

  問題: 選択した候補ごとに全文の候補を再構築し、非重複 N 件の検証で三次の比較処理を MainActor 上で行う。1,000 件では重なり比較だけで約 4.995 億回になる。実時間は未計測。対象: [`ReplacementService.swift`](../Koecho/ReplacementService.swift)、[`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift)。

  完了条件: 同じ本文・ルールに対する候補構築を検証対象ごとに繰り返さず、既存の候補失効検証・選択範囲・置換順を維持する。多数候補の全選択置換で計算量と応答時間の改善を確認する。

#### 調査・対応判断

[調査・対応判断](v2.0.0-investigations.md)

### 将来の改善

- [x] hosted tests の UserDefaults domain を片付ける

  対応: 起動の launch UUID・exact suite・host identity を Settings 構築前に記録し、終了時の削除と停止後の明示回収を実装した。[回収手順](../docs/xcode.md#hosted-test-の設定回収) に従い、その起動の記録だけを使う。UUID prefix による一括削除はしない。

  確認: 通常 build、全 App tests（228 tests / 270 cases）、helper 回帰が成功。実 host と helper の強制終了後の回収・再回収、生存 host の拒否、通常相当・別 launch・所有記録なしの sentinel 保持を確認した。正常終了後に OS が再生成した空 plist は helper の回収として区別した。F29 の隔離契約を維持し、所有不明の過去 domain は削除していない。

- [ ] D2 非ブロッキングの注意 UI を検討する

  現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)

  2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する

  2026-09-18 判断: モーダル alert や操作中断は行わず、録音・編集を継続できる注意 UI とする。表示位置・意匠は今後決める。今回は実装しない。

  現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける

  選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する

- [ ] スクリプトのモードの価値を調べる

  目的: ユーザー定義のモードごとにスクリプト一覧を切り替える必要があるか判断する。議事録用と翻訳用など、用途ごとに使うスクリプトが異なる場合を対象にする。

  作業・完了条件: 現在の複数スクリプト・手動選択・自動実行の導線で困る具体例を調べ、モード追加の必要性と範囲を決めて記録する。実装を採用する場合の設定移行と切替操作は、その判断後に別途定める。
