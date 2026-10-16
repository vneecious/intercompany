*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Change ID      : V001                                                *
* Date           : 02.07.2026                                          *
* Description    : Reintegro Gastos - Motor de Calculo IC - F0 Fundaciones y DDIC *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* F2 delta note (06.07.2026): same OT/Solman as F0 -> Change ID V001
* reused (no new header block). Adds the 2 types the F2 blueprint
* specifies (SS A.3/SS F: ty_tax_type_t, ty_consistency_result) plus one
* Developer-added type (ty_me_metric) required to close a real
* implementation gap in step_pc_split — see code-summary.md "Desviaciones
* del Blueprint" for the justification; not a silent invention, the
* pipeline literally cannot compile/execute step_pc_split without it.
* Iteration #2 (07.07.2026, amendment F2-DD-6): ty_ct_identity added —
* Architect-ratified resolution of the ct_uuid/mat_uuid -> ct_id/matnr
* identity gap escalated in Iteration #1 (blueprint SS6.2/SS9.3).
* Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-08 — added
* ty_bukrs_t (method signatures cannot build an inline 'STANDARD TABLE
* OF ...' type, same reason as ty_me_item_t/ty_tx_rule_t above), backs
* get_cm_recv_filter() on ZIF_REING_CA_SOURCES.
* Change ID V005 (05.08.2026 | EXT_GONZALCA): Delta v2 CA-11 — removed
* ty_me_metric (backed only get_me_metric(), retired as dead code, no
* other consumer). Delta v2 CON-08 — added ty_an2_regen_result, backs
* ZCL_REING_CA_AN2_REGENERATOR=>regenerate().
* Change ID V006 (07.09.2026 | EXT_GONZALCA): fix CT_CURRENCY vacio en el
* Path B1 del pipeline - agregado WAERS a ty_ct_identity (moneda de la
* cabecera ZREING_CT2_A, autoritativa; ZREING_CT2_OPT_A-WAERS esta
* deprecado y vacio en contratos reales).
*----------------------------------------------------------------------*
"Begin Insert V001 (CC)
INTERFACE zif_reing_ca_types PUBLIC.

  " Table types over the F0 tables
  " DD-8 (Iteration #4): ZREING_CA_LINE_PC_A renamed to ZREING_CA_LPC_A
  " (19 chars exceeded the 16-char limit for transparent tables). The
  " alias ty_line_pc_t keeps its name (internal to the interface, no
  " length limit) — only its TYPE target changes.
  TYPES: ty_line_t    TYPE STANDARD TABLE OF zreing_ca_line_a    WITH EMPTY KEY,
         ty_line_pc_t TYPE STANDARD TABLE OF zreing_ca_lpc_a     WITH EMPTY KEY,
         ty_step_t    TYPE STANDARD TABLE OF zreing_ca_step_a    WITH EMPTY KEY,
         ty_log_t     TYPE STANDARD TABLE OF zreing_ca_log_a     WITH EMPTY KEY.

  " Table types over external tables consumed by ZIF_REING_CA_SOURCES (DD-2):
  " method signatures cannot build an inline 'STANDARD TABLE OF ...' type, so
  " these named types live here (the canonical home for the project types).
  TYPES: ty_me_item_t TYPE STANDARD TABLE OF zreing_me_i_a   WITH EMPTY KEY,
         ty_tx_rule_t TYPE STANDARD TABLE OF zreing_tx_rule_a WITH EMPTY KEY.

  " Pipeline execution context
  TYPES: BEGIN OF ty_context,
           calc_run_id TYPE zreing_ca_run_a-calc_run_id,
           period      TYPE zreing_ca_run_a-fiscal_period,
           year        TYPE zreing_ca_run_a-fiscal_year,
         END OF ty_context.

  " Pipeline result (execute())
  TYPES: BEGIN OF ty_pipeline_result,
           lines   TYPE ty_line_t,
           line_pc TYPE ty_line_pc_t,
           steps   TYPE ty_step_t,
           errors  TYPE ty_log_t,
         END OF ty_pipeline_result.

  " Mass RAP action scope (ZS_CA_ActionScope, ET 6.1)
  TYPES: BEGIN OF ty_group_key,
           calc_run_id TYPE zreing_ca_line_a-calc_run_id,
           ct_uuid     TYPE zreing_ca_line_a-ct_uuid,
           mat_uuid    TYPE zreing_ca_line_a-mat_uuid,
           op_type     TYPE zreing_ca_line_a-op_type,
           op_uuid     TYPE zreing_ca_line_a-op_uuid,
           cm_h_id     TYPE zreing_ca_line_a-cm_h_id,
         END OF ty_group_key,
         ty_group_key_t TYPE STANDARD TABLE OF ty_group_key WITH EMPTY KEY.

  TYPES: BEGIN OF ty_action_scope,
           groups TYPE ty_group_key_t,
         END OF ty_action_scope.

  " CONTAB dispatcher result (TY_CONTAB_RESULT, ET 7.12)
  TYPES: BEGIN OF ty_contab_result,
           success        TYPE abap_bool,
           message        TYPE c LENGTH 255,
           accounting_doc TYPE zreing_cm_h_a-accounting_doc,   " char20 verified
         END OF ty_contab_result.

  "Begin Insert V001 (CC)
  " F2 SS A.3: pre-filter for TX-02 (ZCL_REING_CA_SOURCES~get_gl_tax_types).
  TYPES: ty_tax_type_t TYPE STANDARD TABLE OF zreing_tx_type_c-tax_type WITH EMPTY KEY.

  " F2 SS F: ZCL_REING_CA_INSUMO_MGR~check_consistency result (v42 SS2.12).
  TYPES: BEGIN OF ty_consistency_result,
           is_orphan         TYPE abap_bool,
           is_stale          TYPE abap_bool,
           added_receptors   TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY,
           removed_receptors TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY,
           " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-10
           " -- distingue si la causa de IS_STALE es un delta de CM_H_A
           " pendiente de recalcular (BR-CA-41), en vez del mensaje generico.
           delta_pending     TYPE abap_bool,
           " End Change ID V003 (04.08.2026 | EXT_GONZALCA)
         END OF ty_consistency_result.
  "End Insert V001 (CC)

  "Begin Insert V001 (CC)
  " F2 — amendment F2-DD-6 (blueprint SS6.2/SS9.3): bridge ct_uuid/mat_uuid
  " -> contract business keys, needed by step_01_validate Path A
  " (CM_LOADABLE), which builds the generic line from scratch with no
  " prior LINE_A to copy these fields from. Backs the new
  " get_ct_identity() on ZIF_REING_CA_SOURCES.
  TYPES: BEGIN OF ty_ct_identity,
           ct_id       TYPE zreing_ct2_a-ct_id,
           lifnr       TYPE zreing_ct2_a-lifnr,
           bukrs_prest TYPE zreing_ct2_a-bukrs,
           matnr       TYPE zreing_ct2_mat_a-matnr,
           " Begin Insert V006 (07.09.2026 | EXT_GONZALCA)
           " Contract header currency (ZREING_CT2_A-WAERS): the authoritative
           " contract currency. ZREING_CT2_OPT_A-WAERS (option level) is
           " deprecated, empty in real contracts and not maintainable from the
           " contracts UI, so step_validate can no longer use it as the
           " CT_CURRENCY fallback.
           " MUST stay the LAST component: get_ct_identity reads an explicit
           " column list INTO a flat structure, i.e. positional assignment -
           " column order must mirror component order.
           waers       TYPE zreing_ct2_a-waers,
           " End Insert V006 (07.09.2026 | EXT_GONZALCA)
         END OF ty_ct_identity.
  "End Insert V001 (CC)

  "Begin Insert V002 (03.08.2026 | EXT_GONZALCA)
  " Delta v2 CA-08: lista simple de bukrs (BR-CA-44, receptoras
  " participantes desde ZREING_CM_RECV_A). Backs get_cm_recv_filter() on
  " ZIF_REING_CA_SOURCES.
  TYPES: ty_bukrs_t TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY.
  "End Insert V002 (03.08.2026 | EXT_GONZALCA)

  "Begin Insert V005 (05.08.2026 | EXT_GONZALCA)
  " Delta v2 CON-08: resultado de ZCL_REING_CA_AN2_REGENERATOR=>regenerate()
  " -- contrato CONTAB->CA (direccion inversa a ZIF_REING_CONTAB_DISPATCHER)
  " para que ZCL_REING_CONTAB_EVT_POSTED regenere el AN2 al contabilizar su
  " ANT padre. Sin RAISING en el metodo que lo devuelve (mismo estilo que
  " ty_contab_result): errores de negocio se reportan en success/message.
  TYPES: BEGIN OF ty_an2_regen_result,
           success     TYPE abap_bool,
           message     TYPE c LENGTH 255,
           calc_run_id TYPE zreing_ca_run_a-calc_run_id,
           line_num    TYPE zreing_ca_line_a-line_num,
         END OF ty_an2_regen_result.
  "End Insert V005 (05.08.2026 | EXT_GONZALCA)

  " V001 (CC) - Shared local FX contract and standard API representation.
  TYPES ty_local_fx_amount TYPE decfloat34.
  TYPES ty_local_fx_multiplier TYPE decfloat34.
  TYPES ty_local_fx_status TYPE c LENGTH 12.
  TYPES ty_local_fx_policy TYPE c LENGTH 16.
  " The released ANY boundary requires an explicit packed layout.
  TYPES ty_fx_api_amount TYPE p LENGTH 16 DECIMALS 8.
  TYPES: BEGIN OF ty_local_fx_result,
           available         TYPE abap_bool,
           amount_local      TYPE ty_local_fx_amount,
           multiplier        TYPE ty_local_fx_multiplier,
           rate_type         TYPE kurst_curr,
           derived_rate_type TYPE kurst_curr,
           policy_source     TYPE ty_local_fx_policy,
           status_code       TYPE ty_local_fx_status,
           message           TYPE string,
         END OF ty_local_fx_result.

  " V001 (CC) - Shared nominal transaction-currency projection contract.
  TYPES ty_trans_state TYPE c LENGTH 12.
  TYPES: BEGIN OF ty_currency_precision,
           currency TYPE waers,
           decimals TYPE i,
         END OF ty_currency_precision,
         tt_currency_precision TYPE HASHED TABLE OF ty_currency_precision
           WITH UNIQUE KEY currency.
  TYPES: BEGIN OF ty_trans_state_result,
           state TYPE ty_trans_state,
           is_v2 TYPE abap_bool,
           local_available TYPE abap_bool,
         END OF ty_trans_state_result.
  TYPES BEGIN OF ty_trans_pc.
  INCLUDE TYPE zreing_ca_lpc_a.
  TYPES calc_trans_amt TYPE zreing_ca_calc_amt.
  TYPES END OF ty_trans_pc.
  TYPES tt_trans_pc TYPE SORTED TABLE OF ty_trans_pc
    WITH UNIQUE KEY calc_run_id line_num pc_seq.
  TYPES: BEGIN OF ty_trans_projection,
           line TYPE zreing_ca_line_a,
           line_pc TYPE tt_trans_pc,
           steps TYPE ty_step_t,
           calc_trans_amt TYPE zreing_ca_calc_amt,
           bruto_trans_amt TYPE zreing_ca_bruto_amt,
           use_trans TYPE abap_bool,
           local_available TYPE abap_bool,
           local_message TYPE string,
         END OF ty_trans_projection.

  " V001 (CC) - TVARVC selection values stay untruncated at the released boundary.
  TYPES: BEGIN OF ty_eba_bypass_entry,
           sign TYPE c LENGTH 1,
           opti TYPE c LENGTH 2,
           low TYPE string,
           high TYPE string,
         END OF ty_eba_bypass_entry,
         tt_eba_bypass_entries TYPE STANDARD TABLE OF ty_eba_bypass_entry WITH EMPTY KEY.

ENDINTERFACE.
"End Insert V001 (CC)
