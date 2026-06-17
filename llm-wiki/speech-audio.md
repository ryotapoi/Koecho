---
regen: compiled
sources:
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerLocaleManager.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechLocale.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AudioInputLevelMonitor.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceManager.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceListing.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AudioInputExclusiveAccess.swift
  - docs/decisions/0012-speechanalyzer-voice-input-engine.md
  - docs/decisions/0013-auhal-for-level-metering.md
  - docs/decisions/0014-separate-output-volume-ducker-class.md
  - docs/decisions/0015-persist-device-name-in-settings.md
  - docs/decisions/0016-accumulated-text-overlap-removal-for-speechanalyzer.md
  - docs/decisions/0019-voice-input-off-as-engine-mode.md
---

# Speech / Audio

## SpeechAnalyzer

- SpeechAnalyzer は macOS 26 以降のみ。関連コードは availability guard と `KoechoPlatform` 内に閉じる。
- ソースから復元しづらい macOS 26 SpeechAnalyzer の実測メモは [SpeechAnalyzer 外部知見](speechanalyzer-external-notes.md) に分ける。
- Speech framework は Foundation ではなく `import Speech` が必要。API 確認時は OS バージョン差も見る。
- locale は `SpeechLocale.normalizationKey` で正規化して比較する。表示名や生 identifier の文字列比較に寄せると、`en_US` / `en-US` などでずれる。
- model install と status 更新は非同期で競合しやすい。モデル解放や切替の変更では、ダウンロード中・利用中・削除後の状態遷移を確認する。
- transcriber restart では、古い stream からの重複結果を受けないように世代管理や cancellation の扱いを確認する。

## AVAudioEngine

- `AVAudioEngine.inputNode` は既定入力デバイスを使う。任意の入力デバイスを選ぶには CoreAudio / AUHAL 側の実装が必要。
- audio callback から MainActor state を直接触らない。`AudioInputLevelMonitor` は callback で軽い計算だけを行い、必要な値を安全に渡す。
- continuation を audio thread から resume する設計では、二重 resume と deinit 中の race を避ける。

## CoreAudio デバイス管理

- デバイス選択は transient な device ID ではなく、安定した UID を永続化する。
- CoreAudio property listener は callback queue と lifetime が壊れやすい。登録と解除のペア、deinit 時の isolation、MainActor への受け渡しを確認する。
- exclusive access は失敗する前提で扱う。権限や他アプリの利用状況によって取得できない場合でも、アプリが固まらないようにする。
