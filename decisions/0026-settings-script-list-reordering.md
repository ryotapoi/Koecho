---
status: current
---

# ADR 0026: Settings の Scripts 一覧は `.onMove` を維持する

## Date

2026-09-27

## Context

D11 では、Settings の Scripts 一覧を `List` のまま SwiftUI 27 の `ForEach.reorderable` と `reorderContainer` に置き換え、既存の選択・並べ替え・保存を保てるか試した。比較環境は macOS 27.0、Xcode 27.0（27A266a）。

同じ scripts と UUID 選択を使った隔離画面で、ユーザーが4種類の List をクリックした。旧 `.onMove` と `.reorderable()` 単独では行を選択できた一方、`.reorderContainer` を付けた列は `isEnabled` が false / true のどちらでもクリックで選択が更新されなかった。行の `.tag(script.id)` を外した試行でも改善しなかった。これは今回の環境で確認した現象であり、SwiftUI API 全般の仕様や内部原因は特定していない。

## Considered Options

- 新しい並べ替え API を Settings の `List` へ採用し、別の選択処理を追加する。
- Settings では既存の `.onMove` を維持する。

## Decision

Settings の Scripts 一覧は `.onMove` を維持する。D11 の採否基準は、選択の明確な退行や追加コストがあれば旧方式を維持するものだった。新 API 版は並べ替え先の変換、既存 helper の呼び出し、設定 setter への代入が必要で、旧方式の `settings.moveScripts(from:to:)` への接続より処理が増える。選択を迂回処理で補う前提で採用する理由はない。

入力パネルの script strip は別の UI であり、既存の新 API 利用を変更しない。

## Consequences

Settings の選択と編集対象、既存の保存・保護経路を維持する。D11 で試した新 API 版は採用しない。
