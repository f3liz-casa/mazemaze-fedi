// Smoke test: import the convenience layer, exercise each major path with a
// stub fetchFn, and assert that (a) URLs are built correctly and (b) the
// response round-trips through the Melange decoder without error.
//
// Run after tsc: node test/smoke.mjs
import {
  connect,
  getTimeline,
  createRecord,
  deleteRecord,
  uploadBlob,
} from "../src/Bluesky.js";

// ─── Stub setup ──────────────────────────────────────────────────────────────

const calls = [];

/**
 * Returns a minimal valid response for each XRPC endpoint used in this test.
 * Responses must satisfy the Melange decoder's required-field checks.
 */
const stubFetch = (method, url, body) => {
  calls.push({ method, url, body });

  if (url.includes("/xrpc/app.bsky.feed.getTimeline")) {
    // AppBskyFeedGetActorLikesResponse: { feed: FeedViewPost[], cursor? }
    return Promise.resolve({ feed: [] });
  }
  if (url.includes("/xrpc/com.atproto.repo.createRecord")) {
    // ComAtprotoRepoCreateRecordResponse: { uri, cid, commit?, validationStatus? }
    return Promise.resolve({
      uri: "at://did:plc:test/app.bsky.feed.post/abc123",
      cid: "bafyreidef123",
    });
  }
  if (url.includes("/xrpc/com.atproto.repo.deleteRecord")) {
    // ComAtprotoRepoDeleteRecordResponse: { commit? }
    return Promise.resolve({});
  }
  if (url.includes("/xrpc/com.atproto.repo.uploadBlob")) {
    return Promise.resolve({ blob: { $type: "blob", ref: "bafy", mimeType: "image/jpeg", size: 42 } });
  }
  return Promise.resolve({});
};

// ─── Test 1: connect() wires service prefix ───────────────────────────────────

const SERVICE = "https://bsky.social";
const c = connect(SERVICE, { fetch: stubFetch });

if (c.service !== SERVICE) {
  throw new Error(`Expected service=${SERVICE}, got ${c.service}`);
}

// ─── Test 2: getTimeline ─────────────────────────────────────────────────────

calls.length = 0;
await getTimeline(c, { limit: 5 });

const tlCall = calls[0];
if (!tlCall) throw new Error("getTimeline: stub not called");
if (tlCall.method !== "GET") {
  throw new Error(`getTimeline: expected GET, got ${tlCall.method}`);
}
if (!tlCall.url.startsWith(`${SERVICE}/xrpc/app.bsky.feed.getTimeline`)) {
  throw new Error(`getTimeline: unexpected URL: ${tlCall.url}`);
}
if (!tlCall.url.includes("limit=5")) {
  throw new Error(`getTimeline: expected limit=5 in URL, got: ${tlCall.url}`);
}

console.log("getTimeline: OK  url =", tlCall.url);

// ─── Test 3: createRecord (post) ─────────────────────────────────────────────

calls.length = 0;
const postRecord = {
  $type: "app.bsky.feed.post",
  text: "hello world",
  createdAt: "2026-06-29T00:00:00Z",
};
await createRecord(c, {
  repo: "did:plc:test",
  collection: "app.bsky.feed.post",
  record: postRecord,
});

const crCall = calls[0];
if (!crCall) throw new Error("createRecord: stub not called");
if (crCall.method !== "POST") {
  throw new Error(`createRecord: expected POST, got ${crCall.method}`);
}
if (!crCall.url.includes("/xrpc/com.atproto.repo.createRecord")) {
  throw new Error(`createRecord: unexpected URL: ${crCall.url}`);
}
if (crCall.body.repo !== "did:plc:test") {
  throw new Error(`createRecord: repo mismatch: ${JSON.stringify(crCall.body)}`);
}
if (crCall.body.collection !== "app.bsky.feed.post") {
  throw new Error(`createRecord: collection mismatch`);
}

console.log("createRecord: OK  url =", crCall.url);
console.log("               body.repo =", crCall.body.repo, "  body.collection =", crCall.body.collection);

// ─── Test 4: deleteRecord ────────────────────────────────────────────────────

calls.length = 0;
await deleteRecord(c, {
  repo: "did:plc:test",
  collection: "app.bsky.feed.like",
  rkey: "abc123",
});

const drCall = calls[0];
if (!drCall) throw new Error("deleteRecord: stub not called");
if (drCall.method !== "POST") {
  throw new Error(`deleteRecord: expected POST, got ${drCall.method}`);
}
if (!drCall.url.includes("/xrpc/com.atproto.repo.deleteRecord")) {
  throw new Error(`deleteRecord: unexpected URL: ${drCall.url}`);
}
if (drCall.body.rkey !== "abc123") {
  throw new Error(`deleteRecord: rkey mismatch: ${JSON.stringify(drCall.body)}`);
}

console.log("deleteRecord: OK  url =", drCall.url, "  rkey =", drCall.body.rkey);

// ─── Test 5: uploadBlob bypasses generated send (binary body passes through) ─

calls.length = 0;
const fakeBlob = new Uint8Array([0xff, 0xd8, 0xff]); // JPEG magic bytes
await uploadBlob(c, fakeBlob);

const ubCall = calls[0];
if (!ubCall) throw new Error("uploadBlob: stub not called");
if (ubCall.method !== "POST") {
  throw new Error(`uploadBlob: expected POST, got ${ubCall.method}`);
}
if (!ubCall.url.includes("/xrpc/com.atproto.repo.uploadBlob")) {
  throw new Error(`uploadBlob: unexpected URL: ${ubCall.url}`);
}
if (!(ubCall.body instanceof Uint8Array)) {
  throw new Error(`uploadBlob: expected Uint8Array body, got ${typeof ubCall.body}`);
}

console.log("uploadBlob:   OK  url =", ubCall.url, "  body instanceof Uint8Array =", ubCall.body instanceof Uint8Array);

// ─── All done ────────────────────────────────────────────────────────────────

console.log("\nSmoke tests passed — connect / getTimeline / createRecord / deleteRecord / uploadBlob all green");
