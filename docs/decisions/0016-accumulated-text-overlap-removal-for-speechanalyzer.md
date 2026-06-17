# ADR 0016: Accumulated text overlap removal for SpeechAnalyzer

## Status

Accepted

## Context

SpeechAnalyzer の `DictationTranscriber`（`frequentFinalization` オプション付き）は連続音声ストリームを処理する。キーボード入力（改行等）が音声セグメント間に入ると、次の `didFinalize` の結果に前のセグメントのテキスト（全体または末尾の句読点）が含まれることがある。

既存の防御機構は 2 つ：
- `isLocallyFinalized` — volatile テキストが既にクリアされている場合には効かない
- `stripLeadingDuplicatePunctuation` — textStorage ベースで 1 文字の句読点重複のみ対応

これらでは「前セグメント全文 + 新テキスト」形式の重複を防げない。

## Considered Options

- **A: textStorage ベースの拡張** — `stripLeadingDuplicatePunctuation` を拡張し、textStorage の内容と新テキストのプレフィックスを比較する。textStorage はユーザーのキーボード編集を反映するため正確だが、ユーザー編集と音声重複の区別が困難
- **B: 蓄積テキスト（accumulatedFinalizedText）ベースの重複除去** — SpeechAnalyzer から受け取った finalized テキストを別途蓄積し、その末尾と新テキストの先頭の一致を検出・除去する。音声入力で確定したテキストのみを追跡するため、ユーザーのキーボード編集と混同しない
- **C: SpeechAnalyzer 側でセグメント管理** — エンジン層で前セグメントを記憶し重複を除去してからデリゲートに渡す。責務の分離としては美しいが、SpeechAnalyzer の挙動は Apple の内部実装に依存しており、エンジン層での汎用的な処理は過剰

## Decision

2 層防御を採用する:

1. **Primary: Transcriber 再生成** — ユーザー操作による割り込み時（キーボード入力、カーソル移動）に `DictationTranscriber` + `SpeechAnalyzer` + `AsyncStream` を再生成（オーディオエンジンは維持）。セグメントバッファがクリアされ、次の `didFinalize` が新しいバッファから開始される。Apple 内部実装への依存だが、実験で 70-100% → ほぼ 0% に改善を確認
2. **Secondary: 蓄積テキスト + 重複除去** — option B の `accumulatedFinalizedText` で finalized テキストを蓄積し、`stripOverlappingPrefix` で重複プレフィックスを除去する。Primary が効かなくなった場合でも引き続き防御として機能する

誤削除を防ぐため、1 文字一致は句読点のみ除去する。2 文字以上の一致は常に除去する。これは「おはよう」+「うん」→「ん」のような偶然の 1 文字一致による誤削除を防ぎつつ、「？」のような句読点重複は確実に除去するためのルール。

蓄積テキストと transcriber restart フラグは showPanel / switchEngine / clearState でリセットする。

## Consequences

- 正: ユーザー操作（キーボード入力・カーソル移動）割り込み後の音声テキスト重複が解消される
- 正: 既存の `stripLeadingDuplicatePunctuation` と `isLocallyFinalized` はそのまま残り、defense-in-depth として機能する
- 正: Primary が効かなくなった場合でも Secondary が引き続き防御として機能する
- 正: 重複がない場合は `stripOverlappingPrefix` が素通しするため、通常の音声入力に影響しない
- 負: `accumulatedFinalizedText` は置換ルール適用後のテキスト変換を反映しない（意図的なトレードオフ。音声入力の生テキストのみを追跡することで、置換ルールによる変換と音声重複を区別する）
- 負: `accumulatedFinalizedText` はユーザーのキーボード編集（削除・挿入）を反映しないため、理論上、蓄積の末尾と次の finalize テキストの先頭が偶然一致して正常テキストが削除されるリスクがある（ただし 1 文字非句読点を除外しているため、実質的には同一テキストの連続口述に限定）
- 負: `accumulatedFinalizedText` はセッション中無制限に成長する（ただしループ回数は `newText.length` に制約されるため実用上の問題にはならない）
- 負: Transcriber 再生成は Apple 内部実装に依存。将来の OS アップデートで挙動が変わる可能性がある
- 中立: `.prompt` ターゲット中の finalize は蓄積に含まれないため、prompt → textEditor 切り替え後の初回 finalize でオーバーラップ検出が不完全になりうる
