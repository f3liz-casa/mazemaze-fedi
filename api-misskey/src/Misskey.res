// SPDX-License-Identifier: MPL-2.0
// Misskey.res - Clean, intuitive API for Misskey
//
// This is the main entry point providing a simple, discoverable API.
//
// Quick Start:
//   let client = Misskey.connect("https://misskey.io", ~token="your-token")
//
//   // Fetch timeline
//   let notes = await client->Misskey.Notes.fetch(#home, ~limit=20, ())
//
//   // Stream timeline
//   let sub = client->Misskey.Stream.timeline(#home, note => {
//     Console.log2("New note!", note)
//   })
//
// The default fetch implementation uses the browser's Fetch API.
// You can override it by passing ~fetch to connect() for custom behavior
// (e.g., adding performance metrics, retries, logging, etc.).

// ============================================================================
// Client & Configuration
// ============================================================================

// The fetch function signature used by the generated wrapper
type fetchFn = (~url: string, ~method_: string, ~body: option<JSON.t>) => Promise.t<JSON.t>

type t = {
  origin: string,
  token: option<string>,
  fetchFn: fetchFn,
  mutable streamClient: option<StreamClient.t>,
}

// Inject auth token into request body (Misskey API convention)
let injectToken = (body: option<JSON.t>, token: option<string>): option<JSON.t> => {
  switch (body, token) {
  | (Some(jsonBody), Some(t)) =>
    switch jsonBody->JSON.Decode.object {
    | Some(obj) =>
      obj->Dict.set("i", t->JSON.Encode.string)
      Some(obj->JSON.Encode.object)
    | None => body
    }
  | (None, Some(t)) =>
    let obj = Dict.make()
    obj->Dict.set("i", t->JSON.Encode.string)
    Some(obj->JSON.Encode.object)
  | _ => body
  }
}

// Default fetch implementation using ofetch.
// Uses baseURL for origin, auto JSON parsing, and token injection.
let defaultFetch = (~origin: string, ~token: option<string>) => {
  (~url: string, ~method_: string, ~body: option<JSON.t>): Promise.t<JSON.t> => {
    let bodyWithToken = injectToken(body, token)
    Ofetch.ofetch(url, {
      baseURL: `${origin}/api`,
      method: method_,
      body: ?bodyWithToken,
      retry: 0,
    })
  }
}

/// Connect to a Misskey instance.
///
/// The default fetch uses the browser's Fetch API, injects the token into
/// the request body, and constructs URLs from the origin. Override ~fetch
/// to add custom behavior (logging, retries, metrics, etc.).
///
/// Example:
///   let client = Misskey.connect("https://misskey.io", ~token="abc123")
///
///   // With custom fetch:
///   let client = Misskey.connect("https://misskey.io", ~token="abc123", ~fetch=myCustomFetch)
let connect = (origin: string, ~token: option<string>=?, ~fetch: option<fetchFn>=?): t => {
  let fetchFn = switch fetch {
  | Some(f) => f
  | None => defaultFetch(~origin, ~token)
  }

  {
    origin,
    token,
    fetchFn,
    streamClient: None,
  }
}

/// fetch hook for the typed Endpoints layer (Melange-backed). Posts the
/// encoded request to the instance API; the Melange encoder omits absent
/// optionals (`[@json.drop_default]`), so no null reaches the server. Token
/// injection stays in the underlying fetchFn.
///   let notes = await Endpoints.Notes.PostNotesFeatured.send(
///     Misskey.apiFetch(client), {limit: Some(20), untilId: None, channelId: None})
let apiFetch = (client: t): Endpoints.fetchFn =>
  (method_, url, body) => client.fetchFn(~url, ~method_, ~body=Some(body))

// ============================================================================
// Generic Request
// ============================================================================

