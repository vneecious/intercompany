
" V001 (CC) - CB-04: capture document construction without calling FI.
CLASS lcl_cb04_poster DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_reing_contab_fi_poster.
    DATA calls TYPE i.
    DATA header TYPE zif_reing_contab_types=>ty_header.
    DATA items TYPE zif_reing_contab_types=>ty_doc_item_t.
    DATA mode TYPE zreing_ca_contab_mode.
ENDCLASS.
CLASS lcl_cb04_poster IMPLEMENTATION.
  METHOD zif_reing_contab_fi_poster~post_document.
    calls += 1.
    header = is_header.
    items = it_items.
    mode = iv_mode.
    rs_result = VALUE #( belnr = '7000000004' gjahr = '2026' ).
  ENDMETHOD.
  METHOD zif_reing_contab_fi_poster~reverse_document.
    cl_abap_unit_assert=>fail( 'CB-04 must not reverse a document' ).
  ENDMETHOD.
ENDCLASS.


" V001 (CC) - CB-01: no business API is called by these isolated tests.
CLASS lcl_cb01_poster DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_reing_contab_fi_poster.
    DATA post_calls TYPE i.
    DATA reverse_calls TYPE i.
    DATA original_bukrs TYPE bukrs.
    DATA original_belnr TYPE belnr_d.
    DATA original_gjahr TYPE gjahr.
ENDCLASS.
CLASS lcl_cb01_poster IMPLEMENTATION.
  METHOD zif_reing_contab_fi_poster~post_document.
    post_calls += 1.
  ENDMETHOD.
  METHOD zif_reing_contab_fi_poster~reverse_document.
    reverse_calls += 1.
    original_bukrs = iv_bukrs.
    original_belnr = iv_belnr.
    original_gjahr = iv_gjahr.
    rs_result = VALUE #( belnr = '7000000001' gjahr = '2026' ).
  ENDMETHOD.
ENDCLASS.
*"* CON-09 — Pruebas ABAP Unit de CONTAB (rework Delta v2)
*"* Clase bajo prueba: ZCL_REING_CONTAB_DOC
*"*
*"* CÓMO INSTALARLO: pegar TODO este contenido en la pestaña
*"* "Test Classes" (Local Types -> Test Classes) de la clase
*"* ZCL_REING_CONTAB_DOC en ADT, y correr con Ctrl+Shift+F10.
*"*
*"* Qué cubre (lógica reworkeada, sin tocar BD — HARMLESS):
*"*   - CON-01  build_items: apertura GL por profit center (1 item por PC
*"*             de LPC_A filtrado por role_category); AR/AP en 1 sola línea
*"*             con el TOTAL (no se abren por PC); item_num secuencial.
*"*   - CON-02  determine_kostl: layout CAMPANA(3)+ALLOCATION(1)+INTERNAL(3)+PRCTR₃.
*"*   - SS8.7 Regla C (V008, 17.09.2026): un rol con TAX_TYPE postea el
*"*             OUTPUT_AMT del paso TAX de ese impuesto, prorrateado por
*"*             SHARE_ABS, y no el importe de la línea.
*"*   - apply_sign: S mantiene signo, H lo invierte.
*"* Se accede a métodos/atributos PROTECTED/PRIVATE vía LOCAL FRIENDS;
*"* el contexto se inyecta seteando atributos (no se llama set_context,
*"* así no hay SELECTs y el test queda aislado).

CLASS ltc_contab_doc DEFINITION DEFERRED.
CLASS zcl_reing_contab_doc DEFINITION LOCAL FRIENDS ltc_contab_doc.

