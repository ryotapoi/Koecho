# Backlog

## v1.7.0

- [ ] アクセシビリティ権限の設定後、アプリを再起動せずに貼り付けを再試行できるようにする
  - アクセシビリティ権限エラー時に `frontmostApplication` が失われ、復帰した入力パネルからは同じ対象へ再試行できない。テキストと貼り付け先を保ったままエラー表示に戻す
  - 警告は「アクセシビリティで Koecho をオンにして再試行」を通常手順とし、すでにオンなら現在の Koecho を追加し直すこと、それでも反映されない場合のみ再起動することを案内する。再起動を必須手順とは書かない
  - 回帰テストで権限エラー時のクリップボード復元と、その後の同一パネル再確定が元の対象へ貼り付け、成功時の状態と履歴記録まで正しく進むことを検証する。macOS の実権限反映は手動確認する
- [ ] InputPanelScriptStrip にスクリプトの drag-to-reorder を追加する
  - macOS 27 の `.reorderable()` + `.reorderContainer(for:)` で List 以外（横 ScrollView の HStack）でも並び替えが可能になった。機能自体は増えず「どこでできるか」が変わる: 設定画面を開かずに入力パネル上でスクリプト順を変えられる
  - デプロイターゲット macOS 14 のままなら `if #available(macOS 27, *)` ガードが必要。deployment target を上げた後にやれば分岐なしで書ける
  - 実装する時に、管理画面 List の `onMove`（`ReplacementRuleManagementView.swift:52` / `ScriptManagementView.swift:24`）を `reorderable` に揃えるかも同時に判断する

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