/// Make a generic API request to any endpoint.
///
/// Example:
///   let user = await client->Misskey.request("i", ())
let request = async (
  client: t,
  endpoint: string,
  ~params: JSON.t=JSON.Encode.object(Dict.make()),
  (),
): result<JSON.t, string> => {
  try {
    let json = await client.fetchFn(~url=endpoint, ~method_="POST", ~body=Some(params))
    Ok(json)
  } catch {
  | err =>
    // ofetch attaches response data to error.data for non-2xx responses
    let errorData: option<JSON.t> = (err->Obj.magic)["data"]
    let baseMsg = switch err->JsExn.fromException {
    | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
    | None => "Unknown error"
    }
    let msg = switch errorData {
    | Some(data) =>
      switch data->JSON.Decode.object {
      | Some(obj) =>
        switch obj->Dict.get("error")->Option.flatMap(JSON.Decode.object) {
        | Some(errObj) =>
          let code =
            errObj->Dict.get("code")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
          let message =
            errObj->Dict.get("message")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
          `${baseMsg} [${code}] ${message}`
        | None => baseMsg
        }
      | None => baseMsg
      }
    | None => baseMsg
    }
    Error(msg)
  }
}

/// Get current user info.
let currentUser = (client: t): promise<result<JSON.t, string>> => {
  request(client, "i", ())
}

/// Get client origin (instance URL).
let origin = (client: t): string => client.origin

/// Get client authentication token.
let token = (client: t): option<string> => client.token

/// Close client and cleanup (close streaming connections).
let close = (client: t): unit => {
  client.streamClient->Option.forEach(s => s->StreamClient.close)
  client.streamClient = None
}

// ============================================================================
// Notes API
// ============================================================================

module Notes = {
  type visibility = [#public | #home | #followers | #specified]

  type timelineType = [
    | #home
    | #local
    | #global
    | #hybrid
    | #antenna(string)
    | #list(string)
    | #channel(string)
  ]

  /// Create a note.
  let create = (
    client: t,
    text: string,
    ~visibility: visibility=#public,
    ~cw: option<string>=?,
    ~localOnly: bool=false,
    ~replyId: option<string>=?,
    ~renoteId: option<string>=?,
    ~fileIds: option<array<string>>=?,
    (),
  ): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("text", text->JSON.Encode.string)

    let vis = switch visibility {
    | #public => "public"
    | #home => "home"
    | #followers => "followers"
    | #specified => "specified"
    }
    params->Dict.set("visibility", vis->JSON.Encode.string)
    params->Dict.set("localOnly", localOnly->JSON.Encode.bool)

    cw->Option.forEach(v => params->Dict.set("cw", v->JSON.Encode.string))
    replyId->Option.forEach(v => params->Dict.set("replyId", v->JSON.Encode.string))
    renoteId->Option.forEach(v => params->Dict.set("renoteId", v->JSON.Encode.string))
    fileIds->Option.forEach(ids =>
      params->Dict.set("fileIds", ids->Array.map(JSON.Encode.string)->JSON.Encode.array)
    )

    request(client, "notes/create", ~params=params->JSON.Encode.object, ())
  }

  /// Delete a note.
  let delete = (client: t, noteId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    request(client, "notes/delete", ~params=params->JSON.Encode.object, ())
  }

