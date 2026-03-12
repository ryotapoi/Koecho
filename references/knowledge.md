# Knowledge Base

このファイルはプロジェクト固有の技術的な知見・ハマりどころを蓄積する場所。

## このファイルの使い方

- **いつ読むか**: 新しい機能の実装前、バグ調査時に関連セクションを確認する
- **何を書くか**: 特定の状況で役立つ知見（罠、回避策、仕様の癖など）
- **CLAUDE.md との違い**: CLAUDE.md は毎回読み込まれる「常に守るルール」。ここは「該当する実装のときだけ必要な知見」
- **書き方**: セクション見出しでテーマ分け。各項目は簡潔に。症状・原因・対処がわかるように書く

---

## macOS / Process

- 子プロセス（Process）に `ProcessInfo.processInfo.environment` をそのまま渡さない。macOS の内部環境変数（`__CF_*` 等）経由で TCC 保護フォルダ（Photos, Music, iCloud）へのアクセスが発生し、許可ダイアログが出る
- `currentDirectoryURL` 未設定だと親の CWD を継承し、TCC 保護パスに当たりうる
- 対策: `PATH` と `HOME` のみ渡す + `currentDirectoryURL` を `FileManager.default.temporaryDirectory` に設定
- Process を使う箇所すべてに適用すること（ScriptRunner 等）
- 子プロセスのアクセスは親プロセス（Koecho）の権限として扱われる

## macOS / MenuBarExtra

- `LSUIElement = YES` と `setActivationPolicy(.accessory)` を両方指定すると MenuBarExtra のアイコンが表示されないことがある
- `LSUIElement = YES`（Info.plist）だけで Dock 非表示になるので、`setActivationPolicy(.accessory)` は不要
- `App.init()` 内での `NSApplication.shared` アクセスは SwiftUI のライフサイクル初期化と競合するリスクがある

## Swift / @Observable

- `@Observable` マクロはストアドプロパティのアクセスを変換する。通常の Swift では `init` 内の直接代入で `didSet` は呼ばれないが、`@Observable` がプロパティアクセスを書き換えるため、`init` 内でも `didSet` が発火する可能性がある
- Settings.swift の `scripts` プロパティは `init` 内代入 + `didSet { save() }` パターンでこの挙動に依存している。`persistsChanges` テストで検証済み
- `pasteDelay` / `scriptTimeout` は computed property + backing store パターンに移行済み（値クランプのため）。`init` では backing store に直接代入し `didSet` 問題を回避している
- Swift バージョンアップ時に `@Observable` マクロの挙動が変わると壊れうるので、テストが通ることを確認する

## macOS / VoiceInputTextView + NSViewRepresentable

- SwiftUI TextEditor の内部 NSTextView にアクセスする脆弱なハック（`findTextView(in:)`、isa-swizzling）を廃止し、VoiceInputTextView（NSTextView サブクラス）+ VoiceInputTextEditor（NSViewRepresentable）に置き換え済み（ADR 0010）
- テキスト同期はコールバック方式。`didChangeText()` → `onTextChanged` で外向き同期、`updateNSView` で内向き同期。SwiftUI Binding は使わない
- `didChangeText()` は `insertText` から内部的に呼ばれるので、`onTextChanged` は `didChangeText` のみで発火させる。`insertText` では `onTextCommitted`（Dictation 確定シグナル）のみ発火
- フィードバックループ防止: `VoiceInputTextView.isSuppressingCallbacks` フラグ。コントローラから `textView.string` を直接変更する箇所（clearTextView, stopDictation, applyReplacementRulesNow）すべてで true/false をセットする
- `updateNSView` でも `isSuppressingCallbacks` をチェックし、`hasMarkedText()` ガードと合わせて Dictation 中の上書きを防止
- 初回表示では `makeNSView` → `onViewCreated` で textView 参照を取得するが、`makeKeyAndOrderFront` 直後はまだ SwiftUI レイアウトが完了しておらず textView が nil の場合がある。nil なら `DispatchQueue.main.async` で 1 サイクル遅延
- `@FocusState` は prompt TextField のみに使用。TextEditor 側のフォーカスは `panel.makeFirstResponder(textView)` で直接管理

## SwiftUI / .frame の .infinity 型推論

