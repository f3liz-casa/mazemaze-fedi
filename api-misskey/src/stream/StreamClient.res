// StreamClient.res - Native ReScript WebSocket streaming client
// Pure ReScript implementation replacing misskey-js Stream class

module WS = MisskeyWebSocket
module Protocol = StreamProtocol
module Connection = StreamConnection

// Shared connection pool for channels without params
type pool = {
  channel: string,
  id: string,
  mutable users: int,
  mutable disposeTimerId: option<timeoutId>,
  mutable isConnected: bool,
  onConnect: string => unit,
  onDisconnect: string => unit,
  onStreamDisconnected: unit => unit,
}

type t = {
  ws: WS.t,
  origin: string,
  credential: option<string>,
  mutable state: Protocol.streamState,
  sharedConnectionPools: Dict.t<pool>,
  sharedConnections: Dict.t<Connection.t>,
  nonSharedConnections: Dict.t<Connection.t>,
  mutable idCounter: int,
  broadcastHandlers: Dict.t<JSON.t => unit>,
  mutable onConnectedCallback: option<unit => unit>,
  mutable onDisconnectedCallback: option<unit => unit>,
  mutable pendingMessages: array<string>,
}

// Generate unique ID for connections
let genId = (stream: t): string => {
  stream.idCounter = stream.idCounter + 1
  stream.idCounter->Int.toString
}

// Create a new stream client
let make = (~origin: string, ~credential: option<string>=?, ()): t => {
  let url = Protocol.buildStreamingUrl(~origin, ~token=credential)
  let ws = WS.make(url)
  
  let stream = {
    ws,
    origin,
    credential,
    state: #initializing,
    sharedConnectionPools: Dict.make(),
    sharedConnections: Dict.make(),
    nonSharedConnections: Dict.make(),
    idCounter: 0,
    broadcastHandlers: Dict.make(),
    onConnectedCallback: None,
    onDisconnectedCallback: None,
    pendingMessages: [],
  }
  
  // Set up WebSocket event handlers
  ws->WS.addEventListener((_event) => {
    let isReconnect = stream.state == #reconnecting
    stream.state = #connected
    
    // Flush any pending messages
    let pending = stream.pendingMessages
    stream.pendingMessages = []
    pending->Array.forEach(msg => stream.ws->WS.send(msg))
    
    // Call user callback
    switch stream.onConnectedCallback {
    | Some(cb) => cb()
    | None => ()
    }
    
    // Reconnect all pools and non-shared connections
    if isReconnect {
      stream.sharedConnectionPools
        ->Dict.valuesToArray
        ->Array.forEach(pool => {
          if pool.users > 0 {
            pool.onConnect(pool.id)
          }
        })
      
      stream.nonSharedConnections
        ->Dict.valuesToArray
        ->Array.forEach(conn => {
          let msg = Protocol.Connect({
            channel: conn.channel,
            id: conn.id,
            params: conn.params,
          })
          ws->WS.send(Protocol.serializeOutgoing(msg))
        })
    }
  })
  
  ws->WS.addCloseListener((_event) => {
    if stream.state == #connected {
      stream.state = #reconnecting
      
      // Call user callback
      switch stream.onDisconnectedCallback {
      | Some(cb) => cb()
      | None => ()
      }
      
      // Mark all pools as disconnected
      stream.sharedConnectionPools
        ->Dict.valuesToArray
        ->Array.forEach(pool => {
          pool.isConnected = false
        })
    }
  })
  
  ws->WS.addMessageListener((event) => {
    let data = WS.MessageEvent.data(event)
    
    switch Protocol.parseIncoming(data) {
      | Some(Protocol.ChannelEvent({id, type_, body})) => {
        // Try to find in shared connections first
        let connections = stream.sharedConnections
          ->Dict.valuesToArray
          ->Array.filter(conn => Connection.getId(conn) == id)
        
        // If not found, check non-shared connections
        let connections = if Array.length(connections) == 0 {
          switch stream.nonSharedConnections->Dict.get(id) {
          | Some(conn) => [conn]
          | None => []
          }
        } else {
          connections
        }
        
        // Emit event to all matching connections
        connections->Array.forEach(conn => {
          Connection.emit(conn, type_, body)
        })
      }
    | Some(Protocol.BroadcastEvent({type_, body})) => {
        // Handle broadcast events
        switch stream.broadcastHandlers->Dict.get(type_) {
        | Some(handler) => handler(body)
        | None => ()
        }
      }
    | None => ()
    }
  })
  
  stream
}

