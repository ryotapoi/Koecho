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

#### 実行結果のフォローアップ

[実行結果のフォローアップ](v2.0.0-followups.md)

#### 全体レビューの修正候補

2026-10-03、開始時 HEAD `af41702d74bc79a4cedc71b1bd8c8ab973bfefc5` の全体レビュー（Sol による12担当の simple review と Sol verifier）で、以下の候補は静的に `confirmed` / `actionable` と判定した。実行再現・発生頻度は未確認で、導入時期も判定していない。着手時に現在の実装で成立条件と変更範囲を再確認してから修正する。成立しなければ、その根拠と見送り判断を記録して完了とする。

各タスクの検証は [Verification の必須 gate](../docs/rules/verification.md) に従い、変更箇所に応じた build / test と、OS・外部環境に依存する対象操作の実環境確認を行う。

##### 先に扱う

- [ ] F1 キャンセル前のスクリプト結果が再表示後の入力セッションへ反映されないようにする
  - 目的・発生条件: 遅い手動スクリプトまたは auto-run の実行中に Escape でキャンセルし、完了前にパネルを再表示すると、新しい本文・prompt が旧結果や旧本文で上書きされる。auto-run では別の対象アプリへ旧本文を貼り付け、履歴にも記録し得る。
  - 根拠: `R02-C01` / `R06-C01`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の cancel は実行を無効化せず、[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift) の再表示は visibility・対象アプリ・本文を更新する。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) と confirm の await 後は現在の visibility だけで旧処理の結果を受け入れ、手動処理の cleanup は新しい prompt・実行フラグも消す。paste は現在の対象アプリを使う。
  - 作業・完了条件: キャンセル前の処理完了が再表示後の本文・prompt・Undo・実行状態を変更せず、auto-run の旧結果を新しい対象へ貼り付けたり履歴へ追加したりしないことを確認する。手動・auto-run の成功と失敗、再表示後に新しい処理を始めた場合を既存のテストと実操作で確認する。
  - 限界: 実行未確認。旧処理が完了する前に再表示するタイミングが条件。2候補の auto-run 部分は同じ問題として統合した。

- [ ] F2 音声終了待ち中の再確定で最終認識が欠落しないようにする
  - 目的・発生条件: auto-run 未選択で音声入力を確定し、最終結果を待つ間にホットキーまたは Command+Return で再確定すると、末尾を欠いた本文の貼り付けや空入力としての終了に至る。
  - 根拠: `R02-C02`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) は音声終了 await 前に isConfirming を立てず、[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の stop は .stopping への再入で即時に返る。二つ目の confirm がパネルを閉じると、[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の後続 didFinalize は非表示 guard で棄却される。
  - 作業・完了条件: 終了待ち中に繰り返し確定しても最終認識を含む本文が一度だけ貼り付けられ、空本文扱いで発話が失われないことを確認する。終了待ちと最終結果の順序を既存テストで確認し、実音声で連続確定を確認する。
  - 限界: 実行未確認。停止 await 中の追加確定より後に最終結果が届く順序が条件。

- [ ] F3 手動スクリプト中の未確定音声で成功結果が消失しないようにする
  - 目的・発生条件: 音声入力を有効にしたまま追加入力なしの custom スクリプトを実行し、実行中に話し始めて成功時にも volatile text が残ると、加工結果が表示されず後続の音声確定で失われる。
  - 根拠: `R03-C01`。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) は開始時にだけ volatile を除去し、成功結果を AppState へ設定する。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) は実行中も音声プレビューを挿入し、[`VoiceInputTextEditor.swift`](../Koecho/VoiceInputTextEditor.swift) は volatileRange があると結果の表示同期を抑止する。その後の確定音声が古い表示本文を AppState へ書き戻す。
  - 作業・完了条件: スクリプト成功結果が表示され、後続の音声確定で実行前本文へ戻らないことを確認する。本文 hello の加工結果 HELLO と実行中からの音声 world の順序を既存テストで確認し、実音声と遅いスクリプトでも結果保持を確認する。
  - 限界: 実画面未確認。成功後の SwiftUI 同期より先に finalize が来る場合もあり、全実行で必ず起きるとは判断していない。

