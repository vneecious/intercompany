*"* fixes-048 - Interdivisional applicability tests
CLASS lcl_testable_contab_int DEFINITION
  INHERITING FROM zcl_reing_contab_doc_int.

  PUBLIC SECTION.
    METHODS set_line
      IMPORTING iv_bukrs_prest TYPE bukrs
                iv_bukrs_recv  TYPE bukrs
                iv_bruto_amt   TYPE zreing_ca_line_a-bruto_amt.
    METHODS add_pc_amount
      IMPORTING iv_bruto_amt TYPE zreing_ca_lpc_a-bruto_amt.
    METHODS set_nominal IMPORTING iv_first TYPE zreing_ca_calc_amt iv_second TYPE zreing_ca_calc_amt.
ENDCLASS.

CLASS lcl_testable_contab_int IMPLEMENTATION.
  METHOD set_line.
    ms_line_a = VALUE #(
      bukrs_prest = iv_bukrs_prest
      bukrs_recv  = iv_bukrs_recv
      bruto_amt   = iv_bruto_amt ).
    CLEAR mt_line_pc.
  ENDMETHOD.

  METHOD add_pc_amount.
    APPEND VALUE #( bruto_amt = iv_bruto_amt ) TO mt_line_pc.
  ENDMETHOD.
  METHOD set_nominal.
    mv_use_trans = abap_true.
    ms_trans_projection = VALUE #( line_pc = VALUE #(
      ( calc_run_id = 'UT-INT' line_num = 1 pc_seq = 1 bruto_trans_amt = iv_first )
      ( calc_run_id = 'UT-INT' line_num = 1 pc_seq = 2 bruto_trans_amt = iv_second ) ) ).
    mt_role_master = VALUE #( ( gl_role = 'RGL' posting_context = 'GL' ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltc_contab_doc_int DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO lcl_testable_contab_int.

    METHODS setup.
    METHODS same_company_with_amount FOR TESTING.
    METHODS different_company_skips  FOR TESTING.
    METHODS same_company_zero_skips  FOR TESTING.
    METHODS zero_header_with_pc_runs  FOR TESTING.
    METHODS nominal_zero_skips FOR TESTING RAISING cx_static_check.
    METHODS nominal_compensated_runs FOR TESTING RAISING cx_static_check.
    METHODS nominal_intercompany_skips FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_contab_doc_int IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW lcl_testable_contab_int( ).
  ENDMETHOD.

  METHOD same_company_with_amount.
    mo_cut->set_line( iv_bukrs_prest = 'MUR'
                      iv_bukrs_recv  = 'MUR'
                      iv_bruto_amt   = 100 ).

    cl_abap_unit_assert=>assert_true(
      act = mo_cut->zif_reing_contab~is_applicable( )
      msg = 'A non-zero intra-company line must generate INT' ).
  ENDMETHOD.

  METHOD different_company_skips.
    mo_cut->set_line( iv_bukrs_prest = 'MUR'
                      iv_bukrs_recv  = 'DRU'
                      iv_bruto_amt   = 100 ).

    cl_abap_unit_assert=>assert_false(
      act = mo_cut->zif_reing_contab~is_applicable( )
      msg = 'An intercompany line must not generate INT' ).
  ENDMETHOD.

  METHOD same_company_zero_skips.
    mo_cut->set_line( iv_bukrs_prest = 'MUR'
                      iv_bukrs_recv  = 'MUR'
                      iv_bruto_amt   = 0 ).

    cl_abap_unit_assert=>assert_false(
      act = mo_cut->zif_reing_contab~is_applicable( )
      msg = 'A fully zero intra-company line must not call FI' ).
  ENDMETHOD.

  METHOD zero_header_with_pc_runs.
    mo_cut->set_line( iv_bukrs_prest = 'MUR'
                      iv_bukrs_recv  = 'MUR'
                      iv_bruto_amt   = 0 ).
    mo_cut->add_pc_amount( 100 ).

    cl_abap_unit_assert=>assert_true(
      act = mo_cut->zif_reing_contab~is_applicable( )
      msg = 'A zero header with a non-zero breakdown must generate INT' ).
  ENDMETHOD.
  METHOD nominal_zero_skips.
mo_cut->set_line( iv_bukrs_prest = 'EBA' iv_bukrs_recv = 'EBA' iv_bruto_amt = 100 ).
    mo_cut->set_nominal( iv_first = 0 iv_second = 0 ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
  ENDMETHOD.

  METHOD nominal_compensated_runs.
mo_cut->set_line( iv_bukrs_prest = 'EBA' iv_bukrs_recv = 'EBA' iv_bruto_amt = 0 ).
    mo_cut->set_nominal( iv_first = 50 iv_second = -50 ).
    cl_abap_unit_assert=>assert_true( mo_cut->zif_reing_contab~is_applicable( ) ).
  ENDMETHOD.

  METHOD nominal_intercompany_skips.
mo_cut->set_line( iv_bukrs_prest = 'EBA' iv_bukrs_recv = 'MUR' iv_bruto_amt = 100 ).
    mo_cut->set_nominal( iv_first = 50 iv_second = 50 ).
    cl_abap_unit_assert=>assert_false( mo_cut->zif_reing_contab~is_applicable( ) ).
  ENDMETHOD.

ENDCLASS.
