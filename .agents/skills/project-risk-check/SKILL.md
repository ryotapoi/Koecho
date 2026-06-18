---
name: project-risk-check
description: Koecho 固有の plan / 実装チェック。ディクテーション制御・テキストライフサイクル（volatile テキスト / isSuppressingCallbacks）、NSTextView / textStorage 操作、UserDefaults 永続化、権限（Accessibility / Input Monitoring）、ホットキー・ペースト・選択テキスト取得、外部スクリプト実行、モジュール依存方向に触れる変更で使う。汎用レビューではなく Koecho 固有の実害に絞って確認する。
---

# Project Risk Check

## Intent

Koecho 固有の mission・アーキテクチャ制約・既知の落とし穴に照らして、計画または実装のリスクを確認する。

## Constraints

- 汎用レビューではなく、Koecho 固有の実害に絞る。一般的なコード品質は `/code-review`、構造劣化は `thermo-nuclear-code-quality-review` 側で見る。
- 仕様・UX 判断が必要なら、実装判断として決めずユーザー確認に回す。
- 具体的な過去知見は `llm-wiki/` を参照し、skill 本体には増やしすぎない。
- plan / 実装どちらのレビューでも使える。対象は plan ファイル、または未コミット差分 / commit range。
- Checkpoints と対象を照合する際、必要に応じて `docs/rules/` と関連 ADR（`docs/decisions/`）を Read で読む。

## Acceptance

- `LGTM` またはリスク一覧がある。
- リスクには影響、根拠、推奨対応がある。
- 必要な場合、更新すべき `docs/rules/`, `backlog/backlog.md`, `docs/decisions/`, `llm-wiki/` が明確。

## Relevant

- ユーザー依頼、plan、または変更差分（未コミット / commit range）
- `docs/rules/mission.md`
- `docs/rules/scope.md`
- `docs/rules/architecture.md`
- `docs/rules/constraints.md`
- `docs/rules/principles.md`
- `docs/decisions/`
- `llm-wiki/`

## Checkpoints

### Mission / Scope

- 軽量・即応の音声入力という mission と矛盾しないか（`docs/rules/mission.md`）。
- 非目標（`docs/rules/scope.md` 外の機能）を混ぜていないか。

### Architecture / 依存方向

- `Koecho → KoechoPlatform → KoechoCore` の一方向依存を守っているか。逆方向の import がないか。
- KoechoCore に macOS 固有 API（AppKit, Carbon, CoreAudio 等）を import していないか。
- NSTextView 依存のコード（DictationEngine 等）が App target の外に漏れていないか。

### テキストライフサイクル（繰り返し発見されたもの）

- **プログラム由来のテキスト変更では `isSuppressingCallbacks` で囲む**: textStorage 直接編集や setString() でも didChangeText → onTextChanged/onTextCommitted が発火する。意図しない状態変更を防ぐため isSuppressingCallbacks ガードが必要。
- **volatile テキストと他機能の整合性**: volatile テキストが textView.string に実挿入される設計のため、スクリプト実行・置換ルールプレビュー・UI 表示で NSRange 座標不整合が起きやすい。volatile 中の操作は finalizedString ベースか textView.string ベースかを明確にすること。
- **Off モードでのエンジン init は設計判断として許容**: Off モードでエンジンが init されることは意図的な設計判断であり、過剰指摘しないこと。

### 永続化

- **UserDefaults の nil 永続化パターンを既存方式に統一する**: `removeObject` 方式と `Data()` センチネル方式が混在すると事故りやすい。同種データは既存パターン（`Data()` センチネル）に合わせること。

### 権限・システム連携

- Accessibility / Input Monitoring 権限がない場合のフォールバックがあるか（クラッシュや無反応にならないか）。
- CGEvent ペースト後のクリップボード復元、選択テキスト取得失敗時のハンドリングを壊していないか。
- 外部スクリプト実行（Process + Pipe）のタイムアウト / 空出力 / 非ゼロ終了のフォールバックを壊していないか。

上記に該当しないが Koecho 固有の設計判断に関わる問題も自由に指摘してよい。

## Output

- 日本語。指摘には 🔴 MUST / 🟡 SHOULD / 🔵 NIT を付け、該当箇所を引用する。
- Koecho 固有の問題がなければ「Koecho 固有の指摘なし（LGTM）」。
