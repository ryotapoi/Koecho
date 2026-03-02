# Koecho 機能仕様書

## ユーザーフロー

### 基本フロー
1. グローバルホットキーでフローティングウィンドウを表示
2. フォアグラウンドアプリの選択テキストを取得・保存し、初期テキストとして表示（選択なしの場合は空）
3. ユーザーが音声またはキーボードでテキスト入力
4. 必要に応じてスクリプトを実行（テキストがその場で置き換わる。何度でも実行可能）
5. ホットキー再押下で確定 → クリップボードにセット → Cmd+V でペースト → クリップボード復元
6. Escape でキャンセル（貼り付けずにウィンドウを閉じる）

### ホットキーのトグル動作
- 1回目: ウィンドウを開く（フォアグラウンドアプリを記憶）
- 2回目: 確定して貼り付け、ウィンドウを閉じる
- Escape: キャンセル（何もせずウィンドウを閉じる）

---

## フローティングウィンドウ

### InputPanel（NSPanel サブクラス）
- level = .floating（常に最前面）
- canBecomeKey = true（テキスト入力受付のため）
- canBecomeMain = false
- hidesOnDeactivate = false
- collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
- タイトルバー非表示、移動可能
- 初期幅 300pt、自由にリサイズ可能。最小 200×150pt。位置・サイズは自動保存

### 注意: フォアグラウンドアプリの記憶
- パネル表示前に NSWorkspace.shared.frontmostApplication を記録
- ペースト前にそのアプリを activate(options:) で再アクティベート
- TextEditor で Dictation を受けるにはウィンドウがキーウィンドウである必要がある

### 操作
- ホットキー再押下: テキスト確定・貼り付け（auto-run スクリプト選択時はスクリプトが自動実行される）
- Escape: キャンセル・ウィンドウ非表示（auto-run 実行中も中断可能）
- スクリプト実行: ショートカットキーまたはボタンで選択
- メニューバーから auto-run スクリプトを選択・解除できる
- パネル内ショートカットで auto-run スクリプトをサイクル切り替えできる

---

## スクリプト連携

### 概要
- スクリプトは**複数登録**できる
- 各スクリプトは「名前」「コマンド」「ショートカットキー（修飾キーの組み合わせ + 文字キー、任意）」「追加入力の有無」を持つ
- 「コマンド」はシェルコマンド文字列（`/bin/sh -c` に渡される）。引数・パイプ・リダイレクト等をそのまま記述可能。スペースを含むパスはシングルクォートで囲む（例: `'/path/to/my script.sh' arg1`）
- 実行するとウィンドウ内のテキストが結果で**その場で置き換わる**
- 何度でも実行可能（別のスクリプトを通したり、手で直したりできる）

### 追加入力（プロンプト）
- スクリプト登録時に「追加入力あり」を設定できる
- 「追加入力あり」のスクリプトを選択すると、実行前に入力欄が表示される
- ユーザーが指示を入力（音声・キーボード）して実行
- 「追加入力なし」のスクリプトはすぐに実行される
- 追加入力の内容は環境変数 KOECHO_PROMPT でスクリプトに渡る

### 実行方法
- ショートカットキー（スクリプトごとに設定可能）。修飾キー（Ctrl / Cmd / Option / Shift の組み合わせ）と文字キーの組み合わせ。設定UIはキーレコーダー方式
- ウィンドウ内のボタン（スクリプト名が表示される）

### 実行方式
- /bin/sh -c で実行
- stdin: テキスト全文
- stdout: 加工済みテキスト
- stderr: エラー・ログ
- exit code: 0=成功, 非0=失敗

### 環境変数

| 変数名 | 説明 |
|--------|------|
| PATH | 親プロセスから継承 |
| HOME | 親プロセスから継承 |
| KOECHO_SELECTION | フォアグラウンドアプリの選択テキスト |
| KOECHO_SELECTION_START | 選択範囲の開始位置（未取得時は空） |
| KOECHO_SELECTION_END | 選択範囲の終了位置（未取得時は空） |
| KOECHO_PROMPT | スクリプト実行時の追加入力（未入力時は空） |

※ __CF_* 等の macOS 内部環境変数は渡さない（TCC 対策）

