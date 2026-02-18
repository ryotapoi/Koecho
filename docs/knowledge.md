# Knowledge Base

このファイルはプロジェクト固有の技術的な知見・ハマりどころを蓄積する場所。

## このファイルの使い方

- **いつ読むか**: 新しい機能の実装前、バグ調査時に関連セクションを確認する
- **何を書くか**: 特定の状況で役立つ知見（罠、回避策、仕様の癖など）
- **CLAUDE.md との違い**: CLAUDE.md は毎回読み込まれる「常に守るルール」。ここは「該当する実装のときだけ必要な知見」
- **書き方**: セクション見出しでテーマ分け。各項目は簡潔に。症状・原因・対処がわかるように書く

---

## macOS / Process

- 子プロセス（Process）に `ProcessInfo.processInfo.environment` をそのまま渡さない。macOS の内部環境変数（`__CF_*` 等）経由で TCC 保護フォルダ（Photos, Music, iCloud）へのアクセスが発生し、許可ダイアログが出る
- `currentDirectoryURL` 未設定だと親の CWD を継承し、TCC 保護パスに当たりうる
- 対策: `PATH` と `HOME` のみ渡す + `currentDirectoryURL` を `FileManager.default.temporaryDirectory` に設定
- Process を使う箇所すべてに適用すること（ScriptRunner 等）
- 子プロセスのアクセスは親プロセス（Koecho）の権限として扱われる

## macOS / MenuBarExtra

- `LSUIElement = YES` と `setActivationPolicy(.accessory)` を両方指定すると MenuBarExtra のアイコンが表示されないことがある
- `LSUIElement = YES`（Info.plist）だけで Dock 非表示になるので、`setActivationPolicy(.accessory)` は不要
- `App.init()` 内での `NSApplication.shared` アクセスは SwiftUI のライフサイクル初期化と競合するリスクがある

## Swift / @Observable

- `@Observable` マクロはストアドプロパティのアクセスを変換する。通常の Swift では `init` 内の直接代入で `didSet` は呼ばれないが、`@Observable` がプロパティアクセスを書き換えるため、`init` 内でも `didSet` が発火する可能性がある
- Settings.swift の `scripts` プロパティは `init` 内代入 + `didSet { save() }` パターンでこの挙動に依存している。`persistsChanges` テストで検証済み
- `pasteDelay` / `scriptTimeout` は computed property + backing store パターンに移行済み（値クランプのため）。`init` では backing store に直接代入し `didSet` 問題を回避している
- Swift バージョンアップ時に `@Observable` マクロの挙動が変わると壊れうるので、テストが通ることを確認する

## macOS / NSPanel + SwiftUI TextEditor

- NSPanel を `orderOut` で非表示にした後、SwiftUI の `@Observable` バインディング経由で `inputText = ""` をセットしても、内部の NSTextView のテキストストレージに反映されないことがある。パネルが非表示の間、SwiftUI のビュー更新が遅延されるため
- 対策: `showPanel()` 時に `findTextView(in:)` でビュー階層から NSTextView を直接見つけて `textView.string = ""` でクリアする
- 初回表示では `makeKeyAndOrderFront` 直後に NSHostingView のレイアウトがまだ完了しておらず NSTextView が見つからない。`DispatchQueue.main.async` で次の RunLoop サイクルまで遅延させる必要がある
- `@FocusState` の `onAppear` は NSPanel の show/hide サイクルで再発火しない。`onChange(of: isVisible)` を使うか、`panel.makeFirstResponder(textView)` で直接セットする

## macOS / NSPanel + Escape キー

- NSPanel 内に TextEditor（NSTextView）があると、Escape キーは NSTextView が消費するため `keyDown(with:)` がパネルまで届かない
- 対策: `keyDown(with:)` ではなく `cancelOperation(_:)` を override する。NSTextView は Escape を受けると `cancelOperation(_:)` をレスポンダーチェーンに送る

## SwiftUI / Scene + .onAppear

- `.onAppear` は View モディファイアであり、Scene（`MenuBarExtra` 等）には使えない（コンパイルエラー: `has no member 'onAppear'`）
- `.menu` スタイルの MenuBarExtra ではメニューを開くまで content の View が表示されないため、content 内ビューの `.onAppear` も初回起動時には発火しない
- 対策: `.onChange(of:initial:true)` を Scene に付けて初回評価時にコードを実行する。`initial: true` により最初の body 評価で実行される

