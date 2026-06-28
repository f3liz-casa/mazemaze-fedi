// StreamProtocol.res - Misskey WebSocket streaming protocol types and message handling
// Based on misskey-js streaming implementation

// Stream state
type streamState = [#initializing | #reconnecting | #connected]

// Outgoing message types (Client -> Server)
type outgoingMessage = 
  | Connect({channel: string, id: string, params: option<JSON.t>})
  | Disconnect({id: string})
  | ChannelMessage({id: string, type_: string, body: JSON.t})
  | Ping
  | Heartbeat

// Incoming message types (Server -> Client)
type incomingMessage = 
  | ChannelEvent({id: string, type_: string, body: JSON.t})
  | BroadcastEvent({type_: string, body: JSON.t})

// Serialize outgoing message to JSON string
let serializeOutgoing = (msg: outgoingMessage): string => {
  switch msg {
  | Connect({channel, id, params}) => {
      let obj = Dict.make()
      obj->Dict.set("type", "connect"->JSON.Encode.string)
      
      let bodyObj = Dict.make()
      bodyObj->Dict.set("channel", channel->JSON.Encode.string)
      bodyObj->Dict.set("id", id->JSON.Encode.string)
      
      switch params {
      | Some(p) => bodyObj->Dict.set("params", p)
      | None => ()
      }
      
      obj->Dict.set("body", bodyObj->JSON.Encode.object)
      obj->JSON.Encode.object->JSON.stringify
    }
  | Disconnect({id}) => {
      let obj = Dict.make()
      obj->Dict.set("type", "disconnect"->JSON.Encode.string)
      
      let bodyObj = Dict.make()
      bodyObj->Dict.set("id", id->JSON.Encode.string)
      
      obj->Dict.set("body", bodyObj->JSON.Encode.object)
      obj->JSON.Encode.object->JSON.stringify
    }
  | ChannelMessage({id, type_, body}) => {
      let obj = Dict.make()
      obj->Dict.set("type", "ch"->JSON.Encode.string)
      
      let bodyObj = Dict.make()
      bodyObj->Dict.set("id", id->JSON.Encode.string)
      bodyObj->Dict.set("type", type_->JSON.Encode.string)
      bodyObj->Dict.set("body", body)
      
      obj->Dict.set("body", bodyObj->JSON.Encode.object)
      obj->JSON.Encode.object->JSON.stringify
    }
  | Ping => "ping"
  | Heartbeat => "h"
  }
}

// Parse incoming message from JSON string
let parseIncoming = (data: string): option<incomingMessage> => {
  try {
    let json = JSON.parseOrThrow(data)
    
    switch json->JSON.Decode.object {
    | Some(obj) => {
        let type_ = obj->Dict.get("type")->Option.flatMap(JSON.Decode.string)
        let body = obj->Dict.get("body")
        
        switch (type_, body) {
        | (Some("channel"), Some(bodyJson)) => {
            switch bodyJson->JSON.Decode.object {
            | Some(bodyObj) => {
                let id = bodyObj->Dict.get("id")->Option.flatMap(JSON.Decode.string)
                let type_ = bodyObj->Dict.get("type")->Option.flatMap(JSON.Decode.string)
                let body = bodyObj->Dict.get("body")
                
                switch (id, type_, body) {
                | (Some(id), Some(type_), Some(body)) => 
                    Some(ChannelEvent({id, type_, body}))
                | _ => None
                }
              }
            | None => None
            }
          }
        | (Some(eventType), Some(eventBody)) => {
            Some(BroadcastEvent({type_: eventType, body: eventBody}))
          }
        | _ => None
        }
      }
    | None => None
    }
  } catch {
  | _ => None
  }
}

// Build WebSocket URL with query parameters
let buildStreamingUrl = (~origin: string, ~token: option<string>): string => {
  let wsOrigin = origin
    ->String.replace("http://", "ws://")
    ->String.replace("https://", "wss://")
  
  // Add query parameters
  let query = switch token {
  | Some(t) => `i=${t}&_t=${Date.now()->Float.toString}`
  | None => `_t=${Date.now()->Float.toString}`
  }
  
  `${wsOrigin}/streaming?${query}`
}
