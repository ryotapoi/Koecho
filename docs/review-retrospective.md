# レビュープロセス振り返り分析

## 目的

初期段階の実装（9コミット）を振り返り、以下の3問に答える:

1. self-plan-review に追加すべきもの、改善すべき観点はあるか。UnitTests の観点は含まれているか
2. self-impl-review に追加すべきもの、改善すべき観点はあるか。UnitTests の観点は含まれているか
3. plan→実装→レビュー→コミットを人間の介入なしで回しても品質が担保できるか

## 分析方法

全コミットの diff パターンを抽出し、「初回実装→見直し」の痕跡を分類。knowledge.md への記録（＝実装中に発見された問題の痕跡）を手がかりにした。

## 対象コミット

```
2684630 chore: initial project setup
2752ffd feat: add menu bar resident app skeleton
37bfc19 feat: add AppState and Settings for core state management
aaad3fd feat: add floating input panel with menu toggle
e3866f7 feat: add global hotkey toggle with Fn key tap detection
04d66cd feat: add ScriptRunner for shell script execution via Process + Pipe
8c9be49 feat: add ClipboardPaster and SelectedTextReader for paste flow
5e58d48 feat: add script execution UI to InputPanel
3685894 feat: add script management UI with add, edit, and delete
```

## diff パターンの分類結果

### カテゴリ A: macOS プラットフォーム固有の罠（5件）

| コミット | 問題 | knowledge.md |
|----------|------|:---:|
| Step 1 (2752ffd) | `LSUIElement` と `setActivationPolicy(.accessory)` の競合。両方指定すると MenuBarExtra のアイコンが消える | Yes |
| Step 3 (aaad3fd) | NSPanel 内の TextEditor が Escape キーを消費し `keyDown(with:)` がパネルに届かない → `cancelOperation(_:)` で対処 | Yes |
| Step 4 (e3866f7) | `.onAppear` は Scene（MenuBarExtra）に使えない。`.menu` スタイルではメニューを開くまで View が表示されず `.onAppear` も発火しない → `onChange(of:initial:true)` で対処 | Yes |
| Step 5 (04d66cd) | macOS の `/bin/sh`（BSD sh）で `echo -n ''` が `-n` をリテラル出力する → `printf ''` で対処 | Yes |
| Step 6 (8c9be49) | NSPanel 非表示中に SwiftUI `@Observable` バインディング経由のテキストクリアが反映されない → `findTextView(in:)` で NSTextView を直接操作 | Yes |

**特徴**: プラットフォーム API の undocumented / non-obvious な挙動。事前のレビューでは検出不可能。ビルド・実行して初めて判明する。

### カテゴリ B: Swift コンパイラ / 言語仕様の罠（2件）

| コミット | 問題 | knowledge.md |
|----------|------|:---:|
| Step 2 (37bfc19) | `@Observable` マクロが `init` 内でも `didSet` を発火させる（通常の Swift と異なる挙動） | Yes |
| Step 2 (37bfc19) | `@MainActor` クラスの `init` のデフォルト引数で別の `@MainActor` 型を生成するとコンパイルエラー → designated + convenience init に分離 | Yes |

**特徴**: コンパイルエラーまたは予想外のランタイム挙動。ビルドして初めて判明。

### カテゴリ C: 仕様変更 / 設計見直し（2件）

| コミット | 変更内容 |
|----------|---------|
| Step 1 (2752ffd) | spec.md から `setActivationPolicy(.accessory)` の記述を削除（カテゴリ A の問題による） |
| Step 2 (37bfc19) | CLAUDE.md のレビュールール改善（収束判定の追加、コミットセクション分離） |

**特徴**: 実装中に仕様やプロセスの問題が見つかりドキュメントを更新。

### カテゴリ D: 後続ステップでの統合変更（3件）

| コミット | 変更内容 |
|----------|---------|
| Step 6 (8c9be49) | InputPanelController を DI 対応に拡張（`Pasting` プロトコル導入、`MockPaster` でテスト可能に） |
| Step 7 (5e58d48) | InputPanelController にスクリプト実行機能を統合（`makeScriptRunner` DI 追加） |
| Step 8 (3685894) | KoechoApp のメニュー構造をリファクタ（`MenuBarContent` View 切り出し） |

**特徴**: 新機能追加時に既存コードを拡張する正常な開発フロー。問題ではない。

### カテゴリ E: テスト不足 / テスト品質

テスト漏れのパターンは確認されなかった。各ステップで対応するテストが同時にコミットされている。

ただし以下の制約がある:
- `HotkeyService` のテストなし（グローバルイベントモニターのためユニットテスト困難）
- `SelectedTextReaderTests` は「テスト環境では nil を返す」のみ（Accessibility API の制約）
- View 系（`InputPanelContent`, `ScriptEditView`, `ScriptManagementView`）のテストなし

## 現在のレビュースキルの観点

### self-plan-review（5観点）
1. 整合性チェック — 仕様書との矛盾、変更対象ファイル漏れ
2. 状態遷移チェック — 異常系、境界条件、非同期タイミング
3. 暗黙の前提チェック — 未明示の仮定、責務分担
4. 過剰設計チェック — YAGNI 違反、不要な互換性
5. テスト品質チェック — テスト計画、エッジケース、アサーション品質

### self-impl-review（5観点）
1. プラン準拠チェック — 全ステップ実装済みか、スコープクリープ
2. 仕様整合性チェック — 仕様書との矛盾、命名規則
3. エッジケース・異常系チェック — エラーハンドリング、リソース解放
4. 過剰設計チェック — YAGNI 違反、不要な互換性
5. テスト品質チェック — テスト網羅性、アサーション品質

両方とも UnitTests の観点は Agent 5（テスト品質チェック）に含まれている。

## 暫定的な所見

### レビュー観点の追加について
- カテゴリ A/B（全7件中7件）はプラットフォーム固有 or コンパイラの罠。プラン段階・コードレビュー段階のいずれでも事前検出は困難
- レビュー観点を増やしても、これらの問題は防げない
- 検出手段は「ビルド＆テスト実行」であり、レビュー観点ではない

### ノンストップ実行について
- 全コミットを通じて「人間が介入して軌道修正した」パターンは確認できなかった
- 発見された問題はすべて knowledge.md に蓄積されており、再発防止の仕組みがある
- ビルド＆テスト実行が self-impl-review の前提条件として明示されていない点が気になる

### 未決定事項（他プロジェクトの資料と合わせて判断する）
- レビュー観点の追加は本当に不要か、他プロジェクトで別パターンの問題が出ていないか
- ノンストップ実行の条件として何を組み込むべきか
- ビルド＆テスト実行をどの段階に組み込むか（impl-review の前？後？）
