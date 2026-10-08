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

#### 機能改善

[機能改善](v2.0.0-features.md)

#### 実行結果のフォローアップ

[実行結果のフォローアップ](v2.0.0-followups.md)

#### 置換 UI の見直し

[置換 UI の見直し](v2.0.0-replacement-ui.md)

#### 通常対応

[通常対応（完了済み）](v2.0.0-normal-completed.md)

#### 高難度対応

- [ ] F1 旧セッションのスクリプト結果を遮断する

  目的・発生条件: 遅い手動スクリプトまたは auto-run の実行中に Escape でキャンセルし、完了前にパネルを再表示すると、新しい本文・prompt が旧結果や旧本文で上書きされる。auto-run では別の対象アプリへ旧本文を貼り付け、履歴にも記録し得る。

  根拠: `KM-01-C04` / `KM-04-C01`。`R02-C01` / `R06-C01`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の cancel は実行を無効化せず、[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift) の再表示は visibility・対象アプリ・本文を更新する。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) と confirm の await 後は現在の visibility だけで旧処理の結果を受け入れ、手動処理の cleanup は新しい prompt・実行フラグも消す。paste は現在の対象アプリを使う。

  作業・完了条件: キャンセル前の処理完了が再表示後の本文・prompt・Undo・実行状態を変更せず、auto-run の旧結果を新しい対象へ貼り付けたり履歴へ追加したりしないことを確認する。手動・auto-run の成功と失敗、再表示後に新しい処理を始めた場合を既存のテストと実操作で確認する。

  限界: 実行未確認。旧処理が完了する前に再表示するタイミングが条件。2候補の auto-run 部分は同じ問題として統合した。

- [ ] F3 スクリプト待機中の音声入力を止める

  目的・発生条件: 音声入力を有効にしたまま追加入力なしの custom スクリプトを実行し、実行中に話し始めて成功時にも volatile text が残ると、加工結果が表示されず後続の音声確定で失われる。

  根拠: `KM-02-C08` / `KM-04-C03`。`R03-C01`。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) は開始時にだけ volatile を除去し、成功結果を AppState へ設定する。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) は実行中も音声プレビューを挿入し、[`VoiceInputTextEditor.swift`](../Koecho/VoiceInputTextEditor.swift) は volatileRange があると結果の表示同期を抑止する。その後の確定音声が古い表示本文を AppState へ書き戻す。

  対応方針: 実行前の追加入力中は音声入力を許可する。custom スクリプトの実行開始時に既存の未確定音声を本文へ取り込み、音声入力を停止して実行対象を固定する。実行待機中は既存のキーボード編集無効化と合わせて本文への入力を止め、加工結果と並行発話を合成する仕組みは作らない。

  作業・完了条件: 手動実行の成功・失敗後は、同じ入力セッションが表示中かつ音声入力が有効な場合だけ認識を再開する。確定時 auto-run の待機中も新しい音声を受け付けない。音声停止待ち・実行待ち中の Escape、再表示、音声無効化で旧処理が本文を書き換えたり認識を再開したりしないことを F1 と整合させて確認する。既存テストと実音声・遅いスクリプトで結果保持と再開を確認する。

  限界: 実画面未確認。成功後の SwiftUI 同期より先に finalize が来る場合もあり、全実行で必ず起きるとは判断していない。

