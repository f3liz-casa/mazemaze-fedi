(* Graphql — a second front-end, the sibling of Openapi. It lowers a *normalized*
   GraphQL operations document into the same Ir.t the OpenAPI front-end produces,
   so everything downstream (Resolve, the emitters, the [@@deriving json] runtime,
   the JSDoc) is reused unchanged.

   GraphQL differs from REST in one essential way: the *shape* of a response is
   decided by the query's selection set, not by the schema alone. So this is a
   document-driven front-end — the probe (graphql-js: schema + executable
   document -> resolved selection tree) hands us each operation already typed,
   and we project its selection set into synthesized Records. Each operation
   becomes a single POST /graphql op carrying its query document.

   The probe's normalized JSON is the contract (a `type` node is one of
   {object:[field]} | {list:type} | {scalar:name}); this file is the only place
   that knows it. *)

open Ir
module U = Yojson.Safe.Util

(* GraphQL scalars on the wire: every custom scalar (HTML, DateTime, URL, UUID,
   Markdown, …) is a JSON string, so only the built-ins and JSON differ. *)
let scalar_ty = function
  | "Int" -> Prim Int
  | "Float" -> Prim Float
  | "Boolean" -> Prim Bool
  | "JSON" -> Json
  | _ -> Prim String

let cap = String.capitalize_ascii
let bool_field j name = match U.member name j with `Bool b -> b | _ -> false

(* records synthesized while walking one document's selection sets. The selection
   set is anonymous in GraphQL; we name each object by its path so the names are
   unique and stable, and push it here as a named schema for the emitters. *)
let synth : named list ref = ref []
let add name schema = synth := { name; schema; doc = None } :: !synth

(* a selection `type` node -> Ir.ty, registering a Record for every object (and,
   for a union/interface, one Record per branch) it contains. `name` is the
   synthesized name this node takes; a list passes the same name to its element.

   A union/interface selection becomes `Union [Ref branch …]` where each branch
   is a Record carrying a `__typename` field pinned to its concrete type name (a
   single-value enum) plus the interface's common fields and its own fragment
   fields. That is exactly the shape the existing emitters already discriminate
   on: emit_rescript's detect_disc_union picks `__typename` as the tag (@tag
   variant), emit_jsdoc emits `A | B | …` with each branch's `__typename` literal
   (a TS discriminated union), and emit_melange keeps the union opaque (runtime =
   the raw object), uniform with the OpenAPI `$type` discriminated unions. *)
let rec lower_type name node : ty =
  match U.member "object" node, U.member "union" node, U.member "input" node, U.member "list" node with
  | `List fields, _, _, _ ->
    add name (Record (List.map (lower_field name) fields)); Ref name
  | _, (`Assoc _ as uni), _, _ ->
    let common = match U.member "common" uni with `List l -> l | _ -> [] in
    let refs =
      U.member "branches" uni |> U.to_list |> List.map (fun br ->
        let tn = U.member "typename" br |> U.to_string in
        let bname = name ^ tn in
        let typename_field =
          { name = "__typename"; ty = Prim String; optional = false; nullable = false;
            enum_values = Some [ tn ]; doc = None; format = None } in
        let common_fields = List.map (lower_field bname) common in
        let own_fields =
          match U.member "fields" br with `List l -> List.map (lower_field bname) l | _ -> [] in
        add bname (Record (typename_field :: (common_fields @ own_fields)));
        Ref bname)
    in
    add name (Union refs); Ref name
  | _, _, `String iname, _ ->
    (* a reference to a named input-object type (variable / input field); the
       record itself is lowered once from the `inputs` section. *)
    Ref iname
  | _, _, _, `Null ->
    (match U.member "scalar" node with `String s -> scalar_ty s | _ -> Json)
  | _, _, _, inner -> Array (lower_type name inner)

and lower_field parent fjson : field =
  let fname = U.member "name" fjson |> U.to_string in
  let ty = lower_type (parent ^ cap fname) (U.member "type" fjson) in
  { name = fname; ty;
    optional = bool_field fjson "optional";
    nullable = bool_field fjson "nullable";
    enum_values = None; doc = None; format = None }

(* an operation variable ($after: String, $input: SomeInput!) -> a request field.
   A variable with no `!` is omittable, which is exactly the field's
   optional+nullable shape. The variable's type is a `type` node (scalar / input
   ref / list); the legacy bare `scalar` form is still accepted for the
   hand-written spike fixtures. *)
let lower_var vjson : field =
  let name = U.member "name" vjson |> U.to_string in
  let optional = bool_field vjson "optional" in
  let ty =
    match U.member "type" vjson with
    | `Null -> (match U.member "scalar" vjson with `String s -> scalar_ty s | _ -> Json)
    | tnode -> lower_type (name ^ "Var") tnode
  in
  { name; ty; optional; nullable = optional;
    enum_values = None; doc = None; format = None }

let lower_op ojson : op =
  let opname = U.member "name" ojson |> U.to_string in
  let document = U.member "document" ojson |> U.to_string in
  let vars = U.member "variables" ojson |> U.to_list |> List.map lower_var in
  (* the selection set itself is an object; name it <Op>Data and wrap it in a
     <Op>Response so the decoder reads the GraphQL `{ "data": … }` envelope
     directly through the ordinary record machinery (errors are ignored). *)
  let data_name = opname ^ "Data" in
  let _ : ty = lower_type data_name (U.member "selection" ojson) in
  let resp_name = opname ^ "Response" in
  add resp_name
    (Record [ { name = "data"; ty = Ref data_name; optional = false; nullable = false;
                enum_values = None; doc = None; format = None } ]);
  { name = Repr.lower_first opname; http_method = "POST"; path = "/graphql";
    request = vars; response = Ref resp_name; doc = None; tag = "Graphql";
    path_params = []; query_params = []; gql_document = Some document }

(* the probe's `inputs` section: each named input-object type -> a Record, so a
   variable of that type gets a real typed request field (not opaque Json). *)
let lower_input ijson =
  let iname = U.member "name" ijson |> U.to_string in
  let fields = match U.member "fields" ijson with `List l -> List.map (lower_field iname) l | _ -> [] in
  add iname (Record fields)

let lower (root : Yojson.Safe.t) : t =
  synth := [];
  (match U.member "inputs" root with `List l -> List.iter lower_input l | _ -> ());
  let ops = U.member "operations" root |> U.to_list |> List.map lower_op in
  { schemas = List.rev !synth; ops }
