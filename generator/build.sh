#!/usr/bin/env bash
# Build the annotated module. With B2 the whole pipeline (generator -> Melange
# ESM -> JSDoc annotate -> promote to source tree) is a single `dune build`;
# this script just adds the runtime-resolution shim so the PROMOTED module can
# also be *run* by the tests (run.mjs / test/decode.mjs import the melange
# runtime). Building alone needs none of that — annotate only reads the JS.
set -euo pipefail
cd "$(dirname "$0")"
eval "$(opam env)"

# 1. gen -> melange -> annotate(promote), all under dune (spec fixed in ml/dune)
dune build

# 2. make the vendored melange runtime resolvable as ESM packages so node can
#    execute the promoted module (skeleton hack; a real package would vendor
#    these with package.json — see misskey-api #16/#17)
# the melange runtime lives under the emit's dist/ (a sibling acorn node_modules
# now also exists from the annotate rule's deps — match dist/ specifically)
NMROOT="$PWD/$(find _build -type d -path '*dist/node_modules' | head -1)"
for pkg in melange-json melange.js melange melange.__private__.melange_mini_stdlib; do
  d="$NMROOT/$pkg"
  [ -d "$d" ] || continue
  [ -f "$d/package.json" ] || printf '{"name":"%s","type":"module"}\n' "$pkg" > "$d/package.json"
  ln -sfn "$d" "node_modules/$pkg"
done

# 3. ReScript binding layer (.res): generate into the rescript project, copy the
#    melange JS + runtime in as the @module target, and compile to .res.mjs.
RESGEN="$(mktemp -d)"
dune exec ./gen/driver.exe -- "$RESGEN" specs/misskey.json >/dev/null
mkdir -p res/src/melange-dist
cp "$RESGEN"/ComponentSchemas.res "$RESGEN"/Endpoints.res res/src/
rm -rf "$RESGEN"
# the @module("./melange-dist/*.js") runtime: the JSDoc-annotated modules + the
# melange runtime, so the compiled .res.mjs can actually be run.
# the .res externals import ./melange-dist/{ComponentSchemas,Endpoints}.js; the
# annotated Endpoints module imports its schema sibling by its B1-promoted name,
# so provide both names (same file).
cp componentSchemas.annotated.mjs res/src/melange-dist/ComponentSchemas.js
cp componentSchemas.annotated.mjs res/src/melange-dist/componentSchemas.annotated.mjs
cp endpoints.annotated.mjs res/src/melange-dist/Endpoints.js
printf '{"type":"module"}\n' > res/src/melange-dist/package.json  # the .js are ESM
ln -sfn "$NMROOT" res/src/melange-dist/node_modules
./node_modules/.bin/rescript build res >/dev/null

echo "OK -> componentSchemas.annotated.mjs, endpoints.annotated.mjs, res/src/*.res.mjs"
