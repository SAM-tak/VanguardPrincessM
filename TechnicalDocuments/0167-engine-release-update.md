# 配布用エンジンの更新

`tools/update-engine.ps1` で `tools/engine-release.json` のタグと全プラットフォームの compiler/runtime のアセット名・SHA-256 を更新する。GitHub CLI (`gh`) が必要。

```powershell
# プレリリースを含む最新リリース
pwsh -NoProfile -File tools/update-engine.ps1
# タグを指定
pwsh -NoProfile -File tools/update-engine.ps1 -Tag v12.0.0-alpha.8
```

全アセットと GitHub が公開する SHA-256 が揃っていることを確認してから JSON を書き換える。`-Verify` を追加すると、更新後に実行中のプラットフォーム用のアセットをダウンロードしてハッシュと必要な実行ファイルを検証する。

VS Code の「タスクの実行」から `Update engine release (latest, including prereleases)` または `Update engine release (select tag)` を選べる。後者はタグの入力欄を表示する。既存のビルドタスクはそのまま使える。`.vscode/` は現在 `.gitignore` の対象なので、タスク設定はローカルに保存される。
