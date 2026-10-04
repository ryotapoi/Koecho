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

#### 通常対応

- [x] F2 音声終了待ち中の再確定で最終認識が欠落しないようにする
  - 目的・発生条件: auto-run 未選択で音声入力を確定し、最終結果を待つ間にホットキーまたは Command+Return で再確定すると、末尾を欠いた本文の貼り付けや空入力としての終了に至る。
  - 根拠: `KM-01-C05`。`R02-C02`。修正前は [`InputPanelController.swift`](../Koecho/InputPanelController.swift) の音声終了 await 中に再確定でき、二つ目の confirm がパネルを閉じると後続 didFinalize が非表示 guard で棄却されていた。
  - 作業・完了条件: 終了待ち中に繰り返し確定しても最終認識を含む本文が一度だけ貼り付けられ、空本文扱いで発話が失われないことを確認する。終了待ちと最終結果の順序を既存テストで確認し、実音声で連続確定を確認する。
  - 進捗: confirm 入口に専用の再入ガードを追加。停止待ち中の追加確定より後に最終結果が届く順序を、初期本文あり／空の回帰テストで確認。最終本文の一回貼付、次回確定、既存 auto-run キャンセル・ペースト失敗後の再試行を含む App テスト192件と Package テスト190件、build が成功（2026-10-04）。
  - 実環境確認: 専用署名ビルドを起動・再ビルド再起動し、本人が script と実音声の Command+Return／ホットキー連続確定で全文の一回貼付を確認。「問題なく動いた」「権限周りは何もない」と報告し、再許可なし（2026-10-04）。共有入力履歴の使用は本人許可済み。検証用プロセスは確認後に停止。
  - 限界: 実画面確認は CUA timeout のため本人報告による。実音声の細かい結果到着順は回帰テストで担保する。

- [x] F6 クリップボード復元がペースト後の新しいコピー内容を上書きしないようにする
  - 目的・発生条件: ペースト後の復元待ち（既定2秒）に外部アプリでコピーするか「最後の履歴をコピー」を操作すると、その新しいコピー内容が古い snapshot で失われる。
  - 根拠: `KM-05-C02` / `KM-06-C01`。`R09-C01`。修正前の [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) は snapshot を無条件に復元していた。現在は一時本文を書いた版の changeCount を持ち、所有喪失時は復元を見送り、次のペーストでは新しいコピーを保存し直す。
  - 完了: 外部コピー相当・実履歴コピーの遅延／明示復元、同一本文の再コピー、途中コピー後の連続ペーストの回帰テストを追加。Package テスト190件、build、専用署名アプリの build/run・署名確認が成功（2026-10-04）。
  - 実環境確認: production source と hash が一致する一時 SPM harness で実 `.general`・実 ClipboardPaster・別 process の `pbcopy`・実 HistoryStore を使用。外部／履歴コピーの遅延・明示復元、同一本文、通常の遅延・明示復元、コピーあり／なしの連続ペーストの9ケースが成功。開始時 clipboard は全型をメモリ保存し、最後の所有版のままであることを確認して復元。証拠: `tmp/workflow/orchestrator-normal-20261004/changes/F6/evidence/`。
  - 限界: CGEvent 送信・trust と対象 activate は既存依存で置換した。実 Cmd+V の貼付成功、UI 操作、Accessibility / Input Monitoring の権限維持は今回再確認していない。