  /// Fetch timeline notes (one-time fetch, not streaming).
  let fetch = (
    client: t,
    type_: timelineType,
    ~limit: int=10,
    ~sinceId: option<string>=?,
    ~untilId: option<string>=?,
    (),
  ): promise<result<JSON.t, string>> => {
    let (endpoint, extraParams) = switch type_ {
    | #home => ("notes/timeline", None)
    | #local => ("notes/local-timeline", None)
    | #global => ("notes/global-timeline", None)
    | #hybrid => ("notes/hybrid-timeline", None)
    | #antenna(id) => {
        let p = Dict.make()
        p->Dict.set("antennaId", id->JSON.Encode.string)
        ("antennas/notes", Some(p))
      }
    | #list(id) => {
        let p = Dict.make()
        p->Dict.set("listId", id->JSON.Encode.string)
        ("notes/user-list-timeline", Some(p))
      }
    | #channel(id) => {
        let p = Dict.make()
        p->Dict.set("channelId", id->JSON.Encode.string)
        ("channels/timeline", Some(p))
      }
    }

    let params = Dict.make()
    params->Dict.set("limit", limit->JSON.Encode.int)
    sinceId->Option.forEach(v => params->Dict.set("sinceId", v->JSON.Encode.string))
    untilId->Option.forEach(v => params->Dict.set("untilId", v->JSON.Encode.string))

    extraParams->Option.forEach(extra => {
      extra
      ->Dict.toArray
      ->Array.forEach(((key, value)) => {
        params->Dict.set(key, value)
      })
    })

    request(client, endpoint, ~params=params->JSON.Encode.object, ())
  }

  /// Alias for fetch.
  let timeline = fetch

  /// React to a note.
  let react = (client: t, noteId: string, reaction: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    params->Dict.set("reaction", reaction->JSON.Encode.string)
    request(client, "notes/reactions/create", ~params=params->JSON.Encode.object, ())
  }

  /// Remove reaction from a note.
  let unreact = (client: t, noteId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    request(client, "notes/reactions/delete", ~params=params->JSON.Encode.object, ())
  }

  /// Get a single note by ID.
  let show = (client: t, noteId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    request(client, "notes/show", ~params=params->JSON.Encode.object, ())
  }

  /// Get replies/children of a note.
  let children = (
    client: t,
    noteId: string,
    ~limit: int=30,
    ~sinceId: option<string>=?,
    ~untilId: option<string>=?,
    (),
  ): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    params->Dict.set("limit", limit->JSON.Encode.int)
    sinceId->Option.forEach(v => params->Dict.set("sinceId", v->JSON.Encode.string))
    untilId->Option.forEach(v => params->Dict.set("untilId", v->JSON.Encode.string))
    request(client, "notes/children", ~params=params->JSON.Encode.object, ())
  }

  /// Get the conversation thread (parent notes) for a note.
  let conversation = (
    client: t,
    noteId: string,
    ~limit: int=30,
    (),
  ): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    params->Dict.set("limit", limit->JSON.Encode.int)
    request(client, "notes/conversation", ~params=params->JSON.Encode.object, ())
  }

  /// Vote on a poll attached to a note.
  let pollVote = (client: t, noteId: string, choice: int): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    params->Dict.set("choice", choice->JSON.Encode.int)
    request(client, "notes/polls/vote", ~params=params->JSON.Encode.object, ())
  }
}

// ============================================================================
// Following API
// ============================================================================

module Following = {
  /// Follow a user.
  let follow = (client: t, userId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("userId", userId->JSON.Encode.string)
    request(client, "following/create", ~params=params->JSON.Encode.object, ())
  }

  /// Unfollow a user.
  let unfollow = (client: t, userId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("userId", userId->JSON.Encode.string)
    request(client, "following/delete", ~params=params->JSON.Encode.object, ())
  }
}

// ============================================================================
// Favorites API
// ============================================================================

module Favorites = {
  /// Add a note to favorites.
  let create = (client: t, noteId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    request(client, "notes/favorites/create", ~params=params->JSON.Encode.object, ())
  }

  /// Remove a note from favorites.
  let delete = (client: t, noteId: string): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("noteId", noteId->JSON.Encode.string)
    request(client, "notes/favorites/delete", ~params=params->JSON.Encode.object, ())
  }
}

// ============================================================================
// Users API
// ============================================================================

module Users = {
  /// Get user profile by username (and optional host for remote users).
  let show = (
    client: t,
    ~userId: option<string>=?,
    ~username: option<string>=?,
    ~host: option<string>=?,
    (),
  ): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    userId->Option.forEach(v => params->Dict.set("userId", v->JSON.Encode.string))
    username->Option.forEach(v => params->Dict.set("username", v->JSON.Encode.string))
    host->Option.forEach(v => params->Dict.set("host", v->JSON.Encode.string))
    request(client, "users/show", ~params=params->JSON.Encode.object, ())
  }

  /// Get notes posted by a user.
  let notes = (
    client: t,
    userId: string,
    ~limit: int=20,
    ~withReplies: bool=false,
    ~withRenotes: bool=true,
    ~withFiles: bool=false,
    ~sinceId: option<string>=?,
    ~untilId: option<string>=?,
    (),
  ): promise<result<JSON.t, string>> => {
    let params = Dict.make()
    params->Dict.set("userId", userId->JSON.Encode.string)
    params->Dict.set("limit", limit->JSON.Encode.int)
    params->Dict.set("withReplies", withReplies->JSON.Encode.bool)
    params->Dict.set("withRenotes", withRenotes->JSON.Encode.bool)
    params->Dict.set("withFiles", withFiles->JSON.Encode.bool)
    sinceId->Option.forEach(v => params->Dict.set("sinceId", v->JSON.Encode.string))
    untilId->Option.forEach(v => params->Dict.set("untilId", v->JSON.Encode.string))
    request(client, "users/notes", ~params=params->JSON.Encode.object, ())
  }
}

