# 選択テキストを inputText の初期値に設定する

## Context

現在、ホットキー押下時にフォアグラウンドアプリの選択テキストを Accessibility API で読み取り、スクリプトの環境変数（`KOECHO_SELECTION`）として渡しているが、パネルの UI には表示されない。

選択テキストを `inputText` の初期値として設定することで：
- ユーザーが選択テキストを見ながら音声で追記できる
- LLM スクリプトに渡す stdin に既存テキスト＋新しい入力が含まれ、コンテキストが豊富になる
- 選択テキストがない場合は今まで通り白紙で開く

コピー（読み取り専用）で取り込む。切り取りは行わない。常にこの動作をする（ホットキーの種類は増やさない）。

## 前提

- `showPanel()` のコードフロー: `selectedText` をセット → `inputText = selectedText` → `clearTextView()` の順序に依存する
- `clearTextView()` 内の `isSuppressingCallbacks = true` により `didChangeText` → `onTextChanged` コールバックは発火しない（意図的）
- `clearTextView()` で `textView.string = appState.inputText` とするため、`DictationTextEditor.updateNSView` の `textView.string != text` 条件が false になり、SwiftUI 側の同期パスは textView を上書きしない

## Step 1: SelectedTextReader をプロトコル化

**ファイル:** `Koecho/SelectedTextReader.swift`

`Pasting` プロトコルのパターン（`ClipboardPaster.swift`）に倣い、`SelectedTextReading` プロトコルを抽出する。

```swift
protocol SelectedTextReading {
    func read(from pid: pid_t) -> SelectedTextResult?
}
```

`Sendable` は付けない。`InputPanelController` は `@MainActor` であり、プロパティ `selectedTextReader` はメインスレッドからのみアクセスされる。テストの MockSelectedTextReader が可変プロパティを持つため `Sendable` にすると Swift の並行性チェックと衝突する。

既存の `SelectedTextReader` を `SelectedTextReading` に準拠させる。

**ファイル:** `Koecho/InputPanelController.swift`

`selectedTextReader` プロパティの型を `SelectedTextReader` → `any SelectedTextReading` に変更。init パラメータも同様。

## Step 2: showPanel() で inputText に選択テキストを設定

**ファイル:** `Koecho/InputPanelController.swift` — `showPanel()` (行143)

```swift
// 変更前
appState.inputText = ""

// 変更後
appState.inputText = appState.selectedText
```

## Step 3: clearTextView() で選択テキストをセットしカーソルを末尾に配置

**ファイル:** `Koecho/InputPanelController.swift` — `clearTextView()` (行153-173)

同期パスと async フォールバックパスの両方を変更する。`setSelectedRange` は `makeFirstResponder` の**後**に呼ぶ（安全側に倒すため）。

同期パス（行156-161）:
```swift
textView.isSuppressingCallbacks = true
textView.string = appState.inputText                    // 変更: "" → appState.inputText
textView.isSuppressingCallbacks = false
panel.makeFirstResponder(textView)
textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))  // 追加
textView.scrollRangeToVisible(textView.selectedRange())  // 追加: 長文の場合にスクロールを追随
scheduleDictation()
```

async フォールバックパス（行163-173）:
```swift
textView.isSuppressingCallbacks = true
textView.string = appState.inputText                    // 変更: "" → appState.inputText
textView.isSuppressingCallbacks = false
if textView.window != nil {
    self.panel.makeFirstResponder(textView)
    textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))  // 追加
    textView.scrollRangeToVisible(textView.selectedRange())  // 追加
}
self.scheduleDictation()
```

**実装時の変更**: `setSelectedRange` / `scrollRangeToVisible` を `window != nil` ブロック内に移動。理由: `textView.window == nil` の場合に `setSelectedRange` を呼んでも `makeFirstResponder` されていないため効果がなく、将来的にカーソル位置保証が崩れるリスクがある（Codex レビュー指摘）。

注意: `NSRange` の `location` は UTF-16 オフセットなので `(textView.string as NSString).length` を使う。`String.count`（Character 数）は不可。

## Step 4: テスト追加

**ファイル:** `KoechoTests/InputPanelControllerTests.swift`

### 4a. MockSelectedTextReader を追加

```swift
private final class MockSelectedTextReader: SelectedTextReading {
    var resultToReturn: SelectedTextResult?
    func read(from pid: pid_t) -> SelectedTextResult? { resultToReturn }
}
```

### 4b. makeController にモック注入を追加

`makeController` ヘルパーに `selectedTextReader` パラメータを追加（デフォルト `SelectedTextReader()`）。

### 4c. テストケース追加

- `showPanelWithSelectedTextSetsInputText`: MockSelectedTextReader が選択テキストを返す → `showPanel()` 後に `appState.inputText == selectedText` かつ `appState.selectedText == selectedText` を検証。`showPanel()` は `NSWorkspace.shared.frontmostApplication` で `frontmostApplication` を自動設定するので、テスト環境でも `read()` は呼ばれる。MockSelectedTextReader は pid を無視して固定値を返す。
- `confirmWithSelectedTextOnly`: MockSelectedTextReader でテキストありの状態から、追記なしで `confirm()` → 選択テキスト（trim 後）が貼り付けられることを検証。`appState.frontmostApplication = NSRunningApplication.current` を設定すること（既存の `confirmSuccessClearsState` と同様）。
- 既存テスト `showPanelSetsState` は変更なし（テスト環境では `SelectedTextReader` のデフォルトが使われ、Accessibility API が trusted でないため nil を返す → `inputText == ""`）。

## Step 5: spec.md の更新

**ファイル:** `docs/spec.md`

基本フロー Step 2 を以下のように変更:

```
2. フォアグラウンドアプリの選択テキストを取得・保存し、初期テキストとして表示（選択なしの場合は空）
```

## 変更しないもの

- `KOECHO_SELECTION` 環境変数は引き続き渡す（スクリプトが「元の選択テキスト」と「編集後の全文」を区別できるように）
- ホットキーの種類は増やさない
- 切り取りは行わない（読み取りのみ）
- `clearTextView` のリネームはスコープ外
- `showPanel()` 2回目呼び出し時の `inputText` 非リセット（既存テスト `showPanelTwicePreservesText` で検証済み）
- 選択テキストのみで追記なし → 確定で貼り付け（既存の trim 処理は適用される）
- 初期テキスト（選択テキスト）に自動置換ルールは適用しない。`clearTextView()` で `isSuppressingCallbacks = true` のまま設定するため `onTextChanged` が発火せず、自動置換は走らない。これは意図的な動作（ユーザーが意図していない初期テキストの変更を防ぐ）

## 検証

1. `xcodebuild build` — ビルド成功
2. `xcodebuild test` — テスト成功（既存テスト + 新規テスト）
3. 手動確認:
   - テキストエディタで文字列を選択 → ホットキー → パネルに選択テキストが表示され、カーソルが末尾にある
   - 選択なし → ホットキー → パネルが白紙で開く（従来通り）
   - 選択テキスト表示後、音声入力で追記できる
   - 選択テキストのみで追記なし → 確定で選択テキスト（trim 適用後）が貼り付けられる
   - スクリプト実行で stdin に全文（選択テキスト＋追記）が渡る
