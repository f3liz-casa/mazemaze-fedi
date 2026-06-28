#!/usr/bin/env bash
# Build the Melange decoder layer (melange/*.ml -> JS) and vendor the emitted
# JS next to the ReScript type layer (src/melange-api/melange-dist), so the
# `@module` externals in ComponentSchemas.res / Endpoints.res resolve at both
# rescript-compile time and consumer runtime. The vendored dist carries its own
# node_modules (melange-json + melange runtime) for the bare-specifier imports.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v opam >/dev/null 2>&1; then
  echo "build-melange: opam not found; need the Melange toolchain (opam + dune)." >&2
  exit 1
fi
eval "$(opam env)"

cd "$HERE/melange"
dune build

DEST="$HERE/src/melange-api/melange-dist"
rm -rf "$DEST"
cp -R "$HERE/melange/_build/default/dist" "$DEST"

# Splice JSDoc into the flat melange .js (from the generator's metadata) so a TS
# consumer importing the flat layer (./melange-endpoints) gets real types —
# Promise<Note[]> instead of unknown[]. Needs acorn (devDependency). The schema
# sibling here is ComponentSchemas.js (melange-dist's own name).
if [ -f "$HERE/scripts/annotate.mjs" ] && [ -f "$HERE/melange/ComponentSchemas.jsdoc.json" ]; then
  for mod in ComponentSchemas Endpoints; do
    node "$HERE/scripts/annotate.mjs" \
      "$DEST/$mod.js" "$HERE/melange/$mod.jsdoc.json" "ComponentSchemas.js" > "$DEST/$mod.js.tmp"
    mv "$DEST/$mod.js.tmp" "$DEST/$mod.js"
  done
  echo "build-melange: spliced JSDoc into melange-dist/{ComponentSchemas,Endpoints}.js"
fi

# The vendored Melange/melange-json runtime packages ship as bare directories of
# .js files with NO package.json. Node's ESM resolver is happy to read a subpath
# file out of such a directory (e.g. `melange.js/caml_option.js`), but Rollup /
# Vite refuse to treat a node_modules entry as a package without a package.json,
# so a consumer bundle (kaguya) fails to resolve those bare specifiers. Drop a
# minimal ESM package.json into each so both resolvers agree.
VENDORED="$DEST/node_modules"
if [ -d "$VENDORED" ]; then
  for pkg in "$VENDORED"/*/; do
    name="$(basename "$pkg")"
    if [ ! -f "$pkg/package.json" ]; then
      printf '{\n  "name": "%s",\n  "type": "module"\n}\n' "$name" > "$pkg/package.json"
    fi
  done
fi
echo "build-melange: vendored Melange dist -> src/melange-api/melange-dist"
