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

- [x] M1 macOS 27-only へ移行する
  - 目的・根拠: 対応 OS を macOS 27 以降へ固定し、現在の製品挙動を保ったまま旧 OS 向けの可用性分岐・フォールバックを必要な範囲で整理する。Dictation は選択可能な engine として維持する。
  - 作業・完了条件: deployment target と Package platform を macOS 27 に更新し、現在の正本・ユーザー向け文書を更新する。ADR 0023 の対応 OS 基準に関わる部分を supersede する新しい decision を記録し、既存 ADR 本文は書き換えない。旧 OS にのみ必要な availability / fallback 分岐だけを削除し、旧 OS 固有ではない製品挙動は保持する。`docs/rules/verification.md` の必須 gate と macOS 27 runtime 確認を実施する。旧 OS 向け test / CI は、これらの作業に必要な場合を除き追加しない。

- [x] M2 System Dictation を廃止し、音声入力をオン／オフへ一本化する
  - 目的・根拠: ユーザーが engine を選ばず、音声入力を有効・無効にできるようにする。production の音声実装は `SpeechAnalyzer` のみとし、無効時は音声 engine を開始せずキーボード入力を維持する。
  - 作業・完了条件: `DictationEngine`、`startDictation`、Dictation 固有の lifecycle・UI・test・現行文書を削除する。状態モデルを有効・無効の二状態にし、旧 enum / raw value は migration に必要な場合だけ残す。保存済みの `dictation` と `speechAnalyzer` は有効へ移行して canonical な値で再保存し、`off` は無効、欠損値・未知値は有効とする。入力パネルの Voice ボタンは有効・無効を切り替え、有効時は locale / model 管理・マイク・status を保つがユーザー向け表現は一般化する。
  - ユーザー向け UI・概念には `Engine`、`System Dictation`、`SpeechAnalyzer` を表示せず、音声入力のオン／オフ（または有効／無効）だけを示す。仕様・rules・localization・README と関連 test を更新し、影響する既存 decision を supersede する新しい ADR を追加する（既存 ADR 本文は変更しない）。`docs/rules/verification.md` の必須 gate と macOS 27 runtime 確認を完了する。

- [x] M3 SpeechAnalyzerEngine の macOS 27 deprecated audio API を移行する
  - 目的・根拠: [`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) で使う `inputNode.audioUnit` と `installTap(onBus:bufferSize:format:block:)` は macOS 27 で deprecated となる。macOS 27 専用化後も現在の音声入力経路を維持しつつ、deprecated 警告を解消する。
  - 作業・完了条件: `inputNode.audioUnit` は `withAudioUnit` を使う macOS 27 API へ移行し、`installTap(onBus:bufferSize:format:block:)` は macOS 27 API へ移行する。選択した入力デバイス設定、system default fallback、音声 buffer の受け渡し、format conversion の既存挙動を維持し、該当する deprecated 警告が消えることを確認する。`docs/rules/verification.md` の Packages production / audio device の必須 gate（`swift test`、`build_macos`、`build_run_macos` と実環境確認）を実施する。

#### 信頼性改善

- [x] N5 リリース版でスクリプトをすべて削除するとクラッシュする不具合を修正する
  - 目的・根拠: リリース版でスクリプトをすべて削除した際にクラッシュしたとのユーザー報告。
  - 作業・完了条件: 再現条件と原因を調査して修正し、リリース版でスクリプトをすべて削除してもクラッシュしないことを確認する。

- [x] N6 組み込みスクリプトをサブメニューから選んで追加できるようにする
  - 目的・根拠: スクリプトがない状態から組み込みスクリプトを追加すると、1回に1種類ずつ合計5回の操作ですべて追加されたとのユーザー報告。追加対象の種類が分かりにくい。
  - 作業・完了条件: 組み込みスクリプトを追加するメニューに5種類のサブメニューを用意し、選んだ種類が1回の操作で追加されることを確認する。

- [x] N2 設定読み込み失敗を起動時に通知し、読めない一覧データを保護する
  - 目的・根拠: Script / Replacement の保存値を読み込めなかった場合に、起動時の警告を1回だけ表示する。単一値は安全な既定値で継続し、読めない一覧データは空データとして自動保存せず、既存内容を失わないようにする。[`ScriptSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift) と [`ReplacementSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift) の読み込み・保存経路。
  - 作業・完了条件: 読み込み失敗を項目ごとの通知にせず、影響を受けた設定をまとめたアラートを起動時に1回表示する。単一値は既定値で動作し、ユーザーが変更した値を通常どおり保存できる。`scripts` / `replacementRules` を読み込めない場合は実行時に安全な空または利用不可として扱い、保存済みデータを保持したまま該当一覧だけ編集・書き込みを禁止する。他の設定変更による一括保存でも保護中の一覧を上書きしない。ユーザーが明示的に一覧を初期化した後は編集・保存を再開できる。正常時、単一値失敗、各一覧失敗、両一覧失敗、明示的な初期化を検証する。

- [x] N3 履歴読み込み失敗を起動時の集約通知へ含め、保存データを保護する
  - 目的・根拠: 履歴を読み込めなかった場合に、空履歴として自動保存せず既存内容を失わないようにし、N2で用意する起動時の集約通知から理由を説明する。[`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift) と [`KoechoApp.swift`](../Koecho/KoechoApp.swift) の読み込み・保存経路。
  - 作業・完了条件: 履歴の読み込み失敗をN2と同じ起動時アラートへ含め、設定と履歴が同時に失敗してもアラートは1回だけ表示する。読み込めない履歴は表示上利用不可として扱い、保存済みファイルを保持したまま履歴への書き込みを禁止する。ユーザーが明示的に履歴を初期化した後は記録を再開できる。正常時、履歴だけの失敗、設定との同時失敗、明示的な初期化を検証する。

