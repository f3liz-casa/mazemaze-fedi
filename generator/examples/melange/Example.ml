(* Melange consumer — the base, and the one that reads most naturally.

   The generator emits `misskey.ml`: a `Client` plus per-tag modules of
   labeled-optional wrappers over the flat sends. So a Melange consumer never
   touches the all-`option` request record — it writes idiomatic OCaml:

     Misskey.Notes.create client ~text:"hi" ()
     Misskey.Notes.timeline client ~limit:20 ()

   (`misskey.ml` itself is compile-verified against the generated Endpoints /
   ComponentSchemas in the main build; this file is the consumer's side.) *)

(* the transport seam: your platform's fetch (method, url, json body). The Client
   adds origin + /api + token. *)
let post (_method : string) (_url : string) (body : Js.Json.t) : Js.Json.t Js.Promise.t =
  Js.Promise.resolve body (* sketch — a real one does fetch(url, {method, body}) + .json() *)

let () =
  let client = Misskey.Client.make ~origin:"https://misskey.example" ~token:"TOKEN" ~post () in

  (* timeline → Note.t array; nested UserLite and nullable text flow, typed. *)
  Misskey.Notes.timeline client ~limit:20 ()
  |> Js.Promise.then_ (fun (notes : ComponentSchemas.Note.t array) ->
         let first = notes.(0) in
         Js.log2 first.user.username first.text;
         Js.Promise.resolve ())
  |> ignore;

  (* create → just the fields you want; the rest default to None. *)
  Misskey.Notes.create client ~text:"hello from Melange" () |> ignore
