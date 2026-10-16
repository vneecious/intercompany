" V001 (CC) - Nominal local preview; the standard API owns rate factors.
CLASS zcl_reing_ca_local_fx DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_reing_ca_local_fx.
  PRIVATE SECTION.
    " Private standard-error identities and local diagnostic numbers.
    CONSTANTS message_type TYPE symsgty VALUE 'S'.
    CONSTANTS:
      BEGIN OF standard_error,
        message_class TYPE symsgid VALUE 'SG',
        no_rate       TYPE symsgno VALUE '105',
        overflow      TYPE symsgno VALUE '106',
      END OF standard_error.
    CONSTANTS:
      BEGIN OF fx_message,
        invalid_context           TYPE symsgno VALUE '400',
        invalid_decimals          TYPE symsgno VALUE '401',
        conflicting_decimals      TYPE symsgno VALUE '402',
        missing_date              TYPE symsgno VALUE '403',
        trans_precision           TYPE symsgno VALUE '404',
        invalid_api_factors       TYPE symsgno VALUE '405',
        normalized_rate_range     TYPE symsgno VALUE '406',
        canonical_rate_precision  TYPE symsgno VALUE '407',
        canonical_rate_range      TYPE symsgno VALUE '408',
        rate_precision            TYPE symsgno VALUE '409',
        local_precision           TYPE symsgno VALUE '410',
        missing_quote             TYPE symsgno VALUE '411',
        api_overflow              TYPE symsgno VALUE '412',
        api_failure               TYPE symsgno VALUE '413',
        numeric_overflow          TYPE symsgno VALUE '414',
        technical_failure         TYPE symsgno VALUE '415',
      END OF fx_message.
    METHODS resolve_local_rate_type
      RETURNING VALUE(rv_rate_type) TYPE kurst_curr.
ENDCLASS.

