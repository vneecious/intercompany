" V001 (CC) - Pure projection contract fixtures; no business data access.
CLASS ltcl_trans_amounts DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA ms_line TYPE zreing_ca_line_a.
    DATA mt_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_steps TYPE zif_reing_ca_types=>ty_step_t.
    DATA mt_currencies TYPE zif_reing_ca_types=>tt_currency_precision.
    METHODS setup.
    METHODS project RETURNING VALUE(rs_result) TYPE zif_reing_ca_types=>ty_trans_projection
      RAISING zcx_reing_ca_calc_error.
    METHODS expect_error.
    METHODS make_unavailable.
    METHODS set_primary_target.
    METHODS enable_matrix FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS off_snapshot FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS non_eba_snapshot FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS historical_marker_absent FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS normal_targets FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS ct_fields_preserved FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS same_currency_copy FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS residue_last_sequence FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS sequence_order FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS single_zero_share FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS zero_share_real_amount FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS delta_signed_weights FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS delta_compensated_calc FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS step_units_once FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS negative_tax_preserved FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS local_unavailable FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS zero_local_available FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS local_precision_degrades FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS local_missing_metadata FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS zero_currency_decimals FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS third_decimal_rejects FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS missing_trans_precision FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS precision_range_rejects FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS negative_precision_rejects FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS missing_breakdown FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS wrong_pc_key FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS duplicate_pc_key FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS wrong_ct_sum FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS wrong_pc_currency FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS wrong_step_key FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS duplicate_local_marker FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS missing_primary_marker FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS contradictory_local FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS wrong_primary_rate FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS zero_primary_rate FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS bad_marker_category FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS incompatible_step_currency FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS unknown_monetary_category FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS control_zero_output FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS calc_error_not_available FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS caller_processing_allowed FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS repeated_call_no_mutation FOR TESTING RAISING zcx_reing_ca_calc_error.
ENDCLASS.

