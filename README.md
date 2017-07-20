# yomou-tools 

[小説を読もう](http://yomou.syosetu.com) 及び [カクヨム](http://kakuyomu.jp) から指定した小説の各話を取得する。初回実行は第一話から取得し、次回以降は前回の続きからの取得を行う。現在の仕様として取得後に更新された場合は取得しない。
サーバへの負荷を避けるため、各話の取得には数秒間のSleepを入れています。

## yomou.rb

[小説を読もう](http://yomou.syosetu.com) の各話を取得するスクリプト。引数にはURLを与えて実行する。


```
% ruby yomou.rb http://ncode.syosetu.com/n4830bu
```

取得したファイルは work/[ncode]/ 以下の work/ ディレクトリに各ファイルが置かれます。

## kakuyomu.rb

[カクヨム](http://kakuyomu.jp) の各話を取得するスクリプト。引数にはURLを与えて実行する。


```
% ruby kakuyomu.rb https://kakuyomu.jp/works/1177354054882154317
```

取得したファイルは work/[数字コード]/ 以下の work/ ディレクトリに各ファイルが置かれます。

## yomou_merger.rb

指定したディレクトリ以下の各話テキストファイルを1つにまとめます。


```
% ruby yomou_merger.rb ./work/n4830bu
merging files into work/n4830bu/本好きの下剋上　～司書になるためには手段を選んでいられません～ [香月　美夜].txt
677 files merged. total 178,356 lines, 17,395 KB. updated 2017-03-12 12:18:00 +0900
```

## yomou_batch.rb

各小説の各話取得とファイルの統合をバッチ処理として行います。統合したファイルは books/ というフォルダに1小説1テキストファイルで保存します。

上記の yomou.rb 及び kakuyomu.rb に渡す各小説のURLを1行1URLの形で booklist.txt というファイルに記載します。

```
% ruby yomou_batch.rb 
```
