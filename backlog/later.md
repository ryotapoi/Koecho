# 低優先度バックログ

将来の改善候補を置く。通常の作業キューは [backlog/backlog.md](backlog.md) を参照。

## タスク

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
