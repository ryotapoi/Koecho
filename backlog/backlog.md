# Backlog

## 運用ルール

- Backlog には、今後着手でき、完了を判定できる作業を `- [ ]` 形式のタスクとして置く。
- 対応要否を決める調査もタスクにできる。観察事実だけを残さず、判断したい問いと、判断をもって完了とすることを明示する。
- 粗いメモで起票してよいが、着手前に目的と受け入れ条件を読める粒度へ詰める。
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

### 実行結果のフォローアップ

- [x] N11 ScriptExecutionService の emptyOutput による App test 失敗の原因を調査する
  - 目的・根拠: D4 と N10 の実行結果で、`failedAndAutoRunScriptsDoNotOfferUndo` が `.emptyOutput` により失敗し、再実行で成功した。同一ケースの失敗が検証の再試行を要している。製品の出力欠落や N10 差分との因果は未確定。[`ScriptExecutionServiceTests.swift`](../KoechoTests/ScriptExecutionServiceTests.swift)、[`ScriptRunner.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift)。
  - 作業・完了条件: 出力収集・プロセス終了・結果取得の順序と失敗条件を調べ、原因または再現条件を切り分けて対応要否を判断する。原因を確認できた場合は必要な修正と該当ケース・App tests の検証を行う。再現しない場合は試した条件と残る限界、対応判断を記録して完了とする。
  - 調査・対応（2026-10-02）: `tr a-z A-Z` に `original` を渡す直接実行で、逐次200回は成功、16並行×50回は `.emptyOutput` が1回発生した。一時 instrumentation で、callback が8 bytesを読み取って保存する前に finalize が空の結果を確定する順序を確認した。共通 collector の読み取り・保存・終了時回収を同じ Mutex で同期し、修正後の同条件1000回は全成功。過去 D4 / N10 の失敗時の順序と N10 差分との因果は未確認。
  - 検証: Package tests 332件・対象ケースを含む App tests 218件、`build_macos`、`build_run_macos` が成功。入力パネルからの `original` → `tr a-z A-Z` → `ORIGINAL` の反映はユーザー本人が確認した。stdout / stderr の pipe 容量を超える出力の全量・順序と既存の空出力・非0終了・timeout を検証した。詳細ログは一時 workflow artifacts に保存した。

- [x] N12 入力パネルの本文・選択・履歴を検証する App tests の初回失敗原因を調査する
  - 目的・根拠: D13 の初回 App tests は215件成功・3件失敗、コード変更なしの再実行は218件成功だった。`accessibilityFailureRehydratesEditorForImmediateRetryWithoutRestartingVoiceInput`、`accessibilityFailureRetriesSameTargetWithoutRestartingVoiceInput`、`shortcutRFallsBackToScriptWhenNoRules` で本文・選択・履歴の不一致を観測した。製品不具合や D13 試作との因果は未確定。[`InputPanelControllerConfirmTests.swift`](../KoechoTests/InputPanelControllerConfirmTests.swift)、[`InputPanelControllerReplacementTests.swift`](../KoechoTests/InputPanelControllerReplacementTests.swift)。
  - 作業・完了条件: focus、非同期処理完了、テスト間状態の関与を切り分け、原因または再現条件と対応要否を記録する。確認した原因に必要な対処だけを行い、対象ケースと App tests を検証する。再現しない場合は試した条件と残る限界を記録して完了とする。N11 と同じ原因が確認できた場合は作業を統合する。
  - 元結果の確認（2026-10-02）: D13 初回の xcresult（2026-10-01 03:31:14 UTC、macOS 27.0 / 26A428、arm64e）から、retry の履歴は期待 `["こんにちは"]` に対して `["い"]`、rehydrate は本文 `"b"`・editor `"bあn"`・選択 `{3,0}`（期待 `"こんにちは"`・`{5,0}`）、shortcut は期待 `"script output"` に対して空文字だった。rehydrate の firstResponder assertion は失敗していない。focusSink を NSHostingView に直接追加する既存 test に runtime warning はあるが、これだけで本文変更の原因とは断定しない。
  - 未再現の条件・検証: N11 修正後の HEAD `660ccc8`、Debug / Koecho scheme、同じ macOS・architecture、XcodeBuildMCP `test_macos` で対象3件の組合せを2回（各3件成功、3.520秒 / 3.327秒）、各ケースを別 host で単独1回（rehydrate 1件成功3.321秒、retry 1件成功3.181秒、shortcut 1件成功3.218秒）、通常の全 App tests を2回（各218件成功、12.711秒 / 11.160秒）実行した。各ケースは計5回成功し、失敗・hang は再現しなかった。最初の focused 指定は Swift Testing の case ID の `()` 欠落で実行0件（6.809秒）だったため検証回数に含めず、正しい ID で実行し直した。raw tool 結果・build log・xcresult summary と元失敗 activities は一時 workflow artifacts に保存した。
  - 切り分け・対応判断: suite は既に直列化され、AppState / UserDefaults / HistoryStore と mocks はケースごとに分離されるが、他 suite は並行実行され、AppKit の focus・runloop は共有する。単独と全 suite の双方で未再現のため、test 間干渉を排除したとはいえない。show は editor 未接続時に Task で初期化し、confirm は非空の editor を優先する一方、対象 confirm tests は AppState を直接設定して単発 yield に依存する。同期完了の保証不足は候補だが、元の `"い"` / `"bあn"` を生成する順序や外部入力の有無は観測されていない。shortcut は既に task 完了を await し、script 失敗時は元本文を復元するため、空文字だけから N11 の出力欠落と同じ原因とは判断できず、統合しない。原因未確認のまま production / test に sleep・retry・防御的修正を追加せず、未再現として調査を完了する。
  - 限界: 元 run の editor 書き込み・入力イベント・非同期処理の時系列記録はなく、過去 D13 試作との因果、focus / SwiftUI 同期 / test 間状態の原因特定は未完了。有限回の自然実行で schedule を強制していないため再発しない保証ではない。production / test は変更しておらず、N11 の本人 script 操作確認を N12 の focus / retry 実操作証拠へ転用していない。

- [x] N13 SpeechAnalyzer の finalize 失敗を診断記録で区別できるようにする
  - 目的・根拠: 従来は stop の finalize が timeout 前に失敗すると、`TaskTimeout` の `try?` によりエラーが破棄され、成功と同じ終了記録になっていた。実際の失敗頻度や最終テキスト欠落は未確認だが、終了異常を切り分ける診断情報が欠けていた。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)、[`TaskTimeout.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/TaskTimeout.swift)。
  - 作業・完了条件: finalize の成功・cancel・timeout・その他の失敗を必要な診断情報で区別し、既存の stop 完了・結果収集契約を維持する。失敗経路と通常停止を `docs/rules/verification.md` の必須 gate に従って検証する。UI 通知や停止方針の変更は含めない。
  - 実装・自動検証（2026-10-02）: `TaskTimeout.wait` が完了の `Result` または timeout を一度だけ返し、finalize の成功・`CancellationError`・timeout・その他失敗（error domain/code を含む）を既存 Logger で識別する。finalize timeout 時の cancel、resultTask の独立した1秒待機、tearDown、idle 到達は維持。成功・cancel・固有情報を持つ失敗・制御された未完了 task の timeout と遅い完了を下位層4テストで確認。`swift test --package-path Packages/KoechoKit` は217テスト成功（3.58秒）、XcodeBuildMCP `build_macos` 成功（5.3秒）、`build_run_macos` 成功（2.027秒）。
  - 実環境検証（2026-10-03）: 同一署名・固定パスの `com.ryotapoi.Koecho.Verification` を再ビルド・起動（3.425秒）し、本人が日本語発話→Confirm→末尾貼付・パネル閉・次の認識開始を「バッチリ」と報告。所有PID49732の診断ログで00:36:13.023の末尾を含む確定結果、00:36:18.966のfinalize成功、00:36:18.967の停止完了、00:36:23.611の次の認識開始を確認。本人報告とOS診断ログを別の証拠として照合し、確認後は所有アプリとログ収集を終了した。
  - 限界: 本人操作の正確な時刻は不明（上記はログ時刻）。cancel・timeout・その他失敗の識別は下位層テストの証拠であり、実マイクの異常を人工的に発生させていない。実際の finalize 失敗頻度や過去のテキスト欠落の不存在、個別TCCエントリの対象・全権限の維持までは確認していない。

