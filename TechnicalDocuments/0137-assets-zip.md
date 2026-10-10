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
- 無圧縮にした理由: DDS L8 を読むたびにinflateさせない。PNG・音声は元々圧縮済み。
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
