# NEXT — @f3liz/mazemaze-generator でこの先やること

> 旧名 `melange-jsdoc-gen`(さらに前は `jsdoc-sketch`)。spike(`melange-autogen-spike`)＋jsdoc-gen を
> 統合し、Melange/ReScript/TypeScript の三言語を一つの Melange runtime から出す生成器として改名。
> 以下の履歴メモ内の "jsdoc-gen" は本プロジェクトの旧名を指す。

走り書き。優先度は ★(高)〜☆(あとで)、規模は S/M/L、🎀 = 「JSDoc を開いた人に親切」という本筋に直接効くもの。

現状(2026-06-27): 実 misskey spec → flat melange(.ml→.js) + JSDoc注入 + **nested ReScript .res
バインディング層**まで生成。`rescript-autogen-openapi` の生成層(./components + ./endpoints)を
**置き換えられる capable な単体**になった(branch `feat/rescript-binding-layer`、`32831c7` 署名なし)。
test/run.sh は 8 チェック緑。以下は積み残しと磨き。

## ★ melange-dist JSDoc 化 → kaguya 型改善の道 (2026-06-28)

- **やった**(production branch `feat/generate-via-jsdoc-gen` @ `38303e4`、署名済・未push): production の
  build で **melange-dist の flat .js に JSDoc を注入**。`generate-melange.sh` が `.jsdoc.json` メタ＋
  `annotate.mjs` を vendor(build 自己完結)、`build-melange.sh` が dune→dist 後に melange-dist/
  {ComponentSchemas,Endpoints}.js を in-place annotate(acorn devDep)。`package.json` に
  `./melange-endpoints` `./melange-components` export 追加。
- **jsdoc-gen 側**(`ec6a8a4`): `annotate.mjs` を schema モジュール名でパラメタ化(3rd 引数)＋import 書換を
  case-insensitive 化。これで melange-dist(`ComponentSchemas.js`)レイアウトを annotate できる。
- **検証**: melange-dist/Endpoints.js が `@returns {Promise<Note[]>}`＋`import('./ComponentSchemas.js').Note`
  alias 付きに、runtime import 無傷、**rescript build 78 緑**(JSDoc は注釈なので .res バインディング無影響)。
  TS probe で flat 層 import → `postNotesTimeline_send(fetch,{limit:20}): Promise<Note[]>`・`notes[0].user
  .username` typed・bogus 拒否を確認。
- **残り**: kaguya が `./endpoints`(nested .res.mjs, `unknown[]`)→`./melange-endpoints`(flat JSDoc)に
  import 切替＋allowJs＋手書き stub 撤去すれば `Note[]` が出る。**ただし flat 名(`postNotesTimeline_send`)で
  nested(`Notes.PostNotesTimeline.send`)ではない**ので lib-src/misskey.ts の呼び口変更が要る。publish 後。

## ★ production 実配線 (2026-06-28)

- **やった**: `rescript-misskey-api` の Melange 層生成を autogen→jsdoc-gen に差し替え(branch
  `feat/generate-via-jsdoc-gen` @ `92554fe`、署名済・**未push**)。`scripts/generate-melange.sh` が
  jsdoc-gen(兄弟 checkout)を build+run し `melange/{ComponentSchemas,Endpoints}.ml` +
  `src/melange-api/{ComponentSchemas,Endpoints}.res` を配置。`generate` をそれに repoint、autogen devDep 削除、
  lockfile 再生成。
- **効いた一手**: jsdoc-gen の fetchFn をラベル形 `(~path, ~body: option<JSON.t>)` に合わせた(jsdoc-gen
  `51007f0`)ので、手書き `Misskey.res` の apiFetch が無変更でコンパイル。
- **検証**: build:melange(dune) + **クリーン `rescript build` 78モジュール緑**、autogen を node_modules から
  消した状態で。構造 drop-in(28 タグ/439 send)、ComponentSchemas は superset。kaguya は使う send 名が
  388 一致側＆nested パス不変なので publish 後も無影響の見込み(未検証=別 publish)。
- **残り**: ①push(jsdoc-gen 側ブランチも)。②legacy Sury 層(`src/generated/`+`generate-api.mjs`)は committed
  のまま残置、retire は別判断。③kaguya 実ビルド検証は publish 後。④production の melange-dist に JSDoc を
  乗せて kaguya の `unknown[]`→`Note[]` を実現するのは次段(今は raw melange .js)。

