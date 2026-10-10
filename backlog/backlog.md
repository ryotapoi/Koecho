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

発生条件・実環境での影響・対応要否を確認してから、修正・仕様整理・見送りを判断する。改修は確約しない。実害・頻度と、調査・実装・維持のコストを比べて採否を決める。対象を絞った確認で未再現なら、その条件と限界を記録して見送りを判断できる。再現だけのための新しい基盤や網羅的な調査は要求しない。

- [x] ScriptRunner の取消・終了競合時の stdin Broken pipe を調べる

  優先度・調査の区切り: 実 Runner の abort が観測されているため、本節で先に扱う。既存の取消レースと早期終了時の stdin 書込みに絞り、実アプリからの到達性と局所的な対処の可否を判断する。常時再現ではないため、短い再実行の成功だけで解消済みとはしない。

  観測（2026-10-08）: Package gate `caret-preview-package-01` で既存 `cancellationRacingLaunchAndExitCompletesOnce` の実 Runner が `NSFileHandleOperationException`（`writeData: Broken pipe`）により abort し、111件で未完了となった。call stack は [ScriptRunner.swift](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) の stdin 書込みを示す。この run では Runner と当該テストに差分なし。直後の同じ全体 gate `caret-preview-package-02` は319件成功したため、常時再現ではない。証拠: `.tmp/verification/cli/caret-preview-package-01/` と `caret-preview-package-02/`。

  目的・調査範囲: script の終了または取消と stdin 書込みの競合条件、実アプリで到達する入力・操作、プロセス全体の終了リスクを特定する。F1 の旧結果遮断や既存 EOF timeout とは別に扱う。

  作業・完了条件: 再現条件・実環境への影響・修正または見送りの判断を記録する。修正を採用する場合は取消・早期終了時に app を abort せず、Runner の既存完了・取消契約と通常 stdin 送信を維持することを実 Runner の回帰で確認する。

  結果（2026-10-10）: 旧 Runner を独立プロセスで動かし、pipe 容量超の UTF-8 本文と `exec 0<&-; printf done` で SIGPIPE 終了（signal 13）を再現した。これは上記の Objective-C 例外の再観測とは区別する。元の `caret-preview-package-01/02` はこの checkout に存在せず未確認。throwing write だけでも SIGPIPE 終了したため、stdin writer に限った `F_SETNOSIGPIPE` と throwing write / close を採用した。launch 後の書込み失敗は既存 RunState の取消・timeout・exit / EOF 判定に委ねる。実アプリでは本文を送る Custom Script / auto script と、パネル取消 → task.cancel から到達する。全 scheduling interleaving は網羅しない。

  検証: 通常の大きい UTF-8 本文の完全一致、stdin 早期閉鎖時の成功・nonzero / stderr・empty output、送信中の取消と owned process 停止、送信中の timeout、既存 race / EOF 回帰を実 Runner で確認した。Package 337件、通常 build、専用署名 build が成功（失敗・未完了・timeout・残留 process なし）。証拠は `.tmp/workflow/orchestrator-20261010-backlog/changes/T05/evidence/`、`.tmp/verification/cli/t05-package-02/` と `t05-build-01/`。専用版は起動・doctor・cleanup のみ確認し、CUA が `timeoutReached` で実画面操作は未確認。本人確認を次項へ分離した。

- [x] ScriptRunner の stdin 修正を専用検証版の実画面で確認する

  起票時の未確認: T05 の実 Runner 回帰と build は成功したが、専用版の CUA 選択が `timeoutReached` となり、Custom Script とパネル取消の実操作は未確認だった。プロセス起動を実画面成功として扱わない。証拠: `.tmp/verification/verify-koecho/t05-script-ui-01/`（所有 process は cleanup 済み）。

  手順・完了条件: [verify-koecho](../.agents/skills/verify-koecho/SKILL.md) の未使用 run で専用版を prepare → build → launch（voice off）→ doctor し、本人が Settings → Scripts に一時的な Custom Script を登録する。通常の `tr a-z A-Z` で `original` → `ORIGINAL` を確認する。容量超の disposable 本文（例: 100万文字）をパネルに貼り、`exec 0<&-; printf done` が `done` を返して app が生存すること、`exec 0<&-; printf diagnostic >&2; exit 2` がエラーを表示して app と本文を保つことを確認する。`while :; do :; done` 実行中に Escape でパネルを取消し、app の生存・再表示・通常 script の再実行を確認する。実施者・日時・入力サイズ・操作・結果・署名 / PID・必要な権限と再許可有無を保存し、一時 script を削除して所有 run を cleanup する。通常版・通常履歴・TCC を自動変更しない。

  結果（2026-10-10）: 本人操作で通常の uppercase 変換、100万文字を使った stdin 早期閉鎖時の `done` 反映と app 生存、nonzero 終了時のエラー表示・本文保持・app 生存、実行中 Escape 取消後の再表示と通常 script 再実行を確認した。権限の再許可なし。一時 script 削除は本人報告、所有 PID 75807 の生存・専用署名は doctor で確認し、cleanup で停止した。専用 build 成功、timeout・残留 process なし。証拠: `.tmp/verification/verify-koecho/t05-user-ui-20261010-01/`（`manual-results.md`、`session.json`、build / identity 記録）。画面の直接観測と権限項目ごとの設定状態・再ビルド後の権限維持は未確認。

