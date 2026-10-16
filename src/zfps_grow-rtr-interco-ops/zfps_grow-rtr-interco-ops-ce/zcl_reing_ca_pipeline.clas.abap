*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Linear orchestrator (blueprint SS6.11, normalized-spec.md SS E). Order
* is 01 (validate+load BASE_AMT on the generic group line) -> 02 (expand
* per receptor, CALC_AMT) -> 03/04/05 (per expanded line). TRY/CATCH of
* zcx_reing_ca_calc_error wraps each group, never the whole LOOP (P-07) —
* a failing group is marked CALC_ERR and the scope keeps going. No
* COMMIT WORK, no DB writes — returns ty_pipeline_result in memory, so
* it is 100% testable with ZIF_REING_CA_SOURCES mocked.
*
* Two small additions beyond the blueprint's exact method list, both
* documented in code-summary.md "Desviaciones del Blueprint":
*  - mt_validate_step (private attribute): step_01_validate's own
*    signature (blueprint SS6.11) has no ct_steps parameter, yet it must
*    record a temporary VALIDATE STEP_A for step_02_distribute to later
*    replicate (SS E.3/E.4/E.9) — this attribute is the only way to pass
*    that single row across the two calls without changing either
*    method's public signature.
*  - last_day_of_period (private helper): shared by step_03_gross_up (TX
*    rule validity reference date) and step_05_fx (FX type P, past
*    period) — same "last day of the calculation period" computation the
*    spec assumes for both (SS D.1 point 5 note / SS E.7), factored once.
*
* Iteration #2 (07.07.2026, amendment F2-DD-6, blueprint SS6.11/SS9.3):
* step_01_validate's Path B1 (CM_LOADABLE) now calls
* mo_sources->get_ct_identity(...) to resolve CT_ID/LIFNR/BUKRS_PREST/
* MATNR — closes the identity gap escalated in Iteration #1 (previously
* left blank with a DEVELOPER GAP-FIX comment). step_02_distribute's T001
* lookup (Iteration #1, currency only) now also resolves COUNTRY in the
* same SELECT — ratified, not a new gap (COUNTRY is per-receptor, only
* known after expansion, so it was never part of the identity gap).
*
* Iteration #5 (07.07.2026, real activation ERR-002 + F2-DD-11): first
* real contact with the SAP compiler surfaced 9 issues, none detectable
* by code/blueprint review — round_to_currency migrated TCURX to CDS
* I_CURRENCY (Clean Core, F2-DD-11); step_01_validate's B2 SELECT was
* missing MANDT (positional mismatch); step_02_distribute/step_pc_split's
* COLLECT on CHAR-keyed tables replaced with manual find-or-append
* aggregation; replicate_steps' call needed an explicit EXPORTING
* keyword; 3 CURR/DEC type-compatibility mismatches (step_04_tax x2,
* step_05_fx x1) fixed with explicit CONV. See code-summary.md for the
* full list with SAP's exact messages.
*
* Iteration #7 (07.07.2026, Reviewer's own dry-run, OB-004/OB-005): the
* T001 lookup in step_02_distribute (D-6/F2-DD-6) was ALSO blocked by
* Clean Core, same as TCURX — migrated to the released CDS I_CompanyCode
* (CompanyCode/Country/Currency). step_04_tax's IV_SOURCE_KEY had one
* more CURR/DEC-style type mismatch (TAX_TYPE vs. char100) fixed with
* explicit CONV, same pattern as Iteration #5's M-08/M-09/M-10.
* Change ID V002/V003 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-09 --
* renombrados sin prefijo numerico (step_01_validate->step_validate,
* step_02_distribute->step_distribute, step_03_gross_up->step_gross_up,
* step_04_tax->step_tax, step_05_fx->step_fx); step_delta (CA-06) ya
* conectado en execute() entre step_distribute y step_gross_up.
* Change ID V005 (07.09.2026 | EXT_GONZALCA): CT_CURRENCY del Path B1 pasa a
* resolverse desde la cabecera del contrato (ty_ct_identity-WAERS, V006 de
* ZIF_REING_CA_TYPES) en vez del deprecado ZREING_CT2_OPT_A-WAERS, mas
* validacion explicita de CT_CURRENCY en step_validate y de ambas monedas en
* step_fx (cierra el atajo silencioso '' = '' -> EXCH_RATE = 1).
* Deuda transitoria (DD-04): get_ct_option( )-waers se conserva como
* SEGUNDO eslabon del fallback solo para no tocar el include testclasses,
* bloqueado en este pase - retirar cuando se libere el lock.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_pipeline DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " V001 (CC) - AN2 APJ: opt-in physical seed selection.
    TYPES: BEGIN OF ty_pending_key,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
           END OF ty_pending_key,
           tt_pending_key TYPE STANDARD TABLE OF ty_pending_key WITH EMPTY KEY.

    METHODS constructor
      IMPORTING is_context       TYPE zif_reing_ca_types=>ty_context
                io_sources       TYPE REF TO zif_reing_ca_sources
                io_local_fx      TYPE REF TO zif_reing_ca_local_fx OPTIONAL.

    METHODS execute
      IMPORTING it_scope         TYPE zif_reing_ca_types=>ty_group_key_t
                it_pending_keys  TYPE tt_pending_key OPTIONAL
      RETURNING VALUE(rs_result) TYPE zif_reing_ca_types=>ty_pipeline_result.

    " ATC fix (test isolation): permite inyectar mt_tx_type_cache desde el test
    " sin pasar por el OSQL test double (que tiene bug con CHAR comparisons).
    " Solo para uso en tests -- no usar en produccion.
    METHODS inject_tx_cache
      IMPORTING it_cache TYPE ANY TABLE.

  PRIVATE SECTION.
    " V001 (CC) - Ordinal memory index; existing STEP table type stays unchanged.
    TYPES: BEGIN OF ty_trans_step_index,
             calc_run_id TYPE zreing_ca_step_a-calc_run_id,
             line_num TYPE zreing_ca_step_a-line_num,
             table_index TYPE i,
           END OF ty_trans_step_index,
           tt_trans_step_index TYPE SORTED TABLE OF ty_trans_step_index
             WITH UNIQUE KEY calc_run_id line_num table_index.
    DATA mv_removed_fx_steps TYPE i.
    DATA mt_trans_currencies TYPE zif_reing_ca_types=>tt_currency_precision.
    METHODS index_trans_steps
      IMPORTING it_steps TYPE zif_reing_ca_types=>ty_step_t
      RETURNING VALUE(rt_index) TYPE tt_trans_step_index.
    METHODS propagate_trans
      IMPORTING iv_new_from TYPE i
      CHANGING cs_line TYPE zreing_ca_line_a
               ct_pc TYPE zif_reing_ca_types=>ty_line_pc_t
               ct_steps TYPE zif_reing_ca_types=>ty_step_t
               ct_index TYPE tt_trans_step_index
      RAISING zcx_reing_ca_calc_error.

    " V001 (CC) - AN2 APJ: memory-only validation; no shared type change.
    METHODS check_pending_input
      IMPORTING it_scope         TYPE zif_reing_ca_types=>ty_group_key_t
                it_pending_keys  TYPE tt_pending_key
      RETURNING VALUE(rv_message) TYPE zreing_ca_log_a-message.

    METHODS restrict_pending_scope
      IMPORTING it_scope        TYPE zif_reing_ca_types=>ty_group_key_t
                it_pending_keys TYPE tt_pending_key
                it_pending      TYPE zif_reing_ca_types=>ty_line_t
      EXPORTING et_selected     TYPE zif_reing_ca_types=>ty_line_t
                ev_message      TYPE zreing_ca_log_a-message.

    " ATC fix (NonLocal DBREAD via step_fx path H y step_validate path B2):
    " tipo para pre-fetch de exch_rate Y line_status de lineas padre.
    TYPES: BEGIN OF ty_parent_fx,
             origin_run_id   TYPE zreing_ca_line_a-calc_run_id,
             origin_line_num TYPE zreing_ca_line_a-line_num,
             exch_rate       TYPE zreing_ca_line_a-exch_rate,
             line_status     TYPE zreing_ca_line_a-line_status,
             exch_rate_1 TYPE zreing_ca_line_a-exch_rate_1,
             exch_rate_1_type TYPE zreing_ca_line_a-exch_rate_1_type,
             ct_currency TYPE waers,
             trans_currency TYPE waers,
           END OF ty_parent_fx,
           tt_parent_fx TYPE STANDARD TABLE OF ty_parent_fx WITH EMPTY KEY.

    TYPES: BEGIN OF ty_currency_cache,
             currency TYPE waers,
             decimals TYPE i,
           END OF ty_currency_cache.

    TYPES: BEGIN OF ty_tx_type_cache,
             tax_type         TYPE zreing_tx_type_c-tax_type,
             gross_up_default TYPE zreing_tx_type_c-gross_up_default,
           END OF ty_tx_type_cache,
           tt_tx_type_cache TYPE STANDARD TABLE OF ty_tx_type_cache WITH EMPTY KEY.

    " ATC fix: tipos propios para reemplazar data elements deprecados (CHAR1/CHAR30/CHAR100/DATS).
    TYPES: ty_sign         TYPE c LENGTH 1,
           ty_source_table TYPE c LENGTH 30,
           ty_source_key   TYPE c LENGTH 100,
           ty_date         TYPE d.

    " ATC fix (NonLocal DBREAD via step_distribute): cache de I_CompanyCode
    " pre-cargado en execute() antes del LOOP AT it_scope para todos los receptores
    " del scope. step_distribute lo usa directamente sin hacer SELECT.
    TYPES: BEGIN OF ty_bukrs_cache,
             bukrs    TYPE bukrs,
             country  TYPE land1,
             currency TYPE waers,
           END OF ty_bukrs_cache.

    " V001 (CC) - CA-05 (EBA Brasil): FX candidates and explicit fallback.
    TYPES tt_fx_rules TYPE STANDARD TABLE OF zreing_fx_rule_a WITH EMPTY KEY.
    TYPES: BEGIN OF ty_fx_rule_result,
             rule        TYPE zreing_fx_rule_a,
             is_fallback TYPE abap_bool,
           END OF ty_fx_rule_result.

    " V001 (CC) - CA-06: execution-scoped FX caches and injectable policy.
    TYPES tt_fx_options TYPE HASHED TABLE OF zreing_ct2_opt_a
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid op_instance_num.
    TYPES tt_manual_fx TYPE HASHED TABLE OF zreing_ct_o_r_a
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid op_instance_num bukrs_recv.
    TYPES: BEGIN OF ty_primary_quote,
             from_currency TYPE waers,
             to_currency TYPE waers,
             quote_date TYPE d,
             multiplier TYPE zreing_ca_line_a-exch_rate_1,
           END OF ty_primary_quote,
           tt_primary_quotes TYPE HASHED TABLE OF ty_primary_quote
             WITH UNIQUE KEY from_currency to_currency quote_date.
    TYPES: BEGIN OF ty_local_quote,
             company_code TYPE bukrs,
             from_currency TYPE waers,
             to_currency TYPE waers,
             quote_date TYPE d,
             decimals_from TYPE i,
             decimals_to TYPE i,
             amount_trans TYPE decfloat34,
             result TYPE zif_reing_ca_local_fx=>ty_result,
           END OF ty_local_quote,
           tt_local_quotes TYPE HASHED TABLE OF ty_local_quote
             WITH UNIQUE KEY company_code from_currency to_currency quote_date
               decimals_from decimals_to amount_trans.
    DATA mo_local_fx TYPE REF TO zif_reing_ca_local_fx.
    DATA mt_fx_options TYPE tt_fx_options.
    DATA mt_manual_fx TYPE tt_manual_fx.
    DATA mt_primary_quotes TYPE tt_primary_quotes.
    DATA mt_local_quotes TYPE tt_local_quotes.
    METHODS preload_v2_fx
      IMPORTING it_scope TYPE zif_reing_ca_types=>ty_group_key_t.
    METHODS fx_currency_decimals
      IMPORTING iv_currency TYPE waers
      RETURNING VALUE(rv_decimals) TYPE i
      RAISING zcx_reing_ca_calc_error.
    METHODS fx_canonical_rate
      IMPORTING iv_rate TYPE decfloat34
      RETURNING VALUE(rv_rate) TYPE zreing_ca_line_a-exch_rate_1
      RAISING zcx_reing_ca_calc_error.
    METHODS fx_nominal_amount
      IMPORTING iv_amount TYPE decfloat34
                iv_rate TYPE decfloat34
                iv_currency TYPE waers
      RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-net_trans_amt
      RAISING zcx_reing_ca_calc_error.
    METHODS fx_period_date
      RETURNING VALUE(rv_date) TYPE d
      RAISING zcx_reing_ca_calc_error.
    METHODS fx_clean_warnings
      IMPORTING iv_message TYPE zreing_ca_line_a-sim_message
      RETURNING VALUE(rv_message) TYPE string.
    METHODS fx_add_warning
      IMPORTING iv_code TYPE string iv_message TYPE string
      CHANGING cv_message TYPE string.

    DATA mt_fx_rules TYPE tt_fx_rules.

    METHODS load_fx_rules
      IMPORTING iv_bukrs_prest TYPE zreing_fx_rule_a-bukrs_prest.

    METHODS find_fx_rule
      IMPORTING it_rules          TYPE tt_fx_rules
                iv_ct_currency    TYPE zreing_fx_rule_a-ct_currency
                iv_same_country   TYPE zreing_fx_rule_a-same_country
                iv_country_prest  TYPE zreing_fx_rule_a-country_prest
                iv_country_recv   TYPE zreing_fx_rule_a-country_recv
                iv_bukrs_prest    TYPE zreing_fx_rule_a-bukrs_prest
                iv_bukrs_recv     TYPE zreing_fx_rule_a-bukrs_recv
      RETURNING VALUE(rs_result) TYPE ty_fx_rule_result
      RAISING   zcx_reing_ca_calc_error.

    DATA: ms_context           TYPE zif_reing_ca_types=>ty_context,
          mo_sources           TYPE REF TO zif_reing_ca_sources,
          mo_tx_scoring        TYPE REF TO zcl_reing_ca_tx_scoring,
          mt_validate_step     TYPE zif_reing_ca_types=>ty_step_t,
          mt_currency_decimals TYPE HASHED TABLE OF ty_currency_cache
                               WITH UNIQUE KEY currency,
          mt_tx_type_cache     TYPE STANDARD TABLE OF ty_tx_type_cache WITH EMPTY KEY,
          mt_bukrs_cache       TYPE STANDARD TABLE OF ty_bukrs_cache WITH EMPTY KEY.

    " V001 (CC) - ISO-01: the test class alone may override compiled OFF.
    DATA mv_eba_off TYPE abap_bool.

    METHODS:
      step_pc_split
        IMPORTING is_line      TYPE zreing_ca_line_a
        RETURNING VALUE(rt_pc) TYPE zif_reing_ca_types=>ty_line_pc_t
        RAISING   zcx_reing_ca_calc_error,

      record_step
        IMPORTING iv_line_num     TYPE zreing_ca_line_a-line_num
                  iv_step_num     TYPE zreing_ca_step_a-step_num
                  iv_seq          TYPE zreing_ca_step_a-seq
                  iv_category     TYPE zreing_ca_step_category
                  iv_tax_type     TYPE zreing_ca_step_a-tax_type OPTIONAL
                  " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                  " Bug #78: ET SS4.4 declares TX_RULE_ID and RATE_DESC as
                  " columns of STEP_A, but the record_step signature of the
                  " SS7.3 pseudo-code omits both, so neither could ever be
                  " filled (0 of 629 rows on TS4-400). SS4.4 is normative and
                  " wins over the pseudo-code.
                  iv_tx_rule_id   TYPE zreing_ca_step_a-tx_rule_id OPTIONAL
                  iv_rate_desc    TYPE zreing_ca_step_a-rate_desc OPTIONAL
                  " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                  iv_desc         TYPE zreing_ca_step_a-step_desc OPTIONAL
                  iv_input        TYPE zreing_ca_line_a-base_amt
                  iv_input_curr   TYPE waers OPTIONAL
                  iv_rate         TYPE zreing_ca_step_a-rate_pct OPTIONAL
                  iv_output       TYPE zreing_ca_line_a-base_amt
                  iv_output_curr  TYPE waers OPTIONAL
                  iv_sign         TYPE ty_sign
                  iv_source_table TYPE ty_source_table OPTIONAL
                  iv_source_key   TYPE ty_source_key OPTIONAL
        CHANGING  ct_steps        TYPE zif_reing_ca_types=>ty_step_t,

      replicate_steps
        IMPORTING iv_from_line TYPE zreing_ca_line_a-line_num
                  iv_to_line   TYPE zreing_ca_line_a-line_num
        CHANGING  ct_steps     TYPE zif_reing_ca_types=>ty_step_t,

      last_day_of_period
        IMPORTING iv_fiscal_period TYPE zreing_ca_run_a-fiscal_period
                  iv_fiscal_year   TYPE zreing_ca_run_a-fiscal_year
        RETURNING VALUE(rv_date)   TYPE ty_date,

      round_to_currency
        IMPORTING iv_amount        TYPE zreing_ca_line_a-calc_amt
                  iv_currency      TYPE waers
        RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-calc_amt.

    METHODS step_delta
      CHANGING ct_lines TYPE zif_reing_ca_types=>ty_line_t
               ct_steps TYPE zif_reing_ca_types=>ty_step_t
      RAISING  zcx_reing_ca_calc_error.

    METHODS validate_defer_group
      IMPORTING is_group        TYPE zif_reing_ca_types=>ty_group_key
                it_pend_scope   TYPE zif_reing_ca_types=>ty_line_t
                it_parent_data  TYPE tt_parent_fx
      RETURNING VALUE(rt_lines) TYPE zif_reing_ca_types=>ty_line_t
      RAISING   zcx_reing_ca_calc_error.

    METHODS step_validate
      IMPORTING is_group       TYPE zif_reing_ca_types=>ty_group_key
                it_pend_scope  TYPE zif_reing_ca_types=>ty_line_t OPTIONAL
                it_parent_data TYPE tt_parent_fx OPTIONAL
      RETURNING VALUE(rs_line) TYPE zreing_ca_line_a
      RAISING   zcx_reing_ca_calc_error.

    METHODS step_distribute
      CHANGING ct_lines TYPE zif_reing_ca_types=>ty_line_t
               ct_steps TYPE zif_reing_ca_types=>ty_step_t
      RAISING  zcx_reing_ca_calc_error.

    METHODS step_gross_up
      CHANGING cs_line  TYPE zreing_ca_line_a
               ct_steps TYPE zif_reing_ca_types=>ty_step_t
      RAISING  zcx_reing_ca_calc_error.

    METHODS step_tax
      CHANGING cs_line  TYPE zreing_ca_line_a
               ct_steps TYPE zif_reing_ca_types=>ty_step_t
      RAISING  zcx_reing_ca_calc_error.

    METHODS step_fx
      IMPORTING it_parent_fx TYPE tt_parent_fx OPTIONAL
      CHANGING  cs_line      TYPE zreing_ca_line_a
                ct_steps     TYPE zif_reing_ca_types=>ty_step_t
      RAISING   zcx_reing_ca_calc_error.

    " V001 (CC) - ISO-01: preserve active FX and reserve the EBA path.
    METHODS step_fx_legacy
      IMPORTING it_parent_fx TYPE tt_parent_fx OPTIONAL
      CHANGING  cs_line      TYPE zreing_ca_line_a
                ct_steps     TYPE zif_reing_ca_types=>ty_step_t
      RAISING   zcx_reing_ca_calc_error.

    METHODS step_fx_v2
      IMPORTING it_parent_fx TYPE tt_parent_fx OPTIONAL
      CHANGING  cs_line      TYPE zreing_ca_line_a
                ct_steps     TYPE zif_reing_ca_types=>ty_step_t
      RAISING   zcx_reing_ca_calc_error.
METHODS resolve_me_period
      IMPORTING iv_op_uuid      TYPE zreing_ca_line_a-op_uuid
      EXPORTING ev_period_month TYPE zreing_me_h_a-period_month
                ev_period_year  TYPE zreing_me_h_a-period_year.
METHODS build_error_prefix
      IMPORTING is_line          TYPE zreing_ca_line_a
                iv_stage         TYPE string
      RETURNING VALUE(rv_prefix) TYPE string.

ENDCLASS.

CLASS zcl_reing_ca_pipeline IMPLEMENTATION.

  METHOD constructor.
    ms_context    = is_context.
    mo_sources    = io_sources.
    mo_local_fx   = io_local_fx.
    mo_tx_scoring = NEW zcl_reing_ca_tx_scoring( ).
    " V001 (CC) - Freeze the effective switch for this pipeline operation.
    TEST-SEAM eba_pipeline_switch.
      mv_eba_off = zcl_reing_ca_trans_amounts=>get_eba_off( ).
    END-TEST-SEAM.
  ENDMETHOD.

  METHOD inject_tx_cache.
    " ATC fix (test isolation): copia filas de la tabla generica al cache tipado.
    " Usa ASSIGN con campo-symbol generico para compatibilidad con ANY TABLE.
    FIELD-SYMBOLS <ls_row> TYPE data.
    DATA ls_entry TYPE ty_tx_type_cache.
    LOOP AT it_cache ASSIGNING <ls_row>.
      ASSIGN COMPONENT 'TAX_TYPE' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<tax_type>).
      IF sy-subrc = 0. ls_entry-tax_type = <tax_type>. ENDIF.
      ASSIGN COMPONENT 'GROSS_UP_DEFAULT' OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<gu>).
      IF sy-subrc = 0. ls_entry-gross_up_default = <gu>. ENDIF.
      APPEND ls_entry TO mt_tx_type_cache.
    ENDLOOP.
  ENDMETHOD.

