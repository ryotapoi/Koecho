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

- [ ] N2 設定読み込み失敗を起動時に通知し、読めない一覧データを保護する
  - 目的・根拠: Script / Replacement の保存値を読み込めなかった場合に、起動時の警告を1回だけ表示する。単一値は安全な既定値で継続し、読めない一覧データは空データとして自動保存せず、既存内容を失わないようにする。[`ScriptSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift) と [`ReplacementSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift) の読み込み・保存経路。
  - 作業・完了条件: 読み込み失敗を項目ごとの通知にせず、影響を受けた設定をまとめたアラートを起動時に1回表示する。単一値は既定値で動作し、ユーザーが変更した値を通常どおり保存できる。`scripts` / `replacementRules` を読み込めない場合は実行時に安全な空または利用不可として扱い、保存済みデータを保持したまま該当一覧だけ編集・書き込みを禁止する。他の設定変更による一括保存でも保護中の一覧を上書きしない。ユーザーが明示的に一覧を初期化した後は編集・保存を再開できる。正常時、単一値失敗、各一覧失敗、両一覧失敗、明示的な初期化を検証する。

- [ ] N3 履歴読み込み失敗を起動時の集約通知へ含め、保存データを保護する
  - 目的・根拠: 履歴を読み込めなかった場合に、空履歴として自動保存せず既存内容を失わないようにし、N2で用意する起動時の集約通知から理由を説明する。[`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift) と [`KoechoApp.swift`](../Koecho/KoechoApp.swift) の読み込み・保存経路。
  - 作業・完了条件: 履歴の読み込み失敗をN2と同じ起動時アラートへ含め、設定と履歴が同時に失敗してもアラートは1回だけ表示する。読み込めない履歴は表示上利用不可として扱い、保存済みファイルを保持したまま履歴への書き込みを禁止する。ユーザーが明示的に履歴を初期化した後は記録を再開できる。正常時、履歴だけの失敗、設定との同時失敗、明示的な初期化を検証する。

- [ ] N4 マウスによるキャレット移動を音声挿入位置へ同期する
  - 目的・根拠: 実環境で再現を確認した。音声入力中にマウスでキャレットを移動してから発話を続けると、後続の音声テキストは移動前のキャレット位置へ挿入される一方、キーボードでの移動は正しい新しい位置へ挿入される。[`VoiceInputTextView.swift`](../Koecho/VoiceInputTextView.swift)、[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift)、[`InputPanelController.swift`](../Koecho/InputPanelController.swift)。
  - 作業・完了条件: マウスによるキャレット移動で音声挿入位置を更新する。実環境で移動後の継続音声入力が新しい位置へ挿入されることを確認し、既存のキーボード移動、volatile text の確定、transcriber restart・replay suppression が退行しないことを関連テストと実操作で確認する。

#### 追加検証・内部整理

以下の候補は、実装時に[Change Scope](/Users/ryota/dotfiles/agents/.config/agents/change-scope.md)に従って、望む観測可能な結果と「変更しない」案を含む minimum coherent change を決める。[テスト・検証方針](/Users/ryota/dotfiles/agents/.config/agents/test-verification-policy.md)と既存の証拠から必要な確認を選び、プロジェクト必須 check を実施する。完了は、採用した今回の範囲の作業を検証すること、または不要とする理由と証拠を記録することとする。対応を defer する場合は、未解決の問題と追跡先を記録する。

- [ ] B1 クリップボード復元を絞って検証する
  - 目的・根拠: [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) の保存・復元とエラー伝播には既存 unit test があるが、明示的な復元を伴う error、遅延、連続 paste の後に元クリップボードを失わないことは既存自動テストで未確認。既存の clipboard / target / CGEvent 注入を参照する。
  - 実装時の判断・確認: 失敗時の明示復元、遅延復元、連続貼り付け後の復元から必要なケースを選び、最終的なクリップボード内容を確認する。汎用的な production rewrite、時間 DI、新しい復元動作はこのために追加しない。

- [ ] B6 engine 切替・OFF の停止後同期を低優先度で絞って整理する
  - 目的・根拠: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の stop → volatile text の clear → finalized text の同期と reset に、順序を保った局所的な重複がある。処理順序を維持し、engine の再生成・挿入位置更新・開始は切替側に残す。switch / replay には既存検証がある。
  - 実装時の判断・確認: 振る舞いを変えない最小の簡約を判断し、既存の switch / replay 検証を再利用する。OFF は必要な観測可能な差分だけを確認し、包括的な test scaffold や新しい型を追加しない。

### 将来の改善（低優先度）

- [ ] N1 音声変換失敗時の対応要否を判断する
  - 目的・根拠: format / device 変更時に音声だけ落ちて listening 表示が残る可能性がある。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の変換失敗分岐が return のみ。
  - 候補方針: 音声変換に失敗した場合は音声入力をオフにし、失敗したことと、再度オンにすれば続けられる旨を説明する。ただし、この対応自体を採用するかは未決とする。
  - 作業・完了条件: 実環境と必要なテストで失敗の発生条件と頻度を確認し、その結果に基づいて候補方針を正式に採用するか見送るかを判断して記録する。

- [ ] D1 同じ言葉を意図して繰り返した発話を入力できるようにする
  - 背景・根拠: `SpeechAnalyzer` が別々に返す確定結果でも、蓄積済みテキストの末尾と新しい結果の先頭が重なると、現在は重複として後者から除去する。これはキーボード入力・カーソル移動の割り込み後に前セグメントが再配信される既知の問題への防御であり、ユーザーが同じ言葉を繰り返して入力したい意図を削除するためではない。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の `stripOverlappingPrefix`、[`voice-input-text.md`](../docs/specs/voice-input-text.md)、[ADR 0016](../docs/decisions/0016-accumulated-text-overlap-removal-for-speechanalyzer.md)
  - 例: 独立した確定結果が「あい」「あい」と続くと、現在は後者が除去される。将来は、認識結果の再配信と意図した反復発話を区別できるかを調査する。
  - 実装時の判断・確認: 実際の SDK・対応 runtime で `SpeechAnalyzer` の挙動を確認し、重複除去を外せるか、または対象を狭められるかを判断する。macOS 27 専用化および対応下限の変更は決定済みとし、ライブラリ側で解消済みかどうかは未決定とする。採用する範囲で必要な場合だけ仕様と確認項目を更新し、既存の手段で確認する。新しいテスト基盤は要求しない。
  - 補足: 現在の比較は最大 512 UTF-16 code units で、仕様には上限が明記されていない。この契約差は、反復発話と重複除去の振る舞いを決める際に併せて扱う。

- [ ] D2 非ブロッキングの注意 UI を検討する（低優先度）
  - 現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)
  - 2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する
  - 2026-09-18 判断: モーダル alert や操作中断は行わず、録音・編集を継続できる注意 UI とする。表示位置・意匠は今後決める。今回は実装しない。
  - 現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける
  - 選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する
