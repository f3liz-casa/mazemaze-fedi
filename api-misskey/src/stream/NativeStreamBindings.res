// Native ReScript Stream Bindings - Replacement for misskey-js Stream
// This provides the same API as the old MisskeyJS_Stream_Bindings but uses our native implementation

module Client = StreamClient
module Connection = StreamConnection
module Protocol = StreamProtocol

// Re-export stream state
type streamState = Protocol.streamState

// Stream user authentication
type streamUser = {token: string}

// Stream type (wraps our StreamClient)
type stream = Client.t

// Create a stream
let make = (~origin: string, ~user: option<streamUser>=?, ()): stream => {
  let credential = user->Option.map(u => u.token)
  Client.make(~origin, ~credential?, ())
}

// Get state
let state = (stream: stream): streamState => {
  Client.getState(stream)
}

// Event listeners
let onConnected = (stream: stream, callback: unit => unit): unit => {
  Client.onConnected(stream, callback)
}

let onDisconnected = (stream: stream, callback: unit => unit): unit => {
  Client.onDisconnected(stream, callback)
}

// Low-level send methods
let sendTyped = (stream: stream, type_: string, payload: JSON.t): unit => {
  // For raw typed messages, we need to serialize manually
  let obj = Dict.make()
  obj->Dict.set("type", type_->JSON.Encode.string)
  obj->Dict.set("body", payload)
  stream.ws->MisskeyWebSocket.send(obj->JSON.Encode.object->JSON.stringify)
}

let sendRaw = (stream: stream, payload: JSON.t): unit => {
  stream.ws->MisskeyWebSocket.send(payload->JSON.stringify)
}

// Connection management
let ping = (stream: stream): unit => {
  Client.ping(stream)
}

let heartbeat = (stream: stream): unit => {
  Client.heartbeat(stream)
}

let close = (stream: stream): unit => {
  Client.close(stream)
}

// Channel connection type
type connection<'events, 'receives> = Connection.t

// Use channel with params
let useChannelWithParams = (
  stream: stream,
  channel: string,
  params: JSON.t,
  ~name: option<string>=?,
  (),
): connection<'events, 'receives> => {
  Client.useChannel(stream, ~channel, ~params=?Some(params), ~name?, ())
}

// Use channel without params (shared connection)
let useChannelWithoutParams = (
  stream: stream,
  channel: string,
  ~name: option<string>=?,
  (),
): connection<'events, 'receives> => {
  Client.useSharedChannel(stream, ~channel, ~name?, ())
}

// Combined useChannel function
let useChannel = (~stream: stream, ~channel: string, ~params: option<JSON.t>=?, ~name: option<string>=?, ()): connection<'events, 'receives> => {
  switch params {
  | Some(p) => useChannelWithParams(stream, channel, p, ~name?, ())
  | None => useChannelWithoutParams(stream, channel, ~name?, ())
  }
}

// Connection methods
let channelId = (conn: connection<'events, 'receives>): string => {
  Connection.getChannel(conn)
}

let connectionId = (conn: connection<'events, 'receives>): string => {
  Connection.getId(conn)
}

let connectionName = (conn: connection<'events, 'receives>): option<string> => {
  Connection.getName(conn)
}

let inCount = (conn: connection<'events, 'receives>): int => {
  Connection.getInCount(conn)
}

let outCount = (conn: connection<'events, 'receives>): int => {
  Connection.getOutCount(conn)
}

let dispose = (conn: connection<'events, 'receives>): unit => {
  Connection.dispose(conn)
}

// Generic event listener
let on = (conn: connection<'events, 'receives>, event: string, handler: JSON.t => unit): unit => {
  Connection.on(conn, event, handler)
}

// Generic send method (not implemented in our current Connection, would need to add)
let send = (_conn: connection<'events, 'receives>, _type: string, _body: JSON.t): unit => {
  // TODO: Implement if needed
  ()
}

// Typed channel modules
module Main = {
  type events
  type receives = unit
  type t = connection<events, receives>

  let onNotification = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "notification", handler)
  }

  let onMention = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "mention", handler)
  }

  let onReply = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "reply", handler)
  }

  let onRenote = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "renote", handler)
  }

  let onFollow = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "follow", handler)
  }

  let onFollowed = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "followed", handler)
  }

  let onUnfollow = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "unfollow", handler)
  }

  let onMeUpdated = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "meUpdated", handler)
  }

  let onReadAllNotifications = (conn: t, handler: unit => unit): unit => {
    Connection.on(conn, "readAllNotifications", _json => handler())
  }
}

module Timeline = {
  type events
  type receives = unit
  type t = connection<events, receives>

  let onNote = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "note", handler)
  }
}

module Drive = {
  type events
  type receives = unit
  type t = connection<events, receives>

  let onFileCreated = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "fileCreated", handler)
  }

  let onFileDeleted = (conn: t, handler: string => unit): unit => {
    Connection.on(conn, "fileDeleted", json => {
      switch json->JSON.Decode.string {
      | Some(id) => handler(id)
      | None => ()
      }
    })
  }

  let onFileUpdated = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "fileUpdated", handler)
  }

  let onFolderCreated = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "folderCreated", handler)
  }

  let onFolderDeleted = (conn: t, handler: string => unit): unit => {
    Connection.on(conn, "folderDeleted", json => {
      switch json->JSON.Decode.string {
      | Some(id) => handler(id)
      | None => ()
      }
    })
  }

  let onFolderUpdated = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "folderUpdated", handler)
  }
}

module ServerStats = {
  type events
  type receives
  type t = connection<events, receives>

  let onStats = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "stats", handler)
  }

  let onStatsLog = (conn: t, handler: JSON.t => unit): unit => {
    Connection.on(conn, "statsLog", handler)
  }

  type requestLogParams = {id: string, length: int}

  let requestLog = (_conn: t, _params: requestLogParams): unit => {
    // TODO: Implement channel send
    ()
  }
}