CLASS ltc_contab_doc DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_reing_contab_doc.

    METHODS setup.

    " V001 (CC) - CB-04: isolated SQL context and additional document oracles.
    CLASS-DATA cb04_sql TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.
    DATA cb04_poster TYPE REF TO lcl_cb04_poster.
    METHODS cb04_given
      IMPORTING iv_off TYPE abap_bool DEFAULT abap_false
                iv_tax TYPE zreing_ca_line_a-tax_amt DEFAULT 0
                iv_style TYPE c DEFAULT 'G'
                iv_credit TYPE abap_bool DEFAULT abap_false
                iv_weight TYPE zreing_percent_9_6 DEFAULT 50
                iv_missing TYPE c DEFAULT space
                iv_zero TYPE abap_bool DEFAULT abap_false
      RAISING cx_static_check.
    METHODS cb04_context
      IMPORTING iv_rule TYPE zreing_docflow_c-bukrs_rule DEFAULT 'P'.
    METHODS cb04_assert_tax
      IMPORTING iv_off TYPE abap_bool iv_tax TYPE zreing_ca_line_a-tax_amt
                iv_expected TYPE zreing_ca_line_a-net_amt
                iv_credit TYPE abap_bool DEFAULT abap_false
                iv_error TYPE abap_bool DEFAULT abap_false
      RAISING cx_static_check.
    METHODS cb04_assert_ceco
      IMPORTING iv_rule TYPE zreing_docflow_c-bukrs_rule iv_bukrs TYPE bukrs
                iv_code TYPE c.
    METHODS cb04_assert_recovery IMPORTING iv_off TYPE abap_bool RAISING cx_static_check.
    METHODS cb04_assert_bp IMPORTING iv_off TYPE abap_bool RAISING cx_static_check.
    METHODS cb04_assert_zero IMPORTING iv_off TYPE abap_bool RAISING cx_static_check.
    METHODS cb04_assert_missing IMPORTING iv_off TYPE abap_bool iv_missing TYPE c
      RAISING cx_static_check.
    METHODS legacy_tax_pairs_pass FOR TESTING RAISING cx_static_check.
    METHODS nominal_tax_pairs_pass FOR TESTING RAISING cx_static_check.
    METHODS legacy_category_cent_reject FOR TESTING RAISING cx_static_check.
    METHODS nominal_category_cent_reject FOR TESTING RAISING cx_static_check.
    METHODS nominal_credit_cent_reject FOR TESTING RAISING cx_static_check.
    METHODS nominal_role_residue_pass FOR TESTING RAISING cx_static_check.
    METHODS legacy_ceco_context_refresh FOR TESTING RAISING cx_static_check.
    METHODS nominal_ceco_context_refresh FOR TESTING RAISING cx_static_check.
    METHODS legacy_code_missing_cold FOR TESTING RAISING cx_static_check.
    METHODS nominal_code_missing_cold FOR TESTING RAISING cx_static_check.
    METHODS legacy_code_reset_recovery FOR TESTING RAISING cx_static_check.
    METHODS nominal_code_reset_recovery FOR TESTING RAISING cx_static_check.
    METHODS bp_only_without_code FOR TESTING RAISING cx_static_check.
    METHODS zero_gl_without_code FOR TESTING RAISING cx_static_check.
    METHODS code_missing_prior_error FOR TESTING RAISING cx_static_check.

    " V001 (CC) - CB-02: literal rate and additive payload contract.
    TYPES BEGIN OF ty_cb02_payload.
    INCLUDE TYPE zif_reing_contab_types=>ty_step_result.
    TYPES header TYPE zif_reing_contab_types=>ty_header.
    TYPES END OF ty_cb02_payload.
    METHODS cb02_given
      IMPORTING iv_rate TYPE zreing_ca_line_a-exch_rate_1 DEFAULT '5.3'
                iv_base TYPE zreing_ca_line_a-net_amt DEFAULT 100
                iv_currency TYPE waers DEFAULT 'USD'
                iv_style TYPE c DEFAULT 'G'
      RAISING cx_static_check.
    METHODS cb02_project RAISING cx_static_check.
    METHODS cb02_assert
      IMPORTING iv_rate TYPE zreing_ca_line_a-exch_rate_1
                iv_amount TYPE zreing_ca_line_a-net_amt
                iv_bukrs TYPE bukrs DEFAULT 'EBA'
                iv_nominal TYPE abap_bool DEFAULT abap_true.
    METHODS cb02_bad_rate IMPORTING iv_rate TYPE zreing_ca_line_a-exch_rate_1
      RAISING cx_static_check.
    METHODS nominal_rate_header FOR TESTING RAISING cx_static_check.
    METHODS nominal_fraction_exact FOR TESTING RAISING cx_static_check.
    METHODS nominal_max_rate_exact FOR TESTING RAISING cx_static_check.
    METHODS nominal_same_rate_one FOR TESTING RAISING cx_static_check.
    METHODS nominal_cross_rate_one FOR TESTING RAISING cx_static_check.
    METHODS off_rate_not_sent FOR TESTING RAISING cx_static_check.
    METHODS noneba_rate_not_sent FOR TESTING RAISING cx_static_check.
    METHODS historic_eba_no_rate FOR TESTING RAISING cx_static_check.
    METHODS rate_context_reset FOR TESTING RAISING cx_static_check.
    METHODS auto_reversal_fx_header FOR TESTING RAISING cx_static_check.
    METHODS zero_rate_rejects FOR TESTING RAISING cx_static_check.
    METHODS negative_rate_rejects FOR TESTING RAISING cx_static_check.
    METHODS derived_docs_rate_header FOR TESTING RAISING cx_static_check.

    " V001 (CC) - CB-02: reject inherited currency before the captured poster.
    METHODS cb02_recl_given
      IMPORTING iv_rate TYPE zreing_ca_line_a-exch_rate_1 iv_currency TYPE waers
      RAISING cx_static_check.
    METHODS cb02_prev_reject
      IMPORTING iv_rate TYPE zreing_ca_line_a-exch_rate_1 iv_currency TYPE waers
      RAISING cx_static_check.
    METHODS nominal_prev_currency_reject FOR TESTING RAISING cx_static_check.

    " --- CON-01 ---
    METHODS gl_abre_por_pc         FOR TESTING.
    METHODS gl_filtra_por_role_cat FOR TESTING.
    METHODS ar_ap_una_linea_total  FOR TESTING.
    " --- AP balance regression (V010) ---
    METHODS apic_rrec_balances     FOR TESTING.
    METHODS item_num_secuencial    FOR TESTING.
    " --- CON-02 ---
    METHODS kostl_layout           FOR TESTING.
    " --- SS8.7 Regla C (V008) ---
    METHODS tax_role_prorrateo     FOR TESTING.
    " --- Exact monetary reductions (V009) ---
    METHODS balance_keeps_decimals FOR TESTING.
    METHODS balance_exact_zero     FOR TESTING.
    METHODS total_amount_one_side  FOR TESTING.
    " --- helper de firma ---
    METHODS apply_sign_debe_haber  FOR TESTING.

    " Helpers de construcción de datos de entrada
    METHODS make_gl_role
      IMPORTING iv_role_code     TYPE zreing_role_code
                iv_role_category TYPE zreing_role_cat
                iv_posting_side  TYPE shkzg DEFAULT 'S'
      RETURNING VALUE(rs_role)   TYPE zif_reing_contab_types=>ty_role_resolved.
    METHODS make_pc
      IMPORTING iv_role_category TYPE zreing_role_cat
                iv_campana       TYPE zreing_campana
                iv_allocation    TYPE zreing_alloc_type
                iv_prctr         TYPE prctr
                iv_net_amt       TYPE zreing_ca_line_a-net_amt
                iv_share_abs     TYPE zreing_percent_9_6 DEFAULT 0
      RETURNING VALUE(rs_pc)     TYPE zreing_ca_lpc_a.
    DATA ms_line TYPE zreing_ca_line_a.
    DATA mt_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_steps TYPE zif_reing_ca_types=>ty_step_t.
    DATA mt_currencies TYPE zif_reing_ca_types=>tt_currency_precision.
    DATA ms_projection TYPE zif_reing_ca_types=>ty_trans_projection.
    DATA mo_poster TYPE REF TO lcl_cb01_poster.
    METHODS given_trans RAISING zcx_reing_ca_calc_error.
    METHODS refresh_trans RAISING zcx_reing_ca_calc_error.
    METHODS assert_context_error.
    METHODS trans_tax_rounds_to_zero FOR TESTING RAISING cx_static_check.
    METHODS off_tax_rounding_preserved FOR TESTING RAISING cx_static_check.
    METHODS trans_tax_compensated_kept FOR TESTING RAISING cx_static_check.
    METHODS trans_overflow_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_tax_last_exact_residue FOR TESTING RAISING cx_static_check.
    METHODS trans_same_exact_nominal FOR TESTING RAISING cx_static_check.
    METHODS trans_blank_prctr_preserved FOR TESTING RAISING cx_static_check.
    METHODS trans_local_metadata_degrades FOR TESTING RAISING cx_static_check.
    METHODS trans_ar_uses_calc FOR TESTING RAISING cx_static_check.
    METHODS trans_ap_uses_bruto FOR TESTING RAISING cx_static_check.
    METHODS trans_preserves_native_ct FOR TESTING RAISING cx_static_check.
    METHODS trans_tax_nominal_once FOR TESTING RAISING cx_static_check.
    METHODS trans_tax_category_target FOR TESTING RAISING cx_static_check.
    METHODS trans_tax_fallback_residue FOR TESTING RAISING cx_static_check.
    METHODS trans_missing_category_skips FOR TESTING RAISING cx_static_check.
    METHODS trans_missing_cfg_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_rounded_zero_skips FOR TESTING RAISING cx_static_check.
    METHODS trans_compensated_runs FOR TESTING RAISING cx_static_check.
    METHODS trans_old_caller_rejected FOR TESTING RAISING cx_static_check.
    METHODS trans_physical_lpc_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_physical_step_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_calc_total_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_reset_keeps_legacy FOR TESTING RAISING cx_static_check.
    METHODS trans_off_ignores_bad_memory FOR TESTING RAISING cx_static_check.
    METHODS trans_precision_zero_valid FOR TESTING RAISING cx_static_check.
    METHODS trans_third_decimal_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_residual_exact_rejects FOR TESTING RAISING cx_static_check.
    METHODS trans_storno_uses_original FOR TESTING RAISING cx_static_check.
    METHODS trans_storno_without_fi FOR TESTING RAISING cx_static_check.
    " V001 (CC) - bug107 CONTAB: contract selector with captured FI boundary.
    METHODS contract_context
      IMPORTING iv_rule TYPE zreing_bukrs_rule DEFAULT 'P'
                iv_kostl TYPE kostl OPTIONAL.
    METHODS contract_assert_error IMPORTING iv_message TYPE symsgno.
    METHODS contract_off_gl FOR TESTING RAISING cx_static_check.
    METHODS contract_on_gl FOR TESTING RAISING cx_static_check.
    METHODS contract_bad_company FOR TESTING RAISING cx_static_check.
    METHODS contract_missing_kostl FOR TESTING RAISING cx_static_check.
    METHODS contract_context_reset FOR TESTING RAISING cx_static_check.
    METHODS contract_bp_only FOR TESTING RAISING cx_static_check.
    METHODS contract_zero_gl FOR TESTING RAISING cx_static_check.
    METHODS contract_prior_error FOR TESTING RAISING cx_static_check.
    METHODS formula_default_unchanged FOR TESTING RAISING cx_static_check.
    METHODS contract_gl_assert IMPORTING iv_off TYPE abap_bool RAISING cx_static_check.

    " V001 (CC) - #121: exact mapping, controlled errors and context isolation.
    METHODS map_context IMPORTING iv_rule TYPE zreing_bukrs_rule DEFAULT 'O'
      it_map TYPE zif_reing_contab_types=>tt_campana_map OPTIONAL.
    METHODS map_fixture RETURNING VALUE(rt_map) TYPE zif_reing_contab_types=>tt_campana_map.
    METHODS map_assert_gl IMPORTING iv_off TYPE abap_bool RAISING cx_static_check.
    METHODS map_assert_error IMPORTING iv_message TYPE symsgno
      iv_material TYPE zreing_ca_line_a-matnr DEFAULT 'UTCB04'.
    METHODS map_off_gl FOR TESTING RAISING cx_static_check.
    METHODS map_on_gl FOR TESTING RAISING cx_static_check.
    METHODS map_bad_company FOR TESTING RAISING cx_static_check.
    METHODS map_missing_row FOR TESTING RAISING cx_static_check.
    METHODS map_empty_destination FOR TESTING RAISING cx_static_check.
    METHODS map_missing_material FOR TESTING RAISING cx_static_check.
    METHODS map_exact_keys FOR TESTING RAISING cx_static_check.
    METHODS map_context_reset FOR TESTING RAISING cx_static_check.
    METHODS map_bp_only FOR TESTING RAISING cx_static_check.
    METHODS map_zero_gl FOR TESTING RAISING cx_static_check.
    METHODS map_internal_code_missing FOR TESTING RAISING cx_static_check.
    METHODS map_prior_error FOR TESTING RAISING cx_static_check.
    METHODS map_storno_original FOR TESTING RAISING cx_static_check.
    METHODS contract_pc_context FOR TESTING RAISING cx_static_check.

    " V001 (CC) - #122: explicit ET oracles, no live FI calls.
    METHODS text_et_gl_positions FOR TESTING RAISING cx_static_check.
    METHODS text_et_bp_positions FOR TESTING RAISING cx_static_check.
    METHODS text_et_nominal_payload FOR TESTING RAISING cx_static_check.
    METHODS text_et_override_company FOR TESTING RAISING cx_static_check.
    METHODS text_et_blank_dimensions FOR TESTING RAISING cx_static_check.
    METHODS text_et_width_and_refresh FOR TESTING RAISING cx_static_check.
    METHODS text_et_int_inherits FOR TESTING RAISING cx_static_check.
    METHODS bypass_explicit_off_wins FOR TESTING RAISING cx_static_check.
    METHODS bypass_explicit_on_wins FOR TESTING RAISING cx_static_check.
    METHODS bypass_omitted_refreshes FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltc_contab_doc IMPLEMENTATION.

  METHOD cb02_recl_given.
    cb02_given( iv_rate = iv_rate ).
    " Preceding WHT and target/counter roles live exclusively in SQL doubles.
    DATA lt_source TYPE STANDARD TABLE OF zreing_gl_roles WITH EMPTY KEY.
    lt_source = VALUE #( ( gl_role = 'WT' posting_context = 'GL' role_category = 'C'
      tax_type = 'T1' reclassify = abap_true role_reclas = 'RT' )
      ( gl_role = 'RT' posting_context = 'GL' role_category = 'C' tax_type = 'T1' )
      ( gl_role = 'RC' posting_context = 'GL' role_category = 'C' ) ).
    cb04_sql->insert_test_data( lt_source ).
    DATA lt_doc TYPE STANDARD TABLE OF zreing_doctype_r WITH EMPTY KEY.
    lt_doc = VALUE #( ( doc_type_code = 'ZZZ' role_code = 'RT' posting_side = 'S' )
      ( doc_type_code = 'ZZZ' role_code = 'RC' posting_side = 'H' ) ).
    cb04_sql->insert_test_data( lt_doc ).
    CONSTANTS lc_gl1 TYPE sysuuid_x16 VALUE '02000000000000000000000000000001'.
    CONSTANTS lc_gl2 TYPE sysuuid_x16 VALUE '02000000000000000000000000000002'.
    DATA lt_acct TYPE STANDARD TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.
    lt_acct = VALUE #( ( ct_uuid = ms_line-ct_uuid mat_uuid = ms_line-mat_uuid
      gl_uuid = lc_gl1 gl_role = 'RT' saknr = '0000410001' )
      ( ct_uuid = ms_line-ct_uuid mat_uuid = ms_line-mat_uuid
      gl_uuid = lc_gl2 gl_role = 'RC' saknr = '0000410002' ) ).
    cb04_sql->insert_test_data( lt_acct ).
    DATA lt_flow TYPE zif_reing_contab_types=>ty_flow_t.
    lt_flow = VALUE #( ( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR' ) ).
    cb04_sql->insert_test_data( lt_flow ).
    mo_cut = NEW zcl_reing_contab_doc_recl( ).
    mo_cut->mv_test_eba_off = abap_false.
    cb04_poster = NEW #( ).
    mo_cut->zif_reing_contab~set_fi_poster( cb04_poster ).
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 2 doc_type_code = 'ZZZ'
        blart = 'SA' active = abap_true bukrs_rule = 'P' )
      is_trans_projection = ms_projection it_currencies = mt_currencies ).
    DATA lt_prior TYPE zif_reing_contab_types=>ty_step_result_t.
    lt_prior = VALUE #( ( doc_type_code = 'AR' bukrs = 'EBA' belnr = '7000000003' waers = iv_currency
      items = VALUE #( ( item_num = '001' role_code = 'WT' amount = '-53' waers = iv_currency
        prctr = '0000000999' campana = '459' allocation = '1' ) ) ) ).
    mo_cut->zif_reing_contab~set_prior_documents( lt_prior ).
  ENDMETHOD.
  METHOD cb02_prev_reject.
    cb02_recl_given( iv_rate = iv_rate iv_currency = iv_currency ).
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(ls_header) = mo_cut->build_header( ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-exch_rate_1
      exp = COND zreing_ca_line_a-exch_rate_1( WHEN iv_rate = 1 THEN 0 ELSE iv_rate ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-exch_rate_is_set exp = xsdbool( iv_rate <> 1 ) ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    DATA lv_expected TYPE string.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER '004' WITH 'ZZZ' '001' iv_currency 'BRL' INTO lv_expected.
    cl_abap_unit_assert=>assert_true( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_result-error_msg ) exp = lv_expected ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ 1 ]-waers exp = iv_currency ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ 2 ]-waers exp = iv_currency ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ 1 ]-amount exp = 53 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ 2 ]-amount exp = -53 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-waers exp = 'BRL' ).
    " A repeated execute preserves the first error and never reaches FI.
    DATA(ls_again) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-post ).
    cl_abap_unit_assert=>assert_true( ls_again-has_error ).
    cl_abap_unit_assert=>assert_equals( act = ls_again-error_msg exp = ls_result-error_msg ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD nominal_prev_currency_reject.
    cb02_prev_reject( iv_rate = '5.3' iv_currency = 'USD' ).
    cb02_prev_reject( iv_rate = 1 iv_currency = 'USD' ).
    cb02_prev_reject( iv_rate = '5.3' iv_currency = space ).
  ENDMETHOD.


  METHOD cb02_given.
    cb04_given( iv_style = iv_style ).
    ms_line-exch_rate_1 = iv_rate.
    ms_line-ct_currency = iv_currency.
    ms_line-calc_amt = iv_base.
    ms_line-net_amt = iv_base.
    ms_line-bruto_amt = iv_base.
    ms_line-net_trans_amt = CONV decfloat34( iv_base ) * iv_rate.
    ms_line-net_local_amt = ms_line-net_trans_amt.
    mt_pc[ 1 ]-calc_amt = CONV #( CONV decfloat34( iv_base ) / 2 ).
    mt_pc[ 2 ]-calc_amt = iv_base - mt_pc[ 1 ]-calc_amt.
    mt_pc[ 1 ]-net_amt = mt_pc[ 1 ]-calc_amt.
    mt_pc[ 2 ]-net_amt = mt_pc[ 2 ]-calc_amt.
    mt_pc[ 1 ]-bruto_amt = mt_pc[ 1 ]-calc_amt.
    mt_pc[ 2 ]-bruto_amt = mt_pc[ 2 ]-calc_amt.
    mt_pc[ 1 ]-ct_currency = iv_currency.
    mt_pc[ 2 ]-ct_currency = iv_currency.
    mt_pc[ 1 ]-net_local_amt = CONV #( CONV decfloat34( mt_pc[ 1 ]-net_amt ) * iv_rate ).
    mt_pc[ 2 ]-net_local_amt = ms_line-net_local_amt - mt_pc[ 1 ]-net_local_amt.
    cb02_project( ).
    cb04_context( ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_use_trans ).
  ENDMETHOD.

  METHOD cb02_project.
    mt_steps[ step_num = '05' seq = '01' ]-input_amt = ms_line-net_amt.
    mt_steps[ step_num = '05' seq = '01' ]-input_currency = ms_line-ct_currency.
    mt_steps[ step_num = '05' seq = '01' ]-output_amt = ms_line-net_trans_amt.
    mt_steps[ step_num = '05' seq = '01' ]-output_trans_amt = ms_line-net_trans_amt.
    mt_steps[ step_num = '05' seq = '01' ]-rate_pct = ms_line-exch_rate_1.
    mt_steps[ step_num = '05' seq = '02' ]-input_amt = ms_line-net_trans_amt.
    mt_steps[ step_num = '05' seq = '02' ]-output_amt = ms_line-net_local_amt.
    mt_steps[ step_num = '05' seq = '02' ]-output_trans_amt = ms_line-net_local_amt.
    ms_projection = zcl_reing_ca_trans_amounts=>project_line(
      is_line = ms_line it_line_pc = mt_pc it_steps = mt_steps
      it_currencies = mt_currencies iv_eba_off = abap_false ).
    mt_pc = CORRESPONDING #( ms_projection-line_pc ).
  ENDMETHOD.

  METHOD cb02_assert.
    DATA(lv_calls) = cb04_poster->calls.
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = lv_calls + 1 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-exch_rate_1 exp = iv_rate ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-exch_rate_is_set
      exp = xsdbool( iv_rate <> 0 ) ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-bukrs exp = iv_bukrs ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items exp = ls_result-items ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-total_amount exp = iv_amount ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( ls_result-items ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-waers
      exp = COND waers( WHEN iv_nominal = abap_true THEN 'BRL' ELSE ms_line-ct_currency ) ).
    LOOP AT ls_result-items INTO DATA(ls_item).
      cl_abap_unit_assert=>assert_equals( act = ls_item-waers exp = ls_result-waers ).
    ENDLOOP.
    DATA(ls_legacy) = VALUE zif_reing_contab_types=>ty_step_result(
      doc_type_code = 'AR' bukrs = iv_bukrs belnr = '7000000004' items = ls_result-items ).
    IF iv_nominal = abap_true.
      DATA ls_decoded TYPE ty_cb02_payload.
      /ui2/cl_json=>deserialize( EXPORTING json = ls_result-payload CHANGING data = ls_decoded ).
      cl_abap_unit_assert=>assert_equals(
        act = CORRESPONDING zif_reing_contab_types=>ty_step_result( ls_decoded ) exp = ls_legacy ).
      cl_abap_unit_assert=>assert_equals( act = ls_decoded-header exp = cb04_poster->header ).
      DATA(ls_expected) = CORRESPONDING ty_cb02_payload( ls_legacy ).
      ls_expected-header = cb04_poster->header.
      cl_abap_unit_assert=>assert_equals( act = ls_result-payload
        exp = /ui2/cl_json=>serialize( data = ls_expected ) ).
    ELSE.
      cl_abap_unit_assert=>assert_equals( act = ls_result-payload
        exp = /ui2/cl_json=>serialize( data = ls_legacy ) ).
    ENDIF.
  ENDMETHOD.

  METHOD nominal_rate_header.
    cb02_given( ).
    cb02_assert( iv_rate = '5.3' iv_amount = 530 ).
    cl_abap_unit_assert=>assert_equals( act = lines( cb04_poster->items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals(
      act = cb04_poster->items[ role_code = 'GS' prctr = '0000000999' ]-amount exp = 265 ).
    cl_abap_unit_assert=>assert_equals(
      act = cb04_poster->items[ role_code = 'GH' prctr = '0000000123' ]-amount exp = -265 ).
    cb04_context( 'R' ).
    cb02_assert( iv_rate = '5.3' iv_amount = 530 iv_bukrs = 'MUR' ).
    cb04_context( 'O' ).
    cb02_assert( iv_rate = '5.3' iv_amount = 530 iv_bukrs = 'OVR' ).
    cb02_given( iv_style = 'B' ).
    cb02_assert( iv_rate = '5.3' iv_amount = 530 ).
    cl_abap_unit_assert=>assert_equals( act = lines( cb04_poster->items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items[ posting_context = 'AR' ]-amount exp = 530 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items[ posting_context = 'AP' ]-amount exp = -530 ).
  ENDMETHOD.
  METHOD nominal_fraction_exact.
    cb02_given( iv_rate = '0.00001' iv_base = 10000000 ).
    cb02_assert( iv_rate = '0.00001' iv_amount = 100 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items[ role_code = 'GS' prctr = '0000000999' ]-amount
      exp = 50 ).
  ENDMETHOD.
  METHOD nominal_max_rate_exact.
    cb02_given( iv_rate = '9999.99999' iv_base = '0.01' ).
    cb02_assert( iv_rate = '9999.99999' iv_amount = 100 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items[ role_code = 'GS' prctr = '0000000999' ]-amount
      exp = 50 ).
  ENDMETHOD.
  METHOD nominal_same_rate_one.
    cb02_given( iv_rate = 1 iv_currency = 'BRL' ).
    cb02_assert( iv_rate = 0 iv_amount = 100 ).
  ENDMETHOD.
  METHOD nominal_cross_rate_one.
    cb02_given( iv_rate = 1 ).
    cb02_assert( iv_rate = 0 iv_amount = 100 ).
  ENDMETHOD.
  METHOD off_rate_not_sent.
    cb02_given( iv_rate = 5 ).
    ms_projection-calc_trans_amt += 99.
    mo_cut->mv_test_eba_off = abap_true.
    cb04_context( ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cb02_assert( iv_rate = 0 iv_amount = 100 iv_nominal = abap_false ).
  ENDMETHOD.
  METHOD noneba_rate_not_sent.
    cb02_given( iv_rate = 5 ).
    ms_line-bukrs_prest = 'MUR'.
    cb04_context( ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cb02_assert( iv_rate = 0 iv_amount = 100 iv_bukrs = 'MUR' iv_nominal = abap_false ).
  ENDMETHOD.
  METHOD historic_eba_no_rate.
    cb02_given( iv_rate = 5 ).
    DELETE mt_steps WHERE step_num = '05' AND seq = '02'.
    cb04_context( ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cb02_assert( iv_rate = 0 iv_amount = 100 iv_nominal = abap_false ).
  ENDMETHOD.
  METHOD rate_context_reset.
    cb02_given( iv_rate = 5 ).
    DATA(lo_same) = mo_cut.
    cb02_assert( iv_rate = 5 iv_amount = 500 ).
    ms_line-exch_rate_1 = 1.
    ms_line-net_trans_amt = 100.
    ms_line-net_local_amt = 100.
    mt_pc[ 1 ]-net_local_amt = 50.
    mt_pc[ 2 ]-net_local_amt = 50.
    cb02_project( ).
    cb04_context( ).
    cb02_assert( iv_rate = 0 iv_amount = 100 ).
    mo_cut->mv_test_eba_off = abap_true.
    cb04_context( ).
    cb02_assert( iv_rate = 0 iv_amount = 100 iv_nominal = abap_false ).
    mo_cut->mv_test_eba_off = abap_false.
    ms_line-bukrs_prest = 'MUR'.
    cb04_context( ).
    cb02_assert( iv_rate = 0 iv_amount = 100 iv_bukrs = 'MUR' iv_nominal = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut exp = lo_same ).
  ENDMETHOD.
  METHOD auto_reversal_fx_header.
    cb02_given( iv_rate = 5 ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    " Both UPDATE targets are registered SQL doubles, never business tables.
    UPDATE zreing_op_type_c SET auto_reversal = @abap_true, reversal_reason = '01'
      WHERE op_type = @ms_line-op_type.
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = 1 ).
    UPDATE zreing_ca_run_a SET fiscal_period = '01' WHERE calc_run_id = @ms_line-calc_run_id.
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = 1 ).
    cb04_context( ).
    cb02_assert( iv_rate = 5 iv_amount = 500 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-budat
      exp = COND budat( WHEN lv_today(6) = '202601' THEN lv_today ELSE '20260131' ) ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-reversal_date exp = '20260201' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-reversal_reason exp = '01' ).
    UPDATE zreing_ca_run_a SET fiscal_period = '12' WHERE calc_run_id = @ms_line-calc_run_id.
    cl_abap_unit_assert=>assert_equals( act = sy-dbcnt exp = 1 ).
    cb04_context( ).
    cb02_assert( iv_rate = 5 iv_amount = 500 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-budat
      exp = COND budat( WHEN lv_today(6) = '202612' THEN lv_today ELSE '20261231' ) ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-reversal_date exp = '20270101' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-reversal_reason exp = '01' ).
  ENDMETHOD.
  METHOD cb02_bad_rate.
    cb02_given( iv_rate = 5 ).
    ms_line-exch_rate_1 = iv_rate.
    mt_steps[ step_num = '05' seq = '01' ]-rate_pct = iv_rate.
    cb04_context( ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    DATA lv_expected TYPE string.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH ms_line-line_num INTO lv_expected.
    cl_abap_unit_assert=>assert_true( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_result-error_msg ) exp = lv_expected ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD zero_rate_rejects.
    cb02_bad_rate( 0 ).
  ENDMETHOD.
  METHOD negative_rate_rejects.
    cb02_bad_rate( -1 ).
  ENDMETHOD.

  METHOD derived_docs_rate_header.
    cb02_given( ).
    ms_line-bukrs_recv = ms_line-bukrs_prest.
    " V001 (CC) - CB-02: rebuild the canonical snapshot after INT routing changes.
    cb02_project( ).
    mo_cut = NEW zcl_reing_contab_doc_int( ).
    mo_cut->mv_test_eba_off = abap_false.
    mo_cut->zif_reing_contab~set_fi_poster( cb04_poster ).
    cb04_context( ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    cb02_assert( iv_rate = '5.3' iv_amount = 530 ).
    cl_abap_unit_assert=>assert_equals( act = lines( cb04_poster->items ) exp = 4 ).
    cb02_given( ).
    " Preceding WHT and target/counter roles live exclusively in SQL doubles.
    DATA lt_source TYPE STANDARD TABLE OF zreing_gl_roles WITH EMPTY KEY.
    lt_source = VALUE #( ( gl_role = 'WT' posting_context = 'GL' role_category = 'C'
      tax_type = 'T1' reclassify = abap_true role_reclas = 'RT' )
      ( gl_role = 'RT' posting_context = 'GL' role_category = 'C' tax_type = 'T1' )
      ( gl_role = 'RC' posting_context = 'GL' role_category = 'C' ) ).
    cb04_sql->insert_test_data( lt_source ).
    DATA lt_doc TYPE STANDARD TABLE OF zreing_doctype_r WITH EMPTY KEY.
    lt_doc = VALUE #( ( doc_type_code = 'ZZZ' role_code = 'RT' posting_side = 'S' )
      ( doc_type_code = 'ZZZ' role_code = 'RC' posting_side = 'H' ) ).
    cb04_sql->insert_test_data( lt_doc ).
    CONSTANTS lc_gl1 TYPE sysuuid_x16 VALUE '02000000000000000000000000000001'.
    CONSTANTS lc_gl2 TYPE sysuuid_x16 VALUE '02000000000000000000000000000002'.
    DATA lt_acct TYPE STANDARD TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.
    lt_acct = VALUE #( ( ct_uuid = ms_line-ct_uuid mat_uuid = ms_line-mat_uuid
      gl_uuid = lc_gl1 gl_role = 'RT' saknr = '0000410001' )
      ( ct_uuid = ms_line-ct_uuid mat_uuid = ms_line-mat_uuid
      gl_uuid = lc_gl2 gl_role = 'RC' saknr = '0000410002' ) ).
    cb04_sql->insert_test_data( lt_acct ).
    DATA lt_flow TYPE zif_reing_contab_types=>ty_flow_t.
    lt_flow = VALUE #( ( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR' ) ).
    cb04_sql->insert_test_data( lt_flow ).
    mo_cut = NEW zcl_reing_contab_doc_recl( ).
    mo_cut->mv_test_eba_off = abap_false.
    cb04_poster = NEW #( ).
    mo_cut->zif_reing_contab~set_fi_poster( cb04_poster ).
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 2 doc_type_code = 'ZZZ'
        blart = 'SA' active = abap_true bukrs_rule = 'P' )
      is_trans_projection = ms_projection it_currencies = mt_currencies ).
    DATA lt_prior TYPE zif_reing_contab_types=>ty_step_result_t.
    lt_prior = VALUE #( ( doc_type_code = 'AR' bukrs = 'EBA' belnr = '7000000003' waers = 'BRL'
      items = VALUE #( ( item_num = '001' role_code = 'WT' amount = '-53' waers = 'BRL'
        prctr = '0000000999' campana = '459' allocation = '1' ) ) ) ).
    mo_cut->zif_reing_contab~set_prior_documents( lt_prior ).
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-doc_type_code exp = 'ZZZ' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-exch_rate_1 exp = CONV zreing_ca_line_a-exch_rate_1( '5.3' ) ).
    cl_abap_unit_assert=>assert_true( cb04_poster->header-exch_rate_is_set ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-waers exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'RT' ]-amount exp = 53 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'RC' ]-amount exp = -53 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'RT' ]-waers exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'RC' ]-waers exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items exp = ls_result-items ).
    DATA ls_payload TYPE ty_cb02_payload.
    /ui2/cl_json=>deserialize( EXPORTING json = ls_result-payload CHANGING data = ls_payload ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-header exp = cb04_poster->header ).
  ENDMETHOD.


  METHOD class_setup.
    cb04_sql = cl_osql_test_environment=>create( VALUE #(
      ( 'ZREING_CA_RUN_A' ) ( 'ZREING_OP_TYPE_C' ) ( 'ZREING_DOCTYPE_R' )
      ( 'ZREING_GL_ROLES' ) ( 'ZREING_CT2_GL_A' ) ( 'ZREING_DOCFLOW_C' )
      ( 'ZI_COMPANYCODEADDLINFORMATION' ) ( 'ZC_INTERCORELATIONSHIP' )
      ( 'ZI_REINGCBCUSTOMERRECON' ) ( 'ZI_REINGCBSUPPLIERRECON' )
      ( 'ZI_REINGCBPRODUCTTEXT' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    cb04_sql->destroy( ).
  ENDMETHOD.
  METHOD teardown.
    cb04_sql->clear_doubles( ).
    CLEAR cb04_poster.
  ENDMETHOD.

  METHOD cb04_given.
    " Reuse the sole injection; production context and CA-08 projection stay real.
    given_trans( ).
    mo_cut = NEW zcl_reing_contab_doc( ).
    cb04_sql->clear_doubles( ).
    CONSTANTS lc_ct TYPE sysuuid_x16 VALUE '04000000000000000000000000000001'.
    CONSTANTS lc_mat TYPE sysuuid_x16 VALUE '04000000000000000000000000000002'.
    CONSTANTS lc_gl1 TYPE sysuuid_x16 VALUE '04000000000000000000000000000003'.
    CONSTANTS lc_gl2 TYPE sysuuid_x16 VALUE '04000000000000000000000000000004'.
    CONSTANTS lc_gl3 TYPE sysuuid_x16 VALUE '04000000000000000000000000000005'.
    ms_line-calc_run_id = 'UT-CB04'.
    ms_line-ct_uuid = lc_ct.
    ms_line-mat_uuid = lc_mat.
    ms_line-matnr = 'UTCB04'.
    ms_line-calc_amt = COND #( WHEN iv_zero = abap_true THEN 0 ELSE 100 ).
    ms_line-net_amt = ms_line-calc_amt.
    ms_line-tax_amt = iv_tax.
    ms_line-bruto_amt = ms_line-calc_amt + iv_tax.
    ms_line-net_trans_amt = ms_line-net_amt * ms_line-exch_rate_1.
    ms_line-net_local_amt = ms_line-net_trans_amt.
    mt_pc = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 1
        prctr = '999' campana = '459' allocation = '1' role_category = 'C'
        ct_currency = 'USD' local_currency = 'BRL' share_abs = iv_weight
        calc_amt = COND #( WHEN iv_zero = abap_true THEN 0 ELSE iv_weight )
        net_amt = COND #( WHEN iv_zero = abap_true THEN 0 ELSE iv_weight ) )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 2
        prctr = '123' campana = '123' allocation = '3' role_category = 'E'
        ct_currency = 'USD' local_currency = 'BRL' share_abs = 100 - iv_weight
        calc_amt = COND #( WHEN iv_zero = abap_true THEN 0 ELSE 100 - iv_weight )
        net_amt = COND #( WHEN iv_zero = abap_true THEN 0 ELSE 100 - iv_weight ) ) ).
    mt_pc[ 1 ]-tax_amt = CONV zreing_ca_line_a-tax_amt(
      CONV decfloat34( iv_tax ) * iv_weight / 100 ).
    mt_pc[ 2 ]-tax_amt = iv_tax - mt_pc[ 1 ]-tax_amt.
    mt_pc[ 1 ]-bruto_amt = mt_pc[ 1 ]-calc_amt + mt_pc[ 1 ]-tax_amt.
    mt_pc[ 2 ]-bruto_amt = mt_pc[ 2 ]-calc_amt + mt_pc[ 2 ]-tax_amt.
    mt_pc[ 1 ]-net_local_amt = mt_pc[ 1 ]-net_amt * ms_line-exch_rate_1.
    mt_pc[ 2 ]-net_local_amt = mt_pc[ 2 ]-net_amt * ms_line-exch_rate_1.
    mt_steps = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '04' seq = '01'
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'T1'
        output_amt = iv_tax output_trans_amt = iv_tax * ms_line-exch_rate_1 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '01'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = ms_line-net_amt
        input_currency = 'USD' output_amt = ms_line-net_trans_amt
        output_currency = 'BRL' rate_pct = ms_line-exch_rate_1 output_trans_amt = ms_line-net_trans_amt )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '02'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = ms_line-net_trans_amt
        input_currency = 'BRL' output_amt = ms_line-net_local_amt
        output_currency = 'BRL' rate_pct = 1 output_trans_amt = ms_line-net_local_amt ) ).
    ms_projection = zcl_reing_ca_trans_amounts=>project_line(
      is_line = ms_line it_line_pc = mt_pc it_steps = mt_steps
      it_currencies = mt_currencies iv_eba_off = abap_false ).
    " Persisted LPC TRANS and the canonical projection must share one snapshot.
    mt_pc = CORRESPONDING #( ms_projection-line_pc ).

    DATA lt_run TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    lt_run = VALUE #( ( calc_run_id = ms_line-calc_run_id fiscal_year = '2026' fiscal_period = '09' ) ).
    cb04_sql->insert_test_data( lt_run ).
    DATA lt_op TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    lt_op = VALUE #( ( op_type = ms_line-op_type active = abap_true ) ).
    cb04_sql->insert_test_data( lt_op ).
    DATA lt_addl TYPE STANDARD TABLE OF zi_companycodeaddlinformation WITH EMPTY KEY.
    lt_addl = VALUE #(
      ( companycode = 'MUR' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '333' ) ).
    IF iv_missing <> 'E'.
      APPEND VALUE #( companycode = 'EBA' companycodeparametertype = 'ZIC003'
        companycodeparametervalue = 'X' ) TO lt_addl.
    ENDIF.
    IF iv_missing <> 'C'.
      APPEND VALUE #( companycode = 'EBA' companycodeparametertype = 'ZIDMEL'
        companycodeparametervalue = '111' ) TO lt_addl.
    ENDIF.
    IF iv_missing <> 'R'.
      APPEND VALUE #( companycode = 'MUR' companycodeparametertype = 'ZIDMEL'
        companycodeparametervalue = '222' ) TO lt_addl.
    ENDIF.
    cb04_sql->insert_test_data( lt_addl ).
    DATA lt_ic TYPE STANDARD TABLE OF zc_intercorelationship WITH EMPTY KEY.
    lt_ic = VALUE #( ( providerbusinesspartner = '0000000001' recipientbusinesspartner = '0000000002'
      providercompanycode = 'EBA' recipientcompanycode = 'MUR'
      recipientcustomer = '0000000001' providervendor = '0000000002' ) ).
    cb04_sql->insert_test_data( lt_ic ).
    DATA lt_ar TYPE STANDARD TABLE OF zi_reingcbcustomerrecon WITH EMPTY KEY.
    lt_ar = VALUE #( ( customer = '0000000001' companycode = 'EBA' reconciliationaccount = '0000110000' ) ).
    cb04_sql->insert_test_data( lt_ar ).
    DATA lt_ap TYPE STANDARD TABLE OF zi_reingcbsupplierrecon WITH EMPTY KEY.
    lt_ap = VALUE #( ( supplier = '0000000002' companycode = 'MUR' reconciliationaccount = '0000210000' ) ).
    cb04_sql->insert_test_data( lt_ap ).

    DATA lt_roles TYPE STANDARD TABLE OF zreing_gl_roles WITH EMPTY KEY.
    DATA lt_doc TYPE STANDARD TABLE OF zreing_doctype_r WITH EMPTY KEY.
    DATA lt_accounts TYPE STANDARD TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.
    DATA(lv_debit) = CONV shkzg( COND #( WHEN iv_credit = abap_true THEN 'H' ELSE 'S' ) ).
    DATA(lv_credit) = CONV shkzg( COND #( WHEN iv_credit = abap_true THEN 'S' ELSE 'H' ) ).
    CASE iv_style.
      WHEN 'T'.
        lt_roles = VALUE #(
          ( gl_role = 'TC' posting_context = 'GL' role_category = 'C' role_type = 'T' tax_type = 'T1' )
          ( gl_role = 'TE' posting_context = 'GL' role_category = 'E' role_type = 'T' tax_type = 'T1' )
          ( gl_role = 'TA' posting_context = 'GL' role_type = 'T' tax_type = 'T1' ) ).
        lt_doc = VALUE #( ( doc_type_code = 'AR' role_code = 'TC' posting_side = lv_debit )
          ( doc_type_code = 'AR' role_code = 'TE' posting_side = lv_debit )
          ( doc_type_code = 'AR' role_code = 'TA' posting_side = lv_credit ) ).
        lt_accounts = VALUE #( ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl1
          gl_role = 'TC' saknr = '0000410000' ) ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl2
          gl_role = 'TE' saknr = '0000410000' ) ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl3
          gl_role = 'TA' saknr = '0000410000' ) ).
      WHEN 'A'.
        lt_roles = VALUE #( ( gl_role = 'GS' posting_context = 'GL' role_type = 'T' tax_type = 'T1' )
          ( gl_role = 'GH' posting_context = 'GL' role_type = 'T' tax_type = 'T1' ) ).
        lt_doc = VALUE #( ( doc_type_code = 'AR' role_code = 'GS' posting_side = 'S' )
          ( doc_type_code = 'AR' role_code = 'GH' posting_side = 'H' ) ).
        lt_accounts = VALUE #( ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl1
          gl_role = 'GS' saknr = '0000410000' ) ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl2
          gl_role = 'GH' saknr = '0000410000' ) ).
      WHEN 'B'.
        lt_roles = VALUE #( ( gl_role = 'RA' posting_context = 'AR' )
          ( gl_role = 'PA' posting_context = 'AP' ) ).
        lt_doc = VALUE #( ( doc_type_code = 'AR' role_code = 'RA' posting_side = 'S' )
          ( doc_type_code = 'AR' role_code = 'PA' posting_side = 'H' ) ).
      WHEN OTHERS.
        lt_roles = VALUE #( ( gl_role = 'GS' posting_context = 'GL' )
          ( gl_role = 'GH' posting_context = 'GL' ) ).
        lt_doc = VALUE #( ( doc_type_code = 'AR' role_code = 'GS' posting_side = 'S' )
          ( doc_type_code = 'AR' role_code = 'GH' posting_side = 'H' ) ).
        lt_accounts = VALUE #( ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl1
          gl_role = 'GS' saknr = '0000410000' ) ( ct_uuid = lc_ct mat_uuid = lc_mat gl_uuid = lc_gl2
          gl_role = 'GH' saknr = '0000410000' ) ).
    ENDCASE.
    cb04_sql->insert_test_data( lt_roles ).
    cb04_sql->insert_test_data( lt_doc ).
    IF lt_accounts IS NOT INITIAL.
      cb04_sql->insert_test_data( lt_accounts ).
    ENDIF.
    mo_cut->mv_test_eba_off = iv_off.
    cb04_poster = NEW #( ).
    mo_cut->zif_reing_contab~set_fi_poster( cb04_poster ).
    cb04_context( ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_use_trans exp = xsdbool( iv_off = abap_false ) ).
  ENDMETHOD.

  METHOD cb04_context.
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR'
        blart = 'SA' active = abap_true bukrs_rule = iv_rule bukrs_override = 'OVR' )
      is_trans_projection = ms_projection it_currencies = mt_currencies ).
  ENDMETHOD.

  METHOD cb04_assert_tax.
    cb04_given( iv_off = iv_off iv_tax = iv_tax iv_style = 'T' iv_credit = iv_credit ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-has_error exp = iv_error ).
    DATA(lv_currency) = CONV waers( COND #( WHEN iv_off = abap_true THEN 'USD' ELSE 'BRL' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-waers exp = lv_currency ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-items ) exp = 4 ).
    DATA(lv_side_amount) = COND zreing_ca_line_a-net_amt(
      WHEN iv_credit = abap_true THEN - iv_expected ELSE iv_expected ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-items[ role_code = 'TC' ]-amount exp = lv_side_amount ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-items[ role_code = 'TE' ]-amount exp = lv_side_amount ).

    DATA(lv_tax_total) = COND zreing_ca_line_a-net_amt(
      WHEN iv_off = abap_true THEN iv_tax ELSE iv_tax * ms_line-exch_rate_1 ).
    DATA(lv_ta_first) = COND zreing_ca_line_a-net_amt(
      WHEN iv_credit = abap_true THEN iv_expected ELSE - iv_expected ).
    DATA(lv_ta_last) = COND zreing_ca_line_a-net_amt(
      WHEN iv_credit = abap_true THEN lv_tax_total - iv_expected ELSE iv_expected - lv_tax_total ).
    DATA(ls_ta_first) = ls_result-items[ role_code = 'TA' prctr = '0000000999' ].
    DATA(ls_ta_last) = ls_result-items[ role_code = 'TA' prctr = '0000000123' ].
    cl_abap_unit_assert=>assert_equals( act = ls_ta_first-amount exp = lv_ta_first ).
    cl_abap_unit_assert=>assert_equals( act = ls_ta_last-amount exp = lv_ta_last ).
    cl_abap_unit_assert=>assert_equals(
      act = CONV i( ls_ta_last-item_num ) - CONV i( ls_ta_first-item_num ) exp = 1 ).

    IF iv_error = abap_true.
      DATA(lv_balance) = mo_cut->calculate_balance( ls_result-items ).
      cl_abap_unit_assert=>assert_equals(
        act = lv_balance exp = COND zreing_ca_line_a-net_amt(
          WHEN iv_credit = abap_true THEN '-0.01' ELSE '0.01' ) ).
      cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
      cl_abap_unit_assert=>assert_char_cp( act = ls_result-error_msg
        exp = |Documento AR descuadrado en *{ lv_currency }*| ).
      DATA(lt_before) = ls_result-items.
      mo_cut->adjust_rounding( CHANGING ct_items = ls_result-items ).
      cl_abap_unit_assert=>assert_equals( act = ls_result-items exp = lt_before ).
    ELSE.
      cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( ls_result-items ) exp = 0 ).
      cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
      cl_abap_unit_assert=>assert_equals( act = cb04_poster->items exp = ls_result-items ).
      cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-waers exp = lv_currency ).
      cl_abap_unit_assert=>assert_equals( act = cb04_poster->mode exp = zif_reing_ca_c=>contab_mode-check ).
      cl_abap_unit_assert=>assert_equals( act = ls_result-total_amount exp = iv_expected * 2 ).
    ENDIF.
    DATA lv_position TYPE n LENGTH 3.
    LOOP AT ls_result-items INTO DATA(ls_item).
      lv_position += 1.
      cl_abap_unit_assert=>assert_equals( act = ls_item-item_num exp = lv_position ).
      cl_abap_unit_assert=>assert_equals( act = ls_item-waers exp = lv_currency ).
      cl_abap_unit_assert=>assert_not_initial( ls_item-kostl ).
    ENDLOOP.
  ENDMETHOD.

  METHOD cb04_assert_ceco.
    cb04_context( iv_rule ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-bukrs exp = iv_bukrs ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_internal_code exp = iv_code ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-items[ role_code = 'GS' prctr = '0000000999' ]-kostl
      exp = CONV kostl( |4591{ iv_code }999| ) ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-items[ role_code = 'GS' prctr = '0000000123' ]-kostl
      exp = CONV kostl( |1233{ iv_code }123| ) ).
    DATA(lv_amount) = CONV zreing_ca_line_a-net_amt(
      COND #( WHEN mo_cut->mv_test_eba_off = abap_true THEN 50 ELSE 250 ) ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-items[ role_code = 'GS' prctr = '0000000999' ]-amount exp = lv_amount ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( ls_result-items ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items exp = ls_result-items ).
  ENDMETHOD.

  METHOD cb04_assert_missing.
    cb04_given( iv_off = iv_off iv_missing = iv_missing ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_true( ls_result-has_error ).
    DATA lv_expected TYPE string.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER '002' WITH 'AR' 'EBA' INTO lv_expected.
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_result-error_msg ) exp = lv_expected ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_internal_code ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.

  METHOD cb04_assert_recovery.
    cb04_given( iv_off = iv_off iv_missing = 'R' ).
    cb04_assert_ceco( iv_rule = 'P' iv_bukrs = 'EBA' iv_code = '111' ).
    cb04_context( 'R' ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_internal_code ).
    DATA(ls_failed) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    DATA lv_expected TYPE string.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER '002' WITH 'AR' 'MUR' INTO lv_expected.
    cl_abap_unit_assert=>assert_true( ls_failed-has_error ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_failed-error_msg ) exp = lv_expected ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-bukrs exp = 'EBA' ).
    cb04_assert_ceco( iv_rule = 'O' iv_bukrs = 'OVR' iv_code = '333' ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 2 ).
  ENDMETHOD.

  METHOD cb04_assert_bp.
    cb04_given( iv_off = iv_off iv_style = 'B' iv_missing = 'C' ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_internal_code ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( ls_result-items[ posting_context = 'AR' ]-kostl ).
    cl_abap_unit_assert=>assert_initial( ls_result-items[ posting_context = 'AP' ]-kostl ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( ls_result-items ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items exp = ls_result-items ).
  ENDMETHOD.

  METHOD cb04_assert_zero.
    cb04_given( iv_off = iv_off iv_missing = 'C' iv_zero = abap_true ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(lt_items) = mo_cut->build_items( mo_cut->find_roles_for_step( ) ).
    cl_abap_unit_assert=>assert_initial( lt_items ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.

  METHOD legacy_tax_pairs_pass.
    cb04_assert_tax( iv_off = abap_true iv_tax = '0.02' iv_expected = '0.01' ).
  ENDMETHOD.
  METHOD nominal_tax_pairs_pass.
    cb04_assert_tax( iv_off = abap_false iv_tax = '0.02' iv_expected = '0.05' ).
  ENDMETHOD.
  METHOD legacy_category_cent_reject.
    cb04_assert_tax( iv_off = abap_true iv_tax = '0.01' iv_expected = '0.01' iv_error = abap_true ).
  ENDMETHOD.
  METHOD nominal_category_cent_reject.
    cb04_assert_tax( iv_off = abap_false iv_tax = '0.01' iv_expected = '0.03' iv_error = abap_true ).
  ENDMETHOD.
  METHOD nominal_credit_cent_reject.
    cb04_assert_tax( iv_off = abap_false iv_tax = '0.01' iv_expected = '0.03'
      iv_error = abap_true iv_credit = abap_true ).
  ENDMETHOD.
  METHOD nominal_role_residue_pass.
    cb04_given( iv_tax = '0.01' iv_style = 'A' iv_weight = 70 ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'GS' prctr = '0000000999' ]-amount
      exp = CONV zreing_ca_line_a-net_amt( '0.04' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'GS' prctr = '0000000123' ]-amount
      exp = CONV zreing_ca_line_a-net_amt( '0.01' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'GH' prctr = '0000000999' ]-amount
      exp = CONV zreing_ca_line_a-net_amt( '-0.04' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-items[ role_code = 'GH' prctr = '0000000123' ]-amount
      exp = CONV zreing_ca_line_a-net_amt( '-0.01' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( ls_result-items ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-total_amount exp = CONV zreing_ca_line_a-net_amt( '0.05' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-waers exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->items exp = ls_result-items ).
  ENDMETHOD.
  METHOD legacy_ceco_context_refresh.
    cb04_given( iv_off = abap_true ).
    cb04_assert_ceco( iv_rule = 'P' iv_bukrs = 'EBA' iv_code = '111' ).
    cb04_assert_ceco( iv_rule = 'R' iv_bukrs = 'MUR' iv_code = '222' ).
    cb04_assert_ceco( iv_rule = 'O' iv_bukrs = 'OVR' iv_code = '333' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 3 ).
  ENDMETHOD.
  METHOD nominal_ceco_context_refresh.
    cb04_given( ).
    cb04_assert_ceco( iv_rule = 'P' iv_bukrs = 'EBA' iv_code = '111' ).
    cb04_assert_ceco( iv_rule = 'R' iv_bukrs = 'MUR' iv_code = '222' ).
    cb04_assert_ceco( iv_rule = 'O' iv_bukrs = 'OVR' iv_code = '333' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 3 ).
  ENDMETHOD.
  METHOD legacy_code_missing_cold.
    cb04_assert_missing( iv_off = abap_true iv_missing = 'C' ).
  ENDMETHOD.
  METHOD nominal_code_missing_cold.
    cb04_assert_missing( iv_off = abap_false iv_missing = 'E' ).
  ENDMETHOD.
  METHOD legacy_code_reset_recovery.
    cb04_assert_recovery( abap_true ).
  ENDMETHOD.
  METHOD nominal_code_reset_recovery.
    cb04_assert_recovery( abap_false ).
  ENDMETHOD.
  METHOD bp_only_without_code.
    cb04_assert_bp( abap_true ).
    cb04_assert_bp( abap_false ).
  ENDMETHOD.
  METHOD zero_gl_without_code.
    cb04_assert_zero( abap_true ).
    cb04_assert_zero( abap_false ).
  ENDMETHOD.
  METHOD code_missing_prior_error.
    cb04_given( iv_missing = 'C' ).
    ms_projection-calc_trans_amt += 1.
    cb04_context( ).
    DATA lv_expected TYPE string.
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH ms_line-line_num INTO lv_expected.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_trans_error exp = lv_expected ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_true( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_result-error_msg ) exp = lv_expected ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.

  METHOD setup.
    " V001 (CC) - CB-04: clear SQL doubles before every historical or new test.
    cb04_sql->clear_doubles( ).
    mo_cut = NEW zcl_reing_contab_doc( ).
    " Contexto mínimo común (sin BD): total de la línea + internal code.
    " V008 (17.09.2026): BRUTO_AMT además de NET_AMT — desde este fix el
    " monto que se postea es el bruto (definición de Rochelle del
    " 17.09.2026: la retención no reduce el AP). Se dejan los dos con el
    " mismo valor, que es la situación de una línea sin impuestos.
    mo_cut->ms_line_a        = VALUE #( line_num    = '0000001'
                                       calc_amt    = 1000
                                       bruto_amt   = 1000
                                       net_amt     = 1000
                                       ct_currency = 'USD' ).
    mo_cut->mv_internal_code = 'ABC'.
  ENDMETHOD.

  METHOD make_gl_role.
    rs_role = VALUE #(
      role_code       = iv_role_code
      role_category   = iv_role_category
      posting_context = 'GL'
      posting_side    = iv_posting_side ).
  ENDMETHOD.

  METHOD make_pc.
    " V008: BRUTO_AMT es el campo que append_gl_items postea para un rol sin
    " TAX_TYPE, así que el helper llena los dos importes con el mismo valor
    " (fila sin impuestos). SHARE_ABS solo hace falta para los tests de la
    " Regla C; por defecto queda en cero y el prorrateo cae en su fallback
    " por BRUTO_AMT.
    rs_pc = VALUE #(
      role_category = iv_role_category
      campana       = iv_campana
      allocation    = iv_allocation
      prctr         = iv_prctr
      share_abs     = iv_share_abs
      bruto_amt     = iv_net_amt
      net_amt       = iv_net_amt ).
  ENDMETHOD.

  METHOD gl_abre_por_pc.
    " Un rol GL categoría C + 3 profit centers C -> 3 items GL,
    " cada uno con el monto/prctr/campana/allocation de SU fila de LPC_A.
    mo_cut->mt_gl_account = VALUE #( ( gl_role = 'RGL' saknr = '0000410000' ) ).
    mo_cut->mt_line_pc = VALUE #(
      ( make_pc( iv_role_category = 'C' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000111' iv_net_amt = 300 ) )
      ( make_pc( iv_role_category = 'C' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000222' iv_net_amt = 200 ) )
      ( make_pc( iv_role_category = 'C' iv_campana = '200' iv_allocation = '3'
                 iv_prctr = '0000000333' iv_net_amt = 500 ) ) ).

    DATA(lt_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( make_gl_role( iv_role_code = 'RGL' iv_role_category = 'C' ) ) ).

    DATA(lt_items) = mo_cut->build_items( lt_roles ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_items ) exp = 3
      msg = 'Debe generar 1 item por cada profit center de categoría C' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ prctr = '0000000222' ]-amount exp = 200
      msg = 'El monto del item debe venir de su fila de LPC_A' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ prctr = '0000000333' ]-campana exp = '200'
      msg = 'La campaña del item debe venir del PC' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ prctr = '0000000333' ]-allocation exp = '3'
      msg = 'La asignación del item debe venir del PC' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ prctr = '0000000111' ]-hkont exp = '0000410000'
      msg = 'La cuenta GL debe salir de mt_gl_account por rol' ).
  ENDMETHOD.

  METHOD gl_filtra_por_role_cat.
    " PCs de categoría C y E; un rol C solo abre contra los C.
    mo_cut->mt_line_pc = VALUE #(
      ( make_pc( iv_role_category = 'C' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000111' iv_net_amt = 300 ) )
      ( make_pc( iv_role_category = 'E' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000222' iv_net_amt = 700 ) ) ).

    DATA(lt_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( make_gl_role( iv_role_code = 'RGL' iv_role_category = 'C' ) ) ).

    DATA(lt_items) = mo_cut->build_items( lt_roles ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_items ) exp = 1
      msg = 'Un rol de categoría C solo abre contra PC de categoría C' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ 1 ]-prctr exp = '0000000111'
      msg = 'Debe tomar el PC de categoría C, no el E' ).
  ENDMETHOD.

  METHOD ar_ap_una_linea_total.
    " V001 (CC) — fixes-049 (Delta v2).
    " AR toma CALC_AMT tanto en la posicion BP como en su GL ordinario.
    " AP mantiene BRUTO_AMT; ninguno se abre en la posicion BP.
    mo_cut->mv_ar_partner    = '0001000001'.
    mo_cut->mv_ap_partner    = '0002000002'.
    mo_cut->mv_ar_recon_acct = '0000140000'.
    mo_cut->mv_ap_recon_acct = '0000160000'.
    mo_cut->ms_line_a-calc_amt  = 900.
    mo_cut->ms_line_a-bruto_amt = 1000.
    mo_cut->mt_gl_account = VALUE #(
      ( gl_role = 'RGL' saknr = '0000410000' ) ).
    mo_cut->mt_line_pc = VALUE #(
      ( make_pc( iv_role_category = 'C'
                 iv_campana       = '100'
                 iv_allocation    = '1'
                 iv_prctr         = '0000000111'
                 iv_net_amt       = 1000 ) ) ).
    mo_cut->mt_line_pc[ 1 ]-calc_amt = 900.

    " El contexto del documento se determina por POSTING_CONTEXT, no por codigo.
    mo_cut->mt_role_master = VALUE #(
      ( gl_role = 'RAR' posting_context = 'AR' )
      ( gl_role = 'RGL' posting_context = 'GL' ) ).

    DATA(lt_ar_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( role_code = 'RAR' posting_context = 'AR' posting_side = 'S' )
      ( role_code = 'RGL' posting_context = 'GL' posting_side = 'H'
        role_category = 'C' ) ).
    DATA(lt_ar_items) = mo_cut->build_items( lt_ar_roles ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_ar_items ) exp = 2
      msg = 'AR debe generar una posicion BP y su contrapartida GL' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_ar_items[ role_code = 'RAR' ]-amount exp = 900
      msg = 'La posicion AR debe tomar CALC_AMT' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_ar_items[ role_code = 'RGL' ]-amount exp = -900
      msg = 'La contrapartida GL de AR debe tomar LINE_PC_A-CALC_AMT' ).
    cl_abap_unit_assert=>assert_initial(
      act = mo_cut->calculate_balance( lt_ar_items )
      msg = 'El documento AR debe cuadrar con la misma base CALC_AMT' ).

    DATA(lt_ap_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( role_code = 'RAP' posting_context = 'AP' posting_side = 'H' ) ).
    DATA(lt_ap_items) = mo_cut->build_items( lt_ap_roles ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_ap_items ) exp = 1
      msg = 'AP genera una sola posicion BP sin apertura por PC' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_ap_items[ 1 ]-amount exp = -1000
      msg = 'La posicion AP debe conservar BRUTO_AMT' ).
  ENDMETHOD.

  " Begin Insert V010 (21.09.2026 | EXT_GONZALCA)
  METHOD apic_rrec_balances.
    " Complete AP scenario: APIC is the BP credit and RREC(C) is the GL
    " debit generated from the matching C breakdown. This closes the gap
    " between the previous isolated AP and role-category tests.
    mo_cut->mv_ap_partner    = '0002000002'.
    mo_cut->mv_ap_recon_acct = '0000160000'.
    mo_cut->mt_gl_account = VALUE #(
      ( gl_role = 'RREC' saknr = '0000620201' ) ).
    mo_cut->mt_line_pc = VALUE #(
      ( make_pc( iv_role_category = 'C'
                 iv_campana       = '100'
                 iv_allocation    = '1'
                 iv_prctr         = '0000000111'
                 iv_net_amt       = 1000 ) ) ).

    DATA(lt_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( role_code       = 'APIC'
        posting_context = 'AP'
        posting_side    = 'H'
        auto_determ     = abap_true )
      ( make_gl_role( iv_role_code     = 'RREC'
                      iv_role_category = 'C'
                      iv_posting_side  = 'S' ) ) ).

    DATA(lt_items) = mo_cut->build_items( lt_roles ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_items )
      exp = 2
      msg = 'AP must contain APIC and its RREC counterpart' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ role_code = 'APIC' ]-amount
      exp = CONV zreing_ca_line_a-net_amt( -1000 )
      msg = 'APIC must credit the complete gross amount' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ role_code = 'RREC' ]-amount
      exp = CONV zreing_ca_line_a-net_amt( 1000 )
      msg = 'RREC(C) must debit the matching C breakdown' ).
    cl_abap_unit_assert=>assert_initial(
      act = mo_cut->calculate_balance( lt_items )
      msg = 'APIC plus RREC must balance exactly' ).
  ENDMETHOD.
  " End Insert V010 (21.09.2026 | EXT_GONZALCA)

  METHOD item_num_secuencial.
    " 2 items GL (C) + 1 item AR -> item_num 001, 002, 003.
    mo_cut->mv_ar_recon_acct = '0000140000'.
    mo_cut->mt_line_pc = VALUE #(
      ( make_pc( iv_role_category = 'C' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000111' iv_net_amt = 300 ) )
      ( make_pc( iv_role_category = 'C' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000222' iv_net_amt = 700 ) ) ).

    DATA(lt_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( make_gl_role( iv_role_code = 'RGL' iv_role_category = 'C' ) )
      ( role_code = 'RAR' posting_context = 'AR' posting_side = 'S' ) ).

    DATA(lt_items) = mo_cut->build_items( lt_roles ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-item_num exp = '001' ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-item_num exp = '002' ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 3 ]-item_num exp = '003' ).
  ENDMETHOD.

  METHOD kostl_layout.
    " KOSTL(10) = CAMPANA(3) + ALLOCATION(1) + INTERNAL(3) + PRCTR últimos 3.
    " internal_code = 'ABC' (setup). PRCTR '0000000123' -> últimos 3 = '123'.
    DATA(lv_kostl) = mo_cut->determine_kostl(
      iv_campana    = '100'
      iv_allocation = '1'
      iv_prctr      = '0000000123' ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_kostl exp = '1001ABC123'
      msg = 'KOSTL = CAMPANA(3)+ALLOCATION(1)+INTERNAL(3)+PRCTR₃' ).
  ENDMETHOD.

  METHOD tax_role_prorrateo.
    " Regla C (ET-REING-CONTAB-001 SS8.7), V008 del 17.09.2026.
    " Apertura 70% Expenses / 30% COGS y un único paso TAX de WHT por 100,00.
    " Lo que se verifica:
    "   - el rol de impuesto NO postea el importe de la línea (antes posteaba
    "     NET_AMT, o sea 1000), sino el OUTPUT_AMT del paso TAX;
    "   - cada rol se lleva SU porción (70 / 30) y no el impuesto entero, que
    "     es el error que produciría prorratear sobre las filas filtradas;
    "   - la contrapartida agnóstica (sin role_category) abre contra las dos
    "     filas y suma el impuesto completo, así que el asiento cuadra.
    mo_cut->mt_gl_account = VALUE #(
      ( gl_role = 'RWHE' saknr = '0000640001' )
      ( gl_role = 'RWHC' saknr = '0000640002' )
      ( gl_role = 'RWHP' saknr = '0000210001' ) ).
    mo_cut->mt_line_pc = VALUE #(
      ( make_pc( iv_role_category = 'E' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000111' iv_net_amt = 700 iv_share_abs = '70.000000' ) )
      ( make_pc( iv_role_category = 'C' iv_campana = '100' iv_allocation = '1'
                 iv_prctr = '0000000222' iv_net_amt = 300 iv_share_abs = '30.000000' ) ) ).
    mo_cut->mt_step_a = VALUE #(
      ( line_num      = '0000001'
        step_num      = '04'
        seq           = '01'
        step_category = zif_reing_ca_c=>step_category-tax
        tax_type      = 'WHT'
        output_amt    = 100 ) ).

    DATA(lt_roles) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( role_code = 'RWHE' role_category = 'E' posting_context = 'GL'
        posting_side = 'S' tax_type = 'WHT' )
      ( role_code = 'RWHC' role_category = 'C' posting_context = 'GL'
        posting_side = 'S' tax_type = 'WHT' )
      ( role_code = 'RWHP' posting_context = 'GL'
        posting_side = 'H' tax_type = 'WHT' ) ).

    DATA(lt_items) = mo_cut->build_items( lt_roles ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ role_code = 'RWHE' ]-amount exp = 70
      msg = 'El rol de Expenses toma la porción E del impuesto, no el total' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_items[ role_code = 'RWHC' ]-amount exp = 30
      msg = 'El rol de COGS toma la porción C' ).

    DATA(lv_whp) = REDUCE zreing_ca_line_a-net_amt(
                     INIT s = CONV zreing_ca_line_a-net_amt( 0 )
                     FOR ls_whp IN lt_items WHERE ( role_code = 'RWHP' )
                     NEXT s = s + ls_whp-amount ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_whp exp = -100
      msg = 'La contrapartida al Haber lleva el impuesto completo' ).

    DATA(lv_balance) = mo_cut->calculate_balance( lt_items ).
    cl_abap_unit_assert=>assert_initial(
      act = lv_balance
      msg = 'Las líneas de impuesto tienen que cuadrar entre sí' ).
  ENDMETHOD.

  " Begin Insert V009 (21.09.2026 | EXT_GONZALCA)
  METHOD balance_keeps_decimals.
    DATA(lt_items) = VALUE zif_reing_contab_types=>ty_doc_item_t(
      ( amount = '0.49' )
      ( amount = '-0.48' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->calculate_balance( lt_items )
      exp = CONV zreing_ca_line_a-net_amt( '0.01' )
      msg = 'The balance must preserve cents in every intermediate sum' ).
  ENDMETHOD.

  METHOD balance_exact_zero.
    DATA(lt_items) = VALUE zif_reing_contab_types=>ty_doc_item_t(
      ( amount = '2033.71' )
      ( amount = '-42.90' )
      ( amount = '-1990.81' ) ).

    cl_abap_unit_assert=>assert_initial(
      act = mo_cut->calculate_balance( lt_items )
      msg = 'A document with split credits must balance exactly' ).
  ENDMETHOD.

  METHOD total_amount_one_side.
    DATA(lt_items) = VALUE zif_reing_contab_types=>ty_doc_item_t(
      ( amount = '2033.71' )
      ( amount = '-42.90' )
      ( amount = '-1990.81' ) ).

    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->calculate_total_amount( lt_items )
      exp = CONV zreing_ca_line_a-net_amt( '2033.71' )
      msg = 'TOTAL_AMOUNT must contain one effective side of the document' ).
  ENDMETHOD.
  " End Insert V009 (21.09.2026 | EXT_GONZALCA)

  METHOD apply_sign_debe_haber.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->apply_sign( iv_amount = 100 iv_posting_side = 'S' )
      exp = 100
      msg = 'Debe (S) mantiene el signo' ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->apply_sign( iv_amount = 100 iv_posting_side = 'H' )
      exp = -100
      msg = 'Haber (H) invierte el signo' ).
  ENDMETHOD.


  METHOD given_trans.
    TEST-INJECTION cb01_doc_guard.
      lv_eba_off = mv_test_eba_off.
    END-TEST-INJECTION.

    ms_line = VALUE #( calc_run_id = 'UT-CB01' line_num = 1 bukrs_prest = 'EBA' bukrs_recv = 'MUR'
      ct_currency = 'USD' trans_currency = 'BRL' local_currency = 'BRL' op_type = 'F'
      calc_amt = 100 bruto_amt = 125 tax_amt = 25 net_amt = 100
      net_trans_amt = 500 net_local_amt = 500 exch_rate_1 = 5 exch_rate = 1
      share_pct = 100 line_status = zif_reing_ca_c=>line_status-sim_proc ).
    mt_pc = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 1
        prctr = '0000000111' campana = '100' role_category = 'C' allocation = '0'
        ct_currency = 'USD' local_currency = 'BRL' share_abs = 60
        calc_amt = 60 bruto_amt = 75 tax_amt = 15 net_amt = 60 net_local_amt = 300
        bruto_trans_amt = 375 net_trans_amt = 300 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 2
        prctr = '0000000222' campana = '200' role_category = 'E' allocation = '1'
        ct_currency = 'USD' local_currency = 'BRL' share_abs = 40
        calc_amt = 40 bruto_amt = 50 tax_amt = 10 net_amt = 40 net_local_amt = 200
        bruto_trans_amt = 250 net_trans_amt = 200 ) ).
    mt_steps = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '04' seq = '01'
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'T1' output_amt = 25 output_trans_amt = 125 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '01'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 100 input_currency = 'USD'
        output_amt = 500 output_currency = 'BRL' rate_pct = 5 output_trans_amt = 500 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '02'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 500 input_currency = 'BRL'
        output_amt = 500 output_currency = 'BRL' rate_pct = 1 output_trans_amt = 500 ) ).
    mt_currencies = VALUE #( ( currency = 'USD' decimals = 2 ) ( currency = 'BRL' decimals = 2 ) ).

    refresh_trans( ).
  ENDMETHOD.
  METHOD refresh_trans.
    ms_projection = zcl_reing_ca_trans_amounts=>project_line( is_line = ms_line it_line_pc = mt_pc
      it_steps = mt_steps it_currencies = mt_currencies iv_eba_off = abap_false ).
    mo_cut->ms_line_a = ms_line.
    mo_cut->mt_line_pc = mt_pc.
    mo_cut->mt_step_a = mt_steps.
    mo_cut->mv_test_eba_off = abap_false.
    mo_cut->mv_internal_code = 'ABC'.
    mo_cut->mv_ar_recon_acct = '0000110000'.
    mo_cut->mv_ap_recon_acct = '0000210000'.
    mo_cut->mt_gl_account = VALUE #( ( gl_role = 'GEXP' saknr = '0000410000' ) ).
    mo_cut->mt_role_master = VALUE #( ( gl_role = 'GEXP' posting_context = 'GL' ) ).
    mo_poster = NEW #( ).
    mo_cut->mo_fi_poster = mo_poster.
    mo_cut->prepare_trans_context( is_projection = ms_projection it_currencies = mt_currencies ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_use_trans ).
  ENDMETHOD.
  METHOD assert_context_error.
    cl_abap_unit_assert=>assert_not_initial( mo_cut->mv_trans_error ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_true( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD trans_tax_rounds_to_zero.
given_trans( ).
    mo_cut->mv_trans_decimals = 0.
    mo_cut->mt_line_pc[ 1 ]-share_abs = 1. mo_cut->mt_line_pc[ 2 ]-share_abs = 99.
    mo_cut->ms_trans_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 1 ]-share_abs = 1.
    mo_cut->ms_trans_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 2 ]-share_abs = 99.
    mo_cut->mt_step_a[ step_num = '04' ]-output_trans_amt = 1.
    mo_cut->mt_role_master = VALUE #( ( gl_role = 'GEXP' posting_context = 'GL' tax_type = 'T1' role_category = 'C' ) ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'S' tax_type = 'T1' role_category = 'C' ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_items ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->post_calls exp = 0 ).
  ENDMETHOD.

  METHOD off_tax_rounding_preserved.
