# 文字画像のローカライズ（フォント描画への置き換え）

2026-10-12。英語化（将来は多言語化）に向け、日本語の文言を持つ画像を、ロケールごとにフォント描画の文字へ置き換える。
原作のロケール（ja）では何も置き換えない。

## 方式

画像は「パス → テクスチャ」の1か所で作られる（`resource` の読み込み要求、`arena.texture` のフォールバック）。
置き換え対象のパスでは、ファイルを読まずにメインスレッドで Canvas に文字を描き、元のパスのまま arena に登録する。
描画側（I ブロック、ブレンド、COLOR の色加算、HUD の `drawPart`、ステージ）は変更不要。

- `src/locale.lh`（`vp.locale`）
  - ロケール: セーブディレクトリ（またはゲーム側）の `locale.txt` の1行目。無ければ `ja`。L^ からはコマンドライン引数・環境変数が取れないため
  - 上書き表: `data/locale/<locale>/images.lton`。キーは実ファイルのパス（共有プールはハッシュ名なので、複数キャラの同一画像も1件）
  - `render(path)`: 文字を白で Canvas に描き、後処理シェーダーで塗り色と縁取り（正方形＝ピクセルアートの縁）を付ける。読み込み時の1回のみ
- `src/sprite.lh`（Sheet）: 置き換えた画像は rgba 扱い（`isIndexed` が偽。パレット画像の 0242 など）。`draw` / `drawPart` で項目の `offset` を加算
- `src/resource.lh`、`src/arena.lh`: 上の置き換えの入口

## 上書き表の項目

- `size = { w, h }`: Canvas の大きさ（原画像と違ってよい）
- `rect = { x, y, w, h }`: 文字を組む枠（既定は Canvas 全体）。`align` left/center/right、`valign` top/middle/bottom。幅を超えたら縮小
- `offset = { x, y }`: 描画位置への加算。描画は左上（HUD）または下端中央（`Sheet.draw`）基準なので、大きさを変えたときの寄せに使う
- 文字: `text` か `runs = { { text, fontSize, color }, ... }`（1行に並べ、下端揃え。ベースライン取得 API が binding に無いため）
- 既定値: `font`（ファイル。無ければ LÖVE 既定）、`fontSize`、`color`、`outline = { color, width }`（width ≤ 4）
- 未対応: ランごとの塗り色（現状は先頭ランの色）、複数行

## 検討して採らなかったもの

- LÖVE の coloredtext: 色の区間のみで大きさの混在不可。lhat-love の `print` は文字列のみ公開
- SDF: エンジン（FreeType `FT_RENDER_MODE_SDF`）にはあるが binding の `newFont` が設定表を受けない。固定サイズで1回描くだけなので利点が薄い
- 8方向ずらし描画の縁取り: 後処理シェーダーで同等以上（太さ指定可）

## 英語: HUD のネームプレート（全17枚）

- キャラ名（レイアウト3・8、1P/2P で同じ画像）: 241 Yui、270 Haruka、291 Lilith、292 Luna、293 Kurumi、294 Saki、295 Kaede、296 Eri、297 Natalia、298 Ayane、299 Hilda（2P のみ）
- サポート名（レイアウト6・10）: 242 Eko、251 Sierra、248 Juliet、250 Kanae、259 Hilda、252 Kaya & Maya（2P のみ、原画像は x=479）。"and" 9px＋名前 13px
- フォントは Playfair Display BoldItalic（ネームプレートはイタリック。ユーザー指定。OFL、`data/Playfair_Display/`）、白に紺 (0.2, 0.12, 0.62) の1px縁
- 配置: 原作はキャラ名を右揃え（右端 1P x≈118、2P x≈490）、サポート名を左揃え（x=120 / 491）で並べている
  - キャラ名は幅60の Canvas に右揃え（右3px はイタリックのはみ出し用）。原画像ではなく列の右端 x=118 に合わせる（299 は原画像の右端が x=480 で他より10px左のため）。2P は画像共用のため ±2px
  - サポート名は幅100（252 は 130。100 では縮小されて線が細った）の Canvas に左揃え。252 は x=491 に寄せる
  - 原画像の I ブロックの y が 23〜26 とまちまちなので、オフセットで上端を揃える。y=24 では原画像（文字 y 26〜37）より文字の中心が約2px 低く見えたため（ユーザー指摘）、y=22
- 英語表記は Claude の判断（公式英語版の表記と照合していない）
- 確認: 全17枚を HUD と同じ座標で描く一時プローブで撮影。VS の実画面でも 1P「Yui and Eko」、2P「はるか and Eko」（この時点では 270 未登録）を確認
- `tests/locale-image.lh`（`-Test locale-image`）: `locale.txt` を一時的に en にし、Canvas の大きさ・オフセット・rgba 扱い・未登録画像の不変を確認
- 既定（ja）で match-intro・system-object-position・story-continue・victory-preload・selective-preload PASS

## 言語の決め方（未実装・方針）

`locale.txt` は試作用の仮の切り替え。本番は、オプション画面などの設定の仕組み（キーコンフィグと共通）を決めてから実装する（ユーザー判断、2026-10-12）。

- 既定は OS のロケール: `love.system.getPreferredLocales()`（lhat-love で公開済み）を先頭から見て、上書き表を持つ言語に当たれば採用（`en-US` → `en`）。無ければ `ja`
- プレイヤーが設定で言語を選べるようにし、その設定を最優先にする
