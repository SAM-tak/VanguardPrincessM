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
- 複数行: `lines = { 行, 行 }`（各行は `text` か `runs`）。行ごとに揃え・縮小し、`leading` で行間を足す。ブロック全体を `valign` で置く
- 折り返し: `wrap = true^` で各行を段落として単語間で改行（改行した行末の空白は落とす）。ランはフォント・色を保つ
- ランごとのフォント: ラン内の `font`（強調の Bold など）
- 塗りの濃さ: `weight`（既定1）。小さい字のダッシュ・引用符など細い線は半透明の画素になり、縁取りシェーダーが塗りと縁の色を透明度で混ぜるため暗く潰れる。2 で塗りを濃くする
- 上書き表の読み込みに失敗したら理由を出力する（黙って全件無効になるため。`wrap = true`（`true^` でない）で実際に起きた）
- 未対応: ランごとの塗り色（現状は先頭ランの色）

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

## 英語: ロード画面のネームプレート（全17枚）

試合前ロード画面上部の「姓名 and サポート」（システム #119 プレイヤーネーム、#120 サポートネーム）。表記はユーザー指定。

- キャラ名（1行、名 22px＋姓 13px）: 203 Haruka Kutuna、204 Lilith、205 Luna Himeki、208 Kurumi Mirumati、209 Saki Mitonoya、210 Kaede Hioh、211 Eri Hasumi、214 Yui Kutuna、215 Ayane Ikuse、216 Natalia Glinka、235 Hilda Rize（2P のみ）
- サポート名（2行、"and" 13px／名前 22px）: 198 Eko、234 Sierra、199 Juliet、200 Kanae、201 Kaya&Maya（2P のみ）、202 Hilda Rize
- 縁取りは原画像に合わせて 2px（HUD は 1px）。フォントは HUD と同じ Playfair Display BoldItalic
- 配置: 原作はキャラ名を基準 (21, -4)／(500, -4) から I ブロックで左寄せ、サポート名を中心 x≈65／545 付近で中央寄せ
  - キャラ名は幅140（216 は 160）の Canvas に左寄せし、オフセットで左端を 1P の基準 x=21 に揃える（216 の 2P 側は I ブロックで 20px 左）。2P は右端 640 に収まる幅。最長の 208 は幅146で6px 左へ（縮小を避けるため）
  - 上端は y=13 に揃え、下揃えで組む
  - サポート名は幅180の Canvas に中央揃えし、原画像の中心に合わせる。"and" の位置を原作に合わせ、行間0・上へ6px
- 確認: 同じ場面を ja と en で撮影して位置を比較。全17枚を #119／#120 の座標で並べて、縮小・重なりが無いことを確認

## 英語: キャラクターセレクトのネームプレート（全16枚）

セレクト画面の名前はシステムの素材ではなく、キャラセレのデモ自身の画像（ロード画面の約1.3倍、`assets/demos/キャラセレ/images/`）。
レイヤー 27・28（キャラ名）、23・24（"and"）、25・26（サポート名）が、カーソル位置に応じて画像を差し替える。

- キャラ名（名 29px＋姓 17px）: 40 Yui Kutuna、45 Haruka Kutuna、46 Lilith、47 Luna Himeki、48 Kurumi Mirumati、49 Saki Mitonoya、50 Kaede Hioh、51 Eri Hasumi、52 Natalia Glinka、53 Ayane Ikuse（ヒルダは選べないので無し）
- "and"（42、独立した1枚、17px）
- サポート名（29px）: 43 Eko、54 Sierra、55 Juliet、56 Kanae、57 Hilda Rize（カーヤ＆マーヤは無し）
- 配置: 同じ画像を 1P／2P で別の I ブロック x から描き、両側の差も画像ごとに違うため、画像ごとのオフセット1つでは両側を同時に揃えられない
  - 文字の中心を原画像の中心に合わせ（幅200の Canvas に中央揃え）、両側とも原作と同じ場所を中心にする
  - 下端を揃え、ja／en の同じ場面を撮影して文字の高さを原作に合わせた
  - 最長の 48 は 1P 側で左端が切れたため6px 右へ
  - 原画像の「リリス」（短く右寄り）、「じゅりえっと」（長く中心が右）に合わせた結果、Lilith と "and Juliet" は他より内側に寄る
- 確認: 全16枚をレイヤーの座標で両側に並べて撮影

## 英語: タイトルデモの字幕（11枚）

`assets/demos/タイトル/images/0006〜0016`。タイトルデモ #4 が画面下部（I ブロック y 409〜414）に800フレームずつ出す（下から現れて上へ流れつつフェード）。
英文はユーザー作成（日本語版から文の前後を少し入れ替えている）。

- Montserrat Regular 12px（OFL、`data/montserrat/`）、白に黒1px の縁、`weight = 2`。0016 の "Vanguard Princesses" は Montserrat Bold のラン
- 画面幅の Canvas（640×64）に中央揃え、上端 y=408、行間4。段落ごとの行で、長ければ折り返す（12px では最長 624px で全行1行に収まる。13px だと折り返しが出る）
- 1〜3行（原画像は1〜2行）。3行でも y≈461 で画面内
- 確認: 11枚をデモの座標で描いて撮影、実際のオープニングでも撮影

## 言語の決め方（未実装・方針）

`locale.txt` は試作用の仮の切り替え。本番は、オプション画面などの設定の仕組み（キーコンフィグと共通）を決めてから実装する（ユーザー判断、2026-10-12）。

- 既定は OS のロケール: `love.system.getPreferredLocales()`（lhat-love で公開済み）を先頭から見て、上書き表を持つ言語に当たれば採用（`en-US` → `en`）。無ければ `ja`
- プレイヤーが設定で言語を選べるようにし、その設定を最優先にする
