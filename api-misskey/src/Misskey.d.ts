// Hand-written TypeScript declarations for @f3liz/mazemaze-api-misskey (the `.`
// convenience layer). Decode/encode is delegated to the Melange layer — no Sury.

// ============= Result Type =============
// ReScript result<'ok, 'err> compiles to tagged union

export type Result<Ok, Err> =
  | { TAG: "Ok"; _0: Ok }
  | { TAG: "Error"; _0: Err };

// ============= Client =============

export type FetchFn = (
  url: string,
  method_: string,
  body: unknown | undefined
) => Promise<unknown>;

export interface MisskeyClient {
  readonly origin: string;
  readonly token: string | undefined;
  readonly fetchFn: FetchFn;
  streamClient: unknown;
}

export interface Subscription {
  dispose: () => void;
}

export interface ApiError {
  code: string;
  message: string;
  id: string;
}

// ============= Core Functions =============

/**
 * Connect to a Misskey instance.
 *
 * @example
 * ```ts
 * const client = connect("https://misskey.io", "your-token")
 * ```
 */
export function connect(
  origin: string,
  token?: string,
  fetch?: FetchFn
): MisskeyClient;

/** Make a generic API request to any endpoint. */
export function request(
  client: MisskeyClient,
  endpoint: string,
  params?: unknown
): Promise<Result<unknown, string>>;

/** Get current user info. */
export function currentUser(
  client: MisskeyClient
): Promise<Result<unknown, string>>;

/** Get client origin (instance URL). */
export function origin(client: MisskeyClient): string;

/** Get client authentication token. */
export function token(client: MisskeyClient): string | undefined;

/** Close client and cleanup (close streaming connections). */
export function close(client: MisskeyClient): void;

/** Check if error is permission denied. */
export function isPermissionDenied(error: unknown): boolean;

/** Check if error is an API error and extract error info. */
export function isAPIError(error: unknown): ApiError | undefined;

// ============= Notes API =============

export interface NotesModule {
  /** Create a note. */
  create(
    client: MisskeyClient,
    text: string,
    visibility?: Notes.Visibility,
    cw?: string,
    localOnly?: boolean,
    replyId?: string,
    renoteId?: string,
    fileIds?: string[]
  ): Promise<Result<unknown, string>>;

  /** Delete a note. */
  delete(
    client: MisskeyClient,
    noteId: string
  ): Promise<Result<unknown, string>>;

  /** Fetch timeline notes (one-time fetch). */
  fetch(
    client: MisskeyClient,
    type_: Notes.TimelineType,
    limit?: number,
    sinceId?: string,
    untilId?: string
  ): Promise<Result<unknown, string>>;

  /** Alias for fetch. */
  timeline(
    client: MisskeyClient,
    type_: Notes.TimelineType,
    limit?: number,
    sinceId?: string,
    untilId?: string
  ): Promise<Result<unknown, string>>;

  /** React to a note. */
  react(
    client: MisskeyClient,
    noteId: string,
    reaction: string
  ): Promise<Result<unknown, string>>;

  /** Remove reaction from a note. */
  unreact(
    client: MisskeyClient,
    noteId: string
  ): Promise<Result<unknown, string>>;

  /** Get a single note by ID. */
  show(
    client: MisskeyClient,
    noteId: string
  ): Promise<Result<unknown, string>>;

  /** Get replies/children of a note. */
  children(
    client: MisskeyClient,
    noteId: string,
    limit?: number,
    sinceId?: string,
    untilId?: string
  ): Promise<Result<unknown, string>>;

  /** Get the conversation thread for a note. */
  conversation(
    client: MisskeyClient,
    noteId: string,
    limit?: number
  ): Promise<Result<unknown, string>>;

  /** Vote on a poll attached to a note. */
  pollVote(
    client: MisskeyClient,
    noteId: string,
    choice: number
  ): Promise<Result<unknown, string>>;
}

