---
regen: compiled
sources:
  - Koecho/KoechoApp.swift
  - Koecho/MenuBarContent.swift
  - Koecho/InputPanel.swift
  - Koecho/HistoryView.swift
  - Koecho/GeneralSettingsView.swift
  - Packages/KoechoKit/Sources/KoechoCore/ScriptRunner.swift
  - Packages/KoechoKit/Sources/KoechoCore/ReplacementEngine.swift
---

# macOS / AppKit

## 外部プロセス実行

- `ScriptRunner` は `/bin/sh -c` でユーザースクリプトを起動する。
- `ProcessInfo.processInfo.environment` を丸ごと継承しない。親プロセスの `__CF_*` などの TCC 関連値を渡すと、子プロセス側でマイク権限などのダイアログが出ることがある。
- 子プロセスには `PATH` / `HOME` と `KOECHO_*` コンテキストだけを渡す。
- `currentDirectoryURL` は一時ディレクトリに固定する。アプリの起動 cwd に依存させると、ユーザー環境や Xcode 起動時の状態に引きずられる。
- `echo -n` はシェル差があるため、テストやサンプルで改行なし出力が必要な場合は `printf` を優先する。

## MenuBarExtra / LSUIElement

- `MenuBarExtra` 内の SwiftUI `@State` は表示ごとに作り直されやすい。メニュー内で保持したい状態は `App` 側で所有し、クロージャ経由で渡す。
- LSUIElement アプリでは `openWindow(id:)` だけだと Settings が他アプリの背後に出ることがある。`MenuBarContent.bringSettingsWindowToFront()` は少し待ってから対象ウィンドウを探し、`level` を一時的に上げて `activate()` する。
- `openWindow(id:)` 直後に処理すると、メニューの dismiss とウィンドウ生成の順序に負けることがある。短い delay はこの順序を吸収するためにある。

## Scene / Settings

- `KoechoApp` はテスト時にアプリ本体の副作用を避けるため、`TEST_HOST` 環境では `AppState` を初期化しない。
- SwiftUI `Settings` は型名と衝突しやすい。Koecho の設定モデルは `KoechoCore.Settings` として参照する。
- macOS SwiftUI の `Scene` では `onAppear` が使えないケースがある。ウィンドウの初期同期は `View` 側のライフサイクルや明示的なコールバックへ寄せる。

## AppKit UI

- `NSPanel.cancelOperation(_:)` は Escape を捕捉できる。Koecho の入力パネルでは SwiftUI `.keyboardShortcut(.cancelAction)` ではなく、`InputPanel` 側の AppKit hook を使う。
- macOS の `contextMenu` preview は不要な空白を作ることがある。履歴などの一覧では、`NSViewRepresentable` でプレビューなしの menu を組む方が安定する。
- `TextField` の `onChange` で空文字を即削除すると、かな入力の未確定文字が purge されることがある。確定操作や focus out まで削除を遅らせる。
- `ReplacementRule` は `NSRegularExpression` の template syntax を使う。plain text rule の置換文字列は `NSRegularExpression.escapedTemplate(for:)` を通し、`$` や `\` の escaping を手書きしない。regex rule の置換文字列では `$1` などの template syntax を意図的に許可する。