- [x] F11 中断した修飾キータップの古いタイマーが次のダブルタップを失効させないようにする
  - 目的・発生条件: 非表示パネルで対象キーを単独タップし、300ms以内に別 modifier で中断してから対象キーをダブルタップすると、正しいタップ間隔でもパネルが開かない。
  - 根拠・修正: `KM-05-C01`。`R08-01`。[`ModifierTapDetector.swift`](../Packages/KoechoKit/Sources/KoechoCore/ModifierTapDetector.swift) は対象外 modifier で idle へ戻る。修正前の [`HotkeyService.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift) は古い doubleTapTimer を残し、新しい待機を旧期限で失効させていた。現在は対象外 modifier による中断時に service の timer も取り消し、次の待機から新しい300ms期限を開始する。
  - 自動検証: 旧 release=0ms、中断=50/100ms、新タップ=150/200ms・350/400ms の実 timer 回帰を追加。修正前は旧期限による single callback と double callback 欠落で失敗し、修正後は成功。新待機自身の single expiry、重複 release による期限延長防止、既存の通常 single / double・可視時即時 single も成功。Package テスト298件と `build_macos` が成功（2026-10-04）。実時間ログの checkpoint は約54/102/151/204/359/405/664ms。証拠: `tmp/workflow/f11-20261004/changes/F11/evidence/`。
  - 実環境確認: 専用署名アプリの `build_run_macos`・PID・署名照合が成功。本人が非表示 single の無反応、通常 double の表示、可視時 single の即時非表示、別 modifier 中断後 double の表示、Single Toggle の即時表示／非表示の5操作を行い「OK」と回答（2026-10-04）。検証後、所有アプリを停止・検証 build を削除し、証拠を保持した。
  - 限界: 手動操作の正確なイベント間隔は未測定（本人「100msで押せてるかはわからない」）。旧期限と新待機の時間順序は service の実 timer 回帰で確認し、手動操作は実ホットキーとパネル動作の確認として扱う。CUA は timeout のため未使用。実際に選択した設定キー、権限追加有無は未回答であり、権限維持は今回の検証結果に含めない。

- [x] F12 クリップボード復元遅延の設定変更を次回ペーストへ反映する
  - 目的・発生条件: 一度パネルを開いた後に Settings で復元遅延を2秒から10秒などへ変更しても、次回以降のペーストが初回の遅延を使い続ける。
  - 根拠: `KM-01-C03` / `KM-05-C03`。`R09-C02`。[`GeneralSettingsView.swift`](../Koecho/GeneralSettingsView.swift) と [`PasteSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/PasteSettings.swift) は変更値を保存するが、[`InputPanelController.swift`](../Koecho/InputPanelController.swift) は生成時の値を [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) の immutable な pasteDelay へ渡す。[`KoechoApp.swift`](../Koecho/KoechoApp.swift) は controller を再利用し、以後の反映経路がない。
  - 作業・完了条件: パネル生成後の設定変更がアプリ再起動なしで次回ペーストの復元遅延へ反映されることを確認する。設定反映を既存テストと実クリップボードの復元時間で確認する。
  - 完了確認: 同一の実 controller / ClipboardPaster / general clipboard で設定変更後の次回ペーストを確認。2秒設定は約2.13秒、10秒設定は約10.12秒で全 type/data を復元し、待機中の設定変更は進行中の操作へ影響しない。恒久回帰テストと初期値固定 mutation、必須 build / test / 起動 gate が成功。
  - 限界: CGEvent の trust / キー送信のみ stub。実 Cmd+V 挿入・権限・Settings 画面操作は未確認。

- [x] F13 音声無効で起動した後の有効化で認識言語メニューを復帰させる
  - 目的・発生条件: ダウンロード済み言語が2つ以上あり、音声 off で起動した後、Settings を開かずパネルの Voice ボタンまたはショートカットで on にしても認識言語メニューが出ない。
  - 根拠: `KM-01-C01`。`R01-C01`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift) は off 起動時に downloadedLocales を空にし、locale の変更と Settings 操作だけで更新する。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の有効化は locale を変えず一覧も更新しないため、[`MenuBarContent.swift`](../Koecho/MenuBarContent.swift) の2言語以上という表示条件に達しない。[スコープ](../docs/rules/scope.md) の表示契約と食い違う。
  - 作業・完了条件: off 起動後にパネルから on にすると、ダウンロード済み言語が2つ以上ならメニューが表示され切り替えられることを確認する。Voice ボタン・ショートカットの双方と、off 時・1言語時の非表示を既存テストと実メニュー操作で確認する。
  - 完了確認: 専用署名検証版を音声 off で新規起動し、Settings を開かず Voice ボタンと設定済み Ctrl+V の各導線で on にした後、英語（アメリカ合衆国）・日本語の認識言語メニュー表示、別言語選択、off 後の非表示を本人操作で確認。locale を変えず on にする controller 回帰テスト、off・1言語・2言語の表示条件テストを含む App 194テストと必須 build・起動 gate が成功。1言語非表示は既存テストの証拠で受け入れて完了とする本人判断を受領。
  - 限界: 1言語の実メニューは未確認。既存予約言語を削除せず、非表示契約は unit test で確認。CUA は timeout のため本人報告を証拠とした。初回 Ctrl+V 設定消失の trigger は不明だが、再設定後は off 新規起動前後の保存値保持と実操作成功を確認。レビュー時に同一原因として統合された出典 `R11-C01` を含む。

- [x] F14 英語 UI の空スクリプト一覧案内を英語で表示する
  - 目的・発生条件: 英語でアプリを使い、すべてのスクリプトを削除してパネルを開くと、追加先の空一覧案内だけが日本語になる。読み込み保護による空一覧でも到達する。
  - 根拠: `R11-C02`。[`InputPanelScriptStrip.swift`](../Koecho/InputPanelScriptStrip.swift) は日本語リテラルを Text のキーにし、sourceLanguage=en の [`Localizable.xcstrings`](../Koecho/Localizable.xcstrings) にある同じキーには英語 stringUnit がないため、そのリテラルを表示する。
  - 作業・完了条件: 英語 UI の空一覧で追加先を示す英語案内が表示され、日本語 UI でも対応する案内が表示されることを確認する。catalog の整合と両言語の実画面を確認する。
  - 完了確認: 英語ソースキーと日本語訳を対応させ、旧日本語キーを除去。専用署名検証版を英語・日本語の各起動引数で別起動し、スクリプト全件削除後の実入力パネルで各言語の案内全文と周辺 UI の言語を本人操作で確認。catalog・生成 bundle の英語ソース fallback と日本語訳の整合、必須 build、App 194テストが成功。
  - 限界: CUA は timeout のため実画面は本人報告を証拠とした。読み込み保護由来の空一覧は同一表示分岐であり、破損 fixture での再現は行っていない。狭幅レイアウトは今回未検証。本人は日本語「まだありません」の表現に懸念を示したが、今回の文言維持と完了を了承。

