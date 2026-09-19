# Backlog

## 運用ルール

- Backlog には、今後着手でき、完了を判定できる作業を `- [ ]` 形式のタスクとして置く。
- 対応要否を決める調査もタスクにできる。観察事実だけを残さず、判断したい問いと、判断をもって完了とすることを明示する。
- 粗いメモで起票してよいが、着手前に目的と受け入れ条件を読める粒度へ詰める。
- バージョン番号を付ける場合は SemVer に従う。
- タスクは `###` 見出しでグループに分ける。バージョンが確定したグループだけ、`### v0.1.0 名前` のように見出しへ番号を付ける。
- グループが大きい場合は、`####` 見出しでさらに分割してよい。

## タスク

### 保守監査（2026-09-17）

- バージョン目安: bug fix・内部 refactor・テストは patch scope（v1.8.0 後なら v1.8.1 相当）。fallback 通知のような新しいユーザー向け機能は、決定後に v1.9.0 相当となり得る。この監査グループの version は未確定。

#### now

- [ ] N1 音声変換失敗時の停止・復旧方法を決める
  - 目的・根拠: format / device 変更時に音声だけ落ちて listening 表示が残るのを防ぐ。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift) の変換失敗分岐が return のみ。
  - 決めること: 失敗時に認識をどの状態で停止するか、自動再試行・手動再試行・アプリ再起動のどれで復旧できるか、失敗後にユーザーへ示す次の操作、確定済みテキストと認識途中のテキストをどう扱い、保持したまま再試行できるかを決める。
  - 作業・完了条件: 決定した振る舞いを記録し、必要な実装・回帰テストを起票または更新する。通知だけを追加して完了とはしない。

- [ ] N2 設定 decode 失敗時の保持目的と継続方法を決める
  - 目的・根拠: 読み込めなかった Script / Replacement の元 Data が init 時の空配列保存で失われるのを防ぐ。[`ScriptSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ScriptSettings.swift) と [`ReplacementSettings.swift`](../Packages/KoechoKit/Sources/KoechoCore/ReplacementSettings.swift) の decode・save 経路。
  - 決めること: 設定を残す目的に対して、関連機能を使えるフォールバックを提供するか制限するか、アプリを継続使用できるか、元 Data の保持と復旧・reset の経路、ユーザー編集・保存・上書きを許す条件を決める。
  - 作業・完了条件: 決定した振る舞いを記録し、必要な実装・回帰テストを起票または更新する。元 Data の保持だけで完了とはしない。

- [ ] N3 履歴読取失敗後の起動時 purge を非破壊にする
  - 目的・根拠: read / decode 失敗を空履歴として起動時 purge が上書きするのを防ぐ。[`HistoryStore.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/HistoryStore.swift) と [`KoechoApp.swift`](../Koecho/KoechoApp.swift)。
  - ユーザー確認: この問題には対処する。
  - 作業・完了条件: 「空」と「読取失敗」を区別し、自動 purge / save が元ファイルを変更しないことを回帰テストで確認する。通知と手動 reset は決めない。

#### backlog

以下の候補は、実装時に[Change Scope](/Users/ryota/dotfiles/agents/.config/agents/change-scope.md)に従って、望む観測可能な結果と「変更しない」案を含む minimum coherent change を決める。[テスト・検証方針](/Users/ryota/dotfiles/agents/.config/agents/test-verification-policy.md)と既存の証拠から必要な確認を選び、プロジェクト必須 check を実施する。完了は、採用した今回の範囲の作業を検証すること、または不要とする理由と証拠を記録することとする。対応を defer する場合は、未解決の問題と追跡先を記録する。

- [ ] B1 クリップボード復元を絞って検証する
  - 目的・根拠: [`ClipboardPaster.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/ClipboardPaster.swift) の保存・復元とエラー伝播には既存 unit test があるが、明示的な復元を伴う error、遅延、連続 paste の後に元クリップボードを失わないことは既存自動テストで未確認。既存の clipboard / target / CGEvent 注入を参照する。
  - 実装時の判断・確認: 失敗時の明示復元、遅延復元、連続貼り付け後の復元から必要なケースを選び、最終的なクリップボード内容を確認する。汎用的な production rewrite、時間 DI、新しい復元動作はこのために追加しない。

- [ ] B6 engine 切替・OFF の停止後同期を低優先度で絞って整理する
  - 目的・根拠: [`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の stop → volatile text の clear → finalized text の同期と reset に、順序を保った局所的な重複がある。処理順序を維持し、engine の再生成・挿入位置更新・開始は切替側に残す。switch / replay には既存検証がある。
  - 実装時の判断・確認: 振る舞いを変えない最小の簡約を判断し、既存の switch / replay 検証を再利用する。OFF は必要な観測可能な差分だけを確認し、包括的な test scaffold や新しい型を追加しない。

### 将来の改善（低優先度）

- [ ] D1 同じ言葉を意図して繰り返した発話を入力できるようにする
  - 背景・根拠: `SpeechAnalyzer` が別々に返す確定結果でも、蓄積済みテキストの末尾と新しい結果の先頭が重なると、現在は重複として後者から除去する。これはキーボード入力・カーソル移動の割り込み後に前セグメントが再配信される既知の問題への防御であり、ユーザーが同じ言葉を繰り返して入力したい意図を削除するためではない。[`VoiceInputCoordinator.swift`](../Koecho/VoiceInputCoordinator.swift) の `stripOverlappingPrefix`、[`voice-input-text.md`](../docs/specs/voice-input-text.md)、[ADR 0016](../docs/decisions/0016-accumulated-text-overlap-removal-for-speechanalyzer.md)
  - 例: 独立した確定結果が「あい」「あい」と続くと、現在は後者が除去される。将来は、認識結果の再配信と意図した反復発話を区別できるかを調査する。
  - 実装時の判断・確認: 実際の SDK・対応 runtime で `SpeechAnalyzer` の挙動を確認し、重複除去を外せるか、または対象を狭められるかを判断する。macOS 27 専用化や対応下限の変更、およびライブラリ側で解消済みとの判断は未決定とする。採用する範囲で必要な場合だけ仕様と確認項目を更新し、既存の手段で確認する。新しいテスト基盤は要求しない。
  - 補足: 現在の比較は最大 512 UTF-16 code units で、仕様には上限が明記されていない。この契約差は、反復発話と重複除去の振る舞いを決める際に併せて扱う。

- [ ] D2 非ブロッキングの注意 UI を検討する（低優先度）
  - 現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）。[`SpeechAnalyzerEngine.swift`](../Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift)
  - 2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する
  - 2026-09-18 判断: モーダル alert や操作中断は行わず、録音・編集を継続できる注意 UI とする。表示位置・意匠は今後決める。今回は実装しない。
  - 現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける
  - 選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する
