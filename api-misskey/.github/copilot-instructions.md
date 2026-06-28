# Copilot Instructions for @f3liz/rescript-misskey-api

## Overview

ReScript Misskey API client with a **dual-layer architecture**: hand-crafted high-level wrappers (`Misskey.res`, `Cherrypick.res`) over auto-generated OpenAPI bindings. Supports both Misskey and Cherrypick (fork) instances.

## Build & Test

```bash
npm run build        # rescript compile + tsc (TypeScript wrapper)
npm run clean        # rescript clean + rm -rf lib/ts
npm run watch        # rescript build -w (ReScript only, no tsc)
npm run generate     # regenerate src/generated/ from live OpenAPI specs
npm test             # rescript (compile check — no runtime tests)
```

The build is two-phase: `rescript` compiles `.res` → `.mjs` under `lib/es6/`, then `tsc` compiles TypeScript wrappers to `lib/ts/`.

Regenerating bindings (`npm run generate`) fetches live specs from `misskey.io` and `kokonect.link` and runs `@f3liz/rescript-autogen-openapi` to produce `src/generated/`.

## Architecture

### Dual-Layer Design

1. **High-Level API** (`Misskey.res`, `Cherrypick.res`) — hand-crafted wrappers for common tasks (notes, streaming, auth). These inject tokens, handle JSON serialization, and provide a simple pipe-first API. This is what most users interact with.

2. **Full Generated API** (`src/generated/misskey-io/`, `src/generated/kokonect-link/`) — auto-generated from OpenAPI specs via `@f3liz/rescript-autogen-openapi`. Provides 100% endpoint coverage with strict types. Users can "bridge" from high-level to generated via `Misskey.wrapperConnect`.

### Streaming (src/stream/)

Native WebSocket implementation for Misskey's streaming API:
- `StreamConnection.res` — WebSocket connection management
- `StreamClient.res` — channel subscription and message routing
- `StreamProtocol.res` — Misskey streaming protocol types
- `NativeStreamBindings.res` — low-level WebSocket bindings

### TypeScript Layer

- `src/Misskey.ts` — high-level TypeScript wrapper class (mirrors ReScript API)
- `tsconfig.json` — compiles `src/**/*.ts` to `lib/ts/` with declarations
- Main entry: `lib/ts/Misskey.js` + `lib/ts/Misskey.d.ts`

## Conventions

- **Do NOT edit `src/generated/`** — these files are auto-generated. Run `npm run generate` to update them.
- **ReScript 12 + ESM only** — all output is `.mjs`
- **`sury`** is a runtime dependency — generated schemas use it for validation
- **Fork pattern** — `Misskey.res` and `Cherrypick.res` share the same API surface. When adding features to one, add to both.
- **rescript.json sources** — subdirectories are explicitly listed (not `"subdirs": true` at root) because `src/generated/` has deep nesting
- **Warning `+101`** is set to error — unused `open` statements are compile errors
- **FetchBindings** — `Misskey.res` uses raw `@val external` bindings to browser `fetch`, not a library. The fetch function is injectable via `~fetch` parameter for testability.
