(************************************************************************)
(*  v      *   The Coq Proof Assistant  /  The Coq Development Team     *)
(* <O___,, *   INRIA - CNRS - LIX - LRI - PPS - Copyright 1999-2012     *)
(*   \VV/  **************************************************************)
(*    //   *      This file is distributed under the terms of the       *)
(*         *       GNU Lesser General Public License Version 2.1        *)
(************************************************************************)

open Loc
open Names
open Constrexpr
open Libnames
open Globnames
open Nametab
open Genredexpr
open Genarg
open Pattern
open Decl_kinds
open Misctypes
open Locus

type direction_flag = bool (* true = Left-to-right    false = right-to-right *)
type lazy_flag = bool      (* true = lazy             false = eager *)
type evars_flag = bool     (* true = pose evars       false = fail on evars *)
type rec_flag = bool       (* true = recursive        false = not recursive *)
type advanced_flag = bool  (* true = advanced         false = basic *)
type letin_flag = bool     (* true = use local def    false = use Leibniz *)

type debug = Debug | Info | Off (* for trivial / auto / eauto ... *)

type 'a induction_arg =
  | ElimOnConstr of 'a
  | ElimOnIdent of Id.t located
  | ElimOnAnonHyp of int

type inversion_kind =
  | SimpleInversion
  | FullInversion
  | FullInversionClear

type ('c,'id) inversion_strength =
  | NonDepInversion of
      inversion_kind * 'id list * intro_pattern_expr located option
  | DepInversion of
      inversion_kind * 'c option * intro_pattern_expr located option
  | InversionUsing of 'c * 'id list

type ('a,'b) location = HypLocation of 'a | ConclLocation of 'b

type 'id message_token =
  | MsgString of string
  | MsgInt of int
  | MsgIdent of 'id

type 'constr induction_clause =
    'constr with_bindings induction_arg *
    (intro_pattern_expr located option (* eqn:... *)
    * intro_pattern_expr located option) (* as ... *)

type ('constr,'id) induction_clause_list =
    'constr induction_clause list
    * 'constr with_bindings option (* using ... *)
    * 'id clause_expr option (* in ... *)

type multi =
  | Precisely of int
  | UpTo of int
  | RepeatStar
  | RepeatPlus

(* Type of patterns *)
type 'a match_pattern =
  | Term of 'a
  | Subterm of bool * Id.t option * 'a

(* Type of hypotheses for a Match Context rule *)
type 'a match_context_hyps =
  | Hyp of Name.t located * 'a match_pattern
  | Def of Name.t located * 'a match_pattern * 'a match_pattern

(* Type of a Match rule for Match Context and Match *)
type ('a,'t) match_rule =
  | Pat of 'a match_context_hyps list * 'a match_pattern * 't
  | All of 't

type ml_tactic_name = {
  mltac_plugin : string;
  mltac_tactic : string;
}

(** Composite types *)

(** In globalize tactics, we need to keep the initial [constr_expr] to recompute
   in the environment by the effective calls to Intro, Inversion, etc 
   The [constr_expr] field is [None] in TacDef though *)
type glob_constr_and_expr = Glob_term.glob_constr * constr_expr option

type open_constr_expr = unit * constr_expr
type open_glob_constr = unit * glob_constr_and_expr

type glob_constr_pattern_and_expr = glob_constr_and_expr * constr_pattern

(** Generic expressions for atomic tactics *)

type ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_atomic_tactic_expr =
  (* Basic tactics *)
  | TacIntroPattern of intro_pattern_expr located list
  | TacIntrosUntil of quantified_hypothesis
  | TacIntroMove of Id.t option * 'nam move_location
  | TacExact of 'trm
  | TacApply of advanced_flag * evars_flag * 'trm with_bindings list *
      ('nam * intro_pattern_expr located option) option
  | TacElim of evars_flag * 'trm with_bindings * 'trm with_bindings option
  | TacCase of evars_flag * 'trm with_bindings
  | TacFix of Id.t option * int
  | TacMutualFix of Id.t * int * (Id.t * int * 'trm) list
  | TacCofix of Id.t option
  | TacMutualCofix of Id.t * (Id.t * 'trm) list
  | TacAssert of
      ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_expr option *
      intro_pattern_expr located option * 'trm
  | TacGeneralize of ('trm with_occurrences * Name.t) list
  | TacGeneralizeDep of 'trm
  | TacLetTac of Name.t * 'trm * 'nam clause_expr * letin_flag *
      intro_pattern_expr located option

  (* Derived basic tactics *)
  | TacSimpleInductionDestruct of rec_flag * quantified_hypothesis
  | TacInductionDestruct of
      rec_flag * evars_flag * ('trm,'nam) induction_clause_list
  | TacDoubleInduction of quantified_hypothesis * quantified_hypothesis
  | TacDecompose of 'ind list * 'trm

  (* Automation tactics *)
  | TacTrivial of debug * 'trm list * string list option
  | TacAuto of debug * int or_var option * 'trm list * string list option

  (* Context management *)
  | TacClear of bool * 'nam list
  | TacClearBody of 'nam list
  | TacMove of bool * 'nam * 'nam move_location
  | TacRename of ('nam *'nam) list
  | TacRevert of 'nam list

  (* Trmuctors *)
  | TacSplit of evars_flag * 'trm bindings list
  | TacAnyConstructor of evars_flag *
      ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_expr option
  | TacConstructor of evars_flag * int or_var * 'trm bindings

  (* Conversion *)
  | TacReduce of ('trm,'cst,'pat) red_expr_gen * 'nam clause_expr
  | TacChange of 'pat option * 'trm * 'nam clause_expr

  (* Equivalence relations *)
  | TacSymmetry of 'nam clause_expr

  (* Equality and inversion *)
  | TacRewrite of evars_flag *
      (bool * multi * 'trm with_bindings) list * 'nam clause_expr *
      ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_expr option
  | TacInversion of ('trm,'nam) inversion_strength * quantified_hypothesis

  (* For ML extensions *)
  | TacExtend of Loc.t * ml_tactic_name * 'lev generic_argument list

  (* For syntax extensions *)
  | TacAlias of Loc.t * KerName.t * (Id.t * 'lev generic_argument) list

(** Possible arguments of a tactic definition *)

and ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_arg =
  | TacDynamic     of Loc.t * Dyn.t
  | TacGeneric     of 'lev generic_argument
  | MetaIdArg      of Loc.t * bool * string
  | ConstrMayEval  of ('trm,'cst,'pat) may_eval
  | UConstr        of 'trm  (* We can reuse ['trm] because terms and untyped terms
                               only differ at interpretation time (and not at
                               internalisation), and the output of interpration
                               is not a variant of [tactic_expr]. *)
  | Reference      of 'ref
  | TacCall of Loc.t * 'ref *
      ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_arg list
  | TacExternal of Loc.t * string * string *
      ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_arg list
  | TacFreshId of string or_var list
  | Tacexp of ('trm,'pat,'cst,'ind,'ref,'nam,'lev) gen_tactic_expr
  | TacPretype of 'trm

(** Generic ltac expressions.
    't : terms, 'p : patterns, 'c : constants, 'i : inductive,
    'r : ltac refs, 'n : idents, 'l : levels *)

and ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr =
  | TacAtom of Loc.t * ('t,'p,'c,'i,'r,'n,'l) gen_atomic_tactic_expr
  | TacThen of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacThens of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr list
  | TacThens3parts of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr array *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr array
  | TacFirst of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr list
  | TacComplete of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacSolve of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr list
  | TacTry of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacOr of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacOnce of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacExactlyOnce of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacOrelse of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacDo of int or_var * ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacTimeout of int or_var * ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacTime of string option * ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacRepeat of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacProgress of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacShowHyps of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacAbstract of
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr * Id.t option
  | TacId of 'n message_token list
  | TacFail of int or_var * 'n message_token list
  | TacInfo of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacLetIn of rec_flag *
      (Id.t located * ('t,'p,'c,'i,'r,'n,'l) gen_tactic_arg) list *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr
  | TacMatch of lazy_flag *
      ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr *
      ('p,('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr) match_rule list
  | TacMatchGoal of lazy_flag * direction_flag *
      ('p,('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr) match_rule list
  | TacFun of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_fun_ast
  | TacArg of ('t,'p,'c,'i,'r,'n,'l) gen_tactic_arg located

and ('t,'p,'c,'i,'r,'n,'l) gen_tactic_fun_ast =
    Id.t option list * ('t,'p,'c,'i,'r,'n,'l) gen_tactic_expr

(** Globalized tactics *)

type g_trm = glob_constr_and_expr
type g_pat = glob_constr_and_expr * constr_pattern
type g_cst = evaluable_global_reference and_short_name or_var
type g_ind = inductive or_var
type g_ref = ltac_constant located or_var
type g_nam  = Id.t located

type glob_tactic_expr =
    (g_trm, g_pat, g_cst, g_ind, g_ref, g_nam, glevel) gen_tactic_expr

type glob_atomic_tactic_expr =
    (g_trm, g_pat, g_cst, g_ind, g_ref, g_nam, glevel) gen_atomic_tactic_expr

type glob_tactic_arg =
    (g_trm, g_pat, g_cst, g_ind, g_ref, g_nam, glevel) gen_tactic_arg

(** Raw tactics *)

type r_trm = constr_expr
type r_pat = constr_pattern_expr
type r_cst = reference or_by_notation
type r_ind = reference or_by_notation
type r_ref = reference
type r_nam  = Id.t located
type r_lev = rlevel

type raw_atomic_tactic_expr =
    (r_trm, r_pat, r_cst, r_ind, r_ref, r_nam, rlevel) gen_atomic_tactic_expr

type raw_tactic_expr =
    (r_trm, r_pat, r_cst, r_ind, r_ref, r_nam, rlevel) gen_tactic_expr

type raw_tactic_arg =
    (r_trm, r_pat, r_cst, r_ind, r_ref, r_nam, rlevel) gen_tactic_arg

(** Misc *)

type raw_red_expr = (r_trm, r_cst, r_pat) red_expr_gen
type glob_red_expr = (g_trm, g_cst, g_pat) red_expr_gen
