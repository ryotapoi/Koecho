# Backlog

## v1.6.2 — OS 依存層の注入点整備

設計確定済み（2026-07-04 design-decision）。方針: 新設 protocol は capability 境界の `TranscriberRestartable`（KoechoCore）だけ。CoreAudio / Speech 側は決定規則を純関数（データ渡し）または関数注入で KoechoPlatform 内 internal に抽出し、`AudioDeviceListing` や Speech API の protocol 化はしない（抽出後に残る本体は OS グルーだけで、mock を注入しても検証できる規則が増えないため）。抽出分のテストは KoechoPlatformTests（`swift test`）、Coordinator の分岐テストは KoechoTests（`test_macos`）。

- [x] AudioDeviceManager の選択規則を `AudioDeviceSelection` に純関数として抽出しテストする
  - 新設: `Packages/KoechoKit/Sources/KoechoPlatform/AudioDeviceSelection.swift` に internal enum `AudioDeviceSelection`
    - `struct MonitoringTarget: Equatable`: `effectiveUID: String?`（nil = システムデフォルト追従）、`deviceID: AudioDeviceID`、computed `explicitDeviceID: AudioDeviceID?`（effectiveUID が nil なら nil。`levelMonitor.start(deviceID:)` に渡す値）
    - `static func monitoringTarget(requestedUID: String?, resolvedID: AudioDeviceID?, systemDefaultID: AudioDeviceID?) -> MonitoringTarget?`。規則: UID 指定かつ解決成功 → (uid, resolvedID) / UID 指定かつ解決失敗 → (nil, systemDefaultID) へフォールバック / UID 未指定 → (nil, systemDefaultID) / 使えるデバイスなし → nil
    - `static func volumeElement(supportsMainElement: Bool) -> AudioObjectPropertyElement`（true → `kAudioObjectPropertyElementMain` / false → 1）
    - `static func clampedVolume(_ volume: Float) -> Float`（0...1 clamp）
  - `startMonitoring`（`AudioDeviceManager.swift:91-121`）を書き換え: 先に `resolvedID = deviceUID.flatMap(AudioDeviceListing.resolveDeviceID(forUID:))` と `systemDefaultID = AudioDeviceListing.defaultInputDeviceID()` を取得して `monitoringTarget` に渡す。systemDefaultID の取得が UID 解決成功時にも走るようになるが、副作用のない読み取りクエリなので挙動は変わらない。warning ログ 2 本は呼び出し側に残す（フォールバック警告の条件は `deviceUID != nil && resolvedID == nil`）
  - `volumeElement(for:)`（180-187）と `setInputVolume` の clamp（134）も抽出関数の呼び出しに置き換える。`setInputVolume` の guard（137-141）は volumeElement の定義上常に真（main が返るのは supportsMain の時だけ）なので、確認の上削除してよい
  - テスト（KoechoPlatformTests 新規 `AudioDeviceSelectionTests.swift`）: monitoringTarget の 4 規則、explicitDeviceID の nil / 非 nil、volumeElement の 2 ケース、clamp の境界（-0.5→0 / 0 / 0.5 / 1 / 1.5→1）
