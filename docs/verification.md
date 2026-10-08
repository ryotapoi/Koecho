# Verification

この文書を、変更条件ごとの必須 build / test / 実行確認の正本とする。Xcode の操作方法は [xcode.md](xcode.md) に従う。

## 必須 gate

| 変更条件 | 必須の確認 |
| --- | --- |
| ドキュメントだけ | build / test / 実行確認は不要。変更した参照・パス・コマンドを repository の実態と照合する。 |
| `Packages/KoechoKit` の test だけ | `swift test --package-path Packages/KoechoKit` |
| `KoechoCore` / `KoechoPlatform` の production code または `Package.swift` | `swift test --package-path Packages/KoechoKit` と通常 build（公式 MCP `BuildProject` または CLI、操作は [xcode.md](xcode.md)） |
| App target の production code、resource、entitlement、Xcode project / scheme | 通常 build（公式 MCP `BuildProject` または CLI、操作は [xcode.md](xcode.md)） |
| App target のテスト、または App target のテスト可能な振る舞い / bug fix | `xcodebuild` で `-only-testing:KoechoTests` を指定して app tests を実行する。production code を変更した場合は通常 build も行う。 |
| Package と App の境界をまたぐ振る舞い | Package の `swift test`、通常 build、`xcodebuild -only-testing:KoechoTests test` |
| SwiftUI の表示・レイアウト | 該当する上記 gate に加え、適切な `#Preview` があれば Apple Xcode MCP の `RenderPreview`、なければ専用検証アプリを起動して実画面を確認する。 |
| ウィンドウ lifecycle、focus、入力、メニュー、操作フロー | 該当する上記 gate に加え、専用検証アプリで操作を確認する。Preview だけでは代替しない。 |
| 権限、実際のディクテーション、ペースト、global hotkey、audio device、外部 script など OS / 外部環境との連携 | 該当する自動 gate に加え、専用検証アプリと実環境で対象操作を確認する。自力で確定できない権限・hardware・外部 app 依存だけをユーザー確認に回す。 |

テスト可能な振る舞い変更や bug fix には unit test / regression test を追加または更新する。追加できない場合は理由と未検証範囲を報告する。必須 gate を実行できず、代替証拠でも裏付けられない High-risk 変更は完了扱いにしない。

## 制約と例外

- Xcode 操作は [xcode.md](xcode.md) に従う。project 既定は `Koecho.xcodeproj`、scheme は `Koecho`、configuration は Debug。必須 gate を実行できない場合は未実行として報告する。
- `Koecho` scheme は `KoechoTests` と `KoechoUITests` の両方を含む。通常の app test は `-only-testing:KoechoTests` で UITests を除外し、UITest を追加・変更した場合だけ対象に含める。
- `KoechoTests` は `TEST_HOST = Koecho.app` の hosted test。通常の app lifecycle を起動するため、`KoechoApp` は `NSClassFromString("XCTestCase") != nil` でテストを検出し、system integration を抑止する。App の初期 `AppState` / `Settings` も、設定を読み込む前に起動ごとの専用 `suiteName`（`com.ryotapoi.Koecho.hosted-tests-<UUID>`）へ隔離し、通常版の `.standard` は使わない。各テストでは引き続き factory / mock を使い、UserDefaults を扱う fixture は専用の `suiteName` で隔離して自分の domain のみ後片付けする。
- hosted test の初期 HistoryStore は起動ごとの専用一時ディレクトリへ隔離し、通常版の保存先解決・旧履歴移行を行わない。各履歴テストも専用ディレクトリを注入する。起動時 purge はテスト判定で抑止される。自動起動 suite の UUID は run と紐付いて記録されず、fixture と異なり終了時の domain 削除も実装されていない。既存 domain を一括削除せず、残存は報告する。この製品側の lifecycle 改善を検証 helper の変更へ混ぜない。
- 音声認識の OS / hardware 連携は unit test で実送信せず、注入した engine や mock までを検証する。実動作は実環境の確認で補う。
- `RenderPreview` が使えない場合は専用検証アプリとスクリーンショットで代替する。いずれも使えず対象 View の局所確認しかできない場合は、未確認の見た目を報告する。SPM module を使う Preview は事前 build が必要。
- 成否は終了コードだけでなく、実行件数・全失敗・未完了・timeout・残留 process も確認する。保存済み CLI helper と結果取得方法は [xcode.md](xcode.md) を参照する。0件や結果欠損は成功ではない。
- app test が hang / timeout した場合は、再実行前に残留した test process / test host app を確認する。中断した run に由来すると確認できる process だけを終了し、再実行結果で判断する。

## テストの配置と隔離

- Swift Testing（`@Test` / `#expect`）を使う。Core の設定・モデル・純ロジックは `KoechoCoreTests`、Platform の OS 境界は `KoechoPlatformTests`、入力パネルと UI 近傍は `KoechoTests` で検証する。
- マイク、権限、子プロセス、クリップボードなどの外部依存は、factory と mock を注入するか失敗時の動作をテストする。UI 近傍のテストも `TestSupport` の factory と mock を使い、global singleton に依存しない。
- 設定テストの UserDefaults は各 fixture 専用の `suiteName` を使い、自分の domain だけを後片付けする。`UserDefaults.standard` には書かない。nil 相当の保存値は該当 Settings の既存方式に合わせ、`Data()` sentinel と `removeObject` を混在させない。
- menu や selector 周辺のロジックは、SwiftUI の見た目だけに頼らず、対象メソッドと状態遷移を直接検証する。JSON や Foundation 型を使うテストファイルでは `import Foundation` を明示する。
