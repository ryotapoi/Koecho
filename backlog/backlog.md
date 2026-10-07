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

- [x] N15 履歴の保存先を実行アプリの Bundle ID に合わせる
  - 目的・根拠: [`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift) は `com.ryotapoi.koecho` を固定しており、既に別 Bundle ID の通常版と検証版が同じ履歴を読み書きしている。通常版の Bundle ID は `com.ryotapoi.Koecho`、検証版は `com.ryotapoi.Koecho.Verification`。Bundle ID・署名・設定の分離を変更する作業ではなく、履歴の保存先をその識別に合わせる。
  - 実装方針: App 側で `Bundle.main.bundleIdentifier` を取得し、FileManager が返す Application Support にその値を付加して `history.json` の保存先を作る。Bundle ID の文字列をコード内の別定数として重複定義せず、大文字小文字も取得値を維持する。HistoryStore の既存の保存先注入を利用し、テストでは専用ディレクトリを渡す。[Apple の実装例](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html)を参照。
  - 作業・完了条件: 通常版の既存の小文字パスから履歴を引き継ぎ、大文字小文字を区別する環境と区別しない環境の両方を考慮する。検証版は通常版の既存履歴を取り込まず、読み込み・起動時整理・追加・削除が検証版の保存先だけに作用することを確認する。保存先の正本と検証スキル・helper の共有履歴に関する記述・条件を実装に合わせて更新する。
  - 完了・検証（2026-10-06）: App の実行 Bundle ID から保存先を注入し、通常版限定のファイル移行と失敗保護、hosted test の一時ディレクトリ隔離を実装。case-insensitive APFS と専用 case-sensitive HFS+ image で移行・再読み込みを実測し、既存新履歴優先・破損旧履歴・移行失敗・検証版の全履歴操作の隔離を回帰テストで確認。Package 308件、KoechoTests 204論理test / 210case、build、helper 9件が成功（全失敗・残留0）。専用署名版の起動後に検証版保存先の history.json 作成と通常版/旧パスの hash・mtime 不変を確認し、所有PIDのみ停止。UI・TCC・マイク・ペーストは今回未検証。証拠: `tmp/workflow/n15-20261006/changes/n15/`、`tmp/verification/cli/n15-*`、`tmp/verification/verify-koecho/n15-launch/`。

#### 機能改善

[機能改善](v2.0.0-features.md)

#### 実行結果のフォローアップ

[実行結果のフォローアップ](v2.0.0-followups.md)

#### 置換 UI の見直し

F8・個別置換 UI・F21 は対応済み。以下の未完了タスクで、置換操作への到達性と手動置換の契約を見直す。完了済み項目の記述は、その変更時点の契約と検証記録として保持する。

- [x] F8 置換後の挿入位置とプレビューを最終本文の座標に合わせる
  - 完了（2026-10-07）: 登録順の各置換で UTF-16 の挿入位置を対応させ、削除一致の内側は削除開始位置へ写す。preview は元本文の範囲に連鎖後の最終内容を表示する。契約は[置換ルール仕様](../docs/specs/replacement-rules.md#入力中の安全分岐と-preview)へ反映済み。
  - 検証: 四例の Core 回帰、Service から実 NSTextView の選択と後続 volatile / final callback への接続、Package tests 312件・App tests 207件・通常 build が成功。本人が四例の本文と挿入位置、marked preview の最終 x と本文非破壊性、連鎖・削除後の実音声挿入を確認した。一部は案内への返答を文脈で判定し、原文と判断を `tmp/workflow/orchestrator-replacement-ui-20261006/changes/F8/manual-results.json` に保存した。
  - 後続: F8 完了時点では個別置換 UI は未完了だった。連鎖 preview の元範囲は個別ルールの編集範囲と同一ではないため、後続 UI ではそのまま流用しない。

- [x] 置換候補の下線表示と1か所だけの置換を導入し、Tooltip を廃止する
  - 完了（2026-10-07）: 現本文の単独候補へ hover なしの下線を表示し、右クリックの「この箇所を置換」で1件だけ編集する。長さ変更後の選択・音声挿入位置を補正し、本文/ルール/設定変更と音声 final で候補更新する。Tooltip と専用 tracking を廃止した。契約は[置換ルール仕様](../docs/specs/replacement-rules.md)へ反映済み。
  - 検証: Package tests 316件・App tests 209件（215実行）・通常 build・専用署名 build が成功。本人が複数候補/伸長/Unicode 前方編集/全文 Replace と shortcut/単発後実音声位置/通常候補の実 volatile 消去復帰/削除/auto on の即時置換と実 IME 下線・確定削除を肯定した。包括的・番号付き返答を文脈で判定した項目の原文と限界を `tmp/workflow/orchestrator-replacement-ui-20261006/changes/replacement-ui-single/manual-results.json` に保存。専用版の所有 PID を cleanup 済み。
  - F21 の限界: 本人環境では右クリックまたは実音声入力時に IME が確定するため、marked と volatile の同時 OS 描画は観測不能/未確認。通常候補の実音声 lifecycle と、programmatic marked→volatile 回帰を区別して `f21-verification-evidence.json` へ保存。証拠照合と完了判断は下記 F21 の記録を参照。
  - 目的: 自動置換では変化の速い本文に Tooltip を表示せず、手動置換では利用者が必要な候補だけを選んで置換できるようにする。
  - 自動置換 on: Tooltip を廃止する。候補の下線はポインタを重ねずに表示する。既存描画を利用するなど無理のない実装で可能な場合に採用し、下線のために置換を遅らせない。下線を表示できなくても完了を妨げない。
  - 自動置換 off: 候補に下線を表示し、候補の右クリックから「この箇所を置換」を選ぶなどの明示操作で、その1か所だけを置換する。同じ文字列の別の出現箇所や他の候補は変更しない。既存の Replace ボタンによる全体置換は維持する。
  - 実装時の確認: 下線描画と Tooltip の tracking は分離できる。個別置換では表示中の本文に対応する正確な候補範囲を使い、本文変更後は候補を更新する。連鎖置換の preview 用範囲をそのまま編集範囲として使わない。IME・音声の未確定部分は確定するまで変更しない。
  - 作業・完了条件: Tooltip が出ないこと、採用した下線が hover なしで表示されること、個別操作が選んだ1か所だけを変更すること、全体置換が維持されることを確認する。複数の同一候補、長さの変わる置換、本文編集後の候補更新を確認する。仕様の正本と関連テストを更新し、実 IME・音声操作で確認する。F8 の座標対応を利用し、F21 の preview 消去要件を引き継ぐ。
  - 対象範囲: 個別置換は入力パネルの確定・貼り付け操作とは別の操作である。今回の依頼は個別操作の対象を1か所に限定することであり、確定・貼り付け時の既存の置換契約を変更する判断は含めない。

- [x] F21 未確定音声の表示開始時に既存の置換 preview を消去する
  - 完了（2026-10-07）: 個別置換 UI Change の実装と保存済み証拠を現コード・テストへ照合した。Coordinator と実 TextView が非空 volatile 挿入前に候補・操作 callback を消去し、Service は volatile 中の再表示を抑止する。通常 marked preview と volatile 終了・final 後の本文状態に応じた候補復帰を維持する。旧 Tooltip・専用 tracking は UI Change で廃止済み。
  - 検証: App tests 209件（215実行）・Package tests 316件・通常 build が成功。mock marked→Coordinator volatile の消去/final 復帰回帰と実 TextView の volatile 開始による候補 action 失効回帰を確認した。本人は実 IME 下線・確定削除と、通常候補の実音声 volatile 中下線消去/確定後復帰を文脈肯定した。証拠は `tmp/workflow/orchestrator-replacement-ui-20261006/changes/replacement-ui-single/f21-verification-evidence.json` と同ディレクトリの `manual-results.json` に保存。
  - 残存する限界と判断: 本人環境では音声開始で IME が確定するため、marked+hardware volatile の同時 OS 描画は未観測。本人確認は包括的返答中心で個別画像・認識本文は未受領。programmatic 回帰は状態境界、実 TextView 回帰は操作失効を検証し、下線 pixels や同時 OS 描画の実測 pass とは扱わない。自システムの消去境界と通常候補の実音声描画 lifecycle を別々の証拠で裏付けているため、この未観測は完了を妨げる残件とは判断しない。
  - 目的・発生条件: IME marked text の置換 preview が表示される間に音声 volatile が届く。両入力は同じ editor を使用でき、直接 storage 挿入は通常 onTextChanged による Service 経路を通らない。
  - 発見時の根拠: `KM-02-C04`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):249-278; [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift):84-102,194-207,304-337; [`ReplacementService.swift`](../Koecho/ReplacementService.swift):20-33; [`replacement-rules.md`](../docs/specs/replacement-rules.md) volatile 中は preview を消去する契約。非空 volatile callback で既存 preview を消す呼び出しがない。setVolatileText の storage 変更は suppression 内で、previewMatches/tracking/tooltip を保持する。
  - 作業・完了条件: IME marked text の preview 表示中に非空 volatile が届くと、highlight・tracking・tooltip が消え、volatile 中に置換 preview が残らないことを既存テストと実 IME・音声操作で確認する。通常 marked preview を維持する。
  - 発見時の限界: 実 IME と音声の同時描画未実施。古い range がどの文字へ描画されるかは挿入位置・本文長次第。
  - 対応方針（2026-10-05）: 本グループの UI 導入と重なる preview lifecycle は、新しい表示・個別置換仕様と合わせて扱う。現仕様向けの試行では App tests 197件と build が成功し、本人が実 IME・音声の概略動作を確認したが、下線・Tooltip 消去の個別確認は未完了。試行の証拠は tmp/workflow/orchestrator-normal-20261004-next/changes/F21/ に保持する。
  - 関連・順序: UI 導入と一緒に扱い、単独では旧 Tooltip 仕様の修正を進めない。Tooltip 廃止後は残る候補下線・表示状態について、volatile 開始時の消去と通常候補表示の復帰を確認する。

- [ ] 置換操作と Add Replacement Rule を右クリックメニューの先頭へ移す
  - 目的: 頻繁に使う置換操作を、通常の編集メニューの末尾まで移動せず選べるようにする。
  - 方針（2026-10-07）: アプリの項目を「置換操作 → Add Replacement Rule… → 区切り → 通常のメニュー」の順に置く。置換操作はその時点の対象に応じた「この箇所を置換 / 選択範囲を置換」の表示を使う。AppKit の NSMenu への先頭挿入で実現し、通常のメニュー項目は維持する。
  - 作業・完了条件: 候補上・範囲選択中・両項目が出る場合に、表示対象のアプリ項目が上記の順で先頭に並ぶことを実画面で確認する。既存の表示・実行条件を保ち、重複項目や不要な区切りを追加しない。選択範囲に対する置換の振る舞いは、次のショートカット変更タスクと整合させる。

- [ ] 置換ショートカットをカーソル位置・選択範囲への操作に変更し、Replace ボタンを削除する
  - 目的: 手動置換を対象候補への右クリックまたはショートカットで行い、全文置換専用のボタンをなくす。マウスでボタンへ移動する操作は、対象上の右クリックで代替できるため維持しない。
  - 方針（2026-10-07）: 既存の置換ショートカット（既定 Control-R、変更・無効化可能）を対象限定の操作にする。選択がなければカーソル位置の候補1件、範囲選択があればその範囲に完全に含まれる候補をすべて置換する。全選択で実質的な全候補置換ができる。Replace ボタンを削除し、全文置換専用のショートカットは残さない。
  - 対象の契約: `ABCDEFGHI` の `DEF` が候補なら、D の直前・D/E 間・E/F 間・F の直後のカーソルでその候補を置換できる。範囲に一部分だけが重なる候補は編集しない。対象候補がなければ本文を変更しない。隣接候補の境界で複数が該当する場合の選び方は実装時に明文化し、1件だけを選ぶ。
  - 適用の契約: 操作開始時の現在本文にある候補を対象にし、1回の操作では後続ルールを連鎖適用しない。生成された新候補は再表示し、次の明示操作で扱う。候補の登録順優先を維持し、選択範囲・後続音声の挿入位置を長さ変更や削除に対応させる。IME・音声の未確定部分は変更しない。
  - 作業・完了条件: 上記カーソル境界、複数候補の完全包含・部分重なり・全選択、長さ変更・削除・連鎖、本文編集後の候補更新、後続音声位置を既存テストと実操作で確認する。ショートカットの変更・無効化を維持し、Replace ボタンと不要な接続・表示資産を削除する。選択範囲の右クリック置換も同じ対象・適用規則に揃え、仕様の正本と関連テストを更新する。

- [ ] Auto-replace off では確定・貼り付けを含む自動置換を行わないようにする
  - 目的: Auto-replace off を「自動では置換しない」という意味に揃え、利用者が残した候補を確定時に勝手に変更しない。
  - 方針（2026-10-07）: off では通常入力・音声確定・Confirm・貼り付け・ルール追加や設定変更に伴う自動的な本文置換を行わない。候補下線は維持し、右クリックや対象限定ショートカットによる明示的な置換だけを行う。ルール追加そのものを本文置換の指示として扱わない。on の既存の自動置換は維持する。
  - 作業・完了条件: off で未適用候補を残して Confirm すると、音声・IME の確定後の本文が置換されずに貼り付けられ、auto-run script にも置換前の本文が渡ることを確認する。明示操作で一部だけ置換した場合も、残った候補を確定時に変更しない。ルール追加・設定更新時の本文非変更と on の既存挙動を確認する。trim・空本文・script・貼り付けの既存契約は維持し、仕様の正本と関連テストを更新する。

#### 通常対応

[通常対応（完了済み）](v2.0.0-normal-completed.md)

#### 高難度対応

- [ ] F1 キャンセル前のスクリプト結果が再表示後の入力セッションへ反映されないようにする
  - 目的・発生条件: 遅い手動スクリプトまたは auto-run の実行中に Escape でキャンセルし、完了前にパネルを再表示すると、新しい本文・prompt が旧結果や旧本文で上書きされる。auto-run では別の対象アプリへ旧本文を貼り付け、履歴にも記録し得る。
  - 根拠: `KM-01-C04` / `KM-04-C01`。`R02-C01` / `R06-C01`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の cancel は実行を無効化せず、[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift) の再表示は visibility・対象アプリ・本文を更新する。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) と confirm の await 後は現在の visibility だけで旧処理の結果を受け入れ、手動処理の cleanup は新しい prompt・実行フラグも消す。paste は現在の対象アプリを使う。
  - 作業・完了条件: キャンセル前の処理完了が再表示後の本文・prompt・Undo・実行状態を変更せず、auto-run の旧結果を新しい対象へ貼り付けたり履歴へ追加したりしないことを確認する。手動・auto-run の成功と失敗、再表示後に新しい処理を始めた場合を既存のテストと実操作で確認する。
  - 限界: 実行未確認。旧処理が完了する前に再表示するタイミングが条件。2候補の auto-run 部分は同じ問題として統合した。

- [ ] F3 スクリプト実行待機中の音声入力を停止して本文の競合を防ぐ
  - 目的・発生条件: 音声入力を有効にしたまま追加入力なしの custom スクリプトを実行し、実行中に話し始めて成功時にも volatile text が残ると、加工結果が表示されず後続の音声確定で失われる。
  - 根拠: `KM-02-C08` / `KM-04-C03`。`R03-C01`。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) は開始時にだけ volatile を除去し、成功結果を AppState へ設定する。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) は実行中も音声プレビューを挿入し、[`VoiceInputTextEditor.swift`](../Koecho/VoiceInputTextEditor.swift) は volatileRange があると結果の表示同期を抑止する。その後の確定音声が古い表示本文を AppState へ書き戻す。
  - 対応方針: 実行前の追加入力中は音声入力を許可する。custom スクリプトの実行開始時に既存の未確定音声を本文へ取り込み、音声入力を停止して実行対象を固定する。実行待機中は既存のキーボード編集無効化と合わせて本文への入力を止め、加工結果と並行発話を合成する仕組みは作らない。
  - 作業・完了条件: 手動実行の成功・失敗後は、同じ入力セッションが表示中かつ音声入力が有効な場合だけ認識を再開する。確定時 auto-run の待機中も新しい音声を受け付けない。音声停止待ち・実行待ち中の Escape、再表示、音声無効化で旧処理が本文を書き換えたり認識を再開したりしないことを F1 と整合させて確認する。既存テストと実音声・遅いスクリプトで結果保持と再開を確認する。
  - 限界: 実画面未確認。成功後の SwiftUI 同期より先に finalize が来る場合もあり、全実行で必ず起きるとは判断していない。

- [ ] F4 終了した音声開始処理が await 復帰後にマイクを起動しないようにする
  - 目的・発生条件: パネル表示直後のマイク許可・モデル準備・音声 format 決定待ち中に Escape、確定、Voice 無効化を行うと、終了後の処理がマイクや認識リソースを起動し得る。
  - 根拠: `KM-03-C01`。`R04-C01`。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の startRecognition は await 後に取消・state を確認せず、session activate・exclusive access acquire・audioEngine.start へ進む。cancel は既存フィールドを破棄するが開始 Task 内の self・ローカル engine は残る。[`SpeechModelPreparation.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechModelPreparation.swift) の検証済み early return も取消を確認しない。stop の開始待ち timeout 後も後続起動を防げない。
  - 作業・完了条件: 開始待ち中の取消・確定・無効化・停止 timeout 後に処理が復帰しても、マイクと認識リソースが再起動せず、終了状態とリソース状態が一致することを確認する。待機と終了の順序を確認し、実環境で開始途中の終了と次の開始を確認する。
  - 限界: OS の await が取消に応じて返す値、実録音継続時間、hardware 挙動は未確認。許可・モデル・format が成功して復帰する経路を静的に確認した。