// Send a message (queues if WebSocket not yet open)
let send = (stream: t, msg: Protocol.outgoingMessage): unit => {
  let serialized = Protocol.serializeOutgoing(msg)
  if WS.isOpen(stream.ws) && Array.length(stream.pendingMessages) == 0 {
    stream.ws->WS.send(serialized)
  } else {
    // Queue for when connection opens or if there are already pending messages
    stream.pendingMessages = stream.pendingMessages->Array.concat([serialized])
  }
}

// Ping the server
let ping = (stream: t): unit => {
  send(stream, Protocol.Ping)
}

// Send heartbeat
let heartbeat = (stream: t): unit => {
  send(stream, Protocol.Heartbeat)
}

// Close the stream
let close = (stream: t): unit => {
  stream.ws->WS.close
}

// Event callbacks
let onConnected = (stream: t, callback: unit => unit): unit => {
  stream.onConnectedCallback = Some(callback)
}

let onDisconnected = (stream: t, callback: unit => unit): unit => {
  stream.onDisconnectedCallback = Some(callback)
}

// Add broadcast event handler
let on = (stream: t, event: string, handler: JSON.t => unit): unit => {
  stream.broadcastHandlers->Dict.set(event, handler)
}

// Create or get shared connection pool
let getOrCreatePool = (stream: t, channel: string): pool => {
  switch stream.sharedConnectionPools->Dict.get(channel) {
  | Some(pool) => pool
  | None => {
      let id = genId(stream)
      
      let rec pool = {
        channel,
        id,
        users: 0,
        disposeTimerId: None,
        isConnected: false,
        onConnect: (poolId) => {
          if !pool.isConnected {
            pool.isConnected = true
            let msg = Protocol.Connect({
              channel: pool.channel,
              id: poolId,
              params: None,
            })
            send(stream, msg)
          }
        },
        onDisconnect: (poolId) => {
          pool.isConnected = false
          let msg = Protocol.Disconnect({id: poolId})
          send(stream, msg)
          stream.sharedConnectionPools->Dict.delete(channel)
        },
        onStreamDisconnected: () => {
          pool.isConnected = false
        },
      }
      
      stream.sharedConnectionPools->Dict.set(channel, pool)
      pool
    }
  }
}

// Use a channel with params (non-shared connection)
let useChannel = (
  stream: t,
  ~channel: string,
  ~params: option<JSON.t>=?,
  ~name: option<string>=?,
  (),
): Connection.t => {
  let id = genId(stream)
  
  let conn = Connection.make(
    ~id,
    ~channel,
    ~params?,
    ~name?,
    ~onDispose=conn => {
      stream.nonSharedConnections->Dict.delete(Connection.getId(conn))
      let msg = Protocol.Disconnect({id: Connection.getId(conn)})
      send(stream, msg)
    },
  )
  
  stream.nonSharedConnections->Dict.set(id, conn)
  
  // Send connect message
  let msg = Protocol.Connect({channel, id, params})
  send(stream, msg)
  
  conn
}

// Use a shared channel (no params)
let useSharedChannel = (
  stream: t,
  ~channel: string,
  ~name: option<string>=?,
  (),
): Connection.t => {
  let pool = getOrCreatePool(stream, channel)
  
  let conn = Connection.make(
    ~id=pool.id,
    ~channel,
    ~name?,
    ~onDispose=conn => {
      let connId = Connection.getId(conn) ++ Connection.getChannel(conn)
      stream.sharedConnections->Dict.delete(connId)
      
      // Decrement pool users
      pool.users = pool.users - 1
      
      // Schedule pool disposal if no users
      if pool.users == 0 {
        let timerId = setTimeout(() => {
          if pool.users == 0 {
            pool.onDisconnect(pool.id)
          }
        }, 3000)
        pool.disposeTimerId = Some(timerId)
      }
    },
  )
  
  let connId = pool.id ++ channel
  stream.sharedConnections->Dict.set(connId, conn)
  
  // Increment pool users
  pool.users = pool.users + 1
  
  // Cancel disposal timer if exists
  switch pool.disposeTimerId {
  | Some(timerId) => {
      clearTimeout(timerId)
      pool.disposeTimerId = None
    }
  | None => ()
  }
  
  // Connect pool if not connected
  if pool.users == 1 && !pool.isConnected {
    pool.onConnect(pool.id)
  }
  
  conn
}

// Send a channel message
let sendChannelMessage = (stream: t, conn: Connection.t, type_: string, body: JSON.t): unit => {
  let msg = Protocol.ChannelMessage({
    id: Connection.getId(conn),
    type_,
    body,
  })
  send(stream, msg)
  Connection.incrementOutCount(conn)
}

// Get stream state
let getState = (stream: t): Protocol.streamState => stream.state
