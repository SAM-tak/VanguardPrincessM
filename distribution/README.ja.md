# ヴァンガードプリンセスＭ

**ヴァンガードプリンセス**を最新のOS環境でも不自由なく動作する用、格闘ゲームツクール2ndの実行ファイルではなく
独自のプログラムで動作するようにしたものです。

## 動作のさせ方

### 本家ヴァンガードプリンセスを用意

本家ヴァンガードプリンセスの画像・音声データは一切含んでいません。
なのでまず、本家の最新版の `vanpri108.exe` を入手してください。

- [ふり～む](https://www.freem.ne.jp/win/game/2302)
- [Vector](https://www.vector.co.jp/download/file/win95/game/fh655758.html)

既にプレイされてて解凍済みの 「ヴァンガードプリンセス」があるなら、そのフォルダでも構いません。

### Windowsの場合

配布物に同梱の `BuildAssets.exe` に、`vanpri108.exe` またはそれを解凍したフォルダをドラッグ＆ドロップします。

すると以下のように画像素材の抽出が始まります。

![BuildAssetsの画面](images/buildassets-console.png)

しばらく待っていると（結構時間がかかります。５分くらい）変換が終了し、Enter キーでウィンドウを閉じれます。
`assets.zip` が出来上がったら準備完了です。

![BuildAssetsの画面](images/working-directory.png)

あとは `VanguardPrincess.exe` をダブルクリックすればゲームをプレイできるはずです。

### Macの場合

配布物を解凍したフォルダ(`BuildAssets` `VanguradPrincess.command`があるフォルダ)でターミナルを開き、
次を実行します。

```sh
./BuildAssets ~/Downloads/vanpri108.exe assets.zip
```

`~/Downloads/vanpri108.exe` は、実際にダウンロードした場所に合わせて適宜変えてください。

しばらく待っていると（結構時間がかかります。５分くらい）、 `assets.zip` が出来上がるはずです。

MacOS版は署名されていないのでそのままでは実行できません。ターミナルで次のコマンドを打って実行を許可してください（フォルダ名は展開先に合わせます）。

```sh
xattr -dr com.apple.quarantine VanguardPrincess
```

その後、そのターミナルで

```sh
./VanguardPrincess.command
```

と打つか、 `VanguardPrincess.command` をダブルクリックするとゲームが始まるはずです。

> ![Note]  
> 手元にMacがないので動作の確認もできていませんし、通常のMacアプリ（*.app 形式）の形に
> 纏めることができていません。Macをお持ちの方は、修正案のPRを投げていただけると助かります。

### Linuxの場合

配布物を解凍したフォルダ(`BuildAssets` `VanguradPrincess`などがあるフォルダ)でターミナルを開き、
次を実行します。

```sh
./BuildAssets ~/Downloads/vanpri108.exe assets.zip
```

`~/Downloads/vanpri108.exe` は、実際に本家をダウンロードした場所に合わせて適宜変えてください。

しばらく待っていると（結構時間がかかります。５分くらい）、 `assets.zip` が出来上がるはずです。

その後、そのターミナルで

```sh
./VanguardPrincess
```

と打てば、ゲームが始まるはずです。
