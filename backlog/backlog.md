# Backlog

## 運用ルール

- Backlog には、今後着手でき、完了を判定できる作業を `- [ ]` 形式のタスクとして置く。
- 完了したタスクは `- [x]` にし、版を切る変更（バージョンを上げてタグを打つ変更）で消す。取りやめたタスクは消す。
- 対応要否を決める調査もタスクにできる。観察事実だけを残さず、判断したい問いと、判断をもって完了とすることを明示する。
- 粗いメモで起票してよいが、着手前に目的と受け入れ条件を読める粒度へ詰める。
- タスクの行には短い作業名を書き、説明は空行を挟んだ字下げ段落に分ける。
- バージョン番号を付ける場合は SemVer に従う。
- タスクは `###` 見出しでグループに分ける。バージョンが確定したグループだけ、`### v0.1.0 名前` のように見出しへ番号を付ける。
- グループが大きい場合は、`####` 見出しでさらに分割してよい。

## タスク

### 改善

- [ ] ビルド時の既存の警告を解消する

  通常 build と app tests のビルドで毎回約20件の警告が出ており、新しい警告が埋もれる。対象は `Koecho/Assets.xcassets` の `KoechoStatusItemColor`・`MenuBarIcon` の未割当 child、`KoechoUITests/HistoryLoadProtectionUITests.swift`（15件、main actor 分離などの並行性警告）、`KoechoTests/VoiceInputTextViewTests.swift`（4件）、`KoechoTests/AppStartupSettingsTests.swift`（2件）。2026-11-27 の `.tmp/verification/cli/candidate-navigation-build/build.log` と `candidate-navigation-app-tests/build.log` で確認した。

  アプリの挙動は変えない。build と app tests のログに上記ファイルの警告が出ないこと、Package tests・App tests・UI tests が成功することを確認する。

- [ ] SwiftUI Preview の表示で権限ダイアログが出るかを確かめ、出るなら止める

  Xcode で `#Preview` を表示すると、Preview の表示役として DerivedData の Debug 版 Koecho（Bundle ID は通常版と同じ `com.ryotapoi.Koecho`）が起動する。2026-10-22 と 2026-11-27 の検証で起動を確認した。`Koecho/KoechoApp.swift` の `init` はテスト中以外は必ず `requestAccessibilityIfNeeded()` を呼ぶため、Preview の表示だけでアクセシビリティ許可のダイアログが出る可能性がある。ただし、Preview の起動で `init` が実際に呼ばれるか、本人が見たダイアログがこの起動によるものかは確認していない（時刻からの推定）。

  まず、Settings などの Preview を表示し、Debug 版 Koecho の起動と許可ダイアログの有無を確かめる。出る場合は、Xcode が Preview 用の起動に渡す `XCODE_RUNNING_FOR_PREVIEWS=1` を見て、そのときは許可を求めないようにする。出ない場合は、確認結果を記録して完了とする。

  対処した場合は、Preview を表示してもダイアログが出ないこと、Xcode からの通常実行と普段使いの起動では従来どおり許可を求めることを確認する。