- [x] F16 入力パネルの初期寸法と最小寸法を仕様に合わせる
  - 目的・発生条件: 保存 frame のない初回表示、または利用者によるパネル縮小で到達する。
  - 根拠: `KM-01-C02`。[`InputPanel.swift`](../Koecho/InputPanel.swift)、[`InputPanelController.swift`](../Koecho/InputPanelController.swift)、[`scope.md`](../docs/rules/scope.md)。変更前は NSPanel の contentMinSize が520×240pt、controller 生成時が560×240pt だった。本人の寸法改訂に合わせ、初回320×240pt、最小320×180pt とした。
  - 実装: hosting の標準 Auto Layout 制約で実効最小を維持。本文・操作領域の縦スクロール、toolbar の横スクロール、prompt の狭幅配置で既存操作への到達性を保つ。保存 frame 名・キー・復元順は維持。
  - 検証: 更新後の build と App tests 195件が成功。[`InputPanelControllerTests.swift`](../KoechoTests/InputPanelControllerTests.swift) で hosting 接続後の320×180pt、正の本文 viewport、別位置460×320pt の再表示・prompt 出現後の維持を確認。局所画像・計測は通常 frame/content が320×240pt、最小が320×180pt、最小 contentLayout が320×148pt（titlebar/safe area 差32pt）、scroll 後の toolbar・prompt・status への到達を確認。
  - 実操作証拠: 2026-10-04、改訂前の専用署名版を起動し、本人の初回表示報告と専用保存 frame の読み取りで300×240pt、本人の実 drag 最小報告と読み取りで200×150pt、基本 uppercase script の成功を確認。同じ制約・入力・callback 経路を維持した新寸法は、更新後の回帰と局所計測で補完した。
  - 限界: 新寸法の本人 drag・実画面画像、prompt の実入力/Run/Cancel と全 toolbar の網羅操作、保存 frame のアプリ再起動後復元は未確認。CUA 初回取得は timeout。保存経路は変更せず、再表示の維持を回帰で確認。使いやすさ評価は本人指示により対象外。

- [ ] F18 ペースト再試行で処理済み本文へ auto-run を重ねて適用しない
  - 目的・発生条件: 接頭辞追加など非冪等な auto-run を設定し、Accessibility 不足で失敗→権限修正→同じパネルから retry する操作で成立する。
  - 根拠: `KM-01-C07`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift):125-134,185-187,220-243,463-469; [`InputPanelControllerConfirmTests.swift`](../KoechoTests/InputPanelControllerConfirmTests.swift):47-78 は同 target retry を確認するが auto-run は設定していない。auto-run 出力の paste が Accessibility で失敗すると、その出力を inputText/editor に復元する。retry の confirm は処理済み本文へ再度置換と auto-run を実行する。
  - 作業・完了条件: 非冪等な接頭辞追加 auto-run の出力で Accessibility 失敗後に権限を修正して再確定しても、同じ加工を重ねず、保持した本文を元の対象へ貼り付けられることを確認する。再試行と通常確定を既存テスト・実権限操作で確認する。
  - 限界: 実 TCC 権限修正と script は未再現。外部 service への再送はそのようなコマンドを利用者が登録した場合だけ。

- [x] F20 非 Accessibility ペースト失敗の復帰後も再確定を可能にする
  - 目的・発生条件: CGEvent 生成失敗後、復帰パネルの本文をそのまま再 Confirm する。target を再取得する操作は閉じて再表示するまで走らない。
  - 根拠: `KM-01-C09`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift):139-152,200-203,220-243,103-107; [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift):142 の simulatePaste 経路; errorMessage の failedToCreateCGEvent 分岐。failedToCreateCGEvent など非 Accessibility 失敗は復帰時の target を nil にする。再 Confirm の pasteAndRecord は target guard で止まり、showPanel は可視なら refocus だけを行う。
  - 作業・完了条件: failedToCreateCGEvent 等で本文を復帰した後、閉じて再表示しなくても対象アプリへの再確定ができることを確認する。失敗時の本文保持と Accessibility 失敗の同対象 retry を維持し、注入した失敗で対象状態・再確定経路を確認する。
  - 限界: 実 CGEvent 生成失敗の条件・頻度は未測定。terminated target の別契約は対象外。editor は先に clear されるが inputText の fallback があるため本文の恒久消失までは確認していない。

