// MisskeyWebSocket.res - Browser WebSocket API bindings for ReScript

// WebSocket ready state constants
module ReadyState = {
  type t = int
  
  @val @scope("WebSocket") external connecting: t = "CONNECTING"  // 0
  @val @scope("WebSocket") external open_: t = "OPEN"             // 1
  @val @scope("WebSocket") external closing: t = "CLOSING"        // 2
  @val @scope("WebSocket") external closed: t = "CLOSED"          // 3
}

// Binary type for WebSocket
type binaryType = [#blob | #arraybuffer]

// WebSocket class binding
type t

// Constructor
@new external make: string => t = "WebSocket"
@new external makeWithProtocol: (string, string) => t = "WebSocket"
@new external makeWithProtocols: (string, array<string>) => t = "WebSocket"

// Properties
@get external url: t => string = "url"
@get external readyState: t => ReadyState.t = "readyState"
@get external bufferedAmount: t => int = "bufferedAmount"
@get external protocol: t => string = "protocol"
@get external extensions: t => string = "extensions"

@get external binaryType: t => string = "binaryType"
@set external setBinaryType: (t, string) => unit = "binaryType"

// Methods
@send external close: t => unit = "close"
@send external closeWithCode: (t, int) => unit = "close"
@send external closeWithCodeAndReason: (t, int, string) => unit = "close"

@send external send: (t, string) => unit = "send"

// Event types
module Event = {
  type t
  @get external type_: t => string = "type"
}

module MessageEvent = {
  type t
  @get external data: t => string = "data"
  @get external origin: t => string = "origin"
}

module CloseEvent = {
  type t
  @get external code: t => int = "code"
  @get external reason: t => string = "reason"
  @get external wasClean: t => bool = "wasClean"
}

module ErrorEvent = {
  type t
  @get external message: t => string = "message"
}

// Event listeners
@send external addEventListener: (t, @as("open") _, Event.t => unit) => unit = "addEventListener"
@send external addMessageListener: (t, @as("message") _, MessageEvent.t => unit) => unit = "addEventListener"
@send external addCloseListener: (t, @as("close") _, CloseEvent.t => unit) => unit = "addEventListener"
@send external addErrorListener: (t, @as("error") _, ErrorEvent.t => unit) => unit = "addEventListener"

@send external removeEventListener: (t, @as("open") _, Event.t => unit) => unit = "removeEventListener"
@send external removeMessageListener: (t, @as("message") _, MessageEvent.t => unit) => unit = "removeEventListener"
@send external removeCloseListener: (t, @as("close") _, CloseEvent.t => unit) => unit = "removeEventListener"
@send external removeErrorListener: (t, @as("error") _, ErrorEvent.t => unit) => unit = "removeEventListener"

// Helper functions for ready state checking
let isConnecting = (ws: t): bool => readyState(ws) == ReadyState.connecting
let isOpen = (ws: t): bool => readyState(ws) == ReadyState.open_
let isClosing = (ws: t): bool => readyState(ws) == ReadyState.closing
let isClosed = (ws: t): bool => readyState(ws) == ReadyState.closed
