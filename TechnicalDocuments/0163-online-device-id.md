# Online VSのアカウント不要接続（Device ID）

認証方法は維持している。ロビー構成とbucketは後に [0164](0164-persistent-online-rooms.md) の常設ルーム方式へ変更した。

2026-10-15。Epicアカウント方式を残し、`loginDevice("Player")` を使う接続方法を追加した。Online VSを開くと「アカウントなしで接続」「Epic アカウントで接続」「戻る」を表示する。最初の項目がDevice ID方式。接続方法を決めるまでは認証を開始しない。ログイン中のBackとエラー画面からは接続方法の選択へ戻る。

## ロビーの共通化

認証方法にかかわらず、`eosconfig.lton` の同じProduct / Sandbox / Deployment、同じbucket `vanguard-m-0162-v2`、同じsocket `vanguard-v2` を使用する。EpicとDevice IDで部屋を分割しない。両者はEOS ConnectのProduct User IDを使って同じロビー・P2Pへ参加する。別のゲームや互換性のないバージョンはbucketで区別する。

検索では最大100件を取得し、所有者が存在し、定員2人・空き1人の部屋を最大8件表示する。空になった古い部屋や満員の部屋を表示しない。EOSの新規ロビーは検索への反映に数秒かかるため、検索を3秒ごとに更新する。

## 認証と配置

- Device IDはプレイヤーのEpic／Steamアカウントやログイン画面を必要としない。SDKがOSユーザーのローカル認証情報を管理する。ハードウェアのシリアル番号をゲームが取得する実装ではない。
- 開発者のEOS製品設定と、Connect / Lobby / P2Pを許可したクライアントポリシーは必要。
- Device ID方式ではEpicのAccount Portalを使わないため、そのためのBootstrapper起動やEOSサービス導入は不要。EOS拡張とSDKランタイムは引き続き必要。
- 固定の表示名 `Player` は本人識別に使わない。送受信相手はEOSのProduct User IDで識別する。
- 同じPC・OSユーザーで起動した2プロセスは同じDevice IDに対応しうる。実際の2人対戦の検証には別PCを使う。

EOS拡張 `C:/Users/Owner/source/repos/eos-lhat` も変更した。従来の `loginDevice` は新しいClientでしか呼べなかったが、Device認証済みのClientではConnect認証を再実行できるようにした。ゲーム側は `authExpired` 時に、選択した方式で更新する。Device IDの再作成やロビー退出は行わない。別方式の認証済みClientからDevice認証への切り替えと、認証処理中の二重呼び出しは拒否する。ローカルDLL・模擬DLLを再ビルドし、実DLLを `native/` に配置した。

## 検証

- EOS拡張のCTest：Device認証→ロビー作成→期限通知→認証更新でユーザーID・ロビーが維持されること、認証処理の二重呼び出し拒否、退出を確認した。
- `tools/test-online.ps1`：Device/Device、Device/Epic、Epic/Device、Epic/Epicのロビー検索・参加・接続・バイナリ入力交換を模擬EOSで確認した。別bucketのロビーが検索に混ざらないことも確認。Backと再実行のテストは両方式を通す。ソース実行と配布用VMで成功マーカーまで確認した。
- 実EOS：ローカルの製品設定を使い、Device IDで認証し、検証専用bucketの公開ロビーを作成・検索した。さらにDevice認証を更新し、ユーザーIDとロビーが維持されることを確認して退出した。設定値をログへ出していない。最初の即時検索では未反映だったが、3秒間隔の再検索で見つかった。
- 未検証：異なるPC間の参加・入力交換、実Epicアカウントとの相互接続、NAT越え・リレー・対戦の操作感。実EOSの検証は1台での自身のロビー検索であり、これらの代わりにはならない。
