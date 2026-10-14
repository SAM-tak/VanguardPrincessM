# 難易度選択の英文説明

ユーザー指定により、assets/characters/だみー/images/0000.pngの日本語説明を、英語ロケールで白地に黒の英文を重ねて表示する。

- EASY: 初心者向け、CPU難易度が低い、2ラウンド先取、全7試合。
- NORMAL: 中級者向け、CPU難易度が高い、2ラウンド先取、全7試合。
- HARD: 上級者向け、CPU難易度が非常に高い、2ラウンド先取、全11試合。
- 下端: CPU難易度を選ぶ。Left/Rightで選択、Aで決定。

訳文はGameDocuments/OverlayText.md。tools/locale/overlays.pyのdifficulty()がカード3枚と操作説明の計4ブロックを生成する。build_en_text.pyを再実行してdata/locale/en/images.ltonに反映。base=trueで背景と既存の英語見出しを残し、eraseで日本語を白く塗る。Montserrat Bold 11px・黒・行間2px。

カードの白地は画像内座標で(44,256,146,113)、(254,256,140,113)、(461,256,140,113)。下端は(90,431,474,24)。元画像と日本語ロケールは変更しない。左上の透明ピクセルもそのまま。

検証: エンジンで英語ロケールのlocale.renderを実行し、readbackTextureで画素を取得してbuild/difficulty-en-preview.pngに出力。日本語が残らないこと、英文が白地に収まること、枠と英語見出しを保つことを目視確認。実行時の設定ファイルは退避・復元した。
