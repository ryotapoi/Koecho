# ADR 0013: AUHAL for level metering

## Status

Accepted

## Context

設定画面のマイク入力レベルメーターでは、選択されたオーディオ入力デバイスからリアルタイムにオーディオデータを取得し、RMS を計算して表示する必要がある。

当初は AVAudioEngine の `inputNode.installTap` を使っていたが、非デフォルトデバイス（例: AirPods Pro）を `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` で設定しても、tap コールバックが一切呼ばれない問題が発覚した。原因は AVAudioEngine の `inputNode` が遅延初期化されたシングルトンであり、アクセス後にデバイスを設定しても内部ルーティングが更新されないため。

SpeechAnalyzerEngine も同じ AVAudioEngine パターンを使っているが、こちらは SpeechAnalyzer の AsyncStream パイプラインに依存しており、置き換えが大工事になる。

## Considered Options

- **AVAudioEngine + `AudioUnitSetProperty`**: 当初の実装。デフォルトデバイスでは動作するが、非デフォルトデバイスでは tap コールバックが呼ばれない
- **システムデフォルトデバイスの一時変更**: `AudioObjectSetPropertyData` で `kAudioHardwarePropertyDefaultInputDevice` を書き換える。他アプリに副作用があり却下
- **Aggregate Device 作成**: `AudioHardwareCreateAggregateDevice` でラップする。レベルメーター用途には過剰
- **AUHAL (kAudioUnitSubType_HALOutput) 直接使用**: Enable IO → Set Device → Initialize → Start の順序でデバイスを確実に設定可能。Input callback + `AudioUnitRender` でオーディオデータを取得

## Decision

We will use AUHAL AudioUnit directly for the level metering in AudioDeviceManager.

SpeechAnalyzerEngine は AVAudioEngine を継続使用する。非デフォルトデバイスでの音声認識は将来の課題とする。

## Consequences

- レベルメーターが任意の入力デバイスに対して正しく動作する
- AUHAL は低レベル API のため、AudioBufferList の手動管理（allocate / deallocate）、C コールバック、audio I/O スレッドの制約（メモリ確保禁止、ロック禁止）を意識する必要がある
- AVAudioEngine と AUHAL の2つの異なるオーディオ取得方式がコードベースに混在する
- SpeechAnalyzerEngine の非デフォルトデバイス対応は未解決のまま残る