- [ ] F4 終了した音声開始処理が await 復帰後にマイクを起動しないようにする
  - 目的・発生条件: パネル表示直後のマイク許可・モデル準備・音声 format 決定待ち中に Escape、確定、Voice 無効化を行うと、終了後の処理がマイクや認識リソースを起動し得る。
  - 根拠: `R04-C01`。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の startRecognition は await 後に取消・state を確認せず、session activate・exclusive access acquire・audioEngine.start へ進む。cancel は既存フィールドを破棄するが開始 Task 内の self・ローカル engine は残る。[`SpeechModelPreparation.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechModelPreparation.swift) の検証済み early return も取消を確認しない。stop の開始待ち timeout 後も後続起動を防げない。
  - 作業・完了条件: 開始待ち中の取消・確定・無効化・停止 timeout 後に処理が復帰しても、マイクと認識リソースが再起動せず、終了状態とリソース状態が一致することを確認する。待機と終了の順序を確認し、実環境で開始途中の終了と次の開始を確認する。
  - 限界: OS の await が取消に応じて返す値、実録音継続時間、hardware 挙動は未確認。許可・モデル・format が成功して復帰する経路を静的に確認した。

- [ ] F5 子プロセスが出力パイプを保持してもスクリプト timeout を完了させる
  - 目的・発生条件: シェル複合コマンドやパイプラインの子が stdout / stderr を保持したまま timeout すると、エラーと fallback が返らず実行中状態が続く。
  - 根拠: `R06-C02`。[`ScriptRunner.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) は shell の PID だけを停止する。terminationHandler は timeout / kill work を取消後、collectors.finalize の readDataToEndOfFile で EOF を同期的に待つため、shell 終了後も書き込み端を持つ子が残ると continuation を返せない。
  - 作業・完了条件: shell 終了後も子が pipe を保持するケースで timeout が完了し、エラーと fallback が返って入力パネルが操作可能になることを確認する。子の pipe 保持を含む実コマンドで所要時間と結果を確認し、既存の通常出力回収・timeout の保証を維持する。
  - 限界: OS 上の Process / shell のシグナル挙動と所要時間は実行未確認。shell 終了後に pipe を保持する子が残る条件であり、全コマンドの問題ではない。

- [ ] F6 クリップボード復元がペースト後の新しいコピー内容を上書きしないようにする
  - 目的・発生条件: ペースト後の復元待ち（既定2秒）に外部アプリでコピーするか「最後の履歴をコピー」を操作すると、その新しいコピー内容が古い snapshot で失われる。
  - 根拠: `R09-C01`。[`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) は現在のクリップボードが一時本文のままかを確認せず、clearContents と snapshot 書き戻しで遅延・即時復元する。[`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift) の履歴コピーも同じ .general へ書き込む。
  - 作業・完了条件: 復元待ちに行った外部コピーと履歴コピーが、遅延・明示復元後も保持されることを確認する。新しいコピーがない通常復元と連続ペーストも維持し、既存テストと実クリップボード操作で確認する。
  - 限界: 実クリップボード未確認。復元までに別のコピーを挟む条件。

##### 次に扱う

- [ ] F7 テキスト操作による認識再開中も録音を継続させる
  - 目的・発生条件: 発話中にキーボード入力やカーソル移動を行うと、認識再開中の発話が取り込まれず音声入力が途切れる。
  - 根拠: `R04-C02`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) のテキスト操作は restartTranscriber へ到達する。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) は tap を除去し AVAudioEngine を停止した後、analyzer と旧 resultTask の終了を await し、その間の入力を保持しない。[音声テキスト仕様](../docs/specs/voice-input-text.md) は割り込み中も録音継続を求める。
  - 作業・完了条件: テキスト操作に伴う認識再開中も録音が継続し、続けて話した部分を取り込めることを確認する。再開前後の結果同期を既存テストで確認し、実音声とカーソル移動・キーボード入力で仕様を確認する。
  - 限界: 実音声未確認。中断時間と欠落語数は OS・callback の進行に依存し未測定。既存 D1 の意図した反復発話と重複除去の判断とは別に扱う。

