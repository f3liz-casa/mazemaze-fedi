// Demo: an endpoint send round-trips across the B1 file split — the wrapper
// lives in endpoints.annotated.mjs and reaches the schema decoders in
// componentSchemas.annotated.mjs at runtime. This op's response is free-form
// (`unknown`), so the injected fetch's value passes straight through.
import { postAdminDriveCleanup_send } from "./endpoints.annotated.mjs";
import * as J from "melange-json/melange_json.js";

const fakeFetch = (method, url, _body) => {
  console.log("  send hit:", method, url);
  return Promise.resolve(J.of_string('{"ok":true}'));
};

const result = await postAdminDriveCleanup_send(fakeFetch, {}); // encode {} -> fetch -> decode
console.log("  decoded result:", JSON.stringify(result));
