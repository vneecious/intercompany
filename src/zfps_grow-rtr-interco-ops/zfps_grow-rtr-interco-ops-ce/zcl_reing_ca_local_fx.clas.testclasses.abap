" V001 (CC) - Standard-boundary fixtures, with no real quotation access.
CLASS ltcl_local_fx DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PUBLIC SECTION.
    CLASS-DATA mv_api_calls TYPE i.
    CLASS-DATA mv_api_failure TYPE c LENGTH 12.
    CLASS-DATA mv_api_local TYPE zif_reing_ca_types=>ty_fx_api_amount.
    CLASS-DATA mv_api_raw TYPE ukurs_curr.
    CLASS-DATA mv_api_foreign_factor TYPE ffact_curr.
    CLASS-DATA mv_api_local_factor TYPE tfact_curr.
    CLASS-DATA mv_api_derived TYPE kurst_curr.
    CLASS-DATA mv_seen_foreign TYPE decfloat34.
    CLASS-DATA mv_seen_from TYPE waers.
    CLASS-DATA mv_seen_to TYPE waers.
    CLASS-DATA mv_seen_date TYPE d.
    CLASS-DATA mv_seen_type TYPE kurst_curr.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zif_reing_ca_local_fx.
    METHODS setup.
    METHODS convert
      IMPORTING
        iv_amount TYPE decfloat34 DEFAULT '10'
        iv_from TYPE waers DEFAULT 'USD'
        iv_to TYPE waers DEFAULT 'BRL'
        iv_from_dec TYPE i DEFAULT 2
        iv_to_dec TYPE i DEFAULT 2
        iv_company TYPE bukrs DEFAULT '1000'
        iv_date TYPE d DEFAULT '20261007'
      RETURNING VALUE(rs_result) TYPE zif_reing_ca_types=>ty_local_fx_result.
    METHODS assert_unavailable
      IMPORTING is_result TYPE zif_reing_ca_types=>ty_local_fx_result
                iv_status TYPE zif_reing_ca_types=>ty_local_fx_status.
    METHODS quote_m_and_context FOR TESTING.
    METHODS no_op_skips_api FOR TESTING.
    METHODS no_op_zero FOR TESTING.
    METHODS zero_remains_available FOR TESTING.
    METHODS negative_amount FOR TESTING.
    METHODS commercial_half_rounding FOR TESTING.
    METHODS source_zero_decimals FOR TESTING.
    METHODS target_zero_decimals FOR TESTING.
    METHODS source_three_decimals FOR TESTING.
    METHODS target_three_rejected FOR TESTING.
    METHODS target_three_exact FOR TESTING.
    METHODS factors_not_applied_twice FOR TESTING.
    METHODS indirect_is_positive FOR TESTING.
    METHODS derived_type_is_trace FOR TESTING.
    METHODS missing_quote FOR TESTING.
    METHODS other_api_error FOR TESTING.
    METHODS other_message_105 FOR TESTING.
    METHODS api_overflow FOR TESTING.
    METHODS invalid_factors FOR TESTING.
    METHODS small_rate_rejected FOR TESTING.
    METHODS large_rate_rejected FOR TESTING.
    METHODS raw_rate_above_limit FOR TESTING.
    METHODS canonical_before_amount FOR TESTING.
    METHODS amount_overflow FOR TESTING.
    METHODS missing_company FOR TESTING.
    METHODS missing_currency FOR TESTING.
    METHODS invalid_decimals FOR TESTING.
    METHODS no_op_metadata_conflict FOR TESTING.
    METHODS missing_date FOR TESTING.
    METHODS input_precision FOR TESTING.
    METHODS no_stale_success FOR TESTING.
  ENDCLASS.

