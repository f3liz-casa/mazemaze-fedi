// TypeScript consumer of the generated layer.
//
// TS imports the FLAT, JSDoc-annotated melange module directly (endpoints.annotated.mjs).
// With `allowJs`, TS reads the JSDoc, so responses are real types — no `.d.ts`, no cast.
// This is the most natural path for TS: the only thing it must supply is the transport.
//
// (The nested `endpoints.res.mjs` would also work at runtime, but ReScript-compiled JS
//  ships no TS types — you'd be back to `unknown`. So a TS consumer wants the JSDoc .js.)

import {
  postNotesTimeline_send,
  postNotesCreate_send,
} from "../../endpoints.annotated.mjs";

// ── The one piece of boilerplate every consumer needs: a client that turns
//    (origin, token) into the `(method, url, body) => Promise<json>` the sends
//    expect. The send already built the full url (path + query); fetch picks the
//    HTTP method. ──
function makeClient(origin: string, token?: string) {
  const transport = async (method: string, url: string, body: unknown): Promise<unknown> => {
    const res = await fetch(`${origin}/api${url}`, {
      method,
      headers: { "content-type": "application/json" },
      // misskey takes the token in the body as `i`; GET requests carry no body
      body: method === "GET" ? undefined : JSON.stringify(token ? { ...(body as object), i: token } : body),
    });
    return res.json();
  };
  return { transport };
}

async function main() {
  const client = makeClient("https://misskey.example", "TOKEN");

  // timeline → typed `Note[]`. Nested UserLite and the nullable `text` flow through.
  const notes = await postNotesTimeline_send(client.transport, { limit: 20 });
  const first = notes[0];
  const author: string = first.user.username; // required UserLite field
  const body: string | undefined = first.text; // 3.1 nullable → optional
  console.log(author, body);

  // create → the request type is all-optional, so `{ text }` alone type-checks.
  // No friction here: JSDoc optional properties are exactly what a TS author expects.
  const created = await postNotesCreate_send(client.transport, {
    text: "hello from TypeScript",
  });
  console.log(created);
}

void main;