module Stream = {
  type subscription = {dispose: unit => unit}

  let ensureStream = (client: t): StreamClient.t => {
    switch client.streamClient {
    | Some(s) => s
    | None =>
      let s = StreamClient.make(~origin=client.origin, ~credential=?client.token, ())
      client.streamClient = Some(s)
      s
    }
  }

  type timelineType = [
    | #home
    | #local
    | #global
    | #hybrid
    | #antenna(string)
    | #list(string)
    | #channel(string)
  ]

  /// Subscribe to timeline for real-time notes.
  let timeline = (client: t, type_: timelineType, onNote: JSON.t => unit): subscription => {
    let stream = ensureStream(client)

    let (channel, params) = switch type_ {
    | #home => ("homeTimeline", None)
    | #local => ("localTimeline", None)
    | #global => ("globalTimeline", None)
    | #hybrid => ("hybridTimeline", None)
    | #antenna(id) =>
      let p = Dict.make()
      p->Dict.set("antennaId", id->JSON.Encode.string)
      ("antenna", Some(p->JSON.Encode.object))
    | #list(id) =>
      let p = Dict.make()
      p->Dict.set("listId", id->JSON.Encode.string)
      ("userList", Some(p->JSON.Encode.object))
    | #channel(id) =>
      let p = Dict.make()
      p->Dict.set("channelId", id->JSON.Encode.string)
      ("channel", Some(p->JSON.Encode.object))
    }

    let conn = switch params {
    | Some(p) => stream->StreamClient.useChannel(~channel, ~params=p, ())
    | None => stream->StreamClient.useSharedChannel(~channel, ())
    }

    conn->StreamConnection.on("note", onNote)

    {dispose: () => StreamConnection.dispose(conn)}
  }

  /// Subscribe to notifications.
  let notifications = (client: t, onNotification: JSON.t => unit): subscription => {
    let stream = ensureStream(client)
    let conn = stream->StreamClient.useSharedChannel(~channel="main", ())
    conn->StreamConnection.on("notification", onNotification)
    {dispose: () => StreamConnection.dispose(conn)}
  }

  /// Listen for connection events.
  let onConnected = (client: t, callback: unit => unit): unit => {
    let stream = ensureStream(client)
    stream->StreamClient.onConnected(callback)
  }

  let onDisconnected = (client: t, callback: unit => unit): unit => {
    let stream = ensureStream(client)
    stream->StreamClient.onDisconnected(callback)
  }

  /// Close all streaming connections.
  let close = (client: t): unit => {
    client.streamClient->Option.forEach(s => s->StreamClient.close)
    client.streamClient = None
  }
}

// ============================================================================
// Emojis API
// ============================================================================

module Emojis = {
  type customEmoji = {
    name: string,
    url: string,
    category: option<string>,
    aliases: array<string>,
  }

  let decodeCustomEmoji = (json: JSON.t): option<customEmoji> => {
    switch json->JSON.Decode.object {
    | Some(obj) =>
      switch (
        obj->Dict.get("name")->Option.flatMap(JSON.Decode.string),
        obj->Dict.get("url")->Option.flatMap(JSON.Decode.string),
      ) {
      | (Some(name), Some(url)) =>
        let category = obj->Dict.get("category")->Option.flatMap(JSON.Decode.string)
        let aliases = switch obj->Dict.get("aliases")->Option.flatMap(JSON.Decode.array) {
        | Some(arr) => arr->Array.filterMap(JSON.Decode.string)->Array.filter(s => s != "")
        | None => []
        }
        Some({name, url, category, aliases})
      | _ => None
      }
    | None => None
    }
  }

  /// Get list of custom emojis from instance.
  let list = async (client: t): result<array<customEmoji>, string> => {
    let result = await request(client, "emojis", ())
    switch result {
    | Ok(json) =>
      switch json->JSON.Decode.object {
      | Some(obj) =>
        switch obj->Dict.get("emojis")->Option.flatMap(JSON.Decode.array) {
        | Some(emojisArray) => Ok(emojisArray->Array.filterMap(decodeCustomEmoji))
        | None => Ok([])
        }
      | None => Ok([])
      }
    | Error(e) => Error(e)
    }
  }
}

