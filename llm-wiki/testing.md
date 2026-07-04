---
regen: compiled
sources:
  - Koecho/DictationEngine.swift
  - Koecho/KoechoApp.swift
  - KoechoTests/TestSupport.swift
  - KoechoTests/DictationEngineTests.swift
  - KoechoTests/VoiceInputTextViewTests.swift
  - Packages/KoechoKit/Tests/KoechoCoreTests
  - Packages/KoechoKit/Tests/KoechoPlatformTests
---

# Testing

## TEST_HOST

- `KoechoTests` は `TEST_HOST = Koecho.app` で動くため、通常の app lifecycle がテストプロセス内で走る。
- `KoechoApp` は `ProcessInfo.processInfo.environment["TEST_HOST"]` を見て、テスト時に `AppState` や system integration を初期化しない。
- UI 近傍テストで app 本体の状態が必要な場合は、`TestSupport` の factory や mock を使い、global singleton に依存しない。

## UserDefaults

- 設定テストは suiteName を分ける。標準 `UserDefaults.standard` に書くと、開発中の実設定や別テストに影響する。
- nil 相当の永続化は既存の方式に合わせる。Koecho の設定では `Data()` sentinel と `removeObject` の混在を避ける。

## OS 連携テスト

- `DictationEngine` の `startDictation:` 送信は OS action のため、テストで実送信すると segv や環境依存失敗を起こしやすい。テストでは `DictationEngine` の action 送信クロージャを差し替える。
- menu や selector 周辺は SwiftUI の見た目ではなく、直接対象メソッドや状態遷移を検証する。
- JSON や Foundation 型を使うテストファイルでは `import Foundation` を明示する。Swift Testing だけでは型が揃わない。