- [x] N4 マウスによるキャレット移動を音声挿入位置へ同期する
  - 目的・根拠: 実環境で再現を確認した。音声入力中にマウスでキャレットを移動してから発話を続けると、後続の音声テキストは移動前のキャレット位置へ挿入される一方、キーボードでの移動は正しい新しい位置へ挿入される。[`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift)、[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift)、[`InputPanelController.swift`](../Koecho/InputPanelController.swift)。
  - 作業・完了条件: マウスによるキャレット移動で音声挿入位置を更新する。実環境で移動後の継続音声入力が新しい位置へ挿入されることを確認し、既存のキーボード移動、volatile text の確定、transcriber restart・replay suppression が退行しないことを関連テストと実操作で確認する。

- [x] B1 ClipboardPasterTests にクリップボード復元の UnitTests を追加する
  - 目的・根拠: [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) の保存・復元とエラー伝播には既存 UnitTests があるが、貼り付け失敗後の明示復元、遅延復元、連続貼り付け後に元の内容へ戻ることは未確認。
  - 作業・完了条件: 既存の `ClipboardPasterTests` を拡張し、失敗後の明示復元、遅延復元、連続貼り付け後に最終的なクリップボード内容が元へ戻ることを確認する UnitTests を追加する。テストで復元不具合が見つかった場合は必要な修正を行う。コード整理自体は目的とせず、専用検証 skill・新しい検証基盤・過剰な DI や scaffold は追加しない。

- [x] B6 認識言語変更・音声入力オフ時の UnitTests 追加と停止後同期の整理（低優先度）
  - 目的・根拠: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) には、停止 → 未確定テキストの除去 → 確定本文の同期 → 認識状態の reset という順序を保った局所的な重複がある。この重複を整理する価値を判断し、必要な場合だけ振る舞いを変えずに簡約する。
  - 作業・完了条件: 既存の認識言語変更・再開側の UnitTests を再利用し、音声入力オフ時の停止から未確定テキスト除去、確定本文同期、認識状態 reset までを確認する UnitTests を既存 suite に追加する。エンジン再生成・挿入位置更新・再開は認識言語変更・再開側の処理とし、その既存テストを維持する。包括的な test scaffold や新しい型は追加せず、低優先度を維持する。停止側の短い重複は、言語変更側との処理境界を分ける必要があり、今回は整理しない。

#### 機能改善

- [x] D3 直近の手動スクリプト実行前の入力本文へ戻す一時 Undo を追加する
  - 目的・根拠: 手動スクリプトを誤実行した場合に、実行前の入力パネル本文へ戻して救済できるようにする。汎用 Undo や履歴への常設保存は求めず、復帰先として保持するのは直近に成功した手動スクリプト1回分だけとする。
  - 動作: スクリプト実行成功直後に限り、入力パネル下部の Voice・Replace の右、中央の余白の前に「スクリプトを元に戻す」を表示する。対象はユーザーが手動実行したスクリプト（手動実行できる組み込みスクリプトを含む）とし、ボタンを押すと実行直前の本文へ戻して Undo を消費する。実行後の本文編集、確定、キャンセルで Undo を失効させる。確定時に実行される auto-run は対象外とする。
  - 作業・完了条件: 直近の手動スクリプト成功後に指定位置へボタンが表示され、押すと実行直前の本文へ戻ること、実行後の編集・確定・キャンセルで利用できなくなることを確認する。auto-run では表示されないこと、履歴には従来どおり paste 成功後の最終結果のみが記録されることも確認する。

- [x] D4 置換ルールのショートカット注意表示を削除する
  - 目的・根拠: General 設定の置換ルールと `ScriptEditView` の Shortcut key 直下にある「他のアプリやシステムが使用するショートカットは避けてください」という注意文と、その注意文専用の表示領域を削除する。入力パネル内で処理されるショートカットの範囲を誤解させないよう表示を直す。変更は表示のみとし、設定とショートカット処理は維持する。
  - 作業・完了条件: General 設定と `ScriptEditView` の両方で注意文と専用の表示領域が表示されず、Shortcut key の設定・保存・発火が従来どおり動作することを確認する。両 view の修正後にコード参照がない場合は共通 localized key と翻訳を削除する。D5 で設定配置が変わる可能性はあるが、注意表示は復活させない。

- [x] D5 ショートカット設定を整理し、音声入力の切替を追加する
  - 目的・根拠: ホットキーと入力パネル内のショートカットを「ショートカット」設定ページにまとめ、音声入力のオン／オフを入力パネル内のショートカットからも切り替えられるようにする。既存の設定値と操作の意味は維持する。
  - 動作・配置: 既存の「ホットキー」設定ページを「ショートカット」に改め、「ホットキー」と「入力パネル内のショートカット」のグループを設ける。「ホットキー」には既存のパネル表示・確定 modifier tap を置く。「入力パネル内のショートカット」には新しい音声入力オン／オフ、既存の置換、既存の auto-run 選択切替を置き、後二者は General 設定から移す。新しい音声入力ショートカットは入力パネル内で発火し、Voice ボタンと設定からの操作と同じ音声入力オン／オフ状態を切り替える。個別 script shortcut は各 `ScriptEditView` に残す。D4 は現在の General 配置で注意表示を削除し、D5 で置換 shortcut を移す際も注意表示を復活させない。
  - 実装時の判断: キー衝突時の扱いと、同一キーが選択された場合の対処を決める。作用範囲と設定配置は変更しない。
  - 作業・完了条件: 設定ページの名称とグループ、各 shortcut の配置、および各操作の意味が上記どおりであることを確認する。音声入力 shortcut が入力パネル内で Voice ボタン・設定と同じオン／オフ状態を切り替え、General から移す置換・auto-run shortcut の保存済み設定値、パネル表示・確定、個別 script shortcut が維持されることを確認する。

- [x] D6 Claude の整形サンプルを Apple の `fm` を使う例へ置き換える
  - 目的・根拠: Claude 依存の整形サンプルを、Apple macOS 27 の `/usr/bin/fm` を使う単一の例に置き換える。stdin → 整形 → stdout の流れは維持する。
  - 実装方針・動作: `examples/fm-textfmt.sh` は同じディレクトリの固定指示ファイル `fm-textfmt-prompt.md` を読み、`default` / `e` 等のプリセット切替、引数、設定は設けない。空白だけの stdin はそのまま stdout へ返す。非空白入力は `<transcript>…</transcript>` で囲み、`fm respond --no-stream --instructions` に渡して、stdout には整形本文だけを出す。初回の `sudo fm license` は利用者が手動実行するようスクリプト冒頭のコメントで案内し、スクリプトからは実行しない。
  - 作業・完了条件: `examples/claude-fmt.sh` と `examples/claude-textfmt/{default,e}.md` を fm 用例へ置き換え、不要なファイルを削除する。英語・日本語 README は新サンプル名と簡単な使い方へ更新し、固定指示ファイルの編集場所を案内する。ライセンス手順を重複記載しない。空白入力の透過、非空白入力の整形、stdout が整形本文のみであること、および Claude 固有の環境変数・オプションの除去を確認する。

- [x] D7 Auto-replace が有効なときは入力パネルの Replace ボタンを隠す
  - 目的・根拠: Auto-replace の設定状態と入力パネルで選べる操作を一致させる。
  - 作業・完了条件: 置換ルールが1件以上あり Auto-replace がオフの場合だけ Replace ボタンを表示し、オンの場合は表示しない。ボタンからの置換と、実行中にボタンを無効化する既存挙動を維持する。

- [x] D8 Script 編集画面の Type 切替 UI を削除する
  - 目的・根拠: 追加時に決まる Script の種別を編集時に切り替えられないようにし、種別ごとの編集内容を保つ。
  - 作業・完了条件: 編集画面の Type 切替 UI を削除し、追加時に決まった custom / builtin の種別を編集・保存後も固定する。既存の追加経路と、各種別に固有の編集項目を維持する。

- [x] D9 Script ごとに SF Symbol と表示名を設定できるようにする
  - 目的・根拠: スクリプトの用途に沿ったアイコンと表示名を設定し、Settings 一覧と入力パネルで見分けやすくする。
  - 動作:
    - Icon 設定行のボタンから popover を開き、絵のグリッドを検索・選択する。候補外の有効な名前は入力欄から Custom の1候補として選択する。入力だけでは保存せず、None は表示名がある場合に選べる。
    - custom / builtin の各 Script に SF Symbol 名と表示名を設定する。代表候補は絵を見て選択でき、候補外は SF Symbols app 等で調べた名前を手入力できる。全カタログの検索 UI は設けず、実行中 macOS で利用できるシンボルを候補制限なく受け付けてプレビューする。利用できない名前は明示的なエラーを表示し、保存不可とする。
    - SF Symbol 名と表示名は別の値として扱い、両方が空（空白のみを含む）は不可、片方だけ空は許容する。両方あれば両方を表示し、片方だけなら指定された方だけを表示する。明示的に空のアイコンへ既定アイコンを補わない。
    - プリセット（5グループ・29種）:
      - 数字: `1.square`, `2.square`, `3.square`, `4.square`, `5.square`, `6.square`, `7.square`, `8.square`, `9.square`, `0.square`
      - 図形・記号: `circle`, `triangle`, `square`, `star`, `heart`, `sparkles`, `bolt`, `checkmark.rectangle`
      - 矢印: `arrow.up`, `arrow.down`, `arrow.left`, `arrow.right`
      - テキスト: `text.alignleft`, `text.aligncenter`, `text.alignright`, `list.bullet`
      - 操作: `doc.on.clipboard`, `paperplane`, `terminal`
  - 作業・完了条件: 選択・入力した SF Symbol と表示名を Settings 一覧と Input Panel の script strip に反映する。既存保存データの読込時は現在の表示を維持し、SF Symbol と表示名が両方空にならないよう扱う。builtin の stable feature ID を維持する。実装に合わせて [`docs/rules/scope.md`](../docs/rules/scope.md) と [`docs/specs/builtin-script-ui.md`](../docs/specs/builtin-script-ui.md) を更新し、既存の builtin icon-only 表示と名前非表示の仕様との差分を定める。選択、任意名の入力・プレビュー、無効名のエラーと保存不可、片方のみ・両方指定の表示、既存データ読込、builtin ID 維持を確認する。

- [x] D10 内蔵機能の種類と幅を追加後は固定し、表示名とアイコンを表示どおりに反映する
  - 目的・根拠: 内蔵機能の種類と幅は追加時に選択済みなので、編集画面での変更操作をなくして設定を簡潔にする。設定一覧と入力パネルでは、設定した表示名とアイコンをそのまま表示する。
  - 作業・完了条件: Type 行の現行表示は維持する。Feature 行は読み取り専用とし、Indent 系は `Increase Indent (4)` のように幅を Feature の表示へ含め、独立した Indent Width 行と編集時の重複変更防止制御を削除する。追加時に決まった種類と幅は編集・保存後も固定する。同一種類・同一幅の追加時の重複登録防止を維持し、変更には削除・再追加を使う。再追加時に元の表示名・アイコン・ショートカットは引き継がない。
  - 表示の完了条件: 内蔵機能の Display Name の既定値は空、Icon は現行の既定値とし、少なくとも一方の設定を必須とする。設定一覧と入力パネルの両方で、表示名が空ならアイコンのみ、アイコンが空なら表示名のみ、両方あれば両方を表示する。値がある表示名を内蔵機能だからという理由で隠す旧分岐を削除し、両画面の項目表示を Feature 名やコマンド名で補完しない。識別用 tooltip は新設せず、種類と幅の詳細は一覧項目を選択した編集画面で確認できるようにする。既存の未カスタマイズ内蔵機能は空の表示名と既定アイコンで扱い、明示的にカスタマイズした表示名とアイコンは保持する。ショートカットの編集・動作は維持し、関連仕様を更新する。

- [x] D11 Settings の Scripts 一覧の並べ替えを SwiftUI 27 API で試し、採否を決める
  - 目的・根拠: `ScriptManagementView` の `.onMove` を `ForEach.reorderable` と `reorderContainer` で置き換え、明示的な並べ替え API が現在の実装と体験に適するか判断する。入力パネルの script strip は既に新 API を使用しているため対象外とする。
  - 作業・完了条件: Settings の Scripts 一覧で新 API への置き換えを試し、並べ替え結果の保存と一覧・入力パネルへの順序反映、選択状態、既存の操作無効化条件を保つ。その後、変更前後のコードの複雑さと実際の操作感を比較して採否を記録し、採用する実装で仕上げる。複雑さと挙動が同等なら、並べ替えを明示する API 名と今後の方向性を理由に新 API を採用する。明確な退行や追加コストがあれば `.onMove` を維持する。
  - 採否: 新 API の採用を見送り、`.onMove` を維持して完了。macOS 27.0 の `List` に `.reorderContainer` を付けるとクリック選択が更新されない挙動を最小構成でも確認した。SwiftUI の不具合の可能性があるが、原因は未特定（[ADR 0026](../docs/decisions/0026-settings-script-list-reordering.md)）。

- [ ] D12 Input Panel の確定時自動実行メニューの表示を整える
  - 目的・根拠: 自動実行が「なし」の状態と選択できる Script を、アイコンと表示名から分かるようにする。
  - 作業・完了条件: Input Panel の自動実行 UI から `wand.and.stars` を完全に除く。Input Panel 上の選択ボタンには、その時選択中の1項目だけを表示する。未選択なら「`play.slash` なし」、Script を選択中なら設定に応じて「シンボル タイトル」「シンボルのみ」「タイトルのみ」のいずれかとする。メニューの先頭に選択できない見出し「確定時自動実行」を置き、その直下に「`play.slash` なし」の選択項目、続いて候補 Script を並べる。メニュー内の Script も同じ表示形式とする。選択・解除と、候補がないときの操作不可状態を維持し、各表示パターンとメニュー操作を実画面で確認する。

### 将来の改善（低優先度）

[backlog/later.md](later.md)