// ============================================================================
// Custom Timelines API (Antennas, Lists, Channels)
// ============================================================================

module CustomTimelines = {
  /// Fetch user's antennas.
  let antennas = async (client: t): result<array<JSON.t>, string> => {
    let result = await request(client, "antennas/list", ())
    switch result {
    | Ok(json) =>
      switch json->JSON.Decode.array {
      | Some(arr) => Ok(arr)
      | None => Ok([])
      }
    | Error(e) => Error(e)
    }
  }

  /// Fetch user's lists.
  let lists = async (client: t): result<array<JSON.t>, string> => {
    let result = await request(client, "users/lists/list", ())
    switch result {
    | Ok(json) =>
      switch json->JSON.Decode.array {
      | Some(arr) => Ok(arr)
      | None => Ok([])
      }
    | Error(e) => Error(e)
    }
  }

  /// Fetch user's followed channels.
  let channels = async (client: t): result<array<JSON.t>, string> => {
    let result = await request(client, "channels/followed", ())
    switch result {
    | Ok(json) =>
      switch json->JSON.Decode.array {
      | Some(arr) => Ok(arr)
      | None => Ok([])
      }
    | Error(e) => Error(e)
    }
  }

  /// Extract ID and name from a timeline item JSON.
  let extractIdAndName = (item: JSON.t): option<(string, string)> => {
    item
    ->JSON.Decode.object
    ->Option.flatMap(obj => {
      let id = obj->Dict.get("id")->Option.flatMap(JSON.Decode.string)
      let name = obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)
      switch (id, name) {
      | (Some(id), Some(name)) => Some((id, name))
      | _ => None
      }
    })
  }
}

// ============================================================================
// MiAuth - OAuth-like authentication
// ============================================================================

module MiAuth = {
  type permission = [
    | #read_account
    | #write_account
    | #read_blocks
    | #write_blocks
    | #read_drive
    | #write_drive
    | #read_favorites
    | #write_favorites
    | #read_following
    | #write_following
    | #read_messaging
    | #write_messaging
    | #read_mutes
    | #write_mutes
    | #write_notes
    | #read_notifications
    | #write_notifications
    | #read_reactions
    | #write_reactions
    | #write_votes
    | #read_pages
    | #write_pages
    | #write_page_likes
    | #read_page_likes
    | #read_user_groups
    | #write_user_groups
    | #read_channels
    | #write_channels
    | #read_gallery
    | #write_gallery
    | #read_gallery_likes
    | #write_gallery_likes
    | #read_flash
    | #write_flash
    | #read_flash_likes
    | #write_flash_likes
  ]

  let permissionToString = (perm: permission): string => {
    switch perm {
    | #read_account => "read:account"
    | #write_account => "write:account"
    | #read_blocks => "read:blocks"
    | #write_blocks => "write:blocks"
    | #read_drive => "read:drive"
    | #write_drive => "write:drive"
    | #read_favorites => "read:favorites"
    | #write_favorites => "write:favorites"
    | #read_following => "read:following"
    | #write_following => "write:following"
    | #read_messaging => "read:messaging"
    | #write_messaging => "write:messaging"
    | #read_mutes => "read:mutes"
    | #write_mutes => "write:mutes"
    | #write_notes => "write:notes"
    | #read_notifications => "read:notifications"
    | #write_notifications => "write:notifications"
    | #read_reactions => "read:reactions"
    | #write_reactions => "write:reactions"
    | #write_votes => "write:votes"
    | #read_pages => "read:pages"
    | #write_pages => "write:pages"
    | #write_page_likes => "write:page-likes"
    | #read_page_likes => "read:page-likes"
    | #read_user_groups => "read:user-groups"
    | #write_user_groups => "write:user-groups"
    | #read_channels => "read:channels"
    | #write_channels => "write:channels"
    | #read_gallery => "read:gallery"
    | #write_gallery => "write:gallery"
    | #read_gallery_likes => "read:gallery-likes"
    | #write_gallery_likes => "write:gallery-likes"
    | #read_flash => "read:flash"
    | #write_flash => "write:flash"
    | #read_flash_likes => "read:flash-likes"
    | #write_flash_likes => "write:flash-likes"
    }
  }

