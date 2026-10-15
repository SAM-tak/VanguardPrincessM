# Online VS MODE（Epicアカウント・Device ID / EOS）

この文書は初期の2人用接続の記録。現在の名前付き複数人ルーム・暗証番号・対戦台・試合終了後の復帰は [0164](0164-persistent-online-rooms.md) を参照。

2026-10-15。Steam認証は追加せず、EpicアカウントまたはDevice IDでEOSの2人用公開ロビーを作成・検索し、P2P接続後に既存のVS選択画面へ進む。

## 構成

モードメニューの下部ヘルプは専用の `locale:mode-menu/online-caption` を使う。日本語は「インターネットを通じて対戦します。」、英語は「Play against someone online.」。文字組みはLAN対戦などの説明文と揃え、モード名の画像を流用しない。

- `src/online.lh`：Device ID → Connect、またはEOS Auth → Connect、ロビー、認証更新、退出処理。Device IDは `loginDevice("Player")`。Epicは `loginEpic(true)` で保存済み認証を試し、必要ならAccount Portalへ進む。詳細は [0163](0163-online-device-id.md)。
- `src/net.lh`：LANのUDPとEOSの非信頼P2Pで、同じversion 2の選択・試合設定・入力・確認応答・状態要約を交換する。EOSのロビー参加だけでは試合を開始せず、既存のJOIN / ACCEPTを交換してから開始する。
- `src/lanmenu.lh`：LAN / Onlineで画面を共有。Onlineは「アカウントなしで接続」「Epic アカウントで接続」「戻る」を表示し、認証後に「ホストする」「ロビーを探す」を表示する。ロビー検索は3秒ごとに更新。EOSへ最大100件を問い合わせ、有効な2人部屋を最大8件表示する。対戦相手が揃うとホストが1P、参加側が2Pになる。
- ホスト待機・ロビー検索・参加待ちでB/D/ESCを押すと、OnlineのHost / Search選択へ戻り、元の項目を選択状態にする。ログインを維持し、作成・検索・参加の未完了コールバックとロビー退出を処理してから次の操作を許可する。この間は「前の操作を終了しています…」を表示する。Host / Search選択からのBackはメニューを閉じる。
- 部屋は2人で満員になり、空き部屋の検索から外れる。途中退出・所有者変更・通信断で対戦を終了し、ホスト移行による試合継続は行わない。
- `main.lh` の入力ディレイ3フレーム、予測上限4フレーム、巻き戻し・リプレイはLANと共通。WAN向けの自動ディレイ調整や性能改善はまだ行っていない。
- ロビーbucket `vanguard-m-0162-v2` が互換性の境界。ゲームデータ・シミュレーションの互換性を変える更新ではこの値も更新する。ファイル全体のハッシュ照合ではない。

## ローカル設定

EOSの製品・クライアント設定はプレイヤー設定ではなくビルド時に確定するため、JSONではなくLTONを採用する。開発時はテキストを読み、配布時はコンパイル済み設定をアーカイブへ格納する。

1. エンジンと同じL^ ABIのEOS拡張と対応SDK DLLを `native/` に配置する。`extensions.txt` が `native/eos_lhat` を読み込む。今回、既存の `extensions/eos/windows-x64/eos_lhat.dll` は現在のエンジンとABI不一致だったため、現行ソースから `build/eos/` に再ビルドし、`native/` に配置した。
   `tools/setup-eos.ps1` は `build/eos/` からコピーする。別のビルドを使う場合は `-Extension` と `-Runtime` を指定する。Windows以外は対応する `.so` / `.dylib` が必要。