given_trans( ).
    mo_cut->mv_use_trans = abap_false. mo_cut->mv_trans_decimals = 0.
    mo_cut->mt_line_pc[ 1 ]-share_abs = 1. mo_cut->mt_line_pc[ 2 ]-share_abs = 99.
    mo_cut->mt_step_a[ step_num = '04' ]-output_amt = 1.
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'S' tax_type = 'T1' role_category = 'C' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( '0.01' ) ).
  ENDMETHOD.

  METHOD trans_tax_compensated_kept.
given_trans( ).
    mo_cut->ms_trans_projection-line_pc = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 1 bruto_trans_amt = 50 role_category = 'C' )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 2 bruto_trans_amt = -50 role_category = 'C' )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 3 bruto_trans_amt = 100 role_category = 'E' ) ).
    mo_cut->mt_line_pc = CORRESPONDING #( mo_cut->ms_trans_projection-line_pc ).
    mo_cut->mt_step_a[ step_num = '04' ]-output_trans_amt = 1.
    mo_cut->mt_role_master = VALUE #( ( gl_role = 'GEXP' posting_context = 'GL' tax_type = 'T1' role_category = 'C' ) ).
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'S' tax_type = 'T1' role_category = 'C' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( '0.50' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-amount exp = CONV zreing_ca_calc_amt( '-0.50' ) ).
  ENDMETHOD.

  METHOD trans_overflow_rejects.