- [x] SpeechAnalyzerEngine の決定規則を分離してテストする
  - (a) マイク権限（`SpeechAnalyzerEngine.swift:109-126`）: KoechoPlatform に internal enum `MicrophonePermissionRule` を新設。`enum Action: Equatable { case proceed, requestAccess, deny }` と `static func action(for status: AVAuthorizationStatus) -> Action`。マッピング: `.authorized` → proceed / `.denied` `.restricted` → deny / `.notDetermined` → requestAccess / `@unknown default` → proceed（現行の break と同じ）。requestAccess 後の granted 分岐（granted なら続行、でなければ deny）は呼び出し側に残す。テスト: 全 4 ケース
  - (b) モデル検証フロー（139-157）: KoechoPlatform に internal enum `SpeechModelPreparation` を新設し、関数注入で抽出: `static func ensureModelAvailable(localeKey: String, isVerified: (String) -> Bool, markVerified: (String) -> Void, installationRequest: () async throws -> (() async throws -> Void)?, updateStatus: (VoiceInputEngineStatus?) -> Void) async -> VoiceInputEngineError?`（戻り値 nil = 成功。installationRequest の戻り値はダウンロード操作で、nil = ダウンロード不要）。エンジン側は installationRequest に `AssetInventory.assetInstallationRequest(supporting: [transcriber])` と `request.downloadAndInstall()` を包んで渡す。テスト規則: 検証済み → installationRequest 未呼び出しで nil を返す / 未検証かつ request nil → markVerified が呼ばれ status 更新なしで nil / ダウンロードあり成功 → status が `.downloadingModel` → nil の順に更新、markVerified、戻り nil / installationRequest またはダウンロードが throw → status を nil に戻して `.modelDownloadFailed` を返し、markVerified は呼ばれない
  - (c) デバイス UID フォールバック（163-182）: `AudioDeviceSelection` に `static func engineDeviceID(requestedUID: String?, resolvedID: AudioDeviceID?, hasAudioUnit: Bool) -> AudioDeviceID?` を追加（nil = システムデフォルトのまま）。規則: UID 未指定 → nil / 解決成功かつ audioUnit あり → resolvedID / それ以外 → nil。warning ログと `AudioUnitSetProperty` の status 失敗時フォールバックは呼び出し側に残す
  - (d) `waitWithTimeout`（379-397）は private のため現状ではテスト不可。KoechoPlatform の internal な汎用ヘルパー（例: `enum TaskTimeout` の `static func hasTimedOut<Failure: Error>(_ task: Task<Void, Failure>, seconds: Double) async -> Bool`、`@available` 制約なし）へ移動してエンジンから呼び替える。テスト: 即完了する task → false / 完了しない task + 短い timeout → true
- [x] restartTranscriber を capability protocol 化して VoiceInputCoordinator の分岐をテストする
  - KoechoCore の `VoiceInputEngine.swift` に追加: `@MainActor public protocol TranscriberRestartable: AnyObject { @discardableResult func restartTranscriber() async -> Bool }`。SpeechAnalyzerEngine を準拠させる（メソッドは実装済みなので準拠宣言のみ）
  - `restartTranscriberIfNeeded()`（`VoiceInputCoordinator.swift:336-359`）のダウンキャストを `engine as? any TranscriberRestartable` に変更。macOS 26 のシンボル参照が消えるので `if #available(macOS 26, *)` ガードは削除する
  - 既存の `MockVoiceInputEngine`（`KoechoTests/MockVoiceInputEngine.swift`）は準拠させず、TranscriberRestartable に準拠した別 mock（戻り値を設定できる `restartResult: Bool` と呼び出し回数を持つ）を新設する — 既存テストの「restart 分岐に入らない」前提を壊さないため
  - テスト（KoechoTests）: restart 成功かつ replay 中 → suppression 開始 / restart 失敗 → `transcriberAlreadyRestarted` が false に戻り再試行可能 / 連続呼び出しで restart は 1 回だけ

## v1.6.3 — UI モデル変更

- [ ] ReplacementRuleEditView の patterns ForEach を index 識別から安定 ID 識別に変える
  - `ReplacementRuleEditView.swift:52` の `ForEach(rule.patterns.indices, id: \.self)` が index を identity にしている（Apple ガイドのアンチパターン）
  - 途中のパターンを削除すると以降の行の identity がずれ、編集中 TextField のフォーカス・状態リセットや挿入/削除アニメーションの崩れにつながる
  - 方式確定（2026-07-03 design-decision）: モデル変更。patterns の要素を ID 付き型にする（行 identity は編集 UI に既に存在する意味で、型で表す）。encode/decode は `[String]` のまま維持し decode 時に ID 生成（保存フォーマット不変、永続 ID は現在の要求にないため足さない）
  - 実装時の注意: `ReplacementRule` は `Equatable` のため、ID を比較に含めるか（内容が同じでも ID 違いで不等になる）は実装時に既存テスト・利用箇所を見て決める