- [ ] F21 未確定音声の表示開始時に既存の置換 preview を消去する
  - 目的・発生条件: IME marked text の置換 preview が表示される間に音声 volatile が届く。両入力は同じ editor を使用でき、直接 storage 挿入は通常 onTextChanged による Service 経路を通らない。
  - 根拠: `KM-02-C04`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):249-278; [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift):84-102,194-207,304-337; [`ReplacementService.swift`](../Koecho/ReplacementService.swift):20-33; [`replacement-rules.md`](../docs/specs/replacement-rules.md) volatile 中は preview を消去する契約。非空 volatile callback で既存 preview を消す呼び出しがない。setVolatileText の storage 変更は suppression 内で、previewMatches/tracking/tooltip を保持する。
  - 作業・完了条件: IME marked text の preview 表示中に非空 volatile が届くと、highlight・tracking・tooltip が消え、volatile 中に置換 preview が残らないことを既存テストと実 IME・音声操作で確認する。通常 marked preview を維持する。
  - 限界: 実 IME と音声の同時描画未実施。古い range がどの文字へ描画されるかは挿入位置・本文長次第。

- [ ] F23 初期言語補正待ち中の新しい言語選択を保持する
  - 目的・発生条件: 保存値が補正対象で、補正先の準備 await が継続し、他の reserved 言語を Picker で選べる場合。selection 用 task は初期の task とは独立する。
  - 根拠: `KM-03-C05`。[`SpeechAnalyzerLocaleManager.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerLocaleManager.swift):67-74,96-122; [`VoiceInputSection.swift`](../Koecho/VoiceInputSection.swift):37-50,72-83; [`VoiceInputSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift) locale setter の保存。loadLocales は開始時の補正値を計算後 isLoading=false にして download を await する。ユーザーが別言語を選んでも初期 task は失効せず、戻った古い補正値を selection へ代入する。
  - 作業・完了条件: 初期補正の download / 準備待ち中に Picker で別の reserved 言語を選んだ後、旧補正 task が復帰しても選択・保存値を上書きしないことを確認する。選択変更がない初期補正と通常の言語変更を既存テスト・実 UI で確認する。
  - 限界: 実 UI/download 未実施。表記正規化だけの補正も候補になり得るが、await がすぐ終了する場合は競合窓が小さい。

- [ ] F24 音声認識本文を非マスクの診断ログへ出力しない
  - 目的・発生条件: 音声認識 result が到着し、debug ログ収集を有効にした Console/ 診断ログを閲覧・共有する通常の診断経路で到達する。
  - 根拠: `KM-03-C06`。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift):277-285、特に280 の text privacy:.public。全 result の本文全文を Logger.debug の privacy:.public で渡している。本文は private 既定値ではマスクされず、delegate 判定より前にログへ渡される。
  - 作業・完了条件: 確定・未確定結果の本文全文が debug 診断ログの閲覧・共有先へ非マスクで渡らないようにする。実音声のログ収集で本文の扱いを確認し、必要な状態・終了診断は維持する。
  - 限界: 実ログ収集未実施。debug ログの通常時の永続保存や無条件の第三者アクセスを主張しない。取消後 idle では result loop guard が抑止するため、取消済み全文が常に記録されるとは断定しない。

- [x] F25 完了したスクリプトの timeout work の所有 cycle を解消する
  - 目的・発生条件: 短い custom の通常終了時、cancel だけでは RunState → timeoutWork → RunState の所有 cycle が残っていた（`KM-04-C05`）。
  - 完了: [ScriptRunner.swift](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) の完了境界で timeout / kill work を cancel して所有を解除し、完了後の登録・timeout 開始を拒否する。終了前後の登録と timeout 開始済みの順序を production RunState の直接 harness で確認（2026-10-04）。
  - 検証: source hash を記録した一時 harness で実 Runner の RunState を weak 観測し、成功30回、non-zero / empty-output 各30回、SIGTERM / SIGKILL timeout 各1回が期限後に解放されることを確認。所有測定とは別に、実 Process の反復結果・出力回収・timeout の回帰を含む Package テスト192件、build、専用署名アプリの build/run・識別・停止が成功。証拠: `tmp/workflow/orchestrator-normal-tail-20261004/changes/F25/validation/`、`tmp/verification/verify-koecho/20261004-f25/`。
  - 限界: Dispatch queue は cancel 済み work を期限まで一時保持し得る。Foundation Process 全体の heap、RSS、内部資源総量は測定していない。UI・TCC 権限維持の実操作は今回の対象外。

