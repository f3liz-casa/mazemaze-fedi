// StreamConnection.res - Channel connection management
// Manages individual channel connections with event handling

type eventHandler = JSON.t => unit

type rec t = {
  id: string,
  channel: string,
  name: option<string>,
  params: option<JSON.t>,
  eventHandlers: Dict.t<eventHandler>,
  mutable inCount: int,
  mutable outCount: int,
  onDispose: t => unit,
}

// Create a new connection
let make = (
  ~id: string,
  ~channel: string,
  ~params: option<JSON.t>=?,
  ~name: option<string>=?,
  ~onDispose: t => unit,
): t => {
  {
    id,
    channel,
    name,
    params,
    eventHandlers: Dict.make(),
    inCount: 0,
    outCount: 0,
    onDispose,
  }
}

// Add event handler
let on = (conn: t, event: string, handler: eventHandler): unit => {
  conn.eventHandlers->Dict.set(event, handler)
}

// Emit event to handler
let emit = (conn: t, event: string, data: JSON.t): unit => {
  switch conn.eventHandlers->Dict.get(event) {
  | Some(handler) => {
      handler(data)
      conn.inCount = conn.inCount + 1
    }
  | None => ()
  }
}

// Remove all event handlers
let removeAllListeners = (conn: t): unit => {
  conn.eventHandlers->Dict.keysToArray->Array.forEach(key => {
    conn.eventHandlers->Dict.delete(key)
  })
}

// Dispose of this connection
let dispose = (conn: t): unit => {
  removeAllListeners(conn)
  conn.onDispose(conn)
}

// Send a message through this connection
let incrementOutCount = (conn: t): unit => {
  conn.outCount = conn.outCount + 1
}

// Accessors
let getId = (conn: t): string => conn.id
let getChannel = (conn: t): string => conn.channel
let getName = (conn: t): option<string> => conn.name
let getInCount = (conn: t): int => conn.inCount
let getOutCount = (conn: t): int => conn.outCount
