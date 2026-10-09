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

- [x] F1 旧セッションのスクリプト結果を遮断する

  完了内容: F19 の先行修正 `eeca1dd` で解消済み。遅い手動スクリプトまたは auto-run を Escape で取り消し、旧処理の完了前に再表示しても、新しい本文・prompt・Undo・実行状態へ旧処理が干渉せず、auto-run の旧結果を貼り付けたり履歴へ追加したりしない。

  根拠: `KM-01-C04` / `KM-04-C01`、`R02-C01` / `R06-C01`。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) の取消は実行 ID を無効化し、手動の成功・失敗・cleanup は ID 一致を要求する。auto-run の旧完了も CancellationError となり、[`InputPanelController.swift`](../Koecho/InputPanelController.swift) が貼付・履歴記録前に捨てる。先行修正からの差分を照合し、これらの保護と競合回帰の保持を確認した。

  検証: [`InputPanelControllerScriptTests.swift`](../KoechoTests/InputPanelControllerScriptTests.swift) の `escapeStopsScriptAndOldCompletionCannotClearNextRun(autoRun:)` は手動・auto-run の Escape→再表示→新実行→旧完了で本文・実行状態・新 Process 生存、貼付・履歴への非干渉と回復を確認する。通常成功・失敗、prompt・Undo は [`ScriptExecutionServiceTests.swift`](../KoechoTests/ScriptExecutionServiceTests.swift) 等の既存テストが保護する。F19 の保存結果は hosted tests 200件成功（上記競合2ケースを含む）。本人実操作は手動・auto-run の Escape と実 Process 停止、再表示後の正常回復を確認した。証拠は `.tmp/workflow/orchestrator-20261005-f28-f5-f19-fresh/changes/F19/` の `report.md` と `validation/{hosted-tests,human-manual-escape,human-auto-escape,human-recovery}.json`。

  完了判断・限界: F19 時点では F1 全体を未完了としていたが、今回指定された検証方針に従い、共通 ID ガード・代表回帰・既存実操作を十分な証拠として完了とする。prompt / Undo 個別の再表示競合、旧成功・旧失敗の全順序は個別実測していない。実操作は専用署名 fixture と safe fake paster の範囲であり、通常版の実ペースト等の保証ではない。今回は文書だけを更新し、追加テスト・build・実操作は行っていない。

- [x] F3 スクリプト待機中の音声入力を止める

  完了内容: custom の実行開始時に本文・追加入力の未確定音声を取り込んで入力を固定し、停止待ちと実行待ちの音声入力を遮断する。追加入力の編集中は音声入力を許可する。手動成功・失敗後は本文と表示を同期し、同じ入力セッションが表示中かつ Voice 有効の場合だけ認識を再開する。成功時 Undo は固定した元本文へ戻る。auto-run の停止待ちも音声入力を遮断し、停止待ち・実行待ちの取消、再表示、Voice off で旧処理が本文や認識再開へ干渉しない。

  検証: [`ScriptExecutionServiceTests.swift`](../KoechoTests/ScriptExecutionServiceTests.swift) は制御した停止で本文・prompt の固定、成功・失敗と再開後の本文、Voice off、取消後の新セッション保護を確認する。[`InputPanelControllerScriptTests.swift`](../KoechoTests/InputPanelControllerScriptTests.swift) は実 TextView の加工結果が最初の再開音声で失われないこと、auto-run 停止待ちの取消→再表示で本文と貼付・履歴が守られること、既存 F1 の実 Process 競合を確認する。通常 build と全 App tests は成功（225 tests / 266 cases、失敗・skip・timeout・残留なし）。2026-10-09 の専用署名版で本人が手動成功・失敗の未確定音声取込み、待機中の発話遮断、完了後の音声再開、成功加工結果と失敗元本文の保持を確認した。証拠は `.tmp/workflow/f3-20261009/changes/F3/` の `node-results/generator.md` と `validation/human-voice.md`、`.tmp/verification/cli/f3-generator-{build,tests}-final/`。

  完了判断・限界: 自動回帰と手動成功・失敗の実音声による結果保持・正常再開を核心の証拠として完了とする。auto-run、取消→再表示、待機中 Voice off の個別本人実操作は未確認であり、自動回帰で裏付けた。OS 初期起動中の全競合、全発話順序、通常版の実ペースト、再ビルド後の権限維持は保証しない。

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