- [ ] F4 終了後のマイク起動を防ぐ

  目的・発生条件: パネル表示直後のマイク許可・モデル準備・音声 format 決定待ち中に Escape、確定、Voice 無効化を行うと、終了後の処理がマイクや認識リソースを起動し得る。

  根拠: `KM-03-C01`。`R04-C01`。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の startRecognition は await 後に取消・state を確認せず、session activate・exclusive access acquire・audioEngine.start へ進む。cancel は既存フィールドを破棄するが開始 Task 内の self・ローカル engine は残る。[`SpeechModelPreparation.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechModelPreparation.swift) の検証済み early return も取消を確認しない。stop の開始待ち timeout 後も後続起動を防げない。

  作業・完了条件: 開始待ち中の取消・確定・無効化・停止 timeout 後に処理が復帰しても、マイクと認識リソースが再起動せず、終了状態とリソース状態が一致することを確認する。待機と終了の順序を確認し、実環境で開始途中の終了と次の開始を確認する。

  限界: OS の await が取消に応じて返す値、実録音継続時間、hardware 挙動は未確認。許可・モデル・format が成功して復帰する経路を静的に確認した。

- [ ] F9 再接続後のマイク対象を合わせる

  目的・発生条件: 保存済み外部マイクが切断中に Settings を開き、別の system default を変えずに再接続すると、Picker は外部マイクを示す一方、メーターと音量 slider は既定マイクに残る。

  根拠: `KM-03-C03`。`R05-C02`。[`AudioDeviceSelection.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceSelection.swift) の fallback は effectiveUID=nil となり、[`AudioDeviceManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift) は元の requested UID を失う。デバイス一覧更新は選択対象を再解決せず、[`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift) の選択 UID も変わらないため再開せず、音量書き込みも fallback の対象を使う。

  作業・完了条件: Settings を開いたまま保存済みマイクを再接続した後、表示・レベルメーター・入力音量の対象が選択マイクに一致することを確認する。切断時の fallback を維持し、対象解決を既存テストと実デバイスの切断・再接続で確認する。

  限界: hardware 再現未確認。system default が変わらず View も再表示されない条件。既存 D2 の fallback 注意表示の検討とは別に扱う。

- [ ] F10 認識終了後にメーターを再開する

  目的・発生条件: Settings のマイク設定を開いたまま入力パネルで認識し、確定または Escape で閉じると、利用可能になったマイクのメーターが0のままになる。認識中に Settings を開いた場合も該当する。

  根拠: `KM-03-C04`。`R05-C01`。[`AudioInputExclusiveAccess.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputExclusiveAccess.swift) の acquire は monitor を止めるが release は isInUse を戻すだけ。[`AudioInputLevelMonitor.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputLevelMonitor.swift) の開始は使用中 guard で返り、[`AudioDeviceManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift) と [`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift) には release に応じた再開経路がない。

  作業・完了条件: 認識終了後、ページ再表示や選択変更を行わずメーターが再開することを確認する。認識中の排他を維持し、Settings を先に開く場合と認識中に開く場合の双方を既存テストと実マイクで確認する。

  限界: hardware 実測未確認。監視停止と再開契機の欠如を静的に確認した。

- [ ] F17 言語切替中の取消を正しく扱う

  目的・発生条件: 音声入力中にメニューバーの言語を変更し、stop の await 中に Escape する。言語変更 task は cancel されずその後継続する。

  根拠: `KM-01-C06` / `KM-02-C06`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift):37-46; [`InputPanelController.swift`](../Koecho/InputPanelController.swift):259-275; [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):93-111; [`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift):81-118。switchEngine は await 前にだけ visibility を確認し、coordinator は stop 後に無条件で engine 再生成/start する。待機中の cancel は当時の旧 engine を対象とし、新 engine に届かない。

  作業・完了条件: 言語切替の stop 待機中に Escape した後、新しい engine が開始せず、非表示のままマイクが起動しないことを確認する。通常切替と次回パネル表示を既存テストと実マイクで確認する。F4 の engine 内開始待ちとは別の、coordinator の停止→再生成経路を対象とする。

  限界: 実マイクと UI の時系列は未実施。start 成功は権限・モデル・デバイスが利用可能なことが条件。

- [x] F29 hosted test の設定を隔離する

  目的・発生条件: project で KoechoTests は通常 app bundle ID com.ryotapoi.Koecho の Koecho.app を TEST_HOST として使い、verification.md も hosted test が app lifecycle を起動することを明記する。通常ユーザーの domain に値がある状態でこの hosted test を実行すると、テストメソッドによる隔離 factory 利用の有無によらず App 初期化から到達する。

  根拠: `KM-07-C01` / `KM-08-003`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift):9-20；[`AppState.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift):28-29；[`Settings.swift`](../Packages/KoechoKit/Sources/KoechoCore/Settings.swift):24-27；[`ScriptSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift):68-76,98-100,134,173-193；[`VoiceInputSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift):58-83,98-106；[`project.pbxproj`](../Koecho.xcodeproj/project.pbxproj):448,482,510,531；[`TestSupport.swift`](../KoechoTests/TestSupport.swift):8-13；[`verification.md`](../docs/verification.md):25。KoechoApp の stored @State 初期値 AppState() は init の isTesting guard に先行する。AppState は Settings() を生成し、.standard を feature 設定へ渡す。VoiceInputSettings と ScriptSettings は init 内で save し、不正 timeout の補正、voice mode の正規化、壊れた shortcut の encoded nil への書戻し等を行う。test factory による suite 隔離はその前の App 初期化には適用されない。

  作業・完了条件: test factory 使用前の KoechoApp / AppState / Settings 初期化も専用 domain へ隔離し、文書化された KoechoTests の起動だけで通常版の設定を読み書き・正規化しないことを確認する。不正 timeout・旧 voice mode・壊れた shortcut を含む通常 domain の保存値が維持され、test 設定が専用 domain へ保存されることを安全な fixture で検証する。hosted test の起動時挙動を [Verification](../docs/verification.md) の隔離説明と整合させる。

  完了: `KoechoApp.makeInitialAppState` が Settings 生成前に既存の XCTestCase 判定で起動ごとの専用 suite を選ぶ。通常起動は `.standard` を維持する。安全な2つの disposable domain による回帰テストで、不正 timeout・旧 voice mode・壊れた shortcut の値と型の保持、通常側だけの device sentinel の非読込、テスト側の初期保存・更新、通常経路の既存正規化を確認した。XcodeBuildMCP `build_macos`、`test_macos -only-testing:KoechoTests`（197件）、Package `swift test`（192件）が成功（2026-10-05）。

  検証範囲: 実 hosted run で XCTestCase 判定成立と同じ初期状態構築経路を確認した。実ユーザー domain へ異常 fixture を投入する実験は行わず、通常相当の専用 domain で代替した。HistoryStore のファイル保存先隔離は対象外。

