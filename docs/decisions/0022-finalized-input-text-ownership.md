# ADR 0022: 確定入力テキストの所有権と書き込み経路

## Status

Accepted

## Context

音声入力欄には、確定テキストを保持する `AppState.inputText` と、marked text・volatile text を含む `VoiceInputTextView` の表示文字列がある。従来は `VoiceInputCoordinator` が `TextViewOperating` 越しに `textStorage` と `isSuppressingCallbacks` を直接操作し、App target の複数の型が `AppState.inputText` へ直接代入していた。

この構造では、プログラム由来の storage 編集を callback suppression で囲む責務と、確定状態を AppState へ反映する責務が分散する。どちらかを忘れると、volatile text の重複や AppState と表示文字列の不一致を起こし得る。

## Considered Options

- **A: AppState を確定テキストの正本とし、VoiceInputTextView を表示・編集バッファとする**: AppState の setter を閉じて単一 mutation API を公開し、storage 編集と callback suppression は VoiceInputTextView の操作へ閉じる
- **B: VoiceInputTextView の文字列だけを正本とする**: AppState から入力テキストを除去し、必要な箇所が View を参照する
- **C: 2 つの状態と複数の直接操作を維持する**: callback suppression と同期順序をコメントとテストで管理する
- **D: 専用の input text store を追加する**: AppState と VoiceInputTextView の間に新しい状態所有型を置く

## Decision

確定テキストの正本は `AppState.inputText` とする。`inputText` は `private(set)` とし、書き込みは `setInputText(_:)` だけを通す。`VoiceInputTextView` は AppKit が要求する marked text と、SpeechAnalyzer の volatile text を含む表示・編集バッファとして扱う。

`VoiceInputTextView` は、確定挿入、volatile 挿入、隣接する句読点の重複除去、typing attributes、callback suppression を所有する。`TextViewOperating` は storage と suppression state を公開しない。View で確定した内容は callback または明示的な同期点から AppState の mutation API へ反映する。

B は、View がまだ生成されていない panel lifecycle、panel 非表示時、script 実行中にも確定テキストを保持する必要があるため採用しない。C は suppression や同期の漏れを型で防げない。D は AppState がすでにアプリ状態の所有者であり、現在存在する状態を別型へ移しても追加の意味境界が生まれないため採用しない。

## Consequences

- `VoiceInputCoordinator`、`VoiceInputTextEditor`、controller/service は `textStorage` と suppression state を操作できない
- 確定挿入と volatile 挿入は同じ View 内部の UTF-16 座標・句読点処理・suppression 規則に従う
- AppState の確定テキスト更新は単一 API に集約され、直接 setter の追加はコンパイル時に失敗する
- AppState と VoiceInputTextView は役割の異なる 2 状態として残るため、View をプログラム更新する箇所では AppState 更新との同期が引き続き必要になる