given_trans( ).
    DATA(lv_amount) = mo_cut->round_trans_amount( CONV decfloat34( '999999999999999.99' ) ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_tax_last_exact_residue.
given_trans( ).
    mo_cut->mt_line_pc[ 1 ]-share_abs = 70.
    mo_cut->mt_line_pc[ 2 ]-share_abs = 30.
    mo_cut->mt_step_a[ step_num = '04' ]-output_trans_amt = '0.05'.
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'S' tax_type = 'T1' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( '0.04' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-amount exp = CONV zreing_ca_calc_amt( '0.01' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-prctr exp = '0000000222' ).
  ENDMETHOD.

  METHOD trans_same_exact_nominal.
given_trans( ).
    ms_line-trans_currency = 'USD'.
    ms_line-exch_rate_1 = 1. ms_line-exch_rate = 5.
    ms_line-calc_amt = '100.25'. ms_line-bruto_amt = '125.25'. ms_line-net_amt = '100.25'.
    ms_line-net_trans_amt = '100.25'. ms_line-net_local_amt = '501.25'.
    mt_pc[ 1 ]-calc_amt = '60.25'. mt_pc[ 1 ]-bruto_amt = '75.25'. mt_pc[ 1 ]-net_amt = '60.25'.
    mt_pc[ 1 ]-net_local_amt = '301.25'.
    mt_currencies[ currency = 'USD' ]-decimals = 0.
    LOOP AT mt_pc ASSIGNING FIELD-SYMBOL(<pc>).
      <pc>-bruto_trans_amt = <pc>-bruto_amt. <pc>-net_trans_amt = <pc>-net_amt.
    ENDLOOP.
    mt_steps[ step_num = '04' ]-output_trans_amt = 25.
    ASSIGN mt_steps[ step_num = '05' seq = '01' ] TO FIELD-SYMBOL(<primary>).
    <primary>-input_amt = '100.25'. <primary>-output_currency = 'USD'. <primary>-output_amt = '100.25'.
    <primary>-rate_pct = 1. <primary>-output_trans_amt = '100.25'.
    ASSIGN mt_steps[ step_num = '05' seq = '02' ] TO FIELD-SYMBOL(<local>).
    <local>-input_currency = 'USD'. <local>-input_amt = '100.25'. <local>-rate_pct = 5.
    <local>-output_amt = '501.25'. <local>-output_trans_amt = '100.25'.
    refresh_trans( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_line_amount( abap_true ) exp = CONV zreing_ca_calc_amt( '100.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_line_amount( abap_false ) exp = CONV zreing_ca_bruto_amt( '125.25' ) ).
  ENDMETHOD.

  METHOD trans_blank_prctr_preserved.
given_trans( ).
    CLEAR mt_pc[ 1 ]-prctr.
    refresh_trans( ).
    DATA(lt_post) = mo_cut->posting_pc_snapshot( ).
    cl_abap_unit_assert=>assert_initial( lt_post[ 1 ]-prctr ).
  ENDMETHOD.

  METHOD trans_local_metadata_degrades.
given_trans( ).
    ms_line-local_currency = 'EUR'.
    mt_steps[ step_num = '05' seq = '02' ]-output_currency = 'EUR'.
    refresh_trans( ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_use_trans ).
    cl_abap_unit_assert=>assert_false( mo_cut->ms_trans_projection-local_available ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_line_amount( abap_true ) exp = 500 ).
  ENDMETHOD.

  METHOD trans_ar_uses_calc.
given_trans( ).
    mo_cut->mt_role_master = VALUE #( ( gl_role = 'ARIC' posting_context = 'AR' ) ( gl_role = 'GEXP' posting_context = 'GL' ) ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'ARIC' posting_context = 'AR' posting_side = 'S' )
      ( role_code = 'GEXP' posting_context = 'GL' posting_side = 'H' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ role_code = 'ARIC' ]-amount exp = 500 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ prctr = '0000000111' ]-amount exp = -300 ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( lt_items ) exp = 0 ).
    DATA(ls_header) = mo_cut->build_header( ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-waers exp = 'BRL' ).
  ENDMETHOD.

  METHOD trans_ap_uses_bruto.
given_trans( ).
    mo_cut->mt_role_master = VALUE #( ( gl_role = 'APIC' posting_context = 'AP' ) ( gl_role = 'GEXP' posting_context = 'GL' ) ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'APIC' posting_context = 'AP' posting_side = 'H' )
      ( role_code = 'GEXP' posting_context = 'GL' posting_side = 'S' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ role_code = 'APIC' ]-amount exp = -625 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ prctr = '0000000111' ]-amount exp = 375 ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( lt_items ) exp = 0 ).
  ENDMETHOD.

  METHOD trans_preserves_native_ct.
