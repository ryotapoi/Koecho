# 内蔵テキスト操作の設定・表示

## 設定

スクリプトは「カスタムスクリプト」と「内蔵機能」を選択して登録できる。内蔵機能の追加では、Decrease Indent (2 spaces)、Decrease Indent (4 spaces)、Increase Indent (2 spaces)、Increase Indent (4 spaces)、Block Quote の5種類から選ぶ。登録済みの種類も表示するが選択不可とし、削除後は再び選択できる。

- カスタムスクリプトは表示名、SF Symbol、コマンド、ショートカット、追加プロンプトを編集できる。
- 内蔵機能は feature と、Indent 系の場合は 2 または 4 spaces の幅、表示名、SF Symbol、共有のショートカットを編集できる。コマンド、パス、追加プロンプトは表示も編集もされない。
- Type 行には追加時に決まった Script の種別を表示し、編集画面では切り替えられない。
- 内蔵機能の同一 feature と同一幅の重複登録は拒否する。2 と 4 spaces のように設定が異なる同一 feature と、同名のカスタムスクリプトは登録できる。
- 初回登録済み flag により追加された既定の内蔵項目を削除しても自動復元しない。削除後は設定画面から再登録できる。

## 表示と実行

- 内蔵機能のラベルは Decrease Indent、Increase Indent、Block Quote とし、Indent 系には 2 spaces または 4 spaces の設定を付ける。
- 表示設定が未設定なら設定一覧では内蔵機能の既定 icon と設定込みラベルを表示する。Input Panel では icon-only button とし、Decrease Indent / Increase Indent / Block Quote にそれぞれ decrease.indent / increase.indent / text.quote を使う。設定込みラベルは tooltip と accessibility label に使う。既存保存データ、新規登録、読み込み時の自動保存でも未設定を維持する。
- 表示名か SF Symbol の有効な変更を確定すると、編集欄の両値を明示設定として保存する。以後は両画面で指定された要素だけを表示する。片方が空なら残る要素だけを表示し、空の icon は補わない。両方空、利用できない SF Symbol は保存しない。表示設定は feature や indent width、shortcut の変更と独立し、既定値と一致しても未設定には戻さない。
- Icon 設定行には現在のアイコンを示すボタンだけを置き、ボタンから popover を開く。popover は5グループ29候補を見出しと画面幅に応じて折り返すアイコンのグリッドで示し、選択中のアイコンを強調する。候補名は tooltip とアクセシビリティラベルで確認できる。
- popover の入力欄はプリセット名の部分一致検索と、候補外の SF Symbol 名の完全一致入力を兼ねる。入力名が実行中 macOS で有効な場合に限り、重複しない1件を Custom に示す。空欄では全プリセットと、選択中の候補外アイコンを示す。入力だけでは保存せず、タイルを選ぶと保存して閉じる。候補がない場合はその旨を表示する。None は表示名が非空の場合だけ選択できる。
- 内蔵機能はカスタムスクリプトと同じボタン・ショートカット実行導線を使うが、Auto-run の候補にはならない。
- カスタムスクリプトの名前、prompt icon、実行中の無効化、prompt 遷移、ショートカットの既存挙動は変わらない。

保存済みスクリプトを読み込めない場合の一覧保護と初期化は、[設定読み込み失敗時の保護](settings-load-protection.md) を正とする。
