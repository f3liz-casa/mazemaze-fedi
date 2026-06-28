# Using the generated layer — and where it needs boilerplate

The generator emits one runtime (the flat Melange JS + its `[@@deriving json]`
codecs) and two surfaces onto it:

| Consumer    | imports                          | shape                                   |
|-------------|----------------------------------|-----------------------------------------|
| **Melange** | `Endpoints` / `ComponentSchemas` (`.ml`) | flat: `postNotesTimeline_send fetch req` |
| **ReScript**| `Endpoints.res` / `ComponentSchemas.res` | nested: `Notes.PostNotesTimeline.send(fetch, req)` |
| **TypeScript** | `endpoints.annotated.mjs` (JSDoc) | flat, JSDoc-typed: `postNotesTimeline_send(fetch, req)` |

Each example here does the same task: read a timeline (typed `Note[]`, touch
`note.user.username` + the nullable `note.text`) and create a note with just text.

## The two rough edges

**1. The transport seam.** Every generated `send` takes a `fetch : (method, url, body)
=> promise<json>` — the send already built the full URL (path substitution + query
string) and picks the HTTP method. Encode/decode is generated, transport is the
caller's. But threading a bare `fetch` through every call is noise. Fix (all three
languages): a tiny **client** that holds `origin`/`token` and produces the `fetch`.
This is genuine boilerplate and belongs in every example.

**2. The all-`option` request record.** A request type is every body field as an
optional:

```
PostNotesCreate.request = { text: option, visibility: option, cw: option, … ×19 }
```

To send *just text* you must still write the other 18 as `None`. This is the real
friction, and it lands hardest on the two surfaces that should be most natural:

| Consumer    | sending just text                                        | verdict |
|-------------|----------------------------------------------------------|---------|
| TypeScript  | `send(fetch, { text: "hi" })`                            | natural — JSDoc optional props let you omit the rest |
| ReScript    | `send(fetch, { text: Some("hi"), visibility: None, …×18 })` | painful |
| **Melange** | `send fetch { text = Some "hi"; visibility = None; …×18 }` | painful — and it's the base |

## Filling it — Melange first (now implemented)

Since the project is Melange-based, the **canonical, most-natural API is Melange's**,
and the generator now **emits it**: `misskey.ml` — a `Client` plus, per tag, a
labeled-optional wrapper per op.

```ocaml
Misskey.Notes.create client ~text:"hi" ()      (* not a 19-field record *)
Misskey.Notes.timeline client ~limit:20 ()
```

This is mechanical, not hand-waving: an optional field becomes a `?field` argument
and a required field a `~field` one, each **punning straight onto the record field** —

```ocaml
let create (client : Client.t) ?visibility ?text … () =
  Endpoints.postNotesCreate_send client.transport { Endpoints.PostNotesCreate.visibility; text; … }
```

so `Emit_sugar` writes one wrapper for every op (action name = the opId with the
method + tag stripped: `create`, `timeline`, …). The `Client` carries the transport
and does the **one small runtime conversion** — prefix `/api`, inject the token as
misskey's `i` — over an injected JSON `post`.

**ReScript** is natural for free: the generated `.res` request types now use
**optional record fields** (`text?: string`), so

```rescript
Notes.PostNotesCreate.send(client.transport, {text: "hi"})   // omit the rest
```

The compiled JS is identical (an omitted optional field is an absent key, which the
melange decoder reads back as `None`), so the binding is unchanged.

**TypeScript** needs nothing beyond the client — JSDoc optional properties already
make `{ text: "hi" }` type-check, and responses come back as real types
(`Note[]`, nested `UserLite`, nullable `text`). It just imports the **flat JSDoc
`.js`**, not the ReScript-compiled `.res.mjs` (which ships no TS types).

## What was implemented

- **`gen/emit_sugar.ml`** → `misskey.ml`: `Client` + per-tag labeled-optional
  wrappers. Compiled by melange in the main build.
- **`gen/emit_rescript.ml`**: request/schema records now emit ReScript optional
  record fields (`field?: ty`).
- TypeScript already rode the flat JSDoc layer; the example shows the one client helper.

The transport seam (a `Client` from origin/token over an injected `post`) is the only
remaining per-call-free boilerplate, and the small runtime conversion lives there.

## Verification status (all green)

- `melange/Example.ml` — compiles with melange against the generated `Misskey` /
  `Endpoints` / `ComponentSchemas`. ✅
- `rescript/Example.res` — compiles (`rescript`) against the generated `.res`,
  using the natural `{text: "hi"}` form. ✅
- `typescript/example.ts` — type-checks (`tsc`, allowJs) against
  `endpoints.annotated.mjs`. ✅