## Shell / echo -n

- macOS の `/bin/sh`（BSD sh）では `echo -n ''` が `-n` をリテラル文字列として出力する。`-n` フラグは bash 拡張であり POSIX 非標準
- 改行なし出力が必要な場合は `printf ''` を使う
- テストで空出力を作りたい場合も `printf ''` が安全

## macOS / Dictation (startDictation:)

- `startDictation:` セレクタを `NSApp.sendAction` で送ると responder chain 的には成功する（`true` を返す）が、パネル表示直後だと Dictation が実際には開始されない
- 原因: ウィンドウの表示・first responder 設定が完了した直後はまだ Dictation の受付準備ができていない模様
- 対策: `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` で遅延させてから送る。0.3秒で動作確認済み

## Foundation / NSRegularExpression テンプレート構文

- `NSRegularExpression.stringByReplacingMatches(in:range:withTemplate:)` の `withTemplate` パラメータは `$0`, `$1` 等をキャプチャグループ参照として解釈する
- 置換文字列にリテラルの `$` を含めたい場合は `NSRegularExpression.escapedTemplate(for:)` でエスケープが必要
- `escapedPattern(for:)` は検索パターン用、`escapedTemplate(for:)` は置換テンプレート用。両方忘れずに使い分ける

## テスト / UserDefaults 分離

- `UserDefaults.standard` を使うテストは前回のテスト実行データが残留し、次回のテストに干渉する
- 対策: テストでは `UserDefaults(suiteName: "test-\(UUID().uuidString)")!` で毎回新しいインスタンスを作る
- `AppState()` のデフォルト init は `Settings(defaults: .standard)` を使うため、テストでは `AppState(settings: Settings(defaults: isolatedDefaults))` のように明示的に渡す

## macOS / Dictation + SwiftUI TextEditor のテキスト変更検知

- macOS Dictation は「marked text（未確定テキスト）」を NSTextInputClient の内部バッファに保持し、確定（unmark）するまで `NSTextView.string` や `textStorage` を更新しない
- そのため Dictation 入力中は以下の方法では変更を検知できない:
  - SwiftUI `.onChange(of: appState.inputText)` → バインディングが同期されない
  - `NSText.didChangeNotification` → 発火しない
  - `NSTextStorage.didProcessEditingNotification` → 発火しない
  - ポーリングで `NSTextView.string` を読む → 未確定テキストが反映されていないので変化なし
- 変更が検知される条件: フォーカスを外す、音声入力を停止する、キーボード入力する、カーソル移動する（いずれも marked text が確定されるタイミング）
- 対策（将来）: NSTextView サブクラスを自作し `setMarkedText`/`insertText`/`unmarkText` を override してテキスト確定タイミングをフック。確定直後に置換ルールを適用する
- 対策（現行）: リアルタイム自動置換は断念。confirm 時の自動適用 + Ctrl+R / Replace ボタンによる手動トリガーで対応

## macOS / Dictation + フォーカス遷移

- SwiftUI の `@FocusState` でフォーカスを TextEditor から TextField に移動すると、macOS が Dictation セッションを停止する
- 例: Prompt ありスクリプト起動時に `focusedField = .prompt` をセットすると、TextEditor で実行中の Dictation が終了する
- 対策: フォーカス遷移後に `startDictation:` を再送信する。`DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` で遅延が必要（「macOS / Dictation (startDictation:)」セクション参照）
- `InputPanelContent.onPromptFocused` コールバックで `InputPanelController` に通知し、controller 側で Dictation を再起動する構成

## Swift / @MainActor + デフォルト引数

- `@MainActor` クラスの `init` にデフォルト引数で別の `@MainActor` 型のインスタンス生成を書くと、デフォルト引数式は caller の actor isolation を継承しないためコンパイルエラーになる
- 対策: designated init（引数必須）+ convenience init（デフォルト値生成）に分離する。`convenience init` は `@MainActor` クラスの isolation を持つため、中で `@MainActor` 型を生成できる
