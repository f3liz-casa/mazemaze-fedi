export type FetchFn = (method: string, url: string, body: unknown) => Promise<unknown>;
export interface HackersPubClient {
    readonly origin: string;
    readonly token: string | undefined;
    readonly fetchFn: FetchFn;
}
/**
 * Create a client for the hackers.pub GraphQL API.
 *
 * The default fetchFn POSTs `{ query, variables }` to `origin/graphql` with
 * `Authorization: Bearer <token>` when a token is present.  Pass a custom
 * `fetch` to override (e.g. for testing or non-browser environments).
 */
export declare function connect(origin: string, opts?: {
    token?: string;
    fetch?: FetchFn;
}): HackersPubClient;
/** No-op. Included for API symmetry with other mazemaze clients. */
export declare function close(_c: HackersPubClient): void;
export interface CreateNoteInput {
    content: string;
    language: string;
    visibility: "PUBLIC" | "FOLLOWERS" | "DIRECT" | "NONE";
    replyTargetId?: string;
    quotedPostId?: string;
    quotePolicy?: "EVERYONE" | "FOLLOWERS" | "NONE";
    media?: Array<{
        mediumId: string;
        alt: string;
    }>;
    actingAccountId?: string;
}
export interface UpdateNoteInput {
    noteId: string;
    content?: string;
    language?: string;
    quotePolicy?: "EVERYONE" | "FOLLOWERS" | "NONE";
    actingAccountId?: string;
}
export interface DeletePostInput {
    id: string;
    actingAccountId?: string;
}
export interface AddReactionToPostInput {
    postId: string;
    emoji?: string;
    customEmojiId?: string;
    actingAccountId?: string;
}
export interface RemoveReactionFromPostInput {
    postId: string;
    emoji?: string;
    customEmojiId?: string;
    actingAccountId?: string;
}
export interface BookmarkPostInput {
    postId: string;
}
export interface UnbookmarkPostInput {
    postId: string;
}
export interface SharePostInput {
    postId: string;
    actingAccountId?: string;
}
export interface UnsharePostInput {
    postId: string;
    actingAccountId?: string;
}
export interface FollowActorInput {
    actorId: string;
    actingAccountId?: string;
}
export interface UnfollowActorInput {
    actorId: string;
    actingAccountId?: string;
}
export interface VoteOnPollInput {
    questionId: string;
    optionIndices: number[];
    actingAccountId?: string;
}
export interface CreateMediumInput {
    url: string;
}
export interface StartMediumUploadInput {
    contentLength: number;
    contentType: string;
}
export interface FinishMediumUploadInput {
    uploadId: string;
}
export declare function publicTimeline(c: HackersPubClient, req: {
    after?: string;
    first?: number;
    languages?: string[];
    withoutShares?: boolean;
}): Promise<unknown>;
export declare function personalTimeline(c: HackersPubClient, req: {
    after?: string;
    first?: number;
    languages?: string[];
    withoutShares?: boolean;
}): Promise<unknown>;
export declare function actorByHandle(c: HackersPubClient, req: {
    handle: string;
    allowLocalHandle?: boolean;
}): Promise<unknown>;
export declare function accountByUsername(c: HackersPubClient, req: {
    username: string;
}): Promise<unknown>;
export declare function viewer(c: HackersPubClient): Promise<unknown>;
export declare function postByUrl(c: HackersPubClient, req: {
    url: string;
}): Promise<unknown>;
export declare function postById(c: HackersPubClient, req: {
    id: string;
}): Promise<unknown>;
export declare function postReplies(c: HackersPubClient, req: {
    id: string;
    after?: string;
    first?: number;
}): Promise<unknown>;
export declare function actorPosts(c: HackersPubClient, req: {
    handle: string;
    after?: string;
    first?: number;
}): Promise<unknown>;
export declare function actorPostsById(c: HackersPubClient, req: {
    id: string;
    after?: string;
    first?: number;
}): Promise<unknown>;
export declare function notifications(c: HackersPubClient, req: {
    after?: string;
    first?: number;
}): Promise<unknown>;
export declare function createNote(c: HackersPubClient, input: CreateNoteInput): Promise<unknown>;
export declare function updateNote(c: HackersPubClient, input: UpdateNoteInput): Promise<unknown>;
export declare function deletePost(c: HackersPubClient, input: DeletePostInput): Promise<unknown>;
export declare function addReaction(c: HackersPubClient, input: AddReactionToPostInput): Promise<unknown>;
export declare function removeReaction(c: HackersPubClient, input: RemoveReactionFromPostInput): Promise<unknown>;
export declare function bookmarkPost(c: HackersPubClient, input: BookmarkPostInput): Promise<unknown>;
export declare function unbookmarkPost(c: HackersPubClient, input: UnbookmarkPostInput): Promise<unknown>;
export declare function sharePost(c: HackersPubClient, input: SharePostInput): Promise<unknown>;
export declare function unsharePost(c: HackersPubClient, input: UnsharePostInput): Promise<unknown>;
export declare function followActor(c: HackersPubClient, input: FollowActorInput): Promise<unknown>;
export declare function unfollowActor(c: HackersPubClient, input: UnfollowActorInput): Promise<unknown>;
export declare function voteOnPoll(c: HackersPubClient, input: VoteOnPollInput): Promise<unknown>;
export declare function createMedium(c: HackersPubClient, input: CreateMediumInput): Promise<unknown>;
export declare function startMediumUpload(c: HackersPubClient, input: StartMediumUploadInput): Promise<unknown>;
export declare function finishMediumUpload(c: HackersPubClient, input: FinishMediumUploadInput): Promise<unknown>;
export declare function markNotificationsAsRead(c: HackersPubClient, req: {
    upTo?: string;
}): Promise<unknown>;
/**
 * Initiate passwordless sign-in by username.
 * Sends a magic link to the account's email; the link embeds `{token}` and
 * `{code}` as URI Template variables in `verifyUrl`.
 * Call `completeLoginChallenge` with those values to get a session token.
 */
export declare function loginByUsername(c: HackersPubClient, req: {
    username: string;
    locale: string;
    verifyUrl: string;
}): Promise<unknown>;
/**
 * Initiate passwordless sign-in by email.
 * Same flow as `loginByUsername` but keyed on email address.
 */
export declare function loginByEmail(c: HackersPubClient, req: {
    email: string;
    locale: string;
    verifyUrl: string;
}): Promise<unknown>;
/**
 * Exchange the `(token, code)` pair from a magic-link email for a session.
 * On success, `data.completeLoginChallenge.id` is the **bearer token** to
 * pass as `opts.token` when calling `connect`.
 */
export declare function completeLoginChallenge(c: HackersPubClient, req: {
    token: string;
    code: string;
}): Promise<unknown>;
