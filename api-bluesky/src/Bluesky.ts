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

import {
  appBskyFeedGetTimeline_send,
  appBskyFeedGetAuthorFeed_send,
  appBskyFeedGetFeed_send,
  appBskyFeedGetListFeed_send,
  appBskyFeedGetPostThread_send,
  appBskyFeedGetPosts_send,
  appBskyFeedGetActorLikes_send,
  appBskyActorGetProfile_send,
  appBskyActorGetPreferences_send,
  appBskyFeedGetActorFeeds_send,
  appBskyFeedGetFeedGenerators_send,
  appBskyNotificationListNotifications_send,
  appBskyGraphGetLists_send,
  appBskyGraphGetList_send,
  comAtprotoRepoCreateRecord_send,
  comAtprotoRepoDeleteRecord_send,
  comAtprotoServerDescribeServer_send,
} from "./melange-api/melange-dist/Endpoints.js";

// ============= Client types =============

/**
 * Transport function injected by the caller.  Receives (method, absoluteUrl,
 * body) and returns parsed JSON.
 *
 * For uploadBlob the body is a Blob or Uint8Array (binary); the caller's
 * implementation must handle that case (e.g. with fetch(url, { body, method,
 * headers: { "Content-Type": mimeType } }).then(r => r.json())).
 *
 * For all other calls body is a plain object (serialisable to JSON).
 */
export type FetchFn = (
  method: string,
  url: string,
  body: unknown
) => Promise<unknown>;

export interface BlueskyClient {
  readonly service: string;
  /** Internal fetchFn passed to generated sends.  Prepends service to paths. */
  readonly fetchFn: FetchFn;
}

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
export function connect(
  service: string,
  opts: { fetch: FetchFn }
): BlueskyClient {
  // The generated sends pass path-only URLs like "/xrpc/app.bsky.feed.getTimeline?limit=20".
  // We prefix the service so opts.fetch always receives fully-qualified URLs.
  const fetchFn: FetchFn = (method, path, body) =>
    opts.fetch(method, service + path, body);
  return { service, fetchFn };
}

/** No-op.  Included for API symmetry; Bluesky has no persistent connection. */
export function close(_c: BlueskyClient): void {}

// ============= Request types =============

export interface GetTimelineRequest {
  limit?: number;
  cursor?: string;
  algorithm?: string;
}

export interface GetAuthorFeedRequest {
  actor: string;
  limit?: number;
  cursor?: string;
  filter?: string;
  includePins?: boolean;
}

export interface GetFeedRequest {
  feed: string;
  limit?: number;
  cursor?: string;
}

export interface GetListFeedRequest {
  list: string;
  limit?: number;
  cursor?: string;
}

export interface GetPostThreadRequest {
  uri: string;
  depth?: number;
  parentHeight?: number;
}

export interface GetPostsRequest {
  uris: string[];
}

export interface GetActorLikesRequest {
  actor: string;
  limit?: number;
  cursor?: string;
}

export interface GetProfileRequest {
  actor: string;
}

export interface ListNotificationsRequest {
  limit?: number;
  cursor?: string;
  seenAt?: string;
  reasons?: string[];
  priority?: boolean;
}

export interface GetListsRequest {
  actor: string;
  limit?: number;
  cursor?: string;
  purposes?: string[];
}

export interface GetListRequest {
  list: string;
  limit?: number;
  cursor?: string;
}

export interface GetActorFeedsRequest {
  actor: string;
  limit?: number;
  cursor?: string;
}

export interface GetFeedGeneratorsRequest {
  feeds: string[];
}

/**
 * Arguments for com.atproto.repo.createRecord.
 *
 * Common collections:
 *   "app.bsky.feed.post"    post record
 *   "app.bsky.feed.like"    like  (record: { $type, subject: { uri, cid }, createdAt })
 *   "app.bsky.feed.repost"  repost (record: { $type, subject: { uri, cid }, createdAt })
 *   "app.bsky.graph.follow" follow (record: { $type, subject: did, createdAt })
 */
