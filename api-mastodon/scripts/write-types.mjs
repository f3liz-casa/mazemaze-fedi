#!/usr/bin/env node
// Copies hand-written type declarations into melange-dist/ so tsc can
// type-check Mastodon.ts without processing the melange runtime.
// Runs as build:write-types after build:melange (which wipes melange-dist/).
import { copyFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = join(root, "src", "melange-api-types", "Endpoints.d.ts");
const dst = join(root, "src", "melange-api", "melange-dist", "Endpoints.d.ts");

copyFileSync(src, dst);
console.log("write-types: copied Endpoints.d.ts -> melange-dist/");
