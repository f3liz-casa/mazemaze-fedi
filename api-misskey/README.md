# @f3liz/rescript-misskey-api

Type-safe Misskey API bindings for ReScript and TypeScript, generated from OpenAPI specs.

Supports Misskey instances. All endpoints are fully typed.

## Usage

### TypeScript

```typescript
import { connect, Notes, Stream, MiAuth } from '@f3liz/rescript-misskey-api'

const client = connect("https://misskey.io", "your-token")

// Post a note
await Notes.create(client, "Hello, Misskey!")

// Read timeline
const result = await Notes.fetch(client, "home", 20)
if (result.TAG === "Ok") console.log(result._0)

// Stream timeline
const sub = Stream.timeline(client, "home", note => {
  console.log("New note!", note)
})
// sub.dispose() to unsubscribe

// MiAuth authentication
const session = MiAuth.generateUrl("https://misskey.io", "MyApp", ["write:notes"])
MiAuth.openUrl(session.authUrl)

// Antenna / list / channel timelines use polymorphic variant objects:
const antennaNotes = await Notes.fetch(client, { NAME: "antenna", VAL: "antenna-id" })
const streamSub = Stream.timeline(client, { NAME: "list", VAL: "list-id" }, onNote)
```

### ReScript

```rescript
let client = Misskey.connect("https://misskey.io", ~token="your-token")

// Post a note
await client->Misskey.Notes.create("Hello, Misskey!", ())

// Read timeline
let notes = await client->Misskey.Notes.timeline(#home, ~limit=20, ())
```

## Installation

```bash
npm install @f3liz/rescript-misskey-api
```

If you are using ReScript, add to your `rescript.json`:

```json
{
  "dependencies": ["@f3liz/rescript-misskey-api"]
}
```

## Architecture

Two layers:

1. **High-level API** (`Misskey`, `Cherrypick`): Simplified wrappers for common operations (notes, timeline, streaming).

2. **Generated API** (`MisskeyIoWrapper`, `KokonectLinkWrapper`): Complete bindings for all 400+ endpoints, auto-generated from OpenAPI specs.

## Advanced Usage

### Full Generated API (ReScript)

Access any endpoint not covered by the high-level wrapper:

```rescript
let wrapperClient = Misskey.connect("...")->Misskey.wrapperConnect

open MisskeyIoWrapper
let result = await Admin.postAdminShowUser({userId: "..."}, ~client=wrapperClient)
```

### Cherrypick

```rescript
let client = Cherrypick.connect("https://kokonect.link", ~token="...")
await client->Cherrypick.Notes.create("Hello Cherrypick!", ())
```

## Regenerating Bindings

To update bindings from the latest OpenAPI specs:

```bash
npm run generate
```

Fetches specs from `misskey.io` and `kokonect.link` and regenerates `src/generated/`.

## License

MIT