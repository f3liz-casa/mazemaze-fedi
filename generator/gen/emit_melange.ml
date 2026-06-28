(* Emit_melange : Ir.t -> the .ml text (types + [@@deriving json] + flat
   accessors). Mirrors the production emitter's conventions: enum-as-string,
   array (not list), option [@json.option][@json.drop_default], camelCase
   flat accessors with clean computable names. Unsupported schemas (unions,
   free-form) fall back to an opaque Melange_json.t module so refs still
   resolve and everything compiles. *)

open Ir

let buf_add = Buffer.add_string

let field_ml ?(self = "") (f : field) =
  let label, key_opt = Repr.ocaml_label f.name in
  let base = Repr.ocaml_type_self self f.ty in
  let ty, attrs =
    if Repr.field_optional f then base ^ " option", " [@json.option] [@json.drop_default]"
    else base, ""
  in
  let key =
    match key_opt with
    | Some w -> Printf.sprintf " [@json.key \"%s\"]" w
    | None -> ""
  in
  Printf.sprintf "    %s : %s;%s%s" label ty key attrs

let accessors b (n : named) m =
  buf_add b (Printf.sprintf "let %s = %s.of_json\n" (Repr.accessor n.name `Of_json) m);
  buf_add b (Printf.sprintf "let %s = %s.to_json\n\n" (Repr.accessor n.name `To_json) m)

let record_ml b (n : named) fields =
  let m = Repr.module_name n.name in
  buf_add b (Printf.sprintf "module %s = struct\n" m);
  buf_add b "  type t = {\n";
  List.iter (fun f -> buf_add b (field_ml ~self:n.name f); buf_add b "\n") fields;
  buf_add b "  } [@@deriving json]\n";
  buf_add b "end\n";
  accessors b n m

let enum_ml b (n : named) =
  (* enum carried as plain string (melange-json 2.0 dropped bare-string enum
     encoding); the allowed set is not enforced here, matching production. *)
  let m = Repr.module_name n.name in
  buf_add b (Printf.sprintf "module %s = struct\n" m);
  buf_add b "  type t = string\n";
  buf_add b "  let of_json = Melange_json.Of_json.string\n";
  buf_add b "  let to_json = Melange_json.To_json.string\n";
  buf_add b "end\n\n"

(* opaque fallback: a real module with identity converters, so a Ref to it
   still type-checks and the JS surface stays uniform. *)
let opaque_ml b (n : named) =
  let m = Repr.module_name n.name in
  buf_add b (Printf.sprintf "module %s = struct\n" m);
  buf_add b "  type t = Melange_json.t\n";
  buf_add b "  let of_json (j : Melange_json.t) : t = j\n";
  buf_add b "  let to_json (x : t) : Melange_json.t = x\n";
  buf_add b "end\n";
  accessors b n m

(* a type alias `type t = <ty>` with the ty's own codec (atproto's string
   aliases, top-level arrays, …). Json falls through to the opaque module. *)
let alias_ml b (n : named) ty =
  let m = Repr.module_name n.name in
  buf_add b (Printf.sprintf "module %s = struct\n" m);
  buf_add b (Printf.sprintf "  type t = %s\n" (Repr.ocaml_type ty));
  buf_add b (Printf.sprintf "  let of_json = %s\n" (Repr.decoder ty));
  buf_add b (Printf.sprintf "  let to_json = %s\n" (Repr.encoder ty));
  buf_add b "end\n";
  accessors b n m

let named_ml b (n : named) =
  match n.schema with
  | Record fields -> record_ml b n fields
  | Enum _ -> enum_ml b n
  | Alias Json | Union _ -> opaque_ml b n
  | Alias ty -> alias_ml b n ty

(* stringify a scalar query value `expr` of type `ty` (None = not a scalar) *)
let query_scalar_ml ty expr =
  match ty with
  | Prim String -> Some (Printf.sprintf "(Js.Global.encodeURIComponent %s)" expr)
  | Prim Int -> Some (Printf.sprintf "(string_of_int %s)" expr)
  | Prim Float -> Some (Printf.sprintf "(Js.Float.toString %s)" expr)
  | Prim Bool -> Some (Printf.sprintf "(if %s then \"true\" else \"false\")" expr)
  | _ -> None

