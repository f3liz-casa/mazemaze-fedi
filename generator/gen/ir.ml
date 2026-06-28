(* The IR — pure data, the single thing every emitter reads.
   Optionality lives on the field (not a ty constructor), because "this field
   may be absent" is a property of the *declaration site*, and that is exactly
   how both Melange ([@json.option]) and JSDoc (optional property) encode it. *)

type prim = String | Int | Float | Bool

type ty =
  | Prim of prim
  | Array of ty
  | Ref of string        (* name of a named schema *)
  | Json                 (* free-form / unsupported-union fallback *)

type field = {
  name : string;             (* JSON property key (also the JS object key) *)
  ty : ty;
  optional : bool;           (* key may be absent (not in `required`) *)
  nullable : bool;           (* 3.1 `type:[...,"null"]`: value may be JSON null *)
  enum_values : string list option;  (* property-level enum -> string + JSDoc union *)
  doc : string option;       (* OpenAPI description -> JSDoc prose *)
  format : string option;    (* OpenAPI `format` (date-time, url, …) -> JSDoc note *)
}

type schema =
  | Record of field list
  | Enum of string list      (* named enum: OCaml string ; JSDoc union *)
  | Alias of ty
  | Union of ty list         (* oneOf/anyOf/allOf -> opaque Melange_json.t fallback *)

type named = { name : string; schema : schema; doc : string option }

type op = {
  name : string;             (* clean computable base for the send accessor *)
  http_method : string;
  path : string;
  request : field list;      (* path params + inline request-body properties *)
  response : ty;             (* 200 application/json schema, or Json fallback *)
  doc : string option;       (* OpenAPI operation description -> JSDoc prose *)
  tag : string;              (* OpenAPI tags[0] (PascalCase) -> ReScript group module *)
  path_params : string list; (* wire names of `in:path` params, substituted into {name} *)
  query_params : field list; (* `in:query` params, appended to the URL as ?k=v *)
  gql_document : string option; (* GraphQL front-end: the query/mutation document
                                   string. None for REST (OpenAPI) ops; Some doc
                                   makes the send POST {query, variables} to /graphql. *)
}

type t = { schemas : named list; ops : op list }
