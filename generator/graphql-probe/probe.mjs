// The GraphQL probe: the front-edge of the GraphQL path, the analogue of an
// OpenAPI spec file for the REST path. It reads a schema (SDL) and a folder of
// executable operation documents, validates the documents against the schema,
// resolves each operation's variables and its *selection-set* into concrete
// types (graphql-js does the type resolution — the part we don't want to
// re-implement in OCaml), and prints the normalized JSON that gen/graphql.ml
// lowers into the IR.
//
// usage: node probe.mjs <schema.graphql> <operations-dir> > normalized.json
//
// The normalized contract (one place, mirrored by gen/graphql.ml):
//   type node : { object: field[] } | { union: {common,branches} }
//             | { input: name } | { list: type } | { scalar: name }
//   field     : { name, optional, nullable, type }
//   { inputs: {name,fields}[], operations: {name,operationType,document,variables,selection}[] }

import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import {
  buildSchema, parse, validate, print, Kind,
  GraphQLNonNull, GraphQLList,
  isScalarType, isEnumType, isObjectType, isInterfaceType, isUnionType, isInputObjectType,
} from "graphql";

const [, , schemaPath, opsDir] = process.argv;
if (!schemaPath || !opsDir) { console.error("usage: node probe.mjs <schema.graphql> <operations-dir>"); process.exit(2); }

const schema = buildSchema(readFileSync(schemaPath, "utf8"));

// ── input-object types referenced by variables, collected into `inputs` ──
const inputs = new Map();   // name -> fields (null while in progress, breaks cycles)
const inputRef = (t) => {   // a non-null/list-unwrapped *named* input ref typeref
  if (t instanceof GraphQLNonNull) return inputRef(t.ofType);
  if (t instanceof GraphQLList) return { list: inputRef(t.ofType) };
  if (isInputObjectType(t)) { collectInput(t); return { input: t.name }; }
  return { scalar: t.name };   // scalar or enum (enum -> string downstream)
};
function collectInput(t) {
  if (inputs.has(t.name)) return;
  inputs.set(t.name, null);
  const fields = Object.values(t.getFields()).map((f) => {
    const nn = f.type instanceof GraphQLNonNull;
    return { name: f.name, optional: !nn, nullable: !nn, type: inputRef(f.type) };
  });
  inputs.set(t.name, fields);
}

// ── output selection: a GraphQL type + a selection set -> a `type` node ──
function outputType(t, selectionSet) {
  if (t instanceof GraphQLNonNull) return outputType(t.ofType, selectionSet);
  if (t instanceof GraphQLList) return { list: outputType(t.ofType, selectionSet) };
  if (isScalarType(t) || isEnumType(t)) return { scalar: t.name };
  if (isObjectType(t)) return { object: objectFields(t, selectionSet) };
  if (isInterfaceType(t) || isUnionType(t)) return abstractType(t, selectionSet);
  return { scalar: "String" };
}

function outField(parentType, fieldNode) {
  const name = (fieldNode.alias || fieldNode.name).value;
  if (fieldNode.name.value === "__typename")
    return { name, optional: false, nullable: false, type: { scalar: "String" } };
  const def = parentType.getFields()[fieldNode.name.value];
  if (!def) throw new Error(`field ${parentType.name}.${fieldNode.name.value} not in schema`);
  const nullable = !(def.type instanceof GraphQLNonNull);
  return { name, optional: false, nullable, type: outputType(def.type, fieldNode.selectionSet) };
}

const fieldNodes = (ss) => ss.selections.filter((s) => s.kind === Kind.FIELD);
const fragmentNodes = (ss) => ss.selections.filter((s) => s.kind === Kind.INLINE_FRAGMENT);

function objectFields(type, selectionSet) {
  return fieldNodes(selectionSet).map((f) => outField(type, f));
}

// an interface/union selection: common (non-__typename) interface fields +
// one branch per inline fragment, resolved against the concrete type. The
// per-branch __typename tag is synthesized in gen/graphql.ml, so drop it here.
function abstractType(type, selectionSet) {
  const common = fieldNodes(selectionSet)
    .filter((f) => f.name.value !== "__typename")
    .map((f) => outField(type, f));
  const branches = fragmentNodes(selectionSet).map((fr) => {
    const tname = fr.typeCondition.name.value;
    const concrete = schema.getType(tname);
    const fields = fieldNodes(fr.selectionSet)
      .filter((f) => f.name.value !== "__typename")
      .map((f) => outField(concrete, f));
    return { typename: tname, fields };
  });
  return { union: { common, branches } };
}

// ── a variable type from its AST node (resolve named types via the schema) ──
function varType(typeNode) {
  if (typeNode.kind === Kind.NON_NULL_TYPE) return varType(typeNode.type);
  if (typeNode.kind === Kind.LIST_TYPE) return { list: varType(typeNode.type) };
  return inputRef(schema.getType(typeNode.name.value));   // NAMED_TYPE
}

// ── walk every operation in every *.graphql document ──
const rootFor = (op) =>
  op === "query" ? schema.getQueryType()
  : op === "mutation" ? schema.getMutationType()
  : schema.getSubscriptionType();

const operations = [];
for (const file of readdirSync(opsDir).filter((f) => f.endsWith(".graphql")).sort()) {
  const src = readFileSync(join(opsDir, file), "utf8");
  const doc = parse(src);
  const errs = validate(schema, doc);
  if (errs.length) { console.error(`${file}: ${errs.map((e) => e.message).join("; ")}`); process.exit(1); }
  for (const def of doc.definitions) {
    if (def.kind !== Kind.OPERATION_DEFINITION) continue;
    if (!def.name) { console.error(`${file}: anonymous operations are not supported`); process.exit(1); }
    const variables = (def.variableDefinitions || []).map((vd) => ({
      name: vd.variable.name.value,
      optional: vd.type.kind !== Kind.NON_NULL_TYPE,
      type: varType(vd.type),
    }));
    operations.push({
      name: def.name.value,
      operationType: def.operation,
      document: print(def),
      variables,
      selection: { object: objectFields(rootFor(def.operation), def.selectionSet) },
    });
  }
}

const out = {
  inputs: [...inputs.entries()].map(([name, fields]) => ({ name, fields })),
  operations,
};
process.stdout.write(JSON.stringify(out, null, 2) + "\n");
