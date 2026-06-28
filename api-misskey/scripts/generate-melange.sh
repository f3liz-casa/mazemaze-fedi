#!/usr/bin/env bash
# Regenerate the Melange-backed typed layer using mazemaze-generator (the OCaml
# generator), replacing @f3liz/rescript-autogen-openapi for this layer.
#
#   melange/ComponentSchemas.ml   melange/Endpoints.ml        (Melange decoders)
#   src/melange-api/ComponentSchemas.res   .../Endpoints.res  (ReScript type layer)
#
# The generator is a sibling checkout by default; override with JSDOC_GEN.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
JSDOC_GEN="${JSDOC_GEN:-$HERE/../generator}"
SPEC="${SPEC:-$JSDOC_GEN/specs/misskey.json}"

if [ ! -d "$JSDOC_GEN/gen" ]; then
  echo "generate-melange: mazemaze-generator not found at $JSDOC_GEN (set JSDOC_GEN)." >&2
  exit 1
fi
eval "$(opam env)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# build + run the generator
( cd "$JSDOC_GEN" && dune build ./gen/driver.exe && dune exec ./gen/driver.exe -- "$TMP" "$SPEC" )

# place the Melange layer (rename to the package's PascalCase filenames; the
# module names are unchanged — OCaml only capitalises the first letter anyway)
cp "$TMP/componentSchemas.ml" "$HERE/melange/ComponentSchemas.ml"
cp "$TMP/endpoints.ml"        "$HERE/melange/Endpoints.ml"

# place the ReScript type layer
cp "$TMP/ComponentSchemas.res" "$HERE/src/melange-api/ComponentSchemas.res"
cp "$TMP/Endpoints.res"        "$HERE/src/melange-api/Endpoints.res"

# the JSDoc metadata + the annotator: build-melange.sh splices these into the
# compiled melange-dist .js so consumers (kaguya) get real types from the flat
# layer. Vendor them so the build stays self-contained (no jsdoc-gen at build).
cp "$TMP/componentSchemas.jsdoc.json" "$HERE/melange/ComponentSchemas.jsdoc.json"
cp "$TMP/endpoints.jsdoc.json"        "$HERE/melange/Endpoints.jsdoc.json"
cp "$JSDOC_GEN/annotate.mjs"          "$HERE/scripts/annotate.mjs"

echo "generate-melange: regenerated melange/*.ml + src/melange-api/*.res (+ jsdoc meta) via mazemaze-generator"
