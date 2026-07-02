// Smoke test: import the convenience layer, call publicTimeline with a stub
// fetchFn returning a canned response, assert the response wires through.
import { connect, publicTimeline } from "../src/HackersPub.js";

// Canned hackers.pub-style response
const CANNED = {
  data: {
    publicTimeline: {
      edges: [
        {
          cursor: "abc123",
          node: {
            __typename: "Note",
            id: "1",
            uuid: "aaa-bbb-ccc",
            url: "https://hackers.pub/@alice/abc",
            content: "<p>Hello world</p>",
            excerpt: "Hello world",
            language: "en",
            published: "2026-06-28T00:00:00Z",
            updated: "2026-06-28T00:00:00Z",
            sensitive: false,
            viewerHasBookmarked: false,
            viewerHasShared: false,
            actor: { id: "a1", handle: "@alice@hackers.pub", name: "Alice", avatarUrl: "https://hackers.pub/avatar/alice.webp" },
            media: [],
            engagementStats: { replies: 0, shares: 1, reactions: 2, bookmarks: 0, quotes: 0 },
            reactionGroups: [],
            replyTarget: null,
            sharedPost: null,
            visibility: "PUBLIC",
            sourceId: "aaa-bbb-ccc",
          },
        },
      ],
      pageInfo: { endCursor: "abc123", hasNextPage: false },
    },
  },
};

let capturedBody;
const stubFetch = (method, url, body) => {
  capturedBody = body;
  return Promise.resolve(CANNED);
};

const c = connect("https://hackers.pub", { fetch: stubFetch });
const result = await publicTimeline(c, { first: 5 });

// Verify request was built correctly
if (!capturedBody.query.includes("publicTimeline")) {
  throw new Error("Expected query to include 'publicTimeline'");
}
if (capturedBody.variables.first !== 5) {
  throw new Error(`Expected first=5, got ${capturedBody.variables.first}`);
}
if (capturedBody.variables.first !== 5) {
  throw new Error("variables not passed");
}

// Verify response passes through
const edge = result.data.publicTimeline.edges[0];
if (edge.node.__typename !== "Note") {
  throw new Error(`Expected __typename=Note, got ${edge.node.__typename}`);
}
if (edge.node.content !== "<p>Hello world</p>") {
  throw new Error("content mismatch");
}
if (edge.node.visibility !== "PUBLIC") {
  throw new Error("visibility mismatch");
}

console.log("Smoke test passed — connect/publicTimeline round-trip green");
console.log("  query snippet:", capturedBody.query.slice(0, 60).replace(/\s+/g, " "));
console.log("  node.__typename:", edge.node.__typename);
console.log("  node.content:", edge.node.content);
