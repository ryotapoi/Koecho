---
status: current
---

# マイクレベル計測に AUHAL を使い、音声認識には AVAudioEngine を使う

## 判断

設定画面のマイク入力レベル計測には `AudioInputLevelMonitor` の AUHAL AudioUnit を使う。選択した入力デバイスを UID から解決し、計測用 AudioUnit の初期化前に設定する。音声認識の音声取得は `SpeechAnalyzerEngine` の `AVAudioEngine` を維持し、選択 UID がある場合は `inputNode.withAudioUnit` を通じて対象デバイスを設定する。出力音量の ducking は別の [ADR 0014](0014-separate-output-volume-ducker-class.md) に従う。

## 理由

レベル計測を `AVAudioEngine.inputNode.installTap` で行った当時の実機調査では、非既定デバイスの指定後に tap callback が来ない例があった。AUHAL は Enable IO、デバイス指定、初期化、開始の順を明示でき、計測の対象を制御できる。音声認識は SpeechAnalyzer への音声パイプラインと AVAudioEngine に依存するため、計測だけを AUHAL に分ける判断を採った。

この観測を「AVAudioEngine では選択デバイスを一切使えない」という一般則にはしない。現在の音声認識には選択デバイスの設定経路があり、失敗時は既定デバイスへ戻る。

## 採らなかった案

- 計測に従来の `AVAudioEngine.inputNode` tap を使う: 当時の非既定デバイスで callback が得られなかった。
- システムの既定入力デバイスを一時変更する: 他アプリの入力元にも影響する。
- 計測だけのため Aggregate Device を作る: 管理が過大になる。
- 音声認識経路まで AUHAL に置き換える: SpeechAnalyzer の既存パイプライン全体を変える必要がある。