METHOD execute.
    " V001 (CC) - AN2 APJ: omission preserves the existing execution path.
    DATA(lv_exact_pending) = xsdbool( it_pending_keys IS SUPPLIED ).
    DATA lv_pending_message TYPE zreing_ca_log_a-message.
    IF lv_exact_pending = abap_true.
      lv_pending_message = check_pending_input(
        it_scope = it_scope it_pending_keys = it_pending_keys ).
      IF lv_pending_message IS NOT INITIAL.
        rs_result-errors = VALUE #( ( calc_run_id = ms_context-calc_run_id
          action = zif_reing_ca_c=>action-calc
          status_to = zif_reing_ca_c=>line_status-calc_err
          message = lv_pending_message ) ).
        RETURN.
      ENDIF.
    ENDIF.
    " V001 (CC) - CA-05 (EBA Brasil): one CDS read before processing loops.
    CLEAR mt_fx_rules.
    IF mv_eba_off = abap_false AND it_scope IS NOT INITIAL.
      load_fx_rules( iv_bukrs_prest = zif_reing_ca_c=>br_isolation-eba_bukrs ).
    ENDIF.

    preload_v2_fx( it_scope ).

    " ATC fix (NonLocal DBREAD): pre-cargar mt_bukrs_cache con I_CompanyCode
    " antes del LOOP AT it_scope.
    IF mt_bukrs_cache IS INITIAL.
      SELECT companycode AS bukrs, country, currency
        FROM i_companycode
        WHERE companycode IS NOT INITIAL
        INTO CORRESPONDING FIELDS OF TABLE @mt_bukrs_cache.
    ENDIF.

    " ATC fix (NonLocal DBREAD via round_to_currency): pre-cargar mt_currency_decimals.
    IF mt_currency_decimals IS INITIAL.
      DATA lt_all_currencies TYPE STANDARD TABLE OF i_currency WITH EMPTY KEY.
      SELECT currency, decimals
        FROM i_currency
        WHERE currency IS NOT INITIAL
        INTO CORRESPONDING FIELDS OF TABLE @lt_all_currencies.
      LOOP AT lt_all_currencies INTO DATA(ls_curr_row).
        INSERT VALUE ty_currency_cache(
          currency = ls_curr_row-currency
          decimals = ls_curr_row-decimals ) INTO TABLE mt_currency_decimals.
      ENDLOOP.
    ENDIF.

    " V001 (CC) - Reuse the preloaded currency precision outside all line loops.
    CLEAR mt_trans_currencies.
    IF mv_eba_off = abap_false.
      mt_trans_currencies = CORRESPONDING #( mt_currency_decimals ).
    ENDIF.

    " ATC fix (NonLocal DBREAD via step_gross_up/step_tax): pre-cargar mt_tx_type_cache.
    " Sin WHERE active para evitar problemas con ABAP_BOOL en test doubles;
    " el filtro de activos se aplica en ABAP puro post-SELECT.
    IF mt_tx_type_cache IS INITIAL.
      DATA lt_tx_all TYPE STANDARD TABLE OF ty_tx_type_cache WITH EMPTY KEY.
      SELECT tax_type, gross_up_default
        FROM zreing_tx_type_c
        WHERE tax_type IS NOT INITIAL
        INTO CORRESPONDING FIELDS OF TABLE @lt_tx_all.
      DATA lt_tx_active TYPE STANDARD TABLE OF zreing_tx_type_c WITH EMPTY KEY.
      SELECT tax_type, active
        FROM zreing_tx_type_c
        WHERE tax_type IS NOT INITIAL
        INTO CORRESPONDING FIELDS OF TABLE @lt_tx_active.
      " Not nested inside another loop -- plain LOOP AT (was a DO/READ TABLE
      " INDEX walk over an un-ordered SELECT result, flagged by ATC).
      LOOP AT lt_tx_all INTO DATA(ls_tx_row).
        READ TABLE lt_tx_active INTO DATA(ls_tx_act) WITH KEY tax_type = ls_tx_row-tax_type.
        IF sy-subrc = 0 AND ls_tx_act-active = abap_true.
          APPEND ls_tx_row TO mt_tx_type_cache.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " ATC fix (NonLocal DBREAD via get_instance): warm_cache antes del LOOP AT it_scope.
    " Not nested inside another loop -- plain LOOP AT (was a DO/READ TABLE
    " INDEX walk over it_scope, flagged by ATC as if it depended on
    " SELECT ordering, which it doesn't: this only collects distinct op_types).
    DATA lt_scope_op_range TYPE zcl_reing_ca_optype_factory=>ty_op_type_rang.
    LOOP AT it_scope INTO DATA(ls_scope_grp).
      IF NOT line_exists( lt_scope_op_range[ low = ls_scope_grp-op_type ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_scope_grp-op_type )
          TO lt_scope_op_range.
      ENDIF.
    ENDLOOP.
    IF lt_scope_op_range IS NOT INITIAL.
      TRY.
          zcl_reing_ca_optype_factory=>warm_cache( lt_scope_op_range ).
        CATCH zcx_reing_ca_calc_error.
      ENDTRY.
    ENDIF.

    " V001 (CC) - AN2 APJ: reject every non-B2 strategy before calculation.
    IF lv_exact_pending = abap_true.
      TRY.
          LOOP AT it_scope INTO DATA(ls_exact_group).
            DATA(lo_exact_strategy) =
              zcl_reing_ca_optype_factory=>get_instance_from_cache(
                iv_op_type = ls_exact_group-op_type
                io_sources = mo_sources is_context = ms_context ).
            IF lo_exact_strategy->expand_mode(
                CORRESPONDING zreing_ca_line_a( ls_exact_group ) )
                <> zif_reing_ca_c=>row_type-defer_pending.
              lv_pending_message = 'Exact pending selection requires B2 only'.
              EXIT.
            ENDIF.
          ENDLOOP.
        CATCH cx_root INTO DATA(lx_pending_mode).
          lv_pending_message = lx_pending_mode->get_text( ).
      ENDTRY.
      IF lv_pending_message IS NOT INITIAL.
        rs_result-errors = VALUE #( ( calc_run_id = ms_context-calc_run_id
          action = zif_reing_ca_c=>action-calc
          status_to = zif_reing_ca_c=>line_status-calc_err
          message = lv_pending_message ) ).
        RETURN.
      ENDIF.
    ENDIF.

    " V001 (CC) — Devengo: precargar la semilla B2 tanto cuando llega PEND
    " (regenerador) como cuando Calculate ya la promovio a CALC_PROC.
    " step_validate usa READ TABLE
    " en lugar de SELECT SINGLE * (CERO SELECT dentro del LOOP AT it_scope).
    " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-07 -- quitado
    " HAS_PC_BREAKDOWN de la lista explicita (columna retirada de ZREING_CA_LINE_A
    " por CA-02; step_pc_split ya no es condicional).
    DATA lt_pend_scope TYPE zif_reing_ca_types=>ty_line_t.
    IF it_scope IS NOT INITIAL.
      SELECT mandt, calc_run_id, line_num, ct_uuid, ct_id, lifnr, bp_name,
             bukrs_prest, mat_uuid, matnr, op_type, op_uuid, cm_h_id, cm_load_seq,
             op_instance_num,
             parent_op_type, origin_run_id, origin_line_num,
             parent_net_amt, parent_currency, defer_pct, defer_cuota_num,
             defer_cuota_total, defer_from, defer_to, bukrs_recv, country,
             base_amt, share_pct, share_pais_pct, share_comb_pct,
             calc_amt, bruto_amt, gross_up_amt, tax_amt, net_amt,
             ct_currency, net_local_amt, local_currency, exch_rate,
             exch_rate_type, line_status, sim_message,
             trans_currency, net_trans_amt, exch_rate_1, exch_rate_1_type,
             proc_started_at, proc_heartbeat_at, proc_job_id,
             insumo_check_at, fi_awkey, local_last_changed_at
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @it_scope
        WHERE calc_run_id = @ms_context-calc_run_id
          AND ct_uuid     = @it_scope-ct_uuid
          AND mat_uuid    = @it_scope-mat_uuid
          AND op_type     = @it_scope-op_type
          AND op_uuid     = @it_scope-op_uuid
          AND cm_h_id     = @it_scope-cm_h_id
          AND ( line_status = 'PEND' OR line_status = 'CALC_PROC' )
        INTO CORRESPONDING FIELDS OF TABLE @lt_pend_scope.
    ENDIF.
    " End Change ID V002 (03.08.2026 | EXT_GONZALCA)

    " V001 (CC) - AN2 APJ: filter before collecting any parent keys.
    IF lv_exact_pending = abap_true.
      restrict_pending_scope(
        EXPORTING it_scope = it_scope it_pending_keys = it_pending_keys
                  it_pending = lt_pend_scope
        IMPORTING et_selected = DATA(lt_exact_pending)
                  ev_message = lv_pending_message ).
      IF lv_pending_message IS NOT INITIAL.
        rs_result-errors = VALUE #( ( calc_run_id = ms_context-calc_run_id
          action = zif_reing_ca_c=>action-calc
          status_to = zif_reing_ca_c=>line_status-calc_err
          message = lv_pending_message ) ).
        RETURN.
      ENDIF.
      lt_pend_scope = lt_exact_pending.
    ENDIF.

    " ATC fix (NonLocal DBREAD via step_fx path H + step_validate path B2):
    " pre-cargar exch_rate + line_status de lineas PADRE antes del LOOP AT it_scope.
    DATA lt_parent_data_global TYPE tt_parent_fx.
    DATA lt_parent_keys_global TYPE tt_parent_fx.
    " Not nested inside another loop -- plain LOOP AT (was a DO/READ TABLE
    " INDEX walk over lt_pend_scope, flagged by ATC; this only collects
    " distinct parent keys, order does not matter).
    LOOP AT lt_pend_scope INTO DATA(ls_pend_row).
      IF ls_pend_row-origin_run_id IS NOT INITIAL.
        IF NOT line_exists( lt_parent_keys_global[
            origin_run_id   = ls_pend_row-origin_run_id
            origin_line_num = ls_pend_row-origin_line_num ] ).
          APPEND VALUE ty_parent_fx(
            origin_run_id   = ls_pend_row-origin_run_id
            origin_line_num = ls_pend_row-origin_line_num ) TO lt_parent_keys_global.
        ENDIF.
      ENDIF.
    ENDLOOP.
    IF lt_parent_keys_global IS NOT INITIAL.
      SELECT calc_run_id AS origin_run_id,
             line_num    AS origin_line_num,
             exch_rate, line_status, exch_rate_1, exch_rate_1_type,
             ct_currency, trans_currency
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_parent_keys_global
        WHERE calc_run_id = @lt_parent_keys_global-origin_run_id
          AND line_num    = @lt_parent_keys_global-origin_line_num
        INTO CORRESPONDING FIELDS OF TABLE @lt_parent_data_global.
    ENDIF.

    " Begin Insert V008 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : identidad y stage de la linea que REALMENTE falla.
    " Los dos CATCH de abajo reportaban siempre LS_LINE -- la linea
    " GENERICA del grupo -- aunque la excepcion se hubiera producido dentro
    " del DO TIMES, sobre una receptora expandida concreta. Consecuencia
    " real (incidente TS4-400 de 02/2026): la linea marcada CALC_ERR no era
    " la que fallo, el mensaje no traia receptora ni paso, y reconstruir el
    " caso costo leer datos historicos ya sobreescritos por los reintentos.
    " MS_CURRENT_LINE arranca como la generica y pasa a ser la receptora en
    " cuanto el DO TIMES la lee; LV_STAGE nombra el paso en curso. Ambas se
    " declaran fuera del TRY para que los CATCH las vean (en ABAP las
    " declaraciones son method-scoped, pero se explicita por legibilidad).
    DATA ls_current TYPE zreing_ca_line_a.
    DATA lv_stage   TYPE string.
    " End Insert V008 (08.09.2026 | EXT_GONZALCA)

    " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
    " Bug #64 -- two defects with one root cause, fixed together here.
    "
    " (a) STEP_A rows were LOST for any group where a single receptor failed.
    "     "APPEND LINES OF lt_steps" used to run ONLY as the last statement of
    "     the TRY, i.e. after the DO TIMES. Lines and PC breakdown are appended
    "     INSIDE the loop and therefore survive, but the steps of ALL receptors
    "     -- including the ones that calculated correctly -- were discarded by
    "     either CATCH. Silently: lt_steps_bulk arrived empty, the
    "     "IF ... IS NOT INITIAL" skipped the INSERT and COMMIT WORK confirmed
    "     as usual. Reported from TS4-400 (RUN-202602, IC-0008): the Calculation
    "     Sequence tab was empty for the whole group because receptor 14 of 14
    "     (KGB) failed in PC_SPLIT. The APPEND now also runs in both CATCH
    "     blocks, so every receptor keeps the steps it did produce.
    "
    " (b) Groups CROSS-CONTAMINATED each other's steps and PC breakdown.
    "     step_distribute restarts lv_new_line_num at 0 for every group, so the
    "     internal line_num is only unique WITHIN a group (the generic line is
    "     the 0 sentinel). ZREING_CA_STEP_A and ZREING_CA_LPC_A have no group
    "     column -- their keys are calc_run_id + line_num + ... -- and
    "     ZCL_REING_CA_CALC_JOB~reconcile_one_line consumes them with a bare
    "     "WHERE line_num = lv_old_num" over ONE working copy holding every
    "     group of the scope. With 2+ groups the first one to be reconciled
    "     swallowed the rows of the later ones, re-stamped them with ITS final
    "     line_num and DELETEd them, so the later groups found nothing and the
    "     re-stamped rows could collide on the primary key.
    "     Fixing (a) is what EXPOSES (b): until now the failing groups
    "     contributed no steps at all, which is exactly what hid the collision.
    "
    " The fix belongs here, at the origin, rather than in reconcile_one_line: a
    " per-group offset makes the internal numbering unique across the scope, so
    " line / step / PC stay consistent with each other and the consumer needs no
    " change. The offset is uniform per group, so the line-to-steps
    " correspondence is preserved exactly.
    "
    " WHY IT IS CONDITIONAL on 2+ groups: ZCL_REING_CA_AN2_REGENERATOR~regenerate
    " is the other productive caller of this method and it does NOT reconcile --
    " it persists the result straight away ("UPDATE zreing_ca_line_a FROM TABLE
    " ls_pipeline_result-lines", plus INSERTs into LPC_A/STEP_A), relying on the
    " line carrying the very line_num of the PEND seed row it just inserted.
    " Shifting that number would silently turn its UPDATE into a no-op. It always
    " passes a single-group scope, and with one group no collision is possible in
    " the first place, so the window is only opened when there is something to
    " separate. ZCL_REING_CA_CALC_JOB is unaffected either way: it matches the
    " physical LINE_A by NATURAL KEY (and BUKRS_RECV), never by raw line_num --
    " see its class header, 17.07.2026.
    "
    " ZREING_LINE_NUM is NUMC(7): a 1000-wide window per group leaves room for
    " 999 receptors per group and 9999 groups per scope, both far above the real
    " figures (~18 receptors).
    DATA lv_grp_offset  TYPE zreing_ca_line_a-line_num.
    DATA lv_offset_step TYPE zreing_ca_line_a-line_num.
    " V001 (CC) - AN2 APJ: physical B2 keys are already allocated.
    IF lv_exact_pending = abap_false AND lines( it_scope ) > 1.
      lv_offset_step = 1000.
    ENDIF.
    " End Insert V009 (15.09.2026 | EXT_GONZALCA)

    LOOP AT it_scope INTO DATA(ls_group).
      DATA(lt_steps) = VALUE zif_reing_ca_types=>ty_step_t( ).
      DATA(ls_line)  = CORRESPONDING zreing_ca_line_a( ls_group ).

      " V009: window of this group. Set before the TRY so that both CATCH
      " blocks see the same value as the happy path. Stays 0 for a
      " single-group scope (see the note above).
      lv_grp_offset = lv_grp_offset + lv_offset_step.

      " V008: contexto inicial -- si step_validate falla, esto es todo lo
      " que se sabe de la linea (el group key), y ya es mas que nada.
      ls_current = ls_line.
      lv_stage   = 'VALIDATE'.

      TRY.
          " V001 (CC) - A deferral group can contain one physical seed per
          " receiving company. Validate every seed instead of selecting only
          " the first one and silently leaving the others in CALC_PROC.
          DATA(lo_group_strategy) =
            zcl_reing_ca_optype_factory=>get_instance_from_cache(
              iv_op_type = ls_group-op_type
              io_sources = mo_sources
              is_context = ms_context ).
          DATA(lv_group_mode) = lo_group_strategy->expand_mode( ls_line ).
          DATA lt_lines TYPE zif_reing_ca_types=>ty_line_t.
          DATA lt_validate_steps TYPE zif_reing_ca_types=>ty_step_t.
          CLEAR: lt_lines, lt_validate_steps.

          IF lv_group_mode = zif_reing_ca_c=>row_type-defer_pending.
            " Keep receiver iteration outside EXECUTE's group loop. Besides
            " satisfying the ATC release gate, this isolates B2 seed handling.
            lt_lines = validate_defer_group(
              is_group       = ls_group
              it_pend_scope  = lt_pend_scope
              it_parent_data = lt_parent_data_global ).
            ls_line = lt_lines[ 1 ].
          ELSE.
            ls_line = step_validate(
              is_group       = ls_group
              it_pend_scope  = lt_pend_scope
              it_parent_data = lt_parent_data_global ).
            lt_lines = VALUE #( ( ls_line ) ).
          ENDIF.

          ls_current = ls_line.   " V008: ya con ct_id/matnr/base_amt resueltos

          lv_stage = 'DISTRIBUTE'.
          step_distribute( CHANGING ct_lines = lt_lines
                                     ct_steps = lt_steps ).

          " Begin Change ID V003 (03.08.2026 | EXT_GONZALCA)
          " Descripcion : Delta v2 CA-09 -- conecta step_delta (creado en
          " CA-06). Corre ENTRE step_distribute y step_gross_up, sobre el
          " mismo conjunto ct_lines del grupo (igual que step_distribute,
          " no por-linea-expandida como los steps del DO TIMES de abajo).
          lv_stage = 'DELTA'.
          step_delta( CHANGING ct_lines = lt_lines
                                ct_steps = lt_steps ).
          " End Change ID V003 (03.08.2026 | EXT_GONZALCA)

          " ATC fix: DO TIMES en lugar de LOOP anidado.
          " V001 (CC) - Prepare a keyed index once per group, only for EBA ON.
          DATA lt_trans_index TYPE tt_trans_step_index.
          CLEAR lt_trans_index.
          IF mv_eba_off = abap_false.
            lt_trans_index = index_trans_steps( lt_steps ).
          ENDIF.
          DATA ls_expanded LIKE LINE OF lt_lines.
          DATA lv_idx_exp TYPE i.
          lv_idx_exp = 1.
          DO lines( lt_lines ) TIMES.
            READ TABLE lt_lines INTO ls_expanded INDEX lv_idx_exp.
            " V008: desde aca la identidad real es la receptora expandida.
            ls_current = ls_expanded.

            " V001 (CC) - Newly appended monetary steps form a bounded segment.
            DATA(lv_trans_new_from) = lines( lt_steps ) + 1.
            DATA(lv_use_trans) = zcl_reing_ca_trans_amounts=>is_eba_enabled(
              iv_bukrs_prest = ls_expanded-bukrs_prest iv_eba_off = mv_eba_off ).
            lv_stage = 'GROSS_UP'.
            step_gross_up( CHANGING cs_line = ls_expanded ct_steps = lt_steps ).
            lv_stage = 'TAX'.
            step_tax(      CHANGING cs_line = ls_expanded ct_steps = lt_steps ).
            lv_stage = 'FX'.
            step_fx( EXPORTING it_parent_fx = lt_parent_data_global
                     CHANGING  cs_line = ls_expanded ct_steps = lt_steps ).
            ls_current = ls_expanded.   " V008: refresca importes ya calculados

            " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-07 --
            " quitada la asignacion de HAS_PC_BREAKDOWN (columna retirada de
            " ZREING_CA_LINE_A por CA-02; step_pc_split ya siempre genera apertura).
            lv_stage = 'PC_SPLIT'.
            " V001 (CC) - Local preview cannot fail the CT split before projection.
            DATA(ls_pc_line) = ls_expanded.
            IF lv_use_trans = abap_true.
              CLEAR ls_pc_line-net_local_amt.
            ENDIF.
            DATA(lt_pc) = step_pc_split( ls_pc_line ).
            IF lv_use_trans = abap_true.
              propagate_trans( EXPORTING iv_new_from = lv_trans_new_from
                CHANGING cs_line = ls_expanded ct_pc = lt_pc ct_steps = lt_steps ct_index = lt_trans_index ).
              ls_current = ls_expanded.
            ENDIF.
            ls_expanded-line_status      = zif_reing_ca_c=>line_status-calc.
            " End Change ID V002 (03.08.2026 | EXT_GONZALCA)

            " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
            " Line and its PC breakdown move into the group's window. Table
            " comprehension (VALUE ... FOR), not LOOP: a LOOP here would be
            " nested inside the DO and inside the LOOP AT it_scope, which is
            " the P2 finding that blocks release to Quality.
            " Original lines kept for reference:
            "    APPEND ls_expanded TO rs_result-lines.
            "    APPEND LINES OF lt_pc TO rs_result-line_pc.
            ls_expanded-line_num = ls_expanded-line_num + lv_grp_offset.
            APPEND ls_expanded TO rs_result-lines.
            APPEND LINES OF VALUE zif_reing_ca_types=>ty_line_pc_t(
              FOR ls_pc_off IN lt_pc
              ( VALUE #( BASE ls_pc_off
                         line_num = ls_pc_off-line_num + lv_grp_offset ) ) )
              TO rs_result-line_pc.
            " End Mod V009 (15.09.2026 | EXT_GONZALCA)
            lv_idx_exp = lv_idx_exp + 1.
          ENDDO.

          " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
          " Original line kept for reference:
          "    APPEND LINES OF lt_steps TO rs_result-steps.
          APPEND LINES OF VALUE zif_reing_ca_types=>ty_step_t(
            FOR ls_st_ok IN lt_steps
            ( VALUE #( BASE ls_st_ok
                       line_num = ls_st_ok-line_num + lv_grp_offset ) ) )
            TO rs_result-steps.
          " End Mod V009 (15.09.2026 | EXT_GONZALCA)

        CATCH zcx_reing_ca_calc_error INTO DATA(lo_error).
          " Begin Mod V008 (08.09.2026 | EXT_GONZALCA)
          " Se reporta LS_CURRENT (la receptora que fallo) en vez de
          " LS_LINE (la generica), y el mensaje lleva paso + receptora.
          " Lineas originales conservadas como referencia:
          "    ls_line-line_status = zif_reing_ca_c=>line_status-calc_err.
          "    ls_line-sim_message = lo_error->mv_message.
          "    APPEND ls_line TO rs_result-lines.
          DATA(lv_biz_msg) = |{ build_error_prefix( is_line  = ls_current
                                                    iv_stage = lv_stage ) }| &&
                             |{ lo_error->mv_message }|.
          ls_current-line_status = zif_reing_ca_c=>line_status-calc_err.
          ls_current-sim_message = lv_biz_msg.
          " V009: same window as the happy path. The error prefix above is
          " built BEFORE the shift on purpose -- it must keep quoting the
          " number the rest of the pipeline logged.
          ls_current-line_num = ls_current-line_num + lv_grp_offset.
          APPEND ls_current TO rs_result-lines.
          APPEND VALUE #( action    = zif_reing_ca_c=>action-calc
                           status_to = zif_reing_ca_c=>line_status-calc_err
                           message   = lv_biz_msg ) TO rs_result-errors.
          " End Mod V008 (08.09.2026 | EXT_GONZALCA)
          " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
          " Bug #64 (a): keep the steps produced before the failure.
          APPEND LINES OF VALUE zif_reing_ca_types=>ty_step_t(
            FOR ls_st_biz IN lt_steps
            ( VALUE #( BASE ls_st_biz
                       line_num = ls_st_biz-line_num + lv_grp_offset ) ) )
            TO rs_result-steps.
          " End Insert V009 (15.09.2026 | EXT_GONZALCA)

        " Begin Change ID V004 (03.09.2026 | EXT_GONZALCA)
        " Descripcion : hasta ahora este TRY solo capturaba la excepcion de
        " NEGOCIO. Cualquier excepcion TECNICA (p.ej. CX_SY_CONVERSION_OVERFLOW
        " en step_fx al guardar una tasa de cambio ARS/COP en RATE_PCT, bug
        " real reportado desde TS4-400) escapaba del LOOP, escapaba de
        " ZCL_REING_CA_CALC_JOB~run_pipeline -- que tambien captura solo
        " ZCX_REING_CA_CALC_ERROR -- y abortaba el job con dump, SIN COMMIT y
        " sin terminalizar ninguna linea: el run quedaba con todas sus lineas
        " en CALC_PROC, sin heartbeat, y el reintento volvia a leer la misma
        " linea envenenada. Ahora un fallo tecnico degrada SOLO su grupo a
        " CALC_ERR -- mismo tratamiento que un error de negocio, misma
        " invariante P-07 ("a failing group is marked CALC_ERR and the scope
        " keeps going") declarada en el header de la clase.
        " Se registra el nombre de la clase de excepcion ademas del texto:
        " get_text( ) de una excepcion tecnica no siempre identifica el tipo.
        CATCH cx_root INTO DATA(lo_dump).
          DATA(lv_exc_name) = cl_abap_typedescr=>describe_by_object_ref(
                                lo_dump )->get_relative_name( ).
          " SIM_MESSAGE es CHAR 220 -- un texto mas largo se trunca solo.
          " Mod V008: +prefijo con paso y receptora (ver nota del CATCH de
          " negocio). El texto "Error tecnico" se conserva: es lo que
          " distingue un fallo tecnico de uno de negocio en los reportes.
          DATA(lv_tech_msg) = |{ build_error_prefix( is_line  = ls_current
                                                     iv_stage = lv_stage ) }| &&
                              |Error tecnico { lv_exc_name }: { lo_dump->get_text( ) }|.
          ls_current-line_status = zif_reing_ca_c=>line_status-calc_err.
          ls_current-sim_message = lv_tech_msg.
          " V009: see the note in the business CATCH above.
          ls_current-line_num = ls_current-line_num + lv_grp_offset.
          APPEND ls_current TO rs_result-lines.
          APPEND VALUE #( action    = zif_reing_ca_c=>action-calc
                           status_to = zif_reing_ca_c=>line_status-calc_err
                           message   = lv_tech_msg ) TO rs_result-errors.
        " End Change ID V004 (03.09.2026 | EXT_GONZALCA)
          " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
          " Bug #64 (a): keep the steps produced before the failure.
          APPEND LINES OF VALUE zif_reing_ca_types=>ty_step_t(
            FOR ls_st_tech IN lt_steps
            ( VALUE #( BASE ls_st_tech
                       line_num = ls_st_tech-line_num + lv_grp_offset ) ) )
            TO rs_result-steps.
          " End Insert V009 (15.09.2026 | EXT_GONZALCA)
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD step_pc_split.
    " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
    " Descripcion : Delta v2 CA-07 (BR-CA-40, BR-CA-32, generate_pc_delta).
    " Ya no depende de GRANULARITY_TYPE (get_me_metric/get_metric_granularity
    " retirados de este metodo) -- siempre genera apertura por las 4
    " dimensiones. Resuelve el periodo ME con ME_PERIOD_OFFSET (BR-CA-40,
    " rollover de anio) antes de leer shares.
    " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
    " La resolucion del periodo ME (offset + rollover) se movio a
    " resolve_me_period, para que step_validate y step_distribute usen
    " EXACTAMENTE la misma, en vez de leer ME con el periodo del run.
    " Bloque original conservado como referencia historica:
    "    DATA(ls_ct_opt) = mo_sources->get_ct_option( iv_op_uuid = is_line-op_uuid ).
    "    DATA(lv_offset)   = CONV i( ls_ct_opt-me_period_offset ).
    "    DATA(lv_me_month) = CONV zreing_me_h_a-period_month( ms_context-period - lv_offset ).
    "    DATA(lv_me_year)  = CONV zreing_me_h_a-period_year( ms_context-year ).
    "    IF lv_me_month <= 0.
    "      lv_me_month = lv_me_month + 12.
    "      lv_me_year  = lv_me_year - 1.
    "    ENDIF.
    DATA lv_me_month TYPE zreing_me_h_a-period_month.
    DATA lv_me_year  TYPE zreing_me_h_a-period_year.
    resolve_me_period( EXPORTING iv_op_uuid      = is_line-op_uuid
                       IMPORTING ev_period_month = lv_me_month
                                 ev_period_year  = lv_me_year ).
    " End Mod V006 (08.09.2026 | EXT_GONZALCA)

    DATA(lt_shares) = mo_sources->get_me_shares(
                         iv_ct_id        = is_line-ct_id
                         iv_matnr        = is_line-matnr
                         iv_period_year  = lv_me_year
                         iv_period_month = lv_me_month ).

    " Agregacion en memoria por las 4 dimensiones (antes: solo PRCTR).
    " Iteration #5 (activation ERR-002, line 644): mismo patron manual
    " find-or-append que step_02_distribute (COLLECT no sirve con
    " componentes CHAR una vez declarada la key de la tabla interna).
    TYPES: BEGIN OF ty_dim_agg,
             prctr         TYPE prctr,
             campana       TYPE zreing_campana,
             role_category TYPE zreing_role_cat,
             allocation    TYPE zreing_alloc_type,
             share_abs     TYPE zreing_ca_lpc_a-share_abs,
           END OF ty_dim_agg.
    DATA lt_agg TYPE STANDARD TABLE OF ty_dim_agg WITH EMPTY KEY.

    LOOP AT lt_shares INTO DATA(ls_share) WHERE bukrs = is_line-bukrs_recv.
      ASSIGN lt_agg[ prctr         = ls_share-prctr
                     campana       = ls_share-campana
                     role_category = ls_share-role_category
                     allocation    = ls_share-allocation ] TO FIELD-SYMBOL(<ls_agg>).
      IF sy-subrc = 0.
        <ls_agg>-share_abs = <ls_agg>-share_abs + ls_share-share_pct.
      ELSE.
        APPEND VALUE ty_dim_agg( prctr         = ls_share-prctr
                                  campana       = ls_share-campana
                                  role_category = ls_share-role_category
                                  allocation    = ls_share-allocation
                                  share_abs     = ls_share-share_pct ) TO lt_agg.
      ENDIF.
    ENDLOOP.

    IF lt_agg IS INITIAL.
      RETURN.
    ENDIF.

    " Begin Insert V006 (08.09.2026 | EXT_GONZALCA)
    " Guard del denominador del ratio de la rama normal. Con SHARE_PCT = 0 la
    " division de mas abajo lanzaba CX_SY_ZERODIVIDE (incluso en el caso
    " 0 / 0), escapaba como excepcion TECNICA y llegaba al CATCH CX_ROOT de
    " execute, que reporta la linea GENERICA -- sin receptora ni stage. Ahora
    " es un error de NEGOCIO que identifica la receptora, el periodo ME
    " realmente usado y la fuente del dato.
    " La condicion "lines( lt_agg ) > 1" es deliberada: una receptora con
    " share 0 y UNA SOLA combinacion (caso real de MUR en el run de
    " 02/2026) cae en la rama del residuo, nunca divide, y produce una fila
    " correcta en 0,00 -- un guard a secas sobre SHARE_PCT la convertiria en
    " un fallo de grupo, que seria una regresion. Con 2+ combinaciones no
    " hay base para repartir y si corresponde fallar.
    " PENDIENTE FUNCIONAL: que una receptora pueda tener SHARE_PCT total 0 y
    " que regla aplica (excluirla del calculo vs. linea en cero) esta
    " escalado y sin respuesta. Hasta que se defina, esto es un error
    " controlado y NO una decision de negocio.
    " Begin Mod V012 (16.09.2026 | EXT_GONZALCA)
    " EL PENDIENTE FUNCIONAL DE ARRIBA YA ESTA RESUELTO -- bug tracker #63
    " ("los calculos con valores de 0,00 no deberian generar error"),
    " definicion de Rochelle del 16.09.2026: la receptora NO se excluye de la
    " lista, un calculo en cero se interpreta como EXITO y es la
    " contabilizacion la que ignora los importes con saldo cero (esa segunda
    " mitad vive en ZCL_REING_CONTAB_DOC~is_applicable).
    " El caso que #63 reporta -- SHARE_PCT 0 con 2+ combinaciones y la linea
    " ENTERA en cero (KGB en IC-0008 / 02/2026) -- deja de ser un error: el
    " denominador se neutraliza (COND de mas abajo, el MISMO patron que la
    " rama delta ya usa en lv_dim_factor / lv_out_factor), las N combinaciones
    " salen en 0,00 y la ultima absorbe un residuo que tambien es 0,00, de
    " modo que la invariante SUM(LINE_PC_A) = LINE_A se mantiene y la linea
    " termina en CALC.
    " Lo que SI se conserva como error es el dato INCONSISTENTE: share total 0
    " pero un importe REAL a repartir entre 2+ combinaciones. Ahi no hay base
    " para decidir cuanto va a cada una y, con ratio 0, la ultima se llevaria
    " el importe entero como residuo -- un reparto arbitrario y, peor,
    " silencioso.
    " "lines( lt_agg ) > 1" SIGUE SIENDO PARTE DE LA CONDICION, y no es un
    " resto del guard viejo: con UNA sola combinacion la rama del residuo le
    " asigna el importe completo, que es el reparto correcto y el unico
    " posible. Quitarlo rompe Path B (diferidos), donde CALC_AMT no se deriva
    " del share de ME sino de la cuota del padre y por eso SHARE_PCT 0 con
    " importe distinto de cero es legitimo -- lo detecto el unit test
    " PATH_B_DEFER_FX_TYPE_H al primer intento de este fix.
    " Statement original, para el registro:
    "    IF is_line-share_pct IS INITIAL AND lines( lt_agg ) > 1.
    IF is_line-share_pct IS INITIAL AND is_line-calc_amt <> 0 AND lines( lt_agg ) > 1.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |Receptora { is_line-bukrs_recv } (linea { is_line-line_num }) con SHARE_PCT | &&
          |cero pero importe { is_line-calc_amt } a repartir entre { lines( lt_agg ) } | &&
          |combinaciones de la metrica ME { lv_me_month }/{ lv_me_year }: dato | &&
          |inconsistente, sin base para derivar la apertura. | &&
          |Revisar ZREING_ME_I_A de { is_line-ct_id }/{ is_line-matnr }|.
    ENDIF.
    " End Mod V012 (16.09.2026 | EXT_GONZALCA)
    " End Insert V006 (08.09.2026 | EXT_GONZALCA)

    DATA(lv_pc_seq)    = CONV zreing_ca_lpc_a-pc_seq( 0 ).
    DATA(lv_sum_calc)  = CONV zreing_ca_line_a-calc_amt( 0 ).
    DATA(lv_sum_bruto) = CONV zreing_ca_line_a-bruto_amt( 0 ).
    DATA(lv_sum_tax)   = CONV zreing_ca_line_a-tax_amt( 0 ).
    DATA(lv_sum_net)   = CONV zreing_ca_line_a-net_amt( 0 ).
    DATA(lv_sum_local) = CONV zreing_ca_line_a-net_local_amt( 0 ).

    IF is_line-is_delta = abap_true.
      " Delta: target - baseline por combinacion de dimensiones
      " (generate_pc_delta, BR-CA-43). Mantiene invariante
      " SUM(LINE_PC_A.campo) = LINE_A.campo, igual que la rama normal.
      " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
      " Fix de precision en TODA esta rama. Las 4 declaraciones inline de
      " abajo -- lv_total_target_calc, lv_target_dim, lv_delta_dim y
      " lv_delta_out -- operaban sobre importes CURR(15,2) y dejaban que
      " ABAP infiriera el tipo del resultado, que resuelve P(8,0): SIN
      " DECIMALES. Los montos de la apertura delta se truncaban a entero
      " (perdian los centavos) y el truncamiento se propagaba en cadena
      " (target -> delta -> share_abs/calc_amt de cada LINE_PC_A).
      " Mismo patron de inferencia que el lv_ratio de la rama normal -- ver
      " la nota extensa mas abajo. Aca el tipo correcto NO es decfloat34
      " sino el del propio campo de importe: el valor ES un importe y se
      " asigna a CURR(15,2). Los 4 warnings los venia emitiendo el
      " compilador desde la activacion de V002 (03.08.2026).
      " Los tests de delta no lo detectaban porque usan importes redondos
      " (1000,00 / 1250,00 / 200,00), sobre los que truncar a entero no
      " cambia el resultado.
      DATA(lt_baseline) = mo_sources->get_cont_line_pc_baseline(
                             iv_ct_uuid      = is_line-ct_uuid
                             iv_mat_uuid     = is_line-mat_uuid
                             iv_op_type      = is_line-op_type
                             iv_op_uuid      = is_line-op_uuid
                             iv_bukrs_recv   = is_line-bukrs_recv
                             iv_period_year  = ms_context-year
                             iv_period_month = ms_context-period ).

      DATA(lv_baseline_total_calc) = CONV zreing_ca_line_a-calc_amt( 0 ).
      LOOP AT lt_baseline INTO DATA(ls_bl_tot).
        lv_baseline_total_calc = lv_baseline_total_calc + ls_bl_tot-calc_amt.
      ENDLOOP.
      "      DATA(lv_total_target_calc) = lv_baseline_total_calc + is_line-calc_amt.
      DATA(lv_total_target_calc) = CONV zreing_ca_line_a-calc_amt(
                                     lv_baseline_total_calc + is_line-calc_amt ).
      " End Mod V006 (08.09.2026 | EXT_GONZALCA)

      " Combinaciones que estaban en el baseline y ya no aparecen en los
      " shares actuales -- se agregan al recorrido como filas de reversion
      " (monto negativo), para que el residuo final (BR-CA-32) se calcule
      " sobre el conjunto COMPLETO (actuales + salientes).
      DATA lt_left TYPE STANDARD TABLE OF ty_dim_agg WITH EMPTY KEY.
      LOOP AT lt_baseline INTO DATA(ls_bl_left).
        IF NOT line_exists( lt_agg[ prctr = ls_bl_left-prctr campana = ls_bl_left-campana
                                     role_category = ls_bl_left-role_category
                                     allocation = ls_bl_left-allocation ] ).
          APPEND VALUE ty_dim_agg( prctr = ls_bl_left-prctr campana = ls_bl_left-campana
                                    role_category = ls_bl_left-role_category
                                    allocation = ls_bl_left-allocation
                                    share_abs = 0 ) TO lt_left.
        ENDIF.
      ENDLOOP.

      DATA(lv_total_combos) = lines( lt_agg ) + lines( lt_left ).

      LOOP AT lt_agg INTO DATA(ls_dim).
        lv_pc_seq = lv_pc_seq + 1.

        DATA(ls_pc) = VALUE zreing_ca_lpc_a(
                        calc_run_id    = is_line-calc_run_id
                        line_num       = is_line-line_num
                        pc_seq         = lv_pc_seq
                        prctr          = ls_dim-prctr
                        campana        = ls_dim-campana
                        role_category  = ls_dim-role_category
                        allocation     = ls_dim-allocation
                        ct_currency    = is_line-ct_currency
                        local_currency = is_line-local_currency ).

        " Mod V006: CONV explicito -- ver nota de precision al inicio de la rama.
        "        DATA(lv_target_dim) = lv_total_target_calc * ls_dim-share_abs / 100.
        DATA(lv_target_dim) = CONV zreing_ca_line_a-calc_amt(
                                lv_total_target_calc * ls_dim-share_abs / 100 ).
        DATA(lv_baseline_dim) = VALUE zreing_ca_line_a-calc_amt(
          lt_baseline[ prctr = ls_dim-prctr campana = ls_dim-campana
                       role_category = ls_dim-role_category allocation = ls_dim-allocation ]-calc_amt
          OPTIONAL ).
        "        DATA(lv_delta_dim) = lv_target_dim - lv_baseline_dim.
        DATA(lv_delta_dim) = CONV zreing_ca_line_a-calc_amt( lv_target_dim - lv_baseline_dim ).
        " Begin Mod V013 (16.09.2026 | EXT_GONZALCA)
        " Bug tracker #77, segundo hallazgo: SHARE_ABS recibia un IMPORTE.
        " ZREING_CA_LPC_A-SHARE_ABS es ZREING_PERCENT_9_6 -- DEC(9,6), o sea
        " un maximo de 999,999999. LV_DELTA_DIM es CURR(15,2) y lleva un
        " importe de verdad, asi que cualquier delta de 1.000 o mas lanzaba
        " CX_SY_CONVERSION_OVERFLOW. Como este metodo declara RAISING
        " ZCX_REING_CA_CALC_ERROR y nada mas, la excepcion no tenia handler:
        " se convertia en CX_SY_NO_HANDLER, la atrapaba el CATCH CX_ROOT de
        " execute y la linea terminaba en CALC_ERR con un "Error tecnico" que
        " no decia nada util. Reportado desde TS4-400 (RUN-202602,
        " IC-0001/ICSRV44, op P, delta D01, receptora DRM): CALC_AMT
        " 38.709.755,00 = 100.000.000,00 x 38,709755%. El importe estaba
        " BIEN calculado; lo que no entraba era el campo destino.
        " La rama delta nunca corrio con importes reales: los unit tests usan
        " 1000,00 / 1250,00 / 200,00 y el desborde empieza justo en 1.000.
        " El valor correcto es el PORCENTAJE de la combinacion, igual que en
        " la rama normal de mas abajo (ls_pc_norm-share_abs =
        " ls_prctr-share_abs). El importe del delta ya viaja por CALC_AMT y
        " por LV_DIM_FACTOR, asi que no se pierde nada.
        " SHARE_ABS solo lo consume la UI -- columna "Porcentaje" de Apertura
        " por Dimensiones, via ZI_ReingCALinePC. Verificado que nadie mas lo
        " lee: get_cont_line_pc_baseline agrega importes y no lo selecciona,
        " y ZCL_REING_CONTAB_DOC no lo menciona.
        " Statement original, para el registro:
        "        ls_pc-share_abs = lv_delta_dim.
        ls_pc-share_abs = ls_dim-share_abs.
        " End Mod V013 (16.09.2026 | EXT_GONZALCA)

        IF lv_pc_seq = lv_total_combos.
          ls_pc-calc_amt      = is_line-calc_amt      - lv_sum_calc.
          ls_pc-bruto_amt     = is_line-bruto_amt     - lv_sum_bruto.
          ls_pc-tax_amt       = is_line-tax_amt       - lv_sum_tax.
          ls_pc-net_amt       = is_line-net_amt       - lv_sum_net.
          ls_pc-net_local_amt = is_line-net_local_amt - lv_sum_local.
        ELSE.
          DATA(lv_dim_factor) = COND decfloat34( WHEN is_line-calc_amt <> 0 THEN lv_delta_dim / is_line-calc_amt ELSE 0 ).
          ls_pc-calc_amt      = lv_delta_dim.
          ls_pc-bruto_amt     = round_to_currency( iv_amount = is_line-bruto_amt     * lv_dim_factor iv_currency = is_line-ct_currency ).
          ls_pc-tax_amt       = round_to_currency( iv_amount = is_line-tax_amt       * lv_dim_factor iv_currency = is_line-ct_currency ).
          ls_pc-net_amt       = round_to_currency( iv_amount = is_line-net_amt       * lv_dim_factor iv_currency = is_line-ct_currency ).
          ls_pc-net_local_amt = round_to_currency( iv_amount = is_line-net_local_amt * lv_dim_factor iv_currency = is_line-local_currency ).

          lv_sum_calc  = lv_sum_calc  + ls_pc-calc_amt.
          lv_sum_bruto = lv_sum_bruto + ls_pc-bruto_amt.
          lv_sum_tax   = lv_sum_tax   + ls_pc-tax_amt.
          lv_sum_net   = lv_sum_net   + ls_pc-net_amt.
          lv_sum_local = lv_sum_local + ls_pc-net_local_amt.
        ENDIF.

        APPEND ls_pc TO rt_pc.
      ENDLOOP.

      " Combinaciones salientes: reversal completo del baseline (target=0).
      LOOP AT lt_left INTO DATA(ls_out).
        lv_pc_seq = lv_pc_seq + 1.

        DATA(ls_pc_out) = VALUE zreing_ca_lpc_a(
                             calc_run_id    = is_line-calc_run_id
                             line_num       = is_line-line_num
                             pc_seq         = lv_pc_seq
                             prctr          = ls_out-prctr
                             campana        = ls_out-campana
                             role_category  = ls_out-role_category
                             allocation     = ls_out-allocation
                             ct_currency    = is_line-ct_currency
                             local_currency = is_line-local_currency ).

        DATA(lv_baseline_out) = VALUE zreing_ca_line_a-calc_amt(
          lt_baseline[ prctr = ls_out-prctr campana = ls_out-campana
                       role_category = ls_out-role_category allocation = ls_out-allocation ]-calc_amt
          OPTIONAL ).
        " Mod V006: CONV explicito -- ver nota de precision al inicio de la rama.
        "        DATA(lv_delta_out) = 0 - lv_baseline_out.
        DATA(lv_delta_out) = CONV zreing_ca_line_a-calc_amt( 0 - lv_baseline_out ).
        " Begin Mod V013 (16.09.2026 | EXT_GONZALCA)
        " Mismo desborde que en la rama de arriba, mismo criterio. Aca el
        " porcentaje es 0 por construccion: LT_LEFT son las combinaciones que
        " estaban en el baseline y ya NO aparecen en los shares del periodo,
        " y se cargan con share_abs = 0 unas lineas mas arriba. Se asigna el
        " campo y no un literal para que el dato siga teniendo una sola
        " fuente.
        " Statement original, para el registro:
        "        ls_pc_out-share_abs = lv_delta_out.
        ls_pc_out-share_abs = ls_out-share_abs.
        " End Mod V013 (16.09.2026 | EXT_GONZALCA)

        IF lv_pc_seq = lv_total_combos.
          ls_pc_out-calc_amt      = is_line-calc_amt      - lv_sum_calc.
          ls_pc_out-bruto_amt     = is_line-bruto_amt     - lv_sum_bruto.
          ls_pc_out-tax_amt       = is_line-tax_amt       - lv_sum_tax.
          ls_pc_out-net_amt       = is_line-net_amt       - lv_sum_net.
          ls_pc_out-net_local_amt = is_line-net_local_amt - lv_sum_local.
        ELSE.
          DATA(lv_out_factor) = COND decfloat34( WHEN is_line-calc_amt <> 0 THEN lv_delta_out / is_line-calc_amt ELSE 0 ).
          ls_pc_out-calc_amt      = lv_delta_out.
          ls_pc_out-bruto_amt     = round_to_currency( iv_amount = is_line-bruto_amt     * lv_out_factor iv_currency = is_line-ct_currency ).
          ls_pc_out-tax_amt       = round_to_currency( iv_amount = is_line-tax_amt       * lv_out_factor iv_currency = is_line-ct_currency ).
          ls_pc_out-net_amt       = round_to_currency( iv_amount = is_line-net_amt       * lv_out_factor iv_currency = is_line-ct_currency ).
          ls_pc_out-net_local_amt = round_to_currency( iv_amount = is_line-net_local_amt * lv_out_factor iv_currency = is_line-local_currency ).

          lv_sum_calc  = lv_sum_calc  + ls_pc_out-calc_amt.
          lv_sum_bruto = lv_sum_bruto + ls_pc_out-bruto_amt.
          lv_sum_tax   = lv_sum_tax   + ls_pc_out-tax_amt.
          lv_sum_net   = lv_sum_net   + ls_pc_out-net_amt.
          lv_sum_local = lv_sum_local + ls_pc_out-net_local_amt.
        ENDIF.

        APPEND ls_pc_out TO rt_pc.
      ENDLOOP.

    ELSE.
      " Normal: reparto proporcional estandar por las 4 dimensiones
      " (BR-CA-32: la ultima combinacion absorbe el residuo de redondeo).
      DATA(lv_lines) = lines( lt_agg ).

      LOOP AT lt_agg INTO DATA(ls_prctr).
        lv_pc_seq = lv_pc_seq + 1.

        DATA(ls_pc_norm) = VALUE zreing_ca_lpc_a(
                              calc_run_id    = is_line-calc_run_id
                              line_num       = is_line-line_num
                              pc_seq         = lv_pc_seq
                              prctr          = ls_prctr-prctr
                              campana        = ls_prctr-campana
                              role_category  = ls_prctr-role_category
                              allocation     = ls_prctr-allocation
                              share_abs      = ls_prctr-share_abs
                              ct_currency    = is_line-ct_currency
                              local_currency = is_line-local_currency ).

        IF lv_pc_seq = lv_lines.
          ls_pc_norm-calc_amt      = is_line-calc_amt      - lv_sum_calc.
          ls_pc_norm-bruto_amt     = is_line-bruto_amt     - lv_sum_bruto.
          ls_pc_norm-tax_amt       = is_line-tax_amt       - lv_sum_tax.
          ls_pc_norm-net_amt       = is_line-net_amt       - lv_sum_net.
          ls_pc_norm-net_local_amt = is_line-net_local_amt - lv_sum_local.
        ELSE.
          " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
          " Fix CRITICO. El original -- "DATA(lv_ratio) = ls_prctr-share_abs /
          " is_line-share_pct." -- infiere el tipo del resultado de una
          " division entre dos DEC(9,6) (ambos ZREING_PERCENT_9_6) y ABAP
          " resuelve P(8,0), es decir SIN DECIMALES. El compilador lo avisa:
          " "For the result of a computation with type P, the type P(8,0) is
          " used here implicitly because it is not possible to determine the
          " needed length and decimal places in general" -- warning que paso
          " inadvertido en la activacion.
          " Consecuencia: el ratio se REDONDEABA a 0 o 1, asi que una sola
          " combinacion (la del ratio >= 0,5) se llevaba el 100% del importe
          " de la receptora y todas las demas quedaban en 0,00. Verificado
          " con datos reales de TS4-400 (RUN-202602, IC-0001/ICSRV44):
          " DRM tenia 4.213.757,42 en el PRCTR 199 y 0,00 en los otros cinco;
          " en MLA el PRCTR 200 (ratio 0,5096 -> 1) se llevaba todo mientras
          " el 199 (ratio 0,3289 -> 0) quedaba en cero. La invariante
          " SUM(LINE_PC_A) = LINE_A se cumplia igual (por el residuo), de modo
          " que el error era INVISIBLE desde los totales -- y CONTAB consume
          " LINE_PC_A (BR-CA-33), con lo cual los asientos se imputaban
          " integros a un solo CeBe.
          " Es el tercer caso del mismo patron en este codigo (ver V018 en
          " step_distribute y el COLLECT de ZBP_REINGMEHEADER~calcularshare):
          " la inferencia de tipo de una expresion aritmetica sobre packed
          " NO se toma del tipo de los operandos.
          " Aca el tipo correcto SI es decfloat34 y no un tipo de 6 decimales:
          " lv_ratio no es un share ni se persiste, es un FACTOR adimensional
          " que solo multiplica importes. Con 6 decimales el corte del 7mo
          " decimal (<= 5e-7) sobre un importe de 8 cifras ya introduce
          " unidades de moneda de desvio; con decfloat34 el factor conserva
          " precision y el UNICO redondeo ocurre donde corresponde, en
          " round_to_currency, a los decimales reales de la moneda.
          "          DATA(lv_ratio) = ls_prctr-share_abs / is_line-share_pct.
          " Begin Mod V012 (16.09.2026 | EXT_GONZALCA)
          " Bug #63: el denominador se neutraliza en vez de dividir por cero.
          " Con SHARE_PCT 0 la receptora no participa del periodo, todos sus
          " importes ya son 0 y un factor 0 reparte 0,00 en cada combinacion;
          " el residuo de la ultima tambien da 0,00, asi que la invariante
          " SUM(LINE_PC_A) = LINE_A se mantiene.
          " El unico caso en que SHARE_PCT 0 llega aca con un importe REAL es
          " Path B (diferidos), donde CALC_AMT sale de la cuota del padre y no
          " del share de ME; ahi lt_agg tiene una sola combinacion, el flujo
          " entra por la rama del residuo de arriba y este ELSE ni se evalua.
          " La combinacion "importe real + 2 o mas combinaciones" ya quedo
          " rechazada por el guard del principio del metodo, de modo que el
          " ELSE 0 nunca esconde un dato malo.
          " Mismo patron que lv_dim_factor / lv_out_factor de la rama delta.
          " Statement original, para el registro:
          "          DATA(lv_ratio) = CONV decfloat34( ls_prctr-share_abs ) / is_line-share_pct.
          DATA(lv_ratio) = COND decfloat34(
                             WHEN is_line-share_pct <> 0
                             THEN CONV decfloat34( ls_prctr-share_abs ) / is_line-share_pct
                             ELSE 0 ).
          " End Mod V012 (16.09.2026 | EXT_GONZALCA)
          " End Mod V006 (08.09.2026 | EXT_GONZALCA)
          ls_pc_norm-calc_amt      = round_to_currency( iv_amount = is_line-calc_amt      * lv_ratio iv_currency = is_line-ct_currency ).
          ls_pc_norm-bruto_amt     = round_to_currency( iv_amount = is_line-bruto_amt     * lv_ratio iv_currency = is_line-ct_currency ).
          ls_pc_norm-tax_amt       = round_to_currency( iv_amount = is_line-tax_amt       * lv_ratio iv_currency = is_line-ct_currency ).
          ls_pc_norm-net_amt       = round_to_currency( iv_amount = is_line-net_amt       * lv_ratio iv_currency = is_line-ct_currency ).
          ls_pc_norm-net_local_amt = round_to_currency( iv_amount = is_line-net_local_amt * lv_ratio iv_currency = is_line-local_currency ).

          lv_sum_calc  = lv_sum_calc  + ls_pc_norm-calc_amt.
          lv_sum_bruto = lv_sum_bruto + ls_pc_norm-bruto_amt.
          lv_sum_tax   = lv_sum_tax   + ls_pc_norm-tax_amt.
          lv_sum_net   = lv_sum_net   + ls_pc_norm-net_amt.
          lv_sum_local = lv_sum_local + ls_pc_norm-net_local_amt.
        ENDIF.

        APPEND ls_pc_norm TO rt_pc.
      ENDLOOP.
    ENDIF.
    " End Change ID V002 (03.08.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD record_step.
    APPEND VALUE zreing_ca_step_a(
             calc_run_id     = ms_context-calc_run_id
             line_num        = iv_line_num
             step_num        = iv_step_num
             seq             = iv_seq
             step_category   = iv_category
             tax_type        = iv_tax_type
             " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
             tx_rule_id      = iv_tx_rule_id
             rate_desc       = iv_rate_desc
             " End Insert V019 (17.09.2026 | EXT_GONZALCA)
             step_desc       = iv_desc
             input_amt       = iv_input
             input_currency  = iv_input_curr
             rate_pct        = iv_rate
             output_amt      = iv_output
             output_currency = iv_output_curr
             sign            = iv_sign
             source_table    = iv_source_table
             source_key      = iv_source_key ) TO ct_steps.
  ENDMETHOD.

  METHOD replicate_steps.
    " Snapshot the source rows first — appending to ct_steps while
    " looping over it would also visit the newly appended rows.
    DATA(lt_source) = VALUE zif_reing_ca_types=>ty_step_t(
                        FOR ls_s IN ct_steps WHERE ( line_num = iv_from_line ) ( ls_s ) ).
    LOOP AT lt_source INTO DATA(ls_step).
      ls_step-line_num = iv_to_line.
      APPEND ls_step TO ct_steps.
    ENDLOOP.
  ENDMETHOD.

  METHOD last_day_of_period.
    DATA(lv_year)  = iv_fiscal_year.
    DATA(lv_month) = iv_fiscal_period.
    IF lv_month = 12.
      lv_year  = lv_year + 1.
      lv_month = 1.
    ELSE.
      lv_month = lv_month + 1.
    ENDIF.
    rv_date = CONV d( |{ lv_year }{ lv_month }01| ) - 1.
  ENDMETHOD.

  METHOD round_to_currency.
    " F2-14: do not assume 2 decimals — CLP/JPY have 0.
    " ATC fix (NonLocal DBREAD): mt_currency_decimals pre-cargado en execute()
    " con SELECT total de I_CURRENCY antes del LOOP AT it_scope.
    " CERO SELECT aqui -- solo READ TABLE sobre el cache en memoria.
    ASSIGN mt_currency_decimals[ currency = iv_currency ] TO FIELD-SYMBOL(<ls_cc>).
    DATA(lv_decimals) = COND i( WHEN <ls_cc> IS ASSIGNED THEN <ls_cc>-decimals ELSE 2 ).
    DATA(lv_factor) = ipow( base = 10 exp = lv_decimals ).
    rv_amount = round( val = iv_amount * lv_factor dec = 0 ) / lv_factor.
  ENDMETHOD.

  METHOD step_delta.
    " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
    " Descripcion : Delta v2 CA-06 (BR-CA-41/BR-CA-42/BR-CA-43). Corre
    " ENTRE step_02_distribute y step_03_gross_up (la llamada la conecta
    " CA-09 en execute() -- este metodo queda creado pero inalcanzable
    " hasta entonces, mismo patron create-only del resto de Sprint 3).
    "
    " Solo procesa el grupo si alguna de sus lineas ya trae IS_DELTA = X
    " (poblado por step_01_validate al detectar CM_H_A.delta_flag = X,
    " Path A/CM). AN2/Defer (Path B2) todavia no marcan IS_DELTA en este
    " punto -- gap abierto, documentado en SEGUIMIENTO.md, no cubierto hoy.
    READ TABLE ct_lines TRANSPORTING NO FIELDS WITH KEY is_delta = abap_true.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(ls_generic) = ct_lines[ 1 ].

    " BR-CA-41: valida PERMITE_DELTA del OP_TYPE antes de redistribuir.
    IF mo_sources->get_op_type_permite_delta( ls_generic-op_type ) <> abap_true.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |OP_TYPE { ls_generic-op_type } no permite delta|.
    ENDIF.

    " Baseline: LINE_As CONT del grupo base (original + deltas previos ya
    " contabilizados), SIN discriminar delta_seq (BR-CA-42).
    DATA(lt_cont) = mo_sources->get_cont_baseline(
                      iv_ct_uuid      = ls_generic-ct_uuid
                      iv_mat_uuid     = ls_generic-mat_uuid
                      iv_op_type      = ls_generic-op_type
                      iv_op_uuid      = ls_generic-op_uuid
                      iv_period_year  = ms_context-year
                      iv_period_month = ms_context-period ).

    DATA(lv_baseline_total) = CONV zreing_ca_line_a-calc_amt( 0 ).
    DATA(lv_baseline_bruto) = CONV zreing_ca_line_a-bruto_amt( 0 ).
    LOOP AT lt_cont INTO DATA(ls_cont_tot).
      lv_baseline_total = lv_baseline_total + ls_cont_tot-calc_amt.
      lv_baseline_bruto = lv_baseline_bruto + ls_cont_tot-bruto_amt.
    ENDLOOP.

    " CM_DELTA: ya resuelto por step_01_validate como BASE_AMT de la linea
    " generica (get_cm_amount ya se leyo alli para detectar delta_flag) --
    " no se vuelve a leer CM_H_A aca.
    " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
    " Fix de precision: el original -- "DATA(lv_total_target) =
    " lv_baseline_total + ls_generic-base_amt." -- dejaba que ABAP infiriera
    " el tipo del resultado de una suma de dos CURR(15,2) y resolvia P(8,0),
    " o sea SIN DECIMALES: el target del delta perdia los centavos y
    " arrastraba el truncamiento a lv_target_recv (que si tiene su CONV,
    " pero sobre un total ya truncado). Mismo patron de inferencia que el
    " lv_ratio de step_pc_split -- ver la nota extensa alli.
    " El tipo correcto aca NO es decfloat34 sino el del propio campo de
    " importe: el valor ES un importe y se compara/asigna contra CURR(15,2).
    " Es el mismo criterio que este metodo ya aplicaba en lv_target_recv /
    " lv_delta_recv mas abajo.
    "    DATA(lv_total_target) = lv_baseline_total + ls_generic-base_amt.
    DATA(lv_total_target) = CONV zreing_ca_line_a-calc_amt(
                              lv_baseline_total + ls_generic-base_amt ).
    " End Mod V006 (08.09.2026 | EXT_GONZALCA)

    " Shares actuales agregados por receptora -- mismo patron manual
    " find-or-append que step_02_distribute (COLLECT no sirve con BUKRS
    " CHAR una vez declarada la key de la tabla interna, ver nota alli).
    " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
    " Los shares se leian con el periodo del RUN. step_delta es, para las
    " lineas delta, el equivalente de step_distribute: reparte el monto
    " entre receptoras con los shares de ME, asi que tiene que resolver el
    " periodo con ME_PERIOD_OFFSET igual que aquel (BR-CA-40). De lo
    " contrario un mismo grupo repartiria el importe original con los
    " shares de M-1 y su delta con los de M.
    " Linea original conservada como referencia:
    "    iv_period_year  = ms_context-year
    "    iv_period_month = ms_context-period
    DATA lv_me_month_dl TYPE zreing_me_h_a-period_month.
    DATA lv_me_year_dl  TYPE zreing_me_h_a-period_year.
    resolve_me_period( EXPORTING iv_op_uuid      = ls_generic-op_uuid
                       IMPORTING ev_period_month = lv_me_month_dl
                                 ev_period_year  = lv_me_year_dl ).

    DATA(lt_shares) = mo_sources->get_me_shares(
                        iv_ct_id        = ls_generic-ct_id
                        iv_matnr        = ls_generic-matnr
                        iv_period_year  = lv_me_year_dl
                        iv_period_month = lv_me_month_dl ).
    " End Mod V006 (08.09.2026 | EXT_GONZALCA)

    TYPES: BEGIN OF ty_share_agg,
             bukrs     TYPE bukrs,
             share_pct TYPE zreing_ca_line_a-share_pct,
           END OF ty_share_agg.
    DATA lt_agg TYPE STANDARD TABLE OF ty_share_agg WITH EMPTY KEY.
    LOOP AT lt_shares INTO DATA(ls_share).
      ASSIGN lt_agg[ bukrs = ls_share-bukrs ] TO FIELD-SYMBOL(<ls_agg>).
      IF sy-subrc = 0.
        <ls_agg>-share_pct = <ls_agg>-share_pct + ls_share-share_pct.
      ELSE.
        APPEND VALUE ty_share_agg( bukrs = ls_share-bukrs share_pct = ls_share-share_pct ) TO lt_agg.
      ENDIF.
    ENDLOOP.

    DATA(lv_next_line_num) = CONV zreing_ca_line_a-line_num( lines( ct_lines ) ).

    LOOP AT lt_agg INTO DATA(ls_recv).
      DATA(lv_target_recv) = CONV zreing_ca_line_a-calc_amt( lv_total_target * ls_recv-share_pct / 100 ).
      DATA(lv_base_recv)   = CONV zreing_ca_line_a-calc_amt( 0 ).
      READ TABLE lt_cont INTO DATA(ls_cont_recv) WITH KEY bukrs_recv = ls_recv-bukrs.
      IF sy-subrc = 0.
        lv_base_recv = ls_cont_recv-calc_amt.
      ENDIF.
      DATA(lv_delta_recv) = CONV zreing_ca_line_a-calc_amt( lv_target_recv - lv_base_recv ).
      IF lv_delta_recv = 0.
        CONTINUE.
      ENDIF.

      DATA(lv_log_line_num) = CONV zreing_ca_line_a-line_num( 0 ).
      READ TABLE ct_lines ASSIGNING FIELD-SYMBOL(<ls_line>)
        WITH KEY bukrs_recv = ls_recv-bukrs.
      IF sy-subrc = 0.
        <ls_line>-calc_amt       = lv_delta_recv.
        <ls_line>-is_delta       = abap_true.
        <ls_line>-delta_seq      = ls_generic-delta_seq.
        <ls_line>-delta_base_amt = lv_baseline_bruto.
        lv_log_line_num = <ls_line>-line_num.
      ELSE.
        lv_next_line_num = lv_next_line_num + 1.
        DATA(ls_new) = ls_generic.
        ls_new-line_num       = lv_next_line_num.
        ls_new-bukrs_recv     = ls_recv-bukrs.
        ls_new-share_pct      = ls_recv-share_pct.
        ls_new-calc_amt       = lv_delta_recv.
        ls_new-is_delta       = abap_true.
        ls_new-delta_seq      = ls_generic-delta_seq.
        ls_new-delta_base_amt = lv_baseline_bruto.
        APPEND ls_new TO ct_lines.
        lv_log_line_num = lv_next_line_num.
      ENDIF.

      record_step( EXPORTING iv_line_num     = lv_log_line_num
                             iv_step_num     = '06'
                             iv_seq          = '01'
                             iv_category     = zif_reing_ca_c=>step_category-delta
                             iv_input        = lv_baseline_total
                             iv_rate         = ls_recv-share_pct / 100
                             iv_output       = lv_delta_recv
                             iv_sign         = '='
                             iv_source_table = 'ZREING_CM_H_A'
                   CHANGING  ct_steps        = ct_steps ).
    ENDLOOP.

    " Receptoras que SALIERON: estaban en el baseline pero ya no aparecen
    " en los shares actuales -- linea negativa de reversion (BR-CA-43).
    LOOP AT lt_cont INTO DATA(ls_left).
      IF line_exists( lt_agg[ bukrs = ls_left-bukrs_recv ] ).
        CONTINUE.
      ENDIF.

      lv_next_line_num = lv_next_line_num + 1.
      DATA(ls_neg) = ls_generic.
      ls_neg-line_num       = lv_next_line_num.
      ls_neg-bukrs_recv     = ls_left-bukrs_recv.
      ls_neg-country        = ls_left-country.
      ls_neg-share_pct      = 0.
      ls_neg-calc_amt       = 0 - ls_left-calc_amt.
      ls_neg-is_delta       = abap_true.
      ls_neg-delta_seq      = ls_generic-delta_seq.
      ls_neg-delta_base_amt = lv_baseline_bruto.
      APPEND ls_neg TO ct_lines.

      record_step( EXPORTING iv_line_num     = lv_next_line_num
                             iv_step_num     = '06'
                             iv_seq          = '01'
                             iv_category     = zif_reing_ca_c=>step_category-delta
                             iv_input        = ls_left-calc_amt
                             iv_rate         = -1
                             iv_output       = ls_neg-calc_amt
                             iv_sign         = '='
                             iv_source_table = 'ZREING_CM_H_A'
                   CHANGING  ct_steps        = ct_steps ).
    ENDLOOP.
    " End Change ID V002 (03.08.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD validate_defer_group.
    DATA lt_validate_steps TYPE zif_reing_ca_types=>ty_step_t.
    CLEAR mt_validate_step.

    LOOP AT it_pend_scope INTO DATA(ls_group_seed)
      WHERE calc_run_id = ms_context-calc_run_id
        AND ct_uuid     = is_group-ct_uuid
        AND mat_uuid    = is_group-mat_uuid
        AND op_type     = is_group-op_type
        AND op_uuid     = is_group-op_uuid
        AND cm_h_id     = is_group-cm_h_id.
      DATA(lt_single_seed) =
        VALUE zif_reing_ca_types=>ty_line_t( ( ls_group_seed ) ).
      DATA(ls_line) = step_validate(
        is_group       = is_group
        it_pend_scope  = lt_single_seed
        it_parent_data = it_parent_data ).
      APPEND ls_line TO rt_lines.
      APPEND LINES OF mt_validate_step TO lt_validate_steps.
    ENDLOOP.

    IF rt_lines IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |No existe linea PEND para op_uuid { is_group-op_uuid } (Path B/C)|.
    ENDIF.

    mt_validate_step = lt_validate_steps.
  ENDMETHOD.

  METHOD step_validate.
    " Builds the GENERIC group line and resolves BASE_AMT via the OP_TYPE
    " strategy. ty_group_key only carries calc_run_id/ct_uuid/mat_uuid/
    " op_type/op_uuid — it has no bukrs_recv/parent_net_amt/defer_pct/
    " origin_run_id/origin_line_num, so a pure CORRESPONDING from the
    " group key is only enough for the B1 (CM_LOADABLE) path.
    rs_line             = CORRESPONDING zreing_ca_line_a( is_group ).
    rs_line-calc_run_id = ms_context-calc_run_id.

    " ATC fix (NonLocal DBREAD via get_instance en loop): reemplaza get_instance
    " por get_instance_from_cache -- CERO SELECT, lee solo de gt_cache
    " pre-cargado por warm_cache en execute() antes del LOOP AT it_scope.
    DATA(lo_strategy) = zcl_reing_ca_optype_factory=>get_instance_from_cache(
                           iv_op_type = is_group-op_type
                           io_sources = mo_sources
                           is_context = ms_context ).
    DATA(lv_expand_mode) = lo_strategy->expand_mode( rs_line ).

    " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
    " Bug #78: STEP_DESC of the VALIDATE step per ET SS7.4
    " ("Base {source}: {BASE_AMT} {WAERS}"). The source tag is captured
    " INSIDE each branch on purpose: ABAP inline declarations are
    " method-scoped, not block-scoped, so reading a branch variable after
    " the CASE would silently yield an EMPTY value for the other path -- the
    " very trap the Mod V005 note below already documents for ls_identity.
    DATA lv_base_src TYPE c LENGTH 10.
    " End Insert V019 (17.09.2026 | EXT_GONZALCA)

    CASE lv_expand_mode.
      WHEN zif_reing_ca_c=>row_type-cm_pending.
        rs_line-line_num = 0.   " sentinel: generic, not-yet-expanded line.
        lv_base_src = 'CM'.     "V019 (17.09.2026 | EXT_GONZALCA)

        " Amendment F2-DD-6 (blueprint SS6.11/SS9.3): ty_group_key only
        " carries ct_uuid/mat_uuid (technical UUIDs) — CT_ID/LIFNR/
        " BUKRS_PREST/MATNR (business keys, needed right below by
        " get_me_shares and later by get_cm_amount) come from the
        " contract's own identity, resolved via get_ct_identity.
        " Begin Mod V011 (15.09.2026 | EXT_GONZALCA)
        " Bug tracker #65, segundo campo vacio del mismo screenshot.
        " La nota original decia: "BP_NAME stays blank — same simplification
        " F1 already ratified (ZI_ReingCALineAll Lado B-1, cast('' as char80)
        " as BpName)". BP_NAME sigue sin escribirse aca A PROPOSITO: se
        " resolvio por asociacion a I_Supplier en ZI_ReingCALineAll (V009 de
        " esa vista), que es el patron ya ratificado en el proyecto para ese
        " dato y arregla las 4 ramas de la union en vez de solo la rama real.
        " La columna zreing_ca_line_a-bp_name queda sin uso.
        " Lo que SI se corrige aca es OP_INSTANCE_NUM, que es otra cosa: no es
        " un texto de dato maestro sino la IDENTIDAD de la instancia de
        " operacion a la que pertenece la linea. Nadie lo asignaba en esta
        " rama -- la linea generica se arma con CORRESPONDING desde
        " ty_group_key, que no lo lleva -- y como ZCL_REING_CA_CALC_JOB
        " persiste con "UPDATE ... FROM TABLE" la FILA COMPLETA que devuelve
        " el pipeline, el UPDATE PISABA CON BLANCO el valor que la accion
        " Calculate habia dejado en la fila PEND. Es exactamente el mismo
        " mecanismo que describe el V004 de ese job para PROC_STARTED_AT /
        " INSUMO_CHECK_AT, que corrigio esos dos campos y no este.
        " Por eso el campo se ve vacio SOLO en lineas Path A/CM: la rama B2
        " de mas abajo lee la fila PEND completa y lo conserva.
        DATA(ls_identity) = mo_sources->get_ct_identity(
                               iv_ct_uuid  = is_group-ct_uuid
                               iv_mat_uuid = is_group-mat_uuid ).
        rs_line-ct_id       = ls_identity-ct_id.
        rs_line-lifnr       = ls_identity-lifnr.
        rs_line-bukrs_prest = ls_identity-bukrs_prest.
        rs_line-matnr       = ls_identity-matnr.

        " La opcion del contrato se lee UNA vez y se reusa: get_ct_option
        " devuelve la fila completa de ZREING_CT2_OPT_A (ver su propio
        " comentario), asi que el mismo read sirve para OP_INSTANCE_NUM y
        " para el fallback de moneda del bloque V005 de abajo, que antes
        " hacia su propia llamada. Queda un read por GRUPO, no por linea, y
        " en el mismo lugar donde get_ct_identity ya hacia otro.
        DATA(ls_option) = mo_sources->get_ct_option( iv_op_uuid = rs_line-op_uuid ).
        " V001 (CC) - CA-109: the requested UUID must identify this group.
        IF ls_option-ct_uuid <> is_group-ct_uuid
           OR ls_option-mat_uuid <> is_group-mat_uuid
           OR ls_option-op_type <> is_group-op_type
           OR ls_option-op_uuid <> is_group-op_uuid
           OR ls_option-op_instance_num IS INITIAL.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = |Opcion { is_group-op_uuid } no corresponde al grupo de CM|.
        ENDIF.
        rs_line-op_instance_num = ls_option-op_instance_num.
        " End Mod V011 (15.09.2026 | EXT_GONZALCA)
        " Begin Insert V005 (07.09.2026 | EXT_GONZALCA)
        " CT_CURRENCY for the freshly-built B1 generic line. ty_group_key
        " carries no currency and the line is built with CORRESPONDING from
        " that group key, so there is nothing to inherit: this branch depends
        " 100% on the fallback below.
        " Primary source is now the contract HEADER (ZREING_CT2_A-WAERS),
        " already resolved by get_ct_identity above - so no new SELECT and
        " nothing new inside execute()'s LOOP AT it_scope (ATC NonLocal
        " DBREAD pattern).
        " The outer IF keeps an already-filled value (BR-CT-CUR-02).
        "
        " TRANSITIONAL (DD-04): the second link - get_ct_option( )-waers,
        " i.e. the DEPRECATED ZREING_CT2_OPT_A-WAERS, empty in real
        " contracts (IC-0007) and not maintainable from the contracts UI -
        " is kept ONLY because the testclasses include is locked in this
        " pass and 5 existing unit tests feed the currency through the
        " double's mv_ct_waers (which backs get_ct_option) instead of
        " ms_ct_identity-waers. Header always wins, so the deprecated field
        " can never override the authoritative value and the production
        " behaviour is the intended one. REMOVE this inner IF (and its
        " get_ct_option call) as soon as the lock is released and
        " ms_ct_identity carries waers - see code-summary.md.
        " Mod V011 (15.09.2026): la llamada del IF interno se reemplazo por
        " LS_OPTION, ya leido arriba -- mismo metodo, mismo argumento, mismo
        " valor; sin segundo SELECT. El double sigue respondiendo por
        " mv_ct_waers, asi que los 5 tests no cambian.
        IF rs_line-ct_currency IS INITIAL.
          rs_line-ct_currency = ls_identity-waers.
          IF rs_line-ct_currency IS INITIAL.
            rs_line-ct_currency = ls_option-waers.
          ENDIF.
        ENDIF.
        " End Insert V005 (07.09.2026 | EXT_GONZALCA)

        " B1 (BR-CA-38/BR-CA-13): get_me_shares itself already raises if no
        " eligible ZREING_ME_H_A exists for ct_id+matnr+period — calling it
        " here surfaces that as a step_01-specific block before expansion.
        " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
        " El probe validaba la existencia de la metrica del periodo del RUN,
        " pero el calculo consume la del periodo resuelto con
        " ME_PERIOD_OFFSET (BR-CA-40). Con offset '01' eso daba las dos
        " fallas cruzadas posibles: fallar un grupo que SI tiene su metrica
        " (la de M-1) porque falta la de M, y dejar pasar uno que NO la
        " tiene para reventar despues, ya dentro de step_distribute.
        " Ahora valida el mismo periodo que se va a leer.
        " Lineas originales conservadas como referencia:
        "    iv_period_year  = ms_context-year
        "    iv_period_month = ms_context-period
        DATA lv_me_month_v TYPE zreing_me_h_a-period_month.
        DATA lv_me_year_v  TYPE zreing_me_h_a-period_year.
        resolve_me_period( EXPORTING iv_op_uuid      = rs_line-op_uuid
                           IMPORTING ev_period_month = lv_me_month_v
                                     ev_period_year  = lv_me_year_v ).

        mo_sources->get_me_shares(
          iv_ct_id        = rs_line-ct_id
          iv_matnr        = rs_line-matnr
          iv_period_year  = lv_me_year_v
          iv_period_month = lv_me_month_v ).
        " End Mod V006 (08.09.2026 | EXT_GONZALCA)

        " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
        " Descripcion : Delta v2 CA-06 — deteccion de delta (BR-CA-41).
        " Path A/CM es el unico que pasa por get_cm_amount en este metodo
        " (AN2/Defer entran por Path B2 mas abajo, sin CM_H_A propio en
        " este punto — delta para esa rama queda gap abierto, ver
        " SEGUIMIENTO.md). Lectura de CM aislada aqui (no reutiliza el
        " monto de lo_strategy->load_base): la estrategia solo devuelve el
        " importe, no la fila completa, y delta_flag no forma parte de su
        " contrato — coherente con el patron ya usado arriba (get_me_shares
        " se llama dos veces por el mismo motivo: superficie de error
        " temprana, no una optimizacion de una sola lectura).
        TRY.
            DATA(ls_cm_delta) = mo_sources->get_cm_amount(
                                   iv_ct_uuid  = is_group-ct_uuid
                                   iv_mat_uuid = is_group-mat_uuid
                                   iv_op_type  = is_group-op_type
                                   iv_period   = ms_context-period
                                   iv_year     = ms_context-year
                                   iv_cm_h_id  = is_group-cm_h_id
                                   iv_op_instance_num = rs_line-op_instance_num ).
            rs_line-cm_h_id     = ls_cm_delta-cm_h_id.
            rs_line-cm_load_seq = ls_cm_delta-load_seq.
            IF ls_cm_delta-delta_flag = abap_true.
              rs_line-is_delta = abap_true.
              DATA(lt_cont_baseline) = mo_sources->get_cont_baseline(
                                         iv_ct_uuid      = is_group-ct_uuid
                                         iv_mat_uuid     = is_group-mat_uuid
                                         iv_op_type      = is_group-op_type
                                         iv_op_uuid      = is_group-op_uuid
                                         iv_period_year  = ms_context-year
                                         iv_period_month = ms_context-period ).
              DATA(lv_max_delta_seq) = CONV zreing_ca_line_a-delta_seq( '00' ).
              LOOP AT lt_cont_baseline INTO DATA(ls_cont_row) WHERE delta_seq > lv_max_delta_seq.
                lv_max_delta_seq = ls_cont_row-delta_seq.
              ENDLOOP.
              rs_line-delta_seq = lv_max_delta_seq + 1.
            ENDIF.
          CATCH zcx_reing_ca_calc_error.
            " V001 (CC) - CA-109: the mandatory CM guard below handles
            " unavailable/inconsistent loads before strategy load_base.
        ENDTRY.

        " V001 (CC) - CA-109: outside the tolerant delta CATCH on purpose.
        IF ls_cm_delta IS INITIAL
           OR ls_cm_delta-op_instance_num <> ls_option-op_instance_num.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message =
              |CM { ls_cm_delta-cm_h_id } instancia { ls_cm_delta-op_instance_num } | &&
              |no corresponde a opcion { is_group-op_uuid } instancia { ls_option-op_instance_num }|.
        ENDIF.
        " End Change ID V002 (03.08.2026 | EXT_GONZALCA)

      WHEN zif_reing_ca_c=>row_type-defer_pending.
        " B2: a PEND child row already exists.
        " ATC fix (NonLocal DBREAD): READ TABLE desde it_pend_scope pre-cargado
        " en execute() antes del LOOP AT it_scope -- CERO SELECT aqui.
        READ TABLE it_pend_scope INTO rs_line
          WITH KEY ct_uuid = is_group-ct_uuid
                   mat_uuid = is_group-mat_uuid
                   op_type  = is_group-op_type
                   op_uuid  = is_group-op_uuid
                   cm_h_id  = is_group-cm_h_id.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = |No existe linea PEND para op_uuid { is_group-op_uuid } (Path B/C)|.
        ENDIF.
        rs_line-calc_run_id = ms_context-calc_run_id.
        " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
        " ET SS7.4 splits this B2 branch in two: "Base padre" (Path B, the
        " deferral schedule, parent_type 'A') and "Base ANT" (Path C, AN2,
        " parent_type 'ANT'). LV_EXPAND_MODE cannot tell them apart -- both
        " strategies return 'B2' from expand_mode -- but the STRATEGY
        " INSTANCE already resolved above can: the factory dispatches those
        " two parent_type values to two distinct classes (see
        " ZCL_REING_CA_OPTYPE_FACTORY~dispatch_from_entry). No new
        " parameter and no extra read: LO_STRATEGY is in scope.
        " SOURCE_TABLE stays ZREING_CA_LINE_A for BOTH paths on purpose:
        " AN2's load_base copies IS_LINE-PARENT_NET_AMT, i.e. the parent
        " ANT's own LINE_A row, and SS7.4 lists only CM_H_A / LINE_A as the
        " source tables of VALIDATE -- it defines no separate one for ANT.
        IF lo_strategy IS INSTANCE OF zcl_reing_ca_optype_an2.
          lv_base_src = 'ANT'.
        ELSE.
          lv_base_src = 'padre'.
        ENDIF.
        " End Insert V019 (17.09.2026 | EXT_GONZALCA)

        " The parent LINE_A must still be CONT — revalidated for
        " robustness against concurrent state changes (the UI could have
        " shown a PEND row that changed status meanwhile).
        " ATC fix (NonLocal DBREAD): READ TABLE desde it_parent_data pre-cargado
        " en execute() antes del LOOP AT it_scope -- CERO SELECT aqui.
        READ TABLE it_parent_data INTO DATA(ls_parent_data)
          WITH KEY origin_run_id   = rs_line-origin_run_id
                   origin_line_num = rs_line-origin_line_num.
        IF sy-subrc <> 0 OR ls_parent_data-line_status <> zif_reing_ca_c=>line_status-cont.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message =
              |Linea padre { rs_line-origin_run_id }/{ rs_line-origin_line_num } no esta en CONT|.
        ENDIF.

      " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
      " Hardening only -- unreachable today: the three strategies return
      " either 'B1' (CM) or 'B2' (DEFER/AN2), never ROW_TYPE-REAL ('A').
      " Without this branch a future strategy returning any other mode
      " would silently emit a degraded "Base : {amount}" with no source
      " tag. The raw expand mode is used as the tag so the step stays
      " self-diagnosing instead of anonymous. No other behaviour is added:
      " RS_LINE keeps whatever CORRESPONDING built, exactly as before.
      WHEN OTHERS.
        lv_base_src = lv_expand_mode.
      " End Insert V019 (17.09.2026 | EXT_GONZALCA)
    ENDCASE.

    rs_line-base_amt = lo_strategy->load_base( rs_line ).

    " DEVELOPER GAP-FIX: neither the spec nor the blueprint say who sets
    " EXCH_RATE_TYPE on the line before step_05 reads it — SS E.7's
    " pseudo-code assumes it is "just there". The strategy contract already
    " exposes fx_rate_type() for exactly this purpose (SS6.6/6.7/6.8), so it
    " is applied here, once, right after BASE_AMT. For B2 this simply
    " reconfirms the constant the PEND row should already carry (H/P).
    rs_line-exch_rate_type = lo_strategy->fx_rate_type( rs_line ).

    " Begin Mod V005 (07.09.2026 | EXT_GONZALCA)
    " Original block, replaced by the explicit validation below - the
    " CT_CURRENCY fallback moved INTO the cm_pending branch, where the
    " contract header currency is available (see Insert V005 above):
    "    " Same gap for CT_CURRENCY on a freshly-built B1 generic line (B2
    "    " already has it from the PEND row read above) — CT2_OPT_A.waers is
    "    " the contract-level currency, receptor-independent, already reachable
    "    " via get_ct_option (used for the very same op_uuid by the CM
    "    " strategy's own fx_rate_type). LOCAL_CURRENCY cannot be resolved here
    "    " (it depends on BUKRS_RECV, only known after step_02 expansion) — see
    "    " step_02_distribute and code-summary.md.
    "    IF rs_line-ct_currency IS INITIAL.
    "      rs_line-ct_currency = mo_sources->get_ct_option( iv_op_uuid = rs_line-op_uuid )-waers.
    "    ENDIF.
    "
    " CT_CURRENCY must be resolved by now: B1 takes it from the contract
    " header (block inside WHEN cm_pending above), B2 inherits it from the
    " PEND row read out of it_pend_scope.
    " ls_identity is deliberately NOT used here: ABAP inline declarations are
    " method-scoped, not block-scoped, so it would still be readable but
    " EMPTY for a B2 line - the value would silently depend on which branch
    " ran. B2 does not call get_ct_identity on purpose either: a PEND row
    " without CT_CURRENCY is an upstream data defect, and re-reading the
    " contract per line would both cost a read and add a new failure mode
    " (get_ct_identity raises on an unresolvable ct_uuid/mat_uuid pair).
    " Failing here, explicitly, replaces the misleading downstream symptom
    " ("Sin tasa promedio 'ICRG' para /MXN in 20260907") with the real cause.
    " The exception propagates to execute()'s TRY ... CATCH
    " zcx_reing_ca_calc_error, which marks the line CALC_ERR and keeps
    " processing the remaining groups (contract P-07).
    " LOCAL_CURRENCY cannot be validated here - it depends on BUKRS_RECV,
    " only known after step_distribute's expansion; it is validated in
    " step_fx, where it is first used.
    IF rs_line-ct_currency IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |Contrato { rs_line-ct_id } sin moneda: informar la moneda en la cabecera del | &&
          |contrato (ZREING_CT2_A-WAERS, ct_uuid { rs_line-ct_uuid })|.
    ENDIF.
    " End Mod V005 (07.09.2026 | EXT_GONZALCA)

    " Temporary STEP_A on the generic line (SS E.3) — stashed on
    " mt_validate_step because this method has no ct_steps parameter of
    " its own (see class header note). step_02_distribute picks it up,
    " replicates it to every expanded line, then discards the original.
    CLEAR mt_validate_step.
    record_step( EXPORTING iv_line_num = rs_line-line_num
                           iv_step_num = '01'
                           iv_seq      = '01'
                           iv_category = zif_reing_ca_c=>step_category-validate
                           " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                           iv_desc     = |Base { lv_base_src }: | &&
                                         |{ rs_line-base_amt DECIMALS = 2 } | &&
                                         |{ rs_line-ct_currency }|
                           " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                           iv_input    = rs_line-base_amt
                           iv_output   = rs_line-base_amt
                           iv_sign     = '='
                           " Insert V019 (17.09.2026 | EXT_GONZALCA): ET SS7.4 gives VALIDATE a source
                           " table per path (CM_H_A vs. the parent LINE_A);
                           " it was left empty for every path until now.
                           iv_source_table = COND ty_source_table(
                                               WHEN lv_base_src = 'CM'
                                               THEN 'ZREING_CM_H_A'
                                               ELSE 'ZREING_CA_LINE_A' )
                 CHANGING  ct_steps    = mt_validate_step ).
  ENDMETHOD.
  METHOD step_distribute.
    TYPES ty_bukrs_range TYPE RANGE OF bukrs.
    DATA(ls_generic)          = ct_lines[ 1 ].
    DATA(lv_generic_line_num) = ls_generic-line_num.

    APPEND LINES OF mt_validate_step TO ct_steps.
    CLEAR mt_validate_step.

    " Begin Mod V020 (18.09.2026 | EXT_GONZALCA)
    " BR-CA-05 (credit-note sign inversion, x -1) is REMOVED.
    "
    " ET-REING-CA-001 v50 strikes out the ENTIRE BR-CA-05 row of the
    " Business Rules table (SS8), with no green replacement text. Verified
    " run by run on the .docx: all 4 cells of that row are red FF0000 with
    " strike, including the "step_distribute" cell that in the neighbouring
    " BR-CA-02 row is green 008000. So SAP first did the method rename
    " (step_02 -> step_distribute) and only THEN deleted the whole rule:
    " the removal is deliberate, not a drafting slip.
    "
    " The data backs it: the premise of the rule was "if OP_TYPE has
    " IS_NC = X", and ZREING_OP_TYPE_C HAS NO IS_NC field -- verified on
    " DS4-200 and on TS4-400. The rule pointed at a non-existent field; the
    " code resolved it by another route (is_credit_note( ), which dispatches
    " by OP_TYPE class and only returns true for 'NC').
    "
    " INTENDED SIDE EFFECT: it closes a defect of our own recorded in
    " reing-delta-v2-prgi/SEGUIMIENTO.md (2026-08-31 block). The BR-CA-44
    " renormalization further down recalculates CALC_AMT without reapplying
    " the inversion, which left it inconsistent with the two branches that
    " did apply it: if an NC came in with a receptor filter in
    " ZREING_CM_RECV_A, the amount was posted with the sign flipped. With no
    " inversion at all the inconsistency disappears, and the pending 2-line
    " fix noted there IS NOW VOID.
    "
    " LO_STRATEGY is removed together with LV_IS_NC because in this method
    " its ONLY use was to obtain that flag. No validation is lost: the only
    " exception get_instance_from_cache( ) can raise is the OP_TYPE cache
    " miss, and step_validate already ran it for the SAME op_type
    " immediately before, inside execute( ).
    "
    " ZIF_REING_CA_OPTYPE~IS_CREDIT_NOTE is NOT touched, nor its 3
    " implementations (CM / DEFER / AN2) nor their unit tests: they remain
    " part of the strategy contract. They are left with no productive
    " caller -- reported, out of scope for this fix.
    "
    " Original statements, for the record:
    "    " ATC fix: reemplaza get_instance por get_instance_from_cache (CERO SELECT).
    "    DATA(lo_strategy) = zcl_reing_ca_optype_factory=>get_instance_from_cache(
    "                           iv_op_type = ls_generic-op_type
    "                           io_sources = mo_sources
    "                           is_context = ms_context ).
    "    DATA(lv_is_nc) = lo_strategy->is_credit_note( ls_generic ).
    " End Mod V020 (18.09.2026 | EXT_GONZALCA)

    IF ls_generic-bukrs_recv IS NOT INITIAL.
      " Pass-through (D/AN2 inherit the receptor from the parent, BR-CA-02).
      " V001 (CC): keep every physical seed in the group. The previous code
      " operated only on CT_LINES[ 1 ] and then replaced CT_LINES with that
      " singleton, leaving the other receiving companies in CALC_PROC.
      LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_pass>).
        <ls_pass>-calc_amt = <ls_pass>-base_amt.

        record_step(
          EXPORTING iv_line_num     = <ls_pass>-line_num
                    iv_step_num     = '02'
                    iv_seq          = '01'
                    iv_category     = zif_reing_ca_c=>step_category-distribute
                    iv_desc         = |Per-receptora (heredado de padre) | &&
                                      |-> { <ls_pass>-bukrs_recv }|
                    iv_input        = <ls_pass>-base_amt
                    iv_rate         = 1
                    iv_output       = <ls_pass>-calc_amt
                    iv_sign         = '='
                    iv_source_table = '(padre)'
          CHANGING  ct_steps        = ct_steps ).
      ENDLOOP.

      " No replicate_steps/DELETE here: pass-through lines retain their
      " physical line numbers, so their VALIDATE steps are already aligned.
      " V010: SHARE_PAIS_PCT / SHARE_COMB_PCT are deliberately NOT computed in
      " this branch -- see the note at the end of the expansion branch below.

    ELSE.
      " Expansion per receptor (Path A / CM, BR-CA-02).
      " Begin Mod V006 (08.09.2026 | EXT_GONZALCA)
      " Descripcion : los shares se leian con el periodo del RUN, mientras
      " step_pc_split ya los leia con ME_PERIOD_OFFSET (BR-CA-40). Con un
      " contrato con offset '01' eso producia el defecto reportado por
      " funcional (08.09.2026, IC-0001/ICSRV44, periodo 02/2026): el importe
      " de la linea se calculaba con el share de M (38,709755% para DRM)
      " cuando correspondia el de M-1 (39,047732%) -- desvios por receptora
      " de -6,16% a +11,16%, con el total conservado, o sea un error de
      " REPARTO entre sociedades que los totales no delatan.
      " Efecto colateral que se cierra con el mismo cambio: numerador
      " (share_abs de M-1) y denominador (SHARE_PCT de M) del ratio de
      " step_pc_split dejan de pertenecer a periodos distintos, con lo que
      " SUM(ratios) vuelve a ser 1 exacto.
      " NOTA DE ESPECIFICACION: BR-CA-40 nombra unicamente step_pc_split, y
      " el pseudo-codigo de ET-REING-CA-001 v50 SS7.6 usa el periodo del run
      " aqui -- o sea que la ET ESPECIFICA la mezcla M/M-1 y el codigo hacia
      " lo que la ET decia. Este cambio la corrige por definicion funcional
      " (pedido de funcional del 08.09.2026); actualizar BR-CA-40 y SS7.6 en
      " la ET corresponde al arquitecto, no a este desarrollo.
      " Linea original conservada como referencia:
      "    iv_period_year  = ms_context-year
      "    iv_period_month = ms_context-period
      DATA lv_me_month_d TYPE zreing_me_h_a-period_month.
      DATA lv_me_year_d  TYPE zreing_me_h_a-period_year.
      resolve_me_period( EXPORTING iv_op_uuid      = ls_generic-op_uuid
                         IMPORTING ev_period_month = lv_me_month_d
                                   ev_period_year  = lv_me_year_d ).

      DATA(lt_shares) = mo_sources->get_me_shares(
                           iv_ct_id        = ls_generic-ct_id
                           iv_matnr        = ls_generic-matnr
                           iv_period_year  = lv_me_year_d
                           iv_period_month = lv_me_month_d ).
      " End Mod V006 (08.09.2026 | EXT_GONZALCA)

      " Aggregate SHARE_PCT by receptor in memory (F2-DD-1 — not the F1
      " CDS, to keep the pipeline mockable via ZIF_REING_CA_SOURCES).
      TYPES: BEGIN OF ty_share_agg,
               bukrs     TYPE bukrs,
               share_pct TYPE zreing_ca_line_a-share_pct,
             END OF ty_share_agg.
      DATA lt_agg TYPE STANDARD TABLE OF ty_share_agg WITH EMPTY KEY.

      " Iteration #5 (activation ERR-002, line 350): COLLECT requires all
      " non-key fields to be numeric once a table declares an explicit key
      " (even WITH EMPTY KEY disables the legacy "characters=key" magic)
      " — BUKRS is CHAR, so COLLECT was rejected outright. Manual
      " find-or-append aggregation instead.
      LOOP AT lt_shares INTO DATA(ls_share).
        ASSIGN lt_agg[ bukrs = ls_share-bukrs ] TO FIELD-SYMBOL(<ls_agg>).
        IF sy-subrc = 0.
          <ls_agg>-share_pct = <ls_agg>-share_pct + ls_share-share_pct.
        ELSE.
          APPEND VALUE ty_share_agg( bukrs = ls_share-bukrs share_pct = ls_share-share_pct ) TO lt_agg.
        ENDIF.
      ENDLOOP.

      " Begin Change ID V018 (18.07.2026 | EXT_GONZALCA)
      " Fix CRITICO: el REDUCE original -- "REDUCE zreing_ca_line_a-share_pct(
      " INIT s = 0 FOR ls_a IN lt_agg NEXT s = s + ls_a-share_pct )" -- infiere
      " el tipo del acumulador "s" del LITERAL "0" (TYPE I, entero), NO del
      " tipo declarado tras REDUCE. Confirmado con el error real de
      " activacion al agregar un segundo REDUCE con "INIT s = ...": "S" was
      " already declared with the type "I". Consecuencia: cada suma
      " intermedia se redondeaba a entero (no solo el resultado final),
      " acumulando error de redondeo en cada iteracion -- verificado a mano
      " con datos reales de ZREING_ME_I_A (IC-0007/ICSRV44, periodo 2026/01):
      " los 11 grupos por BUKRS suman EXACTAMENTE 100,000000% en precision
      " completa, pero el redondeo entero paso a paso (25,28,29,30,31,35,
      " 36,43,...) terminaba dando 101 -- el bug real detras del mensaje
      " "Shares ME no suman 100%: 101.000000" (el dato NUNCA estuvo mal).
      " Se reemplaza por un LOOP con variable correctamente tipada
      " share_pct (DEC9,6), sin pasar por la inferencia de tipo de REDUCE.
      DATA lv_total_pct TYPE zreing_ca_line_a-share_pct.
      LOOP AT lt_agg INTO DATA(ls_agg_tot).
        lv_total_pct = lv_total_pct + ls_agg_tot-share_pct.
      ENDLOOP.
      " End Change ID V018 (18.07.2026 | EXT_GONZALCA)
      IF lv_total_pct <> 100.
        " Mod V006: el mensaje ahora dice CON QUE PERIODO se leyeron los
        " shares -- con offset activo, el periodo del error no es el del run
        " y sin este dato el analisis del dato de ME arranca en la tabla
        " equivocada.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message =
            |Shares ME no suman 100% para { ls_generic-ct_id }/{ ls_generic-matnr } | &&
            |en el periodo de metrica { lv_me_month_d }/{ lv_me_year_d }: { lv_total_pct }|.
      ENDIF.

      CLEAR ct_lines.
      DATA(lv_new_line_num) = CONV zreing_ca_line_a-line_num( 0 ).

      " Cache I_COMPANYCODE desde atributo mt_bukrs_cache (pre-cargado en execute
      " antes del LOOP AT it_scope -- ATC fix: SELECT eliminado de step_distribute).
      " mt_bukrs_cache contiene todos los company codes; se filtra en memoria por bukrs_recv.

      LOOP AT lt_agg INTO DATA(ls_recv).
        lv_new_line_num = lv_new_line_num + 1.   " F3 pre-assigns the real range under lock (P-05).

        DATA(ls_new) = ls_generic.
        ls_new-line_num   = lv_new_line_num.
        ls_new-bukrs_recv = ls_recv-bukrs.
        ls_new-share_pct  = ls_recv-share_pct.
        ls_new-calc_amt   = ls_generic-base_amt * ls_recv-share_pct / 100.

        " LOCAL_CURRENCY y COUNTRY desde atributo pre-cargado mt_bukrs_cache.
        IF ls_new-local_currency IS INITIAL OR ls_new-country IS INITIAL.
          ASSIGN mt_bukrs_cache[ bukrs = ls_new-bukrs_recv ] TO FIELD-SYMBOL(<ls_cc>).
          IF sy-subrc = 0.
            ls_new-country        = <ls_cc>-country.
            ls_new-local_currency = <ls_cc>-currency.
          ENDIF.
        ENDIF.

        " Begin Mod V020 (18.09.2026 | EXT_GONZALCA)
        " BR-CA-05 removed -- see the note at the start of the method.
        " Original statements, for the record:
        "    IF lv_is_nc = abap_true.
        "      ls_new-calc_amt = ls_new-calc_amt * -1.  " BR-CA-05
        "    ENDIF.
        " End Mod V020 (18.09.2026 | EXT_GONZALCA)

        record_step( EXPORTING iv_line_num     = lv_new_line_num
                               iv_step_num     = '02'
                               iv_seq          = '01'
                               iv_category     = zif_reing_ca_c=>step_category-distribute
                               " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                               " ET SS7.4/SS7.6 expansion text, plus the
                               " RATE_DESC formula of SS4.4 ("125000 x 0.23").
                               iv_desc         = |x { ls_recv-share_pct DECIMALS = 4 }% | &&
                                                 |-> { ls_recv-bukrs }|
                               iv_rate_desc    = |{ ls_generic-base_amt DECIMALS = 2 } | &&
                                                 |x { ls_recv-share_pct DECIMALS = 4 }%|
                               " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                               iv_input        = ls_generic-base_amt
                               iv_rate         = ls_recv-share_pct / 100
                               iv_output       = ls_new-calc_amt
                               iv_sign         = '='
                               iv_source_table = 'ZREING_ME_I_A'
                     CHANGING  ct_steps        = ct_steps ).

        " Iteration #5 (activation ERR-002, line 407): "Unable to
        " interpret CHANGING" — a call mixing IMPORTING and CHANGING
        " parameters needs the EXPORTING keyword explicit; it cannot be
        " omitted here the way it can for calls with only one kind of
        " parameter block.
        replicate_steps( EXPORTING iv_from_line = lv_generic_line_num
                                    iv_to_line   = lv_new_line_num
                          CHANGING  ct_steps     = ct_steps ).

        APPEND ls_new TO ct_lines.
      ENDLOOP.

      " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA)
      " Descripcion : Delta v2 CA-08 (BR-CA-44) -- filtro de receptoras
      " participantes. Si ZREING_CM_RECV_A tiene entradas para el CM
      " elegible de este grupo, solo se retienen las lineas cuya
      " BUKRS_RECV este en esa lista (tipico ANT/ANT2, adiantamentos
      " parciales). Tabla vacia = sin restriccion, comportamiento actual.
      " Iteration fix (activation): NOT IN sobre una tabla simple
      " (TY_BUKRS_T) no es valido -- IN/NOT IN requieren una tabla de
      " rangos (RANGE OF bukrs). Se construye el rango en memoria antes
      " de filtrar.
      DATA(lt_recv_filter) = mo_sources->get_cm_recv_filter(
                                iv_ct_uuid  = ls_generic-ct_uuid
                                iv_mat_uuid = ls_generic-mat_uuid
                                iv_op_type  = ls_generic-op_type
                                iv_period   = ms_context-period
                                iv_year     = ms_context-year
                                iv_cm_h_id  = ls_generic-cm_h_id ).
      IF lt_recv_filter IS NOT INITIAL.
        DATA lt_recv_range TYPE ty_bukrs_range.
        lt_recv_range = VALUE #(
          FOR lv_bukrs IN lt_recv_filter
          ( sign = 'I' option = 'EQ' low = lv_bukrs ) ).
        LOOP AT ct_lines INTO DATA(ls_excluded) WHERE bukrs_recv NOT IN lt_recv_range.
          DELETE ct_steps WHERE line_num = ls_excluded-line_num.
        ENDLOOP.
        DELETE ct_lines WHERE bukrs_recv NOT IN lt_recv_range.

        " Begin Change (28.08.2026 | EXT_AGFAGINA) - BR-CA-44 redistribucion
        " Definicion funcional (pedido 28.08.2026): designar un subconjunto de
        " receptoras como participantes REDEFINE el universo del calculo para ese
        " anticipo: el reparto debe ser del 100% entre las participantes.
        " Antes: se filtraba DESPUES de calcular calc_amt con el share original y
        " NO se redistribuia -> el resto quedaba sin imputar, en silencio
        " (5 receptoras al 20%, participantes 2 => solo se contabilizaba el 40%).
        " Ahora: se renormaliza el share de cada participante en proporcion a su
        " share original, de modo que sumen 100% entre ellas, y se recalcula
        " calc_amt. Tambien se actualiza el paso DISTRIBUTE de la memoria de
        " calculo (rate_pct/output_amt) para que la trazabilidad no quede stale.
        " NOTA V006 (08.09.2026): esta renormalizacion pisa SHARE_PCT de la linea
        " sin tocar el numerador que step_pc_split lee de ME, de modo que para
        " ANT/AN2 con filtro de receptoras el ratio de la apertura queda
        " desalineado aunque ambos periodos coincidan. Pendiente de resolver
        " junto con la regla funcional de BR-CA-44 (escalado 08.09.2026).
        " NOTE V020 (18.09.2026): the other inconsistency of this block -- that
        " it recalculated CALC_AMT without reapplying the BR-CA-05 sign
        " inversion -- no longer exists: BR-CA-05 was removed from ET v50 and
        " from the code.
        DATA lv_share_sum TYPE zreing_percent_9_6.
        CLEAR lv_share_sum.
        LOOP AT ct_lines INTO DATA(ls_share_sum).
          lv_share_sum = lv_share_sum + ls_share_sum-share_pct.
        ENDLOOP.

        IF lv_share_sum > 0.
          " 1) Renormalizar lineas (loop simple, sin anidar).
          LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_redis>).
            <ls_redis>-share_pct = <ls_redis>-share_pct * 100 / lv_share_sum.
            <ls_redis>-calc_amt  = ls_generic-base_amt * <ls_redis>-share_pct / 100.
          ENDLOOP.

          " 2) Propagar a la memoria de calculo en un loop SEPARADO (no anidado,
          "    ATC CL_CI_TEST_SCAN_NESTED): se busca por clave con BINARY SEARCH
          "    sobre una copia ordenada de las lineas ya renormalizadas.
          DATA(lt_redis_vals) = ct_lines.
          SORT lt_redis_vals BY line_num.

          LOOP AT ct_steps ASSIGNING FIELD-SYMBOL(<ls_step_redis>)
               WHERE step_category = zif_reing_ca_c=>step_category-distribute.
            READ TABLE lt_redis_vals INTO DATA(ls_redis_val)
                 WITH KEY line_num = <ls_step_redis>-line_num BINARY SEARCH.
            IF sy-subrc = 0.
              <ls_step_redis>-rate_pct   = ls_redis_val-share_pct / 100.
              <ls_step_redis>-output_amt = ls_redis_val-calc_amt.
            ENDIF.
          ENDLOOP.
        ENDIF.
        " End Change (28.08.2026 | EXT_AGFAGINA)
      ENDIF.
      " End Change ID V002 (03.08.2026 | EXT_GONZALCA)

      " Begin Insert V010 (15.09.2026 | EXT_GONZALCA)
      " Bug tracker #66 -- SHARE_PAIS_PCT and SHARE_COMB_PCT were NEVER written.
      "
      " Verified on TS4-400 (RUN-202602 / IC-0008 / ICSRV45): all 14 lines carry
      " 0,000000 in both fields, so the defect is systematic, not one line. A
      " grep over this class found the two names exactly ONCE -- in the field
      " list of the SELECT in execute -- with no assignment anywhere, and DD03L
      " confirms they exist ONLY in ZREING_CA_LINE_A, i.e. there is no metric
      " column to copy from: they have to be computed.
      "
      " ET-REING-CA-001 v50 (SS9.2 column table, SS9.3 detail panel and SS12
      " export) specifies both, and marks them "Siempre visible":
      "   SHARE_PAIS_PCT = "Suma de shares de todas las receptoras del mismo
      "                     pais dentro del grupo."
      "   SHARE_COMB_PCT = "SHARE_PCT / SHARE_PAIS_PCT x 100. Peso relativo
      "                     dentro del pais."
      "
      " The rule was already implemented -- but only for the OTHER branch. In
      " ZI_ReingCALineAll the PEND branches compute both from
      " ZI_ReingCAMeShareByCountry (MC.SharePctPais) with this very formula,
      " while the REAL branch reads LA.share_pais_pct / LA.share_comb_pct from
      " the table. Hence what the user sees: a pending line shows the shares and
      " the SAME line shows 0,000000 once calculated. It is a visible regression
      " inside one list, which is why it was reported as "no esta completado".
      "
      " WHY HERE, and why at this exact point:
      "  - This is where the group's receptors and their shares are all known at
      "    once, which is what "dentro del grupo" requires.
      "  - It runs AFTER the BR-CA-44 renormalization above, deliberately. That
      "    block OVERWRITES share_pct of every surviving line (participating
      "    receptors are re-based to sum 100%). Computing the country totals
      "    before it would leave both fields derived from shares that no longer
      "    exist on the line.
      "  - COUNTRY comes from mt_bukrs_cache, already pre-loaded in execute from
      "    I_CompanyCode -- zero additional SELECT, and no T001 (Clean Core).
      "
      " PRECISION -- this is the fourth instance of the same trap in this module
      " (see V018 above, Mod V006 in step_pc_split, and the COLLECT of
      " ZBP_REINGMEHEADER~calcularshare). Dividing two DEC(9,6) makes ABAP infer
      " P(8,0) for the result: NO DECIMALS. A share of 27,989500 over a country
      " total of 30,345000 would be stored as 1 instead of 92,217828. The CONV
      " decfloat34 on the numerator is what keeps the quotient a real number;
      " the assignment to the DEC(9,6) target field does the only rounding.
      " The country total is likewise accumulated in a properly typed variable,
      " never with REDUCE ... INIT s = 0, whose accumulator takes its type from
      " the literal (see V018).
      "
      " Verifiable with the reported run: the 14 receptors group into
      " BR 30,3450 (DAB+EBA+MLB+MPB+KGB) / UY 6,7911 / CO 22,5808 / AR 33,7002 /
      " CL 3,5297 / MX 3,0532, which sum to exactly 100,000000. For DAB:
      " 27,9895 / 30,3450 x 100 = 92,2178.
      "
      " SCOPE -- two cases deliberately NOT covered here, both reported:
      "  - The pass-through branch (Path B/C: D and AN2 inherit the receptor from
      "    the parent). A single-receptor group would trivially yield
      "    SHARE_PAIS_PCT = SHARE_PCT and SHARE_COMB_PCT = 100, but the PEND
      "    branch of ZI_ReingCALineAll INHERITS both from PARENT_LINE for
      "    deferrals instead of recomputing them, so the correct rule there is a
      "    functional question, not a copy of this formula. Left untouched.
      "  - Lines that step_delta CREATES afterwards (new receptors and the
      "    BR-CA-43 reversal rows) never pass through this method, so they keep
      "    0,000000. Fixing that means running the same aggregation again after
      "    step_delta, which changes more than this bug asked for.
      TYPES: BEGIN OF ty_pais_agg,
               country   TYPE land1,
               share_pct TYPE zreing_ca_line_a-share_pct,
             END OF ty_pais_agg.
      DATA lt_pais TYPE SORTED TABLE OF ty_pais_agg WITH UNIQUE KEY country.

      " 1) Total por pais. Find-or-insert por clave (expresion de tabla sobre
      "    tabla SORTED = acceso binario), no un LOOP anidado: ese es el
      "    hallazgo P2 del ATC que bloquea la liberacion a Calidad.
      LOOP AT ct_lines INTO DATA(ls_pais_src).
        ASSIGN lt_pais[ country = ls_pais_src-country ] TO FIELD-SYMBOL(<ls_pais>).
        IF sy-subrc = 0.
          <ls_pais>-share_pct = <ls_pais>-share_pct + ls_pais_src-share_pct.
        ELSE.
          INSERT VALUE ty_pais_agg( country   = ls_pais_src-country
                                    share_pct = ls_pais_src-share_pct ) INTO TABLE lt_pais.
        ENDIF.
      ENDLOOP.

      " 2) Asignacion a cada linea, en un LOOP SEPARADO del de agregacion.
      LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_shr>).
        ASSIGN lt_pais[ country = <ls_shr>-country ] TO FIELD-SYMBOL(<ls_pais_tot>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        <ls_shr>-share_pais_pct = <ls_pais_tot>-share_pct.
        IF <ls_pais_tot>-share_pct <> 0.
          <ls_shr>-share_comb_pct =
            CONV decfloat34( <ls_shr>-share_pct ) / <ls_pais_tot>-share_pct * 100.
        ELSE.
          " Guard del denominador, igual que el "MC.SharePctPais <> 0" de la
          " rama PEND de ZI_ReingCALineAll. Aplica al PAIS, no a la receptora:
          " una receptora con share 0 dentro de un pais con total > 0 da
          " SHARE_COMB_PCT = 0, que es el valor correcto.
          <ls_shr>-share_comb_pct = 0.
        ENDIF.
      ENDLOOP.
      " End Insert V010 (15.09.2026 | EXT_GONZALCA)

      " The generic line's own VALIDATE step was already replicated to
      " every expansion above — discard the original now (SS E.4/E.9): no
      " orphaned STEP_A rows survive. Only relevant to this branch: the
      " pass-through branch never renumbers the line, so its VALIDATE step
      " was never duplicated and must not be deleted.
      DELETE ct_steps WHERE line_num = lv_generic_line_num AND step_num = '01' AND seq = '01'.
    ENDIF.
  ENDMETHOD.
  METHOD step_gross_up.
    " Begin Insert V010 (17.09.2026 | EXT_GONZALCA)
    " TAX_AMT se inicializa AQUI y ya no en step_tax: desde este fix el paso
    " de gross-up tambien emite pasos TAX (ver el bloque del final) y
    " step_tax sigue acumulando sobre ese total. Si la inicializacion se
    " quedara en step_tax, borraria los importes de gross-up.
    cs_line-tax_amt = 0.
    " End Insert V010 (17.09.2026 | EXT_GONZALCA)

    DATA(lt_allowed) = mo_sources->get_gl_tax_types( iv_ct_uuid = cs_line-ct_uuid iv_mat_uuid = cs_line-mat_uuid ).
    IF lt_allowed IS INITIAL.
      cs_line-bruto_amt    = cs_line-calc_amt.
      cs_line-gross_up_amt = 0.
      RETURN.
    ENDIF.

    " ATC fix (NonLocal DBREAD): reemplaza SELECT FROM zreing_tx_type_c por
    " filtrado en ABAP sobre mt_tx_type_cache (pre-cargado en execute).
    " lt_allowed es string_table -- cada fila es un tax_type escalar.
    " Begin Mod V010 (17.09.2026 | EXT_GONZALCA)
    " El ruteo GU / non-GU ya NO mira GROSS_UP_DEFAULT del catalogo
    " (ZREING_TX_TYPE_C): manda la marca GROSS_UP de la REGLA
    " (ZREING_TX_RULE_A), que es lo que dice la ET (SS7.8 paso 1 y SS7.9) y lo
    " que el operador ve y edita en Reglas Fiscales. GROSS_UP_DEFAULT no
    " aparece en ninguna de las cuatro ET; el filtro venia de la spec interna
    " F2 (SSE.5 punto 2 / SSE.6).
    " Cuando los dos datos no coincidian el impuesto quedaba en un limbo, en
    " los DOS sentidos:
    "  - regla SIN X sobre un tipo con GROSS_UP_DEFAULT = 'X' (WHT es el unico
    "    asi, verificado en DS4 y TS4): no entraba al gross-up porque la regla
    "    no lo pide, y tampoco a step_tax porque el catalogo lo trataba como
    "    GU -> TAX_AMT = 0. Bug reportado por Rochelle el 17.09.2026 sobre
    "    TX-UY-WHT-001 (12%), RUN-202602 / IC-0008 linea 0000570 (TS4-400).
    "  - regla CON X sobre un tipo con el default vacio (existe en DS4:
    "    TX-BR-PIS-001, PIS 25% con X): el gross-up se ignoraba en silencio.
    " Se conserva la verificacion de existencia en el cache, que ademas
    " implica "tipo activo": execute() precarga mt_tx_type_cache filtrando
    " ACTIVE = 'X'. El catalogo queda como valor sugerido al crear una regla.
    " Statement original, para el registro:
    "      IF line_exists( mt_tx_type_cache[ tax_type         = lv_tax_type_g
    "                                        gross_up_default = abap_true ] ).
    DATA lt_gu_types TYPE STANDARD TABLE OF zreing_tx_type_c WITH EMPTY KEY.
    DATA lv_tax_type_g LIKE LINE OF lt_allowed.
    DATA lv_idx_al_g TYPE i VALUE 1.
    DO lines( lt_allowed ) TIMES.
      READ TABLE lt_allowed INTO lv_tax_type_g INDEX lv_idx_al_g.
      IF line_exists( mt_tx_type_cache[ tax_type = lv_tax_type_g ] ).
        APPEND VALUE zreing_tx_type_c( tax_type = lv_tax_type_g ) TO lt_gu_types.
      ENDIF.
      lv_idx_al_g = lv_idx_al_g + 1.
    ENDDO.
    " End Mod V010 (17.09.2026 | EXT_GONZALCA)

    IF lt_gu_types IS INITIAL.
      cs_line-bruto_amt    = cs_line-calc_amt.
      cs_line-gross_up_amt = 0.
      RETURN.
    ENDIF.

    DATA(lt_rules)    = mo_sources->get_tx_rules( iv_country = cs_line-country iv_gross_up = abap_true ).
    DATA(lv_ref_date) = last_day_of_period( iv_fiscal_period = ms_context-period iv_fiscal_year = ms_context-year ).

    " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
    " ET-REING-BR-001 v5 SS4.6/SS4.9 -- COUNTRY_PREST, el sexto criterio del
    " motor de especificidad.
    " La ET dice derivarlo de T001(BUKRS_PREST).LAND1 y cachearlo en
    " set_context. Ninguna de las dos cosas es posible tal como esta escrito:
    " T001 esta bloqueada por Clean Core en este sistema (la lectura se migro
    " a I_CompanyCode) y no hay metodo set_context -- el contexto llega por el
    " constructor. Igual no cuesta nada: execute() ya precarga mt_bukrs_cache
    " desde I_CompanyCode para TODAS las sociedades (fix de ATC por NonLocal
    " DBREAD), asi que esto es una lectura en memoria sin SELECT extra.
    DATA lv_country_prest TYPE land1.
    lv_country_prest = VALUE #( mt_bukrs_cache[ bukrs = cs_line-bukrs_prest ]-country OPTIONAL ).
    " End Insert V009 (15.09.2026 | EXT_GONZALCA)

    DATA lv_total_rate  TYPE zreing_ca_step_a-rate_pct VALUE 0.
    DATA lt_winning_ids TYPE STANDARD TABLE OF zreing_ca_step_a-tx_rule_id WITH EMPTY KEY.
    " Begin Insert V010 (17.09.2026 | EXT_GONZALCA)
    " Las reglas GU ganadoras completas (tax_type + rate), no solo sus ids:
    " el bloque del final necesita la tasa de CADA una para emitir su paso
    " TAX. Es una tabla local a proposito -- no hace falta un atributo de
    " instancia ni tocar la DEFINITION de la clase.
    DATA lt_gu_win TYPE zif_reing_ca_types=>ty_tx_rule_t.
    " End Insert V010 (17.09.2026 | EXT_GONZALCA)

    LOOP AT lt_gu_types INTO DATA(ls_gu_type).
      DATA(lt_candidates) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
                               FOR ls_r IN lt_rules WHERE ( tax_type = ls_gu_type-tax_type ) ( ls_r ) ).
      " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
      " Cuatro criterios nuevos viajan al motor de scoring (SS4.9: "La logica
      " interna de step_gross_up y step_tax NO cambia. Solo cambia la
      " resolucion de CUAL regla aplica"). COUNTRY es ahora uno de ellos:
      " antes era un filtro WHERE obligatorio en get_tx_rules, de modo que
      " todo candidato lo cumplia por construccion y el motor nunca tenia que
      " mirarlo.
      " Llamada original, para el registro:
      "    DATA(ls_winner) = mo_tx_scoring->find_best_rule(
      "                         it_rules    = lt_candidates
      "                         iv_lifnr    = cs_line-lifnr
      "                         iv_matnr    = cs_line-matnr
      "                         iv_ref_date = lv_ref_date ).
      DATA(ls_winner) = mo_tx_scoring->find_best_rule(
                           it_rules         = lt_candidates
                           iv_lifnr         = cs_line-lifnr
                           iv_matnr         = cs_line-matnr
                           iv_ref_date      = lv_ref_date
                           iv_country       = cs_line-country
                           iv_country_prest = lv_country_prest
                           iv_bukrs_prest   = cs_line-bukrs_prest
                           iv_bukrs_recv    = cs_line-bukrs_recv ).
      " End Mod V009 (15.09.2026 | EXT_GONZALCA)
      IF ls_winner IS NOT INITIAL.
        lv_total_rate = lv_total_rate + ls_winner-rate.
        APPEND ls_winner-tx_rule_id TO lt_winning_ids.
        APPEND ls_winner TO lt_gu_win.                      "V010
      ENDIF.
    ENDLOOP.

    IF lt_winning_ids IS INITIAL.
      cs_line-bruto_amt    = cs_line-calc_amt.
      cs_line-gross_up_amt = 0.
      " Begin Mod V010 (17.09.2026 | EXT_GONZALCA)
      " El registro del cero deja de ser exclusivo del descarte
      " intra-sociedad (V009, bug #69). Rochelle pidio el 17.09.2026 que la
      " Secuencia de Calculo no saltee del paso 2 al 4: cuando el pais no
      " tiene ninguna regla de gross-up vigente -- el caso normal desde que
      " se le quito la X a las reglas de WHT de Uruguay -- el paso 03 se
      " registra igual, con tasa 0 y diciendo por que.
      " Los dos early exits de arriba (contrato sin tipos de impuesto GL en
      " CT2_GL_A, o ninguno activo en el catalogo) siguen sin registrar: ahi
      " no hay ninguna regla fiscal en juego que explicar, y trazarlos
      " agregaria una fila de STEP_A a casi toda linea.
      " El tipo tiene que ser el del campo, no STRING: IV_DESC se pasa por
      " referencia y una variable STRING no es type-compatible (la activacion
      " lo rechaza; una expresion inline si se acepta).
      DATA lv_gu_desc TYPE zreing_ca_step_a-step_desc.
      IF cs_line-bukrs_prest IS NOT INITIAL
         AND cs_line-bukrs_prest = cs_line-bukrs_recv.
        lv_gu_desc = |Sin gross-up: operacion intra-sociedad { cs_line-bukrs_prest }|.
      ELSE.
        lv_gu_desc = |Sin gross-up: sin reglas vigentes para { cs_line-country }|.
      ENDIF.
      record_step( EXPORTING iv_line_num     = cs_line-line_num
                             iv_step_num     = '03'
                             iv_seq          = '01'
                             iv_category     = zif_reing_ca_c=>step_category-gross_up
                             iv_desc         = lv_gu_desc
                             iv_input        = cs_line-calc_amt
                             iv_rate         = 0
                             iv_output       = cs_line-calc_amt
                             iv_sign         = '='
                             iv_source_table = 'ZREING_TX_RULE_A'
                   CHANGING  ct_steps        = ct_steps ).
      " End Mod V010 (17.09.2026 | EXT_GONZALCA)
      RETURN.
    ENDIF.

    " Begin Insert V008 (08.09.2026 | EXT_GONZALCA)
    " Guard del denominador de BR-CA-07. Dos casos, los dos malos y hasta
    " ahora ninguno controlado:
    "  - tasa total EXACTAMENTE 100% -> denominador 0 -> CX_SY_ZERODIVIDE.
    "    Es una excepcion TECNICA: hasta V004 tumbaba el job completo y
    "    desde V004 degrada el grupo a CALC_ERR, pero con un mensaje que no
    "    dice cual es la regla fiscal culpable.
    "  - tasa total MAYOR a 100% -> denominador NEGATIVO -> BRUTO_AMT
    "    negativo que se persiste sin error alguno. Es el peor de los dos,
    "    porque nadie se entera: un reintegro con bruto negativo pasa el
    "    calculo, pasa Release y llega a CONTAB.
    " Los dos se cortan aca con un error de negocio que nombra la tasa
    " total y las reglas TX que la componen, que es lo que hace falta para
    " corregir el dato.
    " PENDIENTE FUNCIONAL (escalado 08.09.2026, sin respuesta): si una tasa
    " total > 100% es dato imposible o si el negocio la admite de alguna
    " forma. Hasta que se defina se rechaza, que es la unica opcion que no
    " inventa un resultado ni lo esconde.
    IF lv_total_rate >= 100.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |Suma de tasas de gross-up = { lv_total_rate }% (>= 100%): el monto | &&
          |bruto no esta definido. Reglas TX aplicadas: | &&
          |{ concat_lines_of( table = lt_winning_ids sep = ',' ) }|.
    ENDIF.
    " End Insert V008 (08.09.2026 | EXT_GONZALCA)

    " BR-CA-07: grossing-up by division, not additive.
    cs_line-bruto_amt    = cs_line-calc_amt / ( 1 - lv_total_rate / 100 ).
    cs_line-gross_up_amt = cs_line-bruto_amt - cs_line-calc_amt.

    record_step( EXPORTING iv_line_num     = cs_line-line_num
                           iv_step_num     = '03'
                           iv_seq          = '01'
                           iv_category     = zif_reing_ca_c=>step_category-gross_up
                           " V010: descripcion del paso segun ET SS7.8
                           " ("GrossUp {TOTAL_RATE}% ({N} reglas)"), que hasta
                           " ahora quedaba vacia en la Secuencia de Calculo.
                           iv_desc         = |GrossUp { lv_total_rate DECIMALS = 2 }% | &&
                                             |({ lines( lt_gu_win ) } reglas)|
                           iv_input        = cs_line-calc_amt
                           iv_rate         = lv_total_rate
                           iv_output       = cs_line-bruto_amt
                           iv_sign         = '='
                           iv_source_table = 'ZREING_TX_RULE_A'
                           " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                           " TX_RULE_ID is CHAR 20 and this step consolidates
                           " N rules, so it is only filled when exactly ONE
                           " rule won -- never a truncated or partial id. With
                           " N rules the full list stays in SOURCE_KEY below,
                           " as the ET design intended (CHAR 100). Decision
                           " taken with the user on 17.09.2026; the ET does
                           " not specify this case.
                           iv_tx_rule_id   = COND zreing_ca_step_a-tx_rule_id(
                                               WHEN lines( lt_winning_ids ) = 1
                                               THEN lt_winning_ids[ 1 ] )
                           iv_rate_desc    = |{ cs_line-calc_amt DECIMALS = 2 } | &&
                                             |/ (1 - { lv_total_rate DECIMALS = 2 }%)|
                           " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                           iv_source_key   = concat_lines_of( table = lt_winning_ids sep = ',' )
                 CHANGING  ct_steps        = ct_steps ).

    " Begin Insert V010 (17.09.2026 | EXT_GONZALCA)
    " Los impuestos de gross-up tambien se registran como pasos TAX y RESTAN
    " del neto. Definicion de Rochelle del 17.09.2026 y mockup
    " app_ca_ui5_v25.html (paso "WHT 15.00% (GU)" en las 6 lineas con
    " gross-up): el receptor cobra el CALC_AMT integro y la retencion queda
    " asentada, que es exactamente el proposito del gross-up -- con una sola
    " regla GU el NET_AMT vuelve a ser igual al CALC_AMT.
    " Hasta este fix TAX_AMT era "solo non-GU" (ET SS7.9) y el gross-up no
    " dejaba rastro por TAX_TYPE, de modo que CONTAB no tenia de donde tomar
    " el importe de las cuentas de retencion (Regla C de ET-REING-CONTAB-001
    " SS8.7 lee STEP_A.OUTPUT_AMT por TAX_TYPE). Es un desvio consciente de
    " la ET del motor: pedido a Rochelle actualizarla (SS7.8, SS7.9 y el
    " diccionario de TAX_AMT).
    " El importe se calcula sobre el BRUTO como cualquier otro impuesto:
    " bruto x rate es identico a (bruto - calc) cuando la tasa es la del
    " gross-up, y con varias reglas GU la suma de los pasos reproduce
    " GROSS_UP_AMT.
    " SEQ 01..N; step_tax sigue numerando a partir del ultimo.
    DATA lv_gu_seq TYPE zreing_ca_step_a-seq VALUE 0.
    DATA lv_tax_gu TYPE zreing_ca_line_a-base_amt.
    LOOP AT lt_gu_win INTO DATA(ls_gu_win).
      lv_gu_seq = lv_gu_seq + 1.
      lv_tax_gu = cs_line-bruto_amt * ls_gu_win-rate / 100.
      cs_line-tax_amt = cs_line-tax_amt + lv_tax_gu.
      record_step( EXPORTING iv_line_num     = cs_line-line_num
                             iv_step_num     = '04'
                             iv_seq          = lv_gu_seq
                             iv_category     = zif_reing_ca_c=>step_category-tax
                             iv_tax_type     = ls_gu_win-tax_type
                             " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                             iv_tx_rule_id   = ls_gu_win-tx_rule_id
                             iv_rate_desc    = |{ cs_line-bruto_amt DECIMALS = 2 } | &&
                                               |x { ls_gu_win-rate DECIMALS = 2 }%|
                             " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                             iv_desc         = |{ ls_gu_win-tax_type } | &&
                                               |{ ls_gu_win-rate DECIMALS = 2 }% (GU)|
                             iv_input        = cs_line-bruto_amt
                             iv_rate         = CONV zreing_ca_step_a-rate_pct( ls_gu_win-rate )
                             iv_output       = lv_tax_gu
                             iv_sign         = '-'
                             iv_source_table = 'ZREING_TX_RULE_A'
                             iv_source_key   = CONV ty_source_key( ls_gu_win-tax_type )
                   CHANGING  ct_steps        = ct_steps ).
    ENDLOOP.
    " End Insert V010 (17.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD step_tax.
    " Begin Mod V010 (17.09.2026 | EXT_GONZALCA)
    " Dos cambios de arranque, los dos porque step_gross_up ya emitio sus
    " propios pasos TAX (ver el bloque final de ese metodo):
    "  - TAX_AMT ya NO se inicializa aca; se inicializa en step_gross_up, que
    "    corre antes para la misma linea. Ponerlo en cero aqui borraria los
    "    importes de gross-up.
    "  - SEQ arranca despues del ultimo paso TAX que ya tenga esta linea, para
    "    no chocar con la clave primaria de ZREING_CA_STEP_A
    "    (CALC_RUN_ID / LINE_NUM / STEP_NUM / SEQ).
    " Sentencia original, para el registro:
    "    DATA lv_seq TYPE zreing_ca_step_a-seq VALUE 0.
    "    cs_line-tax_amt = 0.
    DATA lv_seq TYPE zreing_ca_step_a-seq.
    lv_seq = REDUCE i( INIT n = 0
                       FOR ls_prev IN ct_steps
                       WHERE ( line_num      = cs_line-line_num
                               AND step_category = zif_reing_ca_c=>step_category-tax )
                       NEXT n = n + 1 ).
    " End Mod V010 (17.09.2026 | EXT_GONZALCA)

    " Begin Insert V021 (18.09.2026 | EXT_GONZALCA)
    " Bug #83. Total of the GROSS-UP taxes, consumed by the NET formula at
    " the end of this method.
    " Every TAX step this line already carries at this point was emitted by
    " step_gross_up: it runs immediately before step_tax for the same line
    " (see the DO TIMES in execute) and is the only other producer of TAX
    " steps. So the very rows the REDUCE above counts for lv_seq are exactly
    " the gross-up ones -- no extra flag or lookup is needed to tell them
    " apart from the non-GU taxes this method is about to append.
    "
    " "INIT g TYPE ..." and NOT "INIT g = 0" -- this is the P(8,0) trap that
    " V018 documents in step_distribute and V006 in step_pc_split, and it bit
    " again here on the first attempt. The type of a REDUCE accumulator is
    " inferred from the INITIAL VALUE EXPRESSION, not from the result type
    " declared right next to it: with "INIT g = 0" the literal makes g a plain
    " integer, every addend is rounded to units, and the fixture of
    " path_a_full_happy_path came out at 188 + 63 = 251 instead of
    " 187,50 + 62,50 = 250,00 -- a net of 999,00 instead of 1.000,00. The unit
    " test caught it; nothing else would have, because the figure is only one
    " currency unit away from the right one.
    DATA lv_tax_gu TYPE zreing_ca_line_a-net_amt.
    lv_tax_gu = REDUCE zreing_ca_line_a-net_amt(
                  INIT g TYPE zreing_ca_line_a-net_amt
                  FOR ls_gu IN ct_steps
                  WHERE ( line_num      = cs_line-line_num
                          AND step_category = zif_reing_ca_c=>step_category-tax )
                  NEXT g = g + ls_gu-output_amt ).
    " End Insert V021 (18.09.2026 | EXT_GONZALCA)

    DATA(lt_allowed) = mo_sources->get_gl_tax_types( iv_ct_uuid = cs_line-ct_uuid iv_mat_uuid = cs_line-mat_uuid ).
    IF lt_allowed IS NOT INITIAL.
      " ATC fix (NonLocal DBREAD): reemplaza SELECT FROM zreing_tx_type_c por
      " filtrado en ABAP sobre mt_tx_type_cache (pre-cargado en execute).
      " lt_allowed es string_table -- cada fila es un tax_type escalar.
      " Begin Mod V010 (17.09.2026 | EXT_GONZALCA)
      " Se cae el filtro por GROSS_UP_DEFAULT del catalogo: quien decide si un
      " impuesto es de gross-up o una retencion normal es la marca GROSS_UP de
      " la REGLA, y ese filtro lo aplica get_tx_rules( iv_gross_up = ... ) mas
      " abajo. Ver la nota larga de step_gross_up para el detalle del bug que
      " esto cierra (Rochelle, 17.09.2026) y su caso simetrico.
      " Se conserva la verificacion de existencia, que implica "tipo activo".
      " Sentencia original, para el registro:
      "        IF line_exists( mt_tx_type_cache[ tax_type = lv_tax_type_t ] ) AND
      "           NOT line_exists( mt_tx_type_cache[ tax_type         = lv_tax_type_t
      "                                              gross_up_default = abap_true ] ).
      DATA lt_nongu TYPE STANDARD TABLE OF zreing_tx_type_c WITH EMPTY KEY.
      DATA lv_tax_type_t LIKE LINE OF lt_allowed.
      DATA lv_idx_al_t TYPE i VALUE 1.
      DO lines( lt_allowed ) TIMES.
        READ TABLE lt_allowed INTO lv_tax_type_t INDEX lv_idx_al_t.
        IF line_exists( mt_tx_type_cache[ tax_type = lv_tax_type_t ] ).
          APPEND VALUE zreing_tx_type_c( tax_type = lv_tax_type_t ) TO lt_nongu.
        ENDIF.
        lv_idx_al_t = lv_idx_al_t + 1.
      ENDDO.
      " End Mod V010 (17.09.2026 | EXT_GONZALCA)

      IF lt_nongu IS NOT INITIAL.
        DATA(lt_rules)    = mo_sources->get_tx_rules( iv_country = cs_line-country iv_gross_up = abap_false ).
        DATA(lv_ref_date) = last_day_of_period( iv_fiscal_period = ms_context-period iv_fiscal_year = ms_context-year ).

        " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
        " COUNTRY_PREST, same derivation as in step_gross_up -- in-memory read
        " of mt_bukrs_cache, no extra SELECT, no T001 (blocked by Clean Core).
        " See the long note in step_gross_up for why SS4.6 cannot be followed
        " literally.
        DATA lv_country_prest TYPE land1.
        lv_country_prest = VALUE #( mt_bukrs_cache[ bukrs = cs_line-bukrs_prest ]-country OPTIONAL ).
        " End Insert V009 (15.09.2026 | EXT_GONZALCA)

        LOOP AT lt_nongu INTO DATA(ls_type).
          " Begin Insert V010 (17.09.2026 | EXT_GONZALCA)
          " Un TAX_TYPE que ya gano por gross-up no se vuelve a cobrar aca.
          " Antes era imposible por construccion (el catalogo mandaba a cada
          " tipo a un solo paso); ahora que manda la marca de la regla, un
          " mismo TAX_TYPE puede tener una regla con X y otra sin X en el
          " mismo pais y ganar en los dos pasos -- lo que cobraria el impuesto
          " dos veces y dejaria dos pasos TAX con el mismo TAX_TYPE, que es
          " justo lo que CONTAB lee para las cuentas de retencion.
          IF line_exists( ct_steps[ line_num      = cs_line-line_num
                                    step_category = zif_reing_ca_c=>step_category-tax
                                    tax_type      = ls_type-tax_type ] ).
            CONTINUE.
          ENDIF.
          " End Insert V010 (17.09.2026 | EXT_GONZALCA)
          " BUGFIX (2026-07-14, found while writing F2 test-classes closure
          " sweep): was "WHERE ( tax_type = ls_type )", comparing a scalar
          " field against the FULL zreing_tx_type_c structure -- silently
          " produced an empty lt_candidates for every non-GU tax, so
          " TAX_AMT was always 0 on every real Calculate run since F2's
          " activation. step_03_gross_up already used the correct pattern
          " (ls_gu_type-tax_type) -- this brings step_04 in line with it.
          DATA(lt_candidates) = VALUE zif_reing_ca_types=>ty_tx_rule_t(
                                   FOR ls_r IN lt_rules WHERE ( tax_type = ls_type-tax_type ) ( ls_r ) ).
          " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
          " Same four criteria as step_gross_up (SS4.9). This matters beyond
          " Brazil's domestic case: MUR -> MUR only comes out at zero today
          " because Uruguay happens to have no non-gross-up tax. An
          " intra-company line of a BRAZILIAN provider would pick up CIDE /
          " PIS / COFINS / WHT through THIS step, and those have no role in
          " DOCTYPE INT either -- so the exclusion has to hold here too, not
          " just in the gross-up step.
          " Original call kept for reference:
          "    DATA(ls_winner) = mo_tx_scoring->find_best_rule(
          "                         it_rules    = lt_candidates
          "                         iv_lifnr    = cs_line-lifnr
          "                         iv_matnr    = cs_line-matnr
          "                         iv_ref_date = lv_ref_date ).
          DATA(ls_winner) = mo_tx_scoring->find_best_rule(
                               it_rules         = lt_candidates
                               iv_lifnr         = cs_line-lifnr
                               iv_matnr         = cs_line-matnr
                               iv_ref_date      = lv_ref_date
                               iv_country       = cs_line-country
                               iv_country_prest = lv_country_prest
                               iv_bukrs_prest   = cs_line-bukrs_prest
                               iv_bukrs_recv    = cs_line-bukrs_recv ).
          " End Mod V009 (15.09.2026 | EXT_GONZALCA)
          IF ls_winner IS INITIAL.
            CONTINUE.
          ENDIF.

          lv_seq = lv_seq + 1.
          DATA(lv_tax_this) = CONV zreing_ca_line_a-base_amt( cs_line-bruto_amt * ls_winner-rate / 100 ).
          cs_line-tax_amt = cs_line-tax_amt + lv_tax_this.

          record_step( EXPORTING iv_line_num     = cs_line-line_num
                                 iv_step_num     = '04'
                                 iv_seq          = lv_seq
                                 iv_category     = zif_reing_ca_c=>step_category-tax
                                 iv_tax_type     = ls_winner-tax_type
                                 " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                                 iv_tx_rule_id   = ls_winner-tx_rule_id
                                 iv_rate_desc    = |{ cs_line-bruto_amt DECIMALS = 2 } | &&
                                                   |x { ls_winner-rate DECIMALS = 2 }%|
                                 " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                                 " V010: descripcion del paso, como el mockup
                                 " de la app ("WHT 12.00%"). Antes quedaba
                                 " vacia en la Secuencia de Calculo.
                                 iv_desc         = |{ ls_winner-tax_type } | &&
                                                   |{ ls_winner-rate DECIMALS = 2 }%|
                                 iv_input        = cs_line-bruto_amt
                                 " Change ID V004 (03.09.2026 | EXT_GONZALCA):
                                 " RATE_PCT paso de DEC(9,6) a DEC(13,6)
                                 " (ZREING_CA_STEP_RATE) y IV_RATE se pasa por
                                 " referencia, asi que ls_winner-rate --que sigue
                                 " siendo un porcentaje DEC(9,6)-- ya no es
                                 " type-compatible. CONV explicito, mismo patron
                                 " que las iteraciones #5/#7 (M-08/M-09/M-10).
                                 iv_rate         = CONV zreing_ca_step_a-rate_pct( ls_winner-rate )
                                 iv_output       = lv_tax_this
                                 iv_sign         = '-'
                                 iv_source_table = 'ZREING_TX_RULE_A'
                                 iv_source_key   = CONV ty_source_key( ls_winner-tax_type )
                       CHANGING  ct_steps        = ct_steps ).
        ENDLOOP.

        " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
        " Bug #69: the contract DID have non-gross-up tax types, yet not one
        " rule survived AND this is an intra-company line -> the zero is the
        " deliberate exclusion, so leave it on the record. Same reasoning as
        " in step_gross_up: an unexplained zero reads like missing config.
        " lv_seq is incremented so the closing NET step below keeps its own
        " seq (otherwise both would be written with seq 1 and collide on the
        " primary key of ZREING_CA_STEP_A).
        IF lv_seq = 0
           AND cs_line-bukrs_prest IS NOT INITIAL
           AND cs_line-bukrs_prest = cs_line-bukrs_recv.
          lv_seq = lv_seq + 1.
          record_step( EXPORTING iv_line_num     = cs_line-line_num
                                 iv_step_num     = '04'
                                 iv_seq          = lv_seq
                                 iv_category     = zif_reing_ca_c=>step_category-tax
                                 iv_desc         = |Sin impuestos: operacion intra-sociedad { cs_line-bukrs_prest }|
                                 iv_input        = cs_line-bruto_amt
                                 iv_rate         = 0
                                 iv_output       = 0
                                 iv_sign         = '-'
                                 iv_source_table = 'ZREING_TX_RULE_A'
                       CHANGING  ct_steps        = ct_steps ).
        ENDIF.
        " End Insert V009 (15.09.2026 | EXT_GONZALCA)
      ENDIF.
    ENDIF.

    " Begin Mod V021 (18.09.2026 | EXT_GONZALCA)
    " Bug #83, reported by Rochelle from TS4-400 on 18.09.2026 (IC-0008 /
    " ICSRV45 / 02-2026, receptor DAB, line 0000085). Her definition, quoted
    " verbatim:
    "   "El valor neto solo se deducira cuando el indicador de GP este
    "    marcado en la aplicacion de impuestos. Es decir, en este escenario,
    "    solo el WHT deducira el importe neto."
    "
    " NET_AMT now subtracts ONLY the taxes whose TX RULE carries
    " GROSS_UP = 'X'. The non-gross-up ones -- CIDE, COFINS and PIS on
    " Brazilian service imports -- are borne by the PAYER: they are not
    " withheld from the remittance, so they must not reduce what the
    " contract nets. That is also the whole point of the gross-up: the
    " receiver is meant to collect the CALC_AMT in full.
    " Reported case: BRUTO 59.735,81 came out at 38.625,18 (all four taxes
    " deducted) instead of 50.775,44 (only the 8.960,37 of WHT).
    "
    " The V010 note that used to stand here said the NET formula "no cambia"
    " and that a pure gross-up leaves NET_AMT = CALC_AMT. That holds ONLY
    " when there is no non-GU tax on the line, which is not the Brazilian
    " case -- that is precisely the gap this fix closes.
    "
    " TAX_AMT is deliberately LEFT ALONE: it keeps being the real total
    " (gross-up + non gross-up), which is what the "Total Impuestos" column
    " means and what the header KPI shows. As a consequence
    " BRUTO - TAX_AMT no longer equals NET_AMT. That is inherent to the rule
    " and was accepted with the user on 18.09.2026, not an oversight.
    "
    " Side effect ON RECORD, confirmed with the user before applying: a
    " withholding WITHOUT the gross-up flag stops reducing the net as well.
    " Real case in the same run -- line 0000086 (DRU, Uruguay, WHT 12% via
    " TX-UY-WHT-001, a rule with no X since 17.09) goes from a net of
    " 40.215,12 to 45.699,00. Reported to Rochelle for confirmation.
    "
    " Deviates from ET-REING-CA-001 v50 SS7.9, which states the OPPOSITE
    " (TAX_AMT = non-GU only, NET_AMT = BRUTO - TAX_AMT). Same criterion
    " already applied on 17.09.2026: a recent definition from Rochelle
    " outranks the spec dated 17 July. Asked her to update SS7.8, SS7.9 and
    " the TAX_AMT / NET_AMT dictionary entries.
    " Original statement, for the record:
    "    cs_line-net_amt = cs_line-bruto_amt - cs_line-tax_amt.
    cs_line-net_amt = cs_line-bruto_amt - lv_tax_gu.
    " End Mod V021 (18.09.2026 | EXT_GONZALCA)

    DATA(lv_close_seq) = CONV zreing_ca_step_a-seq( lv_seq + 1 ).
    record_step( EXPORTING iv_line_num = cs_line-line_num
                           iv_step_num = '04'
                           iv_seq      = lv_close_seq
                           iv_category = zif_reing_ca_c=>step_category-net
                           " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                           " ET SS7.4: "= Neto contrato ({WAERS})", and source
                           " "Calculado" -- not a real table, but the ET
                           " defines SOURCE_TABLE as the origin of the datum
                           " in a broad sense and the code already writes
                           " '(padre)' in step_distribute (SS7.6).
                           iv_desc     = |= Neto contrato ({ cs_line-ct_currency })|
                           " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                           iv_input    = cs_line-bruto_amt
                           iv_output   = cs_line-net_amt
                           iv_sign     = '='
                           iv_source_table = 'Calculado'          "V019 (17.09.2026 | EXT_GONZALCA)
                 CHANGING  ct_steps    = ct_steps ).
  ENDMETHOD.
  METHOD load_fx_rules.
    " V001 (CC) - CA-05 (EBA Brasil): keep wildcard providers in the cache.
    CLEAR mt_fx_rules.
    IF mv_eba_off = abap_true.
      RETURN.
    ENDIF.

    SELECT FxRuleId AS fx_rule_id,
           CtCurrency AS ct_currency,
           SameCountry AS same_country,
           CountryPrest AS country_prest,
           CountryRecv AS country_recv,
           BukrsPrest AS bukrs_prest,
           BukrsRecv AS bukrs_recv,
           TransCurrencyMode AS trans_currency_mode,
           TransCurrencyFixed AS trans_currency_fixed
      FROM ZI_ReingFxRule
      WHERE BukrsPrest = @iv_bukrs_prest OR BukrsPrest = @space
      INTO CORRESPONDING FIELDS OF TABLE @mt_fx_rules.
  ENDMETHOD.

  METHOD find_fx_rule.
    " V001 (CC) - CA-05 (EBA Brasil): ET sections 3.2 and 8, pure scoring.
    TYPES: BEGIN OF ty_scored_fx,
             rule  TYPE zreing_fx_rule_a,
             score TYPE i,
           END OF ty_scored_fx.
    DATA lt_scored TYPE STANDARD TABLE OF ty_scored_fx WITH EMPTY KEY.

    LOOP AT it_rules INTO DATA(ls_rule).
      IF ( ls_rule-ct_currency IS NOT INITIAL AND ls_rule-ct_currency <> iv_ct_currency )
         OR ( ls_rule-same_country IS NOT INITIAL AND ls_rule-same_country <> iv_same_country )
         OR ( ls_rule-country_prest IS NOT INITIAL AND ls_rule-country_prest <> iv_country_prest )
         OR ( ls_rule-country_recv IS NOT INITIAL AND ls_rule-country_recv <> iv_country_recv )
         OR ( ls_rule-bukrs_prest IS NOT INITIAL AND ls_rule-bukrs_prest <> iv_bukrs_prest )
         OR ( ls_rule-bukrs_recv IS NOT INITIAL AND ls_rule-bukrs_recv <> iv_bukrs_recv ).
        CONTINUE.
      ENDIF.

      DATA(lv_score) =
          COND i( WHEN ls_rule-bukrs_recv IS NOT INITIAL THEN 32 ELSE 0 )
        + COND i( WHEN ls_rule-bukrs_prest IS NOT INITIAL THEN 16 ELSE 0 )
        + COND i( WHEN ls_rule-ct_currency IS NOT INITIAL THEN 8 ELSE 0 )
        + COND i( WHEN ls_rule-country_recv IS NOT INITIAL THEN 4 ELSE 0 )
        + COND i( WHEN ls_rule-country_prest IS NOT INITIAL THEN 2 ELSE 0 )
        + COND i( WHEN ls_rule-same_country IS NOT INITIAL THEN 1 ELSE 0 ).
      APPEND VALUE ty_scored_fx( rule = ls_rule score = lv_score ) TO lt_scored.
    ENDLOOP.

    IF lt_scored IS INITIAL.
      rs_result-rule-trans_currency_mode = 'SAME'.
      rs_result-is_fallback = abap_true.
      RETURN.
    ENDIF.

    SORT lt_scored BY score DESCENDING rule-fx_rule_id ASCENDING.
    DATA(lv_top_score) = lt_scored[ 1 ]-score.
    DATA(lv_tied) = REDUCE i(
      INIT n = 0 FOR ls_scored IN lt_scored
      NEXT n = n + COND i( WHEN ls_scored-score = lv_top_score THEN 1 ELSE 0 ) ).

    IF lv_tied > 1.
      DATA(lv_tied_ids) = REDUCE string(
        INIT ids = `` FOR ls_tied IN lt_scored
        NEXT ids = COND string(
          WHEN ls_tied-score <> lv_top_score THEN ids
          WHEN ids IS INITIAL THEN CONV string( ls_tied-rule-fx_rule_id )
          ELSE |{ ids },{ ls_tied-rule-fx_rule_id }| ) ).
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |Reglas FX ambiguas: { lv_tied } reglas empatadas en score { lv_top_score } | &&
          |({ lv_tied_ids }). Diferenciar los criterios de moneda/pais/sociedad|.
    ENDIF.

    rs_result-rule = lt_scored[ 1 ]-rule.
  ENDMETHOD.

  METHOD step_fx.
    " V001 (CC) - CA-06: rebuild only this line FX memory on recalculation.
    DATA(lv_steps_before_reset) = lines( ct_steps ).
    DELETE ct_steps WHERE line_num = cs_line-line_num AND step_num = '05'
      AND ( seq = '01' OR seq = '02' ).
    " V001 (CC) - Expose only the reset size to the ordinal projection wrapper.
    mv_removed_fx_steps = lv_steps_before_reset - lines( ct_steps ).
    cs_line-sim_message = fx_clean_warnings( cs_line-sim_message ).
    " V001 (CC) - ISO-01: line-level EBA switch; other prestadoras stay legacy.
    IF zcl_reing_ca_trans_amounts=>is_eba_enabled(
         iv_bukrs_prest = cs_line-bukrs_prest iv_eba_off = mv_eba_off ) = abap_false.
      step_fx_legacy(
        EXPORTING it_parent_fx = it_parent_fx
        CHANGING  cs_line      = cs_line
                  ct_steps     = ct_steps ).
      RETURN.
    ENDIF.

    step_fx_v2(
      EXPORTING it_parent_fx = it_parent_fx
      CHANGING  cs_line      = cs_line
                ct_steps     = ct_steps ).
  ENDMETHOD.

