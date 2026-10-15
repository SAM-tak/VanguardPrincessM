# vタグでGitHub Releaseを公開

2026-10-11。リポジトリのREADMEが「Releasesから最新版をダウンロード」と案内するので、
`distribution.yml` にReleaseの作成を追加した（従来はArtifactsのみ、[0132](0132-windows-actions.md)）。

## 流れ

- `v*` タグのpushで、各プラットフォームのbuildジョブが公開用アーカイブを `release-<platform>` として
  別途アップロードする。通常のArtifact（`VanguardPrincessM-<platform>`）は従来どおり。
  - Windows: `Compress-Archive` で `VanguardPrincessM-windows-x64.zip`（展開すると `VanguardPrincessM/`）
  - Linux/macOS: 既存の `VanguardPrincessM-<platform>.tar.gz`（実行権限を保持）
- `release` ジョブは4プラットフォームすべての成功後に実行する（`needs: build`）。1つでも失敗すれば公開しない。
  `contents: write` はこのジョブだけに付与。
- `gh release create --verify-tag --generate-notes` で作成し、4ファイルを添付する。
  タグに `-` を含む場合（例: `v0.1.0-beta`）はプレリリース。
- 同じタグで再実行した場合、既存のReleaseに `gh release upload --clobber` で添付を差し替える。

## 使い方

```sh
git tag v0.1.0
git push origin v0.1.0
```

## 検証

actionlint 1.7.12で警告なし（1.7.7は `macos-15-intel` ラベルを知らず誤検出）。
`download-artifact` は公開から日の浅いv8.0.2を避けv8.0.1。実際のタグでの実行は未確認。
