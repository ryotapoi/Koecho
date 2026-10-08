# Koecho

常に [開発時の規則](docs/development.md) を読み、作業全体に適用する。

## 作業ごとの入口

- 目的・非目標・守る制約: [要件](docs/requirements.md)
- 設計・責務・依存方向を変える: [decisions/](decisions/) の `status: current` の ADR
- 振る舞いを確認する: 対象のコードとテスト
- 外部スクリプトを作る・入出力を変える: [スクリプトの契約](docs/script-interface.md)
- 変更を検証する: [必須 gate](docs/verification.md)
- Xcode・build・test を操作する: [Xcode 操作](docs/xcode.md)
- 実アプリの入力・メニュー・Settings を検証する: [verify-koecho](.agents/skills/verify-koecho/SKILL.md)
- 文書・ADR・backlog の配置や内容を変える: [情報管理の原則](docs/rules/information-management.md)
- AppKit・Swift・Speech の既知の罠を調べる: [プラットフォーム観測](docs/platform-observations.md)
- 音声認識の語彙・発音モデルを再検討する: [実験記録](docs/speech-custom-vocabulary-experiments.md)
- 今後の作業・版に含める作業を確認する: [backlog](backlog/backlog.md)
- 版を切る: [リリース手順](docs/release.md)

過去の判断理由が必要な場合だけ、`status: superseded` の ADR と git 履歴を参照する。
