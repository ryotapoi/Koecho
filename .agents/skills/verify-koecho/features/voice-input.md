# 音声入力

## Sub-features

- `General` の `Enable voice input`、`Language`、`Manage Languages…`、`Microphone` を確認する。
- 入力パネルの `Voice` ボタンで音声入力を切り替え、話した内容が本文に反映されることを確認する。
- 初回 Microphone 権限、選択マイクとダウンロード済み言語の条件を確認する。

## How to get to it (user POV)

1. メニューバーの `Settings...` → `General` → `Voice Input` で `Enable voice input` を on にする。
2. `Language` に利用できる言語があることを確認する。`No languages downloaded` の場合は `Manage Languages…` から対象言語を `Download` し、`Done` で戻る。
3. `Microphone` で `System Default` または使用するマイクを選ぶ。
4. `Open Input Panel` を開き、Microphone 許可の案内が出たら本人が許可する。実際に短く発話し、パネルの本文へ転記されることを確認する。
5. `Voice` ボタンを押して off / on を確認し、最後は `Escape` で閉じる。

## Driving it with CUA・本人操作

- CUA は [README](README.md) の絶対パスによる `getApp` で開始する。各操作は返された documentation と live state を使い、言語・マイク一覧の現況を読む。
- 発話、マイク接続、Microphone のシステム許可は本人の操作・確認が必要。初回権限と再ビルド・再起動後の維持を別々に記録する。
- 言語・マイク設定、音声入力中の状態、確定した本文を `.tmp/verification/verify-koecho/<run>` に記録する。Finder / desktop は取得しない。

## Gotchas

- 実装の入口: `Koecho/VoiceInputSection.swift`、`InputPanelToolbar.swift`、`Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift`。

- 利用可能な言語、モデルのダウンロード、マイク入力は実環境に依存する。実施不能なら未確認範囲を明記する。
- `Voice` はパネル内の切り替えで、オフにすると設定の `Enable voice input` も変わる。次の導線に進む前に状態を確認する。
- 文字が一時的に表示される途中状態と確定済み本文は区別して観測する。[音声テキストの判断](../../../../decisions/0032-speech-overlap-defense.md)を参照。
- 権限、音声、audio device の必須 gate は[検証の正本](../../../../docs/verification.md)を参照。
