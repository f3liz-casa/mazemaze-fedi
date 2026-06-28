// JSDoc post-processor (sketch).
//
// Input : Melange ESM output (.js) + the deriver/generator metadata (.json).
// Output: the SAME .js with JSDoc @typedef blocks + @type annotations spliced in.
//
// Two principles we settled on:
//   1. typedefs are SYNTHESISED from metadata (types are erased from JS, so they
//      are not matched to any node) — no fragility.
//   2. accessor annotations are joined STRUCTURALLY via the real AST (acorn),
//      keyed on the clean flat-accessor name, and we FAIL LOUD if metadata names
//      an accessor the JS does not export. No regex, no silent skip.

import { readFileSync } from "node:fs";
import * as acorn from "acorn";

const [, , jsPath, metaPath, schemaModuleArg] = process.argv;
const src = readFileSync(jsPath, "utf8");
const meta = JSON.parse(readFileSync(metaPath, "utf8"));

// The Endpoints file links to the schemas by this name at both the runtime-import
// and JSDoc-alias level. Default is jsdoc-gen's promoted layout; an annotator over
// a different layout (e.g. a melange-dist with `ComponentSchemas.js`) passes its
// own name as the 3rd arg.
const SCHEMA_MODULE = schemaModuleArg || "componentSchemas.annotated.mjs";

// --- description helpers ----------------------------------------------------
// `*/` would close the JSDoc comment early; never let doc prose do that.
const safe = (s) => s.replace(/\*\//g, "* /");
// a multi-line description -> ` * <line>` JSDoc body lines (one per source line).
const docBlock = (doc) =>
  doc.split("\n").map((l) => (l.trim() === "" ? ` *` : ` * ${safe(l)}`));
// a description collapsed to a single inline clause (for `@property ... - desc`).
const docInline = (doc) => safe(doc.replace(/\s+/g, " ").trim());

// --- synthesise one @typedef block per type ---------------------------------
function typedefBlock(t) {
  if (t.kind === "enum") {
    // string-literal union — more precise than the OCaml `string` it compiles to
    const union = t.values.map((v) => JSON.stringify(v)).join("|");
    return `/**\n * @typedef {(${union})} ${t.name}\n */`;
  }
  if (t.kind === "union") {
    // oneOf/anyOf of named types — a real `A | B | C` union
    return `/**\n * @typedef {(${t.members.join(" | ")})} ${t.name}\n */`;
  }
  if (t.kind === "alias") {
    // a type alias — string / T[] / a Ref to another schema
    return `/**\n * @typedef {${t.alias}} ${t.name}\n */`;
  }
  if (t.kind === "opaque") {
    // free-form / unnamed-variant fallback — honest `unknown`, not a wrong shape
    return `/**\n * @typedef {unknown} ${t.name}\n */`;
  }
  // record
  const lines = [`/**`];
  if (t.doc) lines.push(...docBlock(t.doc), ` *`);
  lines.push(` * @typedef {object} ${t.name}`);
  for (const f of t.fields) {
    const name = f.optional ? `[${f.name}]` : f.name; // optional property => `T | undefined`
    // description + an optional `format:` note (date-time, url, …) on one line
    const parts = [];
    if (f.doc) parts.push(docInline(f.doc));
    if (f.format) parts.push(`format: ${safe(f.format)}`);
    const desc = parts.length ? ` - ${parts.join(" — ")}` : "";
    lines.push(` * @property {${f.type}} ${name}${desc}`);
  }
  lines.push(` */`);
  return lines.join("\n");
}

// --- accessor signature -----------------------------------------------------
function accessorBlock(a) {
  const sig =
    a.dir === "of_json"
      ? `(json: unknown) => ${a.type}`
      : `(value: ${a.type}) => unknown`;
  return `/** @type {${sig}} */`;
}

// --- send wrapper: a function declaration, so JSDoc uses @param/@returns.
// Param names are READ FROM THE AST, not assumed: Melange mangles `fetch` to
// `$$fetch` (it shadows a JS global), so @param must use the emitted name. ---
function sendBlock(s, fnNode) {
  const params = fnNode.params.map((p, i) =>
    p.type === "Identifier" ? p.name : `p${i}`,
  );
  const types = ["Fetch", s.request]; // fetch, req — by position
  const lines = [`/**`];
  if (s.doc) lines.push(...docBlock(s.doc), ` *`);
  params.forEach((name, i) =>
    lines.push(` * @param {${types[i] ?? "unknown"}} ${name}`),
  );
  lines.push(` * @returns {Promise<${s.response}>}`, ` */`);
  return lines.join("\n");
}

// --- parse the real Melange output ------------------------------------------
const ast = acorn.parse(src, { ecmaVersion: 2022, sourceType: "module" });

// map: name -> start offset of its top-level binding. Flat accessors compile to
// `const NAME = ...` (VariableDeclaration); send wrappers take params and so
// compile to `function NAME(...)` (FunctionDeclaration). Index both.
const bindingStart = new Map();
const funcNode = new Map(); // name -> FunctionDeclaration (to read real param names)
for (const node of ast.body) {
  if (node.type === "VariableDeclaration") {
    for (const d of node.declarations) {
      if (d.id.type === "Identifier") bindingStart.set(d.id.name, node.start);
    }
  } else if (node.type === "FunctionDeclaration" && node.id) {
    bindingStart.set(node.id.name, node.start);
    funcNode.set(node.id.name, node);
  }
}

const require_binding = (name, what) => {
  const at = bindingStart.get(name);
  if (at === undefined) {
    throw new Error(
      `metadata names ${what} "${name}" but it is not a top-level binding ` +
        `in ${jsPath} — refusing to guess (fail loud).`,
    );
  }
  return at;
};

// build the list of (offset, text) splices
const splices = [];

// typedefs (+ the shared Fetch typedef): prepend at top of file (offset 0)
let typedefs = meta.types.map(typedefBlock).join("\n\n");
// B1: re-import each referenced schema typedef from the sibling module, so this
// file can name it bare (`Note`) across the file boundary.
if (meta.imports?.length) {
  const aliases = meta.imports
    .map((n) => `/**\n * @typedef {import('./${SCHEMA_MODULE}').${n}} ${n}\n */`)
    .join("\n\n");
  typedefs = aliases + "\n\n" + typedefs;
}
if (meta.fetchType) {
  typedefs = `/**\n * @typedef {${meta.fetchType}} Fetch\n */\n\n` + typedefs;
}
splices.push({ at: 0, text: typedefs + "\n\n" });

// accessor annotations: structural join + FAIL LOUD
for (const a of meta.accessors ?? []) {
  splices.push({ at: require_binding(a.name, "accessor"), text: accessorBlock(a) + "\n" });
}

// send wrappers: structural join + FAIL LOUD
for (const s of meta.sends ?? []) {
  const at = require_binding(s.name, "send");
  const fn = funcNode.get(s.name);
  if (!fn) {
    throw new Error(`send "${s.name}" is not a function declaration in ${jsPath}`);
  }
  splices.push({ at, text: sendBlock(s, fn) + "\n" });
}

// apply right-to-left so earlier offsets stay valid
splices.sort((p, q) => q.at - p.at);
let out = src;
for (const s of splices) out = out.slice(0, s.at) + s.text + out.slice(s.at);

// repoint the melange cross-module import at the schema module name (case-
// insensitive: the file may be componentSchemas.js or ComponentSchemas.js)
out = out.replace(/"\.\/componentSchemas\.js"/gi, `"./${SCHEMA_MODULE}"`);

process.stdout.write(out);