  type authSession = {
    sessionId: string,
    authUrl: string,
  }

  type checkResult = {
    token: option<string>,
    user: option<JSON.t>,
  }

  @val external encodeURIComponent: string => string = "encodeURIComponent"
  @val @scope("crypto") external randomUUID: unit => string = "randomUUID"

  let generateSessionId = (): string => {
    randomUUID()->String.replaceAll("-", "")
  }

  /// Generate MiAuth URL for user authorization.
  let generateUrl = (
    ~origin: string,
    ~name: string,
    ~permissions: array<permission>,
    ~callback: option<string>=?,
    ~icon: option<string>=?,
    (),
  ): authSession => {
    let sessionId = generateSessionId()
    let permissionStrings = permissions->Array.map(permissionToString)
    let permissionParam = permissionStrings->Array.join(",")
    let encodedName = encodeURIComponent(name)
    let encodedPermission = encodeURIComponent(permissionParam)

    let baseUrl = `${origin}/miauth/${sessionId}?name=${encodedName}&permission=${encodedPermission}`

    let withCallback = switch callback {
    | Some(cb) => `${baseUrl}&callback=${encodeURIComponent(cb)}`
    | None => baseUrl
    }

    let authUrl = switch icon {
    | Some(ic) => `${withCallback}&icon=${encodeURIComponent(ic)}`
    | None => withCallback
    }

    {sessionId, authUrl}
  }

  /// Check if user has authorized the session.
  ///
  /// Returns Ok with token/user on success.
  /// The Misskey MiAuth check endpoint returns `{ok: true, token, user}` when
  /// authorization is complete, and `{ok: false}` when still pending.
  let check = async (~origin: string, ~sessionId: string): result<checkResult, string> => {
    try {
      let json = await Ofetch.ofetch(`${origin}/api/miauth/${sessionId}/check`, {
        method: "POST",
        body: JSON.Encode.object(Dict.make()),
        retry: 0,
      })
      switch json->JSON.Decode.object {
      | Some(obj) =>
        let isOk = obj->Dict.get("ok")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
        if isOk {
          let token = obj->Dict.get("token")->Option.flatMap(JSON.Decode.string)
          let user = obj->Dict.get("user")
          Ok({token, user})
        } else {
          Ok({token: None, user: None})
        }
      | None => Error("Unexpected response format")
      }
    } catch {
    | err =>
      let msg = switch err->JsExn.fromException {
      | Some(jsExn) => JsExn.message(jsExn)->Option.getOr("Unknown error")
      | None => "Unknown error"
      }
      Error(msg)
    }
  }

  @val @scope(("window", "location"))
  external windowLocationAssign: string => unit = "assign"

  /// Open auth URL in the current window.
  let openUrl = (authUrl: string): unit => {
    windowLocationAssign(authUrl)
  }

  @val @scope("window")
  external windowOpen: (string, string, string) => Nullable.t<{..}> = "open"

  /// Open auth URL in a new window.
  let openUrlInNewWindow = (authUrl: string): unit => {
    let _ = windowOpen(authUrl, "_blank", "width=600,height=800")
  }
}

// ============================================================================
// Error Utilities
// ============================================================================

type apiError = {
  code: string,
  message: string,
  id: string,
}

/// Check if error is permission denied.
let isPermissionDenied = (error: JSON.t): bool => {
  switch error->JSON.Decode.object {
  | Some(obj) =>
    switch obj->Dict.get("code")->Option.flatMap(JSON.Decode.string) {
    | Some("PERMISSION_DENIED") => true
    | _ => false
    }
  | None => false
  }
}

/// Check if error is an API error and extract error info.
// ============================================================================
// Instance Meta API
// ============================================================================

module Meta = {
  type meta = {
    swPublickey: option<string>,
  }