- [ ] F8 長さが変わる連鎖置換の挿入位置とプレビューを最終結果に合わせる
  - 目的・発生条件: Auto-replace をオフにし、a → long、long → x の順でルールを登録する。本文 a b の位置1で Replace すると、カーソルが最終結果 x の直後ではなく本文末尾へ移る。同じ連鎖の marked text 中の tooltip も long を示す。
  - 根拠: `R07-C01`。[`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift) は match の location のみ元座標へ戻し、length は中間本文の長さを返す。[`ReplacementService.swift`](../Koecho/ReplacementService.swift) と [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift) は元本文 bounds で後続 match を除外するため、補正 delta と tooltip が最終結果に合わない。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の clamp 後は末尾へ次の音声を挿入する。
  - 作業・完了条件: 上記例で最終本文 x b、挿入位置1、プレビュー x が一致することを確認する。[置換ルール仕様](../docs/specs/replacement-rules.md) の登録順適用を維持し、長さが変わる連鎖の位置・preview と後続入力を既存テストと実操作で確認する。
  - 限界: 実画面未確認。例の range・長さ・clamp は静的追跡。近似 range のコメント上の意図は、誤った最終位置・tooltip の契約とは判断していない。

- [ ] F9 保存済みマイクの再接続後にメーターと入力音量の対象を一致させる
  - 目的・発生条件: 保存済み外部マイクが切断中に Settings を開き、別の system default を変えずに再接続すると、Picker は外部マイクを示す一方、メーターと音量 slider は既定マイクに残る。
  - 根拠: `R05-C02`。[`AudioDeviceSelection.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceSelection.swift) の fallback は effectiveUID=nil となり、[`AudioDeviceManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift) は元の requested UID を失う。デバイス一覧更新は選択対象を再解決せず、[`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift) の選択 UID も変わらないため再開せず、音量書き込みも fallback の対象を使う。
  - 作業・完了条件: Settings を開いたまま保存済みマイクを再接続した後、表示・レベルメーター・入力音量の対象が選択マイクに一致することを確認する。切断時の fallback を維持し、対象解決を既存テストと実デバイスの切断・再接続で確認する。
  - 限界: hardware 再現未確認。system default が変わらず View も再表示されない条件。既存 D2 の fallback 注意表示の検討とは別に扱う。

- [ ] F10 音声認識終了後に開いたままの入力レベルメーターを再開させる
  - 目的・発生条件: Settings のマイク設定を開いたまま入力パネルで認識し、確定または Escape で閉じると、利用可能になったマイクのメーターが0のままになる。認識中に Settings を開いた場合も該当する。
  - 根拠: `R05-C01`。[`AudioInputExclusiveAccess.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputExclusiveAccess.swift) の acquire は monitor を止めるが release は isInUse を戻すだけ。[`AudioInputLevelMonitor.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioInputLevelMonitor.swift) の開始は使用中 guard で返り、[`AudioDeviceManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift) と [`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift) には release に応じた再開経路がない。
  - 作業・完了条件: 認識終了後、ページ再表示や選択変更を行わずメーターが再開することを確認する。認識中の排他を維持し、Settings を先に開く場合と認識中に開く場合の双方を既存テストと実マイクで確認する。
  - 限界: hardware 実測未確認。監視停止と再開契機の欠如を静的に確認した。

- [ ] F11 中断した修飾キータップの古いタイマーが次のダブルタップを失効させないようにする
  - 目的・発生条件: 非表示パネルで対象キーを単独タップし、300ms以内に別 modifier で中断してから対象キーをダブルタップすると、正しいタップ間隔でもパネルが開かない。
  - 根拠: `R08-01`。[`ModifierTapDetector.swift`](../Packages/KoechoKit/Sources/KoechoCore/ModifierTapDetector.swift) は対象外 modifier で idle へ戻るが、[`HotkeyService.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift) は古い doubleTapTimer を残す。新しい waitingForSecondTap で timer を作らず、旧期限で新しい待機を失効させる。旧 release が0ms、中断が50/100ms、新タップが150/200msと350/400msなら、旧300ms期限が後のタップを妨げる。
  - 作業・完了条件: 別 modifier で中断した後の新しいダブルタップが、その新しい待機区間で判定されパネルを表示することを確認する。提示のイベント順序を既存テストで確認し、通常の single / double tap と中断後の実ホットキー操作も確認する。
  - 限界: 実時間のイベント・timer 実行未確認。main queue が提示の期限順に進む条件を静的に確認した。

##### 後で扱う

- [ ] F12 クリップボード復元遅延の設定変更を次回ペーストへ反映する
  - 目的・発生条件: 一度パネルを開いた後に Settings で復元遅延を2秒から10秒などへ変更しても、次回以降のペーストが初回の遅延を使い続ける。
  - 根拠: `R09-C02`。[`GeneralSettingsView.swift`](../Koecho/GeneralSettingsView.swift) と [`PasteSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/PasteSettings.swift) は変更値を保存するが、[`InputPanelController.swift`](../Koecho/InputPanelController.swift) は生成時の値を [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) の immutable な pasteDelay へ渡す。[`KoechoApp.swift`](../Koecho/KoechoApp.swift) は controller を再利用し、以後の反映経路がない。
  - 作業・完了条件: パネル生成後の設定変更がアプリ再起動なしで次回ペーストの復元遅延へ反映されることを確認する。設定反映を既存テストと実クリップボードの復元時間で確認する。
  - 限界: 実時間計測未確認。初回 controller 生成後の変更が条件。

