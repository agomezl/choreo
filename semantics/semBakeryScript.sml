open preamble

open astBakeryTheory

val _ = new_theory "semBakery";

val _ = Datatype`
  label = LTau proc varN
        | LCom proc varN proc varN
        | LSel proc bool proc
        | LLet varN proc (datum list -> datum) (varN list)
`;

val freeprocs_def = Define`
  freeprocs (LTau p n)         = {p}
∧ freeprocs (LCom p1 v1 p2 v2) = {p1;p2}
∧ freeprocs (LSel p1 b p2)     = {p1;p2}
∧ freeprocs (LSel p1 b p2)     = {p1;p2}
∧ freeprocs (LLet v p f vl)     = {p}
`;

val sender_def = Define`
  sender (LTau p n)         = NONE
∧ sender (LCom p1 v1 p2 v2) = SOME p1
∧ sender (LSel p1 b p2)     = SOME p1
∧ sender (LLet v p f vl)     = NONE
`;

val receiver_def = Define`
  receiver (LTau p n)          = NONE
∧ receiver (LCom p1 v1 p2 v2) = SOME p2
∧ receiver (LSel p1 b p2)     = SOME p2
∧ receiver (LLet v p f vl)     = NONE
`;

val written_def = Define`
  written (LTau p n)          = NONE
∧ written (LCom p1 v1 p2 v2) = SOME(v2,p2)
∧ written (LSel p1 b p2)     = NONE
∧ written (LLet v p f vl)     = SOME(v,p)
`;

val read_def = Define`
  read (LTau p n)          = {(n,p)}
∧ read (LCom p1 v1 p2 v2) = {(v1,p1)}
∧ read (LSel p1 b p2)     = {}
∧ read (LLet v p f vl)     = set(MAP (λv. (v,p)) vl)
`;

(* On ListTheory.sml *)
val nub'_def = tDefine "nub'" `
  nub' []      = []