- `.frame(maxHeight: .infinity)` はコンパイルエラー「Cannot infer contextual base in reference to member 'infinity'」になる場合がある
- `maxHeight` パラメータの型が `CGFloat` で、`.infinity` が `Double.infinity` に解決されて型不一致になるケース
- 対策: `CGFloat.infinity` と明示する
- `.frame(maxWidth: .infinity)` は `maxWidth` の型が `CGFloat?` のため暗黙変換で通る

## macOS / NSPanel + Escape キー

- NSPanel 内に TextEditor（NSTextView）があると、Escape キーは NSTextView が消費するため `keyDown(with:)` がパネルまで届かない
- 対策: `keyDown(with:)` ではなく `cancelOperation(_:)` を override する。NSTextView は Escape を受けると `cancelOperation(_:)` をレスポンダーチェーンに送る

## SwiftUI / Scene + .onAppear

- `.onAppear` は View モディファイアであり、Scene（`MenuBarExtra` 等）には使えない（コンパイルエラー: `has no member 'onAppear'`）
- `.menu` スタイルの MenuBarExtra ではメニューを開くまで content の View が表示されないため、content 内ビューの `.onAppear` も初回起動時には発火しない
- 対策: `.onChange(of:initial:true)` を Scene に付けて初回評価時にコードを実行する。`initial: true` により最初の body 評価で実行される

## Shell / echo -n

- macOS の `/bin/sh`（BSD sh）では `echo -n ''` が `-n` をリテラル文字列として出力する。`-n` フラグは bash 拡張であり POSIX 非標準
- 改行なし出力が必要な場合は `printf ''` を使う
- テストで空出力を作りたい場合も `printf ''` が安全

## macOS / Dictation (startDictation:)

- `startDictation:` セレクタを `NSApp.sendAction` で送ると responder chain 的には成功する（`true` を返す）が、パネル表示直後だと Dictation が実際には開始されない（サイレント失敗）
- 原因: ウィンドウの表示・first responder 設定が完了した直後はまだ Dictation の受付準備ができていない模様
- 対策: `makeFirstResponder` 完了後に `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` で遅延させてから送る。`makeFirstResponder` → 0.3秒 → `startDictation:` の順序が重要。`becomeKey()` トリガーなど `makeFirstResponder` と独立したタイミングで送ると失敗率が上がる
- `startDictation:` はトグル動作。Dictation がアクティブ中に再送信すると停止してしまうため、リトライは行わない
- `NSApp.sendAction` が失敗した場合は `textView.perform(startDictation:)` にフォールバック（`.nonactivatingPanel` で responder chain が届かないケース対策）

## Foundation / NSRegularExpression テンプレート構文

- `NSRegularExpression.stringByReplacingMatches(in:range:withTemplate:)` の `withTemplate` パラメータは `$0`, `$1` 等をキャプチャグループ参照として解釈する
- 置換文字列にリテラルの `$` を含めたい場合は `NSRegularExpression.escapedTemplate(for:)` でエスケープが必要
- `escapedPattern(for:)` は検索パターン用、`escapedTemplate(for:)` は置換テンプレート用。両方忘れずに使い分ける

## テスト / TEST_HOST アプリのライフサイクル隔離

- `TEST_HOST = Koecho.app` のため、テスト実行時にアプリ本体が起動する。`@main` の `App.init()` → `body` → `onChange(initial: true)` が走り、ホットキー登録・アクセシビリティダイアログ・パネル表示等の副作用が発生する
- `main.swift` 方式（`@main` を外して `NSApplication.shared.run()` / `RunLoop.main.run()` でテスト時に分岐）は、テストランナーと干渉して xcodebuild CLI・Xcode GUI 両方で問題が発生した。`app.run()` がメインスレッドをブロックし、テストバンドルのロード/実行がトリガーされない
- 対策: `@main` を維持し、`KoechoApp` 内で `NSClassFromString("XCTestCase") != nil` を `static let` で検出。`init()` と各 `onChange` ハンドラでガードして副作用をスキップ
- テストで `showPanel()` するたびに本物の `DictationEngine` が生成されマイクが起動する問題も発生。`InputPanelController.init` に `makeEngine` パラメータ（Optional、デフォルト nil）を追加し、テストから `MockVoiceInputEngine` を注入して回避

## テスト / UserDefaults 分離

