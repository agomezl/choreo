open preamble choreoUtilsTheory
     projectionTheory endpointPropsTheory

open chorSemTheory endpointLangTheory

open chor_to_endpointTheory
     endpoint_to_choiceTheory
     endpoint_to_payloadTheory
open chor_to_endpointProofTheory
     endpoint_to_choiceProofTheory
     endpoint_to_payloadProofTheory

val _ = new_theory "projectionProof";

val to_choice_preservation =
  endpoint_to_choiceProofTheory.compile_network_preservation;

val to_endpoint_preservation =
  chor_to_endpointProofTheory.compile_network_preservation;

val to_payload_preservation =
  endpoint_to_payloadProofTheory.compile_network_preservation;

Theorem endpoints_compile_network:
  ∀s c l. MAP FST (endpointProps$endpoints (compile_network s (c : chor) l)) = l
Proof
  rw [] \\ Induct_on ‘l’
  \\ rw [endpoints_def,compile_network_gen_def]
QED


Theorem gen_fresh_name_same:
  ∀l. ¬MEM (gen_fresh_name l) l
Proof
  Cases >- fs[gen_fresh_name_def] >>
  rename1 `s::l` >>
  simp[] >>
  `STRLEN s < STRLEN(gen_fresh_name (s::l))`
    by(simp[gen_fresh_name_def] >>
       qid_spec_tac `s` >>
       Induct_on `l` >> rw[] >>
       first_x_assum(qspec_then `s` mp_tac) >> intLib.COOPER_TAC) >>
  conj_tac >- (spose_not_then strip_assume_tac >> fs[]) >>
  pop_assum kall_tac >>
  `!s'. MEM s' l ==> STRLEN s' < STRLEN(gen_fresh_name (s::l))`
    by(simp[gen_fresh_name_def] >>
       qid_spec_tac `s` >>
       Induct_on `l` >> rw[] >> rw[] >>
       res_tac >>
       first_x_assum(qspec_then `s` mp_tac) >> intLib.COOPER_TAC) >>
  spose_not_then strip_assume_tac >> res_tac >>
  fs[]
QED

Theorem choice_free_network_compile_network_fv:
  ∀epn fv. choice_free_network (compile_network_fv fv epn)
Proof
  Induct \\ rw [choice_free_network_def,compile_network_fv_def]
  \\ Induct_on ‘e’ \\ rw [choice_free_endpoint_def,
                          endpoint_to_choiceTheory.compile_endpoint_def]
QED

Theorem projection_preservation:
  ∀s c s'' c'' conf.
   compile_network_ok s c (procsOf c)
   ∧ conf.payload_size > 0
   ∧ trans_s (s,c) (s'',c'')
   ∧ no_undefined_vars (s,c)
   ∧ no_self_comunication c
   ⇒ ∃s''' c''' epn.
      trans_s (s'',c'') (s''',c''') ∧
      junkcong {new_fv s c}
               (project_choice (new_fv s c) s''' c''' (procsOf c))
               epn ∧
      (reduction conf)^* (projection conf s c (procsOf c))
                         (compile_network conf epn)
Proof
  rw []
  \\ drule to_endpoint_preservation
  \\ rpt (disch_then drule)
  \\ strip_tac \\ rveq \\ fs []
  \\ asm_exists_tac \\ rw []
  \\ first_x_assum (mp_then Any mp_tac to_choice_preservation)
  \\ qmatch_goalsub_abbrev_tac ‘endpoints to_epn’
  \\ qmatch_goalsub_abbrev_tac ‘junkcong {fv}’
  \\ disch_then (qspec_then ‘fv’ mp_tac)
  \\ impl_tac \\ rw []
  >- rw [Abbr‘to_epn’, endpoints_compile_network,procsOf_all_distinct]
  >- rw [Abbr‘fv’,gen_fresh_name_same]
  \\ fs [projection_def,endpoint_to_choiceTheory.compile_network_def]
  \\ drule_then assume_tac junkcong_sym \\  asm_exists_tac
  \\ fs [projection_def,endpoint_to_choiceTheory.compile_network_def]
  \\ qmatch_goalsub_abbrev_tac ‘compile_network conf to_choice’
  \\ irule to_payload_preservation
  \\ fs [Abbr‘to_choice’]
  \\ rw [choice_free_network_compile_network_fv]
QED

val _ = export_theory ()
