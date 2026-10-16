# 画像に重ねる英文（システムメッセージ・ストーリー冒頭・難易度選択・ポーズのインスト）

元の画像を残し、日本語の部分だけを単色の矩形で消して英文を重ねる対象（翻訳用）。
各項目の直下の text コードブロックが英訳（現在は Claude の下案。改行は訳文に合わせて調整してよい）。

- システムメッセージ: 上段の英語（CALCIUM BREAK など）は残し、下線の下の日本語を消して英文を置く
- ストーリー冒頭の一枚絵: 名前の飾り文字とローマ字は残し、本文を白の矩形で消して英文を置く
- ポーズのインスト: 英語版の画像 `data/images/Instraction.png` に差し替える（下の訳は参考）
- 難易度選択: 3枚の説明文と下端の操作説明を白の矩形で消して英文を置く
- 日本語テキスト段落末の引用は翻訳者向け注釈

## 難易度選択（説明文・操作説明）

assets\characters\だみー\images\0000.png

EASY: 初心者向け。CPUレベルが低く、2ラウンド先取、全7試合。
NORMAL: 中級者向け。CPUレベルが高く、2ラウンド先取、全7試合。
HARD: 上級者向け。CPUレベルが非常に高く、2ラウンド先取、全11試合。
操作説明: CPUの難易度を設定してください。←→で選択、Aボタンで決定します。

```text
For beginners.
Low CPU difficulty.
Win 2 rounds
to win each match.
(7 matches total)

For intermediate players.
High CPU difficulty.
Win 2 rounds
to win each match.
(7 matches total)

For advanced players.
Very high CPU difficulty.
Win 2 rounds
to win each match.
(11 matches total)

Choose the CPU difficulty.   Left/Right: Select   A: Confirm
```

## システムメッセージ（対戦中、下半分）

assets\shared\images\bd12816f476555880380eeccf6ddb55d2ccb8189.png
CALCIUM BREAK
ガード強制解除

```text
Guard broken
```

assets\shared\images\a331396a7d808c403d4377e769011475d9139563.png
SUPPORT COUNTER
サポートキャラ使用不能

```text
Support disabled
```

assets\shared\images\44cc6be82c28028eae2f1979675f23c6cc9efbb6.png
STUN
レバーの左右を連打で回復

```text
Mash left/right to recover
```

assets\shared\images\93fd36be93a0453262c8acf1063f37a9f64335e8.png
TECH BONUS
投げぬけ成功

```text
Throw escaped
```

assets\shared\images\f844b5967124b7136dc7436b4e90ec47497276e5.png
GET BONUS!!
サポートゲージ回復

```text
Support gauge restored
```

assets\characters\くるみ\images\0511.png
GOTCHA!
Dボタン連打で開放
> くるみ固有

```text
Mash D to break free
```

assets\characters\あやね\images\1978.png
MIKO THROUGH
突進技を華麗にスルー
> あやね固有

```text
Slips past a rushing attack
```

assets\characters\はるか\images\1978.png
MAGICAL THROUGH
突進技を華麗にスルー
> はるか固有

```text
Slips past a rushing attack
```

assets\characters\ルナ\images\0179.png
SPEED SHOOTING
早撃ち
> ルナ固有

```text
Quick draw
```

assets\characters\ルナ\images\1977.png
LASTSHOOTING
ガード不能
> ルナ固有

```text
Unblockable
```

## ストーリー冒頭の一枚絵

名前の飾り文字とローマ字（KUTSUNA YUI など）は画像のまま残る。
画像のローマ字は「KUTSUNA」「MIRUMATI」表記（ネームプレートの英語版は Kutuna / Mirumati）。

assets\characters\ゆい\images\1974.png
第107代忽那無想流剣術の伝承者。
アストラルインパクトにより転生した
古代の神剣「サクヤ」の使い手。

失踪した姉、「はるか」を探すべく
戦いの地へ赴く…。

```text
107th heir to the Kutuna Muso school of swordsmanship.
Wielder of Sakuya, an ancient divine sword
reborn through the Astral Impact.

In search of her missing sister, Haruka,
she sets out for the battlefield...
```

assets\characters\はるか\images\1971.png
忽那流剣術の伝承者として育てられてきたが
突然、魔術師に転身する。
その後、政府軍の研究施設において
大きな魔力を手に入れる。

かつての友人を救うために
戦いの地へ赴く…。

```text
Raised as heir to the Kutuna school of swordsmanship,
she suddenly turned to sorcery.
At a government military research facility,
she later gained immense magical power.

To save a friend from long ago,
she sets out for the battlefield...
```

assets\characters\リリス\images\1974.png
ある日突然、魔界からやってきて
学園理事長の座についた悪魔の子。
しかし、自分は悪魔だと言っても
周りの人間は誰一人信じない。

悪魔の偉大さを知らしめるべく
戦いの地へ赴く…。

```text
A demon child who arrived from the underworld one day
and took the seat of the academy's chairwoman.
Yet no matter how often she says she is a demon,
not a single person around her believes it.

To show the world the greatness of demons,
she sets out for the battlefield...
```

assets\characters\ルナ\images\1974.png
特殊部隊「ブレイド・ロア」の元隊員。
現在は賞金稼ぎとして
裏社会に名を馳せる。

とある賞金首の情報を手に入れた
彼女は戦いの地へ赴く…。

```text
A former member of the special forces unit Blade Roar.
Now a bounty hunter
famed throughout the underworld.

Having learned of a certain bounty,
she sets out for the battlefield...
```

assets\characters\くるみ\images\1971.png
とある飛行機事故の翌日
突然現れた謎の少女。
基本的な戦闘力は低いが
大きな力を秘めている。

