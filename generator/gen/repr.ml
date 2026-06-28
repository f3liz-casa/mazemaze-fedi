(* Repr — the ONLY place that knows how an IR type maps to each target.
   Emit_melange, Emit_jsdoc (and later Emit_rescript) all call these, so they
   cannot drift apart. The flat-accessor name in particular is produced here
   once and reused by every emitter, which is what guarantees the Melange
   `let userLite_of_json = ...`, the JSDoc metadata entry, and any future
   ReScript external all agree on the same JS export name. *)

open Ir

let module_name s = String.capitalize_ascii s

(* A field is "optional" on the JS side when its key may be absent OR its value
   may be JSON null: Melange decodes null through [@json.option] to None, which
   is `undefined` at runtime — same shape as an absent key. Modelling nullable
   as "also optional" (rather than `T | null`) matches that erased runtime shape
   AND stops the decoder throwing on a present null. Both emitters read THIS, so
   the OCaml option-ness and the JSDoc optionality can never disagree. *)
let field_optional (f : Ir.field) = f.optional || f.nullable

let lower_first s =
  if s = "" then s
  else String.make 1 (Char.lowercase_ascii s.[0]) ^ String.sub s 1 (String.length s - 1)

(* clean, computable, collision-proof: camelCase type + suffix.
   (Verified against the live dist: `userLite_of_json`, no `$$` mangling.) *)
let accessor type_name dir =
  let suffix = match dir with `Of_json -> "_of_json" | `To_json -> "_to_json" in
  lower_first type_name ^ suffix

let keywords =
  [ "and"; "as"; "assert"; "begin"; "class"; "constraint"; "do"; "done";
    "downto"; "else"; "end"; "exception"; "external"; "false"; "for"; "fun";
    "function"; "functor"; "if"; "in"; "include"; "inherit"; "initializer";
    "land"; "lazy"; "let"; "lor"; "lsl"; "lsr"; "lxor"; "match"; "method";
    "mod"; "module"; "mutable"; "new"; "nonrec"; "object"; "of"; "open"; "or";
    "private"; "rec"; "sig"; "struct"; "then"; "to"; "true"; "try"; "type";
    "val"; "virtual"; "when"; "while"; "with" ]

let is_ident_char c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
  || (c >= '0' && c <= '9') || c = '_'

let valid_lower_ident s =
  s <> ""
  && (let c = s.[0] in (c >= 'a' && c <= 'z') || c = '_')
  && String.for_all is_ident_char s

(* an OCaml record label for a JSON key. Returns (label, json_key_if_differs):
   when the key is a keyword or not a valid lowercase identifier we rename the
   label and keep the wire name via [@json.key]. *)
let ocaml_label name =
  if List.mem name keywords then (name ^ "_", Some name)
  else if valid_lower_ident name then (name, None)
  else begin
    let b = Buffer.create (String.length name) in
    String.iter
      (fun c -> Buffer.add_char b (if is_ident_char c then c else '_'))
      name;
    let s = Buffer.contents b in
    let s =
      if s = "" || not (let c = s.[0] in (c >= 'a' && c <= 'z') || c = '_')
      then "_" ^ s else s
    in
    (s, Some name)
  end

(* OCaml/Melange type expression. `self` is the enclosing module's schema name;
   a Ref to it renders as the bare recursive type `t` (within `module Note`,
   `Note.t` is not yet in scope — `t` is the field's self-reference). *)
let rec ocaml_type_self self = function
  | Prim String -> "string"
  | Prim Int -> "int"
  | Prim Float -> "float"
  | Prim Bool -> "bool"
  | Array t -> ocaml_type_self self t ^ " array"
  | Ref n when n = self -> "t"
  | Ref n -> module_name n ^ ".t"
  | Json -> "Melange_json.t"

let ocaml_type ty = ocaml_type_self "" ty

(* --- ReScript binding layer (.res) -------------------------------------------
   The .res types mirror the OCaml ones in ReScript syntax. `qualify` prefixes a
   component Ref (`"ComponentSchemas."` inside Endpoints, `""` inside the schema
   file itself); a self-Ref is the bare recursive `t`. *)
let rec rescript_type_self ~qualify self = function
  | Prim String -> "string"
  | Prim Int -> "int"
  | Prim Float -> "float"
  | Prim Bool -> "bool"
  | Array t -> "array<" ^ rescript_type_self ~qualify self t ^ ">"
  | Ref n when n = self -> "t"
  | Ref n -> qualify ^ module_name n ^ ".t"
  | Json -> "JSON.t"

let rescript_keywords =
  [ "and"; "as"; "assert"; "constraint"; "else"; "exception"; "external"; "false";
    "for"; "if"; "in"; "include"; "lazy"; "let"; "module"; "mutable"; "of"; "open";
    "rec"; "switch"; "true"; "try"; "type"; "when"; "while"; "with" ]

(* a ReScript record-field label for a JSON key. Returns (label, wire_key_if_differs):
   a reserved word or non-lowercase-ident key is renamed and bound back to the wire
   name via `@as("<key>")` (the ReScript analogue of Melange's [@json.key]). *)
let rescript_label name =
  if List.mem name rescript_keywords then (name ^ "_", Some name)
  else if valid_lower_ident name then (name, None)
  else begin
    let b = Buffer.create (String.length name) in
    String.iter (fun c -> Buffer.add_char b (if is_ident_char c then c else '_')) name;
    let s = Buffer.contents b in
    let s =
      if s = "" || not (let c = s.[0] in (c >= 'a' && c <= 'z') || c = '_')
      then "_" ^ s else s
    in
    (s, Some name)
  end

(* JSDoc type expression — models the Melange *runtime* shape, not the OCaml
   surface. A Ref to an enum is just its typedef name here; the union lives in
   the enum's own @typedef. Optionality is applied at property level. *)
let rec jsdoc_type = function
  | Prim String -> "string"
  | Prim Int | Prim Float -> "number"
  | Prim Bool -> "boolean"
  | Array t -> jsdoc_type t ^ "[]"
  | Ref n -> module_name n
  | Json -> "unknown"

(* an OCaml decoder *expression* for a response ty (Primitives are opened). *)
let rec decoder = function
  | Prim String -> "string_of_json"
  | Prim Int -> "int_of_json"
  | Prim Float -> "float_of_json"
  | Prim Bool -> "bool_of_json"
  | Array t -> "(array_of_json " ^ decoder t ^ ")"
  | Ref n -> module_name n ^ ".of_json"
  | Json -> "(fun (j : Js.Json.t) -> j)"

(* an OCaml encoder *expression* (to_json), mirror of `decoder`. *)
let rec encoder = function
  | Prim String -> "string_to_json"
  | Prim Int -> "int_to_json"
  | Prim Float -> "float_to_json"
  | Prim Bool -> "bool_to_json"
  | Array t -> "(array_to_json " ^ encoder t ^ ")"
  | Ref n -> module_name n ^ ".to_json"
  | Json -> "(fun (j : Js.Json.t) -> j)"
