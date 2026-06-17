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
- AVAudioEngine（マイク入力取得）

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