サポートキャラに導かれるまま
戦いの地へ赴く…。

```text
A mysterious girl who suddenly appeared
the day after a certain plane crash.
Her fighting skills are modest,
but she hides a great power.

Led on by her support character,
she sets out for the battlefield...
```

assets\characters\サキ\images\1974.png
剣道部主将で学園の次期生徒会長候補。
神剣のデータを基に軍が開発した
神刀「ひとひら」の性能テストと
データ収集を任される。

神剣の使い手、忽那ゆいとの
試合を求めて
戦いの地へ赴く…。

```text
Captain of the kendo club and the academy's next student council president hopeful.
She is entrusted with testing Hitohira,
a divine blade the military built from the divine sword's data,
and with gathering data.

Seeking a match with Yui Kutuna,
wielder of the divine sword,
she sets out for the battlefield...
```

assets\characters\かえで\images\1971.png
裏社会に生きる暗殺者。
過去の記憶は失っており、
全てが謎に包まれた女性。

政府軍の将校、澤川大佐の
暗殺依頼を受け
戦いの地へ赴く…。

```text
An assassin who lives in the underworld.
Her memories of the past are lost,
and everything about her is shrouded in mystery.

Hired to assassinate Colonel Miokawa,
an officer of the government army,
she sets out for the battlefield...
```

assets\characters\ナタリア\images\1971.png
某国の軍人であり諜報員。
信心深く、命令にも忠実で
常に冷静沈着である。

機導魔術を開発したのを受け
潜入活動を開始する…。

```text
A soldier and intelligence agent of a certain nation.
Devout, loyal to her orders,
and always calm and composed.

Upon the development of Mechanical Sorcery,
she begins her infiltration...
```

assets\characters\えり\images\1974.png
孤児院で育った彼女だったが
その身体能力を認められ
政府軍の研究所へ送られる。

しかし、度重なる人体実験に
耐え切れず、
自由を求めて脱走する…。

```text
Raised in an orphanage,
her physical gifts were recognized
and she was sent to a government military lab.

But unable to endure
experiment after experiment,
she escapes in search of freedom...
```

assets\characters\あやね\images\1975.png
幾世流弓術の使い手。
修行中に片目の視力を失う。
アストラルインパクトにより恩恵を得るが、
その力も徐々に失いかけている。

幼なじみであり、ライバルである
「ゆい」との決着を付けるため
戦いの地へ赴く…。

```text
Master of the Ikuse school of archery.
She lost the sight of one eye in training.
Blessed by the Astral Impact,
she is now slowly losing that power.

To settle things with Yui,
her childhood friend and rival,
she sets out for the battlefield...
```

## ポーズのインスト

assets\system\ヴァンガードプリンセス\images\0165.png
英語版は別に用意した画像 `data/images/Instraction.png` をそのまま表示する（重ねる方式は無理があったため）。この節の訳は生成ツールでは使わない（画像作成時の参考）。

### 基本操作

基本操作

```text
Basic Controls
```

全てキャラクターが右向きの時のものです。

```text
All inputs assume you are facing right.
```

後方ジャンプ（空中ガード）

```text
Back jump
(air guard)
```

ジャンプ

```text
Jump
```

前方ジャンプ

```text
Forward jump
```

後退（ガード）

```text
Back
(guard)
```

前進

```text
Forward
```

しゃがみガード

```text
Crouch guard
```

しゃがみ

```text
Crouch
```

弱攻撃

```text
Light
```

中攻撃

```text
Medium
```

強攻撃

```text
Heavy
```

サポート攻撃

```text
Support
```

投げ…（アイコン）

```text
Throw...
```

ラン・ステップ…（アイコン）

```text
Run / Step...
```

バックステップ…（アイコン）

```text
Backstep...
```

リフレクト… AB同時押し

```text
Reflect... A+B together
```

### サポートキャラクターコマンド

サポートキャラクターコマンド

```text
Support Character Commands
```

LVとはサポートレベルの事を指します。

```text
LV means support level.
```

S弱攻撃…LV1以上で D

```text
S Light... LV1+: D
```

S中攻撃…LV1以上で（アイコン）

```text
S Medium... LV1+:
```

S強攻撃…LV2以上で（アイコン）

```text
S Heavy... LV2+:
```

S超攻撃…LV2以上で（アイコン）

```text
S Super... LV2+:
```

ブロクシガード… / LV1以上で（アイコン）

```text
Proxy Guard...
LV1+:
```

### その他のシステム

その他のシステム

```text
Other Systems
```

リバティアーツ

```text
Liberty Arts
```

スペシャルゲージを消費して
必殺技の上位版を繰り出します。

```text
Spends the Special gauge to unleash
a stronger version of a special move.
```

サポートカウンター

```text
Support Counter
```

サポートキャラが何らかの行動を起こしている時に
プレイヤーがダメージを受けるとサポートキャラが
一定時間使えなくなります。

```text
If you take damage while your support character is acting,
the support character cannot be used
for a while.
```

投げぬけ

```text
Throw Escape
```

投げられる直前に（アイコン）

```text
Just before being thrown:
```

受身

```text
Recovery
```

吹き飛び中にいずれかのボタンを押します。

```text
Press any button while knocked away.
```

リフレクト

```text
Reflect
```

プレイヤー本体の直接攻撃を受け流します。

```text
Deflects the opponent's direct attacks.
```

プロクシガード

```text
Proxy Guard
```

プレイヤー本体の放った飛び道具と
サポートキャラの攻撃全般を受け流します。

```text
Deflects projectiles fired by the opponent
and all attacks by the support character.
```
