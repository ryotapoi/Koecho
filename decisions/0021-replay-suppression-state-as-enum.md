# ADR 0021: Replay 抑制状態の enum 状態機械化

## Status

Accepted

## Context

SpeechAnalyzer の transcriber 再生成（ADR 0016）後、バッファ残存音声のリプレイを抑制するために、VoiceInputCoordinator は 3 つのフラグ（`isLocallyFinalized: Bool` / `localFinalizedText: String?` / `replaySuppressionDeadline: Date?`）を組み合わせて状態を表現していた。「`isLocallyFinalized` + deadline nil = restart 進行中」のような暗黙の組み合わせ規則がコメントでしか表現されておらず、InputPanelController が closure から 2 つのフラグを直接セットするなど、不正な組み合わせ（例: `localFinalizedText` なしの `isLocallyFinalized`、状態クリア後に restart Task 完了が書き込む宙吊りの deadline）を型レベルで防げなかった。

関連フラグは他に `transcriberAlreadyRestarted` / `accumulatedFinalizedText` / `isStoppingEngine` の 3 つがある。

## Considered Options

- **A: 3 フラグのみを `enum ReplayState`（idle / restartInProgress / suppressing）に集約**: 状態機械を成す 3 つだけを enum 化し、遷移を enum の mutating メソッドに置く
- **B: 6 フラグ全部を 1 つの型に集約**: 関連フラグをすべて含む構造体/enum にする
- **C: 現状維持（フラグ + コメント）**: 規約とテストで守る

## Decision

We will model the replay suppression lifecycle as a nested `enum VoiceInputCoordinator.ReplayState` with cases `idle` / `restartInProgress(localText:)` / `suppressing(localText:, deadline:)`, with transitions as mutating methods on the enum (`recordLocalFinalization(_:)` / `beginSuppression(deadline:)`). External callers go through `VoiceInputCoordinator.recordLocalFinalization(_:)`.

B を却下した理由: 残り 3 フラグはライフサイクルが異なる。`accumulatedFinalizedText` は replay サイクルをまたいで持続する重複除去用の蓄積、`transcriberAlreadyRestarted` は idle 中でも true になり得る Task 重複起動ガード、`isStoppingEngine` はエンジン停止ライフサイクル。意味境界が違うものを 1 つの型に混ぜると、enum の各 case に直交する次元が必要になり状態機械が崩れる。

C を却下した理由: 不正な組み合わせは型で表現不能にする方が、コメント・テストより強い防御になる。

## Consequences

- 不正な組み合わせ（localText なしの finalized 状態、宙吊り deadline）がコンパイル時に表現不能になった
- 旧コードとの意図的な挙動差が 1 つある: 状態クリア後に restart Task が完了した場合、旧コードは宙吊り deadline を書き込み、直後のローカル確定が stale deadline 付き suppressing 相当になった。新コードでは `beginSuppression` が idle で no-op となり、直後のローカル確定は restartInProgress（全 volatile 抑制、次の restart 完了まで）になる。抑制が強い側に倒れ、上限は次の restart 完了 / didFinalize 到着
- 既存ハザードは挙動保存のため温存（本 ADR のスコープ外）: restart Task の `shouldSuppressReplay` を spawn 時にキャプチャするため await 中のローカル確定を拾わない、suppressing 中の再確定が deadline を維持したまま localText を差し替える、連続ローカル確定で先の localText が上書きされる
- テストは遷移メソッド（`recordLocalFinalization` / `beginSuppression`）で状態を組み立てるため、不正な状態を arrange できなくなった