### 確定時自動実行（Auto-run on Confirm）
- `requiresPrompt = false` のスクリプトから1つだけ auto-run スクリプトとして選択できる
- 実行タイミング: 置換ルール適用・trim 後、ペースト前
- エラー時: trim 済みの置換適用後テキストにフォールバックし、パネルにエラー表示。パネルは閉じない
- キャンセル: Escape で中断可能（手動スクリプト実行中と同じ動作）
- 選択方法: パネル内のドロップダウンメニュー、メニューバーのサブメニュー、またはパネル内ショートカットでサイクル切り替え（nil → script[0] → script[1] → ... → nil）
- 選択状態は UserDefaults に永続化

### エラーハンドリング
- 非ゼロ終了: 元テキストをフォールバック（置き換えない）
- 空出力（whitespace trim 後に空）: 元テキストをフォールバック
- タイムアウト (30秒): SIGTERM → 5秒後 SIGKILL → 元テキストをフォールバック

### スクリプト例

最小（そのまま出力）:
  cat

フィラー除去:
  sed 's/えーと//g'

箇条書きに変換（LLM 連携の例）:
  # KOECHO_SELECTION に元のコンテキストがある

---

## メニューバー

- Info.plist: LSUIElement = true で Dock 非表示
- MenuBarExtra (.menu スタイル) で常駐

### メニュー項目
- スクリプト管理（追加・編集・削除）
- ホットキー設定
- 設定を開く
- 終了

---

## グローバルホットキー

- NSEvent.addGlobalMonitorForEvents + addLocalMonitorForEvents で modifier key 監視
- デフォルト: Fn (Globe) キー、シングルタップトグルモード
- DispatchQueue.main.async でメインスレッドに戻す
- Settings の Hotkey タブでカスタマイズ可能

### ホットキー設定

| 設定項目 | 選択肢 | デフォルト |
|---------|--------|-----------|
| Modifier Key | Command / Shift / Option / Control / Fn | Fn |
| Side | Left / Right（Fn 選択時は非表示、常に Left） | Left |
| Tap Mode | Single Toggle / Double Tap to Show | Single Toggle |

### タップモード

**Single Toggle（デフォルト）**
- 1回目のタップ: パネル表示
- 2回目のタップ: 確定して貼り付け
- ダブルタップ判定の遅延なし（即座に反応）

**Double Tap to Show**
- ダブルタップ: パネル表示（パネル非表示時）/ 確定（パネル表示時）
- シングルタップ + パネル表示中: 確定して貼り付け（遅延なし）
- シングルタップ + パネル非表示時: 何もしない（300ms のダブルタップ判定待ち後に破棄）
- ダブルタップ判定間隔: 300ms（固定）

### 左右の区別
- keyCode（Carbon kVK_* 定数）で左右を判別
- NSEvent.ModifierFlags は左右共通のフラグとして使用
- Fn / Globe キーは左右区別なし（同一 keyCode 63）

---

## 音声入力エンジン

### VoiceInputEngine プロトコル
音声入力の抽象化レイヤー。DictationEngine と SpeechAnalyzerEngine の2つの実装がある。

### DictationEngine（macOS 14+）
- macOS 標準の Dictation（`startDictation:` セレクタ）を使用
- NSTextView の marked text / insertText 経路でテキストを受け取る
- 0.3 秒遅延付き開始（パネル表示直後の不安定さ対策）
- `restart()` メソッドでフォーカス遷移後の再送信が可能（DictationEngine 固有）

### SpeechAnalyzerEngine（macOS 26+）
- Speech フレームワークの SpeechAnalyzer / DictationTranscriber を使用
- AVAudioEngine でマイク入力を取得し、オンデバイスで音声認識
- volatile（未確定）テキストをグレー + 薄い背景色で表示
- isFinal で確定テキストを挿入、volatile テキストを置換
- キーボードと音声の併用が可能（voiceInsertionPoint で挿入位置を追跡）
- マイク権限（NSMicrophoneUsageDescription）が必要
- 初回使用時にモデルの自動ダウンロードが発生する場合がある

### 設定
- Settings の Voice Input セクション（macOS 26+ のみ表示）でエンジンを選択
- `effectiveVoiceInputMode` で OS 可用性を考慮した実効モードを返す
- SpeechAnalyzer の locale は Settings で指定（デフォルト: ja-JP）
- パネル表示時にエンジンが生成される（設定変更は次回パネル表示時に反映）

---

## ペースト

- CGEvent で Cmd+V をシミュレーション
- AXIsProcessTrusted() でアクセシビリティ権限を確認
- ペースト前にクリップボード内容を保存、遅延後（デフォルト 2秒）に復元

---

## 将来の拡張候補

- **モード（プリセット）**: ユーザー定義のモードごとにスクリプトのリストを切り替える。例:「議事録モード」「翻訳モード」など。現時点では未実装