- [ ] F13 音声無効で起動した後の有効化で認識言語メニューを復帰させる
  - 目的・発生条件: ダウンロード済み言語が2つ以上あり、音声 off で起動した後、Settings を開かずパネルの Voice ボタンまたはショートカットで on にしても認識言語メニューが出ない。
  - 根拠: `R01-C01`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift) は off 起動時に downloadedLocales を空にし、locale の変更と Settings 操作だけで更新する。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の有効化は locale を変えず一覧も更新しないため、[`MenuBarContent.swift`](../Koecho/MenuBarContent.swift) の2言語以上という表示条件に達しない。[スコープ](../docs/rules/scope.md) の表示契約と食い違う。
  - 作業・完了条件: off 起動後にパネルから on にすると、ダウンロード済み言語が2つ以上ならメニューが表示され切り替えられることを確認する。Voice ボタン・ショートカットの双方と、off 時・1言語時の非表示を既存テストと実メニュー操作で確認する。
  - 限界: 実画面未確認。2言語以上が予約済みで現在の locale を変更しない条件。レビュー時に同一原因として統合された出典 `R11-C01` を含む。

- [ ] F14 英語 UI の空スクリプト一覧案内を英語で表示する
  - 目的・発生条件: 英語でアプリを使い、すべてのスクリプトを削除してパネルを開くと、追加先の空一覧案内だけが日本語になる。読み込み保護による空一覧でも到達する。
  - 根拠: `R11-C02`。[`InputPanelScriptStrip.swift`](../Koecho/InputPanelScriptStrip.swift) は日本語リテラルを Text のキーにし、sourceLanguage=en の [`Localizable.xcstrings`](../Koecho/Localizable.xcstrings) にある同じキーには英語 stringUnit がないため、そのリテラルを表示する。
  - 作業・完了条件: 英語 UI の空一覧で追加先を示す英語案内が表示され、日本語 UI でも対応する案内が表示されることを確認する。catalog の整合と両言語の実画面を確認する。
  - 限界: 英語実画面と生成済み localization bundle は未確認。source と catalog に基づく静的確認。

- [ ] F15 日英 README のスクリプト選択環境変数の説明を入力パネル内選択に合わせる
  - 目的・発生条件: README に従い外部アプリの選択を KOECHO_SELECTION で処理するスクリプトを作って、そのままパネルから実行すると、想定した選択を得られず空入力となる。
  - 根拠: `R12-001`。[`README.md`](../README.md) と [`README.ja.md`](../README.ja.md) はフォアグラウンドアプリの選択と説明するが、[スコープ](../docs/rules/scope.md) はパネル内選択を契約とする。[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift) は外部選択を本文に取り込み、[`InputPanelController.swift`](../Koecho/InputPanelController.swift) はキャレットを末尾へ置く。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) はパネル内 selectedRange から値を作り、[`ScriptRunner.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) へ渡す。
  - 作業・完了条件: 日英 README に KOECHO_SELECTION が実行時の入力パネル内選択で、KOECHO_SELECTION_START / END が同じ本文の UTF-16 座標であると説明し、外部選択の取り込みと区別できることを確認する。説明を仕様・実装・既存の選択あり／なしのテスト期待値と照合する。
  - 限界: スクリプト実行未確認。パネル内で選択し直せばその選択が渡る。既存テストは静的読解のみで実行していない。

### 将来の改善（低優先度）

[backlog/later.md](later.md)
