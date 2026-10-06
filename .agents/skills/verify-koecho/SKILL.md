---
name: verify-koecho
description: Koecho の macOS メニューバー・入力パネル・Settings を実画面で検証するときに使う。専用署名ビルドの起動、識別、CUA または本人操作、権限維持確認、後片付けを行う。
---

# Koecho の実画面検証

実画面の自動操作は **blocked**。2026-10-06 に CLI の専用署名 build・起動・doctor・PID 限定ログ取得を実測したが、CUA の絶対パス取得は `timeoutReached`。画面操作と権限維持は別の証拠が必要であり、プロセス起動だけでは検証済みとしない。[機能マップ](features/README.md)を使い、通った機能だけに証拠を付ける。

## 正本と隔離の限界

作業開始時に repository の AGENTS.md と [検証の正本](../../../docs/rules/verification.md)を読む。変更条件ごとの必須 gate は正本に従い、このスキルで置き換えない。Xcode は [Xcode MCP 操作](../../../docs/rules/xcode-mcp.md)に従う。製品コード・project・tests は変更せず、既存差分を保持する。

| 固定項目 | 値 |
| --- | --- |
| 対象 | macOS 27.0+、Koecho scheme、Debug |
| Bundle ID | `com.ryotapoi.Koecho.Verification` |
| Info.plist の表示名・bundle 名 | `Koecho Verification` |
| 実行ファイル | `Koecho.app/Contents/MacOS/Koecho` |
| 署名 | Developer ID Application: Ryota Kurosaki (5AGP9L4RNN) |
| 証明書 SHA-1 | `85B7C4380400A535BE172DF27D367F6282068BE5` |
| 出力 | repository の `tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app` |

Bundle ID は通常版の UserDefaults / TCC identity と分けるため、表示名は本人が対象を認識するため、固定証明書と path は再ビルド時の署名 requirement と権限継続性を保つために使う。固定 path は checkout ごとに異なるが、複数 worktree の検証版は同じ UserDefaults domain と履歴保存先を共有するため同時に操作しない。

上の証明書と private key が利用可能であることが前提。使えない場合は blocked とし、ad-hoc や別証明書へ自動で切り替えない。`PRODUCT_NAME` / `PRODUCT_MODULE_NAME` の一括 override は依存 SPM target の出力を衝突させるため使わない。

履歴は `~/Library/Application Support/com.ryotapoi.Koecho.Verification/history.json` に保存され、通常版の履歴を読み込まず、起動時整理・追加・削除も検証版の保存先だけに作用する。通常版の旧小文字パスからの移行は通常版だけが行う。同一 Bundle ID の検証版 worktree 同士では履歴を共有するため、同時に操作しない。`Enable History` off は検証中の記録を残したくない場合に選ぶ。通常版の履歴を保護するための必須条件ではなく、検証版自身の起動時整理は off でも実行される。通常版の履歴をバックアップ復元や削除で自動操作しない。

メニューバー名 `Koecho`、Settings タイトル等は製品コードに固定されている。全 UI が Verification 表示になるとは期待しない。通常版が同時起動し、本人がメニューを区別できない場合は操作を止める。通常版を無断終了しない。クリップボード、マイク、global hotkey、貼り付け先は OS と共有する。

## Build-only

ビルドと署名だけ確認する場合は次を使う。起動はしない。

```sh
.agents/skills/verify-koecho/scripts/session.py prepare-build --run koecho-build-check
.agents/skills/verify-koecho/scripts/build_launch.py build --run koecho-build-check
.agents/skills/verify-koecho/scripts/session.py cleanup --run koecho-build-check
```

build-only run は launch / adopt を拒否する。実画面確認には別の未使用 run で通常の prepare が必要。`DEVELOPER_DIR` 未設定なら現在の xcode-select を使い、Beta の run だけ環境変数を設定する。build.log、build-result.json、identity.json は cleanup 後も残る。build-only は履歴・OS 権限に触れない。専用版の起動と実操作の証拠とは分ける。

## Launch

repository root から helper を実行する。`RUN` は毎回異なる一つのディレクトリ名にする。ここでは `20261002-script-check` を使う。helper の process 読取・停止や保護された skill 配下への書込みで sandbox に拒否された場合は、その操作だけ escalation する。

