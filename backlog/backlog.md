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

- [ ] フォーカス復帰テストの NSHostingView 警告を解消する

  優先度・目的: 低優先度。テスト専用の未サポートな view 構成を直し、貼り付け失敗後のフォーカス復帰を警告なしで検証できるようにする。製品での view 破損やテスト失敗は確認されていない。

  根拠: [`InputPanelControllerConfirmTests.swift`](../KoechoTests/InputPanelControllerConfirmTests.swift) の `accessibilityFailureRehydratesEditorForImmediateRetryWithoutRestartingVoiceInput()` が、フォーカス移動を模擬する `focusSink`（NSTextView）を `panel.contentView`（NSHostingView）へ直接追加している。全 app tests で「Adding 'NSTextView' as a subview of NSHostingView is not supported and may result in a broken view hierarchy」という警告を観測した。証拠: `.tmp/verification/cli/ime-session-app-tests-20261011-01/build.log:2509`。同じ警告は IME 修正前の `.tmp/verification/cli/f3-generator-tests-1/build.log:2485` にもある。

  作業・完了条件: テストの focusSink の配置をサポートされる構成へ変更する（例: 通常の NSView を共通の親にして NSHostingView と並べる）。本文・選択・フォーカスの復帰と音声エンジンを再起動しない既存の検証を維持する。全 app tests を通し、該当警告がログに出ないことを確認する。警告の抑制・テスト削除で済ませず、製品コードの変更は前提にしない。

#### 機能改善

[機能改善](v2.0.0-features.md)

#### 実行結果のフォローアップ

[実行結果のフォローアップ](v2.0.0-followups.md)

#### 置換 UI の見直し

[置換 UI の見直し](v2.0.0-replacement-ui.md)

#### 不具合修正・検証

[不具合修正・検証](v2.0.0-bugfixes.md)

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
