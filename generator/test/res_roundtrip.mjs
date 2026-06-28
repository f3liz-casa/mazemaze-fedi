// Verify the generated ReScript binding layer at runtime: a NESTED send from the
// compiled .res.mjs (Admin.PostAdminDriveCleanup.send) reaches the FLAT melange
// JS decoder via the @module external, with an injected fetch. Proves the
// rslayer-style nesting binds correctly onto the flat melange functions.
import { Admin } from "../res/src/Endpoints.res.mjs";

let sentPath;
const fetch = (_method, url, _body) => {
  sentPath = url;
  return Promise.resolve({ ok: true }); // identity (unknown) response: passes through
};

let failed = 0;
const ok = (cond, msg) => {
  console.log(`  ${cond ? "PASS" : "FAIL"}: ${msg}`);
  if (!cond) failed++;
};

try {
  const result = await Admin.PostAdminDriveCleanup.send(fetch, undefined);
  ok(sentPath === "/admin/drive/cleanup", "nested .res send reaches flat melange (right path)");
  ok(result && result.ok === true, "response flows back through the binding");
} catch (e) {
  ok(false, `nested .res send threw: ${e.RE_EXN_ID || e.message || e}`);
}

process.exit(failed === 0 ? 0 : 1);
