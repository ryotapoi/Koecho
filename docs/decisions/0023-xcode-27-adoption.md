# ADR 0023: Xcode 27 の Swift・macOS API 採用判断

## Status

Superseded by ADR 0024

## Date

2026-09-17

## Context

Xcode 27.0（27A266a）は Swift compiler 6.4 と macOS SDK 27 を提供する一方、プロジェクトは Swift 言語モード 6.0、Package tools 6.0、approachable concurrency、app target の MainActor default isolation を使っている。SDK 27 のビルドと既存テストは成功したが、compiler 更新は言語モードや新APIの採用を必須にはしない。macOS 14+ の対応を維持し、互換コードを除去しないこともユーザーが決定した。

## Considered Options

- Swift 言語モードや並行性設定を更新し、Swift 6.4 の機能を追加する
- macOS 27 の音声・SwiftUI API へ移行する
- 現在の設定と実装を維持する

## Decision

現在の Swift 6 言語モード、Package tools 6.0、MainActor / approachable concurrency 設定を維持する。`async defer` に await を要する cleanup はなく、`weak let` に適合する unchecked Sendable の weak storage もない。Swift Testing はすでに採用済みで、Subprocess 1.0 への移行は compiler 互換性に不要な timeout・cancel・環境・I/O 契約の変更を伴う。

`InputPanelScriptStrip` は `reorderable` と `reorderContainer` を compiler 6.4 / macOS 27 gate、および旧OS fallback とともに実装済みである。現行の `onChange` を含む SwiftUI API に移行要件はない。

`AVAudioIONode.audioUnit` と旧 `AVAudioNode.installTap` は macOS 27 で非推奨だが、今回のビルド・テストで障害は確認されなかった。前者の `withAudioUnit`、後者の error-returning Objective-C overload への移行は macOS 26 / 27 の二経路と realtime lifecycle 検証を必要とする。新しい Swift 表記は確定していないため推測で採用しない。Speech の使用中 API に今回の移行を要求する非推奨は見つからず、未使用の `AnalyzerInput.buffer` getter のみ非推奨。read-only buffer tap は現行の変換処理との接続にコピー等を要し、移行の実益を確認できなかった。`NSTextView` / `NSPanel` に必要な移行もない。

## Consequences

今回の production code は変更しない。macOS 27 runtime は未検証であり、今回のSDK 27ビルドはその動作を証明しない。macOS の下限引き上げは別のユーザー判断とする。

## Sources

- Apple skill `swiftui-whats-new-27`: `references/reorderable.md`、`references/state-macro.md`、`references/content-builder.md`
- インストール済み Xcode 27.0 macOS SDK: `AVFAudio.framework/Headers/AVAudioIONode.h`、`AVAudioNode.h`、`AVFAudio.swiftinterface`（`withAudioUnit` の Swift overlay）
- [WWDC26: What's new in Swift](https://developer.apple.com/videos/play/wwdc2026/262/)
