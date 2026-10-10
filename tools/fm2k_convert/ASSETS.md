# 原作から assets を構築する

配布版に同梱の `BuildAssets`（Windowsでは `BuildAssets.exe`）を使用します。
Pythonのインストールは不要です。ゲームと同じフォルダに素材をまとめた `assets.zip` を作成します。

Windowsでは、原作の `vanpri108.exe` を `BuildAssets.exe` にドラッグ＆ドロップします。
数分後に「8492 個の素材を確認して作成しました」と表示されれば完了です。Enterキーで画面を閉じてください。
（メッセージはOSの表示言語が日本語なら日本語、それ以外は英語で表示されます。）
`BuildAssets.exe` と同じフォルダ（ゲームの隣）に `assets.zip` ができます。
手動解凍は不要です。既に解凍してある場合は、原作のフォルダをドロップしても構いません。

macOS/Linuxでは配布フォルダでターミナルを開き、次を実行します。

```sh
./BuildAssets ~/Downloads/vanpri108.exe
```

コマンドで実行する場合、2つ目の引数で出力先を指定できます（省略時は `BuildAssets` の隣の `assets.zip`）。
`.7z` も指定できます。フォルダは原作 `.kgt` が一つだけ含まれるものを指定してください。

完了後はゲームを起動できます。Windowsは `VanguardPrincess.exe`、Linuxは `VanguardPrincess`、
macOSは `VanguardPrincess.command` を実行します。macOS版はゲーム本体
`VanguardPrincess.love` とエンジン `lhat-love.app` を同じフォルダに置いたまま使ってください。

macOS版は公証していません。ダウンロードした配布フォルダは、初回に次を実行して
隔離属性を外してください（フォルダ名は展開先に合わせます）。

```sh
xattr -dr com.apple.quarantine VanguardPrincess
```

処理は原作exeを実行せず、画像・音声だけを取り出します。
配布された技定義やパレットデータは変更しません。Windows用の原作exe/DLLは解凍対象外です。
7-Zipコマンド、Wine、.NETは不要です。

既存の assets.zip は上書きしません。作り直す場合は、assets.zip を削除するか名前を変えてから
もう一度ドロップしてください。失敗時は不完全な assets.zip を作りません。
構築途中のファイルは一時フォルダに作り、完了後に削除します。

以前の版で作った `assets` フォルダも引き続き読めますが、`assets.zip` があればそちらを優先します。
Windowsではフォルダのままだとウイルス対策のスキャンで初回の読込みが非常に遅くなるため、
`assets.zip` を作り直し、`assets` フォルダは削除してください。

素材一覧はexeに内蔵されています。ゲームと同じ配布版のツールを使ってください。原作にない素材が必要な場合や
異なる原作を指定した場合は、不足するファイル名を表示して終了します。

## 開発リポジトリから使う場合

Python 3.10以降が必要です。macOS/Linuxでは `python3` を使用し、必要に応じて
仮想環境へ依存ライブラリをインストールしてください。

```sh
python -m pip install -r tools/fm2k_convert/requirements.txt
python tools/fm2k_convert/build_assets.py vanpri108.exe build/assets.zip
```

出力先が `.zip` で終わらない場合はフォルダとして出力します（開発用）。

素材配置を変更した開発者は、配布前に照合用一覧を更新します。この一覧には素材の内容を
含めず、内容のハッシュと配置先だけを記録します。

```sh
python tools/fm2k_convert/build_assets.py assets tools/fm2k_convert/assets-recipe.json --write-recipe
```
