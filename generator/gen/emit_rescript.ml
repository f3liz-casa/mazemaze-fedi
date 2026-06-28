(* Emit_rescript : Ir.t -> the .res ReScript binding layer (the spike's rslayer,
   now generated). The .res files carry ReScript *types* but delegate every
   encode/decode to the flat Melange JS via `@module` externals — one runtime,
   no second codec. ComponentSchemas mirrors the schema modules; Endpoints nests
   the flat sends back under their OpenAPI tag (Notes.PostNotesTimeline.send),
   which is the API shape production/kaguya consume. *)

open Ir

let buf_add = Buffer.add_string

let schemas_js = "./melange-dist/ComponentSchemas.js"
let endpoints_js = "./melange-dist/Endpoints.js"

(* one ReScript record field. An optional field uses a ReScript OPTIONAL RECORD
   FIELD (`text?: string`) rather than `text: option<string>`: the consumer omits
   it on write and reads it back as `option`, and the compiled JS is identical (an
   absent key the melange codec reads as None) — so `{text: "hi"}` just works. *)
let field_res ~qualify ~self (f : field) =
  let label, wire = Repr.rescript_label f.name in
  let base = Repr.rescript_type_self ~qualify self f.ty in
  let opt = if Repr.field_optional f then "?" else "" in
  let at = match wire with Some w -> Printf.sprintf "@as(\"%s\") " w | None -> "" in
  Printf.sprintf "    %s%s%s: %s," at label opt base

(* ReScript needs `type rec t` for a self-referential record (no implicit rec) *)
let rec ty_mentions self = function
  | Ref n -> n = self
  | Array t -> ty_mentions self t
  | _ -> false

let record_res b ?(qualify = "") ~self fields =
  let self_rec = List.exists (fun (f : field) -> ty_mentions self f.ty) fields in
  buf_add b (if self_rec then "  type rec t = {\n" else "  type t = {\n");
  List.iter (fun f -> buf_add b (field_res ~qualify ~self f); buf_add b "\n") fields;
  buf_add b "  }\n"

(* of_json/to_json externals binding to the flat Melange accessor names *)
let codec_externals b js name =
  buf_add b (Printf.sprintf
    "  @module(\"%s\") external of_json: JSON.t => t = \"%s\"\n" js (Repr.accessor name `Of_json));
  buf_add b (Printf.sprintf
    "  @module(\"%s\") external to_json: t => JSON.t = \"%s\"\n" js (Repr.accessor name `To_json))

(* a ReScript variant constructor name from a discriminator value (capitalised,
   alnum) — "note" -> Note, "pollEnded" -> PollEnded *)
let ctor_of value =
  let b = Buffer.create (String.length value) in
  String.iter (fun c -> if Repr.is_ident_char c && c <> '_' then Buffer.add_char b c) value;
  let s = Buffer.contents b in
  if s = "" then "V" else Repr.module_name s

(* A union whose members are all $refs to records that share a single-value-enum
   field (distinct per member) is a $type/type-discriminated union. ReScript models
   it as a @tag variant whose runtime IS the raw object, so the identity melange
   codec round-trips it and consumers can pattern-match. Returns the discriminator
   field name + (value, payload-fields-minus-discriminator) per member. *)
let detect_disc_union (lookup : string -> field list option) members =
  let single_enum fs name =
    match List.find_opt (fun (f : field) -> f.name = name) fs with
    | Some { enum_values = Some [ v ]; _ } -> Some v
    | _ -> None
  in
  let recs = List.map (function Ref n -> lookup n | _ -> None) members in
  if recs = [] || List.exists (( = ) None) recs then None
  else
    let recs = List.map (function Some fs -> fs | None -> []) recs in
    let first = List.hd recs in
    let candidates = List.filter_map (fun (f : field) ->
      if single_enum first f.name <> None then Some f.name else None) first in
    let works d =
      let vals = List.map (fun fs -> single_enum fs d) recs in
      List.for_all (( <> ) None) vals
      && (let vs = List.map (function Some v -> v | None -> "") vals in
          List.length (List.sort_uniq compare vs) = List.length vs)
    in
    match List.find_opt works candidates with
    | None -> None
    | Some d ->
      Some (d, List.map (fun fs ->
        let v = match single_enum fs d with Some v -> v | None -> "" in
        (v, List.filter (fun (f : field) -> f.name <> d) fs)) recs)

