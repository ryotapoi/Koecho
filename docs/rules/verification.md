# Verification

この文書を、変更条件ごとの必須 build / test / 実行確認の正本とする。Xcode MCP の操作方法は `docs/rules/xcode-mcp.md`、テストの配置と責務は `docs/rules/principles.md` と `docs/rules/architecture.md` を参照する。

## 必須 gate

| 変更条件 | 必須の確認 |
| --- | --- |
| ドキュメントだけ | build / test / 実行確認は不要。変更した参照・パス・コマンドを repository の実態と照合する。 |
| `Packages/KoechoKit` の test だけ | `swift test --package-path Packages/KoechoKit` |
| `KoechoCore` / `KoechoPlatform` の production code または `Package.swift` | `swift test --package-path Packages/KoechoKit` と XcodeBuildMCP の `build_macos` |
| App target の production code、resource、entitlement、Xcode project / scheme | XcodeBuildMCP の `build_macos` |
| App target のテスト、または App target のテスト可能な振る舞い / bug fix | XcodeBuildMCP の `test_macos` に `-only-testing:KoechoTests` を指定する。production code を変更した場合は `build_macos` も行う。 |
| Package と App の境界をまたぐ振る舞い | Package の `swift test`、`build_macos`、`test_macos -only-testing:KoechoTests` |
| SwiftUI の表示・レイアウト | 該当する上記 gate に加え、適切な `#Preview` があれば Apple Xcode MCP の `RenderPreview`、なければ `build_run_macos` で実画面を確認する。 |
| ウィンドウ lifecycle、focus、入力、メニュー、操作フロー | 該当する上記 gate に加え、`build_run_macos` で操作を確認する。Preview だけでは代替しない。 |
| 権限、実際のディクテーション、ペースト、global hotkey、audio device、外部 script など OS / 外部環境との連携 | 該当する自動 gate に加え、`build_run_macos` と実環境で対象操作を確認する。自力で確定できない権限・hardware・外部 app 依存だけをユーザー確認に回す。 |

テスト可能な振る舞い変更や bug fix には unit test / regression test を追加または更新する。追加できない場合は理由と未検証範囲を報告する。必須 gate を実行できず、代替証拠でも裏付けられない High-risk 変更は完了扱いにしない。

## 制約と例外

- Xcode の build / test / 実行には XcodeBuildMCP を優先し、Bash で `xcodebuild` を直接実行しない。project 既定は `Koecho.xcodeproj`、scheme は `Koecho`、configuration は Debug。XcodeBuildMCP が使えず必須 gate を実行できない場合は、未実行として報告する。
- `Koecho` scheme は `KoechoTests` と `KoechoUITests` の両方を含む。通常の app test は `-only-testing:KoechoTests` で UITests を除外し、UITest を追加・変更した場合だけ対象に含める。
- `KoechoTests` は `TEST_HOST = Koecho.app` の hosted test。通常の app lifecycle を起動するため、system integration は `TEST_HOST` 判定で抑止し、テストでは factory / mock を使う。UserDefaults を扱うテストは専用の `suiteName` で隔離する。
- 音声認識の OS / hardware 連携は unit test で実送信せず、注入した engine や mock までを検証する。実動作は実環境の確認で補う。
- `RenderPreview` が使えない場合は `build_run_macos` とスクリーンショットで代替する。いずれも使えず対象 View の局所確認しかできない場合は、未確認の見た目を報告する。SPM module を使う Preview は事前 build が必要。
- app test が hang / timeout した場合は、再実行前に残留した test process / test host app を確認する。中断した run に由来すると確認できる process だけを終了し、再実行結果で判断する。
