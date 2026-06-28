import { userLite_of_json } from "./componentSchemas.annotated.mjs";
import { postAdminAbuseReportNotificationRecipientList_send as listRecipients } from "./endpoints.annotated.mjs";

// --- schema accessor (component types) ---
const u = userLite_of_json(JSON.parse("{}"));
const id: string = u.id;
if (u.onlineStatus === "online") { /* enum narrows */ }
u.onlineStatus = "nope";                       // MISUSE 1: not in enum union

// --- endpoint send (request / Fetch / Promise<response>) ---
const fetchImpl = (method: string, url: string, body: unknown): Promise<unknown> => Promise.resolve(null);
const p = listRecipients(fetchImpl, null as never);
p.then((rows) => {
  const n: number = rows.length;               // good: response is an array
  rows[0].doesNotExist;                         // MISUSE 2: unknown prop on the record
  void n;
});
listRecipients((x: number) => 5, null as never); // MISUSE 3: arg is not a Fetch fn

void [id, p];