export interface CreateRecordRequest {
  /** DID of the repo to write to; typically the authed session's DID. */
  repo: string;
  /** NSID collection, e.g. "app.bsky.feed.post" */
  collection: string;
  record: unknown;
  rkey?: string;
  validate?: boolean;
  swapCommit?: string;
}

export interface DeleteRecordRequest {
  /** DID of the repo; typically the authed session's DID. */
  repo: string;
  /** NSID collection, e.g. "app.bsky.feed.like" */
  collection: string;
  /** Record key extracted from the AT-URI: at://did/collection/<rkey> */
  rkey: string;
  swapRecord?: string;
  swapCommit?: string;
}

// ============= Read operations =============

export function getTimeline(
  c: BlueskyClient,
  req: GetTimelineRequest
): Promise<unknown> {
  return appBskyFeedGetTimeline_send(c.fetchFn, req);
}

export function getAuthorFeed(
  c: BlueskyClient,
  req: GetAuthorFeedRequest
): Promise<unknown> {
  return appBskyFeedGetAuthorFeed_send(c.fetchFn, req);
}

export function getFeed(
  c: BlueskyClient,
  req: GetFeedRequest
): Promise<unknown> {
  return appBskyFeedGetFeed_send(c.fetchFn, req);
}

export function getListFeed(
  c: BlueskyClient,
  req: GetListFeedRequest
): Promise<unknown> {
  return appBskyFeedGetListFeed_send(c.fetchFn, req);
}

export function getPostThread(
  c: BlueskyClient,
  req: GetPostThreadRequest
): Promise<unknown> {
  return appBskyFeedGetPostThread_send(c.fetchFn, req);
}

export function getPosts(
  c: BlueskyClient,
  req: GetPostsRequest
): Promise<unknown> {
  return appBskyFeedGetPosts_send(c.fetchFn, req);
}

export function getActorLikes(
  c: BlueskyClient,
  req: GetActorLikesRequest
): Promise<unknown> {
  return appBskyFeedGetActorLikes_send(c.fetchFn, req);
}

export function getProfile(
  c: BlueskyClient,
  req: GetProfileRequest
): Promise<unknown> {
  return appBskyActorGetProfile_send(c.fetchFn, req);
}

/** Fetch the authed user's actor preferences (saved feeds, etc.). */
export function getPreferences(c: BlueskyClient): Promise<unknown> {
  return appBskyActorGetPreferences_send(c.fetchFn, {});
}

export function getActorFeeds(
  c: BlueskyClient,
  req: GetActorFeedsRequest
): Promise<unknown> {
  return appBskyFeedGetActorFeeds_send(c.fetchFn, req);
}

export function getFeedGenerators(
  c: BlueskyClient,
  req: GetFeedGeneratorsRequest
): Promise<unknown> {
  return appBskyFeedGetFeedGenerators_send(c.fetchFn, req);
}

export function listNotifications(
  c: BlueskyClient,
  req: ListNotificationsRequest
): Promise<unknown> {
  return appBskyNotificationListNotifications_send(c.fetchFn, req);
}

export function getLists(
  c: BlueskyClient,
  req: GetListsRequest
): Promise<unknown> {
  return appBskyGraphGetLists_send(c.fetchFn, req);
}

export function getList(
  c: BlueskyClient,
  req: GetListRequest
): Promise<unknown> {
  return appBskyGraphGetList_send(c.fetchFn, req);
}

/** Fetch server / PDS metadata. */
export function describeServer(c: BlueskyClient): Promise<unknown> {
  return comAtprotoServerDescribeServer_send(c.fetchFn, {});
}

// ============= Write operations =============

export function createRecord(
  c: BlueskyClient,
  req: CreateRecordRequest
): Promise<unknown> {
  return comAtprotoRepoCreateRecord_send(c.fetchFn, req);
}

export function deleteRecord(
  c: BlueskyClient,
  req: DeleteRecordRequest
): Promise<unknown> {
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
export function uploadBlob(
  c: BlueskyClient,
  blob: Blob | Uint8Array
): Promise<unknown> {
  // Bypasses the generated send (which would discard the binary body).
  return c.fetchFn("POST", "/xrpc/com.atproto.repo.uploadBlob", blob);
}