export const Notes: NotesModule;

// ============= Following API =============

export interface FollowingModule {
  /** Follow a user. */
  follow(
    client: MisskeyClient,
    userId: string
  ): Promise<Result<unknown, string>>;

  /** Unfollow a user. */
  unfollow(
    client: MisskeyClient,
    userId: string
  ): Promise<Result<unknown, string>>;
}

export const Following: FollowingModule;

// ============= Favorites API =============

export interface FavoritesModule {
  /** Add a note to favorites. */
  create(
    client: MisskeyClient,
    noteId: string
  ): Promise<Result<unknown, string>>;

  /** Remove a note from favorites. */
  delete(
    client: MisskeyClient,
    noteId: string
  ): Promise<Result<unknown, string>>;
}

export const Favorites: FavoritesModule;

export namespace Notes {
  type Visibility = "public" | "home" | "followers" | "specified";

  type TimelineType =
    | "home"
    | "local"
    | "global"
    | "hybrid"
    | { NAME: "antenna"; VAL: string }
    | { NAME: "list"; VAL: string }
    | { NAME: "channel"; VAL: string };
}

// ============= Users API =============

export interface UsersModule {
  /** Get user profile by username (and optional host for remote users). */
  show(
    client: MisskeyClient,
    userId?: string,
    username?: string,
    host?: string
  ): Promise<Result<unknown, string>>;

  /** Get notes posted by a user. */
  notes(
    client: MisskeyClient,
    userId: string,
    limit?: number,
    withReplies?: boolean,
    withRenotes?: boolean,
    withFiles?: boolean,
    sinceId?: string,
    untilId?: string
  ): Promise<Result<unknown, string>>;
}

export const Users: UsersModule;

// ============= Stream API =============

export interface StreamModule {
  /** Subscribe to timeline for real-time notes. */
  timeline(
    client: MisskeyClient,
    type_: Stream.TimelineType,
    onNote: (note: unknown) => void
  ): Subscription;

  /** Subscribe to notifications. */
  notifications(
    client: MisskeyClient,
    onNotification: (notification: unknown) => void
  ): Subscription;

  /** Listen for connection events. */
  onConnected(client: MisskeyClient, callback: () => void): void;

  onDisconnected(client: MisskeyClient, callback: () => void): void;

  /** Close all streaming connections. */
  close(client: MisskeyClient): void;
}

export const Stream: StreamModule;

export namespace Stream {
  type TimelineType =
    | "home"
    | "local"
    | "global"
    | "hybrid"
    | { NAME: "antenna"; VAL: string }
    | { NAME: "list"; VAL: string }
    | { NAME: "channel"; VAL: string };
}

// ============= Emojis API =============

export interface EmojisModule {
  /** Get list of custom emojis from instance. */
  list(client: MisskeyClient): Promise<Result<Emojis.CustomEmoji[], string>>;
}

export const Emojis: EmojisModule;

export namespace Emojis {
  interface CustomEmoji {
    name: string;
    url: string;
    category: string | undefined;
    aliases: string[];
  }
}

// ============= Custom Timelines API =============

export interface CustomTimelinesModule {
  /** Fetch user's antennas. */
  antennas(client: MisskeyClient): Promise<Result<unknown[], string>>;

  /** Fetch user's lists. */
  lists(client: MisskeyClient): Promise<Result<unknown[], string>>;

  /** Fetch user's followed channels. */
  channels(client: MisskeyClient): Promise<Result<unknown[], string>>;

  /** Extract ID and name from a timeline item JSON. */
  extractIdAndName(item: unknown): [string, string] | undefined;
}

export const CustomTimelines: CustomTimelinesModule;

// ============= MiAuth API =============

export interface MiAuthModule {
  /** Convert a permission to Misskey's colon-separated format (e.g. "read:account"). */
  permissionToString(permission: MiAuth.Permission): string;