```sh
.agents/skills/verify-koecho/scripts/session.py plan
.agents/skills/verify-koecho/scripts/session.py prepare --run 20261002-script-check
.agents/skills/verify-koecho/scripts/build_launch.py build --run 20261002-script-check
.agents/skills/verify-koecho/scripts/build_launch.py launch --run 20261002-script-check
```

`prepare` 成功後だけ次へ進む。既に専用アプリが起動中なら別 run として所有せず作業を止める。`owner.json` が別 run の場合も、その run の後片付けまで進めない。`plan` の設定を使う専用 helper でビルドし、固定 app を起動する。`build` のログと成否は run の証拠ディレクトリに保存する。`launch` は同じ run の成功記録と固定 app の署名を起動前に検査する。launch は `adopt` を自動実行し、所有 PID を保存する。続けて `doctor` で固定 path、PID、開始時刻、署名と実行ファイル hash を検査する。失敗後は再起動前に状態を確認して所有 run を cleanup する。

初回 script 用 launchArgs は `-voiceInputMode off`。通常のキーボード入力・Settings・script 実行を使い、内部 setter や test hook は使わない。音声開始だけを抑止する。検証中の履歴を残したくない場合は、実画面の Settings → General で `Enable History` を off にし、その状態を確認する。検証版自身の起動時整理はこの設定でも抑止しない。Accessibility 要求、hotkey、外部 script、ペーストも抑止しない。本人確認中はプロセスを保持する期限を決め、返信待ちを検証成功と扱わない。

成功後に:

```sh
.agents/skills/verify-koecho/scripts/session.py doctor --run 20261002-script-check
```

`adopt` は起動前不在・固定実行パス・起動時刻・一件の PID を検査し、署名確認より先にその PID を証拠へ記録する。署名確認が失敗しても `cleanup` で所有 process を終了できる。起動コマンドの成功だけで識別済みとしない。`doctor` は read-only で Info.plist、固定証明書、署名検証、designated requirement、所有 PID / 起動時刻を確認する。UI readiness は保証しない。操作前と意外な失敗後に使う。実画面で対象メニューまたはパネルが観測できて初めて操作可能と判断する。初期パネルは非表示。

## Drive と本人操作

確認対象はその作業に関係する [機能マップ](features/README.md) の項目を選ぶ。通常作業中に実際のユーザー導線を確認できた場合も、対象・操作・観測結果・副作用・証拠を記録してその項目の確認に使ってよい。項目の順序は固定しない。一つの成功から他の未確認項目の成功を推測しない。

代表的な初回導線は [custom-script](features/custom-script.md)。`tr a-z A-Z` を Settings から登録し、本文 `original` がボタン操作で `ORIGINAL` になることを確認する。スキルの実操作経路を実証済みとするには、少なくとも一つの mapped feature の launch・doctor・操作・証拠保存・cleanup を実施し、確認範囲を明記する。build・起動だけでは代替しない。

CUA の最初の呼出しはこれ一つだけ:

```js
let app = await cua.getApp('/Users/ryota/Sources/ryotapoi/Koecho/tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app');
```

別 checkout では plan が返す絶対パスを使う。以後は返された documentation と live AX state の名称を使う。操作後に `getAXState()` を取得し、要素番号を取り直す。固定座標・推測した要素番号は使わない。timeout した場合は同じ取得を繰り返さず、doctor → blocked 記録 → 本人操作への引継ぎ。Finder / desktop / 全体 screenshot は現在許可されていない。別 UI 技術で迂回しない。

権限が必要なら本人に対象を **Koecho Verification / com.ryotapoi.Koecho.Verification / plan の app 絶対パス** と示す。システム設定 → プライバシーとセキュリティ → アクセシビリティで対象を確認する。追加が必要な場合は + のファイル選択で Cmd+Shift+G に絶対 app path を入力する。入力監視も hotkey の必要性を確認して対象を設定する。マイクは Voice を on にして開始した際の対象アプリの要求を本人が判断する。通常版の Koecho を選ばない。許可変更は新しいアクセスを与えるため、本人の判断で行ってもらう。CUA backend 自身の権限と Koecho の権限は別物。TCC DB 読取・reset はしない。

