(* Driver — wires the pieces. With a spec path it lowers the real OpenAPI doc
   (Openapi.lower); without one it falls back to a small hand-built sample so
   the pipeline is runnable offline. Emitters are uniform and just folded over.

   usage: driver <outdir> [spec.json] *)

open Ir

let sample : t =
  {
    schemas =
      [
        { name = "userLite"; doc = None;
          schema = Record [
            { name = "id";       ty = Prim String; optional = false; nullable = false; enum_values = None; doc = None; format = None };
            { name = "username"; ty = Prim String; optional = false; nullable = false; enum_values = None; doc = None; format = None };
            { name = "name";     ty = Prim String; optional = true;  nullable = false; enum_values = None; doc = None; format = None };
          ] };
        { name = "visibility"; doc = None;
          schema = Enum [ "public"; "home"; "followers"; "specified" ] };
        { name = "note"; doc = None;
          schema = Record [
            { name = "id";         ty = Prim String;         optional = false; nullable = false; enum_values = None; doc = None; format = None };
            { name = "text";       ty = Prim String;         optional = true;  nullable = false; enum_values = None; doc = None; format = None };
            { name = "visibility"; ty = Ref "visibility";    optional = false; nullable = false; enum_values = None; doc = None; format = None };
            { name = "mentions";   ty = Array (Prim String); optional = false; nullable = false; enum_values = None; doc = None; format = None };
            { name = "user";       ty = Ref "userLite";      optional = false; nullable = false; enum_values = None; doc = None; format = None };
          ] };
      ];
    ops = [];
  }

let emitters : (t -> (string * string) list) list =
  [ Emit_melange.emit; Emit_jsdoc.emit; Emit_rescript.emit; Emit_sugar.emit ]

let write_file dir (name, contents) =
  let path = Filename.concat dir name in
  let oc = open_out path in
  output_string oc contents;
  close_out oc;
  print_endline ("wrote " ^ path)

(* honesty: report how each schema was modelled, especially the fallbacks *)
let tally (ir : t) =
  let r = ref 0 and e = ref 0 and o = ref 0 and u = ref 0 and a = ref 0 in
  List.iter
    (fun n -> match n.schema with
       | Record _ -> incr r
       | Enum _ -> incr e
       | Union (_ :: _) -> incr u          (* typed JSDoc union (opaque at runtime) *)
       | Alias Json | Union [] -> incr o   (* truly opaque unknown *)
       | Alias _ -> incr a)                 (* typed alias (string / T[] / Ref) *)
    ir.schemas;
  Printf.printf
    "lowered %d schemas: %d records, %d enums, %d unions, %d aliases, %d opaque-fallbacks; %d endpoints\n"
    (List.length ir.schemas) !r !e !u !a !o (List.length ir.ops)

let () =
  let outdir = if Array.length Sys.argv > 1 then Sys.argv.(1) else "." in
  (* spike: `driver <outdir> --graphql <ops.json>` runs the GraphQL front-end.
     The union/interface handling rides the existing emitters unchanged, so we
     run all three real surfaces (Melange runtime, JSDoc metadata, ReScript) —
     Emit_sugar is the Misskey-branded convenience layer, left out here. *)
  if Array.length Sys.argv > 3 && Sys.argv.(2) = "--graphql" then begin
    let raw = Graphql.lower (Yojson.Safe.from_file Sys.argv.(3)) in
    let ir, degraded = Resolve.run raw in
    tally ir;
    if degraded > 0 then
      Printf.printf "broke %d cyclic/self/unknown ref(s) down to opaque Json\n" degraded;
    [ Emit_melange.emit; Emit_jsdoc.emit; Emit_rescript.emit ]
    |> List.concat_map (fun e -> e ir) |> List.iter (write_file outdir)
  end else begin
    let raw =
      if Array.length Sys.argv > 2 then Openapi.lower (Yojson.Safe.from_file Sys.argv.(2))
      else sample
    in
    let ir, degraded = Resolve.run raw in
    tally ir;
    if degraded > 0 then
      Printf.printf "broke %d cyclic/self/unknown ref(s) down to opaque Json\n" degraded;
    emitters |> List.concat_map (fun e -> e ir) |> List.iter (write_file outdir)
  end