- `UserDefaults.standard` を使うテストは前回のテスト実行データが残留し、次回のテストに干渉する
- 対策: テストでは `UserDefaults(suiteName: "test-\(UUID().uuidString)")!` で毎回新しいインスタンスを作る
- `AppState()` のデフォルト init は `Settings(defaults: .standard)` を使うため、テストでは `AppState(settings: Settings(defaults: isolatedDefaults))` のように明示的に渡す

## macOS / Dictation + SwiftUI TextEditor のテキスト変更検知

- macOS Dictation は「marked text（未確定テキスト）」を NSTextInputClient の内部バッファに保持し、確定（unmark）するまで `NSTextView.string` や `textStorage` を更新しない
- そのため Dictation 入力中は以下の方法では変更を検知できない:
  - SwiftUI `.onChange(of: appState.inputText)` → バインディングが同期されない
  - `NSText.didChangeNotification` → 発火しない
  - `NSTextStorage.didProcessEditingNotification` → 発火しない
  - ポーリングで `NSTextView.string` を読む → 未確定テキストが反映されていないので変化なし
- 変更が検知される条件: フォーカスを外す、音声入力を停止する、キーボード入力する、カーソル移動する（いずれも marked text が確定されるタイミング）
- 対策（現行）: VoiceInputTextView の didChangeText() をトリガーに、`hasMarkedText()` が false のとき即座に置換ルールを適用。`hasMarkedText()` が true のときはアンダーラインプレビュー + ホバーツールチップを表示。Ctrl+R / Replace ボタンによる手動トリガーも併用可能（ADR 0011）

## macOS / Dictation + フォーカス遷移

- SwiftUI の `@FocusState` でフォーカスを TextEditor から TextField に移動すると、macOS が Dictation セッションを停止する
- 例: Prompt ありスクリプト起動時に `focusedField = .prompt` をセットすると、TextEditor で実行中の Dictation が終了する
- 対策: フォーカス遷移後に `startDictation()` を再送信する。`DispatchQueue.main.asyncAfter(deadline: .now() + 0.3)` で遅延が必要（「macOS / Dictation (startDictation:)」セクション参照）
- `InputPanelContent.onPromptFocused` コールバックで `InputPanelController` に通知し、controller 側で Dictation を再起動する構成

## SwiftUI / contextMenu preview on macOS

- `contextMenu { } preview: { }` API は macOS ではプレビューを表示しない（iOS のみ）。右クリックすると通常のコンテキストメニューが表示されるだけで、preview クロージャは無視される
- 対策: 全文表示などのプレビューが必要な場合は、contextMenu のボタンで `@State` を更新し `.popover(isPresented:)` で表示する

## SwiftUI / TextField onChange + 即時パージの罠

- TextField（`.number` フォーマット）の `onChange` で即座にデータ削除（purge 等）を実行すると、入力途中の中間値で発火して意図しない削除が起きる
- 例: maxCount が 500 のとき、ユーザーが "2" に書き換えようとすると中間値 "5002" や空文字で onChange が発火し、purge が不正な値で実行される
- 対策: onChange でのリアルタイム purge を避け、データ追加時（add）や起動時に purge を実行する

## macOS / NSTextView context menu

- VoiceInputTextView サブクラスで `menu(for:)` を override し、標準メニュー + カスタムアイテム（「Add Replacement Rule…」）を追加
- 選択テキストがない場合はカスタムアイテムを追加しない（`selectedRange().length > 0` でガード）
- テスト時に `super.menu(for:)` を呼ぶとプロセスクラッシュが発生する場合がある。メニューアクションのテストはセレクタの直接呼び出し（`perform(Selector(("addReplacementRuleFromMenu:")))`) で行う

## macOS / NSLayoutManager overlay positioning

- `NSLayoutManager.boundingRect(forGlyphRange:in:)` returns the bounding rect for a glyph range in text container coordinates. Add `textContainerOrigin` to convert to NSTextView coordinates
- `layoutManager.glyphRange(forCharacterRange:actualCharacterRange:)` converts character ranges (NSRange) to glyph ranges needed by `boundingRect`
- VoiceInputTextView uses TextKit 1 by default (NSTextView does not opt into TextKit 2 unless explicitly configured), so `layoutManager` is always non-nil
- **Adding NSView subviews to NSTextView during Dictation corrupts the marked text state and causes duplicate text on the first Dictation phrase.** Use `draw(_:)` override for visual decorations (underlines) and a separate floating NSWindow for tooltips instead
- For multi-line text, use `enumerateLineFragments(forGlyphRange:)` to draw per visual line. `boundingRect` alone returns a single rect spanning the full width across line breaks
- Tooltip NSWindow should be positioned above the text to avoid overlapping the Dictation microphone icon that appears below the cursor