- [x] 置換ルールの日本語変換入力不能を調べる

  調査の区切り: 現行版の Settings で発生する欄と変換操作をまず確認する。未再現なら試した条件を記録して見送りを判断し、状態同期・保存処理を原因と決めた変更は行わない。

  本人観察（2026-10-08）: Settings の置換ルール入力欄では日本語変換すると入力できないが、日本語のコピー＆ペーストでは入力できる。Settings の Pattern / Replacement の具体的な発生欄は未特定。最新製品 commit `65094f5` の専用版で Input Panel のルール追加 Replacement 欄を案内した確認では、本人は日本語変換入力ができると回答した（ルール保存や全入力条件の確認ではない）。根因と今回の置換 UI 差分との回帰因果は未確認。

  目的・調査範囲: 発生する画面・欄・IME の変換操作条件を特定し、入力中の状態同期や field 更新を含む原因を調べ、対応方針を決める。

  作業・完了条件: 再現条件・原因の調査結果と、修正／仕様整理／見送りの対応判断を記録する。修正を採用する場合は、対象欄で実 IME による変換・確定・ルール保存を確認し、既存の日本語貼り付けによる入力を維持する。

  結果（2026-10-10）: 本人が現在の環境では日本語変換入力が正常に動作し、再現しないと確認したため、修正を見送り調査を完了した。以前試した開発中の版に起因した可能性は本人の推測であり、原因は未特定。今回の確認対象の版・欄・具体的な変換操作とルール保存の確認有無は未記録。

- [x] 貼り付け後に残る IME 変換候補と旧本文の復活を修正する

  対応判断: 貼り付け本文は正常だが、再表示後に残る候補を Enter で確定すると旧本文が復活するため、修正対象とする。入力不能やデータ消失は観測しておらず、それらを前提に対応を広げない。

  本人観察（2026-10-08）: キーボードで未確定の「こんにちは」を入力して Fn で貼り付けると、貼り付け内容は「こんにちは」で正常。その後 Input Panel を再表示すると本文は空だが、「こんにちは」の IME 変換候補が表示される。根因と今回の置換 UI 差分との回帰因果は未確認。

  本人確認（2026-10-10）: 未確定の「こんにちは」は正常に貼り付けられ、再表示直後の本文は空だが古い候補が残る。候補だけが表示された状態で Enter を押すと本文に「こんにちは」が入り、その後も入力できる。Fn と Confirm ボタンのどちらでも候補が残る。確認対象のアプリ版・macOS 版・入力ソース・音声入力等の設定は未記録。

  実装: [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift) の `commitMarkedTextIfNeeded()` は marked text がある場合に `unmarkText()` で本文を保持してから `inputContext?.discardMarkedText()` で IME セッションを終了する。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の `finalizeVoiceInput()` は同メソッドで確定してから本文を採取し、text view を空にする。自動 script 有効時も、その前に同メソッドで確定してから入力を停止する。[`VoiceInputTextViewTests.swift`](../KoechoTests/VoiceInputTextViewTests.swift) の `commitMarkedTextKeepsJapaneseComposition` は programmatic な marked text の確認であり、OS の候補窓が終了することを保証しない。

  比較検証（2026-10-11）: 製品 commit `9b62ff6` の変更前専用版では、本人が Confirm 後の候補残存と Enter による旧本文復活を再確認した。一時コピーで `unmarkText()` 直後に `inputContext?.discardMarkedText()` だけを追加し、既存の処理順序を維持した専用版に切替。Confirm と Fn で未確定本文の貼り付け・再表示時の候補・Enter 後の旧本文・後続の日本語入力と貼り付けを案内し、本人は「問題なしでした」と報告した。項目別の詳細回答・画面の直接観測はない。macOS 27.0.1、音声 off。入力ソース名と権限再許可有無は未報告。両版の build・署名確認と所有 PID の cleanup は完了。証拠: `.tmp/verification/verify-koecho/ime-baseline-20261010-01/` と `ime-api-20261010-01/` の `manual-results.md`、build / identity / session 記録。追加差分は `.tmp/ime-investigation/api-after-unmark/variant.patch`。

  修正・完了確認（2026-10-11）: 比較版と同じ一行追加を製品コードへ適用した。API 追加の効果は本人の比較確認で支持された。順序のみを変える比較は未実施であり、別 API が唯一の解決法とは断定しない。同メソッドは貼り付け時にすでに呼ばれており、文字入力から音声入力への切替に流用可能な別の IME セッション終了処理は現行コードでは見つからなかった。通常確定と自動 script 前確定の両呼出し元を確認し、既存の本文保持テストに加えて、自動 script が未確定の日本語本文を受け取り、その加工結果を貼り付けるテストを通した。Fn と Confirm ボタンは同じ `confirm()` に集約される。

  gate: 通常 build と全 app tests が成功（229 tests、parameterized case を含む271実行、失敗・skip・timeout・残留 host・設定回収失敗なし）。証拠: `.tmp/verification/cli/ime-session-build-20261011-02/` と `ime-session-app-tests-20261011-01/`。実 IME 操作は製品差分と同一の既存比較証拠を再利用した。候補終了を programmatic な自動テストの回帰検出とは扱わず、未報告の入力ソース・権限再許可有無、他 OS・他入力ソース・実音声併用は保証しない。

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
