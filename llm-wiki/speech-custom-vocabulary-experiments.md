---
regen: none
sources:
  - https://developer.apple.com/documentation/speech/sfcustomlanguagemodeldata
  - https://developer.apple.com/documentation/speech/dictationtranscriber
  - https://developer.apple.com/documentation/speech/dictationtranscriber/contenthint/customizedlanguage%28modelconfiguration%3A%29
  - https://developer.apple.com/videos/play/wwdc2023/10101/
---

# カスタム語彙・発音の実験記録

2026-10-01、macOS 27.0（26A428）、Xcode 27.0／macOS 27 SDK、arm64・Swift 6で行った D13 試作の外部実測。語句登録 UI と固定発音モデルのコード変更は取りやめた。語句登録機能は提供していない。これは将来の技術禁止や製品仕様ではなく、同じ切り分けを繰り返さないための記録である。

**この環境の DictationTranscriber では、期待表記への改善を証明できなかった。一方、同じ音声・モデルの旧オンデバイス SFSpeechRecognizer では発音指定の陽性対照が成立した。** 公開 API の存在、生成データへの登録、認識器への指定、内部採用、最終表記の改善を分けて扱う。

## 公開仕様と試作の経路

[SFCustomLanguageModelData](https://developer.apple.com/documentation/speech/sfcustomlanguagemodeldata) は語句頻度と CustomPronunciation を export し、SFSpeechLanguageModel でモデル／語彙を prepare する。[DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber) は AnalysisContext.contextualStrings による語句の bias と、[customizedLanguage(modelConfiguration:)](https://developer.apple.com/documentation/speech/dictationtranscriber/contenthint/customizedlanguage%28modelconfiguration%3A%29) によるカスタム語彙を公開している。

macOS 27 SDK の Speech.framework/Headers/SFSpeechLanguageModel.h:16 は同じ Configuration を旧 request の customizedLanguageModel と新 ContentHint に渡せると明記する。従って旧 API 専用とはいえない。[WWDC2023/10101](https://developer.apple.com/videos/play/wwdc2023/10101/) の旧 API customization はオンデバイス認識を明示する。公開機能があることは、全設定・実行経路で同じ結果になる保証ではない。

試作ではユーザー語句の snapshot を .general context に渡し、日本語限定の固定モデルを初回・内部 restart の transcriber に指定した。認識後の強制置換は追加しなかった。実アプリの info log に prepared／applied／listening と stop は記録されたが、これだけで内部の発音採用を証明したとは扱わない。

## 固定4語と音声

CustomPronunciation.phonemes の配列1要素は、下表の**完全な発音列**。各表記単独の PhraseCount は10、各短文は20。Configuration.weight は未指定。gitignore の読みはユーザー指定であり、慣用読みに訂正していない。

| 表記 | 指定読み | phonemes | count 20 の短文 |
| --- | --- | --- | --- |
| Koecho | こえこ | k o e k o | Koechoを開きます |
| mdhop | えむでぃーほっぷ | e m M d_j i i h o p p M | mdhopを使います |
| クロコ | くろこ | k M 4 o k o | クロコを呼びます |
| gitignore | ぎっといごのあ | g i t t o i g o n o a | gitignoreを編集します |

supportedPhonemes の日本語一覧に使用記号と d_j／i i／p p／t t の表現があることを確認した。training.bin は ZIPで、asset_info.json の locale は ja_JP。custom-prons の PLS XML（alphabet=xsampa）に4表記・4発音列、phrase-count に各10／20が正確に保存されていた。compiled custom-vocab にも4表記の UTF-8文字列が存在した。ただし発音列はそのバイナリから公開形式では読み取れず、**文字列の存在は認識中の発音採用の証明ではない**。

全ファイル比較に同じ保存済み音声を使用した。

```sh
say -v Kyoko -r 150 -o readings.aiff 'こえこを開きます。えむでぃーほっぷを使います。くろこを呼びます。ぎっといごのあを編集します。'
```

AIFC、1ch、22050 Hz、16-bit big-endian PCM、8.027937秒。音声 SHA-256 は `bf332b093e5603f9455e4ca876424d6b6854a668098837e3c4751b19fc9f862c`。別OS・voice版で生成し直した音声が同じバイト列になる保証はない。requested locale は ja-JP、新 API の selectedLocales は ja_JP。ファイル probe は実マイクの確認とは別証拠である。

## 最初の3条件比較

progressiveLongDictation＋punctuation＋frequentFinalization、置換なし。base／context／customized をまず同一プロセスで各1回、次に各条件を別プロセスで1回ずつ実行した。

| 条件 | contextualStrings | 固定モデル | 別プロセスの生の最終結果 |
| --- | --- | --- | --- |
| base | 空 | なし | ココ開きます。MDホップを使います。黒子を呼びます。ぎっとり、このを編集します。 |
| context | 4表記 | なし | ココ開きます。MDホップを使います。黒子を呼びます。ぎっとり、このを編集します。 |
| customized | 同じ4表記 | あり | コエコ開きます。MDホップを使います黒子を呼びます。ぎっとりこのを編集します。 |

同一プロセスの3条件は全て base と同じ結果だった。別プロセスの customized では読み相当の表記と句読点が変わったが、指定4表記への改善は確認できなかった。export／prepare と解析は成功。AssetInventory の表示は全条件 supported であり、installed と報告されたとは扱わない。

## 発音有無の対照と API 経路差

造語 Zavuneko と「Zavunekoを開きます」を両モデルに各 count 1000で登録し、Configuration.weight は両方1.0、context は空に固定した。唯一の認識上の差は `CustomPronunciation(grapheme: "Zavuneko", phonemes: ["k o e k o"])` の有無。識別子・出力先を分離し、各条件1回の新 API 比較ではどちらも最終全文が上記 base と同じで、volatile／final に Zavuneko はなかった。生成語彙のサイズ・hash は異なり、同一ファイルを誤って比較した状態ではない。

| 切り分け | 回数・設定 | 結果 |
| --- | --- | --- |
| 新 API の全別候補 | 固定4語／Zavuneko発音なし／あり、各1回。同一音声・context空。alternativeTranscriptions、transcriptionConfidence、audioTimeRangeを追加 | 各31 volatile／4区間final、最大8候補。全35本文・候補列が同じ。登録4表記と Zavuneko は全候補で0 |
| 旧オンデバイス API | 同じ3モデルを許可済み一時bundleで順次、各1回 | 固定4語は Koecho／クロコが最良finalに出た。mdhop／gitignore は全候補でも未到達。Zavuneko は発音ありだけ partial／final に出た |
| 許可済みbundleの新 API | 旧 API と同じbundle・音声・既存モデル。発音なし／あり × frequentFinalizationあり／なしの4条件、各1回 | 全条件31 volatile／4 final、最大8候補。本文・候補列は同じ、Zavuneko は全候補で0 |

新 API の冒頭 final 候補は「ココ、後行、ここを、ココを、後、声行を、コエコ、後行を」。読み相当の「コエコ」は発音なし対照にも同じ位置で存在し、カスタム発音の効果を示す証拠にはならない。一部の音声 range／時刻属性は異なるため、raw JSON全体が同一だったとはいわない。

旧 API は requiresOnDeviceRecognition=true、supportsOnDeviceRecognition=true、taskHint=dictation、addsPunctuation=true、shouldReportPartialResults=true、contextualStrings=[]。request.customizedLanguageModel に同じ model／vocabulary URL・weight を指定し、getterでも保持を確認した。固定4語の最良 request-final は「Koechoを開きます。MDホップを使いますクロコを呼びます。ぎっとり、このを編集します。」。partial／final は固定4語32／1、発音なし29／1、発音あり29／1だった。

旧 API の final は request 全体、新 API は区間単位で、件数・確定境界は同一視できない。旧 taskHint と新 preset に完全対応する設定もない。許可済み新 API の比較で単なる認識未許可や frequentFinalization 単独では差を説明できなくなったが、残る設定・実装・環境差は未特定である。

## 最後の preset／直接初期化比較

同じ許可済み AppKit accessory bundle（NSSpeechRecognitionUsageDescriptionあり、マイク不使用）を1回起動し、同一プロセス・同一 Configuration インスタンスで2条件を各1回実行した。音声認識許可は authorized。録音・モデル計10ファイルの前後hashは不変で、モデル再生成はしていない。

使用したのは前節の Zavuneko 発音ありモデル、weight 1.0、context空。preset の設定は次のとおり。progressiveLongDictation 由来の volatileResults も含む。

```swift
var p = DictationTranscriber.Preset.progressiveLongDictation
p.contentHints.insert(.customizedLanguage(modelConfiguration: config))
p.transcriptionOptions.insert(.punctuation)
p.reportingOptions.insert(.frequentFinalization)
p.reportingOptions.insert(.alternativeTranscriptions)
p.attributeOptions.insert(.transcriptionConfidence)
p.attributeOptions.insert(.audioTimeRange)

// A
let a = DictationTranscriber(locale: Locale(identifier: "ja-JP"), preset: p)
// B: A の完了後、同じ config を含む4集合をそのまま渡す
let b = DictationTranscriber(
  locale: Locale(identifier: "ja-JP"), contentHints: p.contentHints,
  transcriptionOptions: p.transcriptionOptions,
  reportingOptions: p.reportingOptions, attributeOptions: p.attributeOptions)
```

各条件で新しい SpeechAnalyzer と空 AnalysisContext を作り、AssetInputSequenceProvider で同じ音声を入力した。results を並行消費し、analyzeSequence の後に finalizeAndFinishThroughEndOfInput()、結果列の終了まで待つ。条件別45秒timeout、実行時間1.52／0.78秒。直接引数から再構築した Preset の等価性 true と、同じ Configuration の ObjectIdentifier をログ確認した。

両条件は31 volatile／4 final、最大8候補、本文・候補列が一致。最終全文は最初の base と同じで、Zavuneko は未確定・確定・全別候補で0だった。直接初期化に変更しても陽性は得られず、ここで追加探索を終了した。

再現用モデルを初めて作る場合は、任意の実験用ディレクトリで ja-JP の SFCustomLanguageModelData に前節の count 1000の2語句と発音を insert し、exportする。Configuration は compiled languageModel／vocabulary の両URLと weight 1.0、prepareCustomLanguageModel の ignoresCache=true を使う。発音なし対照は insert(term:) だけ省き、別identifier・生成先で作る。最後の比較ではこの既存モデルを再利用した。元の一時ディレクトリや試作ソースを必要としない。

入力 options の同値と hint 指定は確認できるが、消費後のモデルを読み戻す公開getterは確認できない。初期化経路の比較は内部モデル採用の証明ではない。

## ユーザー実発話と限界

試作 app の実マイクでユーザーが報告した結果は次のとおり。baseline認識・生録音・Speech raw final は揃っていない。

| 回 | ユーザーが報告した画面の結果 |
| --- | --- |
| 初回 | 声コを開きます／MDホップを使います／クロコちゃんを呼びます／ぎっと囲碁ノアを編集します |
| 再試行 | 声行を開きます。／MDホップを使います。／黒コを呼びます。／ぎっと囲碁ノアを編集します。 |
| 語句一覧を空にした後 | 声子を開きます。／MDホップを使います。／クロコを呼びます。／ゲット囲碁ノアを編集します |

クロコが現れた回はあるが、他3語は期待表記と一致せず、固定モデルによる改善を証明しない。「Koechoが一瞬表示された後、グレーから通常色になる時に変わった気がする」という観察もあった。保存済み2置換ルールを実 ReplacementEngine に渡した17入力は一致0・変更なしで、この2ルールによる表記変更は否定できた。privateなルール本文は残さない。

通常final挿入は Speech の文字列を使い、局所重複処理は文字削除のみであるため、volatile→final の認識候補改訂が最有力説明。ただし当該 raw final がないので取得済みの事実や確定原因とはしない。

## 結論と記録の使い方

旧 API の造語対照は、同じ生成済み発音モデルがこの音声で効く正の証拠である。新 API の陰性は登録失敗、内部候補の脱落、Apple側の不具合、新 API 一般非対応のいずれとも断定できない。単一 TTS・各条件少数回、確定境界や認識設定の差が残る。期待表記が得られない機能を有効として提供せず、試作は取りやめた。

将来再検討する際は、公開仕様と観測を分け、同じ音声・モデル・locale・context・weight・報告設定で比較し、未確定／区間final／request-final／全別候補を混同しない。この記録は精度保証や製品の旧 API への移行判断ではない。一般的な Speech/Audio の入口は [Speech / Audio](speech-audio.md)、macOS 26時代の注意点は [SpeechAnalyzer 外部知見](speechanalyzer-external-notes.md)。
