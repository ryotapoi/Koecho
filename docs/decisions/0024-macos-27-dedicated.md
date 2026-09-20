# ADR 0024: macOS 27 専用化

## Status

Accepted

## Date

2026-09-20

## Context

Koecho は macOS 14 を下限として、macOS 26 で追加された SpeechAnalyzer を可用性判定と旧 OS 向け UI を介して提供していた。Xcode 27 採用時の ADR 0023 は下限を維持し、互換コードを残す判断だった。現在は macOS 27 以降を対象に固定するため、保存された engine 選択を実効値へ補正する経路、SpeechAnalyzer の可用性分岐、script 並べ替えの旧 OS 表示を維持する理由がなくなった。

## Considered Options

- macOS 14 を下限として可用性判定と旧 OS UI を維持する
- macOS 27 を下限にし、旧 OS 専用の分岐だけを除去する
- SpeechAnalyzer または Dictation のどちらかを廃止する

## Decision

macOS 27.0 を App と Package の対応下限とする。Off / Dictation / SpeechAnalyzer は引き続き保存可能な engine 選択であり、保存した値をそのまま使用する。SpeechAnalyzer を既定とし、Dictation と Off は廃止しない。Settings は3つの engine を常に選択可能にし、SpeechAnalyzer の locale と microphone 選択も維持する。

macOS 27 の `reorderable` / `reorderContainer` は条件なしで使用する。ただし、script 実行中または prompt 中に並べ替えを禁止する表示と実行可否は OS 互換ではないため維持する。

## Consequences

ADR 0012 の macOS 14–25 向け Dictation 専用経路と SpeechAnalyzer availability、ADR 0019 の旧 OS Toggle、ADR 0023 の macOS 14 下限・reorder fallback に関する判断を supersede する。これらの ADR にある SpeechAnalyzer / Dictation / Off の採用理由、音声 lifecycle、Xcode 27 の言語モード維持、および audio API 移行を保留する判断は維持する。
