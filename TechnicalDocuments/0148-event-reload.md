# F8 の love.event.reload

F8 は `love.event.reload()` で変更ユニットを検査し、受理されたら次のフレームで main.lh からやり直す。拒否時は Error.message を出力し、ゲーム状態を変更しない。キーリピートでは呼ばない。

変更のないユニットは状態を保つため、受理後に pending をキャンセルし resource.stop() で task pool と待ち行列を整理する。戦闘資源・シーン arena（system を含む）を解放し、locale.reload() で設定とロケール表の再読み込みを準備する。initialized を false、scene を nil にして、境目までの更新・描画が解放済み資源を参照しないようにする。

従来の titleAfterBoot と手動タイトル復帰を廃止。ウィンドウを保ったまま通常の起動シーケンスを実行する。conf の変更は対象外。配布 VM ではコードの再検査なしで main からやり直す（エンジン側仕様）。

検証: main.lh のコンパイル（22 units）、tools/test-async.ps1 -Test locale-reload（PASS）。locale-reload は変更されない tests/reload-state.lh に進捗と設定の退避を保持し、テスト入口自体の再実行をまたいで検証する。

async-flow と practice-mode も tests/reload-state.lh に F8 要求時の進捗・開始時刻を退避し、入口の load 回数を数える。タイトル到達後に load の再実行を確認するので、単なる手動復帰では合格しない。タイムアウトの開始時刻はリロードで更新しない。

async-flow は読み込み途中・ポーズ中の2回のリロードを検証し、要求時のジョブ解放と再起動後の戦闘資源・スクリプト解放を確認する。practice-mode は再起動後のヒットボックス・練習状態・ポーズ解除を確認し、そのまま VS MODE の検証を続ける。両テストは通常起動のオープニングをスキップしてメニューへ進む。

テストの入口は vp.main を require する別ユニットなので、変更なしの vp.main 自体は状態を保つ。F8 の後始末で残る campaign・selecting・matchArena・入力・ポーズ等も解除し、再び load が呼ばれる形に対応する。

追検証: tools/test-async.ps1 -Test async-flow / practice-mode / locale-reload はすべて PASS（exit=0）。

## F8直後のtask pool再起動を防止

F8がキーイベントとしてupdate前に届くと、resource.stop()の後、同じフレームのupdateがresource.pump()を呼び、空のpoolを再起動してstartedをtrueにしていた。その後エンジンがリロード境界でpoolを停止するが、変更なしのresourceユニットにはstarted=trueが残る。新しいmainのロード要求でpoolを起動せず、std.task.start has not been calledで失敗した。

受理時にmainのreloadPendingを立て、loadで解除する。受理後のupdate・drawと、入力poll後のpumpを止め、境界までpoolを再起動しない。検査拒否時には立てない。

従来のテスト入口はvp.mainをrequireするため、mainの状態が残っており、この実際のmain再実行経路を検証できていなかった。f8-main-reloadはrunnerが本物のmain.lhを入口のbodyとして使い、load/update/drawをテストで包む。F8直後に同じフレームでupdateを再度呼び、2回のリロードと各回の非同期systemロード完了を確認する。修正前に報告と同じpanicを再現し、修正後はPASS（exit=0）。

修正後の検証: main.lhのコンパイル成功（22 units）、f8-main-reload / async-flow / practice-mode / locale-reloadすべてPASS（exit=0）。
