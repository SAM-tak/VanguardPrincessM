# 自動テストの戦闘入力を押下状態で与える

2026-10-11。`story-flow`・`async-flow`・`combat-flow` が失敗していた（ユーザー指摘: 自動プレイでゆいが行動しない）。

## 原因

- `f458b60`（[0090](0090-command-button-edges.md)）で、戦闘の入力はフレームごとの押下状態（`vp.input.isDown` / `heldButtons`）から
  ボタンの押し始めを判定する方式になり、`keypressed` 由来の `pressed` を戦闘に渡す引数が削除された。
- テストは `vp.main.keypressed` でキーイベントを送るだけで、押下状態を作れない。戦闘には何も届かず、攻撃が出なかった。
  [0124](0124-native-cpu-scheduler.md) にも story-flow がこの理由で失敗したまま、と記録がある。
- `combat-flow` の「CPUがヒットストップ・ガード硬直中もガードを保つ」確認は、0124で撤去した独自のランダムガードを前提にした古い期待値。

実際のキーボード・ゲームパッドでは押下状態が取れるので、ゲーム本体の不具合ではない。

## 対処

- `src/input.lh` に `tap(key)` を追加。`poll` 3回分（描画3回分）押下中として扱い、`isDown` が真を返す。実プレイでは呼ばれない。
- テストの戦闘中の攻撃キーを `vp.input.tap` に変更（async-flow の 1P `a`＝D・2P `l`、story-flow の 1P `z`）。
  ポーズの Escape / Return、デバッグキー（F2 等）はイベントで扱うキーなので `keypressed` のまま。
  メニューの一部も `isDown` を読むため、`press` 全体は押下状態にしない。
- `combat-flow` から撤去済みCPUガードの確認を削除。

## 検証

`story-flow`（CPU戦→勝利→次戦）、`async-flow`（2P攻撃・Dサポート攻撃を含む）、`combat-flow` がPASS。
その他の `tools/test-async.ps1` のテスト（memory-soak を除く）も実行し、`selective-preload` 以外はPASS。
`selective-preload` は変更前のHEADでも同じ箇所で失敗する別件（未選択サポートのかなえの画像が読み込まれる）。
