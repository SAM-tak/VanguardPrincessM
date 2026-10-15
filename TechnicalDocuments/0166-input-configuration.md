# settings.jsonによるキーコンフィグ

2026-10-15。ゲーム内の設定画面は作らず、既存のセーブ設定に `input` を追加した。

## 編集方法

一度ゲームを起動すると、セーブフォルダーの `settings.json` に現在の既定割り当てが書き出される。既存ファイルには不足する項目だけを追加し、言語・フルスクリーン・プレイヤー名などは保持する。JSONが壊れている場合はファイルを書き換えず、実行中だけ既定値を使う。

Windowsでソースから起動した場合は `%APPDATA%\LOVE\vanguard-princess-m\settings.json`、配布版は `%APPDATA%\vanguard-princess-m\settings.json`。ゲームを終了して編集し、再起動すると反映される。開発用のリロード（既定F8）でも設定を読み直す。

`input` 内の各節:

| 節 | 対象 |
| --- | --- |
| `keyboard1` | 1Pのキーボード |
| `keyboard2` | 2Pのキーボード |
| `gamepad1` | 最初に割り当てられたゲームパッド |
| `gamepad2` | 次に割り当てられたゲームパッド |
| `shortcuts` | 共通の戻る・Start・リロード |

例えば1Pの方向をWASD、A/B/C/D攻撃をJ/K/L/Iにするなら、既存の `input.keyboard1` 内を次のように編集する。`a`〜`f` は既存のA〜Fボタンに対応する。キー名は小文字。空文字 `""` は無効化、未指定・不正な名前・文字列以外の値はその操作の既定値になる。

```json
{
    "up": "w",
    "left": "a",
    "down": "s",
    "right": "d",
    "a": "j",
    "b": "k",
    "c": "l",
    "d": "i",
    "e": "u",
    "f": "o"
}
```

この例では2Pの既定キーと重なるため、ローカル2人対戦で使う場合は2Pも変更する。同じ物理キーに複数の操作を割り当てると、それらがすべて入力される。

## 既定値と名前

キーボードの `up / left / down / right / a / b / c / d / e / f` は以下。

- 1P: `up / left / down / right / z / x / c / a / s / d`
- 2P: `u / h / j / k / l / semicolon / quote / o / p / leftbracket`

ゲームパッドは両者とも同じ既定値:

```json
{
    "up": "dpup", "left": "dpleft", "down": "dpdown", "right": "dpright",
    "a": "a", "b": "x", "c": "y", "d": "b",
    "e": "rightshoulder", "f": "leftshoulder",
    "back": "back", "start": "start"
}
```

ボタン名はLÖVEのゲームパッド名（`a`, `b`, `x`, `y`, `leftshoulder`, `rightshoulder`, `back`, `start`, `guide`, `leftstick`, `rightstick`, `dpup`, `dpdown`, `dpleft`, `dpright`など）。左スティックの方向操作と閾値0.35は従来どおりで、ボタン割り当てと独立する。

`shortcuts` の既定値:

```json
{
    "back": "escape", "start": "return", "reload": "f8"
}
```

開発用操作（F1判定表示、Gガード、F2瀕死、Tステージ、F5音声ログ、F3/F4 CPU切替）と数字1〜8による1Pパレット変更は固定キー。`settings.json`では変更できない。以前書き出した該当項目は次回入力設定の読み込み時に削除する。

数字1〜8による直接のパレット変更は、既存の開発用表示と同じ `love.filesystem.isFused()` で制限し、ゲームを組み込んだ配布用実行ファイルでは無効にする。ソースからの起動では従来どおり有効。キャラ選択画面の通常の左右によるカラー選択は維持する。他の開発用操作の配布版での扱いは今回変更していない。

数字や記号は `digit1`, `semicolon`, `leftbracket`, `quote` などのエンジンの列挙名に加えて、`"1"`, `";"`, `"["`, `"'"` などの通常のLÖVEキー名も使える。すべての対応名は `src/keynames.lh`。

Startはメニュー決定・ポーズも兼ねる。フルスクリーン切り替えはAlt＋Startのキー（既定Alt+Enter）。ロビー内の離席・退出は `shortcuts.back` またはゲームパッドの `back` のみで、B/D攻撃ボタンでは退出しない。

文字入力欄のTab・Enter・Esc・Backspace・Ctrl/Cmd+Vは編集用の固定キーであり、ゲーム用キー割り当てから独立する。画面に描かれた既存のキー名表記は自動で差し替えない。

## 実装と検証

`settings.inputConfig` が不足項目を補完する。`input` が物理キーを従来の論理入力へ変換し、押下イベントと保持状態の両方で同じ割り当てを使う。ゲームパッドは論理入力を直接生成するため、キーボードを変更しても影響しない。対戦・メニュー・リプレイで同じ経路を使用する。

- `tools/test-input.ps1`: ソースと配布用VMで既定値・設定補完・他の設定の保持・キーの入れ替え・無効化・不正値・数字記号・保持と解除・2台独立・パッドの押下と保持・アナログ方向・不正JSONの保持を確認。
- `tools/test-online-game.ps1 -RemappedInput`: 決定をSpaceに変え、固定のF3でCPUを切り替えて、実ゲーム本体でキャラ選択・試合・リプレイ保存・ロビー復帰・再READYから次のキャラ選択まで確認。
