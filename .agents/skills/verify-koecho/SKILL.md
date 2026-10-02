---
name: verify-koecho
description: Koecho の macOS メニューバー・入力パネル・Settings を実画面で検証するときに使う。専用署名ビルドの起動、識別、CUA または本人操作、権限維持確認、後片付けを行う。
---

# Koecho の実画面検証

実画面導線は **blocked**。固定ビルド・起動・識別・停止は2026-10-02に実行済みだが、CUA の絶対パス取得が timeout し、最初の `original` → `ORIGINAL` は未実行。再ビルド・再起動後の権限維持も未確認。識別子変更で CUA が直るとは扱わない。[機能マップ](features/README.md)を使い、通った機能だけに証拠を付ける。

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

上の証明書と private key が利用可能であることが前提。使えない場合は blocked とし、ad-hoc や別証明書へ自動で切り替えない。`PRODUCT_NAME` / `PRODUCT_MODULE_NAME` の一括 override は依存 SPM target の出力を衝突させるため使わない。

**完全なデータ隔離ではない。** UserDefaults の標準 domain は別 ID になるが、`HistoryStore` は `~/Library/Application Support/com.ryotapoi.koecho/history.json` を共有する。`KoechoApp` は起動時に履歴を purge するため、Settings → General で `Enable History` を off にしても、既存履歴の読み込み・起動時の整理は止まらない。履歴のある通常ユーザーでは、専用 macOS ユーザーを使用するか、起動時に共有履歴が変更されることへの本人の了解が必要。helper の `--allow-shared-history` は了解後だけ使う。共有履歴をバックアップ復元や削除で自動操作しない。

メニューバー名 `Koecho`、Settings タイトル等は製品コードに固定されている。全 UI が Verification 表示になるとは期待しない。通常版が同時起動し、本人がメニューを区別できない場合は操作を止める。通常版を無断終了しない。クリップボード、マイク、global hotkey、貼り付け先は OS と共有する。

## Launch

repository root から helper を実行する。`RUN` は毎回異なる一つのディレクトリ名にする。ここでは `20261002-script-check` を使う。helper の process 読取・停止や保護された skill 配下への書込みで sandbox に拒否された場合は、その操作だけ escalation する。

```sh
.agents/skills/verify-koecho/scripts/session.py plan
.agents/skills/verify-koecho/scripts/session.py prepare --run 20261002-script-check
```

`prepare` 成功後だけ次へ進む。既に専用アプリが起動中なら別 run として所有せず停止する。XcodeBuildMCP `session_show_defaults` で現在の profile と設定を控える。`plan` 出力の `defaults` を `session_set_defaults` に渡し、`profile: "verify-koecho"`、`createIfNotExists: true`、`persist: false` を加える。続いて **`build_run_macos` に同じ plan の `extraArgs` と `launchArgs` を渡す**。Bash から xcodebuild は呼ばない。profile は終了時に元へ戻す。

初回 script 用 launchArgs は `-voiceInputMode off`。通常のキーボード入力・Settings・script 実行を使い、内部 setter や test hook は使わない。音声開始だけを抑止する。入力パネルからの確定操作より前に、実画面の Settings → General で `Enable History` を off にし、その状態を確認する。起動時の履歴整理はこの設定でも抑止しない。Accessibility 要求、hotkey、外部 script、ペーストも抑止しない。本人確認中はプロセスを保持する期限を決め、返信待ちを検証成功と扱わない。

成功後に:

```sh
.agents/skills/verify-koecho/scripts/session.py adopt --run 20261002-script-check
.agents/skills/verify-koecho/scripts/session.py doctor --run 20261002-script-check
```

`adopt` は起動前不在・固定実行パス・起動時刻・一件の PID を検査し、署名確認より先にその PID を証拠へ記録する。署名確認が失敗しても `cleanup` で所有 process を終了できる。MCP が表示する PID を無検証で信用しない。`doctor` は read-only で Info.plist、固定証明書、署名検証、designated requirement、所有 PID / 起動時刻を確認する。UI readiness は保証しない。操作前と意外な失敗後に使う。実画面で対象メニューまたはパネルが観測できて初めて操作可能と判断する。初期パネルは非表示。