## macOS / Hardened Runtime + マイク権限

- Hardened Runtime 有効時、マイクアクセスには `com.apple.security.device.audio-input` entitlement が必要
- `NSMicrophoneUsageDescription`（Info.plist / ビルド設定）だけでは不十分。entitlements ファイルに entitlement を追加しないとマイクアクセスがブロックされ、権限ダイアログも表示されない
- macOS の Settings > Privacy & Security > Microphone には手動追加 UI がない。アプリが初めてマイクにアクセスしたときにシステムダイアログが自動表示される

## macOS 26 / SpeechAnalyzer

- SpeechAnalyzer API は `Speech` フレームワーク内にある（独立フレームワークではない）。`import Speech` で使用可能
- `DictationTranscriber` は句読点自動付与機能を持つ。`Preset` で `reportingOptions: [.volatileResults]` を指定すると volatile results が取得できる
- `DictationTranscriber.Result` は `isFinal: Bool` と `text: AttributedString` を持つ。テキスト取得は `String(result.text.characters)`
- `AnalyzerInput(buffer: AVAudioPCMBuffer)` でオーディオバッファを入力
- `AVAudioEngine.inputNode` のタップコールバックは audio thread で実行される。`@MainActor` のプロパティに直接アクセスしてはいけない。`AsyncStream.Continuation` をローカル変数にキャプチャして `yield` する
- 音声フォーマット変換: `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:considering:)` で最適フォーマット取得。入力フォーマットと異なる場合は `AVAudioConverter` で変換
- モデルダウンロード: `AssetInventory.assetInstallationRequest(supporting:)` で確認。`nil` 返却 = インストール済み。非 nil なら `downloadAndInstall()` で DL。`assetInstallationRequest` は自動で `reserve()` を呼ぶため、明示的な reserve は不要
- モデルリリース: `AssetInventory.release(reservedLocale:)` → `async -> Bool`（throws ではない）。`false` = 元々 reserved でなかった。`release()` は reservation を解除するだけで、モデルファイルは即座には削除されない。`release()` 後も `DictationTranscriber.installedLocales` にロケールが残り続けるが、`AssetInventory.status(forModules:)` は `.supported`（= 再 DL 必要）を返す。つまり `installedLocales` は「ディスク上にファイルがある」を示すだけで、モデルの利用可能状態は `status` が正しい。OS 再起動やディスク逼迫でファイルが削除される可能性がある
- `AssetInventory.status(forModules:)` → `async -> AssetInventory.Status`。ロケールごとにモデルの状態を返す。`.installed` = 利用可能、`.supported` = DL 必要、`.downloading` = DL 中、`.unsupported` = 非対応
- `AssetInventory.reservedLocales` で予約済みロケール一覧を取得可能。identifier 形式が `supportedLocales` と異なる場合があるため、正規化キーで比較する
- Swift Testing の `@available(macOS 26, *)` と `@Test` マクロは互換性がない。`@available` をスイートに付けると `@Test` がコンパイルエラーになる。対策: ランタイムで `guard #available(macOS 26, *) else { return }` を使う
- `import Speech` すると `Speech.Settings` がプロジェクトの `Settings` 型と名前衝突する。対策: `Koecho.Settings` とモジュール名で修飾する
- `DictationTranscriber.supportedLocales` / `installedLocales` は static async プロパティ（throws ではない）。Locale の identifier 形式（`-` vs `_`）が不明なため、比較には `language.languageCode` + `language.script` + `language.region` で正規化する

## macOS / VoiceInputTextView volatile テキスト

