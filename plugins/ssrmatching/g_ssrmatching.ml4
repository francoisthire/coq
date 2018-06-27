(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *   INRIA, CNRS and contributors - Copyright 1999-2018       *)
(* <O___,, *       (see CREDITS file for the list of authors)           *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

open Ltac_plugin
open Genarg
open Pcoq
open Pcoq.Constr
open Ssrmatching
open Ssrmatching.Internal

(* Defining grammar rules with "xx" in it automatically declares keywords too,
 * we thus save the lexer to restore it at the end of the file *)
let frozen_lexer = CLexer.get_keyword_state () ;;

DECLARE PLUGIN "ssrmatching_plugin"

let pr_rpattern _ _ _ = pr_rpattern

ARGUMENT EXTEND rpattern
  TYPED AS rpatternty
  PRINTED BY pr_rpattern
  INTERPRETED BY interp_rpattern
  GLOBALIZED BY glob_rpattern
  SUBSTITUTED BY subst_rpattern
  | [ lconstr(c) ] -> [ mk_rpattern (T (mk_lterm c None)) ]
  | [ "in" lconstr(c) ] -> [ mk_rpattern (In_T (mk_lterm c None)) ]
  | [ lconstr(x) "in" lconstr(c) ] ->
    [ mk_rpattern (X_In_T (mk_lterm x None, mk_lterm c None)) ]
  | [ "in" lconstr(x) "in" lconstr(c) ] ->
    [ mk_rpattern (In_X_In_T (mk_lterm x None, mk_lterm c None)) ]
  | [ lconstr(e) "in" lconstr(x) "in" lconstr(c) ] ->
    [ mk_rpattern (E_In_X_In_T (mk_lterm e None, mk_lterm x None, mk_lterm c None)) ]
  | [ lconstr(e) "as" lconstr(x) "in" lconstr(c) ] ->
    [ mk_rpattern (E_As_X_In_T (mk_lterm e None, mk_lterm x None, mk_lterm c None)) ]
END

let pr_ssrterm _ _ _ = pr_ssrterm

ARGUMENT EXTEND cpattern
     PRINTED BY pr_ssrterm
     INTERPRETED BY interp_ssrterm
     GLOBALIZED BY glob_cpattern SUBSTITUTED BY subst_ssrterm
     RAW_PRINTED BY pr_ssrterm
     GLOB_PRINTED BY pr_ssrterm
| [ "Qed" constr(c) ] -> [ mk_lterm c None ]
END

let input_ssrtermkind strm = match Util.stream_nth 0 strm with
  | Tok.KEYWORD "(" -> '('
  | Tok.KEYWORD "@" -> '@'
  | _ -> ' '
let ssrtermkind = Pcoq.Gram.Entry.of_parser "ssrtermkind" input_ssrtermkind

GEXTEND Gram
  GLOBAL: cpattern;
  cpattern: [[ k = ssrtermkind; c = constr ->
    let pattern = mk_term k c None in
    if loc_of_cpattern pattern <> Some !@loc && k = '('
    then mk_term 'x' c None
    else pattern ]];
END

ARGUMENT EXTEND lcpattern
     TYPED AS cpattern
     PRINTED BY pr_ssrterm
     INTERPRETED BY interp_ssrterm
     GLOBALIZED BY glob_cpattern SUBSTITUTED BY subst_ssrterm
     RAW_PRINTED BY pr_ssrterm
     GLOB_PRINTED BY pr_ssrterm
| [ "Qed" lconstr(c) ] -> [ mk_lterm c None ]
END

GEXTEND Gram
  GLOBAL: lcpattern;
  lcpattern: [[ k = ssrtermkind; c = lconstr ->
    let pattern = mk_term k c None in
    if loc_of_cpattern pattern <> Some !@loc && k = '('
    then mk_term 'x' c None
    else pattern ]];
END

ARGUMENT EXTEND ssrpatternarg TYPED AS rpattern PRINTED BY pr_rpattern
| [ rpattern(pat) ] -> [ pat ]
END

TACTIC EXTEND ssrinstoftpat
| [ "ssrinstancesoftpat" cpattern(arg) ] -> [ Proofview.V82.tactic (ssrinstancesof arg) ]
END

(* We wipe out all the keywords generated by the grammar rules we defined. *)
(* The user is supposed to Require Import ssreflect or Require ssreflect   *)
(* and Import ssreflect.SsrSyntax to obtain these keywords and as a         *)
(* consequence the extended ssreflect grammar.                             *)
let () = CLexer.set_keyword_state frozen_lexer ;;