(* a query field goes in the URL iff it's a scalar or an array of scalars *)
let query_in_url (f : field) =
  match f.ty with
  | Array elem -> query_scalar_ml elem "x" <> None
  | ty -> query_scalar_ml ty "x" <> None

(* a `string` expr contributing `&name=value` (scalar) or `&name[]=v1&name[]=v2`
   (array; Rails/Mastodon bracket style), or "" when absent. The leading `&` is
   stripped after concatenation (melange's mini-stdlib lacks List.filter). *)
let query_pair_ml (f : field) =
  let label, _ = Repr.ocaml_label f.name in
  let contribution value_expr =
    match f.ty with
    | Array elem ->
      (match query_scalar_ml elem "v" with
       | Some s ->
         Printf.sprintf "(%s |> Js.Array.reduce ~f:(fun acc v -> acc ^ %S ^ %s) ~init:\"\")"
           value_expr ("&" ^ f.name ^ "[]=") s
       | None -> "\"\"")
    | ty ->
      (match query_scalar_ml ty value_expr with
       | Some s -> Printf.sprintf "%S ^ %s" ("&" ^ f.name ^ "=") s
       | None -> "\"\"")
  in
  if Repr.field_optional f then
    Printf.sprintf "(match req.%s with Some v -> %s | None -> \"\")" label (contribution "v")
  else contribution (Printf.sprintf "req.%s" label)

(* one endpoint: a request type + a flat `<op>_send fetch req` wrapper that
   encodes the request, calls the injected fetch, and decodes the response. *)
let op_ml b (o : op) =
  let m = Repr.module_name o.name in
  buf_add b (Printf.sprintf "module %s = struct\n" m);
  (match o.request with
   | [] ->
     (* OCaml has no empty record; a no-argument endpoint sends a bare `{}`.
        The send still takes a `req` for a uniform (fetch, req) surface — its
        value is ignored. *)
     buf_add b "  type request = unit\n";
     buf_add b "  let request_to_json (_ : request) : Js.Json.t = Js.Json.object_ (Js.Dict.empty ())\n"
   | fields ->
     buf_add b "  type request = {\n";
     List.iter (fun f -> buf_add b (field_ml f); buf_add b "\n") fields;
     buf_add b "  } [@@deriving json]\n");
  buf_add b "end\n";
  let send = Repr.lower_first o.name ^ "_send" in
  buf_add b
    (Printf.sprintf
       "let %s (fetch : string -> string -> Js.Json.t -> Js.Json.t Js.Promise.t) (req : %s.request) =\n"
       send m);
  match o.gql_document with
  | Some doc ->
    (* GraphQL: one endpoint. The body is { query, variables } (the variables are
       the request record); the response decoder reads the `{ "data": … }`
       envelope through the synthesized <Op>Response wrapper (errors ignored). *)
    buf_add b (Printf.sprintf "  let variables = %s.request_to_json req in\n" m);
    buf_add b
      (Printf.sprintf
         "  let body = Js.Json.object_ (Js.Dict.fromList [(\"query\", Js.Json.string %S); (\"variables\", variables)]) in\n"
         doc);
    buf_add b
      (Printf.sprintf
         "  Js.Promise.then_ (fun j -> Js.Promise.resolve (%s j)) (fetch \"POST\" \"/graphql\" body)\n\n"
         (Repr.decoder o.response))
  | None ->
  let meth = String.uppercase_ascii o.http_method in
  (* only scalar query params can go in the URL; others stay in the body *)
  let scalar_query = List.filter query_in_url o.query_params in
  if o.path_params = [] && scalar_query = [] then
    buf_add b
      (Printf.sprintf
         "  Js.Promise.then_ (fun j -> Js.Promise.resolve (%s j)) (fetch %S %S (%s.request_to_json req))\n\n"
         (Repr.decoder o.response) meth o.path m)
  else begin
    (* build the URL: path template + path-param substitution + query string *)
    (match o.path_params with
     | [] -> buf_add b (Printf.sprintf "  let url = %S in\n" o.path)
     | params ->
       buf_add b (Printf.sprintf "  let url =\n    %S\n" o.path);
       List.iter
         (fun pn ->
           let label = fst (Repr.ocaml_label pn) in
           buf_add b (Printf.sprintf "    |> Js.String.replace ~search:%S ~replacement:req.%s\n"
                        ("{" ^ pn ^ "}") label))
         params;
       buf_add b "  in\n");
    if scalar_query <> [] then begin
      buf_add b "  let q =\n";
      List.iteri
        (fun i f -> buf_add b (Printf.sprintf "    %s %s\n" (if i = 0 then "  " else "^") (query_pair_ml f)))
        scalar_query;
      buf_add b "  in\n";
      (* q is "&a=1&b=2"; turn the leading & into ? (replace hits the first only) *)
      buf_add b "  let url = if q = \"\" then url else url ^ Js.String.replace ~search:\"&\" ~replacement:\"?\" q in\n"
    end;
    buf_add b
      (Printf.sprintf
         "  Js.Promise.then_ (fun j -> Js.Promise.resolve (%s j)) (fetch %S url (%s.request_to_json req))\n\n"
         (Repr.decoder o.response) meth m)
  end

(* B1: schemas and endpoints are emitted to separate modules. Endpoints `open
   Component_schemas`, so every `Note.t` / `Note.of_json` they reference resolves
   without qualification (melange emits the cross-module ESM import for us). *)
let emit (ir : t) : (string * string) list =
  let schemas = Buffer.create 8192 in
  buf_add schemas "(* Generated by the OCaml generator. Do not edit. *)\n";
  buf_add schemas "open! Melange_json.Primitives\n\n";
  List.iter (named_ml schemas) ir.schemas;
  let endpoints = Buffer.create 8192 in
  buf_add endpoints "(* Generated by the OCaml generator. Do not edit. *)\n";
  buf_add endpoints "open! Melange_json.Primitives\n";
  buf_add endpoints "open ComponentSchemas\n\n";
  List.iter (op_ml endpoints) ir.ops;
  [ ("componentSchemas.ml", Buffer.contents schemas);
    ("endpoints.ml", Buffer.contents endpoints) ]
