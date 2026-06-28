#!/usr/bin/env bash
# Generate the Melange-backed typed layer for the Mastodon API with
# mazemaze-generator:
#   melange/{ComponentSchemas,Endpoints}.ml            (Melange decoders)
#   src/melange-api/{ComponentSchemas,Endpoints}.res   (ReScript type layer)
#   melange/*.jsdoc.json + scripts/annotate.mjs        (for build-melange's JSDoc)
#
# The generator is a sibling checkout by default; override with GENERATOR.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
GENERATOR="${GENERATOR:-$HERE/../generator}"
SPEC="${SPEC:-$HERE/specs/schema.json}"

if [ ! -d "$GENERATOR/gen" ]; then
  echo "generate-melange: generator not found at $GENERATOR (set GENERATOR)." >&2
  exit 1
fi
eval "$(opam env)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

( cd "$GENERATOR" && dune build ./gen/driver.exe && dune exec ./gen/driver.exe -- "$TMP" "$SPEC" )

cp "$TMP/componentSchemas.ml" "$HERE/melange/ComponentSchemas.ml"
cp "$TMP/endpoints.ml"        "$HERE/melange/Endpoints.ml"
cp "$TMP/ComponentSchemas.res" "$HERE/src/melange-api/ComponentSchemas.res"
cp "$TMP/Endpoints.res"        "$HERE/src/melange-api/Endpoints.res"
cp "$TMP/componentSchemas.jsdoc.json" "$HERE/melange/ComponentSchemas.jsdoc.json"
cp "$TMP/endpoints.jsdoc.json"        "$HERE/melange/Endpoints.jsdoc.json"
cp "$GENERATOR/annotate.mjs"          "$HERE/scripts/annotate.mjs"

echo "generate-melange: regenerated melange/*.ml + src/melange-api/*.res (+ jsdoc meta) via mazemaze-generator"
