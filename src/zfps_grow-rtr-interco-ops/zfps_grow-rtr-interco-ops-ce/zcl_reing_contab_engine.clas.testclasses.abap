" V001 (CC) - GAP-001 (Delta v2): pure FI classification, no BAPI.
CLASS ltcl_gap001_reversal DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mt_lines TYPE zif_reing_ca_types=>ty_line_t.
    DATA mt_docs TYPE zcl_reing_contab_engine=>tt_reversal_docs.
    DATA mt_journal TYPE zcl_reing_contab_engine=>tt_journal.
    METHODS setup.
    METHODS no_fi_is_not_reversed FOR TESTING.
    METHODS missing_fi_fails_safely FOR TESTING.
    METHODS external_reverse_keeps_header FOR TESTING.
    METHODS partial_reverse_by_own_bukrs FOR TESTING.
    METHODS wrong_fiscal_year_fails FOR TESTING.
    METHODS planned_is_not_reversed FOR TESTING.
    METHODS already_rv_is_idempotent FOR TESTING.
    METHODS simulated_is_not_fi FOR TESTING.
    METHODS false_rv_is_error FOR TESTING.
    METHODS missing_reverse_key_is_error FOR TESTING.
    METHODS other_run_is_not_consumed FOR TESTING.
ENDCLASS.
CLASS ltcl_gap001_reversal IMPLEMENTATION.
  METHOD setup.
    mt_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_num = '0000001' line_status = 'CONT' ) ).
    mt_docs = VALUE #( ( calc_run_id = 'RUN-202602' line_num = '0000001' doc_type_code = 'AP'
      bukrs = 'DAB' belnr = '1234567890' gjahr = '2026' status = 'OK'
      waers = 'BRL' total_amount = '123.45' num_items = 2 payload = 'original-payload'
      created_by = 'ORIGINAL' created_at = '20260228120000' ) ).
    mt_journal = VALUE #( ( companycode = 'DAB' accountingdocument = '1234567890'
      fiscalyear = '2026' isreversed = abap_false ) ).
  ENDMETHOD.
  METHOD no_fi_is_not_reversed.
    CLEAR mt_docs.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'N' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.
  METHOD missing_fi_fails_safely.
    CLEAR mt_journal.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'E' ).
    cl_abap_unit_assert=>assert_not_initial( lt_check[ 1 ]-message ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.
  METHOD external_reverse_keeps_header.
    mt_journal[ 1 ]-isreversed = abap_true.
    mt_journal[ 1 ]-reversedocument = '9876543210'.
    mt_journal[ 1 ]-reversedocumentfiscalyear = '2027'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'R' ).
    DATA(ls_expected) = mt_docs[ 1 ].
    ls_expected-status = 'RV'.
    ls_expected-reverse_belnr = '9876543210'.
    cl_abap_unit_assert=>assert_equals( act = lt_sync[ 1 ] exp = ls_expected ).
  ENDMETHOD.
  METHOD partial_reverse_by_own_bukrs.
    APPEND VALUE #( calc_run_id = 'RUN-202602' line_num = '0000001' doc_type_code = 'ZZZ'
      bukrs = 'ZZZ' belnr = '1234567890' gjahr = '2026' status = 'OK' ) TO mt_docs.
    APPEND VALUE #( companycode = 'ZZZ' accountingdocument = '1234567890'
      fiscalyear = '2026' isreversed = abap_false ) TO mt_journal.
    mt_journal[ 1 ]-isreversed = abap_true.
    mt_journal[ 1 ]-reversedocument = '9876543210'.
    mt_journal[ 1 ]-reversedocumentfiscalyear = '2026'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'P' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_sync ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_sync[ 1 ]-bukrs exp = 'DAB' ).
  ENDMETHOD.
  METHOD wrong_fiscal_year_fails.
    mt_journal[ 1 ]-fiscalyear = '2027'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'E' ).
  ENDMETHOD.
  METHOD planned_is_not_reversed.
    mt_journal[ 1 ]-reversedocument = '9876543210'.
    mt_journal[ 1 ]-reversedocumentfiscalyear = '2026'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'P' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.
  METHOD already_rv_is_idempotent.
    mt_docs[ 1 ]-status = 'RV'.
    mt_docs[ 1 ]-reverse_belnr = '9876543210'.
    mt_journal[ 1 ]-isreversed = abap_true.
    mt_journal[ 1 ]-reversedocument = '9876543210'.
    mt_journal[ 1 ]-reversedocumentfiscalyear = '2026'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'R' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.

  METHOD simulated_is_not_fi.
    mt_docs[ 1 ]-status = 'SI'.
    mt_docs[ 1 ]-simulated = abap_true.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'N' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.


  METHOD false_rv_is_error.
    mt_docs[ 1 ]-status = 'RV'.
    mt_docs[ 1 ]-reverse_belnr = '9876543210'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'E' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.


  METHOD missing_reverse_key_is_error.
    mt_journal[ 1 ]-isreversed = abap_true.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'E' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.


  METHOD other_run_is_not_consumed.
    mt_docs[ 1 ]-calc_run_id = 'RUN-202603'.
    zcl_reing_contab_engine=>classify_reversal(
      EXPORTING it_lines = mt_lines it_docs = mt_docs it_journal = mt_journal
      IMPORTING et_check = DATA(lt_check) et_sync = DATA(lt_sync) ).
    cl_abap_unit_assert=>assert_equals( act = lt_check[ 1 ]-state exp = 'N' ).
    cl_abap_unit_assert=>assert_initial( lt_sync ).
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - CB-01: canonical producer and physical snapshot contract.
CLASS ltcl_cb01_engine DEFINITION DEFERRED.
CLASS zcl_reing_contab_engine DEFINITION LOCAL FRIENDS ltcl_cb01_engine.
CLASS ltcl_cb01_engine DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_reing_contab_engine.
    DATA ms_line TYPE zreing_ca_line_a.
    DATA mt_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_steps TYPE zif_reing_ca_types=>ty_step_t.
    DATA mt_currencies TYPE zif_reing_ca_types=>tt_currency_precision.
    METHODS setup.
    METHODS teardown.
    METHODS project RETURNING VALUE(rs_projection) TYPE zif_reing_ca_types=>ty_trans_projection RAISING zcx_reing_contab.
    METHODS expect_error.
    METHODS compensated_primary_kept FOR TESTING RAISING cx_static_check.
    METHODS physical_projection FOR TESTING RAISING cx_static_check.
    METHODS mismatched_lpc_rejected FOR TESTING RAISING cx_static_check.
    METHODS mismatched_step_rejected FOR TESTING RAISING cx_static_check.
    METHODS missing_primary_rejected FOR TESTING RAISING cx_static_check.
    METHODS duplicate_pc_rejected FOR TESTING RAISING cx_static_check.
    METHODS historical_uses_ct FOR TESTING RAISING cx_static_check.
    METHODS off_ignores_stale FOR TESTING RAISING cx_static_check.
    METHODS storno_ignores_stale FOR TESTING RAISING cx_static_check.
    METHODS local_absence_keeps_primary FOR TESTING RAISING cx_static_check.
    METHODS empty_warm_clears_precision FOR TESTING RAISING cx_static_check.
    METHODS storno_zero_skips_fi FOR TESTING RAISING cx_static_check.
ENDCLASS.
CLASS ltcl_cb01_engine IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW #( ).
    TEST-INJECTION cb01_projection_guard.
      lv_eba_off = zcl_reing_contab_engine=>gv_test_eba_off.
    END-TEST-INJECTION.
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    zcl_reing_contab_engine=>gv_test_eba_off = abap_false.

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
    zcl_reing_contab_engine=>gt_trans_currencies = mt_currencies.
    zcl_reing_contab_engine=>gt_flow_all = VALUE #( ( op_type = 'F' seq = '010' doc_type_code = 'AR' active = abap_true ) ).
    zcl_reing_contab_engine=>gt_doctype_all = VALUE #( ( doc_type_code = 'AR' processing_class = 'ZCL_REING_CONTAB_DOC' ) ).
    zcl_reing_contab_engine=>gt_optype_all = VALUE #( ( op_type = 'F' ) ).
  ENDMETHOD.
  METHOD teardown.
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    zcl_reing_contab_engine=>gv_test_eba_off = abap_false.
  ENDMETHOD.
  METHOD project.
    rs_projection = mo_cut->project_trans_context( is_line = ms_line it_pcs = mt_pc
      it_steps = mt_steps iv_mode = zif_reing_ca_c=>contab_mode-check ).
  ENDMETHOD.
  METHOD expect_error.
    TRY.
        DATA(ls_projection) = project( ).
        cl_abap_unit_assert=>fail( 'Invalid physical memory must be rejected before processing' ).
      CATCH zcx_reing_contab INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->mv_message ).
    ENDTRY.
  ENDMETHOD.
  METHOD compensated_primary_kept.