CLASS ltcl_local_fx IMPLEMENTATION.
  METHOD setup.
    mo_cut = NEW zcl_reing_ca_local_fx( ).
    CLEAR: mv_api_calls, mv_api_failure, mv_api_derived,
           mv_seen_foreign, mv_seen_from, mv_seen_to, mv_seen_date, mv_seen_type.
    mv_api_local = 5.
    mv_api_raw = 5.
    mv_api_foreign_factor = 1.
    mv_api_local_factor = 1.
    TEST-INJECTION local_fx_api.
      ltcl_local_fx=>mv_api_calls += 1.
      ltcl_local_fx=>mv_seen_foreign = lv_foreign_amount.
      ltcl_local_fx=>mv_seen_from = iv_trans_currency.
      ltcl_local_fx=>mv_seen_to = iv_local_currency.
      ltcl_local_fx=>mv_seen_date = iv_date.
      ltcl_local_fx=>mv_seen_type = rs_result-rate_type.
      CASE ltcl_local_fx=>mv_api_failure.
        WHEN 'NO_RATE'.
          RAISE EXCEPTION TYPE cx_exchange_rates
            EXPORTING textid = VALUE #( msgid = 'SG' msgno = '105' ).
        WHEN 'API'.
          RAISE EXCEPTION TYPE cx_exchange_rates
            EXPORTING textid = VALUE #( msgid = 'SG' msgno = '107' ).
        WHEN 'OTHER_105'.
          RAISE EXCEPTION TYPE cx_exchange_rates
            EXPORTING textid = VALUE #( msgid = '00' msgno = '105' ).
        WHEN 'OVERFLOW'.
          RAISE EXCEPTION TYPE cx_exchange_rates
            EXPORTING textid = VALUE #( msgid = 'SG' msgno = '106' ).
      ENDCASE.
      lv_local_amount = ltcl_local_fx=>mv_api_local.
      lv_exchange_rate = ltcl_local_fx=>mv_api_raw.
      lv_foreign_factor = ltcl_local_fx=>mv_api_foreign_factor.
      lv_local_factor = ltcl_local_fx=>mv_api_local_factor.
      lv_derived_type = ltcl_local_fx=>mv_api_derived.
    END-TEST-INJECTION.
  ENDMETHOD.

  METHOD convert.
    rs_result = mo_cut->convert_trans_to_local(
      iv_company_code = iv_company iv_trans_currency = iv_from iv_local_currency = iv_to
      iv_date = iv_date iv_amount_trans = iv_amount
      iv_decimals_trans = iv_from_dec iv_decimals_local = iv_to_dec ).
  ENDMETHOD.

  METHOD assert_unavailable.
    cl_abap_unit_assert=>assert_false( is_result-available ).
    cl_abap_unit_assert=>assert_equals( act = is_result-status_code exp = iv_status ).
    cl_abap_unit_assert=>assert_initial( is_result-amount_local ).
    cl_abap_unit_assert=>assert_initial( is_result-multiplier ).
    cl_abap_unit_assert=>assert_not_initial( is_result-message ).
  ENDMETHOD.

  METHOD quote_m_and_context.
    DATA(ls_result) = convert( ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code exp = 'OK' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( 50 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-rate_type exp = 'M' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-policy_source exp = 'TEMP_M' ).
    cl_abap_unit_assert=>assert_equals( act = mv_api_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_foreign exp = CONV decfloat34( 1 ) ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_from exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_to exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_type exp = 'M' ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_date exp = '20261007' ).
    cl_abap_unit_assert=>assert_initial( ls_result-message ).
  ENDMETHOD.

  METHOD no_op_skips_api.
    DATA(ls_result) = convert( iv_to = 'USD' iv_date = '00000000' ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( 10 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( 1 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-policy_source exp = 'NO_OP' ).
    cl_abap_unit_assert=>assert_initial( ls_result-rate_type ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD no_op_zero.
    DATA(ls_result) = convert( iv_to = 'USD' iv_amount = 0 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_initial( ls_result-amount_local ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( 1 ) ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD zero_remains_available.
    DATA(ls_result) = convert( iv_amount = 0 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_initial( ls_result-amount_local ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = mv_api_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_foreign exp = CONV decfloat34( 1 ) ).
  ENDMETHOD.

  METHOD negative_amount.
    DATA(ls_result) = convert( iv_amount = -10 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( -50 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( 5 ) ).
  ENDMETHOD.

  METHOD commercial_half_rounding.
    mv_api_local = '1.5'.
    DATA(ls_result) = convert( iv_amount = CONV decfloat34( '-1.23' ) ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( '-1.85' ) ).
  ENDMETHOD.

  METHOD source_zero_decimals.
    mv_api_local = '0.0088'.
    mv_api_foreign_factor = 100.
    DATA(ls_result) = convert( iv_from = 'JPY' iv_to = 'USD' iv_from_dec = 0 iv_amount = 100 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_foreign exp = CONV decfloat34( '0.01' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( '0.88' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( '0.0088' ) ).
  ENDMETHOD.

  METHOD target_zero_decimals.
    mv_api_local = '1.5'.
    DATA(ls_result) = convert( iv_to = 'JPY' iv_to_dec = 0 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( 1500 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( 150 ) ).
  ENDMETHOD.

  METHOD source_three_decimals.
    mv_api_local = '3.2'.
    DATA(ls_result) = convert( iv_from = 'KWD' iv_to = 'USD' iv_from_dec = 3
      iv_amount = CONV decfloat34( '1.23' ) ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = mv_seen_foreign exp = CONV decfloat34( 10 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( '3.94' ) ).
  ENDMETHOD.

  METHOD target_three_rejected.
    mv_api_local = '3.065'.
    DATA(ls_result) = convert( iv_to = 'KWD' iv_to_dec = 3 ).
    assert_unavailable( is_result = ls_result iv_status = 'PRECISION' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-rate_type exp = 'M' ).
  ENDMETHOD.

  METHOD target_three_exact.
    mv_api_local = '3.07'.
    DATA(ls_result) = convert( iv_to = 'KWD' iv_to_dec = 3 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( '3.07' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( '0.307' ) ).
  ENDMETHOD.

  METHOD factors_not_applied_twice.
    mv_api_local = '0.05'.
    mv_api_raw = 5.
    mv_api_foreign_factor = 100.
    DATA(ls_result) = convert( ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( '0.5' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( '0.05' ) ).
  ENDMETHOD.

  METHOD indirect_is_positive.
    mv_api_local = '0.25'.
    mv_api_raw = -4.
    DATA(ls_result) = convert( iv_amount = 8 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( 2 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( '0.25' ) ).
  ENDMETHOD.

  METHOD derived_type_is_trace.
    mv_api_derived = 'ICRG'.
    DATA(ls_result) = convert( ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-rate_type exp = 'M' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-derived_rate_type exp = 'ICRG' ).
  ENDMETHOD.

  METHOD missing_quote.
    mv_api_failure = 'NO_RATE'.
    DATA(ls_result) = convert( iv_amount = 0 ).
    assert_unavailable( is_result = ls_result iv_status = 'NO_RATE' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-rate_type exp = 'M' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-policy_source exp = 'TEMP_M' ).
  ENDMETHOD.

  METHOD other_api_error.
    mv_api_failure = 'API'.
    assert_unavailable( is_result = convert( ) iv_status = 'API' ).
  ENDMETHOD.

  METHOD other_message_105.
    mv_api_failure = 'OTHER_105'.
    assert_unavailable( is_result = convert( ) iv_status = 'API' ).
  ENDMETHOD.

  METHOD api_overflow.
    mv_api_failure = 'OVERFLOW'.
    assert_unavailable( is_result = convert( ) iv_status = 'RANGE' ).
  ENDMETHOD.

  METHOD invalid_factors.
    mv_api_foreign_factor = 0.
    assert_unavailable( is_result = convert( ) iv_status = 'API' ).
  ENDMETHOD.

  METHOD small_rate_rejected.
    mv_api_local = '0.000004'.
    assert_unavailable( is_result = convert( ) iv_status = 'PRECISION' ).
  ENDMETHOD.

  METHOD large_rate_rejected.
    mv_api_local = 10000.
    assert_unavailable( is_result = convert( ) iv_status = 'RANGE' ).
  ENDMETHOD.

  METHOD raw_rate_above_limit.
    mv_api_local = '9999.999994'.
    assert_unavailable( is_result = convert( ) iv_status = 'RANGE' ).
  ENDMETHOD.

  METHOD canonical_before_amount.
    mv_api_local = '1.2345678'.
    DATA(ls_result) = convert( iv_amount = 100000 ).
    cl_abap_unit_assert=>assert_true( ls_result-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-multiplier exp = CONV decfloat34( '1.23457' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-amount_local exp = CONV decfloat34( 123457 ) ).
  ENDMETHOD.

  METHOD amount_overflow.
    mv_api_local = 2.
    assert_unavailable( is_result = convert( iv_amount = CONV decfloat34( '9999999999999.99' ) )
      iv_status = 'RANGE' ).
  ENDMETHOD.

  METHOD missing_company.
    assert_unavailable( is_result = convert( iv_company = '' ) iv_status = 'CONFIG' ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD missing_currency.
    assert_unavailable( is_result = convert( iv_to = '' ) iv_status = 'CONFIG' ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD invalid_decimals.
    assert_unavailable( is_result = convert( iv_from_dec = -1 ) iv_status = 'CONFIG' ).
    assert_unavailable( is_result = convert( iv_to_dec = 4 ) iv_status = 'CONFIG' ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD no_op_metadata_conflict.
    assert_unavailable( is_result = convert( iv_to = 'USD' iv_to_dec = 3 ) iv_status = 'CONFIG' ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD missing_date.
    assert_unavailable( is_result = convert( iv_date = '00000000' ) iv_status = 'CONFIG' ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD input_precision.
    assert_unavailable( is_result = convert( iv_amount = CONV decfloat34( '1.234' ) )
      iv_status = 'PRECISION' ).
    cl_abap_unit_assert=>assert_initial( mv_api_calls ).
  ENDMETHOD.

  METHOD no_stale_success.
    DATA(ls_success) = convert( ).
    cl_abap_unit_assert=>assert_true( ls_success-available ).
    mv_api_failure = 'NO_RATE'.
    DATA(ls_failure) = convert( ).
    assert_unavailable( is_result = ls_failure iv_status = 'NO_RATE' ).
    CLEAR mv_api_failure.
    mv_api_local = 2.
    DATA(ls_again) = convert( ).
    cl_abap_unit_assert=>assert_true( ls_again-available ).
    cl_abap_unit_assert=>assert_equals( act = ls_again-amount_local exp = CONV decfloat34( 20 ) ).
    cl_abap_unit_assert=>assert_initial( ls_again-message ).
    cl_abap_unit_assert=>assert_equals( act = mv_api_calls exp = 3 ).
  ENDMETHOD.
ENDCLASS.
