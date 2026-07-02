// Hand-written TypeScript convenience layer for @f3liz/mazemaze-api-mastodon.
// Routes each operation through the generated melange-dist/Endpoints.js sends
// where possible; hand-rolls createStatus and uploadMedia (see notes below).
//
// Usage:
//   const c = connect("https://mastodon.social", { token: "my-token" })
//   const tl = await Timelines.home(c, { limit: 20 })

import {
  getAccountsVerifyCredentials_send,
  getAccount_send,
  getAccountStatuses_send,
  postAccountFollow_send,
  postAccountUnfollow_send,
  getAccountLookup_send,
  getStatus_send,
  deleteStatus_send,
  postStatusReblog_send,
  postStatusUnreblog_send,
  postStatusFavourite_send,
  postStatusUnfavourite_send,
  postStatusBookmark_send,
  postStatusUnbookmark_send,
  getStatusContext_send,
  postPollVotes_send,
  getTimelineHome_send,
  getTimelinePublic_send,
  getTimelinesTagByHashtag_send,
  getTimelinesListByListId_send,
  getNotifications_send,
  getLists_send,
  getCustomEmojis_send,
  getInstanceV2_send,
  getSearchV2_send,
} from "./melange-api/melange-dist/Endpoints.js";

// ============= Client types =============

export type FetchFn = (
  method: string,
  url: string,
  body: unknown
) => Promise<unknown>;

export interface MastodonClient {
  readonly origin: string;
  readonly token: string | undefined;
  readonly fetchFn: FetchFn;
}

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
export function connect(
  origin: string,
  opts?: { token?: string; fetch?: FetchFn }
): MastodonClient {
  const token = opts?.token;
  const fetchFn: FetchFn =
    opts?.fetch ??
    ((method, url, body) => {
      const isFormData =
        typeof FormData !== "undefined" && body instanceof FormData;
      return globalThis
        .fetch(origin + url, {
          method,
          headers: {
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
            ...(!isFormData ? { "Content-Type": "application/json" } : {}),
          },
          body: isFormData ? (body as BodyInit) : JSON.stringify(body),
        })
        .then((r) => r.json());
    });
  return { origin, token, fetchFn };
}

/** No-op. Included for API symmetry with other mazemaze clients. */
export function close(_c: MastodonClient): void {}

// ============= Accounts =============

export const Accounts = {
  verifyCredentials: (c: MastodonClient): Promise<unknown> =>
    getAccountsVerifyCredentials_send(c.fetchFn, {}),

  show: (c: MastodonClient, id: string): Promise<unknown> =>
    getAccount_send(c.fetchFn, { id }),

  statuses: (
    c: MastodonClient,
    id: string,
    opts?: {
      limit?: number;
      excludeReplies?: boolean;
      sinceId?: string;
      maxId?: string;
    }
  ): Promise<unknown> =>
    getAccountStatuses_send(c.fetchFn, {
      id,
      limit: opts?.limit,
      exclude_replies: opts?.excludeReplies,
      since_id: opts?.sinceId,
      max_id: opts?.maxId,
    }),

  follow: (c: MastodonClient, id: string): Promise<unknown> =>
    postAccountFollow_send(c.fetchFn, { id }),

  unfollow: (c: MastodonClient, id: string): Promise<unknown> =>
    postAccountUnfollow_send(c.fetchFn, { id }),

  lookup: (c: MastodonClient, acct: string): Promise<unknown> =>
    getAccountLookup_send(c.fetchFn, { acct }),
};

// ============= Statuses =============

export type StatusVisibility = "public" | "unlisted" | "private" | "direct";

export const Statuses = {
  show: (c: MastodonClient, id: string): Promise<unknown> =>
    getStatus_send(c.fetchFn, { id }),

  // Hand-rolled: createStatus_send passes {} as body — the generator did not
  // model the POST body for this endpoint. We build the JSON body directly.
  create: (
    c: MastodonClient,
    opts: {
      status?: string;
      visibility?: StatusVisibility;
      spoilerText?: string;
      inReplyToId?: string;
      mediaIds?: string[];
      language?: string;
    }
  ): Promise<unknown> => {
    const body: Record<string, unknown> = {};
    if (opts.status !== undefined) body["status"] = opts.status;
    if (opts.visibility !== undefined) body["visibility"] = opts.visibility;
    if (opts.spoilerText !== undefined) body["spoiler_text"] = opts.spoilerText;
    if (opts.inReplyToId !== undefined) body["in_reply_to_id"] = opts.inReplyToId;
    if (opts.mediaIds !== undefined) body["media_ids"] = opts.mediaIds;
    if (opts.language !== undefined) body["language"] = opts.language;
    return c.fetchFn("POST", "/api/v1/statuses", body);
  },

  delete: (c: MastodonClient, id: string): Promise<unknown> =>
    deleteStatus_send(c.fetchFn, { id }),

  reblog: (c: MastodonClient, id: string): Promise<unknown> =>
    postStatusReblog_send(c.fetchFn, { id }),

  unreblog: (c: MastodonClient, id: string): Promise<unknown> =>
    postStatusUnreblog_send(c.fetchFn, { id }),

  favourite: (c: MastodonClient, id: string): Promise<unknown> =>
    postStatusFavourite_send(c.fetchFn, { id }),

  unfavourite: (c: MastodonClient, id: string): Promise<unknown> =>
    postStatusUnfavourite_send(c.fetchFn, { id }),

  bookmark: (c: MastodonClient, id: string): Promise<unknown> =>
    postStatusBookmark_send(c.fetchFn, { id }),

  unbookmark: (c: MastodonClient, id: string): Promise<unknown> =>
    postStatusUnbookmark_send(c.fetchFn, { id }),

  context: (c: MastodonClient, id: string): Promise<unknown> =>
    getStatusContext_send(c.fetchFn, { id }),

  pollVote: (
    c: MastodonClient,
    pollId: string,
    choices: number[]
  ): Promise<unknown> =>
    postPollVotes_send(c.fetchFn, { id: pollId, choices }),
};

