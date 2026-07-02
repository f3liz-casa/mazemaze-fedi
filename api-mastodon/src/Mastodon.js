// Hand-written TypeScript convenience layer for @f3liz/mazemaze-api-mastodon.
// Routes each operation through the generated melange-dist/Endpoints.js sends
// where possible; hand-rolls createStatus and uploadMedia (see notes below).
//
// Usage:
//   const c = connect("https://mastodon.social", { token: "my-token" })
//   const tl = await Timelines.home(c, { limit: 20 })
import { getAccountsVerifyCredentials_send, getAccount_send, getAccountStatuses_send, postAccountFollow_send, postAccountUnfollow_send, getAccountLookup_send, getStatus_send, deleteStatus_send, postStatusReblog_send, postStatusUnreblog_send, postStatusFavourite_send, postStatusUnfavourite_send, postStatusBookmark_send, postStatusUnbookmark_send, getStatusContext_send, postPollVotes_send, getTimelineHome_send, getTimelinePublic_send, getTimelinesTagByHashtag_send, getTimelinesListByListId_send, getNotifications_send, getLists_send, getCustomEmojis_send, getInstanceV2_send, getSearchV2_send, } from "./melange-api/melange-dist/Endpoints.js";
// ============= connect / close =============
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
export function connect(origin, opts) {
    const token = opts?.token;
    const fetchFn = opts?.fetch ??
        ((method, url, body) => {
            const isFormData = typeof FormData !== "undefined" && body instanceof FormData;
            return globalThis
                .fetch(origin + url, {
                method,
                headers: {
                    ...(token ? { Authorization: `Bearer ${token}` } : {}),
                    ...(!isFormData ? { "Content-Type": "application/json" } : {}),
                },
                body: isFormData ? body : JSON.stringify(body),
            })
                .then((r) => r.json());
        });
    return { origin, token, fetchFn };
}
/** No-op. Included for API symmetry with other mazemaze clients. */
export function close(_c) { }
// ============= Accounts =============
export const Accounts = {
    verifyCredentials: (c) => getAccountsVerifyCredentials_send(c.fetchFn, {}),
    show: (c, id) => getAccount_send(c.fetchFn, { id }),
    statuses: (c, id, opts) => getAccountStatuses_send(c.fetchFn, {
        id,
        limit: opts?.limit,
        exclude_replies: opts?.excludeReplies,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
    }),
    follow: (c, id) => postAccountFollow_send(c.fetchFn, { id }),
    unfollow: (c, id) => postAccountUnfollow_send(c.fetchFn, { id }),
    lookup: (c, acct) => getAccountLookup_send(c.fetchFn, { acct }),
};
export const Statuses = {
    show: (c, id) => getStatus_send(c.fetchFn, { id }),
    // Hand-rolled: createStatus_send passes {} as body — the generator did not
    // model the POST body for this endpoint. We build the JSON body directly.
    create: (c, opts) => {
        const body = {};
        if (opts.status !== undefined)
            body["status"] = opts.status;
        if (opts.visibility !== undefined)
            body["visibility"] = opts.visibility;
        if (opts.spoilerText !== undefined)
            body["spoiler_text"] = opts.spoilerText;
        if (opts.inReplyToId !== undefined)
            body["in_reply_to_id"] = opts.inReplyToId;
        if (opts.mediaIds !== undefined)
            body["media_ids"] = opts.mediaIds;
        if (opts.language !== undefined)
            body["language"] = opts.language;
        return c.fetchFn("POST", "/api/v1/statuses", body);
    },
    delete: (c, id) => deleteStatus_send(c.fetchFn, { id }),
    reblog: (c, id) => postStatusReblog_send(c.fetchFn, { id }),
    unreblog: (c, id) => postStatusUnreblog_send(c.fetchFn, { id }),
    favourite: (c, id) => postStatusFavourite_send(c.fetchFn, { id }),
    unfavourite: (c, id) => postStatusUnfavourite_send(c.fetchFn, { id }),
    bookmark: (c, id) => postStatusBookmark_send(c.fetchFn, { id }),
    unbookmark: (c, id) => postStatusUnbookmark_send(c.fetchFn, { id }),
    context: (c, id) => getStatusContext_send(c.fetchFn, { id }),
    pollVote: (c, pollId, choices) => postPollVotes_send(c.fetchFn, { id: pollId, choices }),
};
// ============= Timelines =============
export const Timelines = {
    home: (c, opts) => getTimelineHome_send(c.fetchFn, {
        limit: opts?.limit,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
        min_id: opts?.minId,
    }),
    public: (c, opts) => getTimelinePublic_send(c.fetchFn, {
        limit: opts?.limit,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
        min_id: opts?.minId,
    }),
    local: (c, opts) => getTimelinePublic_send(c.fetchFn, {
        local: true,
        limit: opts?.limit,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
        min_id: opts?.minId,
    }),
    tag: (c, hashtag, opts) => getTimelinesTagByHashtag_send(c.fetchFn, {
        hashtag,
        limit: opts?.limit,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
        min_id: opts?.minId,
        local: opts?.local,
    }),
    list: (c, listId, opts) => getTimelinesListByListId_send(c.fetchFn, {
        list_id: listId,
        limit: opts?.limit,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
        min_id: opts?.minId,
    }),
};
// ============= Media =============
export const Media = {
    // Hand-rolled: createMediaV2_send passes {} as body — multipart upload
    // requires FormData. The default fetchFn special-cases FormData (no
    // JSON.stringify, no explicit Content-Type so the browser sets the boundary).
    upload: (c, file, description) => {
        const form = new FormData();
        form.append("file", file);
        if (description !== undefined)
            form.append("description", description);
        return c.fetchFn("POST", "/api/v2/media", form);
    },
};
// ============= Notifications =============
export const Notifications = {
    list: (c, opts) => getNotifications_send(c.fetchFn, {
        limit: opts?.limit,
        since_id: opts?.sinceId,
        max_id: opts?.maxId,
        min_id: opts?.minId,
    }),
};
// ============= Lists =============
export const Lists = {
    list: (c) => getLists_send(c.fetchFn, {}),
};
// ============= Custom Emojis =============
export const CustomEmojis = {
    list: (c) => getCustomEmojis_send(c.fetchFn, {}),
};
// ============= Instance =============
export const Instance = {
    get: (c) => getInstanceV2_send(c.fetchFn, {}),
};
export const Search = {
    search: (c, q, opts) => getSearchV2_send(c.fetchFn, {
        q,
        type_: opts?.type,
        limit: opts?.limit,
        resolve: opts?.resolve,
        offset: opts?.offset,
    }),
};
