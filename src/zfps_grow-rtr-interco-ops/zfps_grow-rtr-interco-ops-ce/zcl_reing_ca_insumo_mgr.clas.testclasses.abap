*"* use this source file for your ABAP unit test classes
CLASS ltd_sources_insumo DEFINITION FOR TESTING FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_sources.
    DATA mt_me_shares TYPE zif_reing_ca_types=>ty_me_item_t.

ENDCLASS.

CLASS ltd_sources_insumo IMPLEMENTATION.
  METHOD zif_reing_ca_sources~get_cm_amount.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_me_shares.
    IF mt_me_shares IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = 'no shares (test double)'.
    ENDIF.
    rt_items = mt_me_shares.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_ct_option.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_gl_tax_types.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_tx_rules.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_manual_exch_rate.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_average_exch_rate.
  ENDMETHOD.
ENDCLASS.

CLASS ltc_insumo_mgr DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.
  PRIVATE SECTION.
    TYPES lty_run_a_tab TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.

    CONSTANTS:
      lc_ct_uuid  TYPE sysuuid_x16 VALUE '43545539000000000000000000000009',
      lc_mat_uuid TYPE sysuuid_x16 VALUE '4D545539000000000000000000000009',
      lc_op_uuid  TYPE sysuuid_x16 VALUE '4F505539000000000000000000000009'.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_sources TYPE REF TO ltd_sources_insumo.
    DATA ms_line    TYPE zreing_ca_line_a.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS is_orphan_true_when_cm_missing FOR TESTING.
    METHODS is_stale_wh_cm_chngd_aft_check FOR TESTING.
    METHODS not_stale_when_nothing_changed FOR TESTING.
    METHODS detects_added_removed_recptors FOR TESTING.
    " V001 (CC) - #105: safe usage closing over isolated SQL doubles.
    METHODS seed_reversal_usage.
    METHODS shared_usage_stays_reserved FOR TESTING.
    METHODS last_usage_releases_me FOR TESTING.
    METHODS failed_reversal_keeps_usage FOR TESTING.
    METHODS reverted_usage_is_idempotent FOR TESTING.
ENDCLASS.

