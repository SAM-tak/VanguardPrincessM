# 外部assetsをzipアーカイブに

2026-10-10。[0128](0128-external-distribution-assets.md) の外部 `assets/` フォルダ方式は、Windowsで初回ロードが
フリーズを疑うほど長かった（Anti Malware Service が約8,500ファイルを個別にスキャンすると推測。未計測）。
素材を内蔵したFuse exe（[0110](0110-direct-asset-packaging.md)）は快適だった。

利用者の環境でexeをFuseし直す案（love.exe同梱）も検討したが、ファイル数を1つにするだけなら
zipをマウントすれば足りる。exeの作り直しが不要で、Mach-Oに連結できないmacOS（[0136](0136-unix-distribution.md)）向けの別手順もいらない。

## 構成

```text
VanguardPrincess/
  VanguardPrincess.exe
  エンジンのDLL
  assets.zip  ← BuildAssets が原作から構築
```

- `src/media.lh`: source baseを一時マウントした状態で `mount("assets.zip", "assets")` を試し、失敗したら従来の
  `assets` フォルダをマウントする。zipが優先。どちらもなければ `assets.zip is missing beside the game` で停止。
  lhat-loveの `mount` はsource base内のアーカイブを受け付ける（追加のエンジン変更なし）。
  `getInfo` は引数1つのみ（filtertype 不可）なので、存在確認はせずmountの戻り値で判定する。
- `build_assets.py`: 出力先が `.zip` なら、一時ディレクトリに構築・照合した後、ZIP_STOREDでzip化し、
  全エントリを読み戻して元ファイルとバイト比較してから公開する。生ファイルは一時ディレクトリごと削除される。
  `.zip` 以外はフォルダ出力（開発用）。
- ドラッグ＆ドロップ: 引数が source だけなら、出力先は frozen exe の隣の `assets.zip`（開発時はカレントディレクトリ）。
  配布フォルダでは `BuildAssets.exe` と `VanguardPrincess.exe` が並ぶので、ドロップ後そのままゲームを起動できる。
  D&D起動のコンソールは終了で閉じるため、引数0〜1個のfrozen実行では最後にEnter待ちを入れる（引数なしは使い方を表示）。
  利用者向けメッセージはOSの表示言語で日英を切替（Windowsは `GetUserDefaultUILanguage`、他は `LC_ALL`/`LC_MESSAGES`/`LANG`）。
- 圧縮: DDSのみDeflate（レベル9）、他はSTORED。PNGは元々圧縮済みなので展開時間を払うだけになる。
  WAVは非圧縮PCMだが、Deflateしても504個 151.4MB → 140.9MB（-7%）しか減らない。
  しかもstreamソース（BGM）はループのたびに先頭へシークし、PhysFSはDeflate済みエントリを後ろへシークできず先頭から展開し直す → STOREDのまま。
  縮めるなら形式変更（可逆のFLAC、非可逆のOGG）だが、変換処理とパスの書き換えが要るので未着手。
  当初は「DDSを読むたびにinflateさせない」ため全STOREDだった。2026-10-11 にDDSだけDeflateへ変更（下記「DDSのDeflate」）。
- Pythonの `zipfile` は非ASCII名にUTF-8フラグ（0x800）を付け、lhat-love（PhysFS）はこれを読める。
- `dist.ps1` の再ビルドは `assets` と `assets.zip` を保持。`check-distribution.ps1` は両方の混入を拒否。

## 検証

- `tools/test-external-media.ps1`: zipのみ、フォルダのみ（後方互換）、両方あり（zip優先）、なし（案内）、
  日本語パス（`えこ/probe.txt`）、素材内蔵時に外部zipが上書きしないこと。
- `tests/test_build_assets.py`: zip出力、全エントリがSTORED、上書き拒否、生ファイルが残らないこと。
- 原作 `vanpri108` から実際に構築: 8,492エントリ、うち非ASCII名7,311件すべてUTF-8フラグ付き。
  約447MB（無圧縮）、構築は約5分。
- `assets` フォルダのない配布フォルダに `assets.zip` だけを置き実ゲームを起動、40秒エラーなく動作。
  初回ロード時間の体感改善・対戦中の描画・音声は手元の実機で未確認。
- 素材なしコピーで `check-distribution.ps1` 通過。

サイズは素材内蔵exe（Optimal圧縮、約252MB）より大きい。気になるならDDSだけDeflateする選択肢がある。

## DDSのDeflate（2026-10-11）

DDS は GPU 形式の入れ物で、可逆圧縮の形式を持たない（BC系は非可逆。中身がパレット番号なので使えない）。
原作の画像は独自の LZ/RLE で圧縮されている（[0130](0130-automatic-assets-builder.md)）。L8 は 1byte/pixel の非圧縮なので、原作より大きくなる。
そこで zip のエントリ単位で DDS だけ Deflate する。

既存の STORED zip（`dist`、8,492 エントリ）を DDS だけ Deflate で詰め直して計測した:

- DDS 4,319 個: 213.1MB → 20.8MB（約 1/10）。zip 全体 446.9MB → 254.6MB（残りの大半は WAV）
- lhat-love（`lovec`、ウィンドウなし）で save directory の zip を mount し、全 DDS を `love.image.newImageData`:
  STORED 0.90 / 1.02 秒、Deflate 1.43 / 1.36 秒。全数で +0.4〜0.5 秒、1 枚あたり約 0.1ms。
  実ゲームではワーカースレッドで読む（[0028](0028-async-loading.md)）、かつキャラ単位の部分集合なので影響は小さいと判断
- `build_assets.py` の `write_archive` が `.dds` を `ZIP_DEFLATED`（レベル9）、その他を `ZIP_STORED` で書く。
  書き込み後の全エントリ読み戻し・バイト比較は従来どおり。`tests/test_build_assets.py` は圧縮方式をエントリごとに確認する

未確認: 実機での初回ロード体感、BuildAssets.exe（frozen）の再ビルドと原作からの実構築。