- [ ] F28 履歴消去の保存失敗を消去成功として表示しない
  - 目的・発生条件: HistoryView の通常履歴ページにある Clear All から clear へ直接到達する。履歴を読み込めた後、保存先 directory を書き込み不能にする等、元ファイルの読み取りが可能なまま atomic write が失敗する条件で成立する。再起動時の purge も同じ書込み不能状態なら古い履歴を消去できない。
  - 根拠: `KM-06-C02`。[`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift):34-37,76-114；[`HistoryView.swift`](../Koecho/HistoryView.swift):82-99,114-118；[`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift):47-52 は unavailable reset 時のみ保存成功後に memory 状態を変更する；[`KoechoApp.swift`](../Koecho/KoechoApp.swift):57-64。HistoryStore.clear は entries を空にしてから save する。save() は atomic write の失敗を false として返す内部 save 結果を捨て、isUnavailable も変更しない。元ファイルを保持したまま atomic write が失敗すると、UI は空表示である一方、次回 load は元の本文を再読み込みする。
  - 作業・完了条件: 読み取り可能な元履歴が残る atomic write 失敗を扱い、Clear All 後に消去済みと誤認させず失敗を判別できることを確認する。成功時には永続消去され再起動で復活しないこと、失敗時には再読み込みと表示が整合することを保存失敗の検証と実ファイル操作で確認する。完了済み N3 の読込失敗保護とは別の消去保存経路を対象とする。
  - 限界: 書込み失敗と再起動の実行再現は行っていない。全ての atomic write 失敗が必ず元ファイルを保持するという主張ではなく、保存先 directory が書き込み不能で元ファイルが残る条件に限定した。容量不足の発生率は未測定。

#### 高難度対応

- [ ] F1 キャンセル前のスクリプト結果が再表示後の入力セッションへ反映されないようにする
  - 目的・発生条件: 遅い手動スクリプトまたは auto-run の実行中に Escape でキャンセルし、完了前にパネルを再表示すると、新しい本文・prompt が旧結果や旧本文で上書きされる。auto-run では別の対象アプリへ旧本文を貼り付け、履歴にも記録し得る。
  - 根拠: `KM-01-C04` / `KM-04-C01`。`R02-C01` / `R06-C01`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift) の cancel は実行を無効化せず、[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift) の再表示は visibility・対象アプリ・本文を更新する。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) と confirm の await 後は現在の visibility だけで旧処理の結果を受け入れ、手動処理の cleanup は新しい prompt・実行フラグも消す。paste は現在の対象アプリを使う。
  - 作業・完了条件: キャンセル前の処理完了が再表示後の本文・prompt・Undo・実行状態を変更せず、auto-run の旧結果を新しい対象へ貼り付けたり履歴へ追加したりしないことを確認する。手動・auto-run の成功と失敗、再表示後に新しい処理を始めた場合を既存のテストと実操作で確認する。
  - 限界: 実行未確認。旧処理が完了する前に再表示するタイミングが条件。2候補の auto-run 部分は同じ問題として統合した。

- [ ] F3 手動スクリプト中の未確定音声で成功結果が消失しないようにする
  - 目的・発生条件: 音声入力を有効にしたまま追加入力なしの custom スクリプトを実行し、実行中に話し始めて成功時にも volatile text が残ると、加工結果が表示されず後続の音声確定で失われる。
  - 根拠: `KM-02-C08` / `KM-04-C03`。`R03-C01`。[`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift) は開始時にだけ volatile を除去し、成功結果を AppState へ設定する。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) は実行中も音声プレビューを挿入し、[`VoiceInputTextEditor.swift`](../Koecho/VoiceInputTextEditor.swift) は volatileRange があると結果の表示同期を抑止する。その後の確定音声が古い表示本文を AppState へ書き戻す。
  - 作業・完了条件: スクリプト成功結果が表示され、後続の音声確定で実行前本文へ戻らないことを確認する。本文 hello の加工結果 HELLO と実行中からの音声 world の順序を既存テストで確認し、実音声と遅いスクリプトでも結果保持を確認する。
  - 限界: 実画面未確認。成功後の SwiftUI 同期より先に finalize が来る場合もあり、全実行で必ず起きるとは判断していない。

- [ ] F4 終了した音声開始処理が await 復帰後にマイクを起動しないようにする
  - 目的・発生条件: パネル表示直後のマイク許可・モデル準備・音声 format 決定待ち中に Escape、確定、Voice 無効化を行うと、終了後の処理がマイクや認識リソースを起動し得る。
  - 根拠: `KM-03-C01`。`R04-C01`。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の startRecognition は await 後に取消・state を確認せず、session activate・exclusive access acquire・audioEngine.start へ進む。cancel は既存フィールドを破棄するが開始 Task 内の self・ローカル engine は残る。[`SpeechModelPreparation.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechModelPreparation.swift) の検証済み early return も取消を確認しない。stop の開始待ち timeout 後も後続起動を防げない。
  - 作業・完了条件: 開始待ち中の取消・確定・無効化・停止 timeout 後に処理が復帰しても、マイクと認識リソースが再起動せず、終了状態とリソース状態が一致することを確認する。待機と終了の順序を確認し、実環境で開始途中の終了と次の開始を確認する。
  - 限界: OS の await が取消に応じて返す値、実録音継続時間、hardware 挙動は未確認。許可・モデル・format が成功して復帰する経路を静的に確認した。