## v1.x.0 以降（時期未定）

- [ ] ReplacementRule.swift の `LegacyCodingKeys`（旧 pattern 単数キー decode フォールバック）を撤去する
  - v1.4.0 で patterns 複数化と同時に導入。v1.3.0 以前からの直接更新で置換ルールが decode 失敗→全損するのを防ぐための移行コード
  - 2026-06-11 ユーザー判断: v1.4.x / v1.5.x の移行期間を確保し、v1.6 以降で撤去する（条件は v1.6.0 リリース時点で満たされるため前倒し可）
- [ ] InputPanelScriptStrip にスクリプトの drag-to-reorder を追加する
  - macOS 27 の `.reorderable()` + `.reorderContainer(for:)` で List 以外（横 ScrollView の HStack）でも並び替えが可能になった。機能自体は増えず「どこでできるか」が変わる: 設定画面を開かずに入力パネル上でスクリプト順を変えられる
  - デプロイターゲット macOS 14 のままなら `if #available(macOS 27, *)` ガードが必要。deployment target を上げた後にやれば分岐なしで書ける
  - 実装する時に、管理画面 List の `onMove`（`ReplacementRuleManagementView.swift:52` / `ScriptManagementView.swift:24`）を `reorderable` に揃えるかも同時に判断する

## SDK 更新時（バージョン非依存）

- [ ] Xcode 27 SDK でのビルド互換を確認する
  - SDK 27 で `@State` が property wrapper からマクロに移行。問題になる 3 パターン（init 内で `@State` より後の stored property に代入・property wrapper の合成・extension での memberwise init 委譲）は現状のコードに該当なしと確認済みだが、SDK 更新時にビルドして確認する
  - `@ContentBuilder` への result builder 統一で overlay/background の ShapeStyle オーバーロードが曖昧になるケースあり。エラーが出たら swiftui-whats-new-27 skill の references を参照して直す（自力で推測しない）

## レビュー記録（対応不要と判断したもの）

- SwiftUI レビュー（2026-07-02 swiftui-specialist skill）で確認済み・対応不要: `@Observable` + `@Bindable` 統一、新 `onChange` シグネチャ、`Identifiable` な List/ForEach、unary な行ビュー、ローカライズ（カタログ登録済み）はいずれも問題なし。NavigationView / AnyView / ObservableObject 等の soft-deprecated API の使用もなし
- macOS 27 レビュー（2026-07-02 swiftui-whats-new-27 skill）で該当なし: AsyncImage（不使用）、alert/confirmationDialog の item binding（alert 不使用）、swipeActions の非 List 対応（List のみ使用）、新 toolbar API（対象になる toolbar がほぼない）、ReadableDocument/WritableDocument（ドキュメントベースアプリではない）
- テストカバレッジ調査（2026-07-03 実測: App target 42.3% / KoechoCore 91〜100% / KoechoPlatform は OS 依存層に空白）。方針: テスト数を増やすのではなく「OS 依存コードに混ざった純ロジックの抽出・注入点の追加」でテスト可能な形に直す（上の v1.6.0〜v1.8.0 に割り振り済み）
  - KoechoCore は初期値・永続化・migration・エッジケースまで網羅済みで追加余地が小さい
  - 設定系 SwiftUI View の 0%（GeneralSettingsView / VoiceInputSection / HistoryView 等）は View 宣言主体で、ロジックは委譲先の型が持つ。View の行カバレッジ自体は追わない
  - LiveAccessibilityClient / LiveCGEventClient / AccessibilityTrust は OS API の薄いラッパーで protocol 境界の外側。消費者側（SelectedTextReader / ClipboardPaster）は Mock 注入でテスト済み