2. `eosconfig.example.lton` を `eosconfig.lton` にコピーし、Product / Sandbox / Deployment / Clientの各IDとゲームクライアント用Secretを記入する。配布時にLTONをコンパイルするため、VM-only配布でも読める。設定はゲームのソースまたはLÔVEの保存ディレクトリから読む。`native/`・設定本体・キャッシュはGit対象外。
3. 共通でConnect / Lobby / P2Pを許可するゲームクライアント用ポリシーを設定する。Epicアカウント方式を使う場合は、加えてEASアプリのBasic Profile権限、製品クライアントへの関連付け、Epic Games identity providerを設定する。開発中は対象アカウントに組織・テストアクセスを許可する。一般公開にはEASの公開条件の確認も必要。
4. WindowsのAccount PortalはEOSサービスとBootstrapper経由の起動が必要（SDK `eos_auth_types.h` の `EOS_LCT_AccountPortal` 注記）。SDKの `EpicOnlineServicesInstaller.exe` でサービスを導入し、`tools/start-online.ps1` をコンソールから実行する。スクリプトはBootstrapperを生成し、開発用lovecにこのゲームのパスを渡す。`-PrepareOnly` は生成だけ行う。インストーラーの自動実行は行わない。
5. 2台で同じ製品・Sandbox・Deploymentの設定を使い、片方でホスト、もう片方でロビー検索→参加を選ぶ。キャッシュは各PCのゲーム保存ディレクトリ内に作成する。

## 配布

GitHub ActionsではRepository secretsの `EOS_PRODUCT_ID`、`EOS_SANDBOX_ID`、`EOS_DEPLOYMENT_ID`、`EOS_CLIENT_ID`、`EOS_CLIENT_SECRET` を使用する。push／手動実行のビルド手順で、環境変数経由で `tools/write-eos-config.ps1` に渡し、ルートの `eosconfig.lton` を生成する。値をログやコマンド引数へ出さず、既存ファイルは上書きしない。PRビルドにはこれらのSecretsを渡さず、設定生成も行わない。ローカルの設定ファイルには変更を加えない。

`tools/package-game.ps1` はネイティブ拡張をステージへ配置してコンパイルし、アーカイブにはmanifestを含める。設定テンプレートは開発用で、配布には含めない。ルートに `eosconfig.lton` があればコンパイル済み設定として含めるため、**ゲームクライアント用の設定だけ**を置く。管理者用の認証情報は使用しない。`tools/dist.ps1` は `native/` とEOSの第三者ライセンスを外部ファイルとして配布する。

クリーンなCI環境にもABIが一致する拡張・対象OSのEOSランタイムとライセンスの供給が必要。既存のCIはこれらのダウンロードを設定していないため、その準備なしではOnline対応版をビルドできない。Windowsの配布版は、SDKのBootstrapperToolで `VanguardPrincessM.exe` 用の起動ファイルも用意する必要がある。

## 検証と限界

`tests/online-link.lh.in` は生成用テンプレートであり、単独では実行しない。`tools/test-online.ps1` が `build/online-test/` 内へ `main.lh` として配置し、実装から生成したゲスト用モジュールと模擬EOS拡張を揃えて実行する。通常の `.lh` として置くと、エディターが生成前の参照先を解決できずエラーになるため、テンプレートの拡張子を `.lh.in` にしている。

- `tools/test-online.ps1`：実装そのものを2組読み込み、eos-lhatの模擬SDKでEpicログイン、ログイン中キャンセル、空の検索からの自動更新、ロビー参加、JOIN / ACCEPT、キャラ選択、試合設定、バイナリ入力と確認応答、相手の退出、再ログイン、不正設定のエラー復帰を検査する。ソース実行とコンパイル済みVM-only実行の両方で通過。実サービスへの通信は行わない。
- 本体の配布アーカイブ作成と、WindowsのBootstrapper生成（起動はしない）も確認した。`tools/test-package.py` は既存の素材込みfixtureと実行指定が食い違っていたため、`-IncludeAssets` を付けて検査するよう修正した。
- LTON移行後も模擬EOSのソース／VM-only実行が通過。梱包テストではルートの `eosconfig.lton` がコンパイル済みで格納され、`eosconfig.example.lton` が配布対象外になることを検査する。
- Backの回帰検証では、B/D/ESCでHost / Search選択へ戻り、同じ項目から再実行できること、選択画面でさらにBackすると閉じることを検査する。作成・検索の完了前に戻った場合も、遅れたコールバックで待機画面やロビーが復活しないことを確認する。
- `tools/test-lan.ps1 -Impaired -Stage 7`：既存のLAN対戦が通信障害下でも完走し、両者の24回の状態照合・全入力・終了結果・巻き戻しなしのリプレイが一致した。
- Device IDの実EOS認証・検証用公開ロビー作成・検索・認証更新・退出は確認済み（[0163](0163-online-device-id.md)）。Epicの実ログイン、別PC間の接続、NAT越え・リレー・対戦の操作感は未検証。