#### 調査・対応判断

発生条件・実環境での影響・対応要否を確認してから、修正・仕様整理・見送りを判断する。移動した項目の改修はまだ確約しない。

- [ ] ScriptRunner の取消・終了競合時の stdin Broken pipe を調べる

  観測（2026-10-08）: Package gate `caret-preview-package-01` で既存 `cancellationRacingLaunchAndExitCompletesOnce` の実 Runner が `NSFileHandleOperationException`（`writeData: Broken pipe`）により abort し、111件で未完了となった。call stack は [ScriptRunner.swift](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) の stdin 書込みを示す。この run では Runner と当該テストに差分なし。直後の同じ全体 gate `caret-preview-package-02` は319件成功したため、常時再現ではない。証拠: `.tmp/verification/cli/caret-preview-package-01/` と `caret-preview-package-02/`。

  目的・調査範囲: script の終了または取消と stdin 書込みの競合条件、実アプリで到達する入力・操作、プロセス全体の終了リスクを特定する。F1 の旧結果遮断や既存 EOF timeout とは別に扱う。

  作業・完了条件: 再現条件・実環境への影響・修正または見送りの判断を記録する。修正を採用する場合は取消・早期終了時に app を abort せず、Runner の既存完了・取消契約と通常 stdin 送信を維持することを実 Runner の回帰で確認する。

- [ ] 置換ルールの日本語変換入力不能を調べる

  本人観察（2026-10-08）: Settings の置換ルール入力欄では日本語変換すると入力できないが、日本語のコピー＆ペーストでは入力できる。Settings の Pattern / Replacement の具体的な発生欄は未特定。最新製品 commit `65094f5` の専用版で Input Panel のルール追加 Replacement 欄を案内した確認では、本人は日本語変換入力ができると回答した（ルール保存や全入力条件の確認ではない）。根因と今回の置換 UI 差分との回帰因果は未確認。

  目的・調査範囲: 発生する画面・欄・IME の変換操作条件を特定し、入力中の状態同期や field 更新を含む原因を調べ、対応方針を決める。

  作業・完了条件: 再現条件・原因の調査結果と、修正／仕様整理／見送りの対応判断を記録する。修正を採用する場合は、対象欄で実 IME による変換・確定・ルール保存を確認し、既存の日本語貼り付けによる入力を維持する。

