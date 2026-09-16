# Constraints

## 技術スタック

- Swift / SwiftUI / macOS 14.0+
- NSPanel（フローティングウィンドウ）
- NSEvent（グローバルホットキー）
- Process + Pipe（シェルスクリプト実行）
- CGEvent（ペースト）
- Accessibility API（選択テキスト取得）
- MenuBarExtra（メニューバー常駐）
- UserDefaults（設定保存）
- os.Logger（ロギング）
- Speech framework / SpeechAnalyzer（macOS 26+ オンデバイス音声認識）
  - transcriber は `DictationTranscriber` を使う（`SpeechTranscriber` ではない）。句読点が自動で入るため
- AVAudioEngine（マイク入力取得。SpeechAnalyzerEngine が使用）
- AUHAL AudioUnit（入力レベルメーター。CoreAudio を直接使用し、AVAudioEngine の tap は使わない）
- Swift Package Manager: `Packages/KoechoKit`、`swift-tools-version: 6.0`（`nonisolated(unsafe)` を使うため）
- 開発基準は Xcode 27.0 / macOS SDK 27 / Swift compiler 6.4。runtime 下限は macOS 14.0
- Swift 言語モードは `SWIFT_VERSION = 6.0`。Xcode の全 target で `SWIFT_APPROACHABLE_CONCURRENCY = YES`、app target では `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` を使う

検出: Xcode プロジェクト設定・import 文で確認

## 前提条件

- App Sandbox は無効（CGEvent / Process / グローバルホットキー / Accessibility API のため）
  - 検出: Koecho.entitlements に com.apple.security.app-sandbox キーが存在しないこと
- アクセシビリティ権限が必要（ペースト・選択テキスト取得）
  - 検出: AXIsProcessTrusted() のランタイムチェック（実装済み）
- Input Monitoring 権限が必要（NSEvent.addGlobalMonitorForEvents）。macOS バージョンによりアクセシビリティ権限と別途必要になるケースがある
  - 検出: ランタイムでイベント監視の成否を確認
- macOS Dictation がユーザーにより有効化されている必要がある（無効の場合はキーボード入力のみ）
  - 検出: 自動検出困難。Dictation 開始失敗時にユーザー通知
- `startDictation:` セレクタは公開 API ではない。将来の macOS で動作しなくなる可能性があり、Mac App Store 配布の障害にもなる（mission.md の非目標により配布はしない）
  - 検出: `Selector(("startDictation:"))` の文字列リテラル経由呼び出し
