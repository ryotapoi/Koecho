# ADR 0010: NSTextView subclass replacing SwiftUI TextEditor

## Status

Accepted (supersedes ADR 0009)

## Context

InputPanelController は SwiftUI TextEditor の内部 NSTextView にアクセスするために複数の脆弱なハックに依存していた:

1. **`findTextView(in:)`**: NSHostingView のビュー階層を再帰走査して NSTextView を探す。Apple の内部実装変更で壊れるリスク
2. **isa-swizzling (ADR 0009)**: `objc_allocateClassPair` + `object_setClass` でコンテキストメニューをカスタマイズ。ObjC ランタイムの低レベル操作への依存
3. **バインディング遅延**: `$appState.inputText` が NSTextView.string より遅れるため、直接 `textView.string` を読む回避策が必要
4. **Dictation marked text**: テキスト確定タイミングをフックできず、リアルタイム置換の基盤がない

## Considered Options

- **Option A: 純 AppKit で全 UI を書き直す**: InputPanel の SwiftUI レイアウト（VStack + ボタン群 + prompt TextField）も含めて AppKit 化。スコープ過大
- **Option B: NSTextView サブクラス + NSViewRepresentable**: DictationTextView（NSTextView サブクラス）を DictationTextEditor（NSViewRepresentable）でラップし、既存の SwiftUI レイアウトを維持。ShortcutKeyRecorder で確立済みのパターン
- **Option C: 現状維持 + 個別修正**: findTextView と isa-swizzling を維持しつつ、各問題を個別に対処。根本的な脆弱性は残る

## Decision

We will replace SwiftUI TextEditor with a DictationTextView (NSTextView subclass) wrapped in DictationTextEditor (NSViewRepresentable).

主要な設計判断:

- **テキスト同期**: SwiftUI Binding は使わない。`DictationTextView.didChangeText()` → `onTextChanged` コールバックで外向き同期、`updateNSView` で内向き同期。`isSuppressingCallbacks` フラグでフィードバックループを防止
- **marked text ガード**: `updateNSView` で `hasMarkedText()` をチェックし、Dictation 中の上書きを防止
- **コンテキストメニュー**: サブクラスの `menu(for:)` override で直接実装。isa-swizzling と `import ObjectiveC` を廃止
- **Dictation フック**: `insertText(_:replacementRange:)` override で `onTextCommitted` を発火。将来のリアルタイム置換の基盤
- **readTextViewString() 廃止**: `didChangeText` → `onTextChanged` → `appState.inputText` の即時同期により、バインディング遅延問題が解消。常に `appState.inputText` を参照する

## Consequences

- **Positive**: `findTextView(in:)` 廃止。Apple の内部実装変更に影響されない
- **Positive**: isa-swizzling と `import ObjectiveC` 廃止。ObjC ランタイムへの低レベル依存を除去
- **Positive**: テキスト同期が明示的。バインディングの遅延問題が根本的に解消
- **Positive**: `insertText` override により Dictation テキスト確定タイミングをフック可能（将来のリアルタイム置換の基盤）
- **Negative**: NSViewRepresentable のボイラープレート（Coordinator、makeNSView/updateNSView）が増える
- **Negative**: `isSuppressingCallbacks` フラグの管理が必要。コントローラから textView.string を直接変更する箇所すべてでフラグを設定する必要がある
- **Neutral**: `DictationTextEditor` レイヤーの自動テストは SwiftUI ホスティング環境が必要で困難。手動検証で対応