発生条件・実環境での影響・対応要否を確認してから、修正・仕様整理・見送りを判断する。改修は確約しない。実害・頻度と、調査・実装・維持のコストを比べて採否を決める。対象を絞った確認で未再現なら、その条件と限界を記録して見送りを判断できる。再現だけのための新しい基盤や網羅的な調査は要求しない。

- [ ] ScriptRunner の取消・終了競合時の stdin Broken pipe を調べる

  優先度・調査の区切り: 実 Runner の abort が観測されているため、本節で先に扱う。既存の取消レースと早期終了時の stdin 書込みに絞り、実アプリからの到達性と局所的な対処の可否を判断する。常時再現ではないため、短い再実行の成功だけで解消済みとはしない。

  観測（2026-10-08）: Package gate `caret-preview-package-01` で既存 `cancellationRacingLaunchAndExitCompletesOnce` の実 Runner が `NSFileHandleOperationException`（`writeData: Broken pipe`）により abort し、111件で未完了となった。call stack は [ScriptRunner.swift](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) の stdin 書込みを示す。この run では Runner と当該テストに差分なし。直後の同じ全体 gate `caret-preview-package-02` は319件成功したため、常時再現ではない。証拠: `.tmp/verification/cli/caret-preview-package-01/` と `caret-preview-package-02/`。

  目的・調査範囲: script の終了または取消と stdin 書込みの競合条件、実アプリで到達する入力・操作、プロセス全体の終了リスクを特定する。F1 の旧結果遮断や既存 EOF timeout とは別に扱う。

  作業・完了条件: 再現条件・実環境への影響・修正または見送りの判断を記録する。修正を採用する場合は取消・早期終了時に app を abort せず、Runner の既存完了・取消契約と通常 stdin 送信を維持することを実 Runner の回帰で確認する。

- [ ] 置換ルールの日本語変換入力不能を調べる

  調査の区切り: 現行版の Settings で発生する欄と変換操作をまず確認する。未再現なら試した条件を記録して見送りを判断し、状態同期・保存処理を原因と決めた変更は行わない。

  本人観察（2026-10-08）: Settings の置換ルール入力欄では日本語変換すると入力できないが、日本語のコピー＆ペーストでは入力できる。Settings の Pattern / Replacement の具体的な発生欄は未特定。最新製品 commit `65094f5` の専用版で Input Panel のルール追加 Replacement 欄を案内した確認では、本人は日本語変換入力ができると回答した（ルール保存や全入力条件の確認ではない）。根因と今回の置換 UI 差分との回帰因果は未確認。

  目的・調査範囲: 発生する画面・欄・IME の変換操作条件を特定し、入力中の状態同期や field 更新を含む原因を調べ、対応方針を決める。

  作業・完了条件: 再現条件・原因の調査結果と、修正／仕様整理／見送りの対応判断を記録する。修正を採用する場合は、対象欄で実 IME による変換・確定・ルール保存を確認し、既存の日本語貼り付けによる入力を維持する。

- [ ] Fn 貼り付け後に残る IME 変換候補を調べる

  優先度・調査の区切り: 貼り付け本文は正常なため、日本語入力不能の確認時に併せて扱う。候補残存の再現と次の入力への影響を確認し、未観測の旧本文復活やデータ消失を前提に対応を広げない。

  本人観察（2026-10-08）: キーボードで未確定の「こんにちは」を入力して Fn で貼り付けると、貼り付け内容は「こんにちは」で正常。その後 Input Panel を再表示すると本文は空だが、「こんにちは」の IME 変換候補が表示される。根因と今回の置換 UI 差分との回帰因果は未確認。

  静的な根拠と仮説: [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift) の `commitMarkedTextIfNeeded()` は marked text がある場合に `unmarkText()` を呼ぶ。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の `finalizeVoiceInput()` は同メソッドで確定してから本文を採取し、text view を空にする。この経路と実 IME セッションとの不整合は調査対象の仮説であり、原因と断定しない。[`VoiceInputTextViewTests.swift`](../KoechoTests/VoiceInputTextViewTests.swift) の `commitMarkedTextKeepsJapaneseComposition` は programmatic な marked text の確認であり、OS の候補窓が終了することを保証しない。

  目的・調査範囲: 本文の確定・消去と実 IME セッション終了、パネル非表示・再表示の境界を調べ、候補残存の再現条件と対応方針を決める。

  作業・完了条件: 再現条件・原因の調査結果と、修正／仕様整理／見送りの対応判断を記録する。修正を採用する場合は、未確定本文の正しい貼り付けを維持し、実 IME の操作で再表示時の候補残存・旧本文復活がないことを確認する。