  /// Get instance metadata (includes VAPID public key for push notifications).
  let get = async (client: t): result<meta, string> => {
    switch await request(client, "meta", ()) {
    | Ok(json) =>
      switch json->JSON.Decode.object {
      | Some(obj) =>
        Ok({
          swPublickey: obj
          ->Dict.get("swPublickey")
          ->Option.flatMap(JSON.Decode.string),
        })
      | None => Error("Invalid meta response")
      }
    | Error(e) => Error(e)
    }
  }
}

// ============================================================================
// Service Worker (Push Notification) API
// ============================================================================

module Sw = {
  type registration = {
    state: option<string>,
    key: option<string>,
    userId: string,
    endpoint: string,
    sendReadMessage: bool,
  }

  /// Register a push notification endpoint with the Misskey instance.
  let register = async (
    client: t,
    ~endpoint: string,
    ~auth: string,
    ~publickey: string,
    ~sendReadMessage: bool=false,
    (),
  ): result<registration, string> => {
    let params = Dict.make()
    params->Dict.set("endpoint", endpoint->JSON.Encode.string)
    params->Dict.set("auth", auth->JSON.Encode.string)
    params->Dict.set("publickey", publickey->JSON.Encode.string)
    params->Dict.set("sendReadMessage", sendReadMessage->JSON.Encode.bool)
    switch await request(client, "sw/register", ~params=params->JSON.Encode.object, ()) {
    | Ok(json) =>
      switch json->JSON.Decode.object {
      | Some(obj) =>
        Ok({
          state: obj->Dict.get("state")->Option.flatMap(JSON.Decode.string),
          key: obj->Dict.get("key")->Option.flatMap(JSON.Decode.string),
          userId: obj->Dict.get("userId")->Option.flatMap(JSON.Decode.string)->Option.getOr(""),
          endpoint: obj->Dict.get("endpoint")->Option.flatMap(JSON.Decode.string)->Option.getOr(""),
          sendReadMessage: obj
          ->Dict.get("sendReadMessage")
          ->Option.flatMap(JSON.Decode.bool)
          ->Option.getOr(false),
        })
      | None => Error("Invalid sw/register response")
      }
    | Error(e) => Error(e)
    }
  }

  /// Unregister a push notification endpoint.
  let unregister = async (client: t, ~endpoint: string): result<unit, string> => {
    let params = Dict.make()
    params->Dict.set("endpoint", endpoint->JSON.Encode.string)
    switch await request(client, "sw/unregister", ~params=params->JSON.Encode.object, ()) {
    | Ok(_) => Ok()
    | Error(e) => Error(e)
    }
  }
}

// ============================================================================
// Webhooks API
// ============================================================================

module Webhooks = {
  type webhook = {
    id: string,
    name: string,
    url: string,
    active: bool,
  }

  /// Create a webhook on the Misskey instance.
  let create = async (
    client: t,
    ~name: string,
    ~url: string,
    ~secret: string,
    ~on: array<string>,
    (),
  ): result<webhook, string> => {
    let params = Dict.make()
    params->Dict.set("name", name->JSON.Encode.string)
    params->Dict.set("url", url->JSON.Encode.string)
    params->Dict.set("secret", secret->JSON.Encode.string)
    params->Dict.set("on", on->Array.map(JSON.Encode.string)->JSON.Encode.array)
    switch await request(client, "i/webhooks/create", ~params=params->JSON.Encode.object, ()) {
    | Ok(json) =>
      switch json->JSON.Decode.object {
      | Some(obj) =>
        let id = obj->Dict.get("id")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
        let name = obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
        let url = obj->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
        let active = obj->Dict.get("active")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
        Ok({id, name, url, active})
      | None => Error("Invalid webhook response")
      }
    | Error(e) => Error(e)
    }
  }

  /// Delete a webhook by ID.
  let delete = async (client: t, ~webhookId: string): result<unit, string> => {
    let params = Dict.make()
    params->Dict.set("webhookId", webhookId->JSON.Encode.string)
    switch await request(client, "i/webhooks/delete", ~params=params->JSON.Encode.object, ()) {
    | Ok(_) => Ok()
    | Error(e) => Error(e)
    }
  }

