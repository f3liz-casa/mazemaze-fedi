// Minimal type declarations for the generated Mastodon Endpoints.js.
// Only the functions used by src/Mastodon.ts are declared here.
// The JS file contains the full implementation with JSDoc; this file exists
// so tsc can type-check Mastodon.ts without processing the melange runtime.
//
// This source lives in src/melange-api-types/ (committed) and is copied into
// src/melange-api/melange-dist/ by the build:write-types script, because
// build:melange wipes melange-dist/ on each run.

type _Fetch = (method: string, url: string, body: unknown) => Promise<unknown>;

export function getAccountsVerifyCredentials_send(fetch: _Fetch, req: Record<string, never>): Promise<unknown>;
export function getAccount_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function getAccountStatuses_send(fetch: _Fetch, req: {
  id: string;
  limit?: number;
  exclude_replies?: boolean;
  since_id?: string;
  max_id?: string;
  min_id?: string;
  exclude_reblogs?: boolean;
  pinned?: boolean;
  only_media?: boolean;
  tagged?: string;
}): Promise<unknown>;
export function postAccountFollow_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postAccountUnfollow_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function getAccountLookup_send(fetch: _Fetch, req: { acct: string }): Promise<unknown>;

export function getStatus_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function deleteStatus_send(fetch: _Fetch, req: { id: string; delete_media?: boolean }): Promise<unknown>;
export function postStatusReblog_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postStatusUnreblog_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postStatusFavourite_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postStatusUnfavourite_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postStatusBookmark_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postStatusUnbookmark_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function getStatusContext_send(fetch: _Fetch, req: { id: string }): Promise<unknown>;
export function postPollVotes_send(fetch: _Fetch, req: { id: string; choices: number[] }): Promise<unknown>;

export function getTimelineHome_send(fetch: _Fetch, req: {
  limit?: number;
  since_id?: string;
  max_id?: string;
  min_id?: string;
}): Promise<unknown>;
export function getTimelinePublic_send(fetch: _Fetch, req: {
  local?: boolean;
  limit?: number;
  since_id?: string;
  max_id?: string;
  min_id?: string;
  only_media?: boolean;
  remote?: boolean;
}): Promise<unknown>;
export function getTimelinesTagByHashtag_send(fetch: _Fetch, req: {
  hashtag: string;
  limit?: number;
  since_id?: string;
  max_id?: string;
  min_id?: string;
  local?: boolean;
  only_media?: boolean;
  remote?: boolean;
  all?: string[];
  any?: string[];
  none?: string[];
}): Promise<unknown>;
export function getTimelinesListByListId_send(fetch: _Fetch, req: {
  list_id: string;
  limit?: number;
  since_id?: string;
  max_id?: string;
  min_id?: string;
}): Promise<unknown>;

export function getNotifications_send(fetch: _Fetch, req: {
  limit?: number;
  since_id?: string;
  max_id?: string;
  min_id?: string;
  account_id?: string;
  include_filtered?: boolean;
  supported_types?: string[];
}): Promise<unknown>;

export function getLists_send(fetch: _Fetch, req: Record<string, never>): Promise<unknown>;
export function getCustomEmojis_send(fetch: _Fetch, req: Record<string, never>): Promise<unknown>;
export function getInstanceV2_send(fetch: _Fetch, req: Record<string, never>): Promise<unknown>;

export function getSearchV2_send(fetch: _Fetch, req: {
  q: string;
  type_?: string;
  limit?: number;
  resolve?: boolean;
  offset?: number;
  account_id?: string;
  exclude_unreviewed?: boolean;
  following?: boolean;
  max_id?: string;
  min_id?: string;
}): Promise<unknown>;
