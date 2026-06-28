# @f3liz/mazemaze

The umbrella entry for the **mazemaze** family — a stable import that re-exports
the Misskey client so consumers don't pin the underlying package name.

```js
import { ... } from "@f3liz/mazemaze";                 // convenience API
import { Notes } from "@f3liz/mazemaze/endpoints";     // nested typed endpoints
import * as C from "@f3liz/mazemaze/components";        // schema codecs
import { postNotesTimeline_send } from "@f3liz/mazemaze/melange-endpoints"; // flat, JSDoc-typed
```

Each entry re-exports the matching one of
[`@f3liz/mazemaze-api-misskey`](../api-misskey). Type-flow follows the source:
the `melange-*` entries carry JSDoc types when the consumer enables `allowJs`.

## The family

| Package | What |
|---|---|
| `@f3liz/mazemaze` | this umbrella — re-exports the client |
| `@f3liz/mazemaze-api-misskey` | the typed Misskey client (one Melange runtime, three surfaces) |
| `@f3liz/mazemaze-generator` | the OCaml generator that produces the client |