## 再ビルド・再起動と権限維持

初回 script 成功後、許可項目・本人操作・対象 path を記録し、cleanup（build は保持し所有 marker を解放）→新しい run の prepare→`build_launch.py build`→`build_launch.py launch`→doctor を行う。前後の証明書 SHA-1 と designated requirement、Bundle ID、path が同じことを確認する。これだけでは TCC 維持の証拠にならない。

本人または利用可能な CUA で、再許可なしに同じ script 操作と、許可が必要な hotkey / paste を実施する。Microphone を許可済みなら音声機能も再確認する。音声確認の launch では `build_launch.py launch --run <run> --voice-input-on` を使い、明示的な `-voiceInputMode on` を渡す。off / on は Settings が永続化し得るため、単に off 引数を外す方法では保存済み off を解除できない。結果表に Accessibility / Input Monitoring / Microphone ごとに「初回設定」「再起動後の実操作」「再許可の有無」を残す。未設定・未操作の項目は未確認とする。script の成功だけで権限維持を検証済みとしない。

helper の回帰テストは repository root で `python3 -m unittest discover -s .agents/skills/verify-koecho/scripts -p 'test_*.py' -v` を実行する。

## Evidence と Cleanup

証拠は `tmp/verification/verify-koecho/<run>/`。scratch の外であり gitignored。`session.json`、doctor 出力、`build.log`、`build-result.json`、stdout / stderr / PID 限定 OSLog、実施者、操作、観測結果、所要時間、失敗、権限設定、残存ギャップを保存する。CUA の対象 app screenshot を取得できた場合だけ保存し、本人確認は報告文と実施日時で残す。実行不能は draft / blocked と記し、build 成功を実画面検証済みとしない。

```sh
.agents/skills/verify-koecho/scripts/session.py cleanup --run 20261002-script-check
```

所有 PID が同じ実行パス・起動時刻のときだけ SIGTERM を送る。scratch の削除・所有 marker の解放は同じ run の marker がある場合だけ行う。5秒で停止しない場合、または固定実行パスに未所有の process が残る場合は失敗を `session.json` に記録する。未所有 process は kill しない。残留時は scratch も保持する。権限維持の次回確認用に固定 build は保持する。最終終了時は同じ cleanup に `--remove-build` を付けて所有 scratch を削除する。証拠、専用 UserDefaults、TCC 許可、検証版履歴は保持する。ユーザーの通常版や既存プロセスに触れない。証拠が残ることと、無関係な既存差分を変更していないことを確認する。コミットしない。

## 起動オプションと観測

`build_launch.py build --run <run> --timeout 600` は Apple CLI を使い、[共通 helper](../../../scripts/verify.py) の timeout・残留検査と run のログを保存する。通常 build / tests の gate は [Xcode 操作](../../../docs/rules/xcode-mcp.md) にあり、このスキル限定ではない。

```sh
.agents/skills/verify-koecho/scripts/build_launch.py launch --run 20261002-script-check --arg=-AppleLanguages --arg='(en)' --env KOECHO_VERIFICATION_RUN=20261002-script-check
.agents/skills/verify-koecho/scripts/build_launch.py logs --run 20261002-script-check --pattern 'Accessibility|Script|Hotkey' --limit 30
```

起動環境は `open --env` で対象 process にだけ渡し、`launchctl setenv` はしない。引数は `--arg` を繰り返す（先頭が `-` なら `--arg=...`）。stdout / stderr は evidence に直接保存し、OSLog は所有 PID と subsystem で限定する。`logs` は直近5分の保持済みログであり、無期限 stream や全イベントの保存を保証しない。debug が必要なら操作前に本人と対象・期限を決め、PID 限定 `log stream` を別の所有 process として管理する。機密値を引数や environment probe に使わない。

通常版が同時起動していると、同じ hotkey が両方へ届く可能性がある。global hotkey / paste の実操作は本人が通常版を止めるなどして競合を解消した後だけ行う。通常版の無断停止、クリップボード全文の保存、通常版履歴の reset はしない。貼り付け先は本人が指定した disposable 文書を使い、本文・クリップボード復元を観測する。マイク・音量 ducking・モデル download は実環境の作用であり、script / keyboard の確認から推測しない。