- [ ] F7 認識再開中の発話欠落を調べる

  目的・発生条件: キーボード入力や volatile text がある状態でのカーソル移動に伴う認識再開では、録音を一時停止する。停止区間が利用者に分かる発話欠落を生むか、重複防止とのトレードオフを変える価値があるかを判断する。

  優先度・調査の区切り: 低優先度。D1 の実音声確認と同じ機会に通常の入力操作で確認する。実害が見えなければ現行方式を維持し、録音継続のための buffering や認識構成の変更へ進まない。

  根拠: `KM-03-C02`。`R04-C02`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) のテキスト操作は restartTranscriber へ到達する。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) は tap を除去し AVAudioEngine を停止した後、analyzer と旧 resultTask の終了を await し、その間の入力を保持しない。割り込みと重複防止の現行判断は [ADR 0032](../decisions/0032-speech-overlap-defense.md) を参照。

  作業・完了条件: 実音声で認識再開時の録音停止時間・発話欠落を確認し、利用者への影響と対応要否を判断して記録する。改修を採用する場合は、採用した範囲で発話の取り込みを確認する。再開前後の結果同期を既存テストで確認し、実音声とカーソル移動・キーボード入力で影響を確認する。

  限界: 実音声未確認。中断時間と欠落語数は OS・callback の進行に依存し未測定。既存 D1 の意図した反復発話と重複除去の判断とは別に扱う。

- [ ] F26 focus 変更時の誤貼付を調べる

  目的・発生条件: 通常 confirm はパネルを隠してから paste を await する。対象アプリの activate 後の100ms 待機中に別アプリへ focus を移す、またはパネルを再表示すると、送信時の入力欄が Cmd+V を受け付ける場合に元の対象以外へ本文が渡る可能性がある。

  根拠: `KM-05-C04`。[`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) は対象 activate 後に await し、focus を照合せず simulatePaste を呼ぶ。[`CGEventClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/CGEventClient.swift) は PID を指定せず Cmd+V を HID event stream へ post する。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の showPanel は isConfirming で再表示を抑止しない。

  調査の区切り: 元のアプリへの貼り付けは主機能なので、上記2操作に絞って実配送を確認する。再現できなければ条件と限界を記録して見送りを判断する。再現専用の自動化基盤は作らない。

  作業・完了条件: 成立条件・利用者への影響と、局所的な対策の費用を比べ、修正／見送りを判断して記録する。対策を採用する場合は、確認した競合で対象以外への送信を抑止し、送信を見送った本文を履歴へ追加せず、通常の貼り付けを維持する。外部アプリが貼り付けを完了したことの検証は要求しない。

  限界: 実 OS で100ms 内の focus 切替と配送を再現していない。発生頻度は未確認。

- [ ] D1 反復発話と再配信防御の対応要否を判断する

  優先度・調査の区切り: 低優先度。F7 と同じ実音声確認で、通常の反復発話と入力操作後の再配信を確認する。実害が見えない場合や、安全に区別する変更が大きい場合は現行防御を維持して見送りを判断する。

  背景・根拠: `SpeechAnalyzer` が別々に返す確定結果でも、蓄積済みテキストの末尾と新しい結果の先頭が重なると、現在は重複として後者から除去する。これはキーボード入力・カーソル移動の割り込み後に前セグメントが再配信される既知の問題への防御であり、ユーザーが同じ言葉を繰り返して入力したい意図を削除するためではない。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の `stripOverlappingPrefix`、[ADR 0032](../decisions/0032-speech-overlap-defense.md)

  例: 独立した確定結果が「あい」「あい」と続くと、現在は後者が除去される。将来は、認識結果の再配信と意図した反復発話を区別できるかを調査する。

  実装時の判断・確認: 実際の SDK・対応 runtime で `SpeechAnalyzer` の挙動を確認し、重複除去を外せるか、または対象を狭められるかを判断する。macOS 27 専用化および対応下限の変更は決定済みとし、ライブラリ側で解消済みかどうかは未決定とする。採用する範囲で必要な場合だけ仕様と確認項目を更新し、既存の手段で確認する。新しいテスト基盤は要求しない。

  併せて見る観点: 確定音声の直後、次の volatile 到着前にカーソルを移した場合の旧本文の再表示（旧 F30）は未観測。D1 の確認中に現れた場合だけ影響を判断し、独立した再現調査は行わない。512 UTF-16 code units を超える再配信も、実際に観測した場合だけ扱う。

  完了条件: 確認した条件・結果・限界と、修正／仕様整理／見送りの判断を記録する。

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
