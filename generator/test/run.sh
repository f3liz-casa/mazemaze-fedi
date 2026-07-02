#!/usr/bin/env bash
# Regression harness: the proofs we used to run by hand, in one fail-loud pass.
#   build -> determinism -> consumer diagnostics -> kaguya probe -> runtime decode
# Exits non-zero if any proof regresses.
set -uo pipefail
cd "$(dirname "$0")/.."
eval "$(opam env)"

pass=0 fail=0
ok()   { echo "  PASS: $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail+1)); }

echo "[1/7] build pipeline"
if ./build.sh >/tmp/mjg-build.log 2>&1; then ok "build.sh (gen -> melange -> annotate)"
else bad "build.sh failed"; cat /tmp/mjg-build.log; fi

echo "[2/7] determinism (same spec -> byte-identical generator output)"
# Generate twice to scratch dirs and diff: the .ml lives only in _build now (B2),
# so we compare two fresh runs rather than a source-tree copy.
s1="$(mktemp -d)" s2="$(mktemp -d)"
dune exec ./gen/driver.exe -- "$s1" specs/misskey.json >/dev/null 2>&1
dune exec ./gen/driver.exe -- "$s2" specs/misskey.json >/dev/null 2>&1
if diff -rq "$s1" "$s2" >/dev/null
then ok "generator output is deterministic (all 6 files)"
else bad "generator output changed between runs (non-deterministic ordering)"; fi
rm -rf "$s1" "$s2"

echo "[3/7] consumer.ts emits exactly the intended misuse diagnostics"
out="$(npx tsc --noEmit -p tsconfig.json 2>&1)"
n="$(printf '%s\n' "$out" | grep -c 'error TS')"
if [ "$n" -eq 3 ] \
   && printf '%s' "$out" | grep -q 'TS2322' \
   && printf '%s' "$out" | grep -q 'TS2339' \
   && printf '%s' "$out" | grep -q 'TS2345'
then ok "consumer.ts: exactly the 3 intended diagnostics (TS2322/2339/2345)"
else bad "consumer.ts diagnostics drifted (got $n):"; printf '%s\n' "$out"; fi

echo "[4/7] kaguya probe: generated JSDoc types flow under kaguya's tsconfig"
if npx tsc --noEmit -p kaguya-probe/tsconfig.json >/tmp/mjg-probe.log 2>&1
then ok "kaguya-probe green (Note[] flows; oneOf union typed; misuses rejected)"
else bad "kaguya-probe regressed:"; cat /tmp/mjg-probe.log; fi

echo "[5/7] runtime decode (A4 null path + A3 merged record)"
if node test/decode.mjs; then ok "runtime decode"; else bad "runtime decode regressed"; fi

echo "[6/7] ReScript binding layer (.res compiled by build.sh; nested send binds to flat melange)"
if [ -f res/src/Endpoints.res.mjs ] && [ -f res/src/ComponentSchemas.res.mjs ]
then ok ".res compiled to .res.mjs"
else bad ".res did not compile"; fi
nmods="$(grep -cE '^module ' res/src/Endpoints.res 2>/dev/null || echo 0)"
nsend="$(grep -c 'external send' res/src/Endpoints.res 2>/dev/null || echo 0)"
if [ "$nmods" -eq 28 ] && [ "$nsend" -eq 439 ]
then ok "Endpoints.res shape: 28 tag modules, 439 sends (matches production)"
else bad "Endpoints.res shape drifted (modules=$nmods sends=$nsend; want 28/439)"; fi
if node test/res_roundtrip.mjs; then ok "nested .res send round-trip"; else bad "nested .res round-trip failed"; fi

echo "[7/7] the three consumers are natural (examples compile against the generated layer)"
# Melange: the labeled-optional convenience layer (Misskey) + a consumer.
cp examples/melange/Example.ml ml/exampleConsumer.ml
if dune build ml >/tmp/mjg-ex-ml.log 2>&1
then ok "melange example: Misskey.Notes.create client ~text:\"hi\" ()"
else bad "melange example failed:"; cat /tmp/mjg-ex-ml.log; fi
rm -f ml/exampleConsumer.ml
# ReScript: the natural {text: \"hi\"} form against the generated .res.
cp examples/rescript/Example.res res/src/Example.res
if npx rescript build res >/tmp/mjg-ex-res.log 2>&1
then ok "rescript example: Notes.PostNotesCreate.send(_, {text: \"hi\"})"
else bad "rescript example failed:"; cat /tmp/mjg-ex-res.log; fi
rm -f res/src/Example.res res/src/Example.res.mjs res/lib/bs/src/Example.* 2>/dev/null
# TypeScript: the flat JSDoc layer.
if npx tsc --noEmit -p examples/typescript/tsconfig.json >/tmp/mjg-ex-ts.log 2>&1
then ok "typescript example: postNotesCreate_send(_, {text: \"hi\"}) -> typed"
else bad "typescript example failed:"; cat /tmp/mjg-ex-ts.log; fi

echo
echo "── $pass passed, $fail failed ──"
[ "$fail" -eq 0 ]