## Drive と本人操作

最初は [custom-script](features/custom-script.md)。`tr a-z A-Z` を Settings から登録し、本文 `original` がボタン操作で `ORIGINAL` になることを確認する。ほかの機能へ先に進んでこの未確認を隠さない。

CUA の最初の呼出しはこれ一つだけ:

```js
let app = await cua.getApp('/Users/ryota/Sources/ryotapoi/Koecho/tmp/verify-koecho/DerivedData/Build/Products/Debug/Koecho.app');
```

別 checkout では plan が返す絶対パスを使う。以後は返された documentation と live AX state の名称を使う。操作後に `getAXState()` を取得し、要素番号を取り直す。固定座標・推測した要素番号は使わない。timeout した場合は同じ取得を繰り返さず、doctor → blocked 記録 → 本人操作への引継ぎ。Finder / desktop / 全体 screenshot は現在許可されていない。別 UI 技術で迂回しない。

権限が必要なら本人に対象を **Koecho Verification / com.ryotapoi.Koecho.Verification / plan の app 絶対パス** と示す。システム設定 → プライバシーとセキュリティ → アクセシビリティで対象を確認する。追加が必要な場合は + のファイル選択で Cmd+Shift+G に絶対 app path を入力する。入力監視も hotkey の必要性を確認して対象を設定する。マイクは Voice を on にして開始した際の対象アプリの要求を本人が判断する。通常版の Koecho を選ばない。許可変更は新しいアクセスを与えるため、本人の判断で行ってもらう。CUA backend 自身の権限と Koecho の権限は別物。TCC DB 読取・reset はしない。

## 再ビルド・再起動と権限維持

初回 script 成功後、許可項目・本人操作・対象 path を記録し、cleanup（build は保持）→新しい run の prepare→同一 plan で `build_run_macos`→adopt→doctor を行う。前後の証明書 SHA-1 と designated requirement、Bundle ID、path が同じことを確認する。これだけでは TCC 維持の証拠にならない。

本人または利用可能な CUA で、再許可なしに同じ script 操作と、許可が必要な hotkey / paste を実施する。Microphone を許可済みなら音声機能も再確認する。音声確認では `launchArgs` から `-voiceInputMode off` だけを外す。結果表に Accessibility / Input Monitoring / Microphone ごとに「初回設定」「再起動後の実操作」「再許可の有無」を残す。未設定・未操作の項目は未確認とする。script の成功だけで権限維持を検証済みとしない。

helper の回帰テストは repository root で `python3 -m unittest discover -s .agents/skills/verify-koecho/scripts -p 'test_*.py' -v` を実行する。

## Evidence と Cleanup

証拠は `tmp/verification/verify-koecho/<run>/`。scratch の外であり gitignored。`session.json`、doctor 出力、MCP の structured result / build log 参照、実施者、操作、観測結果、所要時間、失敗、権限設定、残存ギャップを保存する。CUA の対象 app screenshot を取得できた場合だけ保存し、本人確認は報告文と実施日時で残す。実行不能は draft / blocked と記し、build 成功を実画面検証済みとしない。

```sh
.agents/skills/verify-koecho/scripts/session.py cleanup --run 20261002-script-check
```

所有 PID が同じ実行パス・起動時刻のときだけ SIGTERM を送る。5秒で停止しない場合、または固定実行パスに未所有の process が残る場合は失敗を `session.json` に記録する。未所有 process は kill しない。残留時は scratch も保持する。権限維持の次回確認用に固定 build は保持する。最終終了時は同じ cleanup に `--remove-build` を付けて所有 scratch を削除する。証拠、専用 UserDefaults、TCC 許可、共有履歴は保持する。ユーザーの通常版や既存プロセスに触れない。元の MCP profile に戻し、証拠が残ることと N13 等の既存差分が不変なことを確認する。コミットしない。
