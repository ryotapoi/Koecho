# Xcode 操作

XcodeBuildMCP は使用しない。通常 build は公式 Xcode MCP の `BuildProject` または Apple CLI、App tests は対象を限定した CLI、Package tests は `swift test` を使う。必須 gate の正本は [verification.md](verification.md)。専用署名・起動・停止は [verify-koecho](../.agents/skills/verify-koecho/SKILL.md) に従う。

## 公式 MCP の接続と対象確認

毎セッション実際の接続を確認する。ツールが列挙されているだけでは接続成功ではない。`XcodeListWorkspaces` が未承認を返す場合は、対象 checkout の `Koecho.xcodeproj` の絶対パスで `XcodeOpenWorkspace` を呼ぶ。返された workspace ID を以後の操作へ渡す。Xcode が求めるエージェント承認は本人が判断する。グローバル登録や他 project を変更しない。

`XcodeListSchemes`、`XcodeListRunDestinations`、`XcodeListTestPlans` で Koecho / My Mac / 対象 plan を確認する。他作業の workspace の scheme・destination を切り替えない。共有 scheme は Debug、App と UI tests を含み、test plan は自動生成される。Package tests は別実行。`RunAllTests` は通常 gate には使わない。

- build: `BuildProject`。成否と `errors` を確認する。
- build log: `GetBuildLog` の severity / pattern / glob で絞る。`totalFound`、`truncated`、`buildIsRunning` を確認し、上限に達した場合は `fullLogPath` の全件ファイルを検索する。
- テスト一覧: `GetTestList`。`counts`、`totalTests`、`truncated` を確認し、100件上限を超えた一覧は `fullTestListPath` から対象と ID を取得する。
- 選択テスト: `RunSomeTests` へ取得した `targetName` と `identifier` をそのまま渡す。Swift Testing の末尾 `()` も省略しない。`counts.passed > 0`、failed / skipped / notRun が 0、期待対象と件数を確認する。0件、失敗、timeout は成功ではない。全失敗は `fullSummaryPath`、console、xcresult から取得し、表示された先頭100件だけで判断しない。

MCP の full path は一時ファイルなので、必要な log・summary・xcresult を run の証拠へコピーする。MCP 操作が timeout した場合は、再実行前に当該 workspace の test host / process の実行パスと開始時刻を確認する。別作業の process を一括停止しない。

## CLI の保存済み入口

repository root から実行する。run 名は毎回未使用の一つのディレクトリ名。出力は `.tmp/verification/cli/<run>`、成果物は `.tmp/verification-scratch/<run>`。他 checkout と共有しない。通常は現在の `xcode-select`、Beta が必要な run だけ `DEVELOPER_DIR` を指定する（`xcode-select --switch` はしない）。実行に必要な cache / process 読取が sandbox に拒否された場合はその command だけ escalation する。

```sh
scripts/verify.py build --run build-check
scripts/verify.py app-list --run app-discovery
scripts/verify.py app-tests --run app-all
scripts/verify.py app-tests --run app-focused --only 'KoechoTests/AppStartupSettingsTests/hostedStartupIsolatesSettingsBeforeNormalization()'
scripts/verify.py package-list --run package-discovery
scripts/verify.py package-tests --run package-all
scripts/verify.py package-tests --run package-focused --filter VoiceInputSettingsTests
```

helper は `xcrun xcodebuild -project <checkout>/Koecho.xcodeproj -scheme Koecho -configuration Debug -destination platform=macOS` を使用する。App tests は `-only-testing:KoechoTests` と `-skip-testing:KoechoUITests`、選択時は発見した ID を使用する。UI tests を変更した場合は対象を明示した別 command として実行・記録する。Package は `xcrun swift test --package-path Packages/KoechoKit` に専用 scratch と event stream 出力を付ける。`--xunit-output` だけでは Swift Testing の結果を得られない。

既定の command timeout は600秒（`--timeout` で指定）、App の各 test timeout は60秒。新しい process group と専用出力 path で run の残留を識別し、所有する process だけ TERM →5秒→KILL で回収する。中断・残留を検出した run は、回収できても失敗として記録する。App は xcresult summary、Package は全 event stream から件数・全失敗を保存する。通常 Package gate は両 test target の実行も確認する。終了コード0でも結果欠損、0件、失敗、skip、未完了 run は失敗とする。

全文を毎回読まず、まず `result.json` / `test-summary.json` の件数と全失敗を確認する。App の parameterized tests は論理 test 数と case 数が異なるため、過去の件数を固定しない。必要な詳細だけ取得する。

```sh
scripts/verify.py results --path .tmp/verification/cli/app-all/tests.xcresult
scripts/verify.py results --path .tmp/verification/cli/app-focused/tests.xcresult --test-id 'AppStartupSettingsTests/hostedStartupIsolatesSettingsBeforeNormalization()'
scripts/verify.py log --path .tmp/verification/cli/app-all/build.log --pattern 'error:|warning:|failed' --limit 30
```

log 出力は全一致件数・表示上限・全文 path を返す。上限を超えた失敗を消さない。run の残留がないことを `result.json` で確認してから、その run の scratch だけ削除し、証拠は保持する。helper の回帰確認は `python3 -B -m unittest discover -s scripts -p 'test_*.py' -v`。

## hosted test の設定回収

`app-tests` の所有記録は run evidence の `hosted-defaults/<launch UUID>.json`、回収結果は `hosted-defaults-cleanup.json` と `result.json` に保存する。App 終了処理で設定値を削除した `appCleanup` と helper が残存を回収した `recovered_by_helper` を区別する。OS が終了後に空 plist を再生成する場合も後者で回収する。helper を使わない正常終了では、空 plist が残った場合に同じ記録で明示回収する。記録・結果が空、所有不一致、生存 host、削除失敗は成功としない。記録は回収後も保持する。

helper 自体の強制終了後は、記録の `pid`・`started`・`command` を `ps` と照合し、その run の host だけを停止してから、対象記録を明示指定する。回収コマンド自身は process を停止しない。正常回収済みの記録は再実行できる。失敗時は記録を削除せず、標準出力の結果を run evidence に保存する。

```sh
scripts/verify.py cleanup-hosted-defaults --record .tmp/verification/cli/<run>/hosted-defaults/<launch UUID>.json
```

通常の Xcode / `xcodebuild` 起動にも同じ終了処理を適用する。helper を使わない起動の所有記録は host の一時ディレクトリ内の `koecho-hosted-defaults/<launch UUID>.json` に残る。対象起動の identity を確認し、その exact 記録で同じ回収コマンドを使う。UUID prefix、時刻、所有記録のない plist を根拠に一括削除しない。

## 補助ツールと未実測の範囲

Apple 文書検索は `DocumentationSearch`、snippet は `RunCodeSnippet`、Preview は `RenderPreview`、診断は `XcodeRefreshCodeIssuesInFile`。必要な場合に利用可能性を確かめる。schema の入口が存在することと実証済みであることを区別する。Preview の SPM 依存は事前 build を行い、返された画像を確認する。

`RunProject` / `GetConsoleOutput` / `StopProject` は対象 scheme の通常版を操作する。任意の専用署名・出力・起動引数・環境変数を一時指定する API ではない。通常版にも履歴・権限・hotkey 等の副作用があるため、単なるツール確認のために起動しない。専用検証版は skill helper を使う。macOS のメニューバー操作は CUA または本人操作で確認し、device / simulator API で代替できると推測しない。