- [ ] F5 子プロセスが出力パイプを保持してもスクリプト timeout を完了させる
  - 目的・発生条件: シェル複合コマンドやパイプラインの子が stdout / stderr を保持すると、設定 timeout を過ぎても復帰せず実行中状態が続く。親 shell が先に正常終了する場合も、出力回収が子の EOF 待ちになり timeout が無効になる。
  - 根拠: `KM-04-C02`。`R06-C02`。[`ScriptRunner.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift) は shell の PID だけを停止する。terminationHandler は timeout / kill work を取消後、collectors.finalize の readDataToEndOfFile で EOF を同期的に待つため、shell 終了後も書き込み端を持つ子が残ると continuation を返せない。
  - 作業・完了条件: 親 shell が先に終了する場合と timeout で終了する場合の双方で、子が pipe を保持しても設定 timeout と終了処理を経て EOF 待ちを終え、エラーと fallback が返って入力パネルが操作可能になることを確認する。`sleep 2 & printf done` など実コマンドで所要時間と結果を確認し、既存の通常出力回収・timeout の保証を維持する。
  - 限界: Logger のみ除去した元 Runner の局所実行で、timeout=0.2秒・killDelay=0.1秒、`sleep 2 & printf done` が2.020秒後に done を成功出力することを再現した。実アプリ未確認。永久継続する子の無期限待ちは EOF と制御経路からの推論で、foreground pipeline の timeout 超過例は別実行していない。

- [ ] F7 テキスト操作による認識再開中も録音を継続させる
  - 目的・発生条件: 発話中にキーボード入力やカーソル移動を行うと、認識再開中の発話が取り込まれず音声入力が途切れる。
  - 根拠: `KM-03-C02`。`R04-C02`。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) のテキスト操作は restartTranscriber へ到達する。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) は tap を除去し AVAudioEngine を停止した後、analyzer と旧 resultTask の終了を await し、その間の入力を保持しない。[音声テキスト仕様](../docs/specs/voice-input-text.md) は割り込み中も録音継続を求める。
  - 作業・完了条件: テキスト操作に伴う認識再開中も録音が継続し、続けて話した部分を取り込めることを確認する。再開前後の結果同期を既存テストで確認し、実音声とカーソル移動・キーボード入力で仕様を確認する。
  - 限界: 実音声未確認。中断時間と欠落語数は OS・callback の進行に依存し未測定。既存 D1 の意図した反復発話と重複除去の判断とは別に扱う。

- [ ] F8 置換後の挿入位置とプレビューを最終本文の座標に合わせる
  - 目的・発生条件: Auto-replace をオフにした手動置換で、連鎖置換・前方の長さ変更・削除一致の内側のカーソルが最終本文に正しく対応しない。aZ の位置1で a→bbbb→c は cZ の位置2、a z t の末尾位置5で z→zzzz、a→aaa、t→TT は最終長11に対して位置10、abcFILLERz の位置4で FILLER→空は abcz の位置0になる。連鎖や座標履歴の不整合は marked text の preview にも使われる。
  - 根拠: `R07-C01` / `KM-02-C01` / `KM-02-C02` / `KM-02-C03`。[`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift):29-84,126-131 は元 location と中間 length を組み合わせ、後続の前方置換で既存 offset entry を移動・更新しない。[`ReplacementService.swift`](../Koecho/ReplacementService.swift):39-60 と [`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift) の元本文 bounds filter は後段の補正・preview を除外する。Service は削除一致の内側にも削除長全体を差し引き、[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):138-140 の clamp で位置0になる。
  - 作業・完了条件: a b の位置1で a→long→x は最終本文 x b・挿入位置1・preview x、aZ の位置1で a→bbbb→c は cZ・位置1、a z t の末尾から z→zzzz、a→aaa、t→TT は aaa zzzz TT・位置11となることを確認する。abcFILLERz の位置4で FILLER→空は abcz の削除開始位置3へ対応させる。[置換ルール仕様](../docs/specs/replacement-rules.md) の登録順適用を維持し、各計算、marked preview、後続音声の挿入を既存テストと実操作で確認する。
  - 限界: Core 本文変換と Service と同じ位置補正 loop の局所実行で、aZ→cZ・point=2、aaa zzzz TT・t match={6,1}・point=10、abcz・point=0 を再現した。Core logger を除去し最小 rule 型を使った計算の証拠で、実 NSTextView 操作・preview 描画・App integration は未確認。旧 a→long→x の tooltip 例は静的追跡。

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

- [ ] F19 Escape の中断を実行中の外部スクリプトへ伝える
  - 目的・発生条件: 長い custom 手動実行または auto-run 中に Escape する通常操作で成立する。再表示なしでも process の継続は生じる。
  - 根拠: `KM-01-C08` / `KM-04-C04`。[`InputPanelController.swift`](../Koecho/InputPanelController.swift):259-268; [`ScriptExecutionService.swift`](../Koecho/ScriptExecutionService.swift):65-71,115-123; [`ScriptRunner.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift):89-165; [`scope.md`](../docs/rules/scope.md) auto-run/Escape 中断契約。既存 cancelDuringScriptDiscardsResult は非表示結果破棄だけを確認する。cancel は panel/voice/clipboard を解除するが、ScriptRunner への中断操作はない。Runner には Task cancellation handler がなく、外部 process は自発終了または timeout まで続く。
  - 作業・完了条件: 手動 custom と auto-run の実行中に Escape すると process の中断が伝わり、自発終了や timeout まで継続しないことを実コマンドで確認する。通常完了・timeout・出力回収を維持する。F1 の旧結果適用防止とは別に process 継続を扱い、実行済みの外部作用の取り消しは求めない。
  - 限界: 実アプリから process を観測していない。network 送信や file 変更の有無は登録コマンド次第であり、過去の副作用が取り消せるとは主張しない。

