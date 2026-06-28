// D1 proof harness — NOT shipped. Mirrors how kaguya-app/src/lib-src/misskey.ts
// calls the Melange endpoints layer, but against THIS generator's JSDoc-typed
// output instead of the hand-written `Promise<unknown[]>` ambient stub.
//
// A fully-green `tsc` run is the proof:
//   - the positive lines prove real types flow (Note[], nested UserLite, the
//     visibility string-literal union, the request record shape);
//   - each `@ts-expect-error` line passes ONLY IF that misuse really is rejected,
//     so green means the types are load-bearing, not just present.
//
// The single config delta vs. kaguya today is `allowJs: true` (see tsconfig).

import { postNotesTimeline_send } from "../endpoints.annotated.mjs";
import {
  userDetailed_of_json,
  notification_of_json,
} from "../componentSchemas.annotated.mjs";

// kaguya builds this with `apiFetch(client)`; its shape is the generated `Fetch`.
const fetch = (_method: string, _url: string, _body: unknown): Promise<unknown> =>
  Promise.resolve(null);

async function main() {
  // Today in kaguya this is `unknown[]`. With the generated types it is `Note[]`.
  const notes = await postNotesTimeline_send(fetch, { limit: 20, untilId: "x" });

  const first = notes[0];
  const id: string = first.id; // Note.id : string
  const handle: string = first.user.username; // nested UserLite flows through
  const v = first.visibility; // narrowed string-literal union
  if (v === "followers") {
    /* visibility narrows */
  }
  void [id, handle];

  // --- the types are load-bearing: each misuse must be rejected ---

  // @ts-expect-error  bogus field on the decoded Note
  void first.doesNotExist;

  // @ts-expect-error  visibility is a closed union, not any string
  const bad: typeof v = "nope";
  void bad;

  // @ts-expect-error  request field `limit` is a number, not a string
  await postNotesTimeline_send(fetch, { limit: "20" });

  // @ts-expect-error  fetch must take (method, url, body), not (number, ...)
  await postNotesTimeline_send((_n: number) => Promise.resolve(null), {});

  // --- A5: oneOf is a real union (UserDetailedNotMe | MeDetailed), not unknown ---
  const ud = userDetailed_of_json(null);
  const sharedId: string = ud.id; // both union members carry id:string; errors if `unknown`
  void sharedId;

  // @ts-expect-error  bogus field on every member of the union
  void ud.notAFieldOnEither;

  // --- A6: inline union variants are hoisted into a real Notification union ---
  const note = notification_of_json(null);
  const noteId: string = note.id; // every variant carries id:string
  void noteId;

  // @ts-expect-error  bogus field on every Notification variant
  void note.notAFieldOnAnyVariant;
}

void main;
