# @f3liz/mazemaze-generator

An OCaml-native code generator that turns an OpenAPI spec into **one Melange
runtime with three natural surfaces** — Melange, ReScript, and TypeScript. One
set of `[@@deriving json]` decoders does the work; the three languages each get
an idiomatic typed view onto it, sourced from a single IR so they cannot drift:

- **Melange** — flat decoders + a `Misskey` convenience layer of labeled-optional
  wrappers (`Misskey.Notes.create client ~text:"hi" ()`).
- **ReScript** — a nested `.res` binding layer (`Notes.PostNotesTimeline.send`)
  with optional record fields (`{text: "hi"}`).
- **TypeScript** — the same JS, with **JSDoc types in the file itself**, so a
  consumer gets real types (`Promise<Note[]>`) by opening the `.js` — no sidecar
  `.d.ts`.

It replaces `rescript-autogen-openapi`'s generated layers (no Sury, no drift) and
supersedes the `melange-autogen-spike` (whose hand-written target shape is now
generated).

## Pipeline

```
OpenAPI(JSON)
  │  Openapi.lower        spec tree -> Ir.t
  │  Resolve.run          toposort + break cycles to opaque Json
  ▼
 Ir.t ──> Emit_melange    -> componentSchemas.ml + endpoints.ml  (types/accessors ; send wrappers)
      └─> Emit_jsdoc      -> {componentSchemas,endpoints}.jsdoc.json  (the metadata contract)
  │  dune + melange (es6)
  ▼
 componentSchemas.js   endpoints.js (imports ./componentSchemas.js)
  │  annotate.mjs (acorn) : synthesise @typedef + structurally join accessor/send @type (fail-loud)
  ▼
 componentSchemas.annotated.mjs   endpoints.annotated.mjs   <- ship these
```

Schemas and endpoints are split (B1): `endpoints` `open ComponentSchemas` on the
OCaml side and re-imports each referenced typedef as
`@typedef {import('./componentSchemas.annotated.mjs').Note} Note` on the JSDoc
side, so a send's `Promise<Note[]>` resolves across the file boundary.

`Repr` is the single source of the mapping rules (`ocaml_type` / `jsdoc_type` /
`accessor` name). Every emitter calls it, which is what keeps the Melange code,
the JSDoc, and any future ReScript layer in agreement.

## Run

```sh
dune build                 # gen -> melange -> annotate -> promote, one shot
./build.sh                 # dune build + the runtime shim so tests can RUN the output
npm test                   # the full regression harness (test/run.sh)
npx tsc -p tsconfig.json   # consumer.ts type-checks against the generated types
```

The spec is wired into `ml/dune` (`specs/misskey.json`); point it elsewhere by
editing that rule.

## Status

Works end-to-end on the real misskey spec.

Schemas (71): 62 records, 9 opaque fallbacks (allOf/oneOf), cross-type refs kept
precise, property-level enums emitted as string-literal unions.

Endpoints (385): each inline-request operation becomes a `<op>_send fetch req`
wrapper (encode request -> injected fetch -> decode response) plus a request
typedef; a shared `Fetch` typedef types the injected fetch. `tsc` confirms
request / `Fetch` / `Promise<Response>` all flow (responses resolve to the
component typedefs); a send drives a stub fetch and decodes at runtime.

`annotate.mjs` reads real param names from the AST, so Melange mangling
(`fetch` -> `$$fetch`, a JS global) is handled without guessing.

Stubbed / reserved seats:
- `Emit_rescript` (types-only ReScript layer) — deferred by design.
- GET / query-parameter operations (no JSON body) are skipped (54 of 439 ops).
- inline nested objects, oneOf/anyOf/allOf -> opaque `Melange_json.t` (no aux
  hoisting / `module rec` yet, so cyclic refs degrade to `unknown`).
- schemas + endpoints share one file to keep typedefs local; production would
  split files (and use `import(...)` JSDoc refs or a bundler).
- the node_modules relink in `build.sh` is a skeleton hack; a published package
  would vendor the melange runtime with package.json.