CLASS ltc_insumo_mgr IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
               i_dependency_list = VALUE #( ( 'ZREING_CA_RUN_A' )
                 ( 'ZREING_CALCUSAGE' ) ( 'ZREING_CA_LINE_A' ) ( 'ZREING_ME_H_A' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    mo_sources = NEW ltd_sources_insumo( ).
    ms_line = VALUE zreing_ca_line_a(
                calc_run_id = 'RUN0009' ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid
                ct_id = 'CT0000001' matnr = 'MAT001' op_type = 'F' op_uuid = lc_op_uuid
                bukrs_recv = '1000' insumo_check_at = '20260601000000.0000000' ).
    go_env->insert_test_data( VALUE lty_run_a_tab(
      ( calc_run_id = 'RUN0009' fiscal_period = '06' fiscal_year = '2026' ) ) ).
  ENDMETHOD.

  METHOD teardown.
    go_env->clear_doubles( ).
  ENDMETHOD.

  METHOD is_orphan_true_when_cm_missing.
    DATA lt_orphan_ctx TYPE zcl_reing_ca_insumo_mgr=>tt_orphan_ctx.
    APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_orphan_ctx(
      ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid op_type = 'F'
      op_uuid = lc_op_uuid bukrs_recv = '1000' is_orphan = abap_true ) TO lt_orphan_ctx.

    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    DATA(rs_check) = lo_cut->check_consistency(
      it_group_lines   = VALUE #( ( ms_line ) )
      iv_fiscal_period = '06'
      iv_fiscal_year   = '2026'
      it_orphan_ctx    = lt_orphan_ctx ).

    cl_abap_unit_assert=>assert_true( rs_check-is_orphan ).
  ENDMETHOD.

  METHOD is_stale_wh_cm_chngd_aft_check.
    DATA lt_orphan_ctx TYPE zcl_reing_ca_insumo_mgr=>tt_orphan_ctx.
    APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_orphan_ctx(
      ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid op_type = 'F'
      op_uuid = lc_op_uuid bukrs_recv = '1000' is_orphan = abap_false ) TO lt_orphan_ctx.

    DATA lt_cm_changed TYPE zcl_reing_ca_insumo_mgr=>tt_cm_changed.
    APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_cm_changed(
      ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid op_type = 'F'
      changed_at = '20260615000000.0000000' ) TO lt_cm_changed.  " after check_at 20260601

    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    DATA(rs_check) = lo_cut->check_consistency(
      it_group_lines   = VALUE #( ( ms_line ) )
      iv_fiscal_period = '06'
      iv_fiscal_year   = '2026'
      it_orphan_ctx    = lt_orphan_ctx
      it_cm_changed    = lt_cm_changed ).

    cl_abap_unit_assert=>assert_true( rs_check-is_stale ).
  ENDMETHOD.

  METHOD not_stale_when_nothing_changed.
    DATA lt_orphan_ctx TYPE zcl_reing_ca_insumo_mgr=>tt_orphan_ctx.
    APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_orphan_ctx(
      ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid op_type = 'F'
      op_uuid = lc_op_uuid bukrs_recv = '1000' is_orphan = abap_false ) TO lt_orphan_ctx.

    DATA lt_cm_changed TYPE zcl_reing_ca_insumo_mgr=>tt_cm_changed.
    APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_cm_changed(
      ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid op_type = 'F'
      changed_at = '20260501000000.0000000' ) TO lt_cm_changed.  " before check_at 20260601

    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    DATA(rs_check) = lo_cut->check_consistency(
      it_group_lines   = VALUE #( ( ms_line ) )
      iv_fiscal_period = '06'
      iv_fiscal_year   = '2026'
      it_orphan_ctx    = lt_orphan_ctx
      it_cm_changed    = lt_cm_changed ).

    cl_abap_unit_assert=>assert_false( rs_check-is_stale ).
  ENDMETHOD.

  METHOD detects_added_removed_recptors.
    DATA lt_orphan_ctx TYPE zcl_reing_ca_insumo_mgr=>tt_orphan_ctx.
    APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_orphan_ctx(
      ct_uuid = lc_ct_uuid mat_uuid = lc_mat_uuid op_type = 'F'
      op_uuid = lc_op_uuid bukrs_recv = '1000' is_orphan = abap_false ) TO lt_orphan_ctx.

    mo_sources->mt_me_shares = VALUE #( ( bukrs = '1000' ) ( bukrs = '2000' ) ).
    DATA(lt_group) = VALUE zif_reing_ca_types=>ty_line_t(
      ( ms_line )
      ( VALUE zreing_ca_line_a( BASE ms_line bukrs_recv = '3000' ) ) ).

    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    DATA(rs_check) = lo_cut->check_consistency(
      it_group_lines   = lt_group
      iv_fiscal_period = '06'
      iv_fiscal_year   = '2026'
      it_orphan_ctx    = lt_orphan_ctx ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_check-added_receptors )   exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = rs_check-added_receptors[ 1 ]       exp = '2000' ).
    cl_abap_unit_assert=>assert_equals( act = lines( rs_check-removed_receptors ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = rs_check-removed_receptors[ 1 ]     exp = '3000' ).
  ENDMETHOD.

  METHOD seed_reversal_usage.
    DATA lt_lines TYPE zif_reing_ca_types=>ty_line_t.
    lt_lines = VALUE #(
      ( calc_run_id = 'RUN0009' line_num = '0000001' line_status = 'ANULD' )
      ( calc_run_id = 'RUN0010' line_num = '0000002' line_status = 'CONT' ) ).
    DATA lt_usage TYPE zcl_reing_ca_insumo_mgr=>ty_usage_t.
    lt_usage = VALUE #(
      ( usage_id = 'USG-105-ME-1' calc_run_id = 'RUN0009' line_num = '0000001'
        insumo_type = 'ME' me_h_id = lc_ct_uuid )
      ( usage_id = 'USG-105-ME-2' calc_run_id = 'RUN0010' line_num = '0000002'
        insumo_type = 'ME' me_h_id = lc_ct_uuid )
      ( usage_id = 'USG-105-CM-1' calc_run_id = 'RUN0009' line_num = '0000001'
        insumo_type = 'CM' cm_h_id = 'CM-HISTORY-105' cm_load_seq = '001' ) ).
    DATA lt_me TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
    lt_me = VALUE #( ( me_h_id = lc_ct_uuid me_status = 'LIBR' ) ).
    go_env->insert_test_data( lt_lines ).
    go_env->insert_test_data( lt_usage ).
    go_env->insert_test_data( lt_me ).
  ENDMETHOD.

  METHOD shared_usage_stays_reserved.
    seed_reversal_usage( ).
    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    lo_cut->revert_usage( iv_calc_run_id = 'RUN0009' iv_line_num = '0000001' ).
    SELECT SINGLE libr_rev_at FROM zreing_calcusage
      WHERE usage_id = 'USG-105-ME-1' INTO @DATA(lv_closed).
    cl_abap_unit_assert=>assert_not_initial( lv_closed ).
    SELECT SINGLE libr_rev_at FROM zreing_calcusage
      WHERE usage_id = 'USG-105-ME-2' INTO @DATA(lv_open).
    cl_abap_unit_assert=>assert_initial( lv_open ).
    SELECT SINGLE me_status FROM zreing_me_h_a
      WHERE me_h_id = @lc_ct_uuid INTO @DATA(lv_status).
    cl_abap_unit_assert=>assert_equals( act = lv_status exp = 'LIBR' ).
    SELECT COUNT( * ) FROM zreing_calcusage
      WHERE calc_run_id = 'RUN0009' OR calc_run_id = 'RUN0010'
      INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 3 ).
    SELECT SINGLE cm_h_id, cm_load_seq, libr_rev_at FROM zreing_calcusage
      WHERE usage_id = 'USG-105-CM-1' INTO @DATA(ls_cm_history).
    cl_abap_unit_assert=>assert_equals( act = ls_cm_history-cm_h_id exp = 'CM-HISTORY-105' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cm_history-cm_load_seq exp = '001' ).
    cl_abap_unit_assert=>assert_not_initial( ls_cm_history-libr_rev_at ).
  ENDMETHOD.

  METHOD last_usage_releases_me.
    seed_reversal_usage( ).
    UPDATE zreing_ca_line_a SET line_status = 'ANULD'
      WHERE calc_run_id = 'RUN0010' AND line_num = '0000002'.
    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    lo_cut->revert_usage_bulk( VALUE #(
      ( calc_run_id = 'RUN0009' line_num = '0000001' line_status = 'ANULD' )
      ( calc_run_id = 'RUN0010' line_num = '0000002' line_status = 'ANULD' ) ) ).
    SELECT SINGLE me_status FROM zreing_me_h_a
      WHERE me_h_id = @lc_ct_uuid INTO @DATA(lv_status).
    cl_abap_unit_assert=>assert_equals( act = lv_status exp = 'LIBD' ).
    SELECT COUNT( * ) FROM zreing_calcusage WHERE libr_rev_at IS INITIAL
      INTO @DATA(lv_open).
    cl_abap_unit_assert=>assert_equals( act = lv_open exp = 0 ).
  ENDMETHOD.

  METHOD failed_reversal_keeps_usage.
    seed_reversal_usage( ).
    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    " Input cannot release a line that still remains CONT in the stored image.
    lo_cut->revert_usage_bulk( VALUE #(
      ( calc_run_id = 'RUN0010' line_num = '0000002' line_status = 'ANULD' ) ) ).
    SELECT SINGLE libr_rev_at FROM zreing_calcusage
      WHERE usage_id = 'USG-105-ME-2' INTO @DATA(lv_closed).
    cl_abap_unit_assert=>assert_initial( lv_closed ).
    SELECT SINGLE me_status FROM zreing_me_h_a
      WHERE me_h_id = @lc_ct_uuid INTO @DATA(lv_status).
    cl_abap_unit_assert=>assert_equals( act = lv_status exp = 'LIBR' ).
  ENDMETHOD.

  METHOD reverted_usage_is_idempotent.
    seed_reversal_usage( ).
    DATA(lo_cut) = NEW zcl_reing_ca_insumo_mgr( io_sources = mo_sources ).
    lo_cut->revert_usage( iv_calc_run_id = 'RUN0009' iv_line_num = '0000001' ).
    SELECT SINGLE libr_rev_at FROM zreing_calcusage
      WHERE usage_id = 'USG-105-ME-1' INTO @DATA(lv_first).
    lo_cut->revert_usage( iv_calc_run_id = 'RUN0009' iv_line_num = '0000001' ).
    SELECT SINGLE libr_rev_at FROM zreing_calcusage
      WHERE usage_id = 'USG-105-ME-1' INTO @DATA(lv_second).
    cl_abap_unit_assert=>assert_equals( act = lv_second exp = lv_first ).
    cl_abap_unit_assert=>assert_not_initial( lv_second ).
  ENDMETHOD.

ENDCLASS.