  /// List webhooks for the current user.
  let list = async (client: t): result<array<webhook>, string> => {
    switch await request(client, "i/webhooks/list", ()) {
    | Ok(json) =>
      switch json->JSON.Decode.array {
      | Some(arr) =>
        Ok(arr->Array.filterMap(item => {
          switch item->JSON.Decode.object {
          | Some(obj) =>
            let id = obj->Dict.get("id")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
            let name = obj->Dict.get("name")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
            let url = obj->Dict.get("url")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
            let active = obj->Dict.get("active")->Option.flatMap(JSON.Decode.bool)->Option.getOr(false)
            Some({id, name, url, active})
          | None => None
          }
        }))
      | None => Ok([])
      }
    | Error(e) => Error(e)
    }
  }
}

let isAPIError = (error: JSON.t): option<apiError> => {
  switch error->JSON.Decode.object {
  | Some(obj) =>
    switch (
      obj->Dict.get("code")->Option.flatMap(JSON.Decode.string),
      obj->Dict.get("message")->Option.flatMap(JSON.Decode.string),
      obj->Dict.get("id")->Option.flatMap(JSON.Decode.string),
    ) {
    | (Some(code), Some(message), Some(id)) => Some({code, message, id})
    | _ => None
    }
  | None => None
  }
}

// ============================================================================
// Drive API
// ============================================================================
// NOTE: All HTTP calls in this module (and throughout Misskey.res) should use
// `Ofetch.ofetch` rather than raw `fetch`.  ofetch handles JSON parsing,
// non-2xx error throwing, and runtime FormData detection automatically, which
// avoids the pitfall of calling `response.json()` on non-standard objects.

module Drive = {
  type uploadProgress = {
    loaded: float,
    total: float,
  }

  let parseResponse = (responseText: string): result<string, string> => {
    switch responseText->JSON.parseOrThrow {
    | exception _ => Error("Drive upload: invalid JSON response")
    | json =>
      switch json->JSON.Decode.object->Option.flatMap(obj => obj->Dict.get("id")) {
      | Some(idJson) =>
        switch idJson->JSON.Decode.string {
        | Some(id) => Ok(id)
        | None => Error("Drive upload: id is not a string")
        }
      | None =>
        let errObj =
          json
          ->JSON.Decode.object
          ->Option.flatMap(obj => obj->Dict.get("error"))
          ->Option.flatMap(JSON.Decode.object)
        let errDetail = errObj->Option.flatMap(obj => obj->Dict.get("message"))->Option.flatMap(JSON.Decode.string)
        let statusCode = errObj->Option.flatMap(obj => obj->Dict.get("code"))->Option.flatMap(JSON.Decode.string)
        let msg = switch (statusCode, errDetail) {
        | (Some(code), Some(detail)) => code ++ ": " ++ detail
        | (None, Some(detail)) => detail
        | (Some(code), None) => "Upload error: " ++ code
        | (None, None) => "Unknown upload error"
        }
        Error(msg)
      }
    }
  }

  /// Upload a File object to the Misskey drive.
  /// Returns the drive file ID on success.
  /// Optionally accepts ~onProgress for tracking upload progress.
  let upload = (
    client: t,
    ~file: {..},
    ~sensitive: bool=false,
    ~onProgress: option<uploadProgress => unit>=?,
    (),
  ): promise<result<string, string>> => {
    let fd: {..} = %raw(`new FormData()`)
    ignore(fd["append"]("file", file))
    client.token->Option.forEach(tok => ignore(fd["append"]("i", tok)))
    if sensitive { ignore(fd["append"]("isSensitive", "true")) }

    let endpoint = client.origin ++ "/api/drive/files/create"

    Promise.make((resolve, _reject) => {
      let xhr: {..} = %raw(`new XMLHttpRequest()`)
      ignore(xhr["open"]("POST", endpoint))

      onProgress->Option.forEach(callback => {
        xhr["upload"]["onprogress"] = (e: {..}) => {
          callback({loaded: e["loaded"], total: e["total"]})
        }
      })

      xhr["onload"] = () => {
        let status: int = xhr["status"]
        if status >= 200 && status < 300 {
          resolve(parseResponse(xhr["responseText"]))
        } else {
          resolve(Error("Drive upload failed with status " ++ Int.toString(status)))
        }
      }

      xhr["onerror"] = () => {
        resolve(Error("Drive upload: network error"))
      }

      ignore(xhr["send"](fd))
    })
  }
}

let default = connect
