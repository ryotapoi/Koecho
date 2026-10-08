---
status: current
---

# SwiftUI の入力パネルに AppKit のテキストエディタを組み込む

## 判断

入力パネルのレイアウトは SwiftUI に置き、入力欄は `NSTextView` subclass の `VoiceInputTextView` を `NSViewRepresentable` の `VoiceInputTextEditor` から組み込む。テキストの変更通知、IME の marked text、SpeechAnalyzer の volatile text、置換候補の描画とメニューはこの AppKit 境界で扱う。確定テキストの所有と書き込み経路は [ADR 0022](0022-finalized-input-text-ownership.md) に従う。

## 理由

SwiftUI `TextEditor` の内部 `NSTextView` を探すビュー階層走査や、コンテキストメニューを差し込むための isa-swizzling は、SwiftUI の内部構造に依存していた。AppKit のエディタを自分で所有すれば、marked text を壊さない更新、音声の未確定表示、確定時の通知、標準メニューへの操作追加を一つの境界で扱える。パネル全体を AppKit に置き換える必要はない。

## 採らなかった案

- SwiftUI `TextEditor` を維持して内部ビューを探す: 内部構造の変更に依存する。
- isa-swizzling でメニューを拡張する: ObjC runtime の動的なクラス変更に依存する。
- パネル全体を AppKit で作る: 入力欄以外の SwiftUI レイアウトまで置き換える理由がない。

## 境界

表示用バッファの storage 編集と callback suppression は `VoiceInputTextView` 内に閉じる。外側の controller や service は `TextViewOperating` の操作を使い、確定文字列は `AppState.setInputText(_:)` へ反映する。