METHOD preload_v2_fx.
    " V001 (CC) - CA-06: bulk preload for exact EBA options only.
    CLEAR: mt_fx_options, mt_manual_fx, mt_primary_quotes, mt_local_quotes.
    IF mv_eba_off = abap_true OR it_scope IS INITIAL.
      RETURN.
    ENDIF.
    SELECT opt~*
      FROM zreing_ct2_opt_a AS opt
      INNER JOIN zreing_ct2_a AS hdr ON hdr~ct_uuid = opt~ct_uuid
      FOR ALL ENTRIES IN @it_scope
      WHERE opt~ct_uuid = @it_scope-ct_uuid
        AND opt~mat_uuid = @it_scope-mat_uuid
        AND opt~op_type = @it_scope-op_type
        AND opt~op_uuid = @it_scope-op_uuid
        AND hdr~bukrs = @zif_reing_ca_c=>br_isolation-eba_bukrs
      INTO CORRESPONDING FIELDS OF TABLE @mt_fx_options.
    IF mt_fx_options IS NOT INITIAL.
      SELECT recv~*
        FROM zreing_ct_o_r_a AS recv
        INNER JOIN zreing_ct2_opt_a AS opt
          ON opt~ct_uuid = recv~ct_uuid
          AND opt~mat_uuid = recv~mat_uuid
          AND opt~op_type = recv~op_type
          AND opt~op_uuid = recv~op_uuid
          AND opt~op_instance_num = recv~op_instance_num
        INNER JOIN zreing_ct2_a AS hdr ON hdr~ct_uuid = opt~ct_uuid
        FOR ALL ENTRIES IN @it_scope
        WHERE opt~ct_uuid = @it_scope-ct_uuid
          AND opt~mat_uuid = @it_scope-mat_uuid
          AND opt~op_type = @it_scope-op_type
          AND opt~op_uuid = @it_scope-op_uuid
          AND hdr~bukrs = @zif_reing_ca_c=>br_isolation-eba_bukrs
        INTO TABLE @mt_manual_fx.
    ENDIF.
  ENDMETHOD.

  METHOD fx_currency_decimals.
    READ TABLE mt_currency_decimals INTO DATA(ls_currency)
      WITH TABLE KEY currency = iv_currency.
    IF sy-subrc <> 0 OR iv_currency IS INITIAL
       OR ls_currency-decimals < 0 OR ls_currency-decimals > 3.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |Moneda { iv_currency } sin decimales FX validos (0..3)|.
    ENDIF.
    rv_decimals = ls_currency-decimals.
  ENDMETHOD.

  METHOD fx_canonical_rate.
    IF iv_rate <= 0 OR iv_rate > CONV decfloat34( '9999.99999' ).
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Tasa FX fuera de rango positivo DEC(9,5)'.
    ENDIF.
    DATA(lv_rate) = round( val = iv_rate dec = 5 mode = cl_abap_math=>round_half_up ).
    IF lv_rate <= 0.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Tasa FX no representable con cinco decimales'.
    ENDIF.
    TRY.
        rv_rate = CONV #( lv_rate ).
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Tasa FX no representable en DDIC'.
    ENDTRY.
  ENDMETHOD.

  METHOD fx_nominal_amount.
    DATA(lv_decimals) = fx_currency_decimals( iv_currency ).
    TRY.
        DATA(lv_amount) = round( val = iv_amount * iv_rate dec = lv_decimals
                                mode = cl_abap_math=>round_half_up ).
        rv_amount = CONV #( lv_amount ).
        IF CONV decfloat34( rv_amount ) <> lv_amount.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = |Importe { iv_currency } no representable en CURR(15,2)|.
        ENDIF.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |Importe { iv_currency } fuera de rango CURR(15,2)|.
    ENDTRY.
  ENDMETHOD.

  METHOD fx_period_date.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_period) = CONV i( ms_context-period ).
    IF lv_period < 1 OR lv_period > 12 OR ms_context-year IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Periodo invalido para fecha FX'.
    ENDIF.
    rv_date = COND #( WHEN CONV i( ms_context-period ) = CONV i( lv_today+4(2) )
                          AND ms_context-year = lv_today(4)
                     THEN lv_today
                     ELSE last_day_of_period( iv_fiscal_period = ms_context-period
                                              iv_fiscal_year = ms_context-year ) ).
    IF rv_date > lv_today.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |Periodo futuro para FX: { ms_context-period }/{ ms_context-year }|.
    ENDIF.
  ENDMETHOD.

  METHOD fx_clean_warnings.
    DATA lt_messages TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    SPLIT iv_message AT '; ' INTO TABLE lt_messages.
    LOOP AT lt_messages INTO DATA(lv_message).
      IF lv_message CP '[BR-FX-02] *' OR lv_message CP '[BR-CA-51] *'
         OR lv_message CP '[BR-CA-52] *' OR lv_message CP '[BR-CA-FX-CONFIG] *'
         OR lv_message CP '[BR-CA-FX-PRECISION] *' OR lv_message CP '[BR-CA-FX-RANGE] *'
         OR lv_message CP '[BR-CA-FX-API] *' OR lv_message CP '[BR-CA-FX-DATE] *'.
        CONTINUE.
      ENDIF.
      IF lv_message IS NOT INITIAL.
        rv_message = COND #( WHEN rv_message IS INITIAL THEN lv_message
                            ELSE |{ rv_message }; { lv_message }| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD fx_add_warning.
    " Put machine codes first so all codes survive the CHAR220 boundary.
    DATA(lv_safe) = iv_message.
    REPLACE ALL OCCURRENCES OF '; ' IN lv_safe WITH ', '.
    DATA(lv_length) = nmin( val1 = strlen( lv_safe ) val2 = 60 ).
    DATA(lv_short) = substring( val = lv_safe off = 0 len = lv_length ).
    cv_message = COND #( WHEN cv_message IS INITIAL THEN |[{ iv_code }] { lv_short }|
                        ELSE |[{ iv_code }] { lv_short }; { cv_message }| ).
  ENDMETHOD.

  METHOD step_fx_v2.
    " V001 (CC) - CA-06: nominal CT -> TRANS -> informative LOCAL.
    DATA(lv_business_type) = cs_line-exch_rate_type.
    DATA(lv_warnings) = fx_clean_warnings( cs_line-sim_message ).
    CLEAR: cs_line-exch_rate, cs_line-exch_rate_type, cs_line-net_local_amt,
           cs_line-exch_rate_1, cs_line-exch_rate_1_type, cs_line-net_trans_amt.

    READ TABLE mt_bukrs_cache INTO DATA(ls_prest) WITH KEY bukrs = cs_line-bukrs_prest.
    READ TABLE mt_bukrs_cache INTO DATA(ls_recv) WITH KEY bukrs = cs_line-bukrs_recv.
    DATA(lv_recv_country) = COND land1( WHEN ls_recv-country IS NOT INITIAL
                                      THEN ls_recv-country ELSE cs_line-country ).
    IF cs_line-ct_currency IS INITIAL OR ls_prest-country IS INITIAL OR lv_recv_country IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Sin moneda CT o paises para resolver regla FX'.
    ENDIF.
    DATA(ls_rule) = find_fx_rule(
      it_rules = mt_fx_rules iv_ct_currency = cs_line-ct_currency
      iv_same_country = COND #( WHEN ls_prest-country = lv_recv_country THEN 'S' ELSE 'D' )
      iv_country_prest = ls_prest-country iv_country_recv = lv_recv_country
      iv_bukrs_prest = cs_line-bukrs_prest iv_bukrs_recv = cs_line-bukrs_recv ).
    cs_line-trans_currency = SWITCH #( ls_rule-rule-trans_currency_mode
      WHEN 'SAME' THEN cs_line-ct_currency
      WHEN 'LOCAL' THEN cs_line-local_currency
      WHEN 'FIXED' THEN ls_rule-rule-trans_currency_fixed
      ELSE space ).
    IF ls_rule-is_fallback = abap_true.
      fx_add_warning( EXPORTING iv_code = 'BR-FX-02' iv_message = 'Sin regla FX; se usa moneda del contrato'
                      CHANGING cv_message = lv_warnings ).
    ENDIF.
    DATA(lv_ct_decimals) = fx_currency_decimals( cs_line-ct_currency ).
    DATA(lv_trans_decimals) = fx_currency_decimals( cs_line-trans_currency ).
    DATA lv_rate1 TYPE decfloat34.
    DATA lv_source TYPE ty_source_table.
    DATA lv_source_key TYPE ty_source_key.
    DATA lv_date1 TYPE d.
    IF cs_line-ct_currency = cs_line-trans_currency.
      cs_line-exch_rate_1 = 1.
      cs_line-net_trans_amt = cs_line-net_amt.
      lv_source_key = 'NO_OP'.
    ELSE.
      IF lv_business_type <> 'H'.
        READ TABLE mt_fx_options INTO DATA(ls_option)
          WITH TABLE KEY ct_uuid = cs_line-ct_uuid mat_uuid = cs_line-mat_uuid
            op_type = cs_line-op_type op_uuid = cs_line-op_uuid op_instance_num = cs_line-op_instance_num.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'Opcion FX ausente para identidad/instancia exacta'.
        ENDIF.
        lv_business_type = ls_option-exch_rate_type.
      ENDIF.
      CASE lv_business_type.
        WHEN 'M'.
          READ TABLE mt_manual_fx INTO DATA(ls_manual)
            WITH TABLE KEY ct_uuid = cs_line-ct_uuid mat_uuid = cs_line-mat_uuid
              op_type = cs_line-op_type op_uuid = cs_line-op_uuid
              op_instance_num = cs_line-op_instance_num bukrs_recv = cs_line-bukrs_recv.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING iv_message = 'Sin tasa manual para instancia/receptora exacta'.
          ENDIF.
          lv_rate1 = ls_manual-manual_exch_rate.
          lv_source = 'ZREING_CT_O_R_A'.
          lv_source_key = |{ cs_line-op_uuid }/{ cs_line-op_instance_num }/{ cs_line-bukrs_recv }|.
        WHEN 'P'.
          lv_date1 = fx_period_date( ).
          READ TABLE mt_primary_quotes INTO DATA(ls_quote1)
            WITH TABLE KEY from_currency = cs_line-ct_currency to_currency = cs_line-trans_currency
                           quote_date = lv_date1.
          IF sy-subrc = 0.
            lv_rate1 = ls_quote1-multiplier.
          ELSE.
            DATA(lv_internal_rate) = mo_sources->get_average_exch_rate(
              iv_from_currency = cs_line-ct_currency iv_to_currency = cs_line-trans_currency iv_date = lv_date1 ).
            lv_rate1 = CONV decfloat34( lv_internal_rate ) *
              CONV decfloat34( ipow( base = 10 exp = lv_ct_decimals ) ) /
              CONV decfloat34( ipow( base = 10 exp = lv_trans_decimals ) ).
            DATA(lv_canonical_p) = fx_canonical_rate( lv_rate1 ).
            INSERT VALUE #( from_currency = cs_line-ct_currency to_currency = cs_line-trans_currency
                            quote_date = lv_date1 multiplier = lv_canonical_p ) INTO TABLE mt_primary_quotes.
          ENDIF.
          lv_source = 'CL_EXCHANGE_RATES'.
          lv_source_key = |ICRG/{ cs_line-ct_currency }/{ cs_line-trans_currency }/{ lv_date1 }|.
        WHEN 'H'.
          READ TABLE it_parent_fx INTO DATA(ls_parent)
            WITH KEY origin_run_id = cs_line-origin_run_id origin_line_num = cs_line-origin_line_num.
          IF sy-subrc <> 0 OR ls_parent-exch_rate_1 <= 0
             OR ls_parent-ct_currency <> cs_line-ct_currency
             OR ls_parent-trans_currency <> cs_line-trans_currency.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING iv_message = 'Padre exacto sin tasa1 o con direccion monetaria incompatible'.
          ENDIF.
          lv_rate1 = ls_parent-exch_rate_1.
          lv_source = 'ZREING_CA_LINE_A'.
          lv_source_key = |{ cs_line-origin_run_id }/{ cs_line-origin_line_num }|.
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = |Tipo de tasa primaria no valido: { lv_business_type }|.
      ENDCASE.
      cs_line-exch_rate_1 = fx_canonical_rate( lv_rate1 ).
      cs_line-exch_rate_1_type = lv_business_type.
      cs_line-net_trans_amt = fx_nominal_amount( iv_amount = CONV #( cs_line-net_amt )
        iv_rate = CONV #( cs_line-exch_rate_1 ) iv_currency = cs_line-trans_currency ).
    ENDIF.
    record_step( EXPORTING iv_line_num = cs_line-line_num iv_step_num = '05' iv_seq = '01'
      iv_category = zif_reing_ca_c=>step_category-fx iv_input = cs_line-net_amt iv_input_curr = cs_line-ct_currency
      iv_output = cs_line-net_trans_amt iv_output_curr = cs_line-trans_currency
      iv_rate = CONV #( cs_line-exch_rate_1 ) iv_sign = 'x' iv_desc = 'Conversion CT a transaccion'
      iv_rate_desc = |{ cs_line-ct_currency }->{ cs_line-trans_currency } tipo { cs_line-exch_rate_1_type }|
      iv_source_table = lv_source iv_source_key = lv_source_key CHANGING ct_steps = ct_steps ).

    DATA ls_local TYPE zif_reing_ca_local_fx=>ty_result.
    DATA lv_local_date TYPE d.
    DATA lv_local_stage TYPE c LENGTH 6.
    IF cs_line-trans_currency = cs_line-local_currency AND cs_line-local_currency IS NOT INITIAL.
      ls_local-available = abap_true.
      ls_local-multiplier = 1.
      ls_local-amount_local = cs_line-net_trans_amt.
      ls_local-policy_source = 'NO_OP'.
      ls_local-status_code = 'OK'.
    ELSE.
      TRY.
          lv_local_stage = 'CONFIG'.
          DATA(lv_local_decimals) = fx_currency_decimals( cs_line-local_currency ).
          lv_local_stage = 'DATE'.
          lv_local_date = fx_period_date( ).
          lv_local_stage = 'API'.
          READ TABLE mt_local_quotes INTO DATA(ls_quote2)
            WITH TABLE KEY company_code = cs_line-bukrs_recv from_currency = cs_line-trans_currency
              to_currency = cs_line-local_currency quote_date = lv_local_date decimals_from = lv_trans_decimals
              decimals_to = lv_local_decimals amount_trans = CONV decfloat34( cs_line-net_trans_amt ).
          IF sy-subrc = 0.
            ls_local = ls_quote2-result.
          ELSE.
            IF mo_local_fx IS NOT BOUND.
              mo_local_fx = NEW zcl_reing_ca_local_fx( ).
            ENDIF.
            ls_local = mo_local_fx->convert_trans_to_local(
              iv_company_code = cs_line-bukrs_recv iv_trans_currency = cs_line-trans_currency
              iv_local_currency = cs_line-local_currency iv_date = lv_local_date
              iv_amount_trans = CONV #( cs_line-net_trans_amt ) iv_decimals_trans = lv_trans_decimals
              iv_decimals_local = lv_local_decimals ).
            INSERT VALUE #( company_code = cs_line-bukrs_recv from_currency = cs_line-trans_currency
              to_currency = cs_line-local_currency quote_date = lv_local_date decimals_from = lv_trans_decimals
              decimals_to = lv_local_decimals amount_trans = CONV decfloat34( cs_line-net_trans_amt )
              result = ls_local ) INTO TABLE mt_local_quotes.
          ENDIF.
        CATCH zcx_reing_ca_calc_error INTO DATA(lx_local_cfg).
          ls_local-status_code = lv_local_stage.
          ls_local-message = lx_local_cfg->mv_message.
        CATCH cx_root INTO DATA(lx_local_api).
          ls_local-status_code = 'API'.
          ls_local-message = lx_local_api->get_text( ).
      ENDTRY.
    ENDIF.
    IF ls_local-available = abap_true.
      TRY.
          TEST-SEAM local_preview_validation.
          cs_line-exch_rate = fx_canonical_rate( ls_local-multiplier ).
          IF ls_local-policy_source = 'NO_OP'.
            cs_line-net_local_amt = cs_line-net_trans_amt.
          ELSE.
            cs_line-net_local_amt = fx_nominal_amount( iv_amount = CONV #( cs_line-net_trans_amt )
              iv_rate = CONV #( cs_line-exch_rate ) iv_currency = cs_line-local_currency ).
          ENDIF.
          IF CONV decfloat34( cs_line-net_local_amt ) <> ls_local-amount_local.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING iv_message = 'Proveedor local devolvio importe/tasa inconsistentes'.
          ENDIF.
          END-TEST-SEAM.
        CATCH zcx_reing_ca_calc_error INTO DATA(lx_local_precision).
          CLEAR: cs_line-exch_rate, cs_line-net_local_amt, ls_local-available.
          ls_local-status_code = 'PRECISION'.
          ls_local-message = lx_local_precision->mv_message.
        CATCH cx_root INTO DATA(lx_result_error).
          CLEAR: cs_line-exch_rate, cs_line-net_local_amt, ls_local-available.
          ls_local-status_code = 'API'.
          ls_local-message = lx_result_error->get_text( ).
      ENDTRY.
    ENDIF.
    cs_line-exch_rate_type = ls_local-rate_type.
    DATA lv_output_curr TYPE waers.
    DATA lv_local_desc TYPE string.
    IF ls_local-available = abap_true.
      lv_output_curr = cs_line-local_currency.
      lv_local_desc = 'Conversion informativa a moneda local'.
    ELSE.
      DATA(lv_warning_code) = SWITCH string( ls_local-status_code
        WHEN 'NO_RATE' THEN 'BR-CA-52' WHEN 'PRECISION' THEN 'BR-CA-FX-PRECISION'
        WHEN 'RANGE' THEN 'BR-CA-FX-RANGE' WHEN 'CONFIG' THEN 'BR-CA-FX-CONFIG'
        WHEN 'DATE' THEN 'BR-CA-FX-DATE'
        ELSE 'BR-CA-FX-API' ).
      fx_add_warning( EXPORTING iv_code = lv_warning_code iv_message = ls_local-message
                      CHANGING cv_message = lv_warnings ).
      lv_local_desc = |[{ lv_warning_code }] { ls_local-message }|.
    ENDIF.
    record_step( EXPORTING iv_line_num = cs_line-line_num iv_step_num = '05' iv_seq = '02'
      iv_category = zif_reing_ca_c=>step_category-fx iv_input = cs_line-net_trans_amt
      iv_input_curr = cs_line-trans_currency iv_output = cs_line-net_local_amt iv_output_curr = lv_output_curr
      iv_rate = CONV #( cs_line-exch_rate ) iv_sign = 'x' iv_desc = CONV #( lv_local_desc )
      iv_rate_desc = |Politica { ls_local-policy_source } tipo { ls_local-rate_type } derivado { ls_local-derived_rate_type }|
      iv_source_table = COND #( WHEN ls_local-policy_source = 'NO_OP' THEN space ELSE 'CL_EXCHANGE_RATES' )
      iv_source_key = |{ cs_line-trans_currency }/{ cs_line-local_currency }/{ lv_local_date }/{ ls_local-rate_type }/{ ls_local-policy_source }|
      CHANGING ct_steps = ct_steps ).
    cs_line-sim_message = lv_warnings.
  ENDMETHOD.

  METHOD step_fx_legacy.
    " Begin Insert V005 (07.09.2026 | EXT_GONZALCA)
    " Guard against the silent-success case: with BOTH currencies empty the
    " shortcut below evaluates '' = '' as true, sets EXCH_RATE = 1 and writes
    " a wrong NET_LOCAL_AMT with no error at all - worse than the loud
    " failure this change fixes. EXCH_RATE = 1 is only legitimate when both
    " currencies are filled AND equal (BR-CT-CUR-04).
    " CT_CURRENCY is already validated in step_validate; LOCAL_CURRENCY is
    " resolved in step_distribute from mt_bukrs_cache and is left EMPTY
    " silently when the receptora is missing from that cache (ASSIGN with
    " sy-subrc <> 0 and no else branch) - so it is validated here, at its
    " first point of use.
    IF cs_line-ct_currency IS INITIAL OR cs_line-local_currency IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |Linea { cs_line-line_num } sin moneda para conversion FX: contrato | &&
          |'{ cs_line-ct_currency }' / local '{ cs_line-local_currency }' | &&
          |(receptora { cs_line-bukrs_recv })|.
    ENDIF.
    " End Insert V005 (07.09.2026 | EXT_GONZALCA)
    IF cs_line-ct_currency = cs_line-local_currency.
      cs_line-exch_rate = 1.
    ELSE.
      CASE cs_line-exch_rate_type.
        WHEN 'M'.
          cs_line-exch_rate = mo_sources->get_manual_exch_rate(
                                 iv_ct_uuid         = cs_line-ct_uuid
                                 iv_mat_uuid        = cs_line-mat_uuid
                                 iv_op_type         = cs_line-op_type
                                 iv_op_uuid         = cs_line-op_uuid
                                 iv_op_instance_num = cs_line-op_instance_num
                                 iv_bukrs_recv      = cs_line-bukrs_recv ).

        WHEN 'P'.
          DATA(lv_today)         = cl_abap_context_info=>get_system_date( ).
          DATA(lv_current_month) = xsdbool( ms_context-year   = lv_today(4)
                                         AND ms_context-period = lv_today+4(2) ).
          DATA lv_ref_date TYPE d.
          lv_ref_date = COND d(
            WHEN lv_current_month = abap_true THEN lv_today
            ELSE last_day_of_period( iv_fiscal_period = ms_context-period iv_fiscal_year = ms_context-year ) ).

          IF lv_current_month = abap_false AND lv_ref_date > lv_today.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING iv_message =
                |Periodo de calculo futuro para FX promedio: { ms_context-period }/{ ms_context-year }|.
          ENDIF.

          cs_line-exch_rate = mo_sources->get_average_exch_rate(
                                 iv_from_currency = cs_line-ct_currency
                                 iv_to_currency   = cs_line-local_currency
                                 iv_date          = lv_ref_date ).

        WHEN 'H'.
          " Heredado — own CA domain, never through Sources (F2-DD-3).
          " ATC fix (NonLocal DBREAD): READ TABLE desde it_parent_fx pre-cargado
          " en execute() antes del DO TIMES -- CERO SELECT aqui.
          READ TABLE it_parent_fx INTO DATA(ls_parent_fx)
            WITH KEY origin_run_id   = cs_line-origin_run_id
                     origin_line_num = cs_line-origin_line_num.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING iv_message =
                |Linea padre { cs_line-origin_run_id }/{ cs_line-origin_line_num } sin tasa de cambio|.
          ENDIF.
          cs_line-exch_rate = ls_parent_fx-exch_rate.

        WHEN OTHERS.
          cs_line-exch_rate = 1.
      ENDCASE.
    ENDIF.

    cs_line-net_local_amt = cs_line-net_amt * cs_line-exch_rate.

    record_step( EXPORTING iv_line_num = cs_line-line_num
                           iv_step_num = '05'
                           iv_seq      = '01'
                           iv_category = zif_reing_ca_c=>step_category-fx
                           " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
                           " ET SS7.4/SS7.9, both branches. The source table
                           " follows the COND of SS7.9, except that the manual
                           " rate really lives in ZREING_CT_O_R_A -- the ET
                           " literal 'CT_OPT_RATE_A' names a table that does
                           " not exist in this system (see get_manual_exch_rate).
                           iv_desc     = COND zreing_ca_step_a-step_desc(
                                           WHEN cs_line-ct_currency = cs_line-local_currency
                                           THEN |Sin conversion (misma moneda)|
                                           ELSE |x { cs_line-exch_rate DECIMALS = 6 } | &&
                                                |({ cs_line-local_currency }) | &&
                                                |tipo { cs_line-exch_rate_type }| )
                           iv_rate_desc = COND zreing_ca_step_a-rate_desc(
                                            WHEN cs_line-ct_currency = cs_line-local_currency
                                            THEN space
                                            ELSE |{ cs_line-net_amt DECIMALS = 2 } | &&
                                                 |x { cs_line-exch_rate DECIMALS = 6 }| )
                           iv_source_table = COND ty_source_table(
                                               WHEN cs_line-ct_currency = cs_line-local_currency
                                               THEN space
                                               WHEN cs_line-exch_rate_type = 'M'
                                               THEN 'ZREING_CT_O_R_A'
                                               WHEN cs_line-exch_rate_type = 'P'
                                               THEN 'TCURR'
                                               WHEN cs_line-exch_rate_type = 'H'
                                               THEN 'ZREING_CA_LINE_A' )
                           " End Insert V019 (17.09.2026 | EXT_GONZALCA)
                           iv_input    = cs_line-net_amt
                           iv_rate     = CONV zreing_ca_step_a-rate_pct( cs_line-exch_rate )
                           iv_output   = cs_line-net_local_amt
                           iv_sign     = 'x'
                 CHANGING  ct_steps    = ct_steps ).
  ENDMETHOD.
  METHOD resolve_me_period.
    " Begin Change ID V006 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : resolucion CENTRALIZADA del periodo de lectura de la
    " metrica ME (BR-CA-40). Hasta ahora esta logica vivia inline y SOLO en
    " step_pc_split, mientras step_validate, step_distribute y step_delta
    " leian ME con el periodo del run -- de ahi la mezcla M/M-1 reportada
    " por funcional (08.09.2026) sobre IC-0001/ICSRV44 con
    " ME_PERIOD_OFFSET = '01': el importe de la linea se calculaba con el
    " share de M y la apertura por dimensiones con el share de M-1. Con los
    " cuatro puntos llamando aqui, numerador y denominador del ratio de
    " step_pc_split pertenecen SIEMPRE al mismo periodo, y por lo tanto
    " SUM(ratios) = 1 exacto: el residuo de BR-CA-32 vuelve a ser residuo
    " de redondeo y no la diferencia entre dos periodos.
    " ALCANCE: el offset aplica solo a la METRICA. ET-REING-CA-001 v50
    " SS4.7 (Tablas Consumidas) lo define como "ME_PERIOD_OFFSET para
    " resolver periodo de lectura de metricas"; el monto CM se sigue
    " leyendo del periodo del run (EF-REING-CA-001 v4 SS5.1, "Monto cargado
    " en la app de Carga de Montos (CM) para el periodo").
    " Begin Mod V007 (08.09.2026 | EXT_GONZALCA)
    " La ARITMETICA (offset + rollover de anio) se movio a
    " ZCL_REING_CA_SOURCES=>CALC_ME_PERIOD, porque ZCL_REING_CA_INSUMO_MGR
    " necesita exactamente la misma para su chequeo de receptoras
    " agregadas/quitadas. Este metodo conserva la parte que SI es propia del
    " pipeline: resolver el offset del op_uuid contra el contrato.
    " Se llama la clase concreta y no la interfaz a proposito: es un calculo
    " sin acceso a BD, no una fuente de datos, asi que no hay nada que
    " mockear y no se toca ZIF_REING_CA_SOURCES ni sus test doubles.
    " Bloque de aritmetica original conservado como referencia:
    "    DATA(lv_month) = CONV i( ms_context-period ) - lv_offset.
    "    DATA(lv_year)  = CONV i( ms_context-year ).
    "    IF lv_month <= 0.
    "      lv_month = lv_month + 12.
    "      lv_year  = lv_year - 1.
    "    ENDIF.
    "    ev_period_month = lv_month.
    "    ev_period_year  = lv_year.
    DATA(ls_ct_opt) = mo_sources->get_ct_option( iv_op_uuid = iv_op_uuid ).

    zcl_reing_ca_sources=>calc_me_period(
      EXPORTING iv_offset       = ls_ct_opt-me_period_offset
                iv_period       = ms_context-period
                iv_year         = ms_context-year
      IMPORTING ev_period_month = ev_period_month
                ev_period_year  = ev_period_year ).
    " End Mod V007 (08.09.2026 | EXT_GONZALCA)
    " End Change ID V006 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD build_error_prefix.
    " Begin Change ID V008 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : prefijo de diagnostico para SIM_MESSAGE y LOG_A.
    " Formato: "[STAGE RECEPTORA L=nnnnnnn P=mm/aaaa] ".
    " Nace del incidente de TS4-400 de 02/2026: una linea quedo en CALC_ERR
    " con el texto "Error tecnico CX_SY_NO_HANDLER: ..." y nada mas -- sin
    " receptora, sin paso y sin periodo -- de modo que identificar cual de
    " las once receptoras habia fallado exigio reconstruir datos que los
    " reintentos del mismo dia ya habian sobreescrito.
    " SIM_MESSAGE es CHAR 220, asi que el prefijo se mantiene corto (~34
    " caracteres) para no comerse el mensaje de la causa.
    " Sin BUKRS_RECV se marca "(grupo)": significa que el fallo ocurrio
    " ANTES de la expansion por receptora, lo cual ya es un dato de
    " diagnostico en si mismo, no una carencia.
    DATA(lv_recv) = COND string( WHEN is_line-bukrs_recv IS NOT INITIAL
                                  THEN | { is_line-bukrs_recv }|
                                  ELSE | (grupo)| ).

    rv_prefix = |[{ iv_stage }{ lv_recv } L={ is_line-line_num } | &&
                |P={ ms_context-period }/{ ms_context-year }] |.
    " End Change ID V008 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD check_pending_input.
    IF it_scope IS INITIAL OR it_pending_keys IS INITIAL.
      rv_message = 'Exact pending selection cannot be empty'.
      RETURN.
    ENDIF.
    DATA lt_keys TYPE HASHED TABLE OF ty_pending_key
      WITH UNIQUE KEY calc_run_id line_num.
    LOOP AT it_pending_keys INTO DATA(ls_key).
      IF ls_key-calc_run_id <> ms_context-calc_run_id
          OR ls_key-calc_run_id IS INITIAL OR ls_key-line_num IS INITIAL.
        rv_message = 'Invalid RUN/LINE in exact pending selection'.
        RETURN.
      ENDIF.
      INSERT ls_key INTO TABLE lt_keys.
      IF sy-subrc <> 0.
        rv_message = 'Duplicate RUN/LINE in exact pending selection'.
        RETURN.
      ENDIF.
    ENDLOOP.
    DATA lt_groups TYPE HASHED TABLE OF zif_reing_ca_types=>ty_group_key
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    LOOP AT it_scope INTO DATA(ls_group).
      IF ls_group-calc_run_id <> ms_context-calc_run_id
          OR ls_group-op_type <> 'AN2' OR ls_group-cm_h_id IS NOT INITIAL
          OR ls_group-ct_uuid IS INITIAL OR ls_group-mat_uuid IS INITIAL
          OR ls_group-op_uuid IS INITIAL.
        rv_message = 'Exact pending selection requires valid AN2 groups in the context RUN'.
        RETURN.
      ENDIF.
      INSERT ls_group INTO TABLE lt_groups.
      IF sy-subrc <> 0.
        rv_message = 'Duplicate group in exact pending selection'.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD restrict_pending_scope.
    CLEAR: et_selected, ev_message.
    DATA lt_pending TYPE HASHED TABLE OF zreing_ca_line_a
      WITH UNIQUE KEY calc_run_id line_num.
    lt_pending = it_pending.
    DATA lt_covered TYPE HASHED TABLE OF zif_reing_ca_types=>ty_group_key
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    LOOP AT it_pending_keys INTO DATA(ls_key).
      READ TABLE lt_pending INTO DATA(ls_seed)
        WITH TABLE KEY calc_run_id = ls_key-calc_run_id line_num = ls_key-line_num.
      IF sy-subrc <> 0.
        ev_message = 'Requested seed is missing, outside scope, or no longer pending'.
        CLEAR et_selected.
        RETURN.
      ENDIF.
      IF ls_seed-op_type <> 'AN2' OR ls_seed-parent_op_type <> 'ANT'
          OR ls_seed-op_instance_num IS INITIAL
          OR ls_seed-origin_run_id IS INITIAL OR ls_seed-origin_line_num IS INITIAL.
        ev_message = 'Requested seed has an invalid AN2/ANT identity'.
        CLEAR et_selected.
        RETURN.
      ENDIF.
      APPEND ls_seed TO et_selected.
      INSERT CORRESPONDING #( ls_seed ) INTO TABLE lt_covered.
    ENDLOOP.
    IF lines( lt_covered ) <> lines( it_scope ).
      ev_message = 'Every exact-mode group must contain a requested physical seed'.
      CLEAR et_selected.
    ENDIF.
  ENDMETHOD.


  METHOD index_trans_steps.
    LOOP AT it_steps INTO DATA(ls_step).
      INSERT VALUE #( calc_run_id = ls_step-calc_run_id line_num = ls_step-line_num
        table_index = sy-tabix ) INTO TABLE rt_index.
    ENDLOOP.
  ENDMETHOD.

  METHOD propagate_trans.
    " Recover ordinals only when the FX dispatcher actually removed older rows.
    IF mv_removed_fx_steps > 0.
      ct_index = index_trans_steps( ct_steps ).
    ENDIF.
    TYPES: BEGIN OF ty_position,
             calc_run_id TYPE zreing_ca_step_a-calc_run_id,
             line_num TYPE zreing_ca_step_a-line_num,
             step_num TYPE zreing_ca_step_a-step_num,
             seq TYPE zreing_ca_step_a-seq,
             table_index TYPE i,
           END OF ty_position,
           tt_positions TYPE HASHED TABLE OF ty_position
             WITH UNIQUE KEY calc_run_id line_num step_num seq.
    DATA lt_positions TYPE tt_positions.
    DATA lt_selected TYPE zif_reing_ca_types=>ty_step_t.
    LOOP AT ct_index INTO DATA(ls_index)
      WHERE calc_run_id = cs_line-calc_run_id AND line_num = cs_line-line_num.
      ASSIGN ct_steps[ ls_index-table_index ] TO FIELD-SYMBOL(<indexed_step>).
      IF sy-subrc <> 0 OR <indexed_step>-calc_run_id <> cs_line-calc_run_id
         OR <indexed_step>-line_num <> cs_line-line_num.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
          NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH cs_line-line_num INTO DATA(lv_invalid_index).
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_invalid_index.
      ENDIF.
      INSERT VALUE #( calc_run_id = <indexed_step>-calc_run_id line_num = <indexed_step>-line_num
        step_num = <indexed_step>-step_num seq = <indexed_step>-seq
        table_index = ls_index-table_index ) INTO TABLE lt_positions.
      IF sy-subrc <> 0.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
          NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH cs_line-line_num INTO lv_invalid_index.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_invalid_index.
      ENDIF.
      APPEND <indexed_step> TO lt_selected.
    ENDLOOP.
    DATA(lv_position) = iv_new_from - mv_removed_fx_steps.
    IF lv_position < 1 OR lv_position > lines( ct_steps ) + 1.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH cs_line-line_num INTO lv_invalid_index.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_invalid_index.
    ENDIF.
    DATA(lv_new_count) = lines( ct_steps ) - lv_position + 1.
    DO lv_new_count TIMES.
      ASSIGN ct_steps[ lv_position ] TO FIELD-SYMBOL(<new_step>).
      IF <new_step>-calc_run_id <> cs_line-calc_run_id OR <new_step>-line_num <> cs_line-line_num.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
          NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH cs_line-line_num INTO lv_invalid_index.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_invalid_index.
      ENDIF.
      " A recovered index already contains this segment: never add it twice.
      ASSIGN lt_positions[ calc_run_id = <new_step>-calc_run_id
        line_num = <new_step>-line_num step_num = <new_step>-step_num seq = <new_step>-seq ]
        TO FIELD-SYMBOL(<known_position>).
      IF sy-subrc = 0 AND <known_position>-table_index <> lv_position.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
          NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH cs_line-line_num INTO lv_invalid_index.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_invalid_index.
      ENDIF.
      IF sy-subrc <> 0.
        INSERT VALUE #( calc_run_id = <new_step>-calc_run_id line_num = <new_step>-line_num
          step_num = <new_step>-step_num seq = <new_step>-seq table_index = lv_position ) INTO TABLE lt_positions.
        APPEND <new_step> TO lt_selected.
      ENDIF.
      lv_position += 1.
    ENDDO.
    " Populate once for direct in-memory callers; execute preloads outside its line loops.
    IF mt_trans_currencies IS INITIAL.
      mt_trans_currencies = CORRESPONDING #( mt_currency_decimals ).
    ENDIF.
    DATA(ls_projection) = zcl_reing_ca_trans_amounts=>project_line(
      is_line = cs_line it_line_pc = ct_pc it_steps = lt_selected it_currencies = mt_trans_currencies
      iv_eba_off = mv_eba_off ).
    IF ls_projection-use_trans = abap_false.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER zif_reing_ca_c=>fx_projection_message-input INTO lv_invalid_index.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_invalid_index.
    ENDIF.
    cs_line = ls_projection-line.
    ct_pc = CORRESPONDING #( ls_projection-line_pc ).
    LOOP AT ls_projection-steps INTO DATA(ls_projected_step).
      DATA(lv_target_index) = lt_positions[ calc_run_id = ls_projected_step-calc_run_id
        line_num = ls_projected_step-line_num step_num = ls_projected_step-step_num seq = ls_projected_step-seq ]-table_index.
      ct_steps[ lv_target_index ] = ls_projected_step.
    ENDLOOP.
    IF ls_projection-local_message IS NOT INITIAL.
      DATA(lv_warnings) = CONV string( cs_line-sim_message ).
      fx_add_warning( EXPORTING iv_code = zif_reing_ca_c=>fx_projection-local_warning
        iv_message = ls_projection-local_message CHANGING cv_message = lv_warnings ).
      cs_line-sim_message = lv_warnings.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

