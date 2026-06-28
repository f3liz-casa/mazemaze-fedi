// Runtime-decode regression: exercises the two shapes that used to break or
// were newly recovered — a UserLite carrying JSON `null` in required fields
// (A4: must decode to undefined, not throw) and the flattened allOf record
// (A3: must pull fields from every merged part). Exits non-zero on any failure.

import {
  userLite_of_json,
  userDetailedNotMe_of_json,
  error_of_json,
  note_of_json,
} from "../componentSchemas.annotated.mjs";
import { postAdminDriveCleanup_send } from "../endpoints.annotated.mjs";
import * as J from "melange-json/melange_json.js";
import { readFileSync } from "node:fs";

const here = new URL(".", import.meta.url).pathname;
const load = (f) => J.of_string(readFileSync(here + "fixtures/" + f, "utf8"));

let failed = 0;
const ok = (cond, msg) => {
  console.log(`  ${cond ? "PASS" : "FAIL"}: ${msg}`);
  if (!cond) failed++;
};

// A4 — required-nullable field decodes a present `null` to undefined, no throw.
try {
  const u = userLite_of_json(load("userLite.null.json"));
  ok(u.name === undefined, "UserLite.name (null) -> undefined");
  ok(typeof u.id === "string", "UserLite.id (non-null) -> string");
} catch (e) {
  ok(false, `UserLite null decode threw: ${e.RE_EXN_ID || e.message || e}`);
}

// A3 — flattened allOf record carries fields from every part.
try {
  const d = userDetailedNotMe_of_json(load("userDetailedNotMe.min.json"));
  ok(typeof d.id === "string", "UserDetailedNotMe.id (from UserLite part)");
  ok(typeof d.followersCount === "number", "UserDetailedNotMe.followersCount (from detailed part)");
} catch (e) {
  ok(false, `UserDetailedNotMe decode threw: ${e.RE_EXN_ID || e.message || e}`);
}

// A7 — a self-referential record (Note.reply : Note) decodes recursively.
try {
  const base = JSON.parse(readFileSync(here + "fixtures/note.min.json", "utf8"));
  const nested = { ...base, id: "outer", reply: base };
  const n = note_of_json(J.of_string(JSON.stringify(nested)));
  ok(n.reply !== undefined && n.reply.id === base.id, "Note.reply (self-ref) decodes recursively");
} catch (e) {
  ok(false, `recursive Note decode threw: ${e.RE_EXN_ID || e.message || e}`);
}

// A6 — an inline object (Error.error) is hoisted and decodes structurally.
try {
  const e = error_of_json(
    J.of_string('{"error":{"code":"X","message":"m","id":"i"}}'),
  );
  ok(e.error.code === "X", "hoisted Error.error decodes nested .code");
} catch (err) {
  ok(false, `Error decode threw: ${err.RE_EXN_ID || err.message || err}`);
}

// A2 — a no-argument endpoint still sends a body, and that body is a bare `{}`.
try {
  let sentMethod, sentPath, sentBody;
  const fetch = (method, url, body) => {
    sentMethod = method;
    sentPath = url;
    sentBody = body;
    return Promise.resolve(null); // identity (no-json) response: decoder passes it through
  };
  await postAdminDriveCleanup_send(fetch, undefined);
  ok(sentMethod === "POST", "empty-req send passes the HTTP method");
  ok(sentPath === "/admin/drive/cleanup", "empty-req send hits the right path");
  ok(
    sentBody && typeof sentBody === "object" && Object.keys(sentBody).length === 0,
    "empty-req send posts a bare {}",
  );
} catch (e) {
  ok(false, `empty-req send threw: ${e.RE_EXN_ID || e.message || e}`);
}

process.exit(failed === 0 ? 0 : 1);
