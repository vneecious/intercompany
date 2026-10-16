*"* use this source file for your ABAP unit test classes
CLASS ltd_sources_cm DEFINITION FOR TESTING FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_sources.

    DATA mv_amount     TYPE zreing_cm_h_a-amount.
    DATA mv_raise_cm   TYPE abap_bool.
    DATA mv_exch_type  TYPE zreing_exrt_type.

ENDCLASS.

CLASS ltd_sources_cm IMPLEMENTATION.

  METHOD zif_reing_ca_sources~get_cm_amount.
    IF mv_raise_cm = abap_true.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = 'no CM (test double)'.
    ENDIF.
    rs_cm-amount = mv_amount.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_ct_option.
    rs_opt-exch_rate_type = mv_exch_type.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_me_shares.
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

CLASS ltc_optype_cm DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.

  PRIVATE SECTION.
    DATA mo_sources TYPE REF TO ltd_sources_cm.
    DATA ms_context TYPE zif_reing_ca_types=>ty_context.

    METHODS setup.
    METHODS load_base_reads_cm_amount FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS load_base_propagates_error FOR TESTING.
    METHODS is_credit_note_true_for_nc FOR TESTING.
    METHODS is_credit_note_false_otherwise FOR TESTING.
    METHODS fx_rate_type_from_ct_option FOR TESTING.
    METHODS fx_rate_typ_falls_back_catalog FOR TESTING.
    METHODS expand_mode_is_b1 FOR TESTING.

ENDCLASS.

CLASS ltc_optype_cm IMPLEMENTATION.

  METHOD setup.
    mo_sources = NEW ltd_sources_cm( ).
    ms_context = VALUE #( calc_run_id = 'RUN0001' period = '06' year = '2026' ).
  ENDMETHOD.

  METHOD load_base_reads_cm_amount.
    mo_sources->mv_amount = '1000.00'.
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    DATA(lv_result) = lo_cut->zif_reing_ca_optype~load_base( VALUE zreing_ca_line_a( op_type = 'F' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_result exp = '1000.00' ).
  ENDMETHOD.

  METHOD load_base_propagates_error.
    mo_sources->mv_raise_cm = abap_true.
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    TRY.
        lo_cut->zif_reing_ca_optype~load_base( VALUE zreing_ca_line_a( op_type = 'F' ) ).
        cl_abap_unit_assert=>fail( 'expected zcx_reing_ca_calc_error' ).
      CATCH zcx_reing_ca_calc_error.
        " expected
    ENDTRY.
  ENDMETHOD.

  METHOD is_credit_note_true_for_nc.
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    cl_abap_unit_assert=>assert_true(
      lo_cut->zif_reing_ca_optype~is_credit_note( VALUE zreing_ca_line_a( op_type = 'NC' ) ) ).
  ENDMETHOD.

  METHOD is_credit_note_false_otherwise.
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    cl_abap_unit_assert=>assert_false(
      lo_cut->zif_reing_ca_optype~is_credit_note( VALUE zreing_ca_line_a( op_type = 'F' ) ) ).
  ENDMETHOD.

  METHOD fx_rate_type_from_ct_option.
    mo_sources->mv_exch_type = 'P'.
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    DATA(lv_type) = lo_cut->zif_reing_ca_optype~fx_rate_type( VALUE zreing_ca_line_a( op_uuid = '4F503100000000000000000000000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_type exp = 'P' ).
  ENDMETHOD.

  METHOD fx_rate_typ_falls_back_catalog.
    " No ZREING_OP_TYPE_C row is inserted for a bogus op_type in this test
    " double — expected to resolve blank when neither CT2_OPT_A nor the
    " catalog default has a value (verifies the method does not fail).
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    DATA(lv_type) = lo_cut->zif_reing_ca_optype~fx_rate_type( VALUE zreing_ca_line_a( op_type = 'ZZZ' op_uuid = '4F503100000000000000000000000000' ) ).
    cl_abap_unit_assert=>assert_initial( lv_type ).
  ENDMETHOD.

  METHOD expand_mode_is_b1.
    DATA(lo_cut) = NEW zcl_reing_ca_optype_cm( io_sources = mo_sources is_context = ms_context ).
    DATA(lv_mode) = lo_cut->zif_reing_ca_optype~expand_mode( VALUE zreing_ca_line_a( ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_mode exp = zif_reing_ca_c=>row_type-cm_pending ).
  ENDMETHOD.

ENDCLASS.
