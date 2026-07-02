// Hand-written TypeScript convenience layer for @f3liz/mazemaze-api-bluesky.
// Delegates to the generated melange-dist/Endpoints.js sends for XRPC path
// building, parameter encoding, and response decoding.  Transport is a
// caller-provided fetchFn — typically the DPoP-authenticated fetch from
// @atproto/oauth-client-browser, wrapped to match this module's FetchFn type.
//
// Auth stays outside this package.  kaguya keeps @atproto/oauth-client-browser
// for sign-in and injects the session fetch here via connect().
//
// Usage:
//   const c = connect("https://bsky.social", { fetch: myDpopFetch })
//   const feed = await getTimeline(c, { limit: 20 })
import { appBskyFeedGetTimeline_send, appBskyFeedGetAuthorFeed_send, appBskyFeedGetFeed_send, appBskyFeedGetListFeed_send, appBskyFeedGetPostThread_send, appBskyFeedGetPosts_send, appBskyFeedGetActorLikes_send, appBskyActorGetProfile_send, appBskyActorGetPreferences_send, appBskyFeedGetActorFeeds_send, appBskyFeedGetFeedGenerators_send, appBskyNotificationListNotifications_send, appBskyGraphGetLists_send, appBskyGraphGetList_send, comAtprotoRepoCreateRecord_send, comAtprotoRepoDeleteRecord_send, comAtprotoServerDescribeServer_send, } from "./melange-api/melange-dist/Endpoints.js";
// ============= connect / close =============
/**
 * Create a Bluesky XRPC client.
 *
 * @param service  PDS base URL, e.g. "https://bsky.social"
 * @param opts.fetch  Required.  A FetchFn that carries DPoP auth.  It will
 *   receive absolute URLs (service + XRPC path).  Binary bodies are only
 *   passed for uploadBlob — all others are plain objects.
 *
 * Wiring example for kaguya (adapt the exact OAuthSession API as needed):
 *   const c = connect(session.serverMetadata.issuer, {
 *     fetch: async (method, url, body) => {
 *       const res = await session.fetchHandler(
 *         url, method, { "Content-Type": "application/json" },
 *         body instanceof Blob || body instanceof Uint8Array
 *           ? body
 *           : JSON.stringify(body),
 *       )
 *       return JSON.parse(new TextDecoder().decode(res.body))
 *     }
 *   })
 */
export function connect(service, opts) {
    // The generated sends pass path-only URLs like "/xrpc/app.bsky.feed.getTimeline?limit=20".
    // We prefix the service so opts.fetch always receives fully-qualified URLs.
    const fetchFn = (method, path, body) => opts.fetch(method, service + path, body);
    return { service, fetchFn };
}
/** No-op.  Included for API symmetry; Bluesky has no persistent connection. */
export function close(_c) { }
// ============= Read operations =============
export function getTimeline(c, req) {
    return appBskyFeedGetTimeline_send(c.fetchFn, req);
}
export function getAuthorFeed(c, req) {
    return appBskyFeedGetAuthorFeed_send(c.fetchFn, req);
}
export function getFeed(c, req) {
    return appBskyFeedGetFeed_send(c.fetchFn, req);
}
export function getListFeed(c, req) {
    return appBskyFeedGetListFeed_send(c.fetchFn, req);
}
export function getPostThread(c, req) {
    return appBskyFeedGetPostThread_send(c.fetchFn, req);
}
export function getPosts(c, req) {
    return appBskyFeedGetPosts_send(c.fetchFn, req);
}
export function getActorLikes(c, req) {
    return appBskyFeedGetActorLikes_send(c.fetchFn, req);
}
export function getProfile(c, req) {
    return appBskyActorGetProfile_send(c.fetchFn, req);
}
/** Fetch the authed user's actor preferences (saved feeds, etc.). */
export function getPreferences(c) {
    return appBskyActorGetPreferences_send(c.fetchFn, {});
}
export function getActorFeeds(c, req) {
    return appBskyFeedGetActorFeeds_send(c.fetchFn, req);
}
export function getFeedGenerators(c, req) {
    return appBskyFeedGetFeedGenerators_send(c.fetchFn, req);
}
export function listNotifications(c, req) {
    return appBskyNotificationListNotifications_send(c.fetchFn, req);
}
export function getLists(c, req) {
    return appBskyGraphGetLists_send(c.fetchFn, req);
}
export function getList(c, req) {
    return appBskyGraphGetList_send(c.fetchFn, req);
}
/** Fetch server / PDS metadata. */
export function describeServer(c) {
    return comAtprotoServerDescribeServer_send(c.fetchFn, {});
}
// ============= Write operations =============
export function createRecord(c, req) {
    return comAtprotoRepoCreateRecord_send(c.fetchFn, req);
}
export function deleteRecord(c, req) {
    return comAtprotoRepoDeleteRecord_send(c.fetchFn, req);
}
/**
 * Upload a binary blob (image, video, etc.).
 *
 * NOTE: The generated comAtprotoRepoUploadBlob_send always sends an empty
 * body and cannot carry binary data, so this function hand-rolls the call
 * directly through c.fetchFn.  The caller's FetchFn must handle a
 * Blob/Uint8Array body for this endpoint (do not JSON.stringify it).
 *
 * @param blob    Binary data to upload.
 * @returns       Raw parsed response; the blob ref lives at `.blob`.
 */
export function uploadBlob(c, blob) {
    // Bypasses the generated send (which would discard the binary body).
    return c.fetchFn("POST", "/xrpc/com.atproto.repo.uploadBlob", blob);
}