- [ ] Fn 貼り付け後に残る IME 変換候補を調べる

  本人観察（2026-10-08）: キーボードで未確定の「こんにちは」を入力して Fn で貼り付けると、貼り付け内容は「こんにちは」で正常。その後 Input Panel を再表示すると本文は空だが、「こんにちは」の IME 変換候補が表示される。根因と今回の置換 UI 差分との回帰因果は未確認。

  静的な根拠と仮説: [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift) の `commitMarkedTextIfNeeded()` は marked text がある場合に `unmarkText()` を呼ぶ。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の `finalizeVoiceInput()` は同メソッドで確定してから本文を採取し、text view を空にする。この経路と実 IME セッションとの不整合は調査対象の仮説であり、原因と断定しない。[`VoiceInputTextViewTests.swift`](../KoechoTests/VoiceInputTextViewTests.swift) の `commitMarkedTextKeepsJapaneseComposition` は programmatic な marked text の確認であり、OS の候補窓が終了することを保証しない。

  目的・調査範囲: 本文の確定・消去と実 IME セッション終了、パネル非表示・再表示の境界を調べ、候補残存の再現条件と対応方針を決める。

  作業・完了条件: 再現条件・原因の調査結果と、修正／仕様整理／見送りの対応判断を記録する。修正を採用する場合は、未確定本文の正しい貼り付けを維持し、実 IME の操作で再表示時の候補残存・旧本文復活がないことを確認する。

- [ ] F7 認識再開中の発話欠落を調べる

  目的・発生条件: 発話中にキーボード入力やカーソル移動を行うと、認識再開中の発話が取り込まれず音声入力が途切れる。

  根拠: `KM-03-C02`。`R04-C02`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) のテキスト操作は restartTranscriber へ到達する。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) は tap を除去し AVAudioEngine を停止した後、analyzer と旧 resultTask の終了を await し、その間の入力を保持しない。割り込みと重複防止の現行判断は [ADR 0032](../decisions/0032-speech-overlap-defense.md) を参照。

  作業・完了条件: 実音声で認識再開時の録音停止時間・発話欠落を確認し、利用者への影響と対応要否を判断して記録する。改修を採用する場合は、採用した範囲で発話の取り込みを確認する。再開前後の結果同期を既存テストで確認し、実音声とカーソル移動・キーボード入力で影響を確認する。

  限界: 実音声未確認。中断時間と欠落語数は OS・callback の進行に依存し未測定。既存 D1 の意図した反復発話と重複除去の判断とは別に扱う。