## ★ 三言語ぜんぶ自然化 (2026-06-27, branch feat/rescript-binding-layer)

- **目標**: Melange を一番自然に(主)、ReScript/TS も自然に。小さな runtime 変換は許容。
- **Melange(主・実装済)**: `gen/emit_sugar.ml` → `misskey.ml`。`Client`(origin/token+注入 post → transport、
  /api 前置と token を `i` に入れる小さな runtime 変換)＋タグ別 labeled-optional ラッパー。required→`~x`、
  optional→`?x`、record punning で機械生成。アクション名=opId から method+tag を剥ぐ(create/timeline)。
  → `Misskey.Notes.create client ~text:"hi" ()`。melange でコンパイル検証済。
- **ReScript(実装済)**: emit_rescript の request/schema を **optional record field**(`text?:`)に。
  → `Notes.PostNotesCreate.send(_, {text:"hi"})`。コンパイル後 JS 同一でバインディング不変。
- **TS(既に自然)**: flat JSDoc 層で `{text:"hi"}` が通り応答は Note[]。`.res.mjs` でなく `.js` を import。
- **例**: `examples/{melange,rescript,typescript}` 三言語＋README。harness phase [7] で三例とも compile 検証
  (run.sh は計 11 チェック緑)。
- **残り**: Misskey.js は promote してない(Melange 消費者は emit を build する前提)。Client の実 fetch 束ねは
  consumer 注入のまま(プラットフォーム非依存)。

## ★ rescript-autogen-openapi 置き換え (2026-06-27, branch feat/rescript-binding-layer)

- **何をした**: melange-jsdoc-gen が flat melange + JSDoc に加え **.res 層**(ComponentSchemas.res +
  Endpoints.res)を生成。melange は flat 据え置き(jsdoc/annotate 無傷)、nested(`Notes.PostNotesTimeline
  .send`)は .res が `@module` external で flat `postNotesTimeline_send` にバインド(spike の rslayer を
  自動生成化)。新規: `gen/emit_rescript.ml`、`Repr.rescript_type_self`/`rescript_label`、op に `tag`、
  `res/rescript.json`、build.sh に rescript build 段。
- **実証**: production `rescript-misskey-api/src/melange-api/*.res` と構造比較で **28 トップモジュール一致・
  439 endpoint 一致・388/439 flat send 名一致**(残51は `i/*` 等の連続短セグメントの camelCase 差のみ、
  内部整合済で nested API には無影響)。ComponentSchemas は 236 vs 71 の **superset**(A6 がインライン
  object を named 型に回復、production は opaque 据え置き)。.res は rescript でコンパイル、nested send の
  round-trip(`Admin.PostAdminDriveCleanup.send`)が flat melange decoder まで到達。
- **残り(このブランチ後)**: ①gpg 再署名(`32831c7` が unsigned)。②**capable 止まり**: production の build を
  autogen→jsdoc-gen に実配線、kaguya の allowJs 化＋手書き stub 撤去は別タスク(B3 実配線)。③camelCase を
  production に完全一致させるか(今は意図的に内部整合優先・gold-plate しない判断)。④no-arg send の .res が
  `(fetchFn, unit)`——production の正確な形と要突き合わせ。

---

---

## ✅ 済んだもの (2026-06-27)

- **A1 doc コメント → JSDoc** — 実装済・検証済。`field.doc` を `@property name - <desc>` に、
  record の `named.doc` を typedef 冒頭に流す。**ここで一つ気づいた**: NEXT.md は「`field.doc`/
  `named.doc` はデータ揃ってる」と書いてたけど、実際に prose が一番たくさん居るのは
  **operation の `description`(439件)** のほう——schema field の説明は 26 件だけ、`named.doc` は 0。
  なので IR の `op` に `doc` の席を足して(無かった)、send 関数の JSDoc に operation 説明を流した。
  これが一番届く: `notesCreate_send` を開くと `**Permission**: *write:notes*` が見える。
  併せて `q`(JSON エスケープ)を本格化——op 説明は全件 `\n` を含むので、改行を捨てると
  メタ JSON が壊れる。これは必須だった。`*/` ガードは annotate 側。`summary` はパスと重複で捨てた。