// ============= Timelines =============

export const Timelines = {
  home: (
    c: MastodonClient,
    opts?: { limit?: number; sinceId?: string; maxId?: string; minId?: string }
  ): Promise<unknown> =>
    getTimelineHome_send(c.fetchFn, {
      limit: opts?.limit,
      since_id: opts?.sinceId,
      max_id: opts?.maxId,
      min_id: opts?.minId,
    }),

  public: (
    c: MastodonClient,
    opts?: { limit?: number; sinceId?: string; maxId?: string; minId?: string }
  ): Promise<unknown> =>
    getTimelinePublic_send(c.fetchFn, {
      limit: opts?.limit,
      since_id: opts?.sinceId,
      max_id: opts?.maxId,
      min_id: opts?.minId,
    }),

  local: (
    c: MastodonClient,
    opts?: { limit?: number; sinceId?: string; maxId?: string; minId?: string }
  ): Promise<unknown> =>
    getTimelinePublic_send(c.fetchFn, {
      local: true,
      limit: opts?.limit,
      since_id: opts?.sinceId,
      max_id: opts?.maxId,
      min_id: opts?.minId,
    }),

  tag: (
    c: MastodonClient,
    hashtag: string,
    opts?: {
      limit?: number;
      sinceId?: string;
      maxId?: string;
      minId?: string;
      local?: boolean;
    }
  ): Promise<unknown> =>
    getTimelinesTagByHashtag_send(c.fetchFn, {
      hashtag,
      limit: opts?.limit,
      since_id: opts?.sinceId,
      max_id: opts?.maxId,
      min_id: opts?.minId,
      local: opts?.local,
    }),

  list: (
    c: MastodonClient,
    listId: string,
    opts?: { limit?: number; sinceId?: string; maxId?: string; minId?: string }
  ): Promise<unknown> =>
    getTimelinesListByListId_send(c.fetchFn, {
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
  upload: (
    c: MastodonClient,
    file: File | Blob,
    description?: string
  ): Promise<unknown> => {
    const form = new FormData();
    form.append("file", file);
    if (description !== undefined) form.append("description", description);
    return c.fetchFn("POST", "/api/v2/media", form);
  },
};

// ============= Notifications =============

export const Notifications = {
  list: (
    c: MastodonClient,
    opts?: {
      limit?: number;
      sinceId?: string;
      maxId?: string;
      minId?: string;
    }
  ): Promise<unknown> =>
    getNotifications_send(c.fetchFn, {
      limit: opts?.limit,
      since_id: opts?.sinceId,
      max_id: opts?.maxId,
      min_id: opts?.minId,
    }),
};

// ============= Lists =============

export const Lists = {
  list: (c: MastodonClient): Promise<unknown> =>
    getLists_send(c.fetchFn, {}),
};

// ============= Custom Emojis =============

export const CustomEmojis = {
  list: (c: MastodonClient): Promise<unknown> =>
    getCustomEmojis_send(c.fetchFn, {}),
};

// ============= Instance =============

export const Instance = {
  get: (c: MastodonClient): Promise<unknown> =>
    getInstanceV2_send(c.fetchFn, {}),
};

// ============= Search =============

export type SearchType = "accounts" | "statuses" | "hashtags";

export const Search = {
  search: (
    c: MastodonClient,
    q: string,
    opts?: {
      type?: SearchType;
      limit?: number;
      resolve?: boolean;
      offset?: number;
    }
  ): Promise<unknown> =>
    getSearchV2_send(c.fetchFn, {
      q,
      type_: opts?.type,
      limit: opts?.limit,
      resolve: opts?.resolve,
      offset: opts?.offset,
    }),
};
