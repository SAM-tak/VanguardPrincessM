# 開発用フォントの配置（2026-10-13 から配布に同梱）

NotoSansMonoCJKjp-Regular.otfをassetsからdataへ移し、原作素材の抽出とは独立させる。
フォントはリポジトリで管理し、ライセンスはlicenses/NotoSansCJK-OFL.txtに置く。

main.lhのdebugTextはfused実行では直ちに戻り、フォントをロードせず、デバッグ文字を描画しない。
ソース実行では従来通り必要時にロードする。ゲーム本編の文字は原作画像を使うため影響しない。
~~package-game.ps1はこのフォントを除外する（IncludeAssets指定時も同様）。~~

2026-10-13: 除外をやめて配布物に同梱する（約16MB。ユーザー判断）。練習メニュー（0145）と日本語ロケールの説明文（0144 の ja の上書き表）が使うため、
除外していた fused 版ではこれらの日本語が描画されなかった（ユーザー報告）。package-game.ps1 の除外と check-distribution.ps1 の不合格条件を削除し、
配布物に入る `data/NotoSansMonoCJKjp-OFL.txt` にライセンス文を置いた（`licenses/` はパッケージに入らない）。
デバッグキーなど、それ以外の操作仕様は変更していない。