- **A4 nullable** — 実装済・検証済。**「型の小さな嘘」ではなく実クラッシュだった**。
  3.1 `type:[...,"null"]` は 175 件、うち **129 件が required**。required-nullable は今まで
  非option の `string` で出てて、misskey が `"name": null`(表示名なしユーザーは普通)を返すと
  `string_of_json null` で **decode が throw** していた(実測で確認: `Of_json_error`)。
  直し方: melange は `[@json.option]` 経由で null を None=`undefined` に畳むので、
  **nullable ⟹ option(null を吸う) かつ JSDoc も optional**。`T | null` と書くのは逆に
  「runtime に null が残る」嘘になる(repr は runtime 形をモデルする方針)ので採らなかった。
  判定は `Repr.field_optional f = f.optional || f.nullable` に一本化し、両 emitter が同じ判断を見る。
  結果: `UserLite.name` は `string option`/JSDoc `[name]` になり、null で落ちなくなった。

## ✅ 済んだもの (続き)

- **C1 回帰ハーネス** — 実装済。`test/run.sh` が手作業の全証明を1コマンド・fail-loud で:
  ①build ②**決定性(C3)=同 spec で .ml/.json が byte 一致** ③consumer.ts が意図した3診断ちょうど
  ④kaguya-probe green ⑤runtime decode(`test/decode.mjs`+固定 fixture: null path/merged/空req `{}`)。
  CI 化は B7(git init)待ち。
- **A2 = 空リクエスト op を捨てない** — 実装済・検証済。**ここも NEXT.md の前提がズレてた**:
  この spec に query/path param の op は **0件**、path テンプレート `{}` も **0件**(GET 5本も param ゼロ)。
  skip されてた 54 op は全部「**空リクエストの POST**」(`/i`→MeDetailed, `/invite/create`→InviteCode,
  24本が配列応答, 14本が204)。`if req=[] then None` がこれらの **typed response** を捨ててた。
  直し: skip 撤去し全 op emit。空 record は OCaml で不正なので空リクエストだけ `type request = unit`
  ＋`request_to_json _ = {}` に特殊化(send 面は `(fetch, req)` で uniform、req は無視)。
  JSDoc 側はメタが空 record→空オブジェクト typedef を既に出すので無変更。385→**439 op**、名前衝突ゼロ。
  `postI_send : Promise<MeDetailed>` が出て、kaguya の `currentUser`(今 `Result<unknown>`)が型を得られる。

## ✅ 済んだもの (続き2)

- **B7 git init ＋ CI** — 済。`git init`(branch `main`)＋初期コミット(`34b0dda`、29ファイル、
  生成物/_build/node_modules は .gitignore 済)。`package.json` の `npm test`→`test/run.sh`、
  `npm run build`→`build.sh`。`.github/workflows/ci.yml`(setup-ocaml 5.2 + setup-node 22 →
  `opam install dune melange melange-json yojson` → harness)。**push 未**(remote 無し)。
  CI YAML は実 run 未検証——初回 push でバージョン pin が要るかも(harness 自体が真実の基準)。

## ✅ 済んだもの (続き4)

- **A6 inline-object hoist** — 実装済・検証済(`fd76c87`、**署名なし**: gpg passphrase 切れで
  --no-gpg-sign。気になれば amend を)。field/array-item/union-member のインライン object を
  名前付き aux schema に hoist して Ref 化。命名は `<Parent><Prop>`、union variant は discriminator
  (`type` const、`reaction:grouped` の `:` は ident_of でサニタイズ)→ NotificationNote 等。
  **効果: opaque object-fallback が 0 に**。Notification(24 variant)/PageBlock(4)が本物の union、
  Error.error→ErrorError、UserLite.instance→UserLiteInstance、op の inline response 114件を回復。
  **71→338 schema**(267 aux)。決定性維持。probe に Notification union チェック、decode に
  nested Error.error チェック追加。
  **既知の磨きどころ**: 構造的に同一なインライン object が op ごとに別 aux になる(構造 dedup 未)。

## ✅ 済んだもの (続き5)

