# Backlog

## SDK 更新時（バージョン非依存）

- [ ] Xcode 27 SDK でのビルド互換を確認する
  - SDK 27 で `@State` が property wrapper からマクロに移行。問題になる 3 パターン（init 内で `@State` より後の stored property に代入・property wrapper の合成・extension での memberwise init 委譲）は現状のコードに該当なしと確認済みだが、SDK 更新時にビルドして確認する
  - `@ContentBuilder` への result builder 統一で overlay/background の ShapeStyle オーバーロードが曖昧になるケースあり。エラーが出たら swiftui-whats-new-27 skill の references を参照して直す（自力で推測しない）

## いつかやりたい改善

- [ ] 選択した入力デバイスが解決できなかった時にパネル上でわかるようにする（必須ではない）
  - 現状は warning ログのみで、選んだマイクと別のデバイスで録音されていることがユーザーに見えない（2026-07-09 Codex audit）
  - 2026-07-09 ユーザー判断: 見た目的に良い形で出せるなら入れる程度の優先度。ステータス表示の意匠が決まったタイミングで実装する
  - 現在の `voiceEngineStatus` は ProgressView の表示と入力欄の dim を伴う「処理中」用なので、録音を継続できるフォールバック警告に流用しない。スピナーなしの非ブロッキング通知として意匠・状態を分ける
  - 選択デバイスを解決できない結果から通知状態への変換は unit test で検証できる。実際のデバイス切断とシステムデフォルトへのフォールバックは手動確認する
