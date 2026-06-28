// ReScript consumer of the generated layer.
//
// ReScript imports the NESTED binding layer (Endpoints.res / ComponentSchemas.res):
// `Notes.PostNotesTimeline.send(fetch, req)`. Types flow natively (it's ReScript).

open Endpoints // brings the per-tag modules (Notes, Users, …) into scope

// ── The one piece of boilerplate every consumer needs: a client holding the
//    transport `(method, url, body) => promise<json>`. Wiring origin/token/HTTP into
//    that fetchFn is the consumer's concern; here we just take it. ──
type client = {transport: Endpoints.fetchFn}
let make = (transport): client => {transport: transport}

let demo = async (client: client) => {
  // timeline → typed array<Note.t>. Nested UserLite + nullable text flow.
  // The request type now uses OPTIONAL RECORD FIELDS, so you write only what you set.
  let notes = await Notes.PostNotesTimeline.send(client.transport, {limit: 20})
  let first = notes->Array.getUnsafe(0)
  Console.log2(first.user.username, first.text)

  // create → just the field you want. No `Some`, no 18 `None`s.
  let _ = await Notes.PostNotesCreate.send(client.transport, {text: "hello from ReScript"})
  ()
}