- volatile テキストは `textStorage` に直接挿入し、`NSLayoutManager.addTemporaryAttribute` でスタイリング（グレー前景色 + 薄い背景色）
- volatile 操作（setVolatileText / clearVolatileText / finalizeVolatileText）では必ず `isSuppressingCallbacks = true` で囲む。そうしないと `didChangeText()` → `onTextChanged` が発火し、volatile テキストが `appState.inputText` に混入する
- `shouldChangeText(in:replacementString:)` をオーバーライドし、キーボード入力前に volatile をクリア。NSRange のずれを防止
- `VoiceInputTextEditor.updateNSView` の同期ガードに `volatileRange == nil` を追加。volatile 存在中は SwiftUI からの同期で volatile を消さない

## NSView / wantsUpdateLayer と draw(_:) の共存

- `wantsUpdateLayer = true` にすると、macOS は `draw(_:)` を呼ばず `updateLayer()` のみ呼ぶ
- `draw(_:)` でテキスト描画をしている NSView では `wantsUpdateLayer` を使えない
- ダイナミックカラーの `.cgColor` 変換はアピアランス変更時に再取得が必要（呼び出し時の値で固定されるため）
- `viewDidChangeEffectiveAppearance()` で CGColor を再設定するのが安全なパターン

## SpeechAnalyzer / Transcriber 再生成による重複防止

- `DictationTranscriber` + `frequentFinalization` では、キーボード入力（改行等）後の次の `didFinalize` に前セグメントのテキストが含まれる既知バグがある
- 対策（Primary）: キーボード入力検知時に `DictationTranscriber` + `SpeechAnalyzer` + `AsyncStream` を再生成する。オーディオエンジン（AVAudioEngine）は維持し、tap を再インストールする
- 対策（Secondary）: `accumulatedFinalizedText` で finalized テキストを蓄積し、`stripOverlappingPrefix` で重複除去
- restart 時はオーディオ tap を再インストールする。tap クロージャが `localContinuation` をローカルキャプチャする既存パターン（ADR 0012）を維持
- `isRestarting` フラグで多重実行防止。`transcriberAlreadyRestarted` フラグで「voice input 到着までの冗長 restart 防止」
- restart 後にバッファ残存音声のリプレイが発生する。volatile は時間窓（restart 完了後 2 秒、`replaySuppressionDeadline`）+ `localFinalizedText` との prefix マッチングで抑制し、新規音声は時間窓内でも表示する。finalize は `localFinalizedText` との exact match で replay を判定（`replaySuppressionDeadline` がセットされている replay context でのみ）。replay finalize 到着時に `clearReplayState()` で全フラグクリア。万一スキップ漏れがあっても `stripOverlappingPrefix` がフォールバックとして機能する
- restart 時はモデルダウンロード済みを前提。同一セッション中にモデルがアンロードされることは想定しない
- ADR 0016 に詳細

## SpeechAnalyzer 既知の問題（未確定・要調査）

- 音声入力の先頭に「。」が挿入されることがある（再現条件不明）
- volatile テキスト（未確定表示）がある状態でスクリプトを実行すると、volatile 部分がスクリプトに渡されない可能性がある

## CoreAudio / オーディオデバイス管理

