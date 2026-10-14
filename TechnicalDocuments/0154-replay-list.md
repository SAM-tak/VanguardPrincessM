# WATCH REPLAY とリプレイ一覧

2026-10-15。ロールバック型ネットコードの前段として、リプレイ再生を先に完備する方針（ユーザー指定）。
その入口として、モードメニューの7つ目の項目 WATCH REPLAY と、保存されたリプレイの一覧を用意した。
記録・再生は [0155](0155-replay.md)。

## モードメニュー

- 項目は STORY / VS / PRACTICE / SURVIVAL / ONLINE VS / LAN VS / WATCH REPLAY（`src/title.lh` の `ITEM_Y`、y=70 から 22 間隔）
- SURVIVAL / ONLINE VS / LAN VS は項目だけ。説明文は「準備中」／「Under Construction」、決定しても何もしない
  （ONLINE VS は EOS 前提、LAN VS は同じネットワーク内のみの予定）
- 説明文は項目ごとの表 `CAPTIONS`（`""` は #107 自身の説明）。ラベル・説明文は両ロケールの `images.lton`

## リプレイ一覧（`src/replaylist.lh`）

- WATCH REPLAY で決定すると、画面遷移せずメニューの上に一覧を開く。練習メニュー（[0145](0145-practice-mode.md)）と同じ簡素な枠
- 中身はセーブディレクトリの `replays/` のファイル（ディレクトリは除く）。名前の降順（日時の名前なら新しい順）。
  開くたびに読み直し、`replays/` が無ければ作る（プレイヤーが場所を見つけられるように）。
  fused なら `%APPDATA%\vanguard-princess\replays`、ソース実行なら `%APPDATA%\LOVE\vanguard-princess\replays`（[0147](0147-settings-and-fullscreen.md)）
- 上下で選択（10行を超えたらスクロール）、A / C / E / F で選んだリプレイを再生（[0155](0155-replay.md)。読めないファイルなら一覧のまま）、B / D または ESC で閉じる。
  開いている間はメニューのカーソルを動かさない。ESC は一覧を閉じるだけで、閉じた後の ESC は従来どおりメニューを離れる
- 0件なら「リプレイがありません」／「No replays」

## 検証

- `tests/replay-list.lh`（`-Test replay-list`）: `replays/` にテスト用の2ファイルを置き（終了時にその2つだけ消す）、
  メニューで上（STORY から折り返して WATCH REPLAY）→ 決定で一覧が開き新しい順、下で2行目、リプレイでないファイルに A で閉じない、
  B・D・ESC で閉じる、その後の ESC でメニューを離れることを確認