- [ ] F22 大量置換の処理時間を調べる

  目的・発生条件: 5 万 UTF-16 程度のＡ，Ｂ；改行の1 万行を取り込み、，→,、；→;を Replace する。本文長制限はこの経路にない。preview も同関数を使う。

  根拠: `KM-02-C07`。[`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift):66-84,126-131; [`ReplacementService.swift`](../Koecho/ReplacementService.swift):6,36-42。delta=0 でも全 match の offset entry を保持し、後続 match 毎に先頭から2 回線形探索するため、各1 万一致の rule で約1 億 entry 訪問になる。MainActor の同期処理である。

  作業・完了条件: Release 条件と実パネルで処理時間・UI 応答を計測し、改善要否を判断して記録する。改善を採用する場合は、登録順・置換結果・座標対応を維持し、5 万 UTF-16 程度の「Ａ，Ｂ；改行」1 万行に ，→,、；→; を適用する場合の約1 億 entry 訪問を解消する。Release 条件の計測と実パネル操作で本文長・一致数に対する処理時間と UI 応答を確認し、preview 経路も同じ計算を使うことを照合する。F8 と同じ座標変換部分を触る場合は実装範囲を合わせる。

  限界: 原 Core 算法の logger を除去し最小型を使った Swift script で20000 match・3.44396 秒を観測した。非最適化環境の値であり Release アプリの待機時間とは扱わない。実アプリの Escape・描画待ち時間は未測定。

- [ ] F26 focus 変更時の誤貼付を調べる

  目的・発生条件: 通常 confirm はパネルを隠し可視状態を false にしてから paste を await する。この待機中にはユーザーが別アプリをクリックでき、singleToggle で再表示する経路も showPanel の isConfirming ガードがないため到達する。送信時に別の入力欄が focus を得て Cmd+V を受け付ける条件で、そこへ本文が渡る。

  根拠: `KM-05-C04`。[`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift):117-142；[`CGEventClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/CGEventClient.swift):24-37；[`InputPanelController.swift`](../Koecho/InputPanelController.swift):104-112,200-215；[`KoechoApp.swift`](../Koecho/KoechoApp.swift):193-204；macOS SDK CoreGraphics/Headers/CGEvent.h:347-354 は CGEventPost を event stream への post、:356-374 は特定アプリ向け post を別 API として定義している。パネル表示前のアプリを記憶してペースト前に再 activate するが、その後100ms の await があり、対象や現在 focus を照合せず simulatePaste を呼ぶ。LiveCGEventClient は PID を指定せず Cmd+V を HID event stream へ post する。対象の貼付成功を確認する処理もなく、イベント生成が成功すれば caller は履歴を追加する。

  作業・完了条件: 実アプリで focus 切替時の配送を確認し、誤貼付の成立条件と最小の対策を判断して記録する。対策を採用する場合は、対象 activate 後の100ms 待機中に他アプリの入力欄へ focus を移した場合とパネルを再表示した場合に、記憶した対象以外へ本文を貼り付けたり成功として履歴に追加したりしないことを確認する。通常の対象アプリへの貼付を維持し、送信時の対象判断を既存テストと実アプリの focus 切替で確認する。

  限界: 実 OS で100ms 内の focus 切替と配送を再現していない。任意の別アプリが貼付を受け入れると断定せず、送信時にその入力欄が focus を持ち Cmd+V を受け付ける場合に限定する。発生頻度は未確認。

- [ ] F27 外部アプリの選択取得待ちを調べる

  目的・発生条件: Accessibility 権限を得た通常 showPanel 経路で常に外部 focus/selection を問い合わせる。最前面アプリが応答停止・長い処理待ちで AX 応答を返せない場合、パネル表示前に呼び出しスレッドが待つ。HotkeyService も main queue へ処理を配送するため、その間後続操作が処理されない。

  根拠: `KM-05-C05`。[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift):5,24-41；[`InputPanelController.swift`](../Koecho/InputPanelController.swift):90-117；[`SelectedTextReader.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SelectedTextReader.swift):25-39；[`AccessibilityClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AccessibilityClient.swift):17-42；[`HotkeyService.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift):83-85；macOS SDK HIServices/Headers/AXUIElement.h:38-39,145-148,388-402 は応答不能時の messaging failure と AX API timeout を説明する。MainActor 上の PanelLifecycleManager.show は makeKeyAndOrderFront より前に SelectedTextReader.read を同期実行し、LiveAccessibilityClient は外部アプリへの AXUIElementCopyAttributeValue を同期実行する。応答待ちの間は MainActor を解放しない。SDK は AX messaging に応答不能アプリと timeout が存在することを明記している。

  作業・完了条件: 実 AX 応答待ちの停止時間と操作への影響を確認し、待機上限の調整・非同期化・見送りを判断して記録する。改修を採用する場合は、最前面アプリが AX 応答を返さない場合でも、選択取得待ちの間にパネル表示・menu・hotkey 操作を処理できることを確認する。通常の選択本文取り込みと表示前アプリの記録を維持し、注入した遅い取得と実 AX 応答待ちを分けて検証する。

  限界: AX 実応答停止、既定 timeout 値、実際の停止秒数は測定していない。停止する長さは外部アプリと OS に依存し、全ての AX 呼び出しが遅いという主張ではない。