- [ ] F9 保存済みマイクの再接続後にメーターと入力音量の対象を一致させる
  - 目的・発生条件: 保存済み外部マイクが切断中に Settings を開き、別の system default を変えずに再接続すると、Picker は外部マイクを示す一方、メーターと音量 slider は既定マイクに残る。
  - 根拠: `KM-03-C03`。`R05-C02`。[`AudioDeviceSelection.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceSelection.swift) の fallback は effectiveUID=nil となり、[`AudioDeviceManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift) は元の requested UID を失う。デバイス一覧更新は選択対象を再解決せず、[`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift) の選択 UID も変わらないため再開せず、音量書き込みも fallback の対象を使う。
  - 作業・完了条件: Settings を開いたまま保存済みマイクを再接続した後、表示・レベルメーター・入力音量の対象が選択マイクに一致することを確認する。切断時の fallback を維持し、対象解決を既存テストと実デバイスの切断・再接続で確認する。
  - 限界: hardware 再現未確認。system default が変わらず View も再表示されない条件。既存 D2 の fallback 注意表示の検討とは別に扱う。

- [ ] F10 音声認識終了後に開いたままの入力レベルメーターを再開させる
  - 目的・発生条件: Settings のマイク設定を開いたまま入力パネルで認識し、確定または Escape で閉じると、利用可能になったマイクのメーターが0のままになる。認識中に Settings を開いた場合も該当する。
  - 根拠: `KM-03-C04`。`R05-C01`。[`AudioInputExclusiveAccess.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputExclusiveAccess.swift) の acquire は monitor を止めるが release は isInUse を戻すだけ。[`AudioInputLevelMonitor.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputLevelMonitor.swift) の開始は使用中 guard で返り、[`AudioDeviceManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift) と [`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift) には release に応じた再開経路がない。
  - 作業・完了条件: 認識終了後、ページ再表示や選択変更を行わずメーターが再開することを確認する。認識中の排他を維持し、Settings を先に開く場合と認識中に開く場合の双方を既存テストと実マイクで確認する。
  - 限界: hardware 実測未確認。監視停止と再開契機の欠如を静的に確認した。

- [ ] F17 認識言語切替中の取消が切替後の音声開始も無効にする
  - 目的・発生条件: 音声入力中にメニューバーの言語を変更し、stop の await 中に Escape する。言語変更 task は cancel されずその後継続する。
  - 根拠: `KM-01-C06` / `KM-02-C06`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift):37-46; [`InputPanelController.swift`](../Koecho/InputPanelController.swift):259-275; [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):93-111; [`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift):81-118。switchEngine は await 前にだけ visibility を確認し、coordinator は stop 後に無条件で engine 再生成/start する。待機中の cancel は当時の旧 engine を対象とし、新 engine に届かない。
  - 作業・完了条件: 言語切替の stop 待機中に Escape した後、新しい engine が開始せず、非表示のままマイクが起動しないことを確認する。通常切替と次回パネル表示を既存テストと実マイクで確認する。F4 の engine 内開始待ちとは別の、coordinator の停止→再生成経路を対象とする。
  - 限界: 実マイクと UI の時系列は未実施。start 成功は権限・モデル・デバイスが利用可能なことが条件。

