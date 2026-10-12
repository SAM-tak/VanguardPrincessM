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

## 試作（英語）

- 0241「ゆい」→ "Yui"、0242「and えこ」→ "and Eko"（"and" 9px、名前 13px）。フォントは Playfair Display BoldItalic（ネームプレートはイタリック。ユーザー指定。OFL、`data/Playfair_Display/`）、白に紺 (0.2, 0.12, 0.62) の1px縁
- HUD の名前表示: 0241/0270/291〜299 がキャラ名（レイアウト3・8）、242/251/248/250/259/252 が「and サポート名」（レイアウト6・10）。システムパレット固定のパレット画像を含む
- VS を自動で進めて HUD を撮影し、1P「Yui and Eko」、2P「はるか and Eko」（0242 は両側共通）を確認
- `tests/locale-image.lh`（`-Test locale-image`）: `locale.txt` を一時的に en にし、Canvas の大きさ・オフセット・rgba 扱い・未登録画像の不変を確認
- 既定（ja）で match-intro・system-object-position・story-continue・victory-preload・selective-preload PASS

## 言語の決め方（未実装・方針）

`locale.txt` は試作用の仮の切り替え。本番は、オプション画面などの設定の仕組み（キーコンフィグと共通）を決めてから実装する（ユーザー判断、2026-10-12）。

- 既定は OS のロケール: `love.system.getPreferredLocales()`（lhat-love で公開済み）を先頭から見て、上書き表を持つ言語に当たれば採用（`en-US` → `en`）。無ければ `ja`
- プレイヤーが設定で言語を選べるようにし、その設定を最優先にする