- [ ] F30 カーソル割込み時の buffer を調べる

  目的・発生条件: `KM-02-C05` は `confirmed` / `uncertain`。確定音声 callback 後から次の volatile 到着前にカーソルを移す場合、buffer を破棄しない現行経路で利用者に見える再送・表示重複が起きるかを調べ、対応要否を決める。

  根拠: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):179-195,249-279 は volatileRange=nil なら挿入点だけを更新し restart を呼ばない。[`InputPanelController.swift`](../Koecho/InputPanelController.swift):414-416 から到達する。割り込みと重複防止の現行判断は [ADR 0032](../decisions/0032-speech-overlap-defense.md) を参照。確定 callback には重複除去があるが volatile にはない。

  作業・完了条件: 対象 runtime の実 SpeechAnalyzer で提示のカーソル操作後に古い本文が volatile として再送されるか、表示への影響と頻度を確認する。条件・結果・限界を記録して修正／仕様整理／見送りの対応判断をもって完了とする。反復発話と重複除去を扱う [D1](#調査対応判断) の調査と観測を共有できるが、同じ原因とは未判定。

  限界: この条件での実再送・表示重複は未観測。buffer を再生成しないことだけから具体的な害や修正必要性を確定しない。

- [ ] N1 音声変換失敗への対応を判断する

  目的・根拠: format / device 変更時に音声だけ落ちて listening 表示が残る可能性がある。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の変換失敗分岐が return のみ。

  候補方針: 音声変換に失敗した場合は音声入力をオフにし、失敗したことと、再度オンにすれば続けられる旨を説明する。ただし、この対応自体を採用するかは未決とする。

  作業・完了条件: 実環境と必要なテストで失敗の発生条件と頻度を確認し、その結果に基づいて候補方針を正式に採用するか見送るかを判断して記録する。

- [ ] D1 意図した反復発話を入力可能にする

  背景・根拠: `SpeechAnalyzer` が別々に返す確定結果でも、蓄積済みテキストの末尾と新しい結果の先頭が重なると、現在は重複として後者から除去する。これはキーボード入力・カーソル移動の割り込み後に前セグメントが再配信される既知の問題への防御であり、ユーザーが同じ言葉を繰り返して入力したい意図を削除するためではない。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の `stripOverlappingPrefix`、[ADR 0032](../decisions/0032-speech-overlap-defense.md)

  例: 独立した確定結果が「あい」「あい」と続くと、現在は後者が除去される。将来は、認識結果の再配信と意図した反復発話を区別できるかを調査する。

  実装時の判断・確認: 実際の SDK・対応 runtime で `SpeechAnalyzer` の挙動を確認し、重複除去を外せるか、または対象を狭められるかを判断する。macOS 27 専用化および対応下限の変更は決定済みとし、ライブラリ側で解消済みかどうかは未決定とする。採用する範囲で必要な場合だけ仕様と確認項目を更新し、既存の手段で確認する。新しいテスト基盤は要求しない。

  補足: 現在の比較は最大 512 UTF-16 code units。この範囲外の再配信への対応が必要かも、反復発話と重複除去の振る舞いを決める際に併せて扱う。

#### その他

- [ ] hosted tests の UserDefaults domain を片付ける

  優先度・時期: hosted test の起動・隔離を次に扱う際に併せて対応する。通常版の設定隔離は F29 で対応済みであり、この残件だけを理由に開発・検証を止めない。

  根拠: [`KoechoApp.makeInitialAppState`](../Koecho/KoechoApp.swift) は起動ごとの UUID suite を生成するが、run との所有記録と終了時の削除は実装されていない。2026-10-06 の実行時間帯に該当 plist が6件あったが、その時間帯の全ファイルが今回の run のものとは確定できず一括削除していない。

  作業・完了条件: 起動が生成した domain を識別できるようにし、その domain だけを終了・後片付け時に削除する。通常版と別 run の設定を維持し、通常終了と中断後の回収で残存・削除対象を確認する。UUID の共通 prefix による一括削除はしない。F29 の隔離契約と [検証ルール](../docs/verification.md) を維持する。

- [ ] D2 非ブロッキングの注意 UI を検討する

  現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)

  2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する

  2026-09-18 判断: モーダル alert や操作中断は行わず、録音・編集を継続できる注意 UI とする。表示位置・意匠は今後決める。今回は実装しない。

  現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける

  選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する

- [ ] スクリプトのモードの価値を調べる

  目的: ユーザー定義のモードごとにスクリプト一覧を切り替える必要があるか判断する。議事録用と翻訳用など、用途ごとに使うスクリプトが異なる場合を対象にする。

  作業・完了条件: 現在の複数スクリプト・手動選択・自動実行の導線で困る具体例を調べ、モード追加の必要性と範囲を決めて記録する。実装を採用する場合の設定移行と切替操作は、その判断後に別途定める。
