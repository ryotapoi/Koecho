---
status: current
---

# macOS 27 と SpeechAnalyzer を基準にし、Swift 6 設定を維持する

## 判断

App と KoechoKit の対応下限を macOS 27.0 とする。音声認識には Speech framework の `SpeechAnalyzer` と、自動句読点を持つ `DictationTranscriber` を採用する。音声の未確定結果を入力欄に表示し、キーボード入力との併用を保つ。音声の有効・無効と保存値は [ADR 0025](0025-speechanalyzer-only-voice-input.md) が定める。

Swift の言語モードと Package tools version は 6.0 を維持する。App target の MainActor default isolation と、Xcode の全 target の approachable concurrency の設定も維持する。Xcode / SDK を更新しただけで言語モードや並行性の契約を変えない。

## 理由

macOS 標準 Dictation の `startDictation:` は開始成功を確認できず、起動タイミングや marked text による制御の限界があった。SpeechAnalyzer ならオンデバイスで認識開始・終了と volatile 結果をアプリで扱える。`DictationTranscriber` は口述向けの句読点を付けられる。macOS 27 を下限にすることで旧 OS 専用の可用性分岐は不要になる。

現在のコードは Swift 6.0 言語設定でビルドされる。compiler や SDK の新しさだけでは言語モード更新による移行コストや並行性境界の変更を正当化しない。

## 採らなかった案

- 標準 Dictation と SpeechAnalyzer の選択を残す: 利用者に認識実装の選択と Dictation 専用の起動制御を負わせる。
- `SFSpeechRecognizer` を音声入力の本線にする: 現行の口述向け結果・制御に対する選択理由がない。
- SDK 更新と同時に Swift 言語モード・並行性設定を変える: 必要な互換性要件がなく、別の意味の変更を混ぜる。

## 境界

音声セッションは入力デバイス、モデル、locale、音声 callback に関わる。`VoiceInputEngine` をエンジンと controller の境界とし、入力欄と音声エンジンの所有はそれぞれの実装境界に置く。再生成と重複抑制の判断は [ADR 0032](0032-speech-overlap-defense.md) が定める。入力パネルの script strip では macOS 27 の並べ替え API を使い、Settings の Scripts 一覧で `.onMove` を維持する理由は [ADR 0026](0026-settings-script-list-reordering.md) が定める。
