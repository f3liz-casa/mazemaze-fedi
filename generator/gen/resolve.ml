(* Resolve — a generator pass between Openapi.lower and the emitters.
   OpenAPI schemas reference each other in any order and form cycles
   (Note <-> User, self-references, ...). A single .ml is sequential, so we:
     1. toposort schemas so a dependency precedes its dependent where acyclic;
     2. degrade any remaining back-edge / self / unknown Ref to the opaque
        Json case, so everything compiles.
   Op request/response refs are degraded only when they point to an unknown
   schema (all schemas are emitted before the ops). It is an IR -> IR transform,
   so BOTH emitters see the same degraded IR and cannot drift. Precise mutual
   recursion (module rec) is a later refinement. *)

open Ir
module S = Set.Make (String)

let rec ty_refs = function
  | Ref n -> S.singleton n
  | Array t -> ty_refs t
  | _ -> S.empty

let schema_refs = function
  | Record fields ->
    List.fold_left (fun acc f -> S.union acc (ty_refs f.ty)) S.empty fields
  | Alias ty -> ty_refs ty
  (* a discriminated union's .res inlines its member records' fields, so it must be
     emitted after them (and transitively after their field types) — track the
     member refs so the toposort orders the union last. *)
  | Union tys -> List.fold_left (fun acc t -> S.union acc (ty_refs t)) S.empty tys
  | Enum _ -> S.empty

(* DFS toposort: emit dependencies before dependents where the graph is acyclic *)
let order (schemas : named list) : named list =
  let by_name = List.map (fun (n : named) -> (n.name, n)) schemas in
  let state = Hashtbl.create 128 in
  let out = ref [] in
  let rec visit name =
    match Hashtbl.find_opt state name with
    | Some _ -> ()
    | None ->
      Hashtbl.replace state name `Temp;
      (match List.assoc_opt name by_name with
       | Some n -> S.iter visit (schema_refs n.schema)
       | None -> ());
      Hashtbl.replace state name `Done;
      (match List.assoc_opt name by_name with Some n -> out := n :: !out | None -> ())
  in
  List.iter (fun (n : named) -> visit n.name) schemas;
  List.rev !out

(* degrade Refs that point to a not-yet-defined schema (mutual cycle / unknown).
   A SELF-reference (a schema's field pointing at the schema itself, e.g.
   Note.reply : Note) is kept — OCaml records are recursive, and the emitter
   renders the self-ref as the bare type `t`. Only true forward/mutual edges,
   which a single sequential .ml cannot satisfy, are broken. *)
let break (schemas : named list) : named list * int =
  let degraded = ref 0 in
  let defined = Hashtbl.create 128 in
  let fix ~self =
    let rec go = function
      | Ref n when n = self -> Ref n                                   (* self-ref: keep *)
      | Ref n when not (Hashtbl.mem defined n) -> incr degraded; Json  (* forward/mutual: break *)
      | Ref n -> Ref n
      | Array t -> Array (go t)
      | t -> t
    in
    go
  in
  let fix_schema self = function
    | Record fields -> Record (List.map (fun f -> { f with ty = fix ~self f.ty }) fields)
    | Alias ty -> Alias (fix ~self ty)
    | s -> s
  in
  let result =
    List.map
      (fun (n : named) ->
        let n' = { n with schema = fix_schema n.name n.schema } in
        Hashtbl.replace defined n.name true;
        n')
      schemas
  in
  (result, !degraded)

let run (ir : t) : t * int =
  let ordered, d1 = break (order ir.schemas) in
  (* ops come after all schemas: degrade only refs to schema names we never saw *)
  let names = List.fold_left (fun s (n : named) -> S.add n.name s) S.empty ordered in
  let d2 = ref 0 in
  let rec fix = function
    | Ref n when not (S.mem n names) -> incr d2; Json
    | Ref n -> Ref n
    | Array t -> Array (fix t)
    | t -> t
  in
  let ops =
    List.map
      (fun o ->
        { o with
          request = List.map (fun f -> { f with ty = fix f.ty }) o.request;
          response = fix o.response })
      ir.ops
  in
  ({ schemas = ordered; ops }, d1 + !d2)