CLASS zcl_reing_ca_local_fx IMPLEMENTATION.
  METHOD resolve_local_rate_type.
    " TODO: replace temporary M after SAP's alternative to the 2026-10-07 decision.
    " This SAP rate type does not mean the contract's manual strategy.
    rv_rate_type = zif_reing_ca_c=>fx_sap_rate_type-local_temporary.
  ENDMETHOD.

  METHOD zif_reing_ca_local_fx~convert_trans_to_local.
    rs_result-status_code = zif_reing_ca_c=>fx_local_status-config.
    IF iv_company_code IS INITIAL
       OR iv_trans_currency IS INITIAL OR iv_local_currency IS INITIAL.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
        NUMBER fx_message-invalid_context
        INTO rs_result-message.
      RETURN.
    ENDIF.
    IF iv_decimals_trans < 0 OR iv_decimals_trans > zif_reing_ca_c=>fx_numeric-max_currency_decimals
       OR iv_decimals_local < 0 OR iv_decimals_local > zif_reing_ca_c=>fx_numeric-max_currency_decimals.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
        NUMBER fx_message-invalid_decimals
        INTO rs_result-message.
      RETURN.
    ENDIF.
    IF iv_trans_currency = iv_local_currency AND iv_decimals_trans <> iv_decimals_local.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
        NUMBER fx_message-conflicting_decimals
        INTO rs_result-message.
      RETURN.
    ENDIF.

    " No-op does not resolve a type, a date, or a quotation.
    IF iv_trans_currency = iv_local_currency.
      rs_result-policy_source = zif_reing_ca_c=>fx_local_policy-no_op.
    ELSE.
      IF iv_date IS INITIAL.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
          NUMBER fx_message-missing_date
          INTO rs_result-message.
        RETURN.
      ENDIF.
      rs_result-rate_type = resolve_local_rate_type( ).
      rs_result-policy_source = zif_reing_ca_c=>fx_local_policy-temporary_m.
    ENDIF.

    TRY.
        " Validate the input against persisted LINE and STEP, even at zero.
        DATA(lv_trans_line) = CONV zreing_ca_line_a-net_trans_amt( iv_amount_trans ).
        DATA(lv_trans_step) = CONV zreing_ca_step_a-input_amt( iv_amount_trans ).
        IF CONV decfloat34( lv_trans_line ) <> iv_amount_trans
           OR CONV decfloat34( lv_trans_step ) <> iv_amount_trans.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-precision.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-trans_precision
            INTO rs_result-message.
          RETURN.
        ENDIF.

        DATA lv_multiplier TYPE decfloat34.
        IF iv_trans_currency = iv_local_currency.
          lv_multiplier = 1.
        ELSE.
          " Materialize ANY parameters; scale only at the standard API boundary.
          DATA lv_foreign_amount TYPE zif_reing_ca_types=>ty_fx_api_amount.
          DATA lv_local_amount TYPE zif_reing_ca_types=>ty_fx_api_amount.
          DATA lv_exchange_rate TYPE ukurs_curr.
          DATA lv_foreign_factor TYPE ffact_curr.
          DATA lv_local_factor TYPE tfact_curr.
          DATA lv_fixed_rate TYPE ukurs_curr.
          DATA lv_derived_type TYPE kurst_curr.
          DATA(lv_source_scale) = CONV decfloat34( zif_reing_ca_c=>fx_numeric-decimal_base ) ** ( iv_decimals_trans - zif_reing_ca_c=>fx_numeric-sap_amount_decimals ).
          DATA(lv_target_scale) = CONV decfloat34( zif_reing_ca_c=>fx_numeric-decimal_base ) ** ( zif_reing_ca_c=>fx_numeric-sap_amount_decimals - iv_decimals_local ).
          lv_foreign_amount = lv_source_scale.
          TEST-SEAM local_fx_api.
            cl_exchange_rates=>convert_to_local_currency(
              EXPORTING
                date              = iv_date
                foreign_amount    = lv_foreign_amount
                foreign_currency  = iv_trans_currency
                local_currency    = iv_local_currency
                rate_type         = rs_result-rate_type
                do_read_tcurr     = abap_true
              IMPORTING
                exchange_rate     = lv_exchange_rate
                foreign_factor    = lv_foreign_factor
                local_amount      = lv_local_amount
                local_factor      = lv_local_factor
                fixed_rate        = lv_fixed_rate
                derived_rate_type = lv_derived_type ).
          END-TEST-SEAM.
          rs_result-derived_rate_type = lv_derived_type.
          IF lv_foreign_factor <= 0 OR lv_local_factor <= 0.
            rs_result-status_code = zif_reing_ca_c=>fx_local_status-api.
            MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
              NUMBER fx_message-invalid_api_factors
              INTO rs_result-message.
            RETURN.
          ENDIF.
          " LOCAL_AMOUNT already includes SAP's factors, direction and derivation.
          lv_multiplier = CONV decfloat34( lv_local_amount ) * lv_target_scale.
        ENDIF.

        IF lv_multiplier < 0 OR lv_multiplier > zif_reing_ca_c=>fx_numeric-max_rate.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-range.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-normalized_rate_range
            INTO rs_result-message.
          RETURN.
        ENDIF.
        DATA(lv_canonical) = round(
          val = lv_multiplier dec = zif_reing_ca_c=>fx_numeric-rate_decimals mode = cl_abap_math=>round_half_up ).
        IF lv_canonical <= 0.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-precision.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-canonical_rate_precision
            INTO rs_result-message.
          RETURN.
        ENDIF.
        IF lv_canonical > zif_reing_ca_c=>fx_numeric-max_rate.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-range.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-canonical_rate_range
            INTO rs_result-message.
          RETURN.
        ENDIF.

        DATA(lv_rate_line) = CONV zreing_ca_line_a-exch_rate( lv_canonical ).
        DATA(lv_rate_step) = CONV zreing_ca_step_a-rate_pct( lv_canonical ).
        IF CONV decfloat34( lv_rate_line ) <> lv_canonical
           OR CONV decfloat34( lv_rate_step ) <> lv_canonical.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-precision.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-rate_precision
            INTO rs_result-message.
          RETURN.
        ENDIF.

        DATA lv_amount TYPE decfloat34.
        IF iv_trans_currency = iv_local_currency.
          lv_amount = iv_amount_trans.
        ELSE.
          lv_amount = round( val = iv_amount_trans * lv_canonical
            dec = iv_decimals_local mode = cl_abap_math=>round_half_up ).
        ENDIF.
        DATA(lv_local_line) = CONV zreing_ca_line_a-net_local_amt( lv_amount ).
        DATA(lv_local_step) = CONV zreing_ca_step_a-output_amt( lv_amount ).
        IF CONV decfloat34( lv_local_line ) <> lv_amount
           OR CONV decfloat34( lv_local_step ) <> lv_amount.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-precision.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-local_precision
            INTO rs_result-message.
          RETURN.
        ENDIF.

        " Publish all success fields together; failures leave amount and rate clean.
        rs_result-amount_local = lv_amount.
        rs_result-multiplier = lv_canonical.
        rs_result-status_code = zif_reing_ca_c=>fx_local_status-ok.
        rs_result-available = abap_true.
      CATCH cx_exchange_rates INTO DATA(lx_api).
        rs_result-status_code = zif_reing_ca_c=>fx_local_status-api.
        " Standard SCUN uses SG/105 for no rate and SG/106 for overflow.
        DATA(lo_t100) = CAST if_t100_message( lx_api ).
        IF lo_t100->t100key-msgid = standard_error-message_class AND lo_t100->t100key-msgno = standard_error-no_rate.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-no_rate.
          DATA(lv_date_text) = |{ iv_date DATE = ISO }|.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-missing_quote WITH rs_result-rate_type iv_trans_currency
              iv_local_currency lv_date_text
            INTO rs_result-message.
        ELSEIF lo_t100->t100key-msgid = standard_error-message_class AND lo_t100->t100key-msgno = standard_error-overflow.
          rs_result-status_code = zif_reing_ca_c=>fx_local_status-range.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-api_overflow
            INTO rs_result-message.
          " Preserve the complete translated cause beyond T100 parameter limits.
          rs_result-message = |{ rs_result-message }: { lx_api->get_text( ) }|.
        ELSE.
          MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
            NUMBER fx_message-api_failure
            INTO rs_result-message.
          " Preserve the complete translated cause beyond T100 parameter limits.
          rs_result-message = |{ rs_result-message }: { lx_api->get_text( ) }|.
        ENDIF.
      CATCH cx_sy_conversion_overflow cx_sy_arithmetic_overflow.
        rs_result-status_code = zif_reing_ca_c=>fx_local_status-range.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
          NUMBER fx_message-numeric_overflow
          INTO rs_result-message.
      CATCH cx_root INTO DATA(lx_other).
        rs_result-status_code = zif_reing_ca_c=>fx_local_status-api.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE message_type
          NUMBER fx_message-technical_failure
          INTO rs_result-message.
        " Preserve the complete translated cause beyond T100 parameter limits.
        rs_result-message = |{ rs_result-message }: { lx_other->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