given_trans( ).
    DATA(ls_before) = mo_cut->ms_line_a.
    DATA(lt_before) = mo_cut->mt_line_pc.
    DATA(lt_post) = mo_cut->posting_pc_snapshot( ).
    cl_abap_unit_assert=>assert_equals( act = lt_post[ 1 ]-calc_amt exp = 300 ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->ms_line_a exp = ls_before ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_line_pc exp = lt_before ).
    cl_abap_unit_assert=>assert_equals( act = lt_before[ 1 ]-calc_amt exp = 60 ).
  ENDMETHOD.

  METHOD trans_tax_nominal_once.
given_trans( ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'H' tax_type = 'T1' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ prctr = '0000000111' ]-amount exp = -75 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ prctr = '0000000222' ]-amount exp = -50 ).
  ENDMETHOD.

  METHOD trans_tax_category_target.
given_trans( ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'S' tax_type = 'T1' role_category = 'E' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-amount exp = 50 ).
  ENDMETHOD.

  METHOD trans_tax_fallback_residue.
given_trans( ).
    LOOP AT mo_cut->mt_line_pc ASSIGNING FIELD-SYMBOL(<pc>).
      CLEAR <pc>-share_abs.
    ENDLOOP.
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL'
      posting_side = 'S' tax_type = 'T1' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-amount exp = 75 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-amount exp = 50 ).
  ENDMETHOD.

  METHOD trans_missing_category_skips.