ms_line-is_delta = abap_true.
    CLEAR: ms_line-calc_amt, ms_line-bruto_amt, ms_line-tax_amt, ms_line-net_amt,
      ms_line-net_trans_amt, ms_line-net_local_amt, ms_line-share_pct.
    LOOP AT mt_pc ASSIGNING FIELD-SYMBOL(<pc>).
      DATA(lv_ct) = COND zreing_ca_calc_amt( WHEN <pc>-pc_seq = 1 THEN 10 ELSE -10 ).
      <pc>-calc_amt = lv_ct. <pc>-bruto_amt = lv_ct. <pc>-net_amt = lv_ct.
      CLEAR: <pc>-tax_amt, <pc>-share_abs.
      <pc>-bruto_trans_amt = lv_ct * 5. <pc>-net_trans_amt = lv_ct * 5.
      <pc>-net_local_amt = lv_ct * 5.
    ENDLOOP.
    LOOP AT mt_steps ASSIGNING FIELD-SYMBOL(<step>).
      CLEAR: <step>-input_amt, <step>-output_amt, <step>-output_trans_amt.
    ENDLOOP.
    DATA(ls_projection) = project( ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-calc_trans_amt exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt exp = 50 ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-line_pc[ calc_run_id = ms_line-calc_run_id line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt exp = -50 ).
  ENDMETHOD.

  METHOD physical_projection.
DATA(ls_projection) = project( ).
    cl_abap_unit_assert=>assert_true( ls_projection-use_trans ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-calc_trans_amt exp = 500 ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-bruto_trans_amt exp = 625 ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-line exp = ms_line ).
  ENDMETHOD.

  METHOD mismatched_lpc_rejected.
mt_pc[ 1 ]-bruto_trans_amt = 374.
    expect_error( ).
  ENDMETHOD.

  METHOD mismatched_step_rejected.
mt_steps[ step_num = '04' ]-output_trans_amt = 124.
    expect_error( ).
  ENDMETHOD.

  METHOD missing_primary_rejected.
DELETE mt_steps WHERE step_num = '05' AND seq = '01'.
    expect_error( ).
  ENDMETHOD.

  METHOD duplicate_pc_rejected.
APPEND mt_pc[ 1 ] TO mt_pc.
    expect_error( ).
  ENDMETHOD.

  METHOD historical_uses_ct.
DELETE mt_steps WHERE step_num = '05' AND seq = '02'.
    DATA(ls_projection) = project( ).
    cl_abap_unit_assert=>assert_false( ls_projection-use_trans ).
  ENDMETHOD.

  METHOD off_ignores_stale.
zcl_reing_contab_engine=>gv_test_eba_off = abap_true.
    mt_steps[ 2 ]-rate_pct = 999.
    DATA(ls_projection) = project( ).
    cl_abap_unit_assert=>assert_false( ls_projection-use_trans ).
  ENDMETHOD.

  METHOD storno_ignores_stale.
mt_steps[ 2 ]-rate_pct = 999.
    DATA(ls_projection) = mo_cut->project_trans_context( is_line = ms_line it_pcs = mt_pc
      it_steps = mt_steps iv_mode = zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_false( ls_projection-use_trans ).
  ENDMETHOD.

  METHOD local_absence_keeps_primary.
CLEAR: ms_line-net_local_amt, ms_line-exch_rate.
    ASSIGN mt_steps[ step_num = '05' seq = '02' ] TO FIELD-SYMBOL(<local>).
    CLEAR: <local>-output_amt, <local>-output_currency, <local>-rate_pct.
    DATA(ls_projection) = project( ).
    cl_abap_unit_assert=>assert_true( ls_projection-use_trans ).
    cl_abap_unit_assert=>assert_false( ls_projection-local_available ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-calc_trans_amt exp = 500 ).
  ENDMETHOD.

  METHOD empty_warm_clears_precision.
zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_trans_currencies ).
  ENDMETHOD.

  METHOD storno_zero_skips_fi.
ms_line-line_status = zif_reing_ca_c=>line_status-anul_proc.
    CLEAR ms_line-bruto_amt.
    CLEAR mt_pc.
    mt_steps[ 2 ]-rate_pct = 999.
    DATA(ls_result) = mo_cut->process_line( is_line_a = ms_line it_line_pc = mt_pc
      it_step_a = mt_steps iv_mode = zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_false( ls_result-has_error ).
    cl_abap_unit_assert=>assert_initial( ls_result-documents ).
  ENDMETHOD.

ENDCLASS.
" V001 (CC) - CB-05 (Delta v2): capture both FI boundaries without real FI.
CLASS lcl_cb05_poster DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_reing_contab_fi_poster.
    TYPES: BEGIN OF ty_call,
             header TYPE zif_reing_contab_types=>ty_header,
             items TYPE zif_reing_contab_types=>ty_doc_item_t,
             mode TYPE zreing_ca_contab_mode,
           END OF ty_call,
           tt_call TYPE STANDARD TABLE OF ty_call WITH EMPTY KEY,
           BEGIN OF ty_reverse,
             belnr TYPE belnr_d,
             bukrs TYPE bukrs,
             gjahr TYPE gjahr,
             reason TYPE stgrd,
             pstng_date TYPE budat,
           END OF ty_reverse,
           tt_reverse TYPE STANDARD TABLE OF ty_reverse WITH EMPTY KEY.
    DATA calls TYPE tt_call.
    DATA reverses TYPE tt_reverse.
    DATA fail_at TYPE i.
ENDCLASS.
CLASS lcl_cb05_poster IMPLEMENTATION.
  METHOD zif_reing_contab_fi_poster~post_document.
    APPEND VALUE #( header = is_header items = it_items mode = iv_mode ) TO calls.
    IF fail_at > 0 AND lines( calls ) = fail_at.
      rs_result = VALUE #( has_error = abap_true error_msg = 'CB05 synthetic AP failure' ).
      RETURN.
    ENDIF.
    rs_result = VALUE #( gjahr = '2026' ).
    IF iv_mode = 'P'.
      rs_result-belnr = '1000000001'.
    ENDIF.
  ENDMETHOD.
  METHOD zif_reing_contab_fi_poster~reverse_document.
    APPEND VALUE #( belnr = iv_belnr bukrs = iv_bukrs gjahr = iv_gjahr
      reason = iv_reason pstng_date = iv_pstng_date ) TO reverses.
    rs_result = VALUE #( belnr = '9000000001' gjahr = '2026' ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_cb05_engine DEFINITION DEFERRED.
CLASS zcl_reing_contab_engine DEFINITION LOCAL FRIENDS ltcl_cb05_engine.
CLASS ltcl_cb05_engine DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CONSTANTS c_ct TYPE sysuuid_x16 VALUE '00000000000000000000000000000001'.
    CONSTANTS c_mat TYPE sysuuid_x16 VALUE '00000000000000000000000000000002'.
    CONSTANTS c_op TYPE sysuuid_x16 VALUE '00000000000000000000000000000003'.
    CONSTANTS c_cm TYPE sysuuid_x16 VALUE '00000000000000000000000000000005'.
    CONSTANTS c_ct_b TYPE sysuuid_x16 VALUE '00000000000000000000000000000011'.
    CONSTANTS c_mat_b TYPE sysuuid_x16 VALUE '00000000000000000000000000000012'.
    CONSTANTS c_op_b TYPE sysuuid_x16 VALUE '00000000000000000000000000000013'.
    CONSTANTS c_cm_b TYPE sysuuid_x16 VALUE '00000000000000000000000000000015'.
    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.
    DATA cut TYPE REF TO zcl_reing_contab_engine.
    DATA poster TYPE REF TO lcl_cb05_poster.
    DATA line TYPE zreing_ca_line_a.
    DATA pcs TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA steps TYPE zif_reing_ca_types=>ty_step_t.
    DATA currencies TYPE zif_reing_ca_types=>tt_currency_precision.
    TYPES tt_docs TYPE STANDARD TABLE OF zreing_cb_doc_a WITH EMPTY KEY.
    TYPES tt_items TYPE STANDARD TABLE OF zreing_cb_item_a WITH EMPTY KEY.
    TYPES tt_traces TYPE STANDARD TABLE OF zreing_cb_trc_a WITH EMPTY KEY.
    DATA db_docs TYPE tt_docs.
    DATA db_items TYPE tt_items.
    DATA db_traces TYPE tt_traces.
    DATA saved_flow LIKE zcl_reing_contab_engine=>gt_flow_all.
    DATA saved_doctype LIKE zcl_reing_contab_engine=>gt_doctype_all.
    DATA saved_optype LIKE zcl_reing_contab_engine=>gt_optype_all.
    DATA saved_orig LIKE zcl_reing_contab_engine=>gt_orig_docs_all.
    DATA saved_docs LIKE zcl_reing_contab_engine=>gt_doc_pending.
    DATA saved_items LIKE zcl_reing_contab_engine=>gt_item_pending.
    DATA saved_traces LIKE zcl_reing_contab_engine=>gt_trace_pending.
    DATA saved_precision LIKE zcl_reing_contab_engine=>gt_trans_currencies.
    DATA saved_kostl LIKE zcl_reing_contab_engine=>gt_contract_kostl.
    DATA saved_map LIKE zcl_reing_contab_engine=>gt_campana_map.
    DATA saved_guard TYPE abap_bool.
    DATA saved_eba_off TYPE abap_bool.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS given
      IMPORTING iv_flow TYPE c DEFAULT 'A' iv_tax TYPE zreing_ca_tax_amt DEFAULT 25
        iv_zero TYPE abap_bool DEFAULT abap_false iv_prest TYPE bukrs DEFAULT 'EBA'
        iv_recv TYPE bukrs DEFAULT 'MUR' iv_missing TYPE abap_bool DEFAULT abap_false
      RAISING cx_static_check.
    METHODS warm.
    METHODS snapshot_db.
    METHODS assert_db_unchanged.
    METHODS process IMPORTING iv_mode TYPE zreing_ca_contab_mode DEFAULT 'C'
      RETURNING VALUE(rs_result) TYPE zif_reing_contab_types=>ty_process_result
      RAISING zcx_reing_contab.
    METHODS expected_items
      IMPORTING iv_type TYPE zreing_doc_type_code iv_scale TYPE i DEFAULT 1
        iv_tax TYPE abap_bool DEFAULT abap_true iv_code TYPE c DEFAULT space
      RETURNING VALUE(rt_items) TYPE zif_reing_contab_types=>ty_doc_item_t.
    METHODS assert_document
      IMPORTING is_result TYPE zif_reing_contab_types=>ty_process_result
        iv_index TYPE i iv_type TYPE zreing_doc_type_code iv_total TYPE zreing_cb_total_amount
        iv_scale TYPE i DEFAULT 1 iv_tax TYPE abap_bool DEFAULT abap_true
        iv_code TYPE c DEFAULT space iv_mode TYPE zreing_ca_contab_mode DEFAULT 'C'
        iv_call TYPE i DEFAULT 0.
    METHODS assert_trace
      IMPORTING iv_index TYPE i iv_type TYPE zreing_trace_type
        iv_doc TYPE zreing_doc_type_code iv_mode TYPE zreing_ca_contab_mode DEFAULT 'C'
        iv_belnr TYPE belnr_d DEFAULT space iv_message TYPE zreing_message_text DEFAULT space.
    METHODS assert_counts IMPORTING iv_calls TYPE i iv_docs TYPE i iv_items TYPE i iv_traces TYPE i.
    METHODS given_original IMPORTING iv_partial TYPE abap_bool DEFAULT abap_false.
    METHODS assert_original.
    METHODS flow_off_ar_ap FOR TESTING RAISING cx_static_check.
    METHODS flow_off_zzz FOR TESTING RAISING cx_static_check.
    METHODS flow_off_zzz_zero_skips FOR TESTING RAISING cx_static_check.
    METHODS flow_noneba_legacy FOR TESTING RAISING cx_static_check.
    METHODS flow_intra_only_int FOR TESTING RAISING cx_static_check.
    METHODS flow_intra_zero_skips FOR TESTING RAISING cx_static_check.
    METHODS flow_dup_type_reject FOR TESTING RAISING cx_static_check.
    METHODS flow_post_error_keeps_prior FOR TESTING RAISING cx_static_check.
    METHODS flow_storno_original_exact FOR TESTING RAISING cx_static_check.
    METHODS flow_storno_partial FOR TESTING RAISING cx_static_check.
    METHODS flow_run_buffers_isolated FOR TESTING RAISING cx_static_check.
    METHODS flow_ceco_error_stops FOR TESTING RAISING cx_static_check.
    " V001 (CC) - bug107 CONTAB: warmed SQL doubles, production Engine, fake FI.
    METHODS contract_flow IMPORTING iv_doc TYPE zreing_doc_type_code DEFAULT 'AR'
      iv_rule TYPE zreing_bukrs_rule DEFAULT 'P' iv_kostl TYPE kostl DEFAULT 'CTCECO1234'.
    METHODS contract_flow_success FOR TESTING RAISING cx_static_check.
    METHODS contract_flow_missing FOR TESTING RAISING cx_static_check.
    METHODS contract_late_error FOR TESTING RAISING cx_static_check.
    METHODS contract_cache_exact FOR TESTING RAISING cx_static_check.
    METHODS contract_cache_reset FOR TESTING RAISING cx_static_check.
    METHODS contract_intra_int FOR TESTING RAISING cx_static_check.
    METHODS contract_recl_own_rule FOR TESTING RAISING cx_static_check.
    METHODS contract_storno_original FOR TESTING RAISING cx_static_check.

    " V001 (CC) - #121: warmed mappings and real processing with fake FI.
    METHODS map_flow IMPORTING iv_doc TYPE zreing_doc_type_code DEFAULT 'ZZZ'
      iv_prctr TYPE prctr DEFAULT '999'
      iv_rule TYPE zreing_bukrs_rule DEFAULT 'O'
      it_map TYPE zif_reing_contab_types=>tt_campana_map OPTIONAL.
    METHODS map_flow_success FOR TESTING RAISING cx_static_check.
    METHODS map_late_error FOR TESTING RAISING cx_static_check.
    METHODS map_empty_target FOR TESTING RAISING cx_static_check.
    METHODS map_bad_company FOR TESTING RAISING cx_static_check.
    METHODS map_cache_exact FOR TESTING RAISING cx_static_check.
    METHODS map_cache_reset FOR TESTING RAISING cx_static_check.
    METHODS map_scope_materials FOR TESTING RAISING cx_static_check.
    METHODS map_intra_int FOR TESTING RAISING cx_static_check.
    METHODS map_zero_recl_skips FOR TESTING RAISING cx_static_check.
    METHODS map_storno_original FOR TESTING RAISING cx_static_check.
    METHODS map_contract_pc_cache FOR TESTING RAISING cx_static_check.
    METHODS map_contract_pc_missing FOR TESTING RAISING cx_static_check.
    METHODS map_contract_pc_identity FOR TESTING RAISING cx_static_check.
    METHODS map_contract_pc_refresh FOR TESTING RAISING cx_static_check.
    METHODS map_contract_pc_alt FOR TESTING RAISING cx_static_check.
    METHODS bypass_on_document_flow FOR TESTING RAISING cx_static_check.
    METHODS bypass_action_snapshot FOR TESTING RAISING cx_static_check.
    METHODS bypass_empty_scope_resets FOR TESTING RAISING cx_static_check.
ENDCLASS.
CLASS ltcl_cb05_engine IMPLEMENTATION.
  METHOD class_setup.
    sql_env = cl_osql_test_environment=>create( VALUE #(
      ( 'ZREING_CA_RUN_A' ) ( 'ZREING_OP_TYPE_C' ) ( 'ZREING_DOCTYPE_R' )
      ( 'ZREING_GL_ROLES' ) ( 'ZREING_CT2_GL_A' ) ( 'ZREING_DOCFLOW_C' )
      ( 'ZI_COMPANYCODEADDLINFORMATION' ) ( 'ZC_INTERCORELATIONSHIP' )
      ( 'ZI_REINGCBCUSTOMERRECON' ) ( 'ZI_REINGCBSUPPLIERRECON' )
      ( 'ZI_REINGCBPRODUCTTEXT' ) ( 'ZREING_DOCTYPE_C' ) ( 'I_CURRENCY' )
      ( 'ZREING_CB_DOC_A' ) ( 'ZREING_CB_ITEM_A' ) ( 'ZREING_CB_TRC_A' )
      ( 'ZREING_CT2_MAT_A' ) ( 'ZREING_CMP_MAP_C' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    sql_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    saved_flow = zcl_reing_contab_engine=>gt_flow_all.
    saved_doctype = zcl_reing_contab_engine=>gt_doctype_all.
    saved_optype = zcl_reing_contab_engine=>gt_optype_all.
    saved_orig = zcl_reing_contab_engine=>gt_orig_docs_all.
    saved_docs = zcl_reing_contab_engine=>gt_doc_pending.
    saved_items = zcl_reing_contab_engine=>gt_item_pending.
    saved_traces = zcl_reing_contab_engine=>gt_trace_pending.
    saved_precision = zcl_reing_contab_engine=>gt_trans_currencies.
    saved_kostl = zcl_reing_contab_engine=>gt_contract_kostl.
    saved_map = zcl_reing_contab_engine=>gt_campana_map.
    saved_guard = zcl_reing_contab_engine=>gv_test_eba_off.
    saved_eba_off = zcl_reing_contab_engine=>gv_eba_off.
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    zcl_reing_contab_engine=>gv_test_eba_off = abap_true.
    sql_env->clear_doubles( ).
    cut = NEW #( ).
    poster = NEW #( ).
    cut->set_fi_poster( poster ).
    TEST-INJECTION eba_engine_switch.
      gv_eba_off = zcl_reing_contab_engine=>gv_test_eba_off.
    END-TEST-INJECTION.
    TEST-INJECTION cb01_projection_guard.
      lv_eba_off = zcl_reing_contab_engine=>gv_test_eba_off.
    END-TEST-INJECTION.
    TEST-INJECTION cb01_precision_guard.
      lv_eba_off = zcl_reing_contab_engine=>gv_test_eba_off.
    END-TEST-INJECTION.
  ENDMETHOD.
  METHOD teardown.
    " Restore all shared state even when a test assertion interrupts execution.
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    zcl_reing_contab_engine=>gt_flow_all = saved_flow.
    zcl_reing_contab_engine=>gt_doctype_all = saved_doctype.
    zcl_reing_contab_engine=>gt_optype_all = saved_optype.
    zcl_reing_contab_engine=>gt_orig_docs_all = saved_orig.
    zcl_reing_contab_engine=>gt_doc_pending = saved_docs.
    zcl_reing_contab_engine=>gt_item_pending = saved_items.
    zcl_reing_contab_engine=>gt_trace_pending = saved_traces.
    zcl_reing_contab_engine=>gt_trans_currencies = saved_precision.
    zcl_reing_contab_engine=>gt_contract_kostl = saved_kostl.
    zcl_reing_contab_engine=>gt_campana_map = saved_map.
    zcl_reing_contab_engine=>gv_test_eba_off = saved_guard.
    zcl_reing_contab_engine=>gv_eba_off = saved_eba_off.
    sql_env->clear_doubles( ).
    CLEAR: cut, poster, db_docs, db_items, db_traces.
  ENDMETHOD.
  METHOD given.
    CONSTANTS c_gl1 TYPE sysuuid_x16 VALUE '05000000000000000000000000000001'.
    CONSTANTS c_gl2 TYPE sysuuid_x16 VALUE '05000000000000000000000000000002'.
    CONSTANTS c_gl3 TYPE sysuuid_x16 VALUE '05000000000000000000000000000003'.
    CONSTANTS c_gl4 TYPE sysuuid_x16 VALUE '05000000000000000000000000000004'.
    CONSTANTS c_gl5 TYPE sysuuid_x16 VALUE '05000000000000000000000000000005'.
    CONSTANTS c_gl6 TYPE sysuuid_x16 VALUE '05000000000000000000000000000006'.
    line = VALUE #( calc_run_id = 'UT-CB05-A' line_num = 1 ct_uuid = c_ct
      mat_uuid = c_mat op_uuid = c_op cm_h_id = c_cm ct_id = 'UT-CB05'
      matnr = 'UTCB05' op_type = 'F' bukrs_prest = iv_prest bukrs_recv = iv_recv
      ct_currency = 'USD' trans_currency = 'BRL' local_currency = 'EUR'
      calc_amt = 100 bruto_amt = 100 + iv_tax tax_amt = iv_tax net_amt = 90
      net_trans_amt = 450 net_local_amt = 90 exch_rate_1 = 5 exch_rate_1_type = 'M'
      exch_rate = '0.2' exch_rate_type = 'M' share_pct = 100 line_status = 'SIM_PROC' ).
    pcs = VALUE #(
      ( calc_run_id = line-calc_run_id line_num = 1 pc_seq = 1 prctr = '0000000999'
        campana = '459' allocation = '1' role_category = 'C' share_abs = 60
        calc_amt = 60 bruto_amt = 60 + iv_tax * '0.6' tax_amt = iv_tax * '0.6' net_amt = 54
        ct_currency = 'USD' local_currency = 'EUR' net_local_amt = 54 )
      ( calc_run_id = line-calc_run_id line_num = 1 pc_seq = 2 prctr = '0000000123'
        campana = '123' allocation = '3' role_category = 'E' share_abs = 40
        calc_amt = 40 bruto_amt = 40 + iv_tax * '0.4' tax_amt = iv_tax * '0.4' net_amt = 36
        ct_currency = 'USD' local_currency = 'EUR' net_local_amt = 36 ) ).
    steps = VALUE #(
      ( calc_run_id = line-calc_run_id line_num = 1 step_num = '04' seq = '01'
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'T1'
        output_amt = iv_tax output_currency = 'USD' output_trans_amt = iv_tax * 5 )
      ( calc_run_id = line-calc_run_id line_num = 1 step_num = '05' seq = '01'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 90 input_currency = 'USD'
        output_amt = 450 output_currency = 'BRL' output_trans_amt = 450 rate_pct = 5 )
      ( calc_run_id = line-calc_run_id line_num = 1 step_num = '05' seq = '02'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 450 input_currency = 'BRL'
        output_amt = 90 output_currency = 'EUR' output_trans_amt = 90 rate_pct = '0.2' ) ).
    IF iv_zero = abap_true.
      CLEAR: line-calc_amt, line-bruto_amt, line-tax_amt, line-net_amt,
        line-net_trans_amt, line-net_local_amt.
      LOOP AT pcs ASSIGNING FIELD-SYMBOL(<pc>).
        CLEAR: <pc>-calc_amt, <pc>-bruto_amt, <pc>-tax_amt, <pc>-net_amt, <pc>-net_local_amt.
      ENDLOOP.
      LOOP AT steps ASSIGNING FIELD-SYMBOL(<step>).
        CLEAR: <step>-input_amt, <step>-output_amt, <step>-output_trans_amt.
      ENDLOOP.
    ENDIF.
    currencies = VALUE #( ( currency = 'USD' decimals = 2 )
      ( currency = 'BRL' decimals = 2 ) ( currency = 'EUR' decimals = 2 ) ).
    " Project the EBA fixture only; non-EBA variants keep that snapshot as distractor.
    DATA(ls_projection_line) = line.
    ls_projection_line-bukrs_prest = 'EBA'.
    DATA(ls_projection) = zcl_reing_ca_trans_amounts=>project_line(
      is_line = ls_projection_line it_line_pc = pcs it_steps = steps
      it_currencies = currencies iv_eba_off = abap_false ).
    pcs = CORRESPONDING #( ls_projection-line_pc ).
    steps = ls_projection-steps.
    DATA lt_run TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    lt_run = VALUE #( ( calc_run_id = 'UT-CB05-A' fiscal_year = '2026' fiscal_period = '09' )
      ( calc_run_id = 'UT-CB05-B' fiscal_year = '2026' fiscal_period = '09' ) ).
    sql_env->insert_test_data( lt_run ).
    DATA lt_op TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    lt_op = VALUE #( ( op_type = 'F' active = abap_true reversal_reason = '03' ) ).
    sql_env->insert_test_data( lt_op ).
    DATA lt_flow TYPE zif_reing_contab_types=>ty_flow_t.
    lt_flow = VALUE #( ( op_type = 'F' seq = '010' doc_type_code = 'AR' blart = 'SA' active = 'X' bukrs_rule = 'P' ) ).
    IF iv_flow <> 'R'.
      APPEND VALUE #( op_type = 'F' seq = '020' doc_type_code = 'AP' blart = 'SA' active = 'X' bukrs_rule = 'R' ) TO lt_flow.
    ENDIF.
    IF iv_flow = 'Z'.
      APPEND VALUE #( op_type = 'F' seq = '030' doc_type_code = 'ZZZ' blart = 'SA' active = 'X' bukrs_rule = 'R' ) TO lt_flow.
    ELSEIF iv_flow = 'I'.
      APPEND VALUE #( op_type = 'F' seq = '040' doc_type_code = 'INT' blart = 'SA' active = 'X' bukrs_rule = 'P' ) TO lt_flow.
    ELSEIF iv_flow = 'D'.
      lt_flow[ 2 ]-doc_type_code = 'AR'.
    ENDIF.
    sql_env->insert_test_data( lt_flow ).
    DATA lt_types TYPE STANDARD TABLE OF zreing_doctype_c WITH EMPTY KEY.
    lt_types = VALUE #( ( doc_type_code = 'AR' processing_class = 'ZCL_REING_CONTAB_DOC' )
      ( doc_type_code = 'AP' processing_class = 'ZCL_REING_CONTAB_DOC' )
      ( doc_type_code = 'ZZZ' processing_class = 'ZCL_REING_CONTAB_DOC_RECL' )
      ( doc_type_code = 'INT' processing_class = 'ZCL_REING_CONTAB_DOC_INT' ) ).
    sql_env->insert_test_data( lt_types ).
    DATA lt_param TYPE STANDARD TABLE OF zi_companycodeaddlinformation WITH EMPTY KEY.
    lt_param = VALUE #(
      ( companycode = 'EBA' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'EBA' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '111' )
      ( companycode = 'MUR' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'MUR' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '222' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '333' ) ).
    IF iv_missing = abap_true.
      DELETE lt_param WHERE companycode = iv_recv AND companycodeparametertype = 'ZIDMEL'.
    ENDIF.
    sql_env->insert_test_data( lt_param ).
    DATA lt_ic TYPE STANDARD TABLE OF zc_intercorelationship WITH EMPTY KEY.
    lt_ic = VALUE #( ( providerbusinesspartner = '0000000001' recipientbusinesspartner = '0000000002'
      providercompanycode = iv_prest recipientcompanycode = iv_recv
      recipientcustomer = '0000000001' providervendor = '0000000002' ) ).
    sql_env->insert_test_data( lt_ic ).
    DATA lt_ar TYPE STANDARD TABLE OF zi_reingcbcustomerrecon WITH EMPTY KEY.
    lt_ar = VALUE #( ( customer = '0000000001' companycode = iv_prest reconciliationaccount = '0000110000' ) ).
    sql_env->insert_test_data( lt_ar ).
    DATA lt_ap TYPE STANDARD TABLE OF zi_reingcbsupplierrecon WITH EMPTY KEY.
    lt_ap = VALUE #( ( supplier = '0000000002' companycode = iv_recv reconciliationaccount = '0000210000' ) ).
    sql_env->insert_test_data( lt_ap ).
    DATA lt_text TYPE STANDARD TABLE OF zi_reingcbproducttext WITH EMPTY KEY.
    lt_text = VALUE #( ( product = 'UTCB05' language = 'S' productdescription = 'Reintegros Licencias' ) ).
    sql_env->insert_test_data( lt_text ).
    DATA lt_roles TYPE STANDARD TABLE OF zreing_gl_roles WITH EMPTY KEY.
    lt_roles = VALUE #( ( gl_role = 'RA' posting_context = 'AR' ) ( gl_role = 'PA' posting_context = 'AP' )
      ( gl_role = 'GE' posting_context = 'GL' )
      ( gl_role = 'TS' posting_context = 'GL' role_type = 'T' tax_type = 'T1' )
      ( gl_role = 'TH' posting_context = 'GL' role_type = 'T' tax_type = 'T1' reclassify = 'X' role_reclas = 'RT' )
      ( gl_role = 'RT' posting_context = 'GL' role_type = 'T' tax_type = 'T1' )
      ( gl_role = 'GS' posting_context = 'GL' ) ( gl_role = 'GH' posting_context = 'GL' ) ).
    sql_env->insert_test_data( lt_roles ).
    " Source contract: ordinary AR GL uses CALC; TAX remains in AP/ZZZ.
    DATA lt_mapping TYPE STANDARD TABLE OF zreing_doctype_r WITH EMPTY KEY.
    lt_mapping = VALUE #( ( doc_type_code = 'AR' role_code = 'RA' posting_side = 'S' )
      ( doc_type_code = 'AR' role_code = 'GE' posting_side = 'H' )
      ( doc_type_code = 'AP' role_code = 'PA' posting_side = 'H' )
      ( doc_type_code = 'AP' role_code = 'GE' posting_side = 'S' )
      ( doc_type_code = 'AP' role_code = 'TS' posting_side = 'S' )
      ( doc_type_code = 'AP' role_code = 'TH' posting_side = 'H' )
      ( doc_type_code = 'ZZZ' role_code = 'RT' posting_side = 'S' )
      ( doc_type_code = 'ZZZ' role_code = 'GE' posting_side = 'H' )
      ( doc_type_code = 'INT' role_code = 'GS' posting_side = 'S' )
      ( doc_type_code = 'INT' role_code = 'GH' posting_side = 'H' ) ).
    sql_env->insert_test_data( lt_mapping ).
    DATA lt_accounts TYPE STANDARD TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.
    lt_accounts = VALUE #( ( ct_uuid = c_ct mat_uuid = c_mat gl_uuid = c_gl1 gl_role = 'GE' saknr = '0000410000' )
      ( ct_uuid = c_ct mat_uuid = c_mat gl_uuid = c_gl2 gl_role = 'TS' saknr = '0000420000' )
      ( ct_uuid = c_ct mat_uuid = c_mat gl_uuid = c_gl3 gl_role = 'TH' saknr = '0000430000' )
      ( ct_uuid = c_ct mat_uuid = c_mat gl_uuid = c_gl4 gl_role = 'RT' saknr = '0000510000' )
      ( ct_uuid = c_ct mat_uuid = c_mat gl_uuid = c_gl5 gl_role = 'GS' saknr = '0000410000' )
      ( ct_uuid = c_ct mat_uuid = c_mat gl_uuid = c_gl6 gl_role = 'GH' saknr = '0000410000' ) ).
    DATA(lt_accounts_b) = lt_accounts.
    LOOP AT lt_accounts_b ASSIGNING FIELD-SYMBOL(<acct>).
      <acct>-ct_uuid = c_ct_b.
      <acct>-mat_uuid = c_mat_b.
    ENDLOOP.
    APPEND LINES OF lt_accounts_b TO lt_accounts.
    sql_env->insert_test_data( lt_accounts ).
    DATA lt_currency TYPE STANDARD TABLE OF i_currency WITH EMPTY KEY.
    lt_currency = CORRESPONDING #( currencies ).
    sql_env->insert_test_data( lt_currency ).
    snapshot_db( ).
    warm( ).
  ENDMETHOD.
  METHOD warm.
    zcl_reing_contab_engine=>warm_config( VALUE #( ( line ) ) ).
  ENDMETHOD.
  METHOD snapshot_db.
    DATA lt_runs TYPE RANGE OF zreing_calc_run_id.
    lt_runs = VALUE #( ( sign = 'I' option = 'EQ' low = 'UT-CB05-A' )
      ( sign = 'I' option = 'EQ' low = 'UT-CB05-B' ) ).
    SELECT * FROM zreing_cb_doc_a WHERE calc_run_id IN @lt_runs INTO TABLE @db_docs.
    SELECT * FROM zreing_cb_item_a WHERE calc_run_id IN @lt_runs INTO TABLE @db_items.
    SELECT * FROM zreing_cb_trc_a WHERE calc_run_id IN @lt_runs INTO TABLE @db_traces.
    SORT db_docs BY calc_run_id line_num doc_type_code.
    SORT db_items BY calc_run_id line_num doc_type_code item_num.
    SORT db_traces BY calc_run_id line_num trace_seq.
  ENDMETHOD.
  METHOD assert_db_unchanged.
    DATA lt_runs TYPE RANGE OF zreing_calc_run_id.
    lt_runs = VALUE #( ( sign = 'I' option = 'EQ' low = 'UT-CB05-A' )
      ( sign = 'I' option = 'EQ' low = 'UT-CB05-B' ) ).
    DATA lt_docs TYPE tt_docs.
    DATA lt_items TYPE tt_items.
    DATA lt_traces TYPE tt_traces.
    SELECT * FROM zreing_cb_doc_a WHERE calc_run_id IN @lt_runs INTO TABLE @lt_docs.
    SELECT * FROM zreing_cb_item_a WHERE calc_run_id IN @lt_runs INTO TABLE @lt_items.
    SELECT * FROM zreing_cb_trc_a WHERE calc_run_id IN @lt_runs INTO TABLE @lt_traces.
    SORT lt_docs BY calc_run_id line_num doc_type_code.
    SORT lt_items BY calc_run_id line_num doc_type_code item_num.
    SORT lt_traces BY calc_run_id line_num trace_seq.
    cl_abap_unit_assert=>assert_equals( act = lt_docs exp = db_docs ).
    cl_abap_unit_assert=>assert_equals( act = lt_items exp = db_items ).
    cl_abap_unit_assert=>assert_equals( act = lt_traces exp = db_traces ).
  ENDMETHOD.
  METHOD process.
    rs_result = cut->process_line( is_line_a = line it_line_pc = pcs it_step_a = steps iv_mode = iv_mode ).
  ENDMETHOD.
  METHOD assert_counts.
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = iv_calls ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_doc_pending ) exp = iv_docs ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_item_pending ) exp = iv_items ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_trace_pending ) exp = iv_traces ).
    cl_abap_unit_assert=>assert_initial( cut->mt_doc_buffer ).
    cl_abap_unit_assert=>assert_initial( cut->mt_item_buffer ).
    cl_abap_unit_assert=>assert_initial( cut->mt_traces ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD expected_items.
    " V001 (CC) - DF-567: ET v41 item text in literal regression oracles.
    " Literal oracles follow CALC for AR, BRUTO for AP/INT, STEP TAX for ZZZ.
    DATA(lv_code) = COND string( WHEN iv_code = '1' THEN '111'
      WHEN iv_code = '3' THEN '333' WHEN iv_code = '2' THEN '222'
      WHEN iv_type = 'AR' OR iv_type = 'INT' THEN '111' ELSE '222' ).
    CASE iv_type.
      WHEN 'AR'.
        rt_items = VALUE #(
          ( role_code = 'RA' posting_context = 'AR' hkont = '0000110000' partner = '0000000001'
            posting_side = 'S' amount = 100 * iv_scale waers = 'USD' zuonr = 'REINT LICENCIAS'
            item_text = |RA \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GE' posting_context = 'GL' hkont = '0000410000' posting_side = 'H'
            amount = -60 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |GE4590000000999 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GE' posting_context = 'GL' hkont = '0000410000' posting_side = 'H'
            amount = -40 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |GE1230000000123 \| { line-bukrs_prest } X { line-bukrs_recv }| )
        ).
      WHEN 'AP'.
        rt_items = VALUE #(
          ( role_code = 'PA' posting_context = 'AP' hkont = '0000210000' partner = '0000000002'
            posting_side = 'H' amount = COND #( WHEN iv_tax = abap_true THEN -125 ELSE -100 ) * iv_scale waers = 'USD' zuonr = 'REINT LICENCIAS'
            item_text = |PA \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GE' posting_context = 'GL' hkont = '0000410000' posting_side = 'S'
            amount = COND #( WHEN iv_tax = abap_true THEN 75 ELSE 60 ) * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |GE4590000000999 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GE' posting_context = 'GL' hkont = '0000410000' posting_side = 'S'
            amount = COND #( WHEN iv_tax = abap_true THEN 50 ELSE 40 ) * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |GE1230000000123 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'TS' posting_context = 'GL' hkont = '0000420000' posting_side = 'S'
            amount = 15 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |TS4590000000999 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'TS' posting_context = 'GL' hkont = '0000420000' posting_side = 'S'
            amount = 10 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |TS1230000000123 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'TH' posting_context = 'GL' hkont = '0000430000' posting_side = 'H'
            amount = -15 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |TH4590000000999 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'TH' posting_context = 'GL' hkont = '0000430000' posting_side = 'H'
            amount = -10 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |TH1230000000123 \| { line-bukrs_prest } X { line-bukrs_recv }| )
        ).
        IF iv_tax = abap_false.
          DELETE rt_items WHERE role_code = 'TS' OR role_code = 'TH'.
        ENDIF.
      WHEN 'ZZZ'.
        rt_items = VALUE #(
          ( role_code = 'RT' posting_context = 'GL' hkont = '0000510000' posting_side = 'S'
            amount = 15 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |RT RECL \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'RT' posting_context = 'GL' hkont = '0000510000' posting_side = 'S'
            amount = 10 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |RT RECL \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GE' posting_context = 'GL' hkont = '0000410000' posting_side = 'H'
            amount = -15 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |GE RECL \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GE' posting_context = 'GL' hkont = '0000410000' posting_side = 'H'
            amount = -10 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |GE RECL \| { line-bukrs_prest } X { line-bukrs_recv }| )
        ).
      WHEN 'INT'.
        rt_items = VALUE #(
          ( role_code = 'GS' posting_context = 'GL' hkont = '0000410000' posting_side = 'S'
            amount = 75 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |GS4590000000999 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GS' posting_context = 'GL' hkont = '0000410000' posting_side = 'S'
            amount = 50 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |GS1230000000123 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GH' posting_context = 'GL' hkont = '0000410000' posting_side = 'H'
            amount = -75 * iv_scale waers = 'USD' prctr = '0000000999' campana = '459' allocation = '1'
            kostl = |4591{ lv_code }999| zuonr = 'REINT LICENCIAS'
            item_text = |GH4590000000999 \| { line-bukrs_prest } X { line-bukrs_recv }| )
          ( role_code = 'GH' posting_context = 'GL' hkont = '0000410000' posting_side = 'H'
            amount = -50 * iv_scale waers = 'USD' prctr = '0000000123' campana = '123' allocation = '3'
            kostl = |1233{ lv_code }123| zuonr = 'REINT LICENCIAS'
            item_text = |GH1230000000123 \| { line-bukrs_prest } X { line-bukrs_recv }| )
        ).
    ENDCASE.
  ENDMETHOD.
  METHOD assert_document.
    DATA(lv_call) = COND i( WHEN iv_call = 0 THEN iv_index ELSE iv_call ).
    DATA(ls_call) = poster->calls[ lv_call ].
    DATA(ls_expected_header) = VALUE zif_reing_contab_types=>ty_header(
      bukrs = COND #( WHEN iv_type = 'AR' OR iv_type = 'INT' THEN line-bukrs_prest ELSE line-bukrs_recv )
      blart = 'SA' budat = '20260930' bldat = cl_abap_context_info=>get_system_date( )
      waers = 'USD' doc_type_code = iv_type header_txt = |REING F { line-calc_run_id }| ).
    cl_abap_unit_assert=>assert_equals( act = ls_call-header exp = ls_expected_header ).
    cl_abap_unit_assert=>assert_equals( act = ls_call-mode exp = iv_mode ).
    DATA(lt_expected_items) = expected_items( iv_type = iv_type iv_scale = iv_scale iv_tax = iv_tax iv_code = iv_code ).
    DATA(lt_actual_items) = ls_call-items.
    DATA lv_seq TYPE i.
    LOOP AT lt_actual_items ASSIGNING FIELD-SYMBOL(<item>).
      lv_seq += 1.
      cl_abap_unit_assert=>assert_equals( act = <item>-item_num exp = CONV zreing_seq3( lv_seq ) ).
      CLEAR <item>-item_num.
    ENDLOOP.
    SORT lt_actual_items BY role_code prctr.
    SORT lt_expected_items BY role_code prctr.
    cl_abap_unit_assert=>assert_equals( act = lt_actual_items exp = lt_expected_items ).
    DATA(ls_doc) = is_result-documents[ iv_index ].
    cl_abap_unit_assert=>assert_equals( act = ls_doc-items exp = ls_call-items ).
    cl_abap_unit_assert=>assert_equals( act = ls_doc-total_amount exp = iv_total ).
    cl_abap_unit_assert=>assert_false( ls_doc-has_error ).
    DATA(ls_expected_payload) = VALUE zif_reing_contab_types=>ty_step_result(
      doc_type_code = iv_type bukrs = ls_expected_header-bukrs
      belnr = COND #( WHEN iv_mode = 'P' THEN '1000000001' ELSE space ) items = ls_call-items ).
    DATA(lv_expected_json) = /ui2/cl_json=>serialize( data = ls_expected_payload ).
    cl_abap_unit_assert=>assert_equals( act = ls_doc-payload exp = lv_expected_json ).
    DATA(ls_expected_result) = VALUE zif_reing_contab_types=>ty_step_result(
      doc_type_code = iv_type bukrs = ls_expected_header-bukrs
      belnr = COND #( WHEN iv_mode = 'P' THEN '1000000001' ELSE space ) gjahr = '2026'
      blart = 'SA' budat = '20260930' waers = 'USD' total_amount = iv_total
      items = ls_call-items payload = lv_expected_json ).
    cl_abap_unit_assert=>assert_equals( act = ls_doc exp = ls_expected_result ).
    DATA(ls_pending) = zcl_reing_contab_engine=>gt_doc_pending[
      calc_run_id = line-calc_run_id line_num = line-line_num doc_type_code = iv_type ].
    cl_abap_unit_assert=>assert_not_initial( ls_pending-created_at ).
    CLEAR ls_pending-created_at.
    DATA(ls_expected_pending) = VALUE zreing_cb_doc_a(
      calc_run_id = line-calc_run_id line_num = line-line_num doc_type_code = iv_type
      bukrs = ls_expected_header-bukrs belnr = ls_expected_result-belnr gjahr = '2026'
      blart = 'SA' budat = '20260930' waers = 'USD' total_amount = iv_total
      num_items = lines( lt_expected_items ) status = COND #( WHEN iv_mode = 'C' THEN 'SI' ELSE 'OK' )
      simulated = xsdbool( iv_mode = 'C' ) payload = lv_expected_json created_by = sy-uname ).
    cl_abap_unit_assert=>assert_equals( act = ls_pending exp = ls_expected_pending ).
    DATA lt_pending_items TYPE tt_items.
    lt_pending_items = VALUE #( FOR ls_item IN zcl_reing_contab_engine=>gt_item_pending
      WHERE ( calc_run_id = line-calc_run_id AND line_num = line-line_num AND doc_type_code = iv_type ) ( ls_item ) ).
    DATA lt_expected_pending_items TYPE tt_items.
    lt_expected_pending_items = CORRESPONDING #( ls_call-items ).
    LOOP AT lt_expected_pending_items ASSIGNING FIELD-SYMBOL(<pending_item>).
      <pending_item>-calc_run_id = line-calc_run_id.
      <pending_item>-line_num = line-line_num.
      <pending_item>-doc_type_code = iv_type.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lt_pending_items exp = lt_expected_pending_items ).
    cl_abap_unit_assert=>assert_equals( act = is_result-calc_run_id exp = line-calc_run_id ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_num exp = line-line_num ).
    cl_abap_unit_assert=>assert_equals( act = is_result-op_type exp = 'F' ).
    cl_abap_unit_assert=>assert_equals( act = is_result-mode exp = iv_mode ).
  ENDMETHOD.
  METHOD assert_trace.
    DATA(ls_actual) = zcl_reing_contab_engine=>gt_trace_pending[ iv_index ].
    cl_abap_unit_assert=>assert_not_initial( ls_actual-created_at ).
    CLEAR ls_actual-created_at.
    DATA(ls_expected) = VALUE zreing_cb_trc_a(
      calc_run_id = line-calc_run_id line_num = line-line_num trace_seq = iv_index
      trace_typ = iv_type doc_type_code = iv_doc contab_mode = iv_mode
      belnr = iv_belnr message = iv_message created_by = sy-uname ).
    cl_abap_unit_assert=>assert_equals( act = ls_actual exp = ls_expected ).
  ENDMETHOD.
  METHOD given_original.
    DATA lt_original TYPE tt_docs.
    lt_original = VALUE #( ( calc_run_id = line-calc_run_id line_num = line-line_num
      doc_type_code = 'AR' bukrs = 'MUR' belnr = '1234567890' gjahr = '2026'
      blart = 'SA' budat = '20260228' waers = 'BRL' total_amount = '123.45'
      num_items = 2 status = 'OK' payload = 'CB05 original payload'
      created_by = 'ORIGINAL' created_at = '20260228120000' ) ).
    IF iv_partial = abap_true.
      APPEND VALUE #( calc_run_id = line-calc_run_id line_num = line-line_num
        doc_type_code = 'AP' bukrs = 'EBA' belnr = '2234567890' gjahr = '2026'
        blart = 'KR' budat = '20260228' waers = 'GBP' total_amount = '456.78'
        num_items = 3 status = 'RV' reverse_belnr = '8234567890'
        payload = 'CB05 already reversed payload' created_by = 'OLDUSER'
        created_at = '20260228120100' ) TO lt_original.
    ENDIF.
    sql_env->insert_test_data( lt_original ).
    " An unrelated original item and trace must remain unchanged in the doubles.
    DATA lt_old_items TYPE tt_items.
    lt_old_items = VALUE #( ( calc_run_id = line-calc_run_id line_num = line-line_num
      doc_type_code = 'AR' item_num = 1 role_code = 'OLD' waers = 'BRL' amount = '123.45' ) ).
    sql_env->insert_test_data( lt_old_items ).
    DATA lt_old_trace TYPE tt_traces.
    lt_old_trace = VALUE #( ( calc_run_id = line-calc_run_id line_num = line-line_num
      trace_seq = 42 trace_typ = 'STEP_OK' doc_type_code = 'AR' contab_mode = 'P'
      belnr = '1234567890' created_by = 'ORIGINAL' created_at = '20260228120000' message = 'old trace' ) ).
    sql_env->insert_test_data( lt_old_trace ).
    line-line_status = 'ANUL_PROC'.
    line-ct_currency = 'EUR'.
    line-trans_currency = 'USD'.
    line-exch_rate_1 = '2.75'.
    snapshot_db( ).
    warm( ).
  ENDMETHOD.
  METHOD assert_original.
    cl_abap_unit_assert=>assert_equals( act = lines( poster->reverses ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( poster->calls ).
    DATA(ls_expected_reverse) = VALUE lcl_cb05_poster=>ty_reverse(
      bukrs = 'MUR' belnr = '1234567890' gjahr = '2026' reason = '03' pstng_date = '20260930' ).
    cl_abap_unit_assert=>assert_equals( act = poster->reverses[ 1 ] exp = ls_expected_reverse ).
    DATA(ls_expected_doc) = VALUE zreing_cb_doc_a(
      calc_run_id = line-calc_run_id line_num = line-line_num doc_type_code = 'AR'
      bukrs = 'MUR' belnr = '1234567890' gjahr = '2026' blart = 'SA' budat = '20260228'
      waers = 'BRL' total_amount = '123.45' num_items = 2 status = 'RV'
      reverse_belnr = '9000000001' payload = 'CB05 original payload'
      created_by = 'ORIGINAL' created_at = '20260228120000' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_doc_pending[ 1 ] exp = ls_expected_doc ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_item_pending ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD flow_off_ar_ap.
    given( ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 ).
    assert_document( is_result = result iv_index = 2 iv_type = 'AP' iv_total = 150 ).
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_OK' iv_doc = 'AP' ).
    assert_counts( iv_calls = 2 iv_docs = 2 iv_items = 10 iv_traces = 2 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_off_zzz.
    given( iv_flow = 'Z' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 3 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 ).
    assert_document( is_result = result iv_index = 2 iv_type = 'AP' iv_total = 150 ).
    assert_document( is_result = result iv_index = 3 iv_type = 'ZZZ' iv_total = 25 ).
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_OK' iv_doc = 'AP' ).
    assert_trace( iv_index = 3 iv_type = 'STEP_OK' iv_doc = 'ZZZ' ).
    assert_counts( iv_calls = 3 iv_docs = 3 iv_items = 14 iv_traces = 3 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_off_zzz_zero_skips.
    given( iv_flow = 'Z' iv_tax = 0 ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 iv_tax = abap_false ).
    assert_document( is_result = result iv_index = 2 iv_type = 'AP' iv_total = 100 iv_tax = abap_false ).
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_OK' iv_doc = 'AP' ).
    assert_trace( iv_index = 3 iv_type = 'STEP_SKIP' iv_doc = 'ZZZ' ).
    assert_counts( iv_calls = 2 iv_docs = 2 iv_items = 6 iv_traces = 3 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_noneba_legacy.
    zcl_reing_contab_engine=>gv_test_eba_off = abap_false.
    given( iv_prest = 'MUR' iv_recv = 'OVR' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 iv_code = '2' ).
    assert_document( is_result = result iv_index = 2 iv_type = 'AP' iv_total = 150 iv_code = '3' ).
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_OK' iv_doc = 'AP' ).
    assert_counts( iv_calls = 2 iv_docs = 2 iv_items = 10 iv_traces = 2 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_intra_only_int.
    given( iv_flow = 'I' iv_recv = 'EBA' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 1 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'INT' iv_total = 125 ).
    assert_trace( iv_index = 1 iv_type = 'STEP_SKIP' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_SKIP' iv_doc = 'AP' ).
    assert_trace( iv_index = 3 iv_type = 'STEP_OK' iv_doc = 'INT' ).
    assert_counts( iv_calls = 1 iv_docs = 1 iv_items = 4 iv_traces = 3 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_intra_zero_skips.
    given( iv_flow = 'I' iv_recv = 'EBA' iv_zero = abap_true iv_missing = abap_true ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_initial( result-documents ).
    assert_trace( iv_index = 1 iv_type = 'STEP_SKIP' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_SKIP' iv_doc = 'AP' ).
    assert_trace( iv_index = 3 iv_type = 'STEP_SKIP' iv_doc = 'INT' ).
    assert_counts( iv_calls = 0 iv_docs = 0 iv_items = 0 iv_traces = 3 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_dup_type_reject.
    given( iv_flow = 'D' ).
    TRY.
        DATA(result) = process( ).
        cl_abap_unit_assert=>fail( 'Duplicate type must fail before the first fake FI call' ).
      CATCH zcx_reing_contab INTO DATA(error).
        cl_abap_unit_assert=>assert_true( xsdbool( error->mv_message CS 'H-3' ) ).
        cl_abap_unit_assert=>assert_true( xsdbool( error->mv_message CS 'OP_TYPE F' ) ).
        cl_abap_unit_assert=>assert_true( xsdbool( error->mv_message CS 'DOC_TYPE_CODE AR' ) ).
    ENDTRY.
    assert_counts( iv_calls = 0 iv_docs = 0 iv_items = 0 iv_traces = 0 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_post_error_keeps_prior.
    given( iv_flow = 'Z' ).
    line-line_status = 'POST_PROC'.
    poster->fail_at = 2.
    DATA(result) = process( 'P' ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = 'CB05 synthetic AP failure' ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 iv_mode = 'P' ).
    cl_abap_unit_assert=>assert_equals( act = poster->calls[ 2 ]-mode exp = 'P' ).
    cl_abap_unit_assert=>assert_equals( act = poster->calls[ 2 ]-header-doc_type_code exp = 'AP' ).
    cl_abap_unit_assert=>assert_true( result-documents[ 2 ]-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 2 ]-error_msg exp = 'CB05 synthetic AP failure' ).
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' iv_mode = 'P' iv_belnr = '1000000001' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_ERR' iv_doc = 'AP' iv_mode = 'P' iv_message = 'CB05 synthetic AP failure' ).
    assert_counts( iv_calls = 2 iv_docs = 1 iv_items = 3 iv_traces = 2 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_storno_original_exact.
    given( iv_flow = 'R' ).
    given_original( ).
    DATA(result) = process( 'S' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-bukrs exp = 'MUR' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-belnr exp = '1234567890' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-gjahr exp = '2026' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-reverse_belnr exp = '9000000001' ).
    assert_original( ).
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' iv_mode = 'S' iv_belnr = '1234567890' ).
    assert_counts( iv_calls = 0 iv_docs = 1 iv_items = 0 iv_traces = 1 ).
  ENDMETHOD.
  METHOD flow_storno_partial.
    given( ).
    given_original( abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_orig_docs_all ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_orig_docs_all[ 1 ]-doc_type_code exp = 'AR' ).
    DATA(result) = process( 'S' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-doc_type_code exp = 'AR' ).
    assert_original( ).
    assert_trace( iv_index = 1 iv_type = 'STEP_SKIP' iv_doc = 'AP' iv_mode = 'S' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_OK' iv_doc = 'AR' iv_mode = 'S' iv_belnr = '1234567890' ).
    assert_counts( iv_calls = 0 iv_docs = 1 iv_items = 0 iv_traces = 2 ).
  ENDMETHOD.
  METHOD flow_run_buffers_isolated.
    given( iv_flow = 'R' ).
    DATA(line_a) = line.
    DATA(line_b) = line.
    line_b-calc_run_id = 'UT-CB05-B'.
    line_b-ct_uuid = c_ct_b.
    line_b-mat_uuid = c_mat_b.
    line_b-op_uuid = c_op_b.
    line_b-cm_h_id = c_cm_b.
    line_b-calc_amt *= 2.
    line_b-bruto_amt *= 2.
    line_b-tax_amt *= 2.
    line_b-net_amt *= 2.
    line_b-net_trans_amt *= 2.
    line_b-net_local_amt *= 2.
    DATA(pcs_b) = pcs.
    LOOP AT pcs_b ASSIGNING FIELD-SYMBOL(<pc>).
      <pc>-calc_run_id = line_b-calc_run_id.
      <pc>-calc_amt *= 2.
      <pc>-bruto_amt *= 2.
      <pc>-tax_amt *= 2.
      <pc>-net_amt *= 2.
      <pc>-net_local_amt *= 2.
      <pc>-bruto_trans_amt *= 2.
      <pc>-net_trans_amt *= 2.
    ENDLOOP.
    DATA(steps_b) = steps.
    LOOP AT steps_b ASSIGNING FIELD-SYMBOL(<step>).
      <step>-calc_run_id = line_b-calc_run_id.
      <step>-input_amt *= 2.
      <step>-output_amt *= 2.
      <step>-output_trans_amt *= 2.
    ENDLOOP.
    zcl_reing_contab_engine=>warm_config( VALUE #( ( line_a ) ( line_b ) ) ).
    DATA(result_a) = process( ).
    cl_abap_unit_assert=>assert_false( result_a-has_error ).
    assert_document( is_result = result_a iv_index = 1 iv_type = 'AR' iv_total = 100 ).
    DATA(doc_a) = zcl_reing_contab_engine=>gt_doc_pending[ 1 ].
    DATA(items_a) = zcl_reing_contab_engine=>gt_item_pending.
    DATA(trace_a) = zcl_reing_contab_engine=>gt_trace_pending[ 1 ].
    line = line_b.
    pcs = pcs_b.
    steps = steps_b.
    DATA(result_b) = process( ).
    cl_abap_unit_assert=>assert_false( result_b-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result_b-documents ) exp = 1 ).
    assert_document( is_result = result_b iv_index = 1 iv_call = 2 iv_type = 'AR' iv_total = 200 iv_scale = 2 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_doc_pending[ 1 ] exp = doc_a ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_trace_pending[ 1 ] exp = trace_a ).
    DATA lt_a_items TYPE tt_items.
    lt_a_items = VALUE #( FOR ls_i IN zcl_reing_contab_engine=>gt_item_pending
      WHERE ( calc_run_id = 'UT-CB05-A' ) ( ls_i ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_a_items exp = items_a ).
    cl_abap_unit_assert=>assert_equals( act = cut->ms_line_a exp = line_b ).
    cl_abap_unit_assert=>assert_equals( act = cut->mt_line_pc exp = pcs_b ).
    cl_abap_unit_assert=>assert_equals( act = cut->mt_step_a exp = steps_b ).
    cl_abap_unit_assert=>assert_equals( act = result_b-calc_run_id exp = 'UT-CB05-B' ).
    DATA(trace_b) = zcl_reing_contab_engine=>gt_trace_pending[ 2 ].
    cl_abap_unit_assert=>assert_not_initial( trace_b-created_at ).
    CLEAR trace_b-created_at.
    DATA(expected_trace_b) = VALUE zreing_cb_trc_a( calc_run_id = 'UT-CB05-B' line_num = 1
      trace_seq = 1 trace_typ = 'STEP_OK' doc_type_code = 'AR' contab_mode = 'C' created_by = sy-uname ).
    cl_abap_unit_assert=>assert_equals( act = trace_b exp = expected_trace_b ).
    assert_counts( iv_calls = 2 iv_docs = 2 iv_items = 6 iv_traces = 2 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD flow_ceco_error_stops.
    given( iv_flow = 'Z' iv_missing = abap_true ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 ).
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER '002' WITH 'AP' 'MUR' INTO DATA(expected_error).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected_error ).
    cl_abap_unit_assert=>assert_true( result-documents[ 2 ]-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 2 ]-doc_type_code exp = 'AP' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 2 ]-error_msg exp = expected_error ).
    LOOP AT result-documents[ 2 ]-items INTO DATA(item) WHERE posting_context = 'GL'.
      cl_abap_unit_assert=>assert_initial( item-kostl ).
    ENDLOOP.
    assert_trace( iv_index = 1 iv_type = 'STEP_OK' iv_doc = 'AR' ).
    assert_trace( iv_index = 2 iv_type = 'STEP_ERR' iv_doc = 'AP' iv_message = CONV #( expected_error ) ).
    assert_counts( iv_calls = 1 iv_docs = 1 iv_items = 3 iv_traces = 2 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
  ENDMETHOD.
  METHOD contract_flow.
    DATA(flows) = zcl_reing_contab_engine=>gt_flow_all.
    ASSIGN flows[ doc_type_code = iv_doc ] TO FIELD-SYMBOL(<flow>).
    <flow>-kostl_rule = 'C'.
    <flow>-bukrs_rule = iv_rule.
    sql_env->get_double( 'ZREING_DOCFLOW_C' )->clear( ).
    sql_env->insert_test_data( flows ).
    DATA materials TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    materials = VALUE #( ( ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid
      matnr = line-matnr kostl = iv_kostl ) ).
    sql_env->get_double( 'ZREING_CT2_MAT_A' )->clear( ).
    sql_env->insert_test_data( materials ).
    warm( ).
  ENDMETHOD.
  METHOD contract_flow_success.
    given( iv_flow = 'R' ).
    contract_flow( ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 1 ).
    LOOP AT result-documents[ 1 ]-items INTO DATA(item).
      IF item-posting_context = 'GL'.
        cl_abap_unit_assert=>assert_equals( act = item-kostl exp = 'CTCECO1234' ).
      ELSE.
        cl_abap_unit_assert=>assert_initial( item-kostl ).
      ENDIF.
    ENDLOOP.
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD contract_flow_missing.
    given( iv_flow = 'R' ).
    contract_flow( iv_kostl = space ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_initial( poster->calls ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_doc_pending ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '006'
      WITH line-ct_id line-matnr 'AR' INTO DATA(expected).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    sql_env->get_double( 'ZREING_CT2_MAT_A' )->clear( ).
    warm( ).
    result = process( ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_initial( poster->calls ).
  ENDMETHOD.
  METHOD contract_late_error.
    given( iv_flow = 'Z' ).
    contract_flow( iv_doc = 'AP' iv_rule = 'R' ).
    line-line_status = zif_reing_ca_c=>line_status-post_proc.
    DATA(result) = process( 'P' ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_doc_pending ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-doc_type_code exp = 'AR' ).
    cl_abap_unit_assert=>assert_false( result-documents[ 1 ]-has_error ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '005' WITH 'AP' INTO DATA(expected).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD contract_cache_exact.
    given( iv_flow = 'R' ).
    contract_flow( ).
    DATA(line_b) = line.
    line_b-ct_uuid = c_ct_b.
    DATA(line_c) = line.
    line_c-mat_uuid = c_mat_b.
    DATA materials TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    materials = VALUE #( ( ct_uuid = c_ct mat_uuid = c_mat matnr = line-matnr kostl = 'CTCECO1234' )
      ( ct_uuid = c_ct_b mat_uuid = c_mat matnr = line-matnr kostl = 'OTHERCT123' )
      ( ct_uuid = c_ct mat_uuid = c_mat_b matnr = line-matnr kostl = 'OTHERMAT12' )
      ( ct_uuid = c_ct_b mat_uuid = c_mat_b matnr = line-matnr kostl = 'OUTSCOPE12' ) ).
    sql_env->get_double( 'ZREING_CT2_MAT_A' )->clear( ).
    sql_env->insert_test_data( materials ).
    zcl_reing_contab_engine=>warm_config( VALUE #( ( line ) ( line_b ) ( line_c ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_contract_kostl ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_contab_engine=>gt_contract_kostl[ ct_uuid = c_ct_b mat_uuid = c_mat ]-kostl exp = 'OTHERCT123' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_contab_engine=>gt_contract_kostl[ ct_uuid = c_ct mat_uuid = c_mat_b ]-kostl exp = 'OTHERMAT12' ).
    warm( ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_contract_kostl ) exp = 1 ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-items[ posting_context = 'GL' ]-kostl exp = 'CTCECO1234' ).
  ENDMETHOD.
  METHOD contract_cache_reset.
    given( iv_flow = 'R' ).
    contract_flow( ).
    cl_abap_unit_assert=>assert_not_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
    warm( ).
    DATA(flows) = zcl_reing_contab_engine=>gt_flow_all.
    flows[ 1 ]-kostl_rule = space.
    sql_env->get_double( 'ZREING_DOCFLOW_C' )->clear( ).
    sql_env->insert_test_data( flows ).
    warm( ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
  ENDMETHOD.
  METHOD contract_intra_int.
    given( iv_flow = 'I' iv_recv = 'EBA' ).
    contract_flow( iv_doc = 'INT' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-doc_type_code exp = 'INT' ).
    LOOP AT result-documents[ 1 ]-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-kostl exp = 'CTCECO1234' ).
    ENDLOOP.
  ENDMETHOD.
  METHOD contract_recl_own_rule.
    given( iv_flow = 'Z' ).
    contract_flow( iv_doc = 'ZZZ' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 2 ]-items[ role_code = 'TH' ]-kostl exp = '4591222999' ).
    LOOP AT result-documents[ 3 ]-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-kostl exp = 'CTCECO1234' ).
    ENDLOOP.
  ENDMETHOD.
  METHOD contract_storno_original.
    given( iv_flow = 'R' ).
    contract_flow( iv_rule = 'R' iv_kostl = space ).
    given_original( ).
    DATA(result) = process( 'S' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_initial( poster->calls ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->reverses ) exp = 1 ).
    assert_original( ).
  ENDMETHOD.

  METHOD map_flow.
    DATA(flows) = zcl_reing_contab_engine=>gt_flow_all.
    ASSIGN flows[ doc_type_code = iv_doc ] TO FIELD-SYMBOL(<flow>).
    <flow>-kostl_rule = 'Z'.
    <flow>-bukrs_rule = iv_rule.
    <flow>-bukrs_override = 'OVR'.
    sql_env->get_double( 'ZREING_DOCFLOW_C' )->clear( ).
    sql_env->insert_test_data( flows ).
    DATA maps TYPE STANDARD TABLE OF zreing_cmp_map_c WITH EMPTY KEY.
    IF it_map IS SUPPLIED.
      maps = CORRESPONDING #( it_map ).
    ELSE.
      maps = VALUE #( ( campana_de = '459' matnr = line-matnr campana_para = '777' )
        ( campana_de = '123' matnr = line-matnr campana_para = '888' ) ).
    ENDIF.
    sql_env->get_double( 'ZREING_CMP_MAP_C' )->clear( ).
    IF maps IS NOT INITIAL.
      sql_env->insert_test_data( maps ).
    ENDIF.
    DATA materials TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    materials = VALUE #( ( ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid
      matnr = line-matnr kostl = 'CONTRACT01' prctr = iv_prctr ) ).
    sql_env->get_double( 'ZREING_CT2_MAT_A' )->clear( ).
    sql_env->insert_test_data( materials ).
    warm( ).
  ENDMETHOD.
  METHOD map_flow_success.
    given( iv_flow = 'Z' ).
    map_flow( ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 3 ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 ).
    assert_document( is_result = result iv_index = 2 iv_type = 'AP' iv_total = 150 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 3 ]-bukrs exp = 'OVR' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 3 ]-total_amount
      exp = CONV zreing_cb_total_amount( 25 ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents[ 3 ]-items ) exp = 4 ).
    LOOP AT result-documents[ 3 ]-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-waers exp = 'USD' ).
      IF item-campana = '459'.
        cl_abap_unit_assert=>assert_equals( act = item-kostl exp = '7771333999' ).
        cl_abap_unit_assert=>assert_equals( act = abs( item-amount ) exp = CONV zreing_ca_calc_amt( 15 ) ).
      ELSE.
        cl_abap_unit_assert=>assert_equals( act = item-campana exp = '123' ).
        cl_abap_unit_assert=>assert_equals( act = item-kostl exp = '8883333999' ).
        cl_abap_unit_assert=>assert_equals( act = abs( item-amount ) exp = CONV zreing_ca_calc_amt( 10 ) ).
      ENDIF.
    ENDLOOP.
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD map_late_error.
    given( iv_flow = 'Z' ).
    map_flow( it_map = VALUE #( ) ).
    line-line_status = zif_reing_ca_c=>line_status-post_proc.
    DATA(result) = process( 'P' ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '008'
      WITH 'ZZZ' '459' line-matnr INTO DATA(expected).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 3 ).
    cl_abap_unit_assert=>assert_false( result-documents[ 1 ]-has_error ).
    cl_abap_unit_assert=>assert_false( result-documents[ 2 ]-has_error ).
    cl_abap_unit_assert=>assert_true( result-documents[ 3 ]-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_doc_pending ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( poster->reverses ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD map_empty_target.
    given( iv_flow = 'Z' ).
    map_flow( it_map = VALUE #( ( campana_de = '459' matnr = line-matnr ) ) ).
    DATA(result) = process( ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '009'
      WITH 'ZZZ' '459' line-matnr INTO DATA(expected).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 2 ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD map_bad_company.
    given( iv_flow = 'Z' ).
    map_flow( iv_rule = 'R' ).
    DATA(result) = process( ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '007'
      WITH 'ZZZ' INTO DATA(expected).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 2 ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD map_cache_exact.
    given( iv_flow = 'Z' ).
    map_flow( it_map = VALUE #( ( campana_de = '459' matnr = line-matnr campana_para = '777' )
      ( campana_de = '123' matnr = line-matnr campana_para = '888' )
      ( campana_de = '459' matnr = 'OTHER' campana_para = '999' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_campana_map ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_campana_map[
      campana_de = '459' matnr = line-matnr ]-campana_para exp = '777' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_campana_map[
      campana_de = '123' matnr = line-matnr ]-campana_para exp = '888' ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists(
      zcl_reing_contab_engine=>gt_campana_map[ campana_de = '459' matnr = 'OTHER' ] ) ) ).
  ENDMETHOD.
  METHOD map_cache_reset.
    given( iv_flow = 'Z' ).
    map_flow( ).
    cl_abap_unit_assert=>assert_not_initial( zcl_reing_contab_engine=>gt_campana_map ).
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_campana_map ).
    warm( ).
    DATA(flows) = zcl_reing_contab_engine=>gt_flow_all.
    flows[ doc_type_code = 'ZZZ' ]-kostl_rule = space.
    sql_env->get_double( 'ZREING_DOCFLOW_C' )->clear( ).
    sql_env->insert_test_data( flows ).
    warm( ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_campana_map ).
  ENDMETHOD.
  METHOD map_scope_materials.
    given( iv_flow = 'Z' ).
    map_flow( it_map = VALUE #( ( campana_de = '459' matnr = line-matnr campana_para = '777' )
      ( campana_de = '123' matnr = line-matnr campana_para = '888' )
      ( campana_de = '459' matnr = 'SECOND' campana_para = '999' )
      ( campana_de = '459' matnr = 'OUTSIDE' campana_para = '555' ) ) ).
    DATA(second) = line.
    second-matnr = 'SECOND'.
    second-line_num = 2.
    zcl_reing_contab_engine=>warm_config( VALUE #( ( line ) ( second ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_campana_map ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_contab_engine=>gt_campana_map[
      campana_de = '459' matnr = second-matnr ]-campana_para exp = '999' ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists(
      zcl_reing_contab_engine=>gt_campana_map[ campana_de = '459' matnr = 'OUTSIDE' ] ) ) ).
  ENDMETHOD.
  METHOD map_intra_int.
    given( iv_flow = 'I' iv_recv = 'EBA' ).
    map_flow( iv_doc = 'INT' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-doc_type_code exp = 'INT' ).
    LOOP AT result-documents[ 1 ]-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-kostl
        exp = COND kostl( WHEN item-campana = '459' THEN '7771333999' ELSE '8883333123' ) ).
    ENDLOOP.
  ENDMETHOD.
  METHOD map_zero_recl_skips.
    given( iv_flow = 'Z' iv_tax = 0 ).
    map_flow( iv_rule = 'R' it_map = VALUE #( ) ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    assert_db_unchanged( ).
  ENDMETHOD.
  METHOD map_storno_original.
    given( iv_flow = 'R' ).
    map_flow( iv_doc = 'AR' iv_rule = 'P' it_map = VALUE #( ) ).
    given_original( ).
    DATA(result) = process( 'S' ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_initial( poster->calls ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->reverses ) exp = 1 ).
    assert_original( ).
  ENDMETHOD.
  METHOD map_contract_pc_cache.
    given( iv_flow = 'Z' ). map_flow( ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists(
      zcl_reing_contab_engine=>gt_flow_all[ kostl_rule = 'C' ] ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_contract_kostl ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_contab_engine=>gt_contract_kostl[ ct_uuid = c_ct mat_uuid = c_mat ]-prctr exp = '999' ).
  ENDMETHOD.
  METHOD map_contract_pc_missing.
    given( iv_flow = 'Z' ). map_flow( iv_prctr = space ).
    DATA(result) = process( ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '012' WITH line-ct_id line-matnr 'ZZZ' INTO DATA(expected).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( zcl_reing_contab_engine=>gt_doc_pending ) exp = 2 ).
  ENDMETHOD.
  METHOD map_contract_pc_identity.
    given( iv_flow = 'Z' ). map_flow( ).
    DATA materials TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    materials = VALUE #( ( ct_uuid = c_ct_b mat_uuid = c_mat matnr = line-matnr prctr = '250' )
      ( ct_uuid = c_ct mat_uuid = c_mat_b matnr = line-matnr prctr = '630' ) ).
    sql_env->get_double( 'ZREING_CT2_MAT_A' )->clear( ).
    sql_env->insert_test_data( materials ). warm( ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( poster->calls ) exp = 2 ).
  ENDMETHOD.
  METHOD map_contract_pc_refresh.
    given( iv_flow = 'Z' ). map_flow( ).
    cl_abap_unit_assert=>assert_not_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
    sql_env->clear_doubles( ).
    given( iv_flow = 'Z' ). map_flow( ).
    sql_env->get_double( 'ZREING_DOCFLOW_C' )->clear( ). warm( ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_contract_kostl ).
  ENDMETHOD.
  METHOD map_contract_pc_alt.
    given( iv_flow = 'Z' ). map_flow( iv_prctr = '250' ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    assert_document( is_result = result iv_index = 1 iv_type = 'AR' iv_total = 100 ).
    assert_document( is_result = result iv_index = 2 iv_type = 'AP' iv_total = 150 ).
    LOOP AT result-documents[ 3 ]-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-prctr exp = '0000000250' ).
      cl_abap_unit_assert=>assert_equals( act = item-kostl+7(3) exp = '250' ).
    ENDLOOP.
  ENDMETHOD.
  METHOD bypass_on_document_flow.
    zcl_reing_contab_engine=>gv_test_eba_off = abap_false.
    given( ).
    DATA(result) = process( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-documents ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-waers exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 2 ]-waers exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = result-documents[ 1 ]-total_amount exp = 500 ).
  ENDMETHOD.
  METHOD bypass_action_snapshot.
    zcl_reing_contab_engine=>gv_test_eba_off = abap_false.
    given( ).
    TEST-INJECTION cb01_projection_guard.
      lv_eba_off = mv_eba_off.
    END-TEST-INJECTION.
    zcl_reing_contab_engine=>gv_test_eba_off = abap_true.
    DATA(first) = process( ).
    cl_abap_unit_assert=>assert_false( first-has_error ).
    cl_abap_unit_assert=>assert_equals( act = first-documents[ 1 ]-waers exp = 'BRL' ).
    warm( ).
    DATA(second) = process( ).
    cl_abap_unit_assert=>assert_false( second-has_error ).
    cl_abap_unit_assert=>assert_equals( act = second-documents[ 1 ]-waers exp = 'USD' ).
  ENDMETHOD.
  METHOD bypass_empty_scope_resets.
    zcl_reing_contab_engine=>gv_test_eba_off = abap_false.
    given( ).
    cl_abap_unit_assert=>assert_false( zcl_reing_contab_engine=>gv_eba_off ).
    zcl_reing_contab_engine=>warm_config( VALUE #( ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_contab_engine=>gv_eba_off ).
    cl_abap_unit_assert=>assert_initial( zcl_reing_contab_engine=>gt_trans_currencies ).
  ENDMETHOD.
ENDCLASS.