- [ ] F22 大量一致の置換で座標変換が二乗時間になる処理を解消する
  - 目的・発生条件: 5 万 UTF-16 程度のＡ，Ｂ；改行の1 万行を取り込み、，→,、；→;を Replace する。本文長制限はこの経路にない。preview も同関数を使う。
  - 根拠: `KM-02-C07`。[`ReplacementEngine.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift):66-84,126-131; [`ReplacementService.swift`](../Koecho/ReplacementService.swift):6,36-42。delta=0 でも全 match の offset entry を保持し、後続 match 毎に先頭から2 回線形探索するため、各1 万一致の rule で約1 億 entry 訪問になる。MainActor の同期処理である。
  - 作業・完了条件: 登録順・置換結果・座標対応を維持し、5 万 UTF-16 程度の「Ａ，Ｂ；改行」1 万行に ，→,、；→; を適用する場合の約1 億 entry 訪問を解消する。Release 条件の計測と実パネル操作で本文長・一致数に対する処理時間と UI 応答を確認し、preview 経路も同じ計算を使うことを照合する。F8 と同じ座標変換部分を触る場合は実装範囲を合わせる。
  - 限界: 原 Core 算法の logger を除去し最小型を使った Swift script で20000 match・3.44396 秒を観測した。非最適化環境の値であり Release アプリの待機時間とは扱わない。実アプリの Escape・描画待ち時間は未測定。

- [ ] F26 ペースト送信前の focus 変更で別の入力先へ本文を送らない
  - 目的・発生条件: 通常 confirm はパネルを隠し可視状態を false にしてから paste を await する。この待機中にはユーザーが別アプリをクリックでき、singleToggle で再表示する経路も showPanel の isConfirming ガードがないため到達する。送信時に別の入力欄が focus を得て Cmd+V を受け付ける条件で、そこへ本文が渡る。
  - 根拠: `KM-05-C04`。[`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift):117-142；[`CGEventClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/CGEventClient.swift):24-37；[`InputPanelController.swift`](../Koecho/InputPanelController.swift):104-112,200-215；[`KoechoApp.swift`](../Koecho/KoechoApp.swift):193-204；macOS SDK CoreGraphics/Headers/CGEvent.h:347-354 は CGEventPost を event stream への post、:356-374 は特定アプリ向け post を別 API として定義している；[`scope.md`](../docs/rules/scope.md):32-35 はパネル表示前のアプリを記憶してペースト前に再 activate する契約。記憶した対象を activate した後に100ms の await があり、その後は対象や現在 focus を照合せず simulatePaste を呼ぶ。LiveCGEventClient は PID を指定せず Cmd+V を HID event stream へ post する。対象の貼付成功を確認する処理もなく、イベント生成が成功すれば caller は履歴を追加する。
  - 作業・完了条件: 対象 activate 後の100ms 待機中に他アプリの入力欄へ focus を移した場合とパネルを再表示した場合に、記憶した対象以外へ本文を貼り付けたり成功として履歴に追加したりしないことを確認する。通常の対象アプリへの貼付を維持し、送信時の対象判断を既存テストと実アプリの focus 切替で確認する。
  - 限界: 実 OS で100ms 内の focus 切替と配送を再現していない。任意の別アプリが貼付を受け入れると断定せず、送信時にその入力欄が focus を持ち Cmd+V を受け付ける場合に限定する。発生頻度は未確認。

- [ ] F27 外部アプリの選択取得待ちでパネル表示と UI を止めない
  - 目的・発生条件: Accessibility 権限を得た通常 showPanel 経路で常に外部 focus/selection を問い合わせる。最前面アプリが応答停止・長い処理待ちで AX 応答を返せない場合、パネル表示前に呼び出しスレッドが待つ。HotkeyService も main queue へ処理を配送するため、その間後続操作が処理されない。
  - 根拠: `KM-05-C05`。[`PanelLifecycleManager.swift`](../Koecho/PanelLifecycleManager.swift):5,24-41；[`InputPanelController.swift`](../Koecho/InputPanelController.swift):90-117；[`SelectedTextReader.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SelectedTextReader.swift):25-39；[`AccessibilityClient.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AccessibilityClient.swift):17-42；[`HotkeyService.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HotkeyService.swift):83-85；macOS SDK HIServices/Headers/AXUIElement.h:38-39,145-148,388-402 は応答不能時の messaging failure と AX API timeout を説明する。MainActor 上の PanelLifecycleManager.show は makeKeyAndOrderFront より前に SelectedTextReader.read を同期実行し、LiveAccessibilityClient は外部アプリへの AXUIElementCopyAttributeValue を同期実行する。応答待ちの間は MainActor を解放しない。SDK は AX messaging に応答不能アプリと timeout が存在することを明記している。
  - 作業・完了条件: 最前面アプリが AX 応答を返さない場合でも、選択取得待ちの間にパネル表示・menu・hotkey 操作を処理できることを確認する。通常の選択本文取り込みと表示前アプリの記録を維持し、注入した遅い取得と実 AX 応答待ちを分けて検証する。
  - 限界: AX 実応答停止、既定 timeout 値、実際の停止秒数は測定していない。停止する長さは外部アプリと OS に依存し、全ての AX 呼び出しが遅いという主張ではない。

