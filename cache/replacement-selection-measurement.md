---
generated: 2026-10-11
source_commit: a369b6a
---

# 選択範囲置換の計測

比較対象は `a369b6a` の `ReplacementService.replaceOccurrences`（各 match について `findReplacementCandidates(rules, in: text).contains($0)`）と、同じ本文・ルールの候補を一度だけ構築する未コミット差分。macOS 27.0.1、Xcode 27.1 RC、arm64 MacBook Pro、Koecho Debug hosted test。入力は `"a "` × 300、規則は `a → b` 1件、全文選択。各反復は新しい `ReplacementService` と `MockTextViewOperating` を作り、`replaceSelection()` の開始から同期終了までを `ProcessInfo.processInfo.systemUptime` で計時した。結果文字列と選択範囲を毎回照合した。ビルド・ホスト起動は計時外。

比較時は `KoechoTests/ReplacementServiceTests.swift` の `ReplacementServiceTests` 末尾へ次の一時テストを追加し、旧→新→旧→新の順にソースの検証部分だけを切り替えて各版3回測った。一時テストは最終差分から除去した。旧版は上記 commit の `replaceOccurrences`、新版は [ReplacementService.swift](../Koecho/ReplacementService.swift) の現在の実装で復元できる。通常のユーザー設定や通常版アプリは使わない。

```swift
@Test func temporaryReplacementPerformance() {
  let count = 300
  let input = Array(repeating: "a ", count: count).joined()
  for iteration in 0..<3 {
    let (service, state, view, _) = makeService(inputText: input)
    state.settings.replacement.isAutoReplacementEnabled = false
    state.settings.replacement.replacementRules = [ReplacementRule(pattern: "a", replacement: "b")]
    view.selectedRangeValue = NSRange(location: 0, length: input.utf16.count)
    let start = ProcessInfo.processInfo.systemUptime
    service.replaceSelection()
    let elapsed = ProcessInfo.processInfo.systemUptime - start
    #expect(state.inputText == Array(repeating: "b ", count: count).joined())
    #expect(view.selectedRange() == NSRange(location: 0, length: input.utf16.count))
    print("REPLACEMENT_PERF count=\(count) iteration=\(iteration) elapsed_ms=\(elapsed * 1000)")
  }
}
```

各版に対し未使用の run 名で `scripts/verify.py app-tests --run <run> --only 'KoechoTests/ReplacementServiceTests/temporaryReplacementPerformance()'` を実行する。値は `.tmp/verification/cli/<run>/build.log` の `REPLACEMENT_PERF` 行、成否・実行数・経過時間は同じ場所の `result.json` にある。この計測の証拠 run は `replacement-baseline-perf-300`、`replacement-candidate-perf-300`、`replacement-baseline-perf-300-repeat`、`replacement-candidate-perf-300-repeat`。各 run の exit は0、timeout・残留なし。所要時間は順に26.797、24.685、26.200、26.709秒。末尾の run は次の検証処理テストも含め2 tests passed、ほかは各1 test passed。

| 全操作の計時 | 3回の値 (ms) | 中央値 (ms) |
| --- | --- | ---: |
| 旧 1 | 617.467、602.983、601.688 | 602.983 |
| 新 1 | 7.458、6.499、6.677 | 6.677 |
| 旧 2 | 612.078、598.497、607.410 | 607.410 |
| 新 2 | 7.585、6.585、6.665 | 6.665 |

候補検証だけは変更後の同一テストプロセスで旧式と新式を ABBA 交互に4回ずつ計測した。`findReplacementCandidates` の結果を事前に作り、旧式は各 match で再構築、新式は1回構築した。次の一時テストを同じ suite に追加して `scripts/verify.py app-tests --run <run> --only 'KoechoTests/ReplacementServiceTests/temporaryValidationPerformance()'` で再実行できる。

```swift
@Test func temporaryValidationPerformance() {
  let input = Array(repeating: "a ", count: 300).joined()
  let rules = [ReplacementRule(pattern: "a", replacement: "b")]
  let matches = findReplacementCandidates(rules, in: input)
  for iteration in 0..<4 {
    for oldFirst in (iteration.isMultiple(of: 2) ? [true, false] : [false, true]) {
      let start = ProcessInfo.processInfo.systemUptime
      let valid: Bool
      if oldFirst {
        valid = matches.allSatisfy { findReplacementCandidates(rules, in: input).contains($0) }
      } else {
        let currentCandidates = findReplacementCandidates(rules, in: input)
        valid = matches.allSatisfy { currentCandidates.contains($0) }
      }
      let elapsed = ProcessInfo.processInfo.systemUptime - start
      #expect(valid)
      print("VALIDATION_PERF old=\(oldFirst) iteration=\(iteration) elapsed_ms=\(elapsed * 1000)")
    }
  }
}
```

旧 604.748、608.734、603.047、597.056 ms、新 3.828、3.865、3.692、3.630 ms。証拠は `.tmp/verification/cli/replacement-candidate-perf-300-repeat/build.log` の `VALIDATION_PERF` 行。全操作の差の大部分が候補検証に由来することを支持するが、実画面の待ち時間は測っていない。

最終差分の検証: `scripts/verify.py app-tests --run replacement-final-app-tests` は exit 0、41.855秒、230 tests / 274 runs passed、失敗0。`scripts/verify.py build --run replacement-final-build` は exit 0、20.281秒。一時テスト除去後の `scripts/verify.py app-tests --run replacement-final-clean-tests --only 'KoechoTests/ReplacementServiceTests/mixedCandidateActionRejectsStaleMatchWithoutPartialEdit()' --only 'KoechoTests/ReplacementServiceTests/selectedSnapshotMapsMultipleEditsAndNextVoiceWithoutChaining()'` は exit 0、24.187秒、2 tests passed。各 `result.json` は `.tmp/verification/cli/` 配下にある。

Release hosted test は既定設定で `@testable import Koecho` の testability 不足により build exit 65。`ENABLE_TESTABILITY=YES` を一時指定すると、配布用 app と test bundle の Team ID 不一致で test bundle がロードできず exit 65。1,000件と専用検証アプリの実画面操作も未計測。300件の計測は App target の実サービスと mock text view を使用し、実 NSTextView の描画・操作は含まない。

実画面検証の再試行: sandbox 内の `security find-identity` は0件だったが、sandbox 外では固定 Developer ID を確認できた。専用 build は exit 0、20.167秒、launch・doctor も成功。CUA `getApp` は `timeoutReached` となり、本人操作待ち。証拠は `.tmp/verification/verify-koecho/20261011-replacement-ui-retry/`。

本人操作の結果: 2026-10-11、変更後の専用アプリについて「元の悪い状態を知らないから。でも大丈夫だと思うよ」と報告。実画面で問題の報告はないが、旧版との体感比較・個別操作の詳細は未確認。性能改善は hosted A/B 計測を根拠とする。本人報告は上記証拠の `manual-handoff.json`、後片付け結果は `session.json` に保存。
