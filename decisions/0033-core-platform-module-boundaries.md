---
status: current
---

# 一つの SPM package で Core と Platform の依存境界を定める

## 判断

`KoechoKit` を単一のローカル Swift package とし、`KoechoCore` と `KoechoPlatform` の二つの target に分ける。依存方向は App → KoechoPlatform → KoechoCore とし、App は必要な両 module を明示的に import する。KoechoPlatform は KoechoCore を re-export しない。

KoechoCore はモデル、設定、Foundation を中心とするロジックを担い、AppKit、Carbon、CoreAudio、AVFoundation、Speech などの macOS I/O API を import しない。KoechoPlatform は OS との接続を担い、App target は SwiftUI/AppKit の画面、`NSTextView` と `NSPanel`、画面に密接な controller/service の配線を担う。

## 理由

全ソースを一つの Xcode target に置くと、純粋なモデルから OS 統合層への逆依存をコンパイル境界で検出できない。二つの package target に分けることで、Core のテストと依存方向をコード構造として保てる。一つの package なら Xcode の参照管理も増やさずに済む。

## 採らなかった案

- package を二つに分ける: 参照管理が増えるが、現在必要な境界は一つの package の target で表現できる。
- Xcode framework target を使う: 同じ依存境界に対して build 設定の管理が増える。
- Platform から Core を re-export する: App 側の Core 依存が暗黙になり、境界が読み取りにくくなる。
