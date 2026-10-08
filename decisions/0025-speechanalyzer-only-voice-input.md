---
status: current
---

# ADR 0025: SpeechAnalyzer 専用の音声入力

## Date

2026-09-21

## Context

音声実装の選択は、設定・入力パネル・音声 lifecycle に複数の状態と Dictation 専用の制御を持ち込んでいた。macOS 27 では SpeechAnalyzer を production の音声認識として使用できるため、ユーザーが実装を選ぶ必要はない。

## Considered Options

- Dictation と SpeechAnalyzer の選択を維持する
- SpeechAnalyzer だけを提供し、音声入力の有効・無効だけを選択する

## Decision

production の音声認識は SpeechAnalyzerEngine のみとする。設定と入力パネルの Voice ボタンは `isVoiceInputEnabled` の Bool を操作する。既存の `voiceInputMode` 保存キーは canonical な `on` / `off` を保存し、`dictation`、`speechAnalyzer`、`on` は有効、`off` は無効、欠損値と未知値は有効として再保存する。

無効時は認識開始と出力音量ダッキングを行わず、キーボード入力・確定・キャンセルは維持する。IME marked text の扱いと SpeechAnalyzer の volatile text / replay 抑止は維持する。

## Consequences

DictationEngine、`startDictation:`、Dictation 専用の focus/restart lifecycle を削除する。ADR 0001、0005、0012、0019、0024 の Dictation 起動、複数 engine、engine mode、3選択に関する判断を supersede する。macOS 27 基準、SpeechAnalyzer の locale・モデル・マイク管理、および既存の音声テキスト lifecycle は維持する。
