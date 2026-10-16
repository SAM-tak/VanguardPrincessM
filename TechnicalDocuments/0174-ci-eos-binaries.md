# CIへのEOS拡張配置と互換性検証

2026-10-16。DistributionジョブのEOS導入後の失敗への対応。

## 原因

報告された実行のLinuxジョブは `package-game.ps1` の `Run tools/setup-eos.ps1 before packaging` で停止した。
`native/` はGit対象外だが、CIに配置手順がなく、従来の `setup-eos.ps1` もローカルビルドのWindows用ファイルだけを既定としていた。

さらに、Git管理されている `extensions/eos/` の拡張は eos-lhat v0.1.3 であり、常設ロビーで必要になった `setRoom`、`kick`、`displayName`、`roomUpdated` 等を持たない。
この古い拡張を配置するだけでは、現在の `src/online.lh` のコンパイルが失敗することも確認した。
対応済みの eos-lhat コミットは `95ffb66`。ユーザーがv0.1.4として公開し、Windows/Linux/Macの同梱拡張をそのリリースへ更新済み。

## 変更

- `setup-eos.ps1` は既定で同梱のOS別ファイルを `native/` に配置する。Windows x64、Linux x64、macOS arm64/x64に対応。Macは既存の `maxos-universal/` ディレクトリを両CPUで使用する。
- 開発用ビルドは従来どおり `-Extension` と `-Runtime` を明示指定できる。検証用に `-Destination` も指定可能。
- Distributionワークフローはエンジンの取得後にEOSを配置し、`test-eos-runtime.ps1` で検証する。設定生成時のSecretsやPRへの供給条件は変更しない。
- 検証用ゲームは現在必要なロビーAPIを型検査し、ソース実行とコンパイル済み・融合済みVM-only実行を確認する。EOSクライアント生成・ログイン・実サービスへの接続は行わない。30秒でタイムアウトし、描画・音声は不要。
- `check-distribution.ps1` はアーカイブ内の拡張manifest、外部のOS別拡張とSDKランタイム、その内容とコンパイル時のファイルの一致、EOS第三者ライセンスの存在を検査する。

## 拡張リリース公開後

新しいリリースタグを指定して実行する（以下のタグは例）。

```powershell
./tools/update-eos-extension.ps1 -Tag v0.1.4
./tools/setup-eos.ps1
./tools/test-eos-runtime.ps1 -Lovec build/release-engine/compiler/lovec.exe -ShippingDirectory build/release-engine/runtime
```

更新スクリプトはGitHub ReleaseからWindows/Linux/Macの3ファイルを取得し、全ファイルのSHA256がGitHubのdigestと一致してから同梱ファイルを置き換える。
SDKランタイムとライセンスはそのまま保持する。取得したタグとハッシュは `tools/eos-release.json` へ記録する。
記録と同梱拡張はv0.1.4へ更新済み。全3ファイルがGitHub ReleaseのSHA256 digestと一致することを確認した。

## ローカル検証

- 4プラットフォーム指定で同梱ファイル2個ずつを配置できることと、変更したPowerShellの構文を確認。
- 配布固定版エンジン v12.0.0-alpha.9 をダウンロードし、Windowsで実際に使用。
- 同梱v0.1.3は基本的な読み込みには成功するが、現在のゲーム全体のコンパイルは不足APIで失敗。
- ローカルの対応済みWindows拡張は、ロビーAPIの型検査、ソース実行、融合済みVM-only実行に成功。
- 同じ固定版コンパイラと対応済みWindows拡張で、現行ゲーム全体のコンパイル・配布アーカイブ生成にも成功（34コンパイル単位、199 LTONファイル）。
- 古い同梱拡張を読み込み検証が不足APIとして拒否することを確認。更新スクリプトもv0.1.3の再取得で3ファイルのダウンロード・digest検証を確認し、同梱バイナリに差分がないことを確認。
- 公開されたv0.1.4のWindows拡張でも、固定版エンジンでロビーAPIの型検査・ソース実行・融合済みVM-only実行が成功。ゲーム全体の34コンパイル単位・199 LTONファイルのコンパイルと272エントリの配布アーカイブ生成も成功。
- Linux/macOS上での実行とGitHub Actionsの再実行は未実施。
