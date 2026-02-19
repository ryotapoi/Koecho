# ADR 0009: isa-swizzling for TextEditor context menu customization

## Status

Accepted

## Context

InputPanel の TextEditor で音声入力テキストを選択し、右クリックからその場で置換ルールを登録できるようにしたい。SwiftUI TextEditor のコンテキストメニューをカスタマイズする必要があるが、標準の手段では困難:

- SwiftUI の `.contextMenu {}` は NSTextView の標準メニュー（Cut/Copy/Paste/Spelling 等）をすべて消し、カスタムメニューのみに置き換える
- SwiftUI には NSTextView の標準メニューにアイテムを追加する API がない
- NSTextView に直接アクセスするには、既存の `findTextView(in:)` と同じくビュー階層走査が必要

## Considered Options

- **Option A: `.contextMenu {}`**: 標準メニューが消えるため不可。Cut/Copy/Paste が使えなくなる
- **Option B: NSViewRepresentable で NSTextView を自前管理**: TextEditor を捨てて NSTextView を直接使う。SwiftUI バインディングとの同期を自分で実装する必要があり、コスト大。T2 タスクで予定している方針
- **Option C: isa-swizzling (`object_setClass`) で動的サブクラス化**: ObjC ランタイムで NSTextView の `menu(for:)` を override し、標準メニューの後にカスタムアイテムを追加する。既存の `findTextView(in:)` インフラを活用できる

## Decision

We will use isa-swizzling (`object_setClass`) to create a dynamic subclass of the NSTextView found inside SwiftUI TextEditor, overriding `menu(for:)` to append a custom menu item to the standard context menu.

Controller への参照は `objc_setAssociatedObject` (`OBJC_ASSOCIATION_ASSIGN`) で NSTextView に格納する。重複防止はクラス名のプレフィックスチェックで行う。

## Consequences

- **Positive**: 標準メニュー（Cut/Copy/Paste 等）を維持したまま、カスタムアイテムを追加できる
- **Positive**: 既存の `findTextView(in:)` と組み合わせるだけで実装でき、コスト小
- **Negative**: Apple が SwiftUI TextEditor の内部 NSTextView クラスを変更した場合に壊れる可能性がある（`findTextView(in:)` と同じリスク）
- **Negative**: ObjC ランタイム API への依存（`object_setClass`, `objc_allocateClassPair`, `objc_setAssociatedObject`）
- **Neutral**: T2（NSViewRepresentable での NSTextView サブクラス化）を実装すれば、この isa-swizzling は不要になる。T2 のリファクタ対象として記録済み