- **dedup 構造的共有** — 実装済・検証済(`88c3180`)。新 `Dedup` モジュール(IR→IR、Resolve の前)。
  構造的に同一な hoisted aux を1つに畳む。ボトムアップ(`Resolve.order` で子先 → 子 Ref を canonical に
  rewrite してからキー化)。元 component は spec 名を保持(畳まない)、aux が元と同形なら元名に畳む。
  **キーに enum_values を含めるのが肝**: discriminator だけ違う union variant(NotificationNote `"note"`
  vs NotificationMention `"mention"`)は .ml 上は同一(enum→string)でも別物として保存——畳むと
  discriminated union が壊れるから。**338→236 schema(102 aux 畳んだ)**、opaque 0/union 5/439 ep 維持。
  決定性・decode・probe 全部緑。

## ✅ 済んだもの (続き6)

- **A7 nullable-ref 回復＋自己参照保持** — 実装済・検証済(`ece0590`)。①フィールドの
  `anyOf/oneOf:[{$ref:X},{null}]`(misskey の nullable ref: Note.reply/renote, DriveFile.folder,
  DriveFolder.parent, pinnedPage… 25件)を `single_ref_member` で Ref に回復(null は A4 が拾う)。
  ②回復で自己参照ができる(この spec は自己ループのみ・相互循環ゼロを SCC で確認)。Resolve が自己参照を
  Json に degrade しないように、emit は自分への Ref を `Module.t` でなく裸の `t` に(`module rec` 不要、
  `[@@deriving json]` が再帰 decoder を生成)。`Note.reply` が `unknown`→`Note` に。
  **ハマり**: `{type:null}` の `type_field` は `None` でなく `Some "null"`(文字列)。null 判定を直した。
  再帰 Note decode 検証＋fixture を nullable→null で再生成。
- **B2 `dune build` 一発化** — 実装済・検証済(`d6f27c3`)。gen/melange/annotate を dune rule に。
  `ml/dune` が spec→.ml/.jsdoc.json 生成→melange.emit、root `dune` が annotate を promote rule で
  source tree に書き戻し。**鍵**: annotate は js を読むだけ(実行しない)→melange runtime symlink hack 不要、
  acorn だけ。build.sh は `dune build`＋「テスト実行用」runtime shim に縮小(find を `*dist/node_modules` に
  絞った)。決定性チェックは2 fresh run 比較に。クリーンビルドから harness 5/5 緑。

## ✅ 済んだもの (続き7)

- **A8 format → JSDoc** — 実装済・検証済(`e71cb26`)。property の `format`(date-time 90件/url/uri/
  id/uuid/md5)を `@property` 行に添える(`createdAt - format: date-time`、doc と併記)。型中立。
  `example/default/minimum` はノイズ気味で見送り。
- **B1 schemas/endpoints ファイル分割** — 実装済・検証済(`8c2a1eb`)。production misskey-api 配置に合わせ
  `componentSchemas.*`(型+accessor)と `endpoints.*`(request+send)に分割。cross-file: ①OCaml は
  endpoints が `open ComponentSchemas` ②JSDoc は参照 schema を
  `@typedef {import('./componentSchemas.annotated.mjs').Note} Note` で再 import→send が bare `Note[]`
  ③runtime は annotate が melange の `./componentSchemas.js` import を promote 名に repoint。emit_jsdoc は
  2メタ、endpoints メタに `imports` 列挙。consumer/probe/decode の import を分けた。クリーンビルド harness
  5/5(probe=cross-file JSDoc 解決、decode=cross-file runtime 結合を実証)。

## いちばん効きそうな次の一手（私の推し順）

(A1 → A4 → A3 → D1 → C1 → A2 → B7 → A5 → A6 → dedup → A7 → B2 → A8 → B1 まで済。
**生成器側はほぼ完成形**: 型カバレッジ(opaque object 0/union/nullable/allOf/自己参照/空req/doc)、
出力 dedup、`dune build` 一発、回帰 harness、git/CI 全部入り。)

**残りは方針決めが要る大物 B3/B6 だけ。** 生成器の中身はやり切った。