given_trans( ).
    mo_cut->mt_role_master = VALUE #( ( gl_role = 'GEXP' posting_context = 'GL' role_category = 'X' ) ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
  ENDMETHOD.

  METHOD trans_missing_cfg_rejects.
given_trans( ).
    CLEAR mo_cut->mt_role_master.
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_true( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->post_calls exp = 0 ).
  ENDMETHOD.

  METHOD trans_rounded_zero_skips.
given_trans( ).
    CLEAR: mo_cut->ms_trans_projection-calc_trans_amt, mo_cut->ms_trans_projection-bruto_trans_amt.
    LOOP AT mo_cut->ms_trans_projection-line_pc ASSIGNING FIELD-SYMBOL(<pc>).
      CLEAR: <pc>-calc_trans_amt, <pc>-bruto_trans_amt.
    ENDLOOP.
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
  ENDMETHOD.

  METHOD trans_compensated_runs.
given_trans( ).
    CLEAR: mo_cut->ms_trans_projection-calc_trans_amt, mo_cut->ms_trans_projection-bruto_trans_amt.
    mo_cut->ms_trans_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt = 50.
    mo_cut->ms_trans_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt = -50.
    mo_cut->ms_trans_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 1 ]-bruto_trans_amt = 50.
    mo_cut->ms_trans_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 2 ]-bruto_trans_amt = -50.
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(lt_items) = mo_cut->build_items( VALUE #( ( role_code = 'GEXP' posting_context = 'GL' posting_side = 'S' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->calculate_balance( lt_items ) exp = 0 ).
  ENDMETHOD.

  METHOD trans_old_caller_rejected.
given_trans( ).
    mo_cut->prepare_trans_context( it_currencies = mt_currencies ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_physical_lpc_rejects.
given_trans( ).
    mo_cut->mt_line_pc[ 1 ]-net_trans_amt = 299.
    mo_cut->prepare_trans_context( is_projection = ms_projection it_currencies = mt_currencies ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_physical_step_rejects.
given_trans( ).
    mo_cut->mt_step_a[ step_num = '04' ]-output_trans_amt = 124.
    mo_cut->prepare_trans_context( is_projection = ms_projection it_currencies = mt_currencies ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_calc_total_rejects.
given_trans( ).
    ms_projection-calc_trans_amt = 501.
    mo_cut->prepare_trans_context( is_projection = ms_projection it_currencies = mt_currencies ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_reset_keeps_legacy.
given_trans( ).
    mo_cut->ms_line_a-bukrs_prest = 'MUR'.
    mo_cut->prepare_trans_context( ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cl_abap_unit_assert=>assert_initial( mo_cut->ms_trans_projection ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_line_amount( abap_true ) exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_currency( ) exp = 'USD' ).
  ENDMETHOD.

  METHOD trans_off_ignores_bad_memory.
given_trans( ).
    mo_cut->mv_test_eba_off = abap_true.
    mo_cut->mt_step_a[ 2 ]-rate_pct = 999.
    mo_cut->prepare_trans_context( ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
  ENDMETHOD.

  METHOD trans_precision_zero_valid.
given_trans( ).
    mo_cut->mv_trans_decimals = 0.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->round_trans_amount( CONV decfloat34( '12.5' ) ) exp = 13 ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
  ENDMETHOD.

  METHOD trans_third_decimal_rejects.
given_trans( ).
    mo_cut->mv_trans_decimals = 3.
    DATA(lv_amount) = mo_cut->round_trans_amount( CONV decfloat34( '1.235' ) ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_residual_exact_rejects.
given_trans( ).
    DATA(lv_amount) = mo_cut->round_trans_amount( iv_amount = CONV decfloat34( '1.235' ) iv_exact = abap_true ).
    assert_context_error( ).
  ENDMETHOD.

  METHOD trans_storno_uses_original.
given_trans( ).
    mo_cut->mv_trans_error = 'Invalid current monetary memory'.
    mo_cut->mt_prior_docs = VALUE #( ( doc_type_code = 'AR' bukrs = 'OLD' belnr = '1000000001' gjahr = '2025' ) ).
    mo_cut->mv_doc_type_code = 'AR'.
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->original_bukrs exp = 'OLD' ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->original_belnr exp = '1000000001' ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->original_gjahr exp = '2025' ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->reverse_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->post_calls exp = 0 ).
  ENDMETHOD.

  METHOD trans_storno_without_fi.
given_trans( ).
    mo_cut->mv_trans_error = 'Contradictory current markers'.
    CLEAR mo_cut->mt_prior_docs.
    DATA(ls_result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->reverse_calls exp = 0 ).
  ENDMETHOD.

  METHOD contract_context.
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR'
        blart = 'SA' active = abap_true bukrs_rule = iv_rule kostl_rule = 'C' )
      is_trans_projection = ms_projection it_currencies = mt_currencies
      iv_contract_kostl = iv_kostl ).
  ENDMETHOD.
  METHOD contract_gl_assert.
    cb04_given( iv_off = iv_off iv_missing = 'C' ).
    contract_context( iv_kostl = 'CTCECO1234' ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_internal_code ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-items exp = cb04_poster->items ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 4 ).
    LOOP AT result-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-kostl exp = 'CTCECO1234' ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = result-total_amount
      exp = CONV zreing_cb_total_amount( COND i( WHEN iv_off = abap_true THEN 100 ELSE 500 ) ) ).
  ENDMETHOD.
  METHOD contract_off_gl.
    contract_gl_assert( abap_true ).
  ENDMETHOD.
  METHOD contract_on_gl.
    contract_gl_assert( abap_false ).
  ENDMETHOD.
  METHOD contract_assert_error.
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    DATA expected TYPE string.
    IF iv_message = '005'.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_message WITH 'AR' INTO expected.
    ELSE.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_message
        WITH ms_line-ct_id ms_line-matnr 'AR' INTO expected.
    ENDIF.
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD contract_bad_company.
    cb04_given( iv_off = abap_true ).
    contract_context( iv_rule = 'R' iv_kostl = 'CTCECO1234' ).
    contract_assert_error( '005' ).
    contract_context( iv_rule = 'O' iv_kostl = 'CTCECO1234' ).
    contract_assert_error( '005' ).
    contract_context( iv_rule = space iv_kostl = 'CTCECO1234' ).
    contract_assert_error( '005' ).
  ENDMETHOD.
  METHOD contract_missing_kostl.
    cb04_given( iv_off = abap_true ).
    contract_context( ).
    contract_assert_error( '006' ).
  ENDMETHOD.
  METHOD contract_context_reset.
    cb04_given( iv_off = abap_true ).
    contract_context( iv_kostl = 'CTCECO1234' ).
    DATA(first) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( first-has_error ).
    cb04_poster->calls = 0.
    " Omitted OPTIONAL must clear the previous material's cost center.
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( doc_type_code = 'AR' bukrs_rule = 'P' kostl_rule = 'C' ) ).
    contract_assert_error( '006' ).
    cb04_context( ).
    cb04_assert_ceco( iv_rule = 'P' iv_bukrs = 'EBA' iv_code = '111' ).
  ENDMETHOD.
  METHOD contract_bp_only.
    cb04_given( iv_off = abap_true iv_style = 'B' iv_missing = 'C' ).
    contract_context( ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    LOOP AT result-items INTO DATA(item).
      cl_abap_unit_assert=>assert_initial( item-kostl ).
    ENDLOOP.
  ENDMETHOD.
  METHOD contract_zero_gl.
    cb04_given( iv_off = abap_true iv_zero = abap_true iv_missing = 'C' ).
    contract_context( iv_rule = 'R' ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(items) = mo_cut->build_items( mo_cut->find_roles_for_step( ) ).
    cl_abap_unit_assert=>assert_initial( items ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD contract_prior_error.
    cb04_given( iv_off = abap_true ).
    contract_context( ).
    mo_cut->mv_trans_error = 'Earlier context failure'.
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = 'Earlier context failure' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD formula_default_unchanged.
    cb04_given( iv_off = abap_true ).
    cb04_assert_ceco( iv_rule = space iv_bukrs = 'EBA' iv_code = '111' ).
  ENDMETHOD.

  METHOD map_fixture.
    rt_map = VALUE #( ( campana_de = '459' matnr = ms_line-matnr campana_para = '777' )
      ( campana_de = '123' matnr = ms_line-matnr campana_para = '888' )
      ( campana_de = '459' matnr = 'OTHER' campana_para = '999' ) ).
  ENDMETHOD.
  METHOD map_context.
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR'
        blart = 'SA' active = abap_true bukrs_rule = iv_rule bukrs_override = 'OVR' kostl_rule = 'Z' )
      is_trans_projection = ms_projection it_currencies = mt_currencies it_campana_map = it_map ).
  ENDMETHOD.
  METHOD map_assert_gl.
    cb04_given( iv_off = iv_off ).
    map_context( it_map = map_fixture( ) ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-bukrs exp = 'OVR' ).
    cl_abap_unit_assert=>assert_equals( act = result-items exp = cb04_poster->items ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = result-total_amount
      exp = CONV zreing_ca_line_a-net_amt( COND i( WHEN iv_off = abap_true THEN 100 ELSE 500 ) ) ).
    LOOP AT result-items INTO DATA(item).
      IF item-campana = '459'.
        cl_abap_unit_assert=>assert_equals( act = item-kostl exp = '7771333999' ).
        cl_abap_unit_assert=>assert_equals( act = item-prctr exp = '0000000999' ).
        cl_abap_unit_assert=>assert_equals( act = item-allocation exp = '1' ).
      ELSE.
        cl_abap_unit_assert=>assert_equals( act = item-campana exp = '123' ).
        cl_abap_unit_assert=>assert_equals( act = item-kostl exp = '8883333123' ).
        cl_abap_unit_assert=>assert_equals( act = item-prctr exp = '0000000123' ).
        cl_abap_unit_assert=>assert_equals( act = item-allocation exp = '3' ).
      ENDIF.
      cl_abap_unit_assert=>assert_equals( act = item-waers
        exp = COND waers( WHEN iv_off = abap_true THEN 'USD' ELSE 'BRL' ) ).
    ENDLOOP.
  ENDMETHOD.
  METHOD map_off_gl.
    map_assert_gl( abap_true ).
  ENDMETHOD.
  METHOD map_on_gl.
    map_assert_gl( abap_false ).
  ENDMETHOD.
  METHOD map_assert_error.
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    DATA expected TYPE string.
    IF iv_message = '007'.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER iv_message WITH 'AR' INTO expected.
    ELSEIF iv_message = '002'.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER iv_message WITH 'AR' 'OVR' INTO expected.
    ELSE.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER iv_message WITH 'AR' '459' iv_material INTO expected.
    ENDIF.
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD map_bad_company.
    cb04_given( iv_off = abap_true ).
    map_context( iv_rule = 'P' it_map = map_fixture( ) ).
    map_assert_error( '007' ).
    map_context( iv_rule = 'R' it_map = map_fixture( ) ).
    map_assert_error( '007' ).
    map_context( iv_rule = space it_map = map_fixture( ) ).
    map_assert_error( '007' ).
  ENDMETHOD.
  METHOD map_missing_row.
    cb04_given( iv_off = abap_true ).
    map_context( it_map = VALUE #( ( campana_de = '459' matnr = 'OTHER' campana_para = '999' )
      ( campana_de = '123' matnr = ms_line-matnr campana_para = '888' ) ) ).
    map_assert_error( '008' ).
  ENDMETHOD.
  METHOD map_empty_destination.
    cb04_given( iv_off = abap_true ).
    DATA(maps) = map_fixture( ).
    CLEAR maps[ campana_de = '459' matnr = ms_line-matnr ]-campana_para.
    map_context( it_map = maps ).
    map_assert_error( '009' ).
  ENDMETHOD.
  METHOD map_missing_material.
    cb04_given( iv_off = abap_true ).
    CLEAR ms_line-matnr.
    " Even a deliberately inserted empty-material row must not satisfy the rule.
    map_context( it_map = VALUE #( ( campana_de = '459' campana_para = '777' ) ) ).
    map_assert_error( iv_message = '008' iv_material = space ).
  ENDMETHOD.
  METHOD map_exact_keys.
    cb04_given( iv_off = abap_true ).
    map_context( it_map = map_fixture( ) ).
    DATA(first) = mo_cut->determine_kostl( iv_campana = '459' iv_allocation = '1'
      iv_prctr = '0000000999' iv_kostl_rule = 'Z' iv_matnr = ms_line-matnr ).
    DATA(other) = mo_cut->determine_kostl( iv_campana = '459' iv_allocation = '1'
      iv_prctr = '0000000999' iv_kostl_rule = 'Z' iv_matnr = 'OTHER' ).
    DATA(second) = mo_cut->determine_kostl( iv_campana = '123' iv_allocation = '3'
      iv_prctr = '0000000123' iv_kostl_rule = 'Z' iv_matnr = ms_line-matnr ).
    cl_abap_unit_assert=>assert_equals( act = first exp = '7771333999' ).
    cl_abap_unit_assert=>assert_equals( act = other exp = '9991333999' ).
    cl_abap_unit_assert=>assert_equals( act = second exp = '8883333123' ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
  ENDMETHOD.
  METHOD map_context_reset.
    cb04_given( iv_off = abap_true ).
    map_context( it_map = map_fixture( ) ).
    DATA(good) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( good-has_error ).
    cb04_poster->calls = 0.
    map_context( ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mt_campana_map ).
    map_assert_error( '008' ).
    map_context( it_map = map_fixture( ) ).
    map_context( it_map = VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mt_campana_map ).
    map_assert_error( '008' ).
    cb04_context( iv_rule = 'O' ).
    cb04_assert_ceco( iv_rule = 'O' iv_bukrs = 'OVR' iv_code = '333' ).
  ENDMETHOD.
  METHOD map_bp_only.
    cb04_given( iv_off = abap_true iv_style = 'B' ).
    map_context( iv_rule = 'P' ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 1 ).
    LOOP AT result-items INTO DATA(item).
      cl_abap_unit_assert=>assert_initial( item-kostl ).
    ENDLOOP.
  ENDMETHOD.
  METHOD map_zero_gl.
    cb04_given( iv_off = abap_true iv_zero = abap_true ).
    map_context( iv_rule = 'R' ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(items) = mo_cut->build_items( mo_cut->find_roles_for_step( ) ).
    cl_abap_unit_assert=>assert_initial( items ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD map_internal_code_missing.
    cb04_given( iv_off = abap_true ).
    map_context( it_map = map_fixture( ) ).
    CLEAR mo_cut->mv_internal_code.
    map_assert_error( '002' ).
  ENDMETHOD.
  METHOD map_prior_error.
    cb04_given( iv_off = abap_true ).
    map_context( ).
    mo_cut->mv_trans_error = 'Earlier context failure'.
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = 'Earlier context failure' ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->calls exp = 0 ).
  ENDMETHOD.
  METHOD map_storno_original.
    given_trans( ).
    mo_cut->ms_flow_step-kostl_rule = 'Z'.
    mo_cut->ms_flow_step-bukrs_rule = 'P'.
    CLEAR mo_cut->mt_campana_map.
    mo_cut->mt_prior_docs = VALUE #( ( doc_type_code = 'AR' bukrs = 'OLD' belnr = '1000000001' gjahr = '2025' ) ).
    mo_cut->mv_doc_type_code = 'AR'.
    DATA(result) = mo_cut->zif_reing_contab~execute( 'S' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->original_bukrs exp = 'OLD' ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->original_belnr exp = '1000000001' ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->reverse_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD contract_pc_context.
    cb04_given( iv_off = abap_true ).
    DATA(before) = mo_cut->mt_line_pc.
    mo_cut->zif_reing_contab~set_context( is_line_a = ms_line it_line_pc = mt_pc
      it_step_a = mt_steps is_flow_step = VALUE #( doc_type_code = 'AR' )
      iv_contract_prctr = '250' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_contract_prctr exp = '0000000250' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mt_line_pc exp = before ).
    mo_cut->zif_reing_contab~set_context( is_line_a = ms_line it_line_pc = mt_pc
      it_step_a = mt_steps is_flow_step = VALUE #( doc_type_code = 'AR' ) ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_contract_prctr ).
  ENDMETHOD.

  METHOD text_et_gl_positions.
    cb04_given( iv_off = abap_true ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ role_code = 'GS' prctr = '0000000999' ]-item_text
      exp = 'GS4590000000999 | EBA X MUR' ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ role_code = 'GH' prctr = '0000000123' ]-item_text
      exp = 'GH1230000000123 | EBA X MUR' ).
    cl_abap_unit_assert=>assert_equals( act = result-items exp = cb04_poster->items ).
    cl_abap_unit_assert=>assert_initial( mo_cut->calculate_balance( result-items ) ).
  ENDMETHOD.
  METHOD text_et_bp_positions.
    cb04_given( iv_off = abap_true iv_style = 'B' ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ posting_context = 'AR' ]-item_text
      exp = 'RA | EBA X MUR' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ posting_context = 'AP' ]-item_text
      exp = 'PA | EBA X MUR' ).
  ENDMETHOD.
  METHOD text_et_nominal_payload.
    cb04_given( ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    DATA decoded TYPE ty_cb02_payload.
    /ui2/cl_json=>deserialize( EXPORTING json = result-payload CHANGING data = decoded ).
    cl_abap_unit_assert=>assert_equals( act = decoded-items exp = cb04_poster->items ).
    cl_abap_unit_assert=>assert_equals(
      act = decoded-items[ role_code = 'GS' prctr = '0000000999' ]-item_text
      exp = 'GS4590000000999 | EBA X MUR' ).
    cl_abap_unit_assert=>assert_equals( act = result-waers exp = 'BRL' ).
  ENDMETHOD.
  METHOD text_et_override_company.
    cb04_given( iv_off = abap_true ).
    cb04_context( 'O' ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-bukrs exp = 'OVR' ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ role_code = 'GS' prctr = '0000000999' ]-item_text
      exp = 'GS4590000000999 | EBA X MUR' ).
  ENDMETHOD.
  METHOD text_et_blank_dimensions.
    mo_cut->ms_line_a-bukrs_prest = 'MUR'.
    mo_cut->ms_line_a-bukrs_recv = 'MAM'.
    DATA(item) = VALUE zif_reing_contab_types=>ty_doc_item(
      role_code = 'ARIC' zuonr = 'REINT LICENCIAS' item_text = 'STALE' ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->build_item_text( item )
      exp = 'ARIC | MUR X MAM' ).
  ENDMETHOD.
  METHOD text_et_width_and_refresh.
    mo_cut->ms_line_a-bukrs_prest = 'ABCD'.
    mo_cut->ms_line_a-bukrs_recv = 'EFGH'.
    DATA(item) = VALUE zif_reing_contab_types=>ty_doc_item(
      role_code = 'ABCDEFGHIJ' campana = '123' prctr = '1234567890' ).
    DATA(first) = mo_cut->build_item_text( item ).
    cl_abap_unit_assert=>assert_equals( act = first exp = 'ABCDEFGHIJ1231234567890 | ABCD X EFGH' ).
    cl_abap_unit_assert=>assert_equals( act = strlen( first ) exp = 37 ).
    CLEAR: mo_cut->ms_line_a-bukrs_recv, item-campana, item-prctr.
    item-role_code = 'APIC'.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->build_item_text( item )
      exp = 'APIC | ABCD X ' ).
  ENDMETHOD.
  METHOD text_et_int_inherits.
    cb04_given( iv_off = abap_true ).
    ms_line-bukrs_recv = ms_line-bukrs_prest.
    mo_cut = NEW zcl_reing_contab_doc_int( ).
    mo_cut->mv_test_eba_off = abap_true.
    mo_cut->zif_reing_contab~set_fi_poster( cb04_poster ).
    cb04_context( ).
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
    DATA(result) = mo_cut->zif_reing_contab~execute( 'C' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals(
      act = result-items[ role_code = 'GS' prctr = '0000000999' ]-item_text
      exp = 'GS4590000000999 | EBA X EBA' ).
  ENDMETHOD.
  METHOD bypass_explicit_off_wins.
    cb04_given( ).
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR'
        blart = 'SA' active = abap_true bukrs_rule = 'P' )
      is_trans_projection = ms_projection it_currencies = mt_currencies iv_eba_off = abap_true ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_currency( ) exp = 'USD' ).
  ENDMETHOD.
  METHOD bypass_explicit_on_wins.
    cb04_given( iv_off = abap_true ).
    mo_cut->zif_reing_contab~set_context(
      is_line_a = ms_line it_line_pc = mt_pc it_step_a = mt_steps
      is_flow_step = VALUE #( op_type = ms_line-op_type seq = 1 doc_type_code = 'AR'
        blart = 'SA' active = abap_true bukrs_rule = 'P' )
      is_trans_projection = ms_projection it_currencies = mt_currencies iv_eba_off = abap_false ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_use_trans ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    DATA(result) = mo_cut->zif_reing_contab~execute( zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = cb04_poster->header-waers exp = 'BRL' ).
  ENDMETHOD.
  METHOD bypass_omitted_refreshes.
    cb04_given( iv_off = abap_true ).
    mo_cut->prepare_trans_context( is_projection = ms_projection it_currencies = mt_currencies
                                 iv_eba_off = abap_false ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_use_trans ).
    cb04_context( ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_use_trans ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_trans_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->posting_currency( ) exp = 'USD' ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_cb01_recl_probe DEFINITION INHERITING FROM zcl_reing_contab_doc_recl.
  PUBLIC SECTION.
    METHODS build_previous
      IMPORTING it_docs TYPE zif_reing_contab_types=>ty_step_result_t
                it_roles TYPE zif_reing_contab_types=>ty_role_resolved_t
      RETURNING VALUE(rt_items) TYPE zif_reing_contab_types=>ty_doc_item_t.
ENDCLASS.
CLASS lcl_cb01_recl_probe IMPLEMENTATION.
  METHOD build_previous.
    ms_line_a = VALUE #( op_type = 'F' ct_currency = 'USD' trans_currency = 'BRL' exch_rate_1 = 5 ).
    ms_flow_step-seq = '020'.
    mv_use_trans = abap_true.
    ms_trans_projection-calc_trans_amt = 999.
    mv_internal_code = 'ABC'.
    mt_prior_docs = it_docs.
    mt_gl_account = VALUE #( ( gl_role = 'RWPX' saknr = '0000410000' ) ( gl_role = 'GEXP' saknr = '0000510000' ) ).
    rt_items = build_items( it_roles ).
  ENDMETHOD.
ENDCLASS.
CLASS ltcl_cb01_recl DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.
    METHODS previous_nominal_copied FOR TESTING RAISING cx_static_check.
ENDCLASS.
CLASS ltcl_cb01_recl IMPLEMENTATION.
  METHOD class_setup.
    sql_env = cl_osql_test_environment=>create( VALUE #( ( 'ZREING_DOCFLOW_C' ) ( 'ZREING_GL_ROLES' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    sql_env->destroy( ).
  ENDMETHOD.
  METHOD teardown.
    sql_env->clear_doubles( ).
  ENDMETHOD.
  METHOD previous_nominal_copied.
    DATA lt_flow TYPE zif_reing_contab_types=>ty_flow_t.
    lt_flow = VALUE #( ( op_type = 'F' seq = '010' doc_type_code = 'AP' )
                      ( op_type = 'F' seq = '020' doc_type_code = 'ZZZ' ) ).
    sql_env->insert_test_data( lt_flow ).
    DATA lt_master TYPE STANDARD TABLE OF zreing_gl_roles WITH EMPTY KEY.
    lt_master = VALUE #( ( gl_role = 'RWHP' reclassify = abap_true role_reclas = 'RWPX'
      role_category = 'E' tax_type = 'T1' posting_context = 'GL' ) ).
    sql_env->insert_test_data( lt_master ).
    DATA(lo_cut) = NEW lcl_cb01_recl_probe( ).
    DATA(lt_items) = lo_cut->build_previous( it_docs = VALUE #( ( doc_type_code = 'AP'
      items = VALUE #( ( role_code = 'RWHP' amount = '-75.25' waers = 'BRL'
        campana = '100' allocation = '0' prctr = '0000000111' zuonr = 'TRANS-COPY' ) ) ) )
      it_roles = VALUE #( ( role_code = 'RWPX' posting_context = 'GL' role_category = 'E' tax_type = 'T1' posting_side = 'S' )
                         ( role_code = 'GEXP' posting_context = 'GL' role_category = 'E' posting_side = 'H' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( '75.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 2 ]-amount exp = CONV zreing_ca_calc_amt( '-75.25' ) ).
    LOOP AT lt_items INTO DATA(ls_item).
      cl_abap_unit_assert=>assert_equals( act = ls_item-waers exp = 'BRL' ).
      cl_abap_unit_assert=>assert_equals( act = ls_item-kostl exp = '1000ABC111' ).
      cl_abap_unit_assert=>assert_equals( act = ls_item-zuonr exp = 'TRANS-COPY' ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
