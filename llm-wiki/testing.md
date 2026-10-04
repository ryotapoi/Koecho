---
regen: compiled
sources:
  - Koecho/KoechoApp.swift
  - KoechoTests/TestSupport.swift
  - KoechoTests/VoiceInputTextViewTests.swift
  - Packages/KoechoKit/Tests/KoechoCoreTests
  - Packages/KoechoKit/Tests/KoechoPlatformTests
---

# Testing

## TEST_HOST

- `KoechoTests` は `TEST_HOST = Koecho.app` で動くため、通常の app lifecycle がテストプロセス内で走る。
- テスト検出・App 初期設定の隔離・system integration 抑止の正本は [Verification](../docs/rules/verification.md#制約と例外)。配線は `KoechoApp.isTesting` と `makeInitialAppState` を参照する。テスト時にも AppState は生成される。
- UI 近傍テストで app 本体の状態が必要な場合は、`TestSupport` の factory や mock を使い、global singleton に依存しない。

## UserDefaults

- 設定テストは suiteName を分ける。標準 `UserDefaults.standard` に書くと、開発中の実設定や別テストに影響する。
- nil 相当の永続化は既存の方式に合わせる。Koecho の設定では `Data()` sentinel と `removeObject` の混在を避ける。

## OS 連携テスト

- 音声認識の OS / hardware 連携は実送信せず、engine の mock までを検証する。実環境の確認で補う。
- menu や selector 周辺は SwiftUI の見た目ではなく、直接対象メソッドや状態遷移を検証する。
- JSON や Foundation 型を使うテストファイルでは `import Foundation` を明示する。Swift Testing だけでは型が揃わない。
