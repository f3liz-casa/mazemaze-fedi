export type FetchFn = (method: string, url: string, body: unknown) => Promise<unknown>;
export interface MastodonClient {
    readonly origin: string;
    readonly token: string | undefined;
    readonly fetchFn: FetchFn;
}
/**
 * Create a Mastodon REST API client.
 *
 * The default fetchFn prefixes `origin` onto the path-only URL the generated
 * sends produce, adds `Authorization: Bearer <token>` when a token is present,
 * and handles FormData bodies (multipart upload) by passing them through
 * without JSON.stringify and without forcing Content-Type (the browser/runtime
 * sets the boundary automatically).
 *
 * Pass a custom `fetch` to override transport (e.g. for testing).
 */
export declare function connect(origin: string, opts?: {
    token?: string;
    fetch?: FetchFn;
}): MastodonClient;
/** No-op. Included for API symmetry with other mazemaze clients. */
export declare function close(_c: MastodonClient): void;
export declare const Accounts: {
    verifyCredentials: (c: MastodonClient) => Promise<unknown>;
    show: (c: MastodonClient, id: string) => Promise<unknown>;
    statuses: (c: MastodonClient, id: string, opts?: {
        limit?: number;
        excludeReplies?: boolean;
        sinceId?: string;
        maxId?: string;
    }) => Promise<unknown>;
    follow: (c: MastodonClient, id: string) => Promise<unknown>;
    unfollow: (c: MastodonClient, id: string) => Promise<unknown>;
    lookup: (c: MastodonClient, acct: string) => Promise<unknown>;
};
export type StatusVisibility = "public" | "unlisted" | "private" | "direct";
export declare const Statuses: {
    show: (c: MastodonClient, id: string) => Promise<unknown>;
    create: (c: MastodonClient, opts: {
        status?: string;
        visibility?: StatusVisibility;
        spoilerText?: string;
        inReplyToId?: string;
        mediaIds?: string[];
        language?: string;
    }) => Promise<unknown>;
    delete: (c: MastodonClient, id: string) => Promise<unknown>;
    reblog: (c: MastodonClient, id: string) => Promise<unknown>;
    unreblog: (c: MastodonClient, id: string) => Promise<unknown>;
    favourite: (c: MastodonClient, id: string) => Promise<unknown>;
    unfavourite: (c: MastodonClient, id: string) => Promise<unknown>;
    bookmark: (c: MastodonClient, id: string) => Promise<unknown>;
    unbookmark: (c: MastodonClient, id: string) => Promise<unknown>;
    context: (c: MastodonClient, id: string) => Promise<unknown>;
    pollVote: (c: MastodonClient, pollId: string, choices: number[]) => Promise<unknown>;
};
export declare const Timelines: {
    home: (c: MastodonClient, opts?: {
        limit?: number;
        sinceId?: string;
        maxId?: string;
        minId?: string;
    }) => Promise<unknown>;
    public: (c: MastodonClient, opts?: {
        limit?: number;
        sinceId?: string;
        maxId?: string;
        minId?: string;
    }) => Promise<unknown>;
    local: (c: MastodonClient, opts?: {
        limit?: number;
        sinceId?: string;
        maxId?: string;
        minId?: string;
    }) => Promise<unknown>;
    tag: (c: MastodonClient, hashtag: string, opts?: {
        limit?: number;
        sinceId?: string;
        maxId?: string;
        minId?: string;
        local?: boolean;
    }) => Promise<unknown>;
    list: (c: MastodonClient, listId: string, opts?: {
        limit?: number;
        sinceId?: string;
        maxId?: string;
        minId?: string;
    }) => Promise<unknown>;
};
export declare const Media: {
    upload: (c: MastodonClient, file: File | Blob, description?: string) => Promise<unknown>;
};
export declare const Notifications: {
    list: (c: MastodonClient, opts?: {
        limit?: number;
        sinceId?: string;
        maxId?: string;
        minId?: string;
    }) => Promise<unknown>;
};
export declare const Lists: {
    list: (c: MastodonClient) => Promise<unknown>;
};
export declare const CustomEmojis: {
    list: (c: MastodonClient) => Promise<unknown>;
};
export declare const Instance: {
    get: (c: MastodonClient) => Promise<unknown>;
};
export type SearchType = "accounts" | "statuses" | "hashtags";
export declare const Search: {
    search: (c: MastodonClient, q: string, opts?: {
        type?: SearchType;
        limit?: number;
        resolve?: boolean;
        offset?: number;
    }) => Promise<unknown>;
};
