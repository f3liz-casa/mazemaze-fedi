# @f3liz/mazemaze-api-bluesky

Typed Bluesky (atproto `app.bsky`) API client — **one Melange runtime with three
surfaces** (ReScript, TypeScript-via-JSDoc, Melange), generated from the
[`endpoints.bsky.app`](https://endpoints.bsky.app/#bluesky-app)
`openapi.bluesky-app.json` (OpenAPI 3.1) by
[`@f3liz/mazemaze-generator`](../generator).

```sh
npm run generate   # regenerate from specs/schema.json via the generator
npm run build      # melange -> JSDoc'd dist + rescript .res -> .res.mjs
```

Exports: `./endpoints`, `./components` (ReScript), `./melange-endpoints`,
`./melange-components` (flat, JSDoc-typed for TS).

> Coverage note: atproto's lexicon-derived schemas lean on `$type`-discriminated
> unions, cross-lexicon `#defs` refs, and empty marker objects. The surface is
> typed (484 schemas → 372 records, 18 enums, 77 type aliases, 2 unions; e.g.
> `getProfile -> ProfileViewDetailed` with `did`/`handle`/… typed). atproto
> "token" unions (`listPurpose`) decode as a runtime `string`; only 15 schemas —
> atproto's empty marker objects (`{}`, no fields to type) — stay `unknown`.