- [ ] F29 hosted test の App 初期化から通常版の設定を隔離する
  - 目的・発生条件: project で KoechoTests は通常 app bundle ID com.ryotapoi.Koecho の Koecho.app を TEST_HOST として使い、verification.md も hosted test が app lifecycle を起動することを明記する。通常ユーザーの domain に値がある状態でこの hosted test を実行すると、テストメソッドによる隔離 factory 利用の有無によらず App 初期化から到達する。
  - 根拠: `KM-07-C01` / `KM-08-003`。[`KoechoApp.swift`](../Koecho/KoechoApp.swift):9-20；[`AppState.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/AppState.swift):28-29；[`Settings.swift`](../Packages/KoechoKit/Sources/KoechoCore/Settings.swift):24-27；[`ScriptSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift):68-76,98-100,134,173-193；[`VoiceInputSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/VoiceInputSettings.swift):58-83,98-106；[`project.pbxproj`](../Koecho.xcodeproj/project.pbxproj):448,482,510,531；[`TestSupport.swift`](../KoechoTests/TestSupport.swift):8-13；[`verification.md`](../docs/rules/verification.md):25。KoechoApp の stored @State 初期値 AppState() は init の isTesting guard に先行する。AppState は Settings() を生成し、.standard を feature 設定へ渡す。VoiceInputSettings と ScriptSettings は init 内で save し、不正 timeout の補正、voice mode の正規化、壊れた shortcut の encoded nil への書戻し等を行う。test factory による suite 隔離はその前の App 初期化には適用されない。
  - 作業・完了条件: test factory 使用前の KoechoApp / AppState / Settings 初期化も専用 domain へ隔離し、文書化された KoechoTests の起動だけで通常版の設定を読み書き・正規化しないことを確認する。不正 timeout・旧 voice mode・壊れた shortcut を含む通常 domain の保存値が維持され、test 設定が専用 domain へ保存されることを安全な fixture で検証する。hosted test の起動時挙動を [Verification](../docs/rules/verification.md) の隔離説明と整合させる。
  - 限界: hosted test を起動して実 UserDefaults domain を観測する検証は実行していない。専用 OS user や外部環境による HOME/domain 隔離が別途ある run は除く。文書化された標準 hosted test 経路と project 設定を照合した。

- [ ] F30 volatile がないカーソル割込みの buffer 未破棄に対応が必要か判断する
  - 目的・発生条件: `KM-02-C05` は `confirmed` / `uncertain`。確定音声 callback 後から次の volatile 到着前にカーソルを移す場合、buffer を破棄する仕様との差がある。利用者に見える再送・表示重複が起きるかを調べ、対応要否を決める。
  - 根拠: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift):179-195,249-279 は volatileRange=nil なら挿入点だけを更新し restart を呼ばない。[`InputPanelController.swift`](../Koecho/InputPanelController.swift):414-416 から到達する。[音声テキスト仕様](../docs/specs/voice-input-text.md):11 と [ADR 0016](../docs/decisions/0016-accumulated-text-overlap-removal-for-speechanalyzer.md) を照合する。確定 callback には重複除去があるが volatile にはない。
  - 作業・完了条件: 対象 runtime の実 SpeechAnalyzer で提示のカーソル操作後に古い本文が volatile として再送されるか、表示への影響と頻度を確認する。条件・結果・限界を記録して修正／仕様整理／見送りの対応判断をもって完了とする。反復発話と重複除去を扱う [D1](#高難度対応) の調査と観測を共有できるが、同じ原因とは未判定。
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

- [ ] D2 非ブロッキングの注意 UI を検討する（低優先度）
  - 現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)
  - 2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する
  - 2026-09-18 判断: モーダル alert や操作中断は行わず、録音・編集を継続できる注意 UI とする。表示位置・意匠は今後決める。今回は実装しない。
  - 現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける
  - 選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する