- [x] F29 hosted test の App 初期化から通常版の設定を隔離する
  - 目的・発生条件: project で KoechoTests は通常 app bundle ID com.ryotapoi.Koecho の Koecho.app を TEST_HOST として使い、verification.md も hosted test が app lifecycle を起動することを明記する。通常ユーザーの domain に値がある状態でこの hosted test を実行すると、テストメソッドによる隔離 factory 利用の有無によらず App 初期化から到達する。
  - 根拠: `KM-07-C01` / `KM-08-003`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift):9-20；[`AppState.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift):28-29；[`Settings.swift`](../Packages/KoechoKit/Sources/KoechoCore/Settings.swift):24-27；[`ScriptSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift):68-76,98-100,134,173-193；[`VoiceInputSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift):58-83,98-106；[`project.pbxproj`](../Koecho.xcodeproj/project.pbxproj):448,482,510,531；[`TestSupport.swift`](../KoechoTests/TestSupport.swift):8-13；[`verification.md`](../docs/rules/verification.md):25。KoechoApp の stored @State 初期値 AppState() は init の isTesting guard に先行する。AppState は Settings() を生成し、.standard を feature 設定へ渡す。VoiceInputSettings と ScriptSettings は init 内で save し、不正 timeout の補正、voice mode の正規化、壊れた shortcut の encoded nil への書戻し等を行う。test factory による suite 隔離はその前の App 初期化には適用されない。
  - 作業・完了条件: test factory 使用前の KoechoApp / AppState / Settings 初期化も専用 domain へ隔離し、文書化された KoechoTests の起動だけで通常版の設定を読み書き・正規化しないことを確認する。不正 timeout・旧 voice mode・壊れた shortcut を含む通常 domain の保存値が維持され、test 設定が専用 domain へ保存されることを安全な fixture で検証する。hosted test の起動時挙動を [Verification](../docs/rules/verification.md) の隔離説明と整合させる。
  - 完了: `KoechoApp.makeInitialAppState` が Settings 生成前に既存の XCTestCase 判定で起動ごとの専用 suite を選ぶ。通常起動は `.standard` を維持する。安全な2つの disposable domain による回帰テストで、不正 timeout・旧 voice mode・壊れた shortcut の値と型の保持、通常側だけの device sentinel の非読込、テスト側の初期保存・更新、通常経路の既存正規化を確認した。XcodeBuildMCP `build_macos`、`test_macos -only-testing:KoechoTests`（197件）、Package `swift test`（192件）が成功（2026-10-05）。
  - 検証範囲: 実 hosted run で XCTestCase 判定成立と同じ初期状態構築経路を確認した。実ユーザー domain へ異常 fixture を投入する実験は行わず、通常相当の専用 domain で代替した。HistoryStore のファイル保存先隔離は対象外。

#### 調査後に改修規模・リスクを判断する

実装範囲・改修規模・既存動作へのリスクを調査し、対応するかと対応範囲を判断してから着手する。以下の完了条件は、改修を採用した場合の条件とする。

- [x] F5 子プロセスが出力パイプを保持してもスクリプト timeout を完了させる
  - 目的・発生条件: シェル複合コマンドやパイプラインの子が stdout / stderr を保持すると、shell 終了後も EOF 待ちで timeout が失効していた（`KM-04-C02`、`R06-C02`）。
  - 完了: [ScriptRunner.swift](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) の出力を非 blocking read で回収し、shell 終了と両 EOF が揃うまで期限を維持する。timeout 後は既存 TERM / KILL 猶予の範囲で子の EOF を待たずエラーを一度だけ返し、timer / collector callback の所有を解除する（2026-10-05）。
  - 検証: 実 Runner の timeout=0.2秒 / killDelay=0.1秒で `sleep 2 & printf done` が0.204秒で timeout、shell が期限まで生存し子が stdout / stderr の片方だけを保持する場合も約0.204秒で timeout。通常全量・順序・stderr・stdin・environment・cwd・KILL回帰を含む Package193件、build、App199件が通過。manual の元本文、auto-run のtrim後fallback・error・running解除と次実行の成功、source hash付きweak観測でRunState/両collector解放・登録競合1000回を確認。
  - 実画面: 実controller/service/view/Runnerのsource同一性を記録し、専用defaults・historyの署名fixtureを使用。本人が通常Uppercase・失敗後の即再実行・概ね編集可能を明示し、両timeout手順を含む案内に対しCmd+A以外は大丈夫と文脈了承した。所有fixtureのみ停止済み。証拠: `tmp/workflow/orchestrator-20261005-f28-f5-f19-fresh/changes/F5/validation/`。
  - 限界: 本人報告は両case個別のcaption逐語記録・実測時刻ではなく手順全体の文脈確認。Cmd+Aはfixtureに標準Edit menuがない起動方式との差が説明候補で、製品bugとは未確定。通常版のTCC/hotkey/paste/mic維持は未確認。任意の子孫停止・外部作用取消・F19のEscape中断はこの完了の保証外。

- [x] F19 Escape の中断を実行中の外部スクリプトへ伝える
  - 目的・発生条件: 長い custom 手動実行または auto-run 中に Escape すると、パネル非表示に加えて実行中の外部 Process へ中断を伝える。
  - 実装: [`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) が実行 Task を所有し、[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の Escape から取消を伝える。[`ScriptRunner.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) は起動前・起動中の取消を受け、TERM と既存 killDelay 後の KILL で停止する。取消完了は子の pipe EOF や設定 timeout を待たず、取消された実行の結果・cleanup は次実行へ適用しない。
  - 検証: 2026-10-05 の署名付き隔離 SwiftUI fixture で本人が通常入力・編集・Cmd+A・Uppercase、manual と auto-run の Escape、再表示後の Uppercase を確認。manual PID 82084 は 13:13:34 開始→13:15:00 TERM、auto PID 92229 は 13:31:35 開始→13:35:43 TERM。両 PID の消滅を確認し、自然終了予定（各1200秒）・設定 timeout（1800秒）より前に停止した。auto-run は貼付け fake の呼出しなし・隔離履歴0件。Package 197件、KoechoTests 200件、build / build_run が成功。取消状態・TERM無視・EOF待ち・再実行の回帰と、source hash付き一時 harness で timer / collector 所有解除・完了後登録拒否を確認。証拠は `tmp/workflow/orchestrator-20261005-f28-f5-f19-fresh/changes/F19/validation/`。所有 fixture のみ終了済み。
  - 限界: 任意の子孫・daemon・別 session の停止や既実行の外部作用の巻き戻しは保証しない。通常版の TCC・mic・clipboard・実 paste・global hotkey は未検証。F1 全体は未完了で、今回の取消実行の直接的な干渉防止だけを扱う。

#### 調査・対応判断

発生条件・実環境での影響・対応要否を確認してから、修正・仕様整理・見送りを判断する。移動した項目の改修はまだ確約しない。

- [ ] F7 テキスト操作による認識再開中の発話欠落と対応要否を調べる
  - 目的・発生条件: 発話中にキーボード入力やカーソル移動を行うと、認識再開中の発話が取り込まれず音声入力が途切れる。
  - 根拠: `KM-03-C02`。`R04-C02`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) のテキスト操作は restartTranscriber へ到達する。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) は tap を除去し AVAudioEngine を停止した後、analyzer と旧 resultTask の終了を await し、その間の入力を保持しない。[音声テキスト仕様](../docs/specs/voice-input-text.md) は割り込み中も録音継続を求める。
  - 作業・完了条件: 実音声で認識再開時の録音停止時間・発話欠落を確認し、録音継続の改修または仕様整理・見送りを判断して記録する。改修を採用する場合は、テキスト操作に伴う認識再開中も録音が継続し、続けて話した部分を取り込めることを確認する。再開前後の結果同期を既存テストで確認し、実音声とカーソル移動・キーボード入力で仕様を確認する。
  - 限界: 実音声未確認。中断時間と欠落語数は OS・callback の進行に依存し未測定。既存 D1 の意図した反復発話と重複除去の判断とは別に扱う。

- [ ] F22 大量一致の置換の実処理時間と改善要否を調べる
  - 目的・発生条件: 5 万 UTF-16 程度のＡ，Ｂ；改行の1 万行を取り込み、，→,、；→;を Replace する。本文長制限はこの経路にない。preview も同関数を使う。
  - 根拠: `KM-02-C07`。[`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift):66-84,126-131; [`ReplacementService.swift`](../Koecho/ReplacementService.swift):6,36-42。delta=0 でも全 match の offset entry を保持し、後続 match 毎に先頭から2 回線形探索するため、各1 万一致の rule で約1 億 entry 訪問になる。MainActor の同期処理である。
  - 作業・完了条件: Release 条件と実パネルで処理時間・UI 応答を計測し、改善要否を判断して記録する。改善を採用する場合は、登録順・置換結果・座標対応を維持し、5 万 UTF-16 程度の「Ａ，Ｂ；改行」1 万行に ，→,、；→; を適用する場合の約1 億 entry 訪問を解消する。Release 条件の計測と実パネル操作で本文長・一致数に対する処理時間と UI 応答を確認し、preview 経路も同じ計算を使うことを照合する。F8 と同じ座標変換部分を触る場合は実装範囲を合わせる。
  - 限界: 原 Core 算法の logger を除去し最小型を使った Swift script で20000 match・3.44396 秒を観測した。非最適化環境の値であり Release アプリの待機時間とは扱わない。実アプリの Escape・描画待ち時間は未測定。

- [ ] F26 ペースト送信前の focus 変更による誤貼付と対応方針を調べる
  - 目的・発生条件: 通常 confirm はパネルを隠し可視状態を false にしてから paste を await する。この待機中にはユーザーが別アプリをクリックでき、singleToggle で再表示する経路も showPanel の isConfirming ガードがないため到達する。送信時に別の入力欄が focus を得て Cmd+V を受け付ける条件で、そこへ本文が渡る。
  - 根拠: `KM-05-C04`。[`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift):117-142；[`CGEventClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/CGEventClient.swift):24-37；[`InputPanelController.swift`](../Koecho/InputPanelController.swift):104-112,200-215；[`KoechoApp.swift`](../Koecho/KoechoApp.swift):193-204；macOS SDK CoreGraphics/Headers/CGEvent.h:347-354 は CGEventPost を event stream への post、:356-374 は特定アプリ向け post を別 API として定義している；[`scope.md`](../docs/rules/scope.md):32-35 はパネル表示前のアプリを記憶してペースト前に再 activate する契約。記憶した対象を activate した後に100ms の await があり、その後は対象や現在 focus を照合せず simulatePaste を呼ぶ。LiveCGEventClient は PID を指定せず Cmd+V を HID event stream へ post する。対象の貼付成功を確認する処理もなく、イベント生成が成功すれば caller は履歴を追加する。
  - 作業・完了条件: 実アプリで focus 切替時の配送を確認し、誤貼付の成立条件と最小の対策を判断して記録する。対策を採用する場合は、対象 activate 後の100ms 待機中に他アプリの入力欄へ focus を移した場合とパネルを再表示した場合に、記憶した対象以外へ本文を貼り付けたり成功として履歴に追加したりしないことを確認する。通常の対象アプリへの貼付を維持し、送信時の対象判断を既存テストと実アプリの focus 切替で確認する。
  - 限界: 実 OS で100ms 内の focus 切替と配送を再現していない。任意の別アプリが貼付を受け入れると断定せず、送信時にその入力欄が focus を持ち Cmd+V を受け付ける場合に限定する。発生頻度は未確認。

- [ ] F27 外部アプリの選択取得による UI 待機と対応要否を調べる
  - 目的・発生条件: Accessibility 権限を得た通常 showPanel 経路で常に外部 focus/selection を問い合わせる。最前面アプリが応答停止・長い処理待ちで AX 応答を返せない場合、パネル表示前に呼び出しスレッドが待つ。HotkeyService も main queue へ処理を配送するため、その間後続操作が処理されない。
  - 根拠: `KM-05-C05`。[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift):5,24-41；[`InputPanelController.swift`](../Koecho/InputPanelController.swift):90-117；[`SelectedTextReader.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SelectedTextReader.swift):25-39；[`AccessibilityClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AccessibilityClient.swift):17-42；[`HotkeyService.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift):83-85；macOS SDK HIServices/Headers/AXUIElement.h:38-39,145-148,388-402 は応答不能時の messaging failure と AX API timeout を説明する。MainActor 上の PanelLifecycleManager.show は makeKeyAndOrderFront より前に SelectedTextReader.read を同期実行し、LiveAccessibilityClient は外部アプリへの AXUIElementCopyAttributeValue を同期実行する。応答待ちの間は MainActor を解放しない。SDK は AX messaging に応答不能アプリと timeout が存在することを明記している。
  - 作業・完了条件: 実 AX 応答待ちの停止時間と操作への影響を確認し、待機上限の調整・非同期化・見送りを判断して記録する。改修を採用する場合は、最前面アプリが AX 応答を返さない場合でも、選択取得待ちの間にパネル表示・menu・hotkey 操作を処理できることを確認する。通常の選択本文取り込みと表示前アプリの記録を維持し、注入した遅い取得と実 AX 応答待ちを分けて検証する。
  - 限界: AX 実応答停止、既定 timeout 値、実際の停止秒数は測定していない。停止する長さは外部アプリと OS に依存し、全ての AX 呼び出しが遅いという主張ではない。

- [ ] F30 volatile がないカーソル割込みの buffer 未破棄に対応が必要か判断する
  - 目的・発生条件: `KM-02-C05` は `confirmed` / `uncertain`。確定音声 callback 後から次の volatile 到着前にカーソルを移す場合、buffer を破棄する仕様との差がある。利用者に見える再送・表示重複が起きるかを調べ、対応要否を決める。
  - 根拠: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):179-195,249-279 は volatileRange=nil なら挿入点だけを更新し restart を呼ばない。[`InputPanelController.swift`](../Koecho/InputPanelController.swift):414-416 から到達する。[音声テキスト仕様](../docs/specs/voice-input-text.md):11 と [ADR 0016](../docs/decisions/0016-accumulated-text-overlap-removal-for-speechanalyzer.md) を照合する。確定 callback には重複除去があるが volatile にはない。
  - 作業・完了条件: 対象 runtime の実 SpeechAnalyzer で提示のカーソル操作後に古い本文が volatile として再送されるか、表示への影響と頻度を確認する。条件・結果・限界を記録して修正／仕様整理／見送りの対応判断をもって完了とする。反復発話と重複除去を扱う [D1](#調査対応判断) の調査と観測を共有できるが、同じ原因とは未判定。
  - 限界: この条件での実再送・表示重複は未観測。仕様不一致だけから具体的な害や修正必要性を確定しない。

- [ ] N1 音声変換失敗時の対応要否を判断する
  - 目的・根拠: format / device 変更時に音声だけ落ちて listening 表示が残る可能性がある。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の変換失敗分岐が return のみ。
  - 候補方針: 音声変換に失敗した場合は音声入力をオフにし、失敗したことと、再度オンにすれば続けられる旨を説明する。ただし、この対応自体を採用するかは未決とする。
  - 作業・完了条件: 実環境と必要なテストで失敗の発生条件と頻度を確認し、その結果に基づいて候補方針を正式に採用するか見送るかを判断して記録する。

- [ ] D1 同じ言葉を意図して繰り返した発話を入力できるようにする
  - 背景・根拠: `SpeechAnalyzer` が別々に返す確定結果でも、蓄積済みテキストの末尾と新しい結果の先頭が重なると、現在は重複として後者から除去する。これはキーボード入力・カーソル移動の割り込み後に前セグメントが再配信される既知の問題への防御であり、ユーザーが同じ言葉を繰り返して入力したい意図を削除するためではない。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の `stripOverlappingPrefix`、[`voice-input-text.md`](../docs/specs/voice-input-text.md)、[ADR 0016](../docs/decisions/0016-accumulated-text-overlap-removal-for-speechanalyzer.md)
  - 例: 独立した確定結果が「あい」「あい」と続くと、現在は後者が除去される。将来は、認識結果の再配信と意図した反復発話を区別できるかを調査する。
  - 実装時の判断・確認: 実際の SDK・対応 runtime で `SpeechAnalyzer` の挙動を確認し、重複除去を外せるか、または対象を狭められるかを判断する。macOS 27 専用化および対応下限の変更は決定済みとし、ライブラリ側で解消済みかどうかは未決定とする。採用する範囲で必要な場合だけ仕様と確認項目を更新し、既存の手段で確認する。新しいテスト基盤は要求しない。
  - 補足: 現在の比較は最大 512 UTF-16 code units で、仕様には上限が明記されていない。この契約差は、反復発話と重複除去の振る舞いを決める際に併せて扱う。

#### その他

- [ ] hosted tests の自動生成 UserDefaults domain の後片付けを整える（低優先度）
  - 優先度・時期: hosted test の起動・隔離を次に扱う際に併せて対応する。通常版の設定隔離は F29 で対応済みであり、この残件だけを理由に開発・検証を止めない。
  - 根拠: [`KoechoApp.makeInitialAppState`](../Koecho/KoechoApp.swift) は起動ごとの UUID suite を生成するが、run との所有記録と終了時の削除は実装されていない。2026-10-06 の実行時間帯に該当 plist が6件あったが、その時間帯の全ファイルが今回の run のものとは確定できず一括削除していない。
  - 作業・完了条件: 起動が生成した domain を識別できるようにし、その domain だけを終了・後片付け時に削除する。通常版と別 run の設定を維持し、通常終了と中断後の回収で残存・削除対象を確認する。UUID の共通 prefix による一括削除はしない。F29 の隔離契約と [検証ルール](../docs/rules/verification.md) を維持する。

- [ ] D2 非ブロッキングの注意 UI を検討する（低優先度）
  - 現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)
  - 2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する
  - 2026-09-18 判断: モーダル alert や操作中断は行わず、録音・編集を継続できる注意 UI とする。表示位置・意匠は今後決める。今回は実装しない。
  - 現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける
  - 選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する
