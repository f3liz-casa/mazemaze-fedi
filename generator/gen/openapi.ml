(* Openapi.lower : a parsed OpenAPI document (yojson tree) -> Ir.t.
   We navigate the spec tree rather than typing the whole of OpenAPI: the IR is
   the typed target; the spec side stays a tree we read defensively. Anything we
   do not model yet (inline nested objects, oneOf/anyOf/allOf, free-form) falls
   back to the opaque Json case so lowering is total and the output compiles. *)

open Ir

let ( >>= ) = Option.bind

(* --- tiny tree helpers ---------------------------------------------------- *)
let member k = function
  | `Assoc l -> (try Some (List.assoc k l) with Not_found -> None)
  | _ -> None

let to_str = function `String s -> Some s | _ -> None
let strings = function `List l -> List.filter_map to_str l | _ -> []

let cap = String.capitalize_ascii

(* keep alnum; non-alnum chars become word boundaries -> camelCase. Schema names
   (atproto: `app.bsky.actor.defs.nux`), discriminator values (misskey's
   `reaction:grouped`) and property keys carry dots/colons/other punctuation that
   are not legal OCaml/JS identifier chars. *)
let ident_of s =
  let b = Buffer.create (String.length s) in
  let upper = ref false in
  String.iter
    (fun c ->
      let alnum =
        (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
      in
      if alnum then (Buffer.add_char b (if !upper then Char.uppercase_ascii c else c); upper := false)
      else upper := true)
    s;
  let r = Buffer.contents b in
  if r = "" then "x" else r

(* "#/components/schemas/app.bsky.actor.defs" -> "appBskyActorDefs" *)
let ref_name s =
  let base =
    match String.rindex_opt s '/' with
    | Some i -> String.sub s (i + 1) (String.length s - i - 1)
    | None -> s
  in
  Repr.lower_first (ident_of base)

(* openapi 3.1 may write `type: ["string","null"]`; take the first non-null. *)
let type_field node =
  match member "type" node with
  | Some (`String s) -> Some s
  | Some (`List l) -> List.filter_map to_str l |> List.find_opt (fun s -> s <> "null")
  | _ -> None

(* nullable when the 3.1 type list carries "null" (misskey uses this form; the
   3.0 `nullable: true` keyword is absent from this spec but cheap to honour). *)
let nullable_of node =
  (match member "type" node with
   | Some (`List l) -> List.mem "null" (List.filter_map to_str l)
   | _ -> false)
  || (match member "nullable" node with Some (`Bool b) -> b | _ -> false)

let doc_of node = match member "description" node with Some (`String d) -> Some d | _ -> None

(* --- A6 inline-object hoisting -------------------------------------------
   An inline object (`type:object` with `properties`) sitting at a field, an
   array-item or a union-member position has no name to Ref, so it used to
   degrade to Json (unknown). Instead we HOIST it: synthesise a named aux
   schema from a `hint` derived from its position (<Parent><Prop>, or
   <Parent><discriminator> for a union variant) and replace the occurrence with
   a Ref to that name. Accumulated here during lowering; `lower` resets it per
   run and traversal order is deterministic, so the emitted aux order is stable. *)
let hoist_tbl : (string, named) Hashtbl.t = Hashtbl.create 64
let hoist_order : named list ref = ref []
let reset_hoist () = Hashtbl.clear hoist_tbl; hoist_order := []
let add_hoist (n : named) =
  if not (Hashtbl.mem hoist_tbl n.name) then begin
    Hashtbl.add hoist_tbl n.name n;
    hoist_order := n :: !hoist_order
  end


(* combine a parent schema name (already lower_first) and a suffix into a fresh,
   identifier-safe lower_first aux name: userLite + "instance" -> "userLiteInstance",
   notification + "reaction:grouped" -> "notificationReactionGrouped". *)
let hoist_name parent suffix = Repr.lower_first (cap (ident_of parent) ^ cap (ident_of suffix))

(* a field whose value is `anyOf/oneOf: [ {$ref:X}, {type:null} ]` is just a
   nullable reference to X (misskey writes Note.reply, DriveFolder.parent, … this
   way). Recover the single ref; nullability is already read by `nullable_of`
   (the sibling `type:[...,"null"]`). Returns None for multi-ref / complex unions. *)
let single_ref_member node =
  let members =
    match member "anyOf" node, member "oneOf" node with
    | Some (`List m), _ | _, Some (`List m) -> m
    | _ -> []
  in
  let refs =
    List.filter_map (fun m -> match member "$ref" m with Some (`String r) -> Some r | _ -> None) members
  in
  let is_null m = member "type" m = Some (`String "null") in
  let only_refs_or_null = List.for_all (fun m -> member "$ref" m <> None || is_null m) members in
  match refs with [ r ] when only_refs_or_null && members <> [] -> Some r | _ -> None

(* property node -> (ty, enum_values), hoisting any inline object it names.
   `hint` is the aux schema name to give an inline object found at this spot. *)
let rec ty_of_node ~hint node : ty * string list option =
  match member "$ref" node with
  | Some (`String r) -> (Ref (ref_name r), None)
  | _ -> (
    match single_ref_member node with
    | Some r -> (Ref (ref_name r), None)
    | None -> (
    match member "enum" node with
    | Some (`List _ as e) when strings e <> [] -> (Prim String, Some (strings e))
    | _ -> (
      match type_field node with
      | Some "string" -> (Prim String, None)
      | Some "integer" -> (Prim Int, None)
      | Some "number" -> (Prim Float, None)
      | Some "boolean" -> (Prim Bool, None)
      | Some "array" -> (
        match member "items" node with
        | Some items -> let t, _ = ty_of_node ~hint items in (Array t, None)  (* element shares the field's hint *)
        | None -> (Json, None))
      | Some "object" -> (
        match member "properties" node with
        | Some (`Assoc (_ :: _)) ->        (* non-empty: hoist to a named record *)
          add_hoist { name = hint; schema = Record (fields_of_object ~prefix:hint node);
                      doc = doc_of node };
          (Ref hint, None)
        | _ -> (Json, None))               (* empty / no properties -> free-form *)
      | _ -> (Json, None))))               (* untyped -> fallback *)

(* properties+required object -> field list; each inline-object property is
   hoisted under `<prefix><Prop>`. *)
and fields_of_object ~prefix node =
  let required = match member "required" node with Some (`List _ as r) -> strings r | _ -> [] in
  match member "properties" node with
  | Some (`Assoc props) ->
    List.map
      (fun (pname, pnode) ->
        let ty, enum_values = ty_of_node ~hint:(hoist_name prefix pname) pnode in
        let format = match member "format" pnode with Some (`String s) -> Some s | _ -> None in
        { name = pname; ty; optional = not (List.mem pname required);
          nullable = nullable_of pnode; enum_values; doc = doc_of pnode; format })
      props
  | _ -> []

(* raw (un-lowercased) component name of a "#/components/schemas/UserLite" ref,
   for looking the target schema up in the spec tree. *)
let raw_ref_name s =
  match String.rindex_opt s '/' with
  | Some i -> String.sub s (i + 1) (String.length s - i - 1)
  | None -> s

(* allOf is misskey's "inheritance": a list of `$ref`s (+ optional inline props)
   whose objects are conjoined. OCaml records can't extend, so we FLATTEN — pull
   every part's fields into one record. Refs are resolved against the spec tree;
   a ref to another allOf recurses; `visited` guards self/cyclic inheritance.
   Dedup keeps the first occurrence (allOf parts must agree on shared keys). *)
let rec merged_fields root ~prefix visited node : field list =
  match member "allOf" node with
  | Some (`List parts) ->
    let part_fields part =
      match member "$ref" part with
      | Some (`String r) ->
        let raw = raw_ref_name r in
        if List.mem raw visited then []
        else (
          match Some root >>= member "components" >>= member "schemas" >>= member raw with
          (* expand the referenced schema under ITS own name, so an inline object
             it owns hoists to the same aux as when that schema is lowered alone *)
          | Some tnode -> merged_fields root ~prefix:(Repr.lower_first raw) (raw :: visited) tnode
          | None -> [])
      | _ -> fields_of_object ~prefix part
    in
    let seen = Hashtbl.create 64 in
    List.concat_map part_fields parts
    |> List.filter (fun (f : field) ->
        if Hashtbl.mem seen f.name then false
        else (Hashtbl.replace seen f.name (); true))
  | _ -> fields_of_object ~prefix node

(* a union variant's aux name: prefer its discriminator (a single-value `type`
   enum, e.g. Notification's `type:'note'` -> NotificationNote), else by index. *)
let union_member_hint parent i node =
  match member "properties" node >>= member "type" >>= member "enum" with
  | Some (`List (`String v :: _)) -> hoist_name parent v
  | _ -> hoist_name parent ("variant" ^ string_of_int i)

(* --- schemas -------------------------------------------------------------- *)
(* a field list -> a record, or opaque Json when empty (no `{}` type exists) *)
let record_or_opaque = function [] -> Alias Json | fields -> Record fields

(* a oneOf/anyOf member that resolves to a string / const / enum — atproto "token"
   unions (listPurpose = modlist | curatelist | …) are really a known-value string. *)
let member_is_string (root : Yojson.Safe.t) (m : Yojson.Safe.t) =
  let node =
    match member "$ref" m with
    | Some (`String r) ->
      Some root >>= member "components" >>= member "schemas" >>= member (raw_ref_name r)
    | _ -> Some m
  in
  match node with
  | Some n -> type_field n = Some "string" || member "const" n <> None || member "enum" n <> None
  | None -> false

let schema_of root name node : named =
  let lname = Repr.lower_first (ident_of name) in
  let schema =
    match member "enum" node with
    | Some (`List _ as e) when strings e <> [] -> Enum (strings e)
    | _ -> (
      match member "properties" node with
      (* an object with no properties (atproto marker types like `disableRule`)
         is opaque, not an empty record — OCaml/ReScript have no `{}` type *)
      | Some (`Assoc _) -> record_or_opaque (fields_of_object ~prefix:lname node)
      | _ -> (
        match member "allOf" node with
        | Some _ -> record_or_opaque (merged_fields root ~prefix:lname [ name ] node)  (* inheritance -> flat record *)
        | None -> (
          match member "oneOf" node, member "anyOf" node with
          | Some (`List members), _ | _, Some (`List members) ->
            (* oneOf/anyOf -> JSDoc `A | B`. Inline-object members are hoisted
               (A6) to named aux schemas, so unions that used to be opaque
               (Notification's 24 variants, PageBlock's 4) become real unions.
               We still fall fully opaque if any member can't be named (no $ref,
               not an inline object). Runtime decode stays identity — no
               discriminator dispatch yet, per A5's scope. *)
            if members <> [] && List.for_all (member_is_string root) members then
              (* token union (all members string/const) -> a runtime string *)
              Alias (Prim String)
            else
              let tys =
                List.mapi (fun i m -> fst (ty_of_node ~hint:(union_member_hint lname i m) m)) members
              in
              if tys <> [] && List.for_all (fun t -> t <> Json) tys then Union tys
              else Union []
          (* a bare schema (no object/composition): a type ALIAS — string/array/
             $ref (atproto has 76 string aliases like `app.bsky.actor.status.live`).
             ty_of_node lowers it; an object-with-no-properties stays Json/opaque. *)
          | _ -> Alias (fst (ty_of_node ~hint:lname node)))))
  in
  { name = lname; schema; doc = doc_of node }

(* --- operations ----------------------------------------------------------- *)

(* operationId "post___admin___abuse-report-resolver___create" -> camelCase *)
let camel s =
  let b = Buffer.create (String.length s) in
  let started = ref false and new_word = ref false in
  String.iter
    (fun c ->
      let alnum =
        (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
      in
      if alnum then
        if not !started then (Buffer.add_char b (Char.lowercase_ascii c); started := true)
        else if !new_word then (Buffer.add_char b (Char.uppercase_ascii c); new_word := false)
        else Buffer.add_char b c
      else new_word := true)
    s;
  let r = Buffer.contents b in
  if r = "" then "op" else r

let json_schema node =
  Some node >>= member "content" >>= member "application/json" >>= member "schema"

let op_of path meth node : op option =
  let name =
    camel (match member "operationId" node with Some (`String s) -> s | _ -> meth ^ "_" ^ path)
  in
  (* `in:path` params become required request fields, substituted into the
     `{name}` placeholders; `in:query` params become (mostly optional) fields
     appended to the URL as ?k=v by the send. (header params are not modelled.) *)
  let param_field ~required p =
    match member "name" p with
    | Some (`String pn) ->
      let ty = match member "schema" p with Some s -> fst (ty_of_node ~hint:name s) | None -> Prim String in
      let req = match member "required" p with Some (`Bool b) -> b | _ -> required in
      Some { name = pn; ty; optional = not req; nullable = false;
             enum_values = None; doc = doc_of p; format = None }
    | _ -> None
  in
  let params_in loc required =
    match member "parameters" node with
    | Some (`List ps) ->
      List.filter_map (fun p -> if member "in" p = Some (`String loc) then param_field ~required p else None) ps
    | _ -> []
  in
  let path_param_fields = params_in "path" true in
  let query_param_fields = params_in "query" false in
  let body =
    match Some node >>= member "requestBody" >>= json_schema with
    | Some sch -> fields_of_object ~prefix:name sch
    | None -> []
  in
  let req = path_param_fields @ query_param_fields @ body in
  let response =
    match Some node >>= member "responses" >>= member "200" >>= json_schema with
    | Some sch -> fst (ty_of_node ~hint:(hoist_name name "response") sch)
    | None -> Json
  in
  (* the operation `summary` is just the path (= operationId); the real prose
     — most usefully the **Permission**/**Credential** scope — lives in
     `description`. Flow that to the send wrapper's JSDoc. An empty `req` is a
     real endpoint that takes no arguments (misskey has 54: /i, /invite/create,
     …); we keep it (emit sends `{}`) rather than dropping its typed response. *)
  let tag =
    match member "tags" node with
    (* tags carry hyphens/spaces ("non-productive", "reset password"); PascalCase
       to a valid ReScript module name via the same ident sanitizer A6 uses. *)
    | Some (`List (`String t :: _)) -> Repr.module_name (ident_of t)
    | _ -> "Default"   (* the 55 untagged ops group under module Default *)
  in
  let path_params = List.map (fun (f : field) -> f.name) path_param_fields in
  Some { name; http_method = meth; path; request = req; response; doc = doc_of node; tag;
         path_params; query_params = query_param_fields; gql_document = None }

let ops_of root =
  match member "paths" root with
  | Some (`Assoc paths) ->
    List.concat_map
      (fun (path, methods) ->
        match methods with
        | `Assoc ms -> List.filter_map (fun (meth, node) -> op_of path meth node) ms
        | _ -> [])
      paths
  | _ -> []

let lower (root : Yojson.Safe.t) : t =
  reset_hoist ();
  let schemas =
    match Some root >>= member "components" >>= member "schemas" with
    | Some (`Assoc entries) -> List.map (fun (n, node) -> schema_of root n node) entries
    | _ -> []
  in
  let ops = ops_of root in
  (* hoisted aux schemas (A6) are appended after the originals in discovery
     order; Resolve.run toposorts/breaks them like any other schema. We dedup
     the aux first (Dedup) — many op-response/nested inline objects share a
     shape — keeping the originals untouched. *)
  Dedup.run ~orig:schemas ~aux:(List.rev !hoist_order) ~ops
