# 設定ファイル settings.json と Alt+Enter のフルスクリーン

## 設定ファイル

セーブディレクトリの `settings.json`（`src/settings.lh`）。今あるキー:

- `"lang"`: ロケール（`"en"` など。[0144](0144-localized-images.md)）。プレイヤーが選んだ言語で、最優先。
  無ければ OS の優先言語（`love.system.getPreferredLocales()`、`ja_JP` などを優先順に）を上から見て、
  言語部分（`_` / `-` の前、小文字化）がゲームにある最初のもの（原作の `ja`、または `data/locale/<言語>/` があるもの）。
  どれも無ければ `en`（日本語圏以外には英語が無難）。OS から決めた言語は書き込まない（OS の言語を変えれば追従する）。
  `lang` を書くのは将来のオプション画面で言語を選んだ時
- `"fullscreen"`: 起動時にフルスクリーンにするか（Alt+Enter が書く）

キーコンフィグ等も今後ここに足す。書き戻す時は、この版が知らないキーもそのまま残す。

- **作成**: 最初の読み込み（起動時の `load` の `vp.settings.fullscreen()`）でファイルが無ければ、
  既定値 `{"fullscreen": false}` で作る（プレイヤーが編集できるように）。`lang` は書かない（OS 追従のため）。
  当初は Alt+Enter で初めて作られていた。読めない・JSON として不正なファイルは警告を1回出し、書き換えずに残す
  （以前は読めないと毎回読み直して警告を繰り返していた）
- **整形**: 書き出しは `std.json.pretty(data, 4)`（lhat に追加、メンバー1つに1行・4スペースインデント）。
  プレイヤーが編集しやすいように。`std.json.encode` は1行で書く

- **JSON にした理由**: `std.lton.parse` / `load` はテキストを L^ のフロントエンドで f^ 本体としてコンパイルして読む。
  配布用のエンジン（vmonly-shipping）はフロントエンドを持たず、事前にコンパイルした LTON しか読めない。
  ゲームの `data/*.lton` は `package-game.ps1` が事前にコンパイルするので読めるが、プレイヤーが書く設定ファイルは読めない。
  `std.json` は自前の読み手（lhat `stdlib/json.c`）を持つので VM 版でも動く
- **lhat-love への追加**: lhat-love は `std.json` を登録していなかった。`src/lh/Boot.cpp` の `registerStdlib` に
  `lhatstdlib_json_register` を足し、`scripts/regen-generated.ps1` で `Signatures.h` を再生成。
  full 版とコンパイル済み suite を VM 版（shipping）で走らせ、JSON の往復を含めて 532/532 PASS。
  リモートビルドで使うには、これを含む lhat-love のリリースへ `tools/engine-release.json` を上げる必要がある
- **保存ディレクトリの場所**: LÖVE は fused（配布ビルドの exe）なら `%APPDATA%\<identity>`、
  ソースからの実行なら `%APPDATA%\LOVE\<identity>` を使う（lhat-love `physfs/Filesystem.cpp`）。
  identity は `vanguard-princess-m`。開発時と配布版で設定ファイルは別になる

## フルスクリーン

- Alt+Enter で切り替え（`main.lh` の `keypressed` の先頭）。この Enter は Start として扱わない。
  `love.window.setFullscreen(bool)` の種類は既定の desktop（デスクトップ解像度の枠なしウィンドウ）
- 状態は `settings.json` の `"fullscreen"` に保存し、起動時（`load`）に反映
- 描画: ゲームは 1280x960 のウィンドウ（`WINDOW_W` / `WINDOW_H`）として描き、`draw` が実際のウィンドウへ
  縦横比を保って拡縮・中央寄せし、余りを黒帯で塗る。ウィンドウの大きさに依存していた所（ポーズ画像、
  読み込みのデバッグ表示、練習メニュー）はゲームのウィンドウの大きさで描くよう変更。
  練習メニューは `origin()` で変換を外していたのをやめ、同じ拡縮に乗せた

## 検証

- `tests/locale-image.lh`: `settings.json` を一時的に `{"lang": "en"}` にして読む（元の内容は戻す）
- `tests/locale-system.lh`（`-Test locale-system`）: `lang` の無い `settings.json` で、OS の優先言語から選ぶことを確認（この環境は `ja_JP, en_US` → `ja`）
- `tests/settings-create.lh`（`-Test settings-create`）: ファイルが無ければ既定値（`lang` 無し）でインデントして作られ、不正な JSON は書き換えられないことを確認（元の内容は戻す）
- 1600x900 のウィンドウでタイトルを撮影し、左右に黒帯・中央に縮小表示を確認
- 実際の Alt+Enter の切り替えは自動テストで押せない（Alt の押下状態を作れない）ため手動確認
