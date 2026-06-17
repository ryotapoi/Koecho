# ADR 0018: SPM モジュール分離 (KoechoCore + KoechoPlatform)

## Status

Accepted

## Context

全ソースファイル（49 ファイル）が単一の Xcode ターゲットにフラット配置されており、コンパイル境界がないため依存方向の逆転を静的に検出できなかった。ビルドも常に全ファイル再コンパイルとなっていた。

## Considered Options

- **A: SPM ローカルパッケージ 1 つに 2 ターゲット**: パッケージ参照が 1 つで済み Xcode の管理が簡単
- **B: SPM ローカルパッケージ 2 つ**: ターゲットごとに独立だが Xcode の参照管理が煩雑
- **C: Xcode Framework ターゲット**: SPM 不要だがビルド設定の管理が煩雑

## Decision

We will use option A: 単一パッケージ `KoechoKit` 内に `KoechoCore`（pure Swift）と `KoechoPlatform`（macOS 依存）の 2 ターゲットを配置する。

依存方向: App → KoechoPlatform → KoechoCore。KoechoPlatform は KoechoCore を re-export しない。App は両方を明示的に import する。

`swift-tools-version: 6.0` を使用（`nonisolated(unsafe)` が AudioDeviceManager / OutputVolumeDucker で必要なため）。

DictationEngine は InputPanel / VoiceInputTextView に具象型で依存するため App target に残す。

## Consequences

- 依存方向の逆転がコンパイラで検出される
- KoechoCore は macOS フレームワーク import が禁止され、純粋ロジックの保証がある
- SwiftUI の `Settings` と KoechoCore の `Settings` が名前衝突するため、App target では `KoechoCore.Settings` の明示が必要な箇所がある
- `Array.move(fromOffsets:toOffset:)` は SwiftUI 依存のため、KoechoCore に `moveElements` として自前実装した
- ShortcutKey / HotkeyConfig は model 部分（KoechoCore）と platform extension 部分（KoechoPlatform）に分割
- テストも KoechoCoreTests / KoechoPlatformTests / KoechoTests に分散