let schema_module b lookup (n : named) =
  let m = Repr.module_name n.name in
  buf_add b (Printf.sprintf "module %s = {\n" m);
  (match n.schema with
   | Record fields ->
     record_res b ~self:n.name fields;
     codec_externals b schemas_js n.name
   | Alias ((Prim _ | Array _ | Ref _) as ty) ->
     (* a type alias — string / T[] / a Ref to another schema *)
     buf_add b (Printf.sprintf "  type t = %s\n" (Repr.rescript_type_self ~qualify:"" n.name ty));
     codec_externals b schemas_js n.name
   | Union (_ :: _ as members) when detect_disc_union lookup members <> None ->
     (* @tag discriminated union: the tag field selects the variant; each payload
        is the member record's other fields (runtime = the raw object). *)
     let d, variants = match detect_disc_union lookup members with Some x -> x | None -> assert false in
     buf_add b (Printf.sprintf "  @tag(\"%s\")\n  type t =\n" d);
     List.iter (fun (value, payload) ->
       buf_add b (Printf.sprintf "    | @as(\"%s\") %s({\n" value (ctor_of value));
       List.iter (fun f -> buf_add b (field_res ~qualify:"" ~self:n.name f); buf_add b "\n") payload;
       buf_add b "      })\n") variants;
     codec_externals b schemas_js n.name
   | Alias _ | Union _ ->
     (* opaque at runtime (identity codec) — keep it a free-form JSON value *)
     buf_add b "  type t = JSON.t\n";
     codec_externals b schemas_js n.name
   | Enum _ ->
     (* enums encode as bare strings and export no flat accessor (matching the
        Melange layer); just the type. misskey has none today. *)
     buf_add b "  type t = string\n");
  buf_add b "}\n\n"

let emit_component_schemas (ir : t) : string =
  let b = Buffer.create 65536 in
  let records = List.filter_map (fun (n : named) ->
    match n.schema with Record fs -> Some (n.name, fs) | _ -> None) ir.schemas in
  let lookup name = List.assoc_opt name records in
  buf_add b "// Shared component schemas (ReScript type layer).\n";
  buf_add b "// Generated by melange-jsdoc-gen. DO NOT EDIT.\n";
  buf_add b "// Types are plain records; encode/decode delegates to the Melange layer.\n\n";
  List.iter (schema_module b lookup) ir.schemas;
  Buffer.contents b

(* --- endpoints, nested under their tag ------------------------------------ *)

let qualify = "ComponentSchemas."

let op_module b (o : op) =
  let m = Repr.module_name o.name in
  buf_add b (Printf.sprintf "  module %s = {\n" m);
  (match o.request with
   | [] -> buf_add b "    type request = unit\n"
   | fields ->
     buf_add b "    type request = {\n";
     List.iter (fun f -> buf_add b ("  " ^ field_res ~qualify ~self:"" f); buf_add b "\n") fields;
     buf_add b "    }\n");
  buf_add b (Printf.sprintf "    type response = %s\n"
               (Repr.rescript_type_self ~qualify "" o.response));
  buf_add b (Printf.sprintf
    "    @module(\"%s\") external send: (fetchFn, request) => promise<response> = \"%s\"\n"
    endpoints_js (Repr.lower_first o.name ^ "_send"));
  buf_add b "  }\n\n"

let emit_endpoints (ir : t) : string =
  let b = Buffer.create 262144 in
  buf_add b "// API endpoints (ReScript type layer).\n";
  buf_add b "// Generated by melange-jsdoc-gen. DO NOT EDIT.\n";
  buf_add b "// send delegates encode/decode to the Melange layer; inject fetch for transport.\n\n";
  (* (method, url, body) — the send builds the full URL (path substitution + query
     string) and passes the HTTP method; the melange layer calls fetch positionally. *)
  buf_add b "type fetchFn = (string, string, JSON.t) => promise<JSON.t>\n\n";
  (* group ops by tag; tags alphabetical, op order preserved within a tag *)
  let tags =
    List.fold_left (fun acc o -> if List.mem o.tag acc then acc else o.tag :: acc) [] ir.ops
    |> List.sort_uniq compare
  in
  List.iter
    (fun tag ->
      buf_add b (Printf.sprintf "module %s = {\n" tag);
      List.iter (fun o -> if o.tag = tag then op_module b o) ir.ops;
      buf_add b "}\n\n")
    tags;
  Buffer.contents b

let emit (ir : t) : (string * string) list =
  [ ("ComponentSchemas.res", emit_component_schemas ir);
    ("Endpoints.res", emit_endpoints ir) ]