1. **B3/B6 production への載せ替え道** (L/要判断) — flat accessor のこの生成器で nested の production
   (`Notes.PostNotesTimeline.send`)を置換するか、emitter を production の Endpoints 形(nested module)に
   寄せるか方針決め。D1 で「allowJs + 生成 import」が要ると判った。packaging(vendored runtime +
   package.json + exports、memory #16/#17 のレシピ流用)とセット。**ここはコードより先に nyanrus と方針。**
2. ☆ **B4 native か melange-to-node か** (M) — npm CLI で配るなら `Openapi.lower` だけ melange-json に
   差し替えて node 実行に(IR/Repr/emitter 不変)。B6 packaging とセットで判断。
3. ☆ **B5 Emit_rescript** (M) — 後回し中の「型だけ ReScript 層」。Repr に席はある。production が
   ReScript なら B3 の載せ替え方式次第で要否が決まる。

---

## A. 生成器の正しさ・カバレッジ（spec に忠実に）

- ✅ **A1 doc コメント** (S): **済**。field.doc → `@property name - desc`、op.description → send 関数の
  JSDoc(IR の op に doc を新設)、`q` を制御文字対応に本格化。詳細は上の「済んだもの」。
- ✅ **A2 空リクエスト op** (M): **済**。当初「GET/query-param op」と書いたが、この spec は
  query/path param も path テンプレートも 0件で、skip の正体は空リクエスト POST 54本だった。
  skip 撤去＋空 req を `unit`/`{}` 特殊化で全 op emit(385→439)。詳細は上の「済んだもの(続き)」。
- ✅ **A4 nullable** (S-M): **済**。`Ir.field` に `nullable` を足したが、JSDoc は `| null` ではなく
  **optional 化**(melange が null→None=undefined に畳むため、それが runtime 形)。
  required-nullable 129 件は decode throw のバグだった。詳細は上の「済んだもの」。
- ✅ **A3 allOf merge** (M): **済**。allOf 4件(UserDetailedNotMe/MeDetailed/Role/MetaDetailed)を
  `$ref` 解決＋フラット化で record に復元。`merged_fields`(openapi.ml)が part の `$ref` を生名で
  spec から引き、ネスト allOf に再帰、`visited` で循環ガード、name で dedup。結果 opaque 9→5・
  record 62→66、UserDetailedNotMe は 65 フィールド(16+49)のフラット record に。runtime decode 検証済
  (UserLite 由来 id と detailed 由来 followersCount を両方持つ)。oneOf/anyOf は引き続き opaque。
- ✅ **D1 kaguya 連携の実証**(PoC) — 実装済・検証済。`kaguya-probe/`(probe.ts + tsconfig.json)。
  kaguya-app の **実 compilerOptions(strict + moduleResolution:Bundler)をそのまま写し**、`lib-src/
  misskey.ts` の timeline 呼び出しを生成 `postNotesTimeline_send` に対して再現。green=実証:
  `unknown[]` が **`Note[]`** に化け、`first.user.username`(nested UserLite)・visibility の閉 union が
  流れ、`@ts-expect-error` 4本(bogus field / union 外 / req 型違い / fetch 型違い)が全部正しく拒否。
  **核の発見**: kaguya の今の tsconfig は **`allowJs` 無し**で、endpoints 層を手書き ambient
  `declare module`(`Promise<unknown[]>`)で型付けしてる。allowJs を切ると probe は TS7016(モジュール=
  any)＋ts-expect-error が全部「未使用」になる=型が流れない。**つまり kaguya 側に必要な変更は
  ちょうど `allowJs: true`**(＋手書き ambient stub を生成 .mjs の import に置換)。生成器が埋めるのは
  まさにこの穴: production `@f3liz/rescript-misskey-api/endpoints` は melange 出力の JS で JSDoc も
  .d.ts も持たない(だから kaguya は stub を手書きしてた)。
  **注**: production は ReScript の nested accessor(`Notes.PostNotesTimeline.send`)、この生成器は
  flat `postNotesTimeline_send`。形が違うので **in-place の production 差し替えは B3 の領域**で、D1 は
  「生成 JSDoc 型が kaguya の TS 設定で load-bearing に流れる」ことの実証に留める(意図的)。
- ✅ **A5 oneOf/anyOf** (M-L): **済**。全メンバー `$ref` の oneOf を JSDoc `A | B` に(3件)。
  インライン object メンバーは opaque 据え置き(Notification/PageBlock、A6 待ち)。詳細は上の「済んだもの(続き3)」。
- ✅ **A6 inline nested object の aux 抽出** (M): **済**。field/array-item/union-member を
  名前付き aux に hoist、opaque object 0 に。詳細は上の「済んだもの(続き4)」。〔旧メモ↓〕
  `Error.error` 等のインライン object を
  名前付き補助 schema に hoist して構造を復元(production の "aux抽出" 相当)。今は `unknown`。
- ✅ **A7 自己参照** (L): **済**。nullable-ref(field 級 anyOf)を回復＋自己参照を裸 `t` で保持
  (相互循環ゼロなので `module rec` 不要)。`Note.reply` が `unknown`→`Note`。詳細は上の「続き6」。
- ✅ **A8 format** (S): **済**。`format`(date-time/url/id/uuid…)を `@property` に添える。詳細は「続き7」。
- ☆ **A9 204/非JSON応答** (S): 今 Json 落ち。204 → `void`/`unit` 相当に。
- ☆ **A10 enum の名前付き typedef 化** (S): 同じ enum(visibility 等)が各所でインライン union 重複。
  共通 enum を名前付き typedef に hoist で DRY。
- ☆ **A11 op 名の衝突チェック** (S): `camel(operationId)` のユニーク性を assert、衝突時に suffix。

## B. アーキテクチャ・製品化

- ✅ **B1 ファイル分割** (M): **済**。ComponentSchemas/Endpoints に分割、cross-file は
  `open` ＋ `import('./componentSchemas.annotated.mjs').Note` 再 import で繋いだ。詳細は「続き7」。
- ✅ **B2 dune rule で一発化** (S-M): **済**。`dune build` だけで annotated JS まで(promote rule)。
  詳細は上の「続き6」。
- **B3 既存 ReScript 生成器との整合** (L/要判断): これは `rescript-autogen-openapi` の
  **OCaml ネイティブ移植**(memory task #12)の実体。あちらは multi-fork/SharedBase/IR が既にある。
  この skeleton で置換するのか、あちらの IR を OCaml 化して emitter だけ移すのか、方針決め。
- **B4 native か melange-to-node か** (M): 今 native OCaml + yojson。npm CLI で配るなら
  `Openapi.lower` だけ melange-json に差し替えて node 実行に(IR/Repr/emitter は不変)。
- **B5 Emit_rescript** (M): 後回し中の「型だけ ReScript 層」。Repr に席はある。
- **B6 packaging** (M): vendored runtime + package.json + exports + npm scripts。memory #16/#17 の
  vendoring レシピを流用。`build.sh` の node_modules relink hack を本物に。
- **B7 git init** (S): まだしてない。

## C. テスト・堅牢性

- ★ **C1 ゴールデン/回帰テスト** (M): 今手で回してる証明(gen compile / melange compile /
  annotate 成功 / tsc が**意図した診断だけ**出す / runtime decode)を自動化。CI 化。
- **C2 他 spec で一般性確認** (S): `rescript-autogen-openapi/examples/fixtures` の petstore で回す。
- **C3 出力の決定性** (S): 同じ spec で byte 同一の出力か(toposort/Hashtbl の順序)。clean diff 用。

## D. 本丸＝kaguya 連携

- ★ **D1 一経路を載せ替え** (M): 生成 send を kaguya の手書き ambient 型の代わりに一本差して、
  実 build(svelte-check/vite)で型が流れるか実証。memory #17 の続き。
- **D2 手書き ambient との差分監査** (S): kaguya の `types/global.d.ts` と生成型を突き合わせ、
  欠け/食い違いを洗う。
- **D3 apiFetch 合流** (S): kaguya の token 注入 + null-strip する fetch wrapper と、生成 send の
  `fetch:(path,body)=>Promise<json>` が噛むか確認。null-omit は emit が既に
  `[@json.option][@json.drop_default]` を出してるので OK のはず(run-endpoint で {} → 省略を確認済)。

## E. 細かい磨き

- ☆ **E1 op 名の短縮/tag ネスト** (S): `postAdminAbuse...` が長い。tag グループ(Admin.X.create)化は
  flat accessor の clean さと trade-off。要検討。
- ☆ **E2 `unknown` vs `any`** : 今 `unknown`(narrow 強制で安全)。維持。
- ☆ **E3 メタ JSON の完全エスケープ** : A1(description 流入)とセットで `q` を堅く。

---

## ひとこと

この repo の魂は「型が `.js` を開いた人に届く」こと。だから純粋なカバレッジ(A2/A3/A5)より、
**A1(description を流す)** が実は一番その魂に近い。次の半日があるなら A1 → A4 → D1 の順が、
「正しくて、親切で、意味がある」を一番短く満たす気がする。