- [x] N14 ScriptRunner の環境変数除外テストを親環境に依存しない検証にする
  - 目的・根拠: `doesNotLeakTCCVariables` は親環境に禁止変数がないと除外漏れを検出できず、PATH / HOME の継承確認も親に存在する場合だけ実行する。production の除外処理は存在し、実際の変数漏れを確認したものではない。[`ScriptRunnerTests.swift`](../Packages/KoechoKit/Tests/KoechoCoreTests/ScriptRunnerTests.swift)。
  - 作業・完了条件: 禁止変数が存在する入力で子への除外と許可変数の継承を確認し、除外処理を欠く誤実装を検出できることを示す。既存 suite や並列実行の環境を汚染しない方法を使い、関連テストを検証する。
  - 完了・検証（2026-10-03）: 共通の `makeProcess` に固定の親環境 fixture を渡し、構成済み環境と実子の出力で非空の `__CF_*`・許可外変数の除外、PATH / HOME の継承を無条件に確認。親環境を全継承する一時 mutation は実子の禁止キー不在 assertion で失敗し、ソース復元後の Package 217 テスト（通常の並列実行）、関連 16 テスト、XcodeBuildMCP `build_macos` / 専用署名 `build_run_macos` が成功。global environment は変更していない。証拠: `tmp/workflow/followups-20261002/n14/changes/n14/validation/`。
  - 限界: アプリ起動と子プロセスの環境契約検証は別の証拠。UI・マイク・権限操作は追加せず、TCC 全体・未知の OS 追加変数・ユーザー固有 script は未検証。

### 将来の改善（低優先度）

[backlog/later.md](later.md)