∧ nub' (x::xs) = x :: FILTER ($≠ x) (nub' xs)`
(WF_REL_TAC `measure LENGTH`
\\ rw [LENGTH]
\\ ho_match_mp_tac LESS_EQ_LESS_TRANS
\\ Q.EXISTS_TAC `LENGTH xs`
\\ rw [LENGTH_FILTER_LEQ]);

val all_distinct_nub' = Q.store_thm("all_distinct_nub'",
  `∀l. ALL_DISTINCT (nub' l)`,
  rw [ALL_DISTINCT,nub'_def]
  \\ Induct_on `l`
  \\ rw [ALL_DISTINCT,nub'_def,FILTER_ALL_DISTINCT,MEM_FILTER]
);


(* The set of all processes in a choreography *)
val procsOf_def = Define`
  procsOf  Nil             = []
∧ procsOf (IfThen _ p l r) = nub' ([p] ++ procsOf l ++ procsOf r)
∧ procsOf (Com p _ q _ c)  = nub' ([p;q] ++ procsOf c)
∧ procsOf (Sel p _ q c)    = nub' ([p;q] ++ procsOf c)
∧ procsOf (Let _ p _ _ c)  = nub' ([p] ++ procsOf c)
`;

val procsOf_all_distinct = Q.store_thm("procsOf_all_distinct",
  `∀c. ALL_DISTINCT (procsOf c)`,
  Induct_on `c` >> rw [procsOf_def,ALL_DISTINCT,all_distinct_nub']
);


val (lcong_rules,lcong_ind,lcong_cases) = Hol_reln `
(* Congruence rules for lists of asyncronous operations *)

  (* Symmetric *)
  (∀l. lcong l l)

  (* Reflexive *)
∧ (∀l1 l2.
    lcong l1 l2
    ⇒ lcong l2 l1)
  (* Transitive *)
∧ (∀l1 l2 l3.
     lcong l1 l2
     ∧ lcong l2 l3
     ⇒ lcong l1 l3)

  (* Reorder *)
∧ (∀h t t1 t2.
    DISJOINT (freeprocs t1) (freeprocs t2)
    ⇒ lcong (h ++ [t1;t2] ++ t) (h ++ [t2;t1] ++ t))
`;

val _ = Parse.add_infix("τ≅",425,Parse.NONASSOC);
val _ = Parse.overload_on("τ≅",``lcong``);

val [lcong_sym,lcong_refl,lcong_trans,lcong_reord] =
    zip ["lcong_sym","lcong_refl","lcong_trans","lcong_reord"]
        (CONJUNCTS lcong_rules) |> map save_thm;

val (trans_rules,trans_ind,trans_cases) = Hol_reln `

  (* Communication *)
  (∀s v1 p1 v2 p2 d c.
    FLOOKUP s (v1,p1) = SOME d
    ∧ p1 ≠ p2
    ⇒ trans (s,Com p1 v1 p2 v2 c) (LCom p1 v1 p2 v2,[]) (s |+ ((v2,p2),d),c))

  (* Selection *)
∧ (∀s p1 b p2 c.
    p1 ≠ p2
    ⇒ trans (s,Sel p1 b p2 c) (LSel p1 b p2,[]) (s,c))

  (* Let *)
∧ (∀s v p f vl c.
    EVERY IS_SOME (MAP (FLOOKUP s) (MAP (λv. (v,p)) vl))
    ⇒ trans (s,Let v p f vl c)
            (LLet v p f vl,[])
            (s |+ ((v,p),f(MAP (THE o FLOOKUP s) (MAP (λv. (v,p)) vl))),c))

  (* If (True) *)
∧ (∀s v p c1 c2.
    FLOOKUP s (v,p) = SOME [1w]
    ⇒ trans (s,IfThen v p c1 c2) (LTau p v,[]) (s,c1))

  (* If (False) *)
∧ (∀s v p c1 c2.
    FLOOKUP s (v,p) = SOME w ∧ w ≠ [1w]
    ⇒ trans (s,IfThen v p c1 c2) (LTau p v,[]) (s,c2))

  (* Swapping transitions / Structural congruence *)
∧ (∀s v p c1 c2 s' c1' c2' l l' alpha.
    trans (s,c1) (alpha,l) (s',c1')
    ∧ trans (s,c2) (alpha,l') (s',c2')
    ∧ l τ≅ l'
    ∧ p ∉ freeprocs alpha
    ⇒ trans (s,IfThen v p c1 c2) (alpha,l) (s',IfThen v p c1' c2'))
∧ (∀s c s' c' p1 v1 p2 v2 l alpha.
    trans (s,c) (alpha,l) (s',c')
    ∧ p1 ∉ freeprocs alpha
    ∧ p2 ∉ freeprocs alpha
    ⇒ trans (s,Com p1 v1 p2 v2 c) (alpha,l) (s',Com p1 v1 p2 v2 c'))
∧ (∀s c s' c' p1 b p2 l alpha.
    trans (s,c) (alpha,l) (s',c')
    ∧ p1 ∉ freeprocs alpha
    ∧ p2 ∉ freeprocs alpha
    ⇒ trans (s,Sel p1 b p2 c) (alpha,l) (s',Sel p1 b p2 c'))
∧ (∀s c s' c' p v f vl l alpha.
    trans (s,c) (alpha,l) (s',c')
    ∧ p ∉ freeprocs alpha
    ⇒ trans (s,Let v p f vl c) (alpha,l) (s',Let v p f vl c'))

  (* Asynchrony *)
∧ (∀s c s' c' p1 v1 p2 v2 l alpha.
    trans (s,c) (alpha,l) (s',c')
    ∧ p1 ∈ freeprocs alpha
    ∧ written alpha ≠ SOME (v1,p1)
    ∧ p2 ∉ freeprocs alpha
    ⇒ trans (s,Com p1 v1 p2 v2 c) (alpha,LCom p1 v1 p2 v2::l) (s',Com p1 v1 p2 v2 c'))

∧ (∀s c s' c' p1 b p2 l alpha.
    trans (s,c) (alpha,l) (s',c')
    ∧ p1 ∈ freeprocs alpha
    ∧ p2 ∉ freeprocs alpha
    ⇒ trans (s,Sel p1 b p2 c) (alpha,LSel p1 b p2::l) (s',Sel p1 b p2 c'))

`;

val _ = zip ["trans_com","trans_sel","trans_let","trans_if_true","trans_if_false",
              "trans_if_swap","trans_com_swap","trans_sel_swap","trans_let_swap",
              "trans_com_async","trans_sel_async"]
            (CONJUNCTS trans_rules) |> map save_thm;

val trans_pairind = save_thm("trans_pairind",
  theorem"trans_strongind"
  |> Q.SPEC `λa0 a1 a2. P (FST a0) (SND a0) (FST a1) (SND a1)  (FST a2) (SND a2)`
  |> SIMP_RULE std_ss [FORALL_PROD]
  |> Q.GEN `P`
);

(* valid_action ensures a transition tag `alpha` and an asyncronous
   transition tag `h` are related as described in the asyncronous
   transitions rules (trans_com_async and trans_sel_async).

   For this relation to hold `h` must:

   * Be one of LSel or LCom

   * Have its sender be a free process in `alpha`

   * Don't have as a receiver a free process in `alpha`
*)
val valid_action_def = Define`
  valid_action alpha h = ((∃p1 b p2 .
                           h = LSel p1 b p2
                           ∧ p1 ∈ freeprocs alpha
                           ∧ p2 ∉ freeprocs alpha) ∨
                          (∃p1 v1 p2 v2.
                            h = LCom p1 v1 p2 v2
                            ∧ p1 ∈ freeprocs alpha
                            ∧ p2 ∉ freeprocs alpha))
`;

(* Two list in a lcong relationship have the same length *)
val lcong_length = Q.store_thm("lcong_length",
  `∀l l'. l τ≅ l' ⇒ LENGTH l = LENGTH l'`,
  ho_match_mp_tac (theorem"lcong_strongind")
  \\ rw []
);

(* An empty list can't be in an lcong relationship with a non empty list *)
val not_nil_lcong_cons = Q.store_thm("not_nil_lcong_cons",
  `∀h l. ¬ ([] τ≅ h :: l)`,
  rw [] >> CCONTR_TAC  >> rw []
  \\ IMP_RES_TAC lcong_length
  \\ fs [LENGTH]
);

(* `lrm l e` removes the first appearance of element `e` in `l` *)
val lrm_def = Define `
  lrm [] e      = []
∧ lrm (x::ls) e = (if x = e
                 then ls
                 else x :: lrm ls e)
`;

(* If an element `e` is not in `l` then `lrm e l` is redundant *)
val mem_lrm_id = Q.store_thm("mem_lrm_id",
  `¬ MEM e l ⇒ lrm l e = l`,
  Induct_on `l` >> rw [lrm_def,MEM]
);

(* `lrm` conditionaly distributes over the first argument (`l`) of an
   append if the element you are trying to remove is in `l`
*)
val lrm_mem_append = Q.store_thm("lrm_mem_append",
  `∀l e r. MEM e l ⇒ lrm (l ++ r) e = lrm l e ++ r`,
  induct_on `l` >> rw [MEM,lrm_def]
);

(* `lrm` conditionaly distributes over the second argument (`r`) of an
   append if the element (`e`) you are trying to remove is not in the
   first argument (`l`). Note that this does not imply that `e` is in
   `r`
*)
val lrm_not_mem_append = Q.store_thm("lrm_not_mem_append",
  `∀l e r. ¬ MEM e l ⇒ lrm (l ++ r) e = l ++ lrm r e`,
  induct_on `l` >> rw [MEM,lrm_def]
);

(* Applying `lrm` at both sides of an lcong preserves the relation *)
val lcong_lrm = Q.store_thm("lcong_lrm",
  `∀e l l'. l τ≅ l' ⇒ lrm l e τ≅ lrm l' e`,
  GEN_TAC
  \\ ho_match_mp_tac (theorem"lcong_strongind")
  \\ rw [lcong_rules]
  \\ IMP_RES_TAC lcong_trans
  \\ Cases_on `MEM e (h ++ [t1; t2])`
  >- (`MEM e (h ++ [t2; t1])` by fs [MEM_PERM,PERM_APPEND_IFF,PERM_SWAP_AT_FRONT]
     \\ rw [lrm_mem_append]
     \\ Cases_on `MEM e h`
     \\ rw [lrm_mem_append,lcong_rules,lrm_not_mem_append]
     \\ rw [lrm_def,lcong_rules])
  >- (`¬MEM e (h ++ [t2; t1])` by fs [MEM_PERM,PERM_APPEND_IFF,PERM_SWAP_AT_FRONT]
     \\ rw [lrm_not_mem_append,lcong_rules])
);

(* [] can only be related in `lcong` with  (itself) [] *)
val lcong_nil_simp = Q.store_thm("lcong_nil_simp",
  `∀l. (l τ≅ [] ⇔ l = []) ∧ ([] τ≅ l ⇔ l = [])`,
  Cases_on `l`
  >- rw [lcong_rules]
  >- (fs [] >> metis_tac [not_nil_lcong_cons,lcong_refl])
);

(* Prepending and element (`h`) preserves `lcong` *)
val lcong_cons = Q.store_thm("lcong_cons",
  `∀h l l'. lcong l l' ⇒ lcong (h :: l) (h :: l')`,
  GEN_TAC
  \\ ho_match_mp_tac (fetch "-" "lcong_strongind")
  \\ rw [lcong_rules]
  \\ metis_tac [lcong_rules,GSYM APPEND |> CONJUNCT2]
);

(* Removing the identical heads preserves `lcong` *)
val cons_lcong = Q.store_thm("cons_lcong",
  `∀h l l'. h :: l τ≅ h :: l' ⇒ l τ≅ l'`,
  rw []
  \\ IMP_RES_TAC lcong_lrm
  \\ pop_assum (ASSUME_TAC o Q.SPEC `h`)
  \\ fs [lrm_def]
);

(* An slightly more specific case of `lcong_lrm` *)
val lcong_cons_simp = Q.store_thm("lcong_cons_simp",
  `∀h l h' l'. h ≠ h' ∧ h :: l τ≅ h' :: l'
    ⇒ l τ≅ h' :: lrm l' h`,
  rw []
  \\ IMP_RES_TAC lcong_lrm
  \\ pop_assum (ASSUME_TAC o Q.SPEC `h`)
  \\ rfs [lrm_def]
);

(* Any valid transition ensures the relationship between the
   transition tag `t` and the head of the asyncronous transitions list
   `h` is a valid_action
*)
val trans_valid_action = Q.store_thm("trans_valid_action",
  `∀s c s' c' t h l.
    trans (s,c) (t,h::l) (s',c')
    ⇒ valid_action t h`,
  rpt GEN_TAC
  \\ `∀s c t l' s' c'.
        trans (s,c) (t,l') (s',c')
        ⇒ l' = h::l
        ⇒ valid_action t h`
     suffices_by (metis_tac [])
  \\ ho_match_mp_tac trans_pairind
  \\ rw [trans_rules,valid_action_def]
);

(* Any valid trasition with a non-empty list of asyncronous trasitions
   implies there exist a transition with the same transition tag
   and the tail of the asyncronous transition list
*)
val trans_async_some_trans = Q.store_thm("trans_async_some_trans",
  `∀s c s' c' t h l.
    trans (s,c) (t,h::l) (s',c')
    ⇒ ∃s1 c1 s1' c1'. trans (s1,c1) (t,l) (s1',c1')`,
  rpt GEN_TAC
  \\ `∀s c t l' s' c'.
        trans (s,c) (t,l') (s',c')
        ⇒ l' = h::l
        ⇒ ∃s1 c1 s1' c1'. trans (s1,c1) (t,l) (s1',c1')`
     suffices_by (metis_tac [])
  \\ ho_match_mp_tac trans_pairind
  \\ rw [trans_rules,not_nil_lcong_cons]
  \\ metis_tac []
);

(* valid_actions over a list of actions *)
val valid_actions_def   = Define`
  valid_actions alpha l = EVERY (valid_action alpha) l
`;


(* Any valid transition ensures that both transition tag `t` and
   asyncronous transitions list `l` satisfies valid_actions
*)
val trans_valid_actions = Q.store_thm("trans_valid_actions",
  `∀s c s' c' t l.
    trans (s,c) (t,l) (s',c')
    ⇒ valid_actions t l`,
  Induct_on `l` >> rw []
  >- rw [valid_actions_def]
  \\ IMP_RES_TAC trans_valid_action
  \\ IMP_RES_TAC trans_async_some_trans
  \\ `valid_actions t l` by metis_tac []
  \\ fs [valid_actions_def]
);

(* In a list of valid actions (`h`) there are no LTau actions *)
val valid_actions_not_ltau = Q.store_thm("valid_actions_not_ltau",
  `∀t h p v. valid_actions t h ⇒ ¬ MEM (LTau p v) h`,
  rw []
  \\ CCONTR_TAC
  \\ fs [valid_actions_def,EVERY_MEM]
  \\ RES_TAC
  \\ fs [valid_action_def]
);

(* Reflexive transitive closure *)
val trans_s_def = Define`
  trans_s = RTC (λp q. ∃s. trans p s q)
`;

(* Give a state and a transition tag, one can generate the resulting state *)
val state_from_tag_def = Define`
  state_from_tag s (LCom p1 v1 p2 v2) = (s |+ ((v2,p2),s ' (v1,p1)))
∧ state_from_tag s (LLet v p f vl)  =
    (s |+ ((v,p),f (MAP (THE ∘ FLOOKUP s) (MAP (λv. (v,p)) vl))))
∧ state_from_tag s _ = s`


(* The resulting state of any transition can be described using `state_from_tag` *)
Theorem trans_state:
  ∀s c α τ s' c'. trans (s,c) (α,τ) (s',c') ⇒ s' = state_from_tag s α
Proof
  ho_match_mp_tac trans_pairind
  \\ rw [state_from_tag_def]
  \\ fs [FLOOKUP_DEF]
QED

(* Making the state bigger does not affect the behaviour of the choreography *)
Theorem trans_submap:
  ∀s c α τ s' c' z.
   trans (s,c) (α,τ) (s',c') ∧ s ⊑ z
   ⇒ ∃z'. trans (z,c) (α,τ) (z',c') ∧ s' ⊑ z'
Proof
  let
    val local_metis =
      metis_tac [trans_rules,FLOOKUP_SUBMAP,SUBMAP_mono_FUPDATE
                , SUBMAP_DOMSUB,GSYM SUBMAP_DOMSUB_gen
                , SUBMAP_TRANS]
  in
  `∀s c α τ s' c'.
   trans (s,c) (α,τ) (s',c')
   ⇒ ∀z. s ⊑ z
      ⇒ ∃z'. trans (z,c) (α,τ) (z',c') ∧ s' ⊑ z'`
  suffices_by metis_tac []
  \\ ho_match_mp_tac trans_pairind
  \\ rw []
  >- local_metis
  >- local_metis
  >- (`EVERY IS_SOME (MAP (FLOOKUP z) (MAP (λv. (v,p)) vl))`
      by (Induct_on `vl` \\ rw [FLOOKUP_DEF,IS_SOME_DEF]
         \\ rfs [SUBMAP_DEF])
      \\  qexists_tac `z |+ ((v,p),f (MAP (THE ∘ FLOOKUP z) (MAP (λv. (v,p)) vl)))`
      \\ qmatch_goalsub_abbrev_tac `s |+ sl ⊑ z |+ zl`
      \\ `sl = zl` suffices_by local_metis
      \\ unabbrev_all_tac \\ rw [] \\ AP_TERM_TAC
      \\ Induct_on `vl` \\ rw []
      \\ fs [IS_SOME_EXISTS,SUBMAP_DEF,FLOOKUP_SUBMAP,FLOOKUP_DEF])
  >- local_metis
  >- local_metis
  >- (res_tac
     \\ `z' = z''` by metis_tac [trans_state]
     \\ rveq \\ qexists_tac `z'` \\ local_metis)
  \\ local_metis
  end
QED

val RTC_TRANS =  RTC_RULES |> CONV_RULE FORALL_AND_CONV
                           |> CONJUNCTS |> el 2;

(* RTC version of `trans_submap` *)
Theorem trans_s_submap_gen:
  ∀s c α τ s' c' z.
   trans_s (s,c) (s',c') ∧ s ⊑ z
   ⇒ ∃z'. trans_s (z,c) (z',c') ∧ s' ⊑ z'
Proof
  `∀x y. trans_s x y
    ⇒ ∀s c s' c' z. x = (s,c) ∧ y = (s',c') ∧ s ⊑ z
       ⇒ ∃z'. trans_s (z,c) (z',c') ∧ s' ⊑ z'`
  suffices_by metis_tac []
  \\ rewrite_tac [trans_s_def]
  \\ ho_match_mp_tac RTC_INDUCT
  \\ rw []
  >- (qexists_tac `z` \\ rw [])
  \\ PairCases_on `x'` \\ Cases_on `s`
  \\ drule trans_submap
  \\ disch_then drule  \\ rw []
  \\ pop_assum drule   \\ rw []
  \\ qexists_tac `z''` \\ rw []
  \\ ho_match_mp_tac RTC_TRANS
  \\ metis_tac []
QED

(* Slightly more mp-friendly version of `trans_s_submap_gen` *)
Theorem trans_s_submap:
  ∀s c α τ s' c' z.
   trans_s (s,c) (s',c') ∧ s ⊑ z
   ⇒ ∃z'. trans_s (z,c) (z',c')
Proof
  metis_tac [trans_s_submap_gen]
QED

val free_variables_def = Define `
  (free_variables (Nil) = {}) /\
  (free_variables (IfThen v p c1 c2) = {(v,p)} ∪ (free_variables c1 ∪ free_variables c2)) /\
  (free_variables (Com p1 v1 p2 v2 c) = {(v1,p1)} ∪ (free_variables c DELETE (v2,p2))) /\
  (free_variables (Let v p f vl c) = set(MAP (λv. (v,p)) vl) ∪ (free_variables c DELETE (v,p))) /\
  (free_variables (Sel p b q c) = free_variables c)
`

val defined_vars_def = Define `
  defined_vars (s,c) = FDOM s`

val no_undefined_vars_def = Define `
  no_undefined_vars (s,c) = (free_variables c ⊆ FDOM s)`

Theorem defined_vars_mono:
  ∀sc alpha sc'. trans sc alpha sc' ⇒ defined_vars sc ⊆ defined_vars sc'
Proof
  ho_match_mp_tac trans_ind
  >> rpt strip_tac
  >> fs[defined_vars_def,SUBSET_OF_INSERT]
QED

Theorem free_vars_mono:
  ∀sc alpha sc'. trans sc alpha sc'
    ⇒ (free_variables(SND sc') DIFF defined_vars sc' ⊆ free_variables(SND sc) DIFF defined_vars sc)
Proof
  ho_match_mp_tac (theorem "trans_strongind")
  >> rpt strip_tac
  >> imp_res_tac defined_vars_mono
  >> fs[free_variables_def,defined_vars_def,DIFF_INSERT] >> rw[]
  >> fs[DELETE_DEF,DIFF_DEF,SUBSET_DEF] >> rpt strip_tac
  >> fs[] >> metis_tac[]
QED

Theorem no_undefined_vars_trans_pres:
  ∀sc alpha sc'. no_undefined_vars sc ∧ trans sc alpha sc' ⇒ no_undefined_vars sc'
Proof
  rpt gen_tac >> disch_then(MAP_EVERY assume_tac o CONJUNCTS)
  >> qpat_x_assum `no_undefined_vars _` mp_tac
  >> qpat_x_assum `trans _ _ _` mp_tac
  >> MAP_EVERY (W(curry Q.SPEC_TAC)) (rev [`sc`,`alpha`,`sc'`])
  >> ho_match_mp_tac (theorem "trans_strongind")
  >> rpt strip_tac
  >> imp_res_tac defined_vars_mono
  >> imp_res_tac free_vars_mono
  >> fs[no_undefined_vars_def,free_variables_def,DELETE_SUBSET_INSERT,defined_vars_def,SUBSET_OF_INSERT]
  >> fs[SUBSET_DEF,INSERT_DEF,DIFF_DEF] >> metis_tac[]
QED

val no_self_comunication_def = Define `
  no_self_comunication (Com p _ q _ c)   = (p ≠ q ∧ no_self_comunication c)
∧ no_self_comunication (Sel p _ q c)     = (p ≠ q ∧ no_self_comunication c)
∧ no_self_comunication (IfThen _ _ c c') = (no_self_comunication c ∧
                                            no_self_comunication c')

∧ no_self_comunication (Let _ _ _ _ c)   = no_self_comunication c
∧ no_self_comunication _                 = T
`
val _ = export_theory ()
