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
export type FetchFn = (method: string, url: string, body: unknown) => Promise<unknown>;
export interface BlueskyClient {
    readonly service: string;
    /** Internal fetchFn passed to generated sends.  Prepends service to paths. */
    readonly fetchFn: FetchFn;
}
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
export declare function connect(service: string, opts: {
    fetch: FetchFn;
}): BlueskyClient;
/** No-op.  Included for API symmetry; Bluesky has no persistent connection. */
export declare function close(_c: BlueskyClient): void;
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
export declare function getTimeline(c: BlueskyClient, req: GetTimelineRequest): Promise<unknown>;
export declare function getAuthorFeed(c: BlueskyClient, req: GetAuthorFeedRequest): Promise<unknown>;
export declare function getFeed(c: BlueskyClient, req: GetFeedRequest): Promise<unknown>;
export declare function getListFeed(c: BlueskyClient, req: GetListFeedRequest): Promise<unknown>;
export declare function getPostThread(c: BlueskyClient, req: GetPostThreadRequest): Promise<unknown>;
export declare function getPosts(c: BlueskyClient, req: GetPostsRequest): Promise<unknown>;
export declare function getActorLikes(c: BlueskyClient, req: GetActorLikesRequest): Promise<unknown>;
export declare function getProfile(c: BlueskyClient, req: GetProfileRequest): Promise<unknown>;
/** Fetch the authed user's actor preferences (saved feeds, etc.). */
export declare function getPreferences(c: BlueskyClient): Promise<unknown>;
export declare function getActorFeeds(c: BlueskyClient, req: GetActorFeedsRequest): Promise<unknown>;
export declare function getFeedGenerators(c: BlueskyClient, req: GetFeedGeneratorsRequest): Promise<unknown>;
export declare function listNotifications(c: BlueskyClient, req: ListNotificationsRequest): Promise<unknown>;
export declare function getLists(c: BlueskyClient, req: GetListsRequest): Promise<unknown>;
export declare function getList(c: BlueskyClient, req: GetListRequest): Promise<unknown>;
/** Fetch server / PDS metadata. */
export declare function describeServer(c: BlueskyClient): Promise<unknown>;
export declare function createRecord(c: BlueskyClient, req: CreateRecordRequest): Promise<unknown>;
export declare function deleteRecord(c: BlueskyClient, req: DeleteRecordRequest): Promise<unknown>;
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
export declare function uploadBlob(c: BlueskyClient, blob: Blob | Uint8Array): Promise<unknown>;
