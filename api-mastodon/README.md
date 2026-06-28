# @f3liz/mazemaze-api-mastodon

Typed Mastodon API client — **one Melange runtime with three surfaces**
(ReScript, TypeScript-via-JSDoc, Melange), generated from the
[abraham/mastodon-openapi](https://github.com/abraham/mastodon-openapi)
`schema.json` by
[`@f3liz/mazemaze-generator`](../generator).

```sh
npm run generate   # regenerate from specs/schema.json via the generator
npm run build      # melange -> JSDoc'd dist + rescript .res -> .res.mjs
```

Exports: `./endpoints`, `./components` (ReScript), `./melange-endpoints`,
`./melange-components` (flat, JSDoc-typed for TS).

> Mastodon templates paths (`/api/v1/accounts/{id}`); the generator now takes the
> path parameters as required request fields and substitutes them, so
> `getAccount(fetch, {id: "123"})` hits `/api/v1/accounts/123`. Query parameters
> (`limit`, `offset`, …) are not yet appended to the URL — a planned follow-up.