  /** Generate MiAuth URL for user authorization. */
  generateUrl(
    origin: string,
    name: string,
    permissions: MiAuth.Permission[],
    callback?: string,
    icon?: string
  ): MiAuth.AuthSession;

  /** Check if user has authorized the session. */
  check(
    origin: string,
    sessionId: string
  ): Promise<Result<MiAuth.CheckResult, string>>;

  /** Open auth URL in the current window. */
  openUrl(authUrl: string): void;

  /** Open auth URL in a new window. */
  openUrlInNewWindow(authUrl: string): void;
}

export const MiAuth: MiAuthModule;

export namespace MiAuth {
  type Permission =
    | "read_account"
    | "write_account"
    | "read_blocks"
    | "write_blocks"
    | "read_drive"
    | "write_drive"
    | "read_favorites"
    | "write_favorites"
    | "read_following"
    | "write_following"
    | "read_messaging"
    | "write_messaging"
    | "read_mutes"
    | "write_mutes"
    | "write_notes"
    | "read_notifications"
    | "write_notifications"
    | "read_reactions"
    | "write_reactions"
    | "write_votes"
    | "read_pages"
    | "write_pages"
    | "write_page_likes"
    | "read_page_likes"
    | "read_user_groups"
    | "write_user_groups"
    | "read_channels"
    | "write_channels"
    | "read_gallery"
    | "write_gallery"
    | "read_gallery_likes"
    | "write_gallery_likes"
    | "read_flash"
    | "write_flash"
    | "read_flash_likes"
    | "write_flash_likes";

  interface AuthSession {
    sessionId: string;
    authUrl: string;
  }

  interface CheckResult {
    token: string | undefined;
    user: unknown | undefined;
  }
}

// ============= Meta API =============

export interface MetaModule {
  /** Get instance metadata (includes VAPID public key for push notifications). */
  get(client: MisskeyClient): Promise<Result<Meta.InstanceMeta, string>>;
}

export const Meta: MetaModule;

export namespace Meta {
  interface InstanceMeta {
    swPublickey: string | undefined;
  }
}

// ============= Service Worker API =============

export interface SwModule {
  /** Register a push notification endpoint with the Misskey instance. */
  register(
    client: MisskeyClient,
    endpoint: string,
    auth: string,
    publickey: string,
    sendReadMessage?: boolean
  ): Promise<Result<Sw.Registration, string>>;

  /** Unregister a push notification endpoint. */
  unregister(
    client: MisskeyClient,
    endpoint: string
  ): Promise<Result<void, string>>;
}

export const Sw: SwModule;

export namespace Sw {
  interface Registration {
    state: string | undefined;
    key: string | undefined;
    userId: string;
    endpoint: string;
    sendReadMessage: boolean;
  }
}

// ============= Webhooks API =============

export interface WebhooksModule {
  /** Create a webhook on the Misskey instance. */
  create(
    client: MisskeyClient,
    name: string,
    url: string,
    secret: string,
    on: string[]
  ): Promise<Result<Webhooks.Webhook, string>>;

  /** Delete a webhook by ID. */
  delete(
    client: MisskeyClient,
    webhookId: string
  ): Promise<Result<void, string>>;

  /** List webhooks for the current user. */
  list(client: MisskeyClient): Promise<Result<Webhooks.Webhook[], string>>;
}

export const Webhooks: WebhooksModule;

export namespace Webhooks {
  interface Webhook {
    id: string;
    name: string;
    url: string;
    active: boolean;
  }
}

// ============= Drive API =============

export interface DriveModule {
  /** Upload a File object to the Misskey drive. Returns the drive file ID on success. */
  upload(
    client: MisskeyClient,
    file: File | Blob,
    sensitive?: boolean,
    onProgress?: (progress: Drive.UploadProgress) => void
  ): Promise<Result<string, string>>;
}

export const Drive: DriveModule;

export namespace Drive {
  interface UploadProgress {
    loaded: number;
    total: number;
  }
}
