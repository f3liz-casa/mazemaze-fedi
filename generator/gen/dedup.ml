(* Dedup — fold structurally-identical hoisted aux records into one.
   A6 hoists every inline object it meets, so many op responses and nested
   shapes produce byte-identical records under different position-derived names
   (postX_response, postY_response, …). Here we collapse those: keep one
   canonical schema per structure and rewrite every Ref to it.

   ONLY the aux schemas are folded — the original component schemas keep their
   spec names (those names carry meaning; two distinct components are never
   merged). An aux that matches an original's shape folds INTO the original,
   which is the nicest outcome (the synthesised name disappears in favour of the
   real one).

   Bottom-up: we order aux children-before-parents (Resolve.order) and rewrite
   each record's child Refs to their already-chosen canonical before keying it,
   so identically-shaped subtrees collapse too. A cyclic aux simply doesn't fold
   (its key keeps an unresolved name) — correctness is preserved, we just keep a
   duplicate. *)

open Ir

let run ~orig ~aux ~ops : t =
  let alias : (string, string) Hashtbl.t = Hashtbl.create 256 in
  let rec resolve n = match Hashtbl.find_opt alias n with Some m -> resolve m | None -> n in

  (* structure key — Refs resolved through the alias map so equal subtrees match *)
  let rec ty_key = function
    | Prim String -> "s" | Prim Int -> "i" | Prim Float -> "f" | Prim Bool -> "b"
    | Json -> "j"
    | Array t -> "[" ^ ty_key t ^ "]"
    | Ref n -> "R" ^ resolve n
  in
  let field_key (f : field) =
    Printf.sprintf "%s=%s/%b/%b/%s" f.name (ty_key f.ty) f.optional f.nullable
      (match f.enum_values with Some vs -> String.concat "|" vs | None -> "")
  in
  let record_key fields = String.concat ";" (List.map field_key fields) in

  (* originals seed the table as canonical, but are never folded themselves *)
  let by_key : (string, string) Hashtbl.t = Hashtbl.create 256 in
  List.iter
    (fun (n : named) ->
      match n.schema with
      | Record fields ->
        let k = record_key fields in
        if not (Hashtbl.mem by_key k) then Hashtbl.replace by_key k n.name
      | _ -> ())
    orig;

  (* fold aux children-first; non-records are always kept as-is *)
  let kept = ref [] in
  List.iter
    (fun (n : named) ->
      match n.schema with
      | Record fields ->
        let k = record_key fields in
        (match Hashtbl.find_opt by_key k with
         | Some canon -> Hashtbl.replace alias n.name canon
         | None -> Hashtbl.replace by_key k n.name; kept := n :: !kept)
      | _ -> kept := n :: !kept)
    (Resolve.order aux);

  (* rewrite every Ref through the final alias map *)
  let rec fix = function
    | Ref n -> Ref (resolve n)
    | Array t -> Array (fix t)
    | t -> t
  in
  let fix_fields fs = List.map (fun (f : field) -> { f with ty = fix f.ty }) fs in
  let fix_schema = function
    | Record fs -> Record (fix_fields fs)
    | Union tys -> Union (List.map fix tys)
    | Alias t -> Alias (fix t)
    | Enum _ as s -> s
  in
  let fix_named (n : named) = { n with schema = fix_schema n.schema } in
  let fix_op (o : op) =
    { o with request = fix_fields o.request; response = fix o.response }
  in

  let schemas = List.map fix_named (orig @ List.rev !kept) in
  { schemas; ops = List.map fix_op ops }