- `AudioDeviceID` は transient（セッション内でのみ有効）。永続化にはデバイス UID（String）を使う。`kAudioDevicePropertyDeviceUID` で取得
- UID → AudioDeviceID: `kAudioHardwarePropertyDeviceForUID` + `AudioValueTranslation`。`withUnsafeMutablePointer` で CFString と AudioDeviceID のポインタを渡す
- AVAudioEngine は非デフォルト入力デバイスを正式にサポートしない。`inputNode` は遅延初期化されたシングルトンで、アクセス後に `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` を設定しても内部ルーティングが更新されず、tap コールバックが呼ばれない。SpeechAnalyzerEngine は AVAudioEngine を使い続けるが非デフォルトデバイス対応は未解決
- 非デフォルトデバイスからの入力取得には AUHAL (kAudioUnitSubType_HALOutput) を直接使う。手順: Enable IO (element 1 input) → Disable IO (element 0 output) → Set device → Set output format (element 1 output scope) → Allocate AudioBufferList → Set input callback → AudioUnitInitialize → AudioOutputUnitStart。コールバック内で `AudioUnitRender` を呼んでバッファにデータを引き込む
- デバイス変更監視: `AudioObjectAddPropertyListenerBlock` on `kAudioHardwarePropertyDevices`。リスナーは `deinit` で `AudioObjectRemovePropertyListenerBlock` で解除。ブロックは必ず `[weak self]` でキャプチャ
- デフォルト入力デバイス: `kAudioHardwarePropertyDefaultInputDevice` で取得。変更監視も同プロパティで。`deviceUID == nil` で monitoring 中にデフォルトデバイスが変わった場合は `startMonitoring(deviceUID: nil)` を再呼び出し（engine 再起動 + 音量リスナー付け替え）
- 入力音量: `kAudioDevicePropertyVolumeScalar`（scope: input）。element: main が非対応なら element: 1 にフォールバック。Slider 連動時はフィードバックループ防止フラグ（`isUpdatingVolume`）が必要
- レベル計測: CoreAudio にはリアルタイム入力レベル取得 API がない。AUHAL の input callback 内で `AudioUnitRender` → RMS 計算で取得。コールバックは audio I/O スレッドで実行されるため、メモリ確保・ロック取得・ObjC メッセージ送信は禁止
- 設定画面のレベルメーター用 AUHAL と SpeechAnalyzerEngine の AVAudioEngine は同時に動くとクラッシュする（同一デバイスの inputNode に tap は 1 つ）。`AudioDeviceManager.isAudioInputInUse` static フラグ + `activeMonitoringInstance` weak 参照で双方向の排他制御
- `@MainActor` クラスの `deinit` は nonisolated。CoreAudio のリスナー除去は `deinit` 内で直接 C API を呼ぶ（インスタンスメソッドは呼べない）
- 入力デバイス判定: `kAudioDevicePropertyStreamConfiguration`（scope: input）でチャンネル数 > 0 をフィルタ
- `AudioBufferList` の解析: `rawPointer.advanced(by: MemoryLayout<UInt32>.size)` で `AudioBuffer` 配列にアクセスするとアラインメントパディングでずれる。`UnsafeMutableAudioBufferListPointer` を使うのが正しい方法

## Swift / @MainActor + デフォルト引数

- `@MainActor` クラスの `init` にデフォルト引数で別の `@MainActor` 型のインスタンス生成を書くと、デフォルト引数式は caller の actor isolation を継承しないためコンパイルエラーになる
- 対策: designated init（引数必須）+ convenience init（デフォルト値生成）に分離する。`convenience init` は `@MainActor` クラスの isolation を持つため、中で `@MainActor` 型を生成できる

## SPM モジュール分離（ADR 0018）

- SwiftUI の `Settings` 型と KoechoCore の `Settings` クラスが名前衝突する。`import SwiftUI` + `import KoechoCore` している App target のファイルでは `KoechoCore.Settings` と明示が必要
- `Array.move(fromOffsets:toOffset:)` は SwiftUI が提供する extension。SPM ターゲットで `import Observation` のみの場合は使えない。名前衝突を避けるため `moveElements(fromOffsets:toOffset:)` として自前実装
- `@Observable` は `import Observation` で使えるが、`import SwiftUI` 経由で暗黙に使っていたファイルは明示的に `import Observation` が必要
- Carbon の `kVK_Function` 等の定数を KoechoCore で使う場合はリテラル値（`63`）に置き換える。`import Carbon.HIToolbox` は macOS 依存
- ShortcutKey の `Modifier.flag`（NSEvent.ModifierFlags）や HotkeyConfig の `keyCode`（Carbon 依存）は platform extension として KoechoPlatform に配置。model 本体は KoechoCore に残す
- SPM テストファイルで `JSONEncoder`/`JSONDecoder` を使う場合は `import Foundation` が必要（`import Testing` だけでは不足）

## InputPanelController サービス分割（ADR 0017）

- VoiceInputCoordinator は `init` で `makeEngine()` を呼んだ後、必ず `engine.delegate = self` を設定すること。`regenerateEngine()` 経由なら自動で設定されるが、`init` では手動設定が必要
- `textView` は coordinator + 3 サービスに配布される。`onTextViewCreated` callback 内で全サービスに設定し、voiceCoordinator には `configureEngineWithTextView()` も追加で呼ぶ
- `clearTextView()` の `DispatchQueue.main.async` フォールバック: `makeKeyAndOrderFront` 直後は SwiftUI レイアウト未完了で textView.window が nil の場合がある。1 サイクル遅延で回避
