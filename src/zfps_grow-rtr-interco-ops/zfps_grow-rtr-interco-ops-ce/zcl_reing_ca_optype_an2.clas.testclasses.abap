*"* use this source file for your ABAP unit test classes
CLASS ltc_optype_an2 DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_reing_ca_optype_an2.

    METHODS setup.
    METHODS load_base_copies_parent_1to1 FOR TESTING.
    METHODS is_credit_note_always_false FOR TESTING.
    METHODS fx_rate_type_is_p FOR TESTING.
    METHODS expand_mode_is_b2 FOR TESTING.

ENDCLASS.

CLASS ltc_optype_an2 IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_reing_ca_optype_an2( ).
  ENDMETHOD.

  METHOD load_base_copies_parent_1to1.
    TRY.
        DATA(lv_result) = mo_cut->zif_reing_ca_optype~load_base( VALUE zreing_ca_line_a( parent_net_amt = '850.00' ) ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = '850.00' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx).
        cl_abap_unit_assert=>fail( lx->mv_message ).
    ENDTRY.
  ENDMETHOD.

  METHOD is_credit_note_always_false.
    cl_abap_unit_assert=>assert_false(
      mo_cut->zif_reing_ca_optype~is_credit_note( VALUE zreing_ca_line_a( op_type = 'AN2' ) ) ).
  ENDMETHOD.

  METHOD fx_rate_type_is_p.
    DATA(lv_type) = mo_cut->zif_reing_ca_optype~fx_rate_type( VALUE zreing_ca_line_a( ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_type exp = 'P' ).
  ENDMETHOD.

  METHOD expand_mode_is_b2.
    DATA(lv_mode) = mo_cut->zif_reing_ca_optype~expand_mode( VALUE zreing_ca_line_a( ) ).
    cl_abap_unit_assert=>assert_equals( act = lv_mode exp = zif_reing_ca_c=>row_type-defer_pending ).
  ENDMETHOD.

ENDCLASS.