CLASS ltcl_trans_amounts IMPLEMENTATION.
  METHOD setup.
    ms_line = VALUE #( calc_run_id = 'UT-TRANS' line_num = 1 bukrs_prest = 'EBA'
      ct_currency = 'USD' trans_currency = 'BRL' local_currency = 'BRL'
      calc_amt = 100 bruto_amt = 125 tax_amt = 25 net_amt = 100
      net_trans_amt = 500 net_local_amt = 500 exch_rate_1 = 5 exch_rate = 1
      share_pct = 100 line_status = zif_reing_ca_c=>line_status-calc ).
    mt_pc = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 1
        prctr = '0000000001' campana = 'ABC' role_category = 'C' allocation = '0'
        ct_currency = 'USD' local_currency = 'BRL' share_abs = 60
        calc_amt = 60 bruto_amt = 75 tax_amt = 15 net_amt = 60 net_local_amt = 300 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 2
        prctr = '0000000002' campana = 'XYZ' role_category = 'E' allocation = '1'
        ct_currency = 'USD' local_currency = 'BRL' share_abs = 40
        calc_amt = 40 bruto_amt = 50 tax_amt = 10 net_amt = 40 net_local_amt = 200 ) ).
    mt_steps = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '01' seq = '01'
        step_category = zif_reing_ca_c=>step_category-validate output_amt = 100 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '03' seq = '01'
        step_category = zif_reing_ca_c=>step_category-gross_up output_amt = 125 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '04' seq = '01'
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'T1' output_amt = 25 sign = '+' )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '04' seq = '02'
        step_category = zif_reing_ca_c=>step_category-net output_amt = 100 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '01'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 100 input_currency = 'USD'
        output_amt = 500 output_currency = 'BRL' rate_pct = 5 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '02'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 500 input_currency = 'BRL'
        output_amt = 500 output_currency = 'BRL' rate_pct = 1 ) ).
    mt_currencies = VALUE #( ( currency = 'USD' decimals = 2 )
      ( currency = 'BRL' decimals = 2 ) ( currency = 'JPY' decimals = 0 )
      ( currency = 'KWD' decimals = 3 ) ).
  ENDMETHOD.

  METHOD project.
    rs_result = zcl_reing_ca_trans_amounts=>project_line(
      is_line = ms_line it_line_pc = mt_pc it_steps = mt_steps
      it_currencies = mt_currencies iv_eba_off = abap_false ).
  ENDMETHOD.

  METHOD expect_error.
    TRY.
        DATA(ls_result) = project( ).
        cl_abap_unit_assert=>fail( ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->mv_message ).
    ENDTRY.
  ENDMETHOD.

  METHOD make_unavailable.
    CLEAR: ms_line-net_local_amt, ms_line-exch_rate.
    ASSIGN mt_steps[ step_num = '05' seq = '02' ] TO FIELD-SYMBOL(<local>).
    CLEAR: <local>-output_amt, <local>-output_currency, <local>-rate_pct.
  ENDMETHOD.

  METHOD set_primary_target.
    ASSIGN mt_steps[ step_num = '05' seq = '01' ] TO FIELD-SYMBOL(<primary>).
    <primary>-input_currency = ms_line-ct_currency.
    <primary>-input_amt = ms_line-net_amt.
    <primary>-output_currency = ms_line-trans_currency.
    <primary>-output_amt = ms_line-net_trans_amt.
    <primary>-rate_pct = ms_line-exch_rate_1.
    ASSIGN mt_steps[ step_num = '05' seq = '02' ] TO FIELD-SYMBOL(<local>).
    <local>-input_currency = ms_line-trans_currency.
    <local>-input_amt = ms_line-net_trans_amt.
    <local>-output_currency = ms_line-local_currency.
    <local>-output_amt = ms_line-net_local_amt.
    <local>-rate_pct = ms_line-exch_rate.
  ENDMETHOD.

  METHOD enable_matrix.
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = 'EBA' iv_eba_off = abap_false ) ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = 'EBA' iv_eba_off = abap_true ) ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = 'MUR' iv_eba_off = abap_false ) ).
  ENDMETHOD.

  METHOD off_snapshot.
    DATA(ls_result) = zcl_reing_ca_trans_amounts=>project_line(
      is_line = ms_line it_line_pc = mt_pc it_steps = mt_steps
      it_currencies = mt_currencies iv_eba_off = abap_true ).
    cl_abap_unit_assert=>assert_false( ls_result-use_trans ).
    cl_abap_unit_assert=>assert_equals( exp = ms_line act = ls_result-line ).
    cl_abap_unit_assert=>assert_equals( exp = mt_steps act = ls_result-steps ).
    DATA(lt_original) = CORRESPONDING zif_reing_ca_types=>ty_line_pc_t( ls_result-line_pc ).
    cl_abap_unit_assert=>assert_equals( exp = mt_pc act = lt_original ).
  ENDMETHOD.

  METHOD non_eba_snapshot.
    ms_line-bukrs_prest = 'MUR'.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_false( ls_result-use_trans ).
    cl_abap_unit_assert=>assert_equals( exp = ms_line act = ls_result-line ).
  ENDMETHOD.

  METHOD historical_marker_absent.
    DELETE mt_steps WHERE step_num = '05' AND seq = '02'.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_false( ls_result-use_trans ).
    cl_abap_unit_assert=>assert_equals( exp = mt_steps act = ls_result-steps ).
  ENDMETHOD.

  METHOD normal_targets.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_true( ls_result-use_trans ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 625 act = ls_result-bruto_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 300 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 200 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 375 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-bruto_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 250 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-bruto_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 300 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-net_trans_amt ).
  ENDMETHOD.

  METHOD ct_fields_preserved.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 60 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 75 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-bruto_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 15 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-tax_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 'ABC' act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-campana ).
    cl_abap_unit_assert=>assert_equals( exp = '0' act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-allocation ).
    cl_abap_unit_assert=>assert_equals( exp = 60 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-share_abs ).
  ENDMETHOD.

  METHOD same_currency_copy.
    ms_line-trans_currency = 'USD'. ms_line-local_currency = 'USD'.
    ms_line-exch_rate_1 = 1. ms_line-net_trans_amt = 100. ms_line-net_local_amt = 100.
    set_primary_target( ).
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 100 act = ls_result-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 60 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 75 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-bruto_trans_amt ).
  ENDMETHOD.

  METHOD residue_last_sequence.
    mt_pc[ 1 ]-share_abs = '33.333333'. mt_pc[ 2 ]-share_abs = '66.666667'.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = '166.67' act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = '333.33' act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = '208.33' act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-bruto_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = '416.67' act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-bruto_trans_amt ).
  ENDMETHOD.

  METHOD sequence_order.
    mt_pc[ 1 ]-pc_seq = 9. mt_pc[ 2 ]-pc_seq = 1.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = ls_result-line_pc[ 1 ]-pc_seq ).
    cl_abap_unit_assert=>assert_equals( exp = 9 act = ls_result-line_pc[ 2 ]-pc_seq ).
  ENDMETHOD.

  METHOD single_zero_share.
    mt_pc = VALUE #( ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 1
      ct_currency = 'USD' calc_amt = 100 bruto_amt = 125 tax_amt = 25 net_amt = 100 ) ).
    ms_line-share_pct = 0.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-line_pc[ 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 625 act = ls_result-line_pc[ 1 ]-bruto_trans_amt ).
  ENDMETHOD.

  METHOD zero_share_real_amount.
    ms_line-share_pct = 0.
    expect_error( ).
  ENDMETHOD.

  METHOD delta_signed_weights.
    ms_line-is_delta = abap_true.
    mt_pc[ 1 ]-calc_amt = 120. mt_pc[ 2 ]-calc_amt = -20.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 600 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = -100 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 750 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-bruto_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = -125 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-bruto_trans_amt ).
  ENDMETHOD.

  METHOD delta_compensated_calc.
    ms_line-is_delta = abap_true.
    CLEAR: ms_line-calc_amt, ms_line-bruto_amt, ms_line-tax_amt, ms_line-net_amt,
      ms_line-net_trans_amt, ms_line-net_local_amt.
    mt_pc[ 1 ]-calc_amt = 40. mt_pc[ 2 ]-calc_amt = -40.
    mt_pc[ 1 ]-bruto_amt = 0. mt_pc[ 2 ]-bruto_amt = 0.
    mt_pc[ 1 ]-tax_amt = 0. mt_pc[ 2 ]-tax_amt = 0.
    mt_pc[ 1 ]-net_amt = 0. mt_pc[ 2 ]-net_amt = 0.
    set_primary_target( ).
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 200 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = -200 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-bruto_trans_amt ).
  ENDMETHOD.

  METHOD step_units_once.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 625 act = ls_result-steps[ step_num = '03' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 125 act = ls_result-steps[ step_num = '04' seq = '01' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-steps[ step_num = '05' seq = '01' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-steps[ step_num = '05' seq = '02' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-steps[ step_num = '05' seq = '02' ]-output_amt ).
  ENDMETHOD.

  METHOD negative_tax_preserved.
    mt_steps[ step_num = '04' seq = '01' ]-output_amt = -25.
    mt_steps[ step_num = '04' seq = '01' ]-sign = '-'.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = -125 act = ls_result-steps[ step_num = '04' seq = '01' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = '-' act = ls_result-steps[ step_num = '04' seq = '01' ]-sign ).
  ENDMETHOD.

  METHOD local_unavailable.
    make_unavailable( ).
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_true( ls_result-use_trans ).
    cl_abap_unit_assert=>assert_false( ls_result-local_available ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-steps[ step_num = '05' seq = '02' ]-output_trans_amt ).
  ENDMETHOD.

  METHOD zero_local_available.
    ms_line-is_delta = abap_true. ms_line-net_amt = 0.
    ms_line-net_trans_amt = 0. ms_line-net_local_amt = 0.
    mt_pc[ 1 ]-net_amt = 0. mt_pc[ 2 ]-net_amt = 0.
    set_primary_target( ).
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_true( ls_result-local_available ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-net_local_amt ).
  ENDMETHOD.

  METHOD local_precision_degrades.
    ms_line-local_currency = 'KWD'. ms_line-exch_rate = '1.00002'.
    ms_line-net_local_amt = '500.01'.
    mt_pc[ 1 ]-share_abs = 50. mt_pc[ 2 ]-share_abs = 50.
    set_primary_target( ).
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_true( ls_result-use_trans ).
    cl_abap_unit_assert=>assert_false( ls_result-local_available ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = ls_result-line-net_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-line-exch_rate ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_initial( ls_result-steps[ step_num = '05' seq = '02' ]-output_currency ).
    cl_abap_unit_assert=>assert_not_initial( ls_result-local_message ).
  ENDMETHOD.

  METHOD local_missing_metadata.
    ms_line-local_currency = 'USD'. set_primary_target( ).
    DELETE TABLE mt_currencies WITH TABLE KEY currency = 'USD'.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_false( ls_result-local_available ).
    cl_abap_unit_assert=>assert_equals( exp = 625 act = ls_result-bruto_trans_amt ).
  ENDMETHOD.

  METHOD zero_currency_decimals.
    ms_line-trans_currency = 'JPY'. ms_line-local_currency = 'USD'.
    ms_line-calc_amt = '1.01'. ms_line-bruto_amt = '1.01'. ms_line-tax_amt = 0.
    ms_line-net_amt = '1.01'. ms_line-net_trans_amt = 1. ms_line-net_local_amt = 1.
    ms_line-exch_rate_1 = '1.15'.
    mt_pc[ 1 ]-calc_amt = '0.61'. mt_pc[ 2 ]-calc_amt = '0.40'.
    mt_pc[ 1 ]-bruto_amt = '0.61'. mt_pc[ 2 ]-bruto_amt = '0.40'.
    mt_pc[ 1 ]-tax_amt = 0. mt_pc[ 2 ]-tax_amt = 0.
    mt_pc[ 1 ]-net_amt = '0.61'. mt_pc[ 2 ]-net_amt = '0.40'.
    DELETE mt_steps WHERE step_num <> '05'.
    set_primary_target( ).
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = ls_result-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 1 ]-calc_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-line_pc[ calc_run_id = ms_line-calc_run_id
      line_num = ms_line-line_num pc_seq = 2 ]-calc_trans_amt ).
  ENDMETHOD.

  METHOD third_decimal_rejects.
    ms_line-trans_currency = 'KWD'. ms_line-local_currency = 'USD'.
    ms_line-exch_rate_1 = '1.01'. ms_line-net_trans_amt = 101. ms_line-net_local_amt = 101.
    mt_pc[ 1 ]-share_abs = 50. mt_pc[ 2 ]-share_abs = 50.
    ms_line-calc_amt = 1. mt_pc[ 1 ]-calc_amt = '0.50'. mt_pc[ 2 ]-calc_amt = '0.50'.
    set_primary_target( ).
    expect_error( ).
  ENDMETHOD.

  METHOD missing_trans_precision.
    DELETE TABLE mt_currencies WITH TABLE KEY currency = 'BRL'.
    expect_error( ).
  ENDMETHOD.

  METHOD precision_range_rejects.
    mt_currencies[ currency = 'BRL' ]-decimals = 4.
    expect_error( ).
  ENDMETHOD.

  METHOD negative_precision_rejects.
    mt_currencies[ currency = 'BRL' ]-decimals = -1.
    expect_error( ).
  ENDMETHOD.

  METHOD missing_breakdown.
    CLEAR mt_pc. expect_error( ).
  ENDMETHOD.

  METHOD wrong_pc_key.
    mt_pc[ 1 ]-line_num = 2. expect_error( ).
  ENDMETHOD.

  METHOD duplicate_pc_key.
    APPEND mt_pc[ 1 ] TO mt_pc. expect_error( ).
  ENDMETHOD.

  METHOD wrong_ct_sum.
    mt_pc[ 1 ]-calc_amt = 61. expect_error( ).
  ENDMETHOD.

  METHOD wrong_pc_currency.
    mt_pc[ 1 ]-ct_currency = 'BRL'. expect_error( ).
  ENDMETHOD.

  METHOD wrong_step_key.
    mt_steps[ 1 ]-calc_run_id = 'ANOTHER-RUN'. expect_error( ).
  ENDMETHOD.

  METHOD duplicate_local_marker.
    APPEND mt_steps[ step_num = '05' seq = '02' ] TO mt_steps. expect_error( ).
  ENDMETHOD.

  METHOD missing_primary_marker.
    DELETE mt_steps WHERE step_num = '05' AND seq = '01'. expect_error( ).
  ENDMETHOD.

  METHOD contradictory_local.
    mt_steps[ step_num = '05' seq = '02' ]-output_currency = 'USD'. expect_error( ).
  ENDMETHOD.

  METHOD wrong_primary_rate.
    mt_steps[ step_num = '05' seq = '01' ]-rate_pct = 4. expect_error( ).
  ENDMETHOD.

  METHOD zero_primary_rate.
    ms_line-exch_rate_1 = 0. expect_error( ).
  ENDMETHOD.

  METHOD bad_marker_category.
    mt_steps[ step_num = '05' seq = '02' ]-step_category = zif_reing_ca_c=>step_category-tax.
    expect_error( ).
  ENDMETHOD.

  METHOD incompatible_step_currency.
    mt_steps[ 1 ]-output_currency = 'BRL'. expect_error( ).
  ENDMETHOD.

  METHOD unknown_monetary_category.
    mt_steps[ 1 ]-step_category = 'OTHER'. expect_error( ).
  ENDMETHOD.

  METHOD control_zero_output.
    mt_steps[ 1 ]-step_category = 'OTHER'. mt_steps[ 1 ]-output_amt = 0.
    DATA(ls_result) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = ls_result-steps[ 1 ]-output_trans_amt ).
  ENDMETHOD.

  METHOD calc_error_not_available.
    ms_line-line_status = zif_reing_ca_c=>line_status-calc_err. expect_error( ).
  ENDMETHOD.

  METHOD caller_processing_allowed.
    ms_line-line_status = zif_reing_ca_c=>line_status-calc_proc.
    DATA(ls_result) = project( ). cl_abap_unit_assert=>assert_true( ls_result-use_trans ).
  ENDMETHOD.

  METHOD repeated_call_no_mutation.
    DATA(ls_original) = ms_line. DATA(lt_original) = mt_pc. DATA(lt_steps_original) = mt_steps.
    DATA(ls_first) = project( ). DATA(ls_second) = project( ).
    cl_abap_unit_assert=>assert_equals( exp = ls_first act = ls_second ).
    cl_abap_unit_assert=>assert_equals( exp = ls_original act = ms_line ).
    cl_abap_unit_assert=>assert_equals( exp = lt_original act = mt_pc ).
    cl_abap_unit_assert=>assert_equals( exp = lt_steps_original act = mt_steps ).
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - Context and released-CDS tests for the OFF bypass contract.
CLASS lcx_eba_read_failure DEFINITION INHERITING FROM cx_no_check FINAL.
ENDCLASS.
CLASS lcx_eba_read_failure IMPLEMENTATION.
ENDCLASS.

CLASS ltcl_eba_bypass DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PUBLIC SECTION.
    CLASS-DATA master_off TYPE abap_bool.
    CLASS-DATA system_id TYPE c LENGTH 3.
    CLASS-DATA actor TYPE string.
    CLASS-DATA read_called TYPE abap_bool.
  PRIVATE SECTION.
    TYPES tt_tvarvc TYPE STANDARD TABLE OF zi_tvarvc WITH EMPTY KEY.
    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS put IMPORTING it_rows TYPE tt_tvarvc.
    METHODS forbid_read.
    METHODS master_on_skips_list FOR TESTING.
    METHODS production_ignores_list FOR TESTING.
    METHODS other_system_ignores_list FOR TESTING.
    METHODS ds4_exact_match FOR TESTING.
    METHODS ts4_exact_match FOR TESTING.
    METHODS missing_list_stays_off FOR TESTING.
    METHODS other_user_stays_off FOR TESTING.
    METHODS query_filters_name_type FOR TESTING.
    METHODS duplicates_and_case FOR TESTING.
    METHODS blank_rows_stay_off FOR TESTING.
    METHODS exclusion_rejects_list FOR TESTING.
    METHODS pattern_option_rejected FOR TESTING.
    METHODS pattern_low_rejected FOR TESTING.
    METHODS interval_rejects_list FOR TESTING.
    METHODS invalid_after_match_rejects FOR TESTING.
    METHODS long_name_not_truncated FOR TESTING.
    METHODS internal_space_not_removed FOR TESTING.
    METHODS read_error_stays_off FOR TESTING.
    METHODS empty_actor_skips_list FOR TESTING.
    METHODS new_call_refreshes_list FOR TESTING.
    METHODS bypass_keeps_provider_gate FOR TESTING.
ENDCLASS.

CLASS ltcl_eba_bypass IMPLEMENTATION.
  METHOD class_setup.
    sql_env = cl_osql_test_environment=>create( VALUE #( ( 'ZI_TVARVC' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    sql_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    sql_env->clear_doubles( ).
    master_off = abap_true.
    system_id = 'TS4'.
    actor = 'UT_BRASIL'.
    read_called = abap_false.
    TEST-INJECTION eba_bypass_context.
      lv_master_off = ltcl_eba_bypass=>master_off.
      lv_system = ltcl_eba_bypass=>system_id.
    END-TEST-INJECTION.
    TEST-INJECTION eba_bypass_user.
      lv_user = ltcl_eba_bypass=>actor.
    END-TEST-INJECTION.
  ENDMETHOD.
  METHOD teardown.
    sql_env->clear_doubles( ).
    CLEAR: actor, system_id, read_called.
    master_off = abap_true.
  ENDMETHOD.
  METHOD put.
    sql_env->insert_test_data( it_rows ).
  ENDMETHOD.
  METHOD forbid_read.
    TEST-INJECTION eba_bypass_read.
      ltcl_eba_bypass=>read_called = abap_true.
      CLEAR lt_entries.
    END-TEST-INJECTION.
  ENDMETHOD.
  METHOD master_on_skips_list.
    forbid_read( ).
    master_off = abap_false.
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
    cl_abap_unit_assert=>assert_false( read_called ).
  ENDMETHOD.
  METHOD production_ignores_list.
    forbid_read( ).
    system_id = 'PS4'.
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
    cl_abap_unit_assert=>assert_false( read_called ).
  ENDMETHOD.
  METHOD other_system_ignores_list.
    forbid_read( ).
    system_id = 'XS4'.
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
    cl_abap_unit_assert=>assert_false( read_called ).
  ENDMETHOD.
  METHOD ds4_exact_match.
    system_id = 'DS4'.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD ts4_exact_match.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD missing_list_stays_off.
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD other_user_stays_off.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'OTHER_USER' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD query_filters_name_type.
    put( VALUE #(
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'P' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' )
      ( name = 'Z_OTHER_VARIABLE' type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD duplicates_and_case.
    actor = '  ut_brasil  '.
    put( VALUE #(
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = '  Ut_Brasil  ' )
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'S' numb = '0001' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD blank_rows_stay_off.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD exclusion_rejects_list.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'E' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD pattern_option_rejected.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'CP' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD pattern_low_rejected.
    put( VALUE #(
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' )
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'S' numb = '0001' sign = 'I' opti = 'EQ' low = 'UT_*' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD interval_rejects_list.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' high = 'ZZZZ' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD invalid_after_match_rejects.
    put( VALUE #(
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' )
      ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
        type = 'S' numb = '0001' sign = 'I' opti = 'BT' low = 'A' high = 'Z' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD long_name_not_truncated.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL_EXTRA_SUFFIX' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD internal_space_not_removed.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_ BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD read_error_stays_off.
    TEST-INJECTION eba_bypass_read.
      RAISE EXCEPTION TYPE lcx_eba_read_failure.
    END-TEST-INJECTION.
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD empty_actor_skips_list.
    forbid_read( ).
    CLEAR actor.
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
    cl_abap_unit_assert=>assert_false( read_called ).
  ENDMETHOD.
  METHOD new_call_refreshes_list.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
    sql_env->clear_doubles( ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>get_eba_off( ) ).
  ENDMETHOD.
  METHOD bypass_keeps_provider_gate.
    put( VALUE #( ( name = zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
      type = 'S' numb = '0000' sign = 'I' opti = 'EQ' low = 'UT_BRASIL' ) ) ).
    DATA(lv_off) = zcl_reing_ca_trans_amounts=>get_eba_off( ).
    cl_abap_unit_assert=>assert_false( zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = 'MUR' iv_eba_off = lv_off ) ).
    cl_abap_unit_assert=>assert_true( zcl_reing_ca_trans_amounts=>is_eba_enabled(
      iv_bukrs_prest = 'EBA' iv_eba_off = lv_off ) ).
  ENDMETHOD.
ENDCLASS.
