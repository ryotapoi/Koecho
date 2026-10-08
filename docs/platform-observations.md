# プラットフォーム調査時に参照する観測

現在のコードから復元できず、同じ切り分けを繰り返さないために残す既存の観測記録。環境が記録されていない項目はOS・Xcodeの版と再現条件が不明であり、現在のSDKでも成立する制約とは断定しない。

## SwiftUI / AppKit の再調査

次の症状を調べるときに、当時の回避策を候補として使う。今回の文書移行で再実測したものではない。

| 当時の症状・注意点 | 切り分け・回避策 | 適用範囲 |
| --- | --- | --- |
| SwiftUI の `Scene` に `onAppear` を適用できないケースがあった | ウィンドウの初期同期を `View` 側の lifecycle または明示 callback へ置く | OS/SDK/具体的なScene型は旧記録にない |
| macOS の `contextMenu` preview が不要な空白を作ることがあった | `NSViewRepresentable` で preview を持たない menu を組む案 | 現在の HistoryView は SwiftUI contextMenu を使う。この観測を理由に一律置換しない。発生環境は不明 |
| `@MainActor` initializer の default argument が actor isolation と衝突することがあった | default 値の生成を呼び出し側または適切な factory に分ける | compiler版と元の宣言は旧記録にない |
| `import Speech` により `Speech.Settings` とアプリの設定モデルの名前が曖昧になりうる | `KoechoCore.Settings` など module 修飾を使う | SwiftUI の Settings scene とも型名が重なるため、曖昧な参照で確認する |
| macOS 26 時代に Swift Testing の `@available(macOS 26, *)` と `@Test` macro の相性問題があった | 当時はテスト内の runtime guard を使った | macOS 27 を下限とする現テストには旧availability対処は不要。具体compiler版は不明 |

MenuBarExtraの状態所有、Settings前面化の待機、IME編集中の空行削除、`draw(_:)` と `wantsUpdateLayer` の関係は、それぞれの実装の理由コメントに残している。

## macOS 26 での Speech / Audio 観測

- `AssetInventory.assetInstallationRequest(supporting:)` は内部で reservation を作ったため、別途 `reserve()` を呼ぶ必要はなかった。モデルが利用可能なら request は `nil` だった。モデルの状態を調べるときは、`installedLocales` の列挙だけで判断せず、status / installation request の結果を確認する。
- `release(reservedLocale:)` は予約解除であり、即時のファイル削除ではなかった。解除後も `DictationTranscriber.installedLocales` に残ることがあり、予約・利用可能性とディスク上の存在を同一視できなかった。再起動やディスク逼迫でモデルファイルが削除される場合もあった。現在の cache / release 実装にもこの理由をコメントしている。
- `AVAudioEngine.inputNode` へアクセスした後で `kAudioOutputUnitProperty_CurrentDevice` を設定すると、非既定デバイスの tap callback が呼ばれないケースを観測した。当時は内部routingが更新されないと解釈し、レベルメーターで AUHAL を採用した。現在の音声認識には `withAudioUnit` を使う選択device経路があり、非既定deviceでは常に AVAudioEngine が使えないという一般的制約にはしない。判断は [ADR 0031](../decisions/0031-audio-input-and-metering.md) に置く。
- 当時のAUHALの手順は、Enable IO（element 1 input）→ Disable IO（element 0 output）→ device設定 → output format設定（element 1 output scope）→ AudioBufferList確保 → input callback設定 → initialize → start。変更時は現行 `AudioInputLevelMonitor` と対象SDKを照合する。

この節の観測日は旧記録にない。macOS 27の再検証結果ではなく、過去の切り分けの入口である。APIの現在の型・シグネチャ・列挙値はSDKとコードで確認する。

## 語彙・発音モデルの調査

macOS 27での同一音声・同一モデルを使った比較は [カスタム語彙・発音の実験記録](speech-custom-vocabulary-experiments.md) に、環境・生の結果・限界を含めて保存する。
