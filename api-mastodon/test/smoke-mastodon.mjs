// Smoke test: import the convenience layer, call through stub fetchFns,
// and assert URLs and request bodies are built correctly.
import { connect, Timelines, Statuses, Accounts } from "../src/Mastodon.js";

// ---- helpers ----

function assert(cond, msg) {
  if (!cond) throw new Error(`FAIL: ${msg}`);
}

// ---- minimal valid Mastodon account (all required fields) ----

const CANNED_ACCOUNT = {
  id: "42",
  username: "alice",
  acct: "alice",
  display_name: "Alice",
  locked: false,
  bot: false,
  group: false,
  created_at: "2026-01-01T00:00:00.000Z",
  note: "",
  url: "https://mastodon.social/@alice",
  uri: "https://mastodon.social/users/alice",
  avatar: "https://mastodon.social/avatars/alice.png",
  avatar_static: "https://mastodon.social/avatars/alice.png",
  header: "https://mastodon.social/headers/alice.png",
  header_static: "https://mastodon.social/headers/alice.png",
  followers_count: 0,
  following_count: 0,
  statuses_count: 0,
  emojis: [],
  fields: [],
};

// ---- minimal valid Mastodon status (all required fields) ----

const CANNED_STATUS = {
  id: "109012345678",
  uri: "https://mastodon.social/users/alice/statuses/109012345678",
  created_at: "2026-06-29T00:00:00.000Z",
  account: CANNED_ACCOUNT,
  content: "<p>Hello Fediverse</p>",
  visibility: "public",
  sensitive: false,
  spoiler_text: "",
  media_attachments: [],
  mentions: [],
  tags: [],
  emojis: [],
  reblogs_count: 0,
  favourites_count: 0,
  replies_count: 0,
};

// ---- test 1: Timelines.home URL construction ----

let capturedMethod, capturedUrl;

const stubFetch = (method, url, _body) => {
  capturedMethod = method;
  capturedUrl = url;
  return Promise.resolve([CANNED_STATUS]);
};

const c = connect("https://mastodon.social", { token: "test-token", fetch: stubFetch });
const tl = await Timelines.home(c, { limit: 20, sinceId: "100" });

assert(capturedMethod === "GET", `expected GET, got ${capturedMethod}`);
assert(
  capturedUrl.includes("/api/v1/timelines/home"),
  `expected home timeline URL, got ${capturedUrl}`
);
assert(capturedUrl.includes("limit=20"), `expected limit=20 in URL, got ${capturedUrl}`);
assert(
  capturedUrl.includes("since_id=100"),
  `expected since_id=100 in URL, got ${capturedUrl}`
);
assert(Array.isArray(tl), "expected decoded array");
assert(tl[0].id === "109012345678", "expected decoded status id");
assert(tl[0].account.acct === "alice", "expected decoded account.acct");

console.log("test 1 passed — Timelines.home URL + decoded response:", capturedUrl);

// ---- test 2: Statuses.create hand-rolled body ----

let createMethod, createUrl, createBody;
const stubCreate = (method, url, body) => {
  createMethod = method;
  createUrl = url;
  createBody = body;
  return Promise.resolve(CANNED_STATUS);
};

const c2 = connect("https://mastodon.social", { token: "tok", fetch: stubCreate });
await Statuses.create(c2, {
  status: "Hello world",
  visibility: "public",
  spoilerText: "CW",
  inReplyToId: "123",
  mediaIds: ["m1", "m2"],
});

assert(createMethod === "POST", `expected POST, got ${createMethod}`);
assert(createUrl === "/api/v1/statuses", `expected /api/v1/statuses, got ${createUrl}`);
assert(createBody["status"] === "Hello world", "status field");
assert(createBody["visibility"] === "public", "visibility field");
assert(createBody["spoiler_text"] === "CW", "spoiler_text field");
assert(createBody["in_reply_to_id"] === "123", "in_reply_to_id field");
assert(
  JSON.stringify(createBody["media_ids"]) === '["m1","m2"]',
  "media_ids field"
);

console.log("test 2 passed — Statuses.create body:", JSON.stringify(createBody));

// ---- test 3: default fetchFn prefixes origin ----

let fetchedUrl;
const origFetch = globalThis.fetch;
globalThis.fetch = (url, _opts) => {
  fetchedUrl = url;
  return Promise.resolve({ json: () => Promise.resolve([]) });
};

const c3 = connect("https://mastodon.example");
// Ignore decode errors — we just want to verify the URL was prefixed
await Timelines.home(c3).catch(() => {});

assert(
  typeof fetchedUrl === "string" &&
    fetchedUrl.startsWith("https://mastodon.example/api/v1/timelines/home"),
  `expected origin-prefixed URL, got ${fetchedUrl}`
);

globalThis.fetch = origFetch;
console.log("test 3 passed — default fetchFn prefixes origin:", fetchedUrl);

// ---- test 4: local timeline passes local=true ----

let localUrl;
const stubLocal = (method, url, _body) => {
  localUrl = url;
  return Promise.resolve([]);
};
const c4 = connect("https://mastodon.social", { fetch: stubLocal });
await Timelines.local(c4, { limit: 10 });

assert(
  localUrl.includes("/api/v1/timelines/public"),
  `expected public timeline URL, got ${localUrl}`
);
assert(localUrl.includes("local=true"), `expected local=true in URL, got ${localUrl}`);
assert(localUrl.includes("limit=10"), `expected limit=10 in URL, got ${localUrl}`);

console.log("test 4 passed — Timelines.local URL:", localUrl);

// ---- test 5: Accounts.verifyCredentials passes empty request ----
// CredentialAccount decoder requires a `role` field (a complex object), so we
// only verify the URL and ignore the decode error from the stub canned data.

let vcUrl;
const stubVc = (method, url, _body) => {
  vcUrl = url;
  return Promise.resolve(CANNED_ACCOUNT);
};
const c5 = connect("https://mastodon.social", { fetch: stubVc });
await Accounts.verifyCredentials(c5).catch(() => {});

assert(
  vcUrl === "/api/v1/accounts/verify_credentials",
  `expected verify_credentials URL, got ${vcUrl}`
);

console.log("test 5 passed — Accounts.verifyCredentials URL:", vcUrl);

console.log("\nAll smoke tests passed.");
