---
regen: none
sources:
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerEngine.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechAnalyzerLocaleManager.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/SpeechModelVerificationCache.swift
  - Packages/KoechoKit/Sources/KoechoCore/SpeechLocale.swift
  - Packages/KoechoKit/Sources/KoechoPlatform/AudioInputLevelMonitor.swift
  - Packages/KoechoKit/Tests/KoechoPlatformTests/SpeechAnalyzerEngineTests.swift
---

# SpeechAnalyzer 外部知見

このページは macOS 26 SpeechAnalyzer 周辺の実測・外部 API 罠を残す。ソースから完全には復元できないため `regen: none` とする。

## AssetInventory / モデル状態

- `AssetInventory.assetInstallationRequest(supporting:)` は対象モデルが利用可能なら `nil` を返す。非 `nil` の request は `downloadAndInstall()` する。
- `assetInstallationRequest` は内部で reservation を作るため、通常は別途 `reserve()` を呼ばない。
- `AssetInventory.release(reservedLocale:)` は `async -> Bool` で、throws ではない。`false` は元々 reserved ではなかったことを示す。
- `release()` は reservation を解除するだけで、モデルファイルを即削除しない。`release()` 後も `DictationTranscriber.installedLocales` に locale が残ることがある。
- `installedLocales` は「ディスク上にモデルファイルがある」ことを示す寄りで、利用可能状態の判定には足りない。`AssetInventory.status(forModules:)` / `assetInstallationRequest` 側の結果を優先する。
- `AssetInventory.status(forModules:)` の主な状態は `.installed` = 利用可能、`.supported` = download 必要、`.downloading` = download 中、`.unsupported` = 非対応。
- OS 再起動やディスク逼迫で、残っていたモデルファイルが削除されることがある。
- `SpeechModelVerificationCache` は、同一セッション中に `assetInstallationRequest` で利用可能確認済みの locale を再確認し続けないための cache。`release()` 後は invalidate する。

## SpeechAnalyzer API

- SpeechAnalyzer API は `Speech` framework にある。独立した SpeechAnalyzer framework ではない。
- `DictationTranscriber` は句読点自動付与を持つ。Koecho は `Preset` で `reportingOptions: [.volatileResults]` を指定し、volatile results を受ける。
- `DictationTranscriber.Result` は `isFinal: Bool` と `text: AttributedString` を持つ。文字列化は `String(result.text.characters)`。
- `AnalyzerInput(buffer: AVAudioPCMBuffer)` で audio buffer を渡す。
- `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:considering:)` で推奨 audio format を取得し、入力 format と違う場合は `AVAudioConverter` で変換する。
- `DictationTranscriber.supportedLocales` / `installedLocales` は static async property で、throws ではない。
- locale identifier は `-` と `_` が混在しうる。比較には `SpeechLocale.normalizationKey` を使う。

## Swift / Testing の罠

- Swift Testing の `@available(macOS 26, *)` と `@Test` macro は相性が悪く、suite に `@available` を付けると `@Test` が compile error になることがある。テストでは runtime `guard #available(macOS 26, *) else { return }` を使う。
- `import Speech` すると `Speech.Settings` と Koecho の `Settings` model が名前衝突しうる。曖昧な場所では `KoechoCore.Settings` など module 修飾を使う。

## AVAudioEngine / audio callback

- `AVAudioEngine.inputNode` は既定入力デバイスを前提に動く。`inputNode` アクセス後に `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` を設定しても内部 routing が更新されず、tap callback が呼ばれないことがある。
- 非デフォルト入力デバイスから取る場合は AUHAL を直接使う。手順は Enable IO（element 1 input）→ Disable IO（element 0 output）→ Set device → Set output format（element 1 output scope）→ AudioBufferList 確保 → input callback 設定 → `AudioUnitInitialize` → `AudioOutputUnitStart`。
- `AVAudioEngine.inputNode` の tap callback は audio thread で実行される。MainActor property に直接触らず、`AsyncStream.Continuation` などを local capture して渡す。
