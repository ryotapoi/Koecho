# 内蔵テキスト操作の設定・表示

## 設定

スクリプトは「カスタムスクリプト」と「内蔵機能」を選択して登録できる。

- カスタムスクリプトは名前、コマンド、ショートカット、追加プロンプトを編集できる。
- 内蔵機能は feature と、Indent 系の場合は 2 または 4 spaces の幅、共有のショートカットだけを編集できる。名前、コマンド、パス、追加プロンプトは表示も編集もされない。
- 内蔵機能の同一 feature と同一幅の重複登録は拒否する。2 と 4 spaces のように設定が異なる同一 feature と、同名のカスタムスクリプトは登録できる。
- 初回登録済み flag により追加された既定の内蔵項目を削除しても自動復元しない。削除後は設定画面から再登録できる。

## 表示と実行

- 内蔵機能のラベルは Decrease Indent、Increase Indent、Block Quote とし、Indent 系には 2 spaces または 4 spaces の設定を付ける。
- 設定一覧では内蔵機能にそれぞれの icon とラベルを表示する。
- Input Panel の内蔵機能は icon-only button とし、Decrease Indent / Increase Indent / Block Quote にそれぞれ decrease.indent / increase.indent / text.quote を使う。設定込みラベルは tooltip と accessibility label に使う。
- 内蔵機能はカスタムスクリプトと同じボタン・ショートカット実行導線を使うが、Auto-run の候補にはならない。
- カスタムスクリプトの名前、prompt icon、実行中の無効化、prompt 遷移、ショートカットの既存挙動は変わらない。
