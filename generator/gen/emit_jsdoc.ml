(* Emit_jsdoc : Ir.t -> the metadata JSON (the contract the node/acorn step
   consumes). We deliberately stop at metadata and let node turn it into JSDoc
   text + splice it: OCaml owns *types*, node owns *JS text*.

   Records and opaque fallbacks both get a typedef + accessors. Named enums get
   a union typedef but no accessor (strings pass through unconverted). *)

open Ir

(* JSON string literal. Must escape quotes (enum-union types embed them, e.g.
   ("unknown"|"online")) AND control characters: operation descriptions carry
   real newlines (every misskey op's prose does), and a raw newline inside a
   JSON string is invalid — the node side would fail to parse the metadata. *)
let q s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | '\b' -> Buffer.add_string b "\\b"
      | '\012' -> Buffer.add_string b "\\f"
      | c when Char.code c < 0x20 -> Buffer.add_string b (Printf.sprintf "\\u%04x" (Char.code c))
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"';
  Buffer.contents b

(* a `"doc": <string>|null` metadata member (leading comma-free; callers join). *)
let doc_member = function Some d -> q d | None -> "null"

(* the JSDoc type for a field: an inline string-literal union when the property
   carried an enum (more precise than the OCaml `string`), else the mapped type. *)
let field_jsdoc_type (f : field) =
  match f.enum_values with
  | Some vs -> "(" ^ String.concat "|" (List.map (fun s -> "\"" ^ s ^ "\"") vs) ^ ")"
  | None -> Repr.jsdoc_type f.ty

let field_json (f : field) =
  Printf.sprintf {|{ "name": %s, "type": %s, "optional": %s, "doc": %s, "format": %s }|}
    (q f.name) (q (field_jsdoc_type f)) (if Repr.field_optional f then "true" else "false")
    (doc_member f.doc) (doc_member f.format)

let type_json (n : named) =
  let name = q (Repr.module_name n.name) in
  match n.schema with
  | Record fields ->
    let fs = List.map field_json fields |> String.concat ",\n        " in
    Printf.sprintf
      {|{ "name": %s, "kind": "record", "doc": %s, "fields": [
        %s
      ] }|}
      name (doc_member n.doc) fs
  | Enum values ->
    let vs = List.map q values |> String.concat ", " in
    Printf.sprintf {|{ "name": %s, "kind": "enum", "values": [ %s ] }|} name vs
  | Union (_ :: _ as members) ->
    (* oneOf/anyOf of named types -> JSDoc `A | B | C` union typedef *)
    let ms = List.map (fun t -> q (Repr.jsdoc_type t)) members |> String.concat ", " in
    Printf.sprintf {|{ "name": %s, "kind": "union", "members": [ %s ] }|} name ms
  | Alias Json | Union [] ->
    Printf.sprintf {|{ "name": %s, "kind": "opaque" }|} name
  | Alias ty ->
    (* type alias -> a JSDoc typedef of the aliased type (string, T[], Ref) *)
    Printf.sprintf {|{ "name": %s, "kind": "alias", "alias": %s }|} name (q (Repr.jsdoc_type ty))

(* accessors for records + opaque fallbacks (enums are plain strings) *)
let accessors_json (n : named) =
  match n.schema with
  | Record _ | Alias _ | Union _ ->
    let m = Repr.module_name n.name in
    [ Printf.sprintf {|{ "name": %s, "type": %s, "dir": "of_json" }|}
        (q (Repr.accessor n.name `Of_json)) (q m);
      Printf.sprintf {|{ "name": %s, "type": %s, "dir": "to_json" }|}
        (q (Repr.accessor n.name `To_json)) (q m) ]
  | Enum _ -> []

(* per-op: a request typedef (named <Module>Req) + a send descriptor *)
let op_request_typedef (o : op) =
  let tn = Repr.module_name o.name ^ "Req" in
  let fs = List.map field_json o.request |> String.concat ",\n        " in
  Printf.sprintf
    {|{ "name": %s, "kind": "record", "fields": [
        %s
      ] }|}
    (q tn) fs

let op_send_json (o : op) =
  Printf.sprintf {|{ "name": %s, "request": %s, "response": %s, "doc": %s }|}
    (q (Repr.lower_first o.name ^ "_send"))
    (q (Repr.module_name o.name ^ "Req"))
    (q (Repr.jsdoc_type o.response))
    (doc_member o.doc)

let fetch_type = "(method: string, url: string, body: unknown) => Promise<unknown>"

(* schema typedef names the endpoints file references (op responses + request
   field types) — the annotate step re-imports each as
   `@typedef {import('./componentSchemas.js').Note} Note` so the Endpoints JSDoc
   can name them bare across the file boundary. *)
let rec refs_of_ty acc = function
  | Ref n -> Repr.module_name n :: acc
  | Array t -> refs_of_ty acc t
  | _ -> acc
let op_imports (o : op) =
  List.fold_left (fun acc (f : field) -> refs_of_ty acc f.ty) (refs_of_ty [] o.response) o.request
let collect_imports ops = List.concat_map op_imports ops |> List.sort_uniq compare

(* B1: schemas and endpoints get their own metadata file, mirroring the split
   .ml / .js. ComponentSchemas owns the schema typedefs + accessors; Endpoints
   owns the request typedefs, send descriptors, the Fetch type, and the list of
   schema typedefs it imports. *)
let emit (ir : t) : (string * string) list =
  let schema_types = List.map type_json ir.schemas |> String.concat ",\n    " in
  let accs = List.concat_map accessors_json ir.schemas |> String.concat ",\n    " in
  let schemas_body =
    Printf.sprintf
      "{\n  \"module\": \"ComponentSchemas\",\n  \"types\": [\n    %s\n  ],\n  \"accessors\": [\n    %s\n  ]\n}\n"
      schema_types accs
  in
  let req_types = List.map op_request_typedef ir.ops |> String.concat ",\n    " in
  let sends = List.map op_send_json ir.ops |> String.concat ",\n    " in
  let imports = collect_imports ir.ops |> List.map q |> String.concat ", " in
  let endpoints_body =
    Printf.sprintf
      "{\n  \"module\": \"Endpoints\",\n  \"fetchType\": %s,\n  \"imports\": [ %s ],\n  \"types\": [\n    %s\n  ],\n  \"sends\": [\n    %s\n  ]\n}\n"
      (q fetch_type) imports req_types sends
  in
  [ ("componentSchemas.jsdoc.json", schemas_body);
    ("endpoints.jsdoc.json", endpoints_body) ]
