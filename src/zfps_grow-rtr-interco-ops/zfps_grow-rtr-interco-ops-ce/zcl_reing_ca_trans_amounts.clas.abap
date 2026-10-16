" V001 (CC) - Pure nominal amounts; no exchange-rate lookup or persistence.
CLASS zcl_reing_ca_trans_amounts DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    " V001 (CC) - Keep the existing OFF polarity at the contextual boundary.
    CLASS-METHODS get_eba_off
      RETURNING VALUE(rv_eba_off) TYPE abap_bool.
    CLASS-METHODS is_eba_enabled
      IMPORTING iv_bukrs_prest TYPE bukrs iv_eba_off TYPE abap_bool
      RETURNING VALUE(rv_enabled) TYPE abap_bool.
    CLASS-METHODS inspect_fx
      IMPORTING is_line TYPE zreing_ca_line_a
                it_steps TYPE zif_reing_ca_types=>ty_step_t
      RETURNING VALUE(rs_state) TYPE zif_reing_ca_types=>ty_trans_state_result
      RAISING zcx_reing_ca_calc_error.
    CLASS-METHODS project_line
      IMPORTING is_line TYPE zreing_ca_line_a
                it_line_pc TYPE zif_reing_ca_types=>ty_line_pc_t
                it_steps TYPE zif_reing_ca_types=>ty_step_t
                it_currencies TYPE zif_reing_ca_types=>tt_currency_precision
                iv_eba_off TYPE abap_bool
      RETURNING VALUE(rs_projection) TYPE zif_reing_ca_types=>ty_trans_projection
      RAISING zcx_reing_ca_calc_error.
  PRIVATE SECTION.
    CLASS-METHODS evaluate_user_bypass
      IMPORTING iv_user TYPE string
                it_entries TYPE zif_reing_ca_types=>tt_eba_bypass_entries
      RETURNING VALUE(rv_eba_off) TYPE abap_bool.
    CLASS-METHODS normalize_user
      IMPORTING iv_user TYPE string
      RETURNING VALUE(rv_user) TYPE string.
    TYPES tt_step_keys TYPE HASHED TABLE OF zreing_ca_step_a
      WITH UNIQUE KEY calc_run_id line_num step_num seq.
    CLASS-METHODS fail
      IMPORTING iv_number TYPE symsgno iv_v1 TYPE symsgv OPTIONAL
                iv_v2 TYPE symsgv OPTIONAL
      RAISING zcx_reing_ca_calc_error.
    CLASS-METHODS precision
      IMPORTING iv_currency TYPE waers
                it_currencies TYPE zif_reing_ca_types=>tt_currency_precision
      RETURNING VALUE(rv_decimals) TYPE i
      RAISING zcx_reing_ca_calc_error.
    CLASS-METHODS amount
      IMPORTING iv_amount TYPE decfloat34 iv_decimals TYPE i iv_currency TYPE waers
                iv_message TYPE symsgno
      RETURNING VALUE(rv_amount) TYPE zreing_ca_calc_amt
      RAISING zcx_reing_ca_calc_error.
    CLASS-METHODS project_steps
      IMPORTING is_line TYPE zreing_ca_line_a iv_decimals TYPE i
      CHANGING ct_steps TYPE zif_reing_ca_types=>ty_step_t
      RAISING zcx_reing_ca_calc_error.
ENDCLASS.

CLASS zcl_reing_ca_trans_amounts IMPLEMENTATION.
  METHOD get_eba_off.
    DATA lv_master_off TYPE abap_bool.
    DATA lv_system TYPE c LENGTH 3.
    TEST-SEAM eba_bypass_context.
      lv_master_off = zif_reing_ca_c=>br_isolation-eba_off.
      lv_system = sy-sysid.
    END-TEST-SEAM.
    rv_eba_off = lv_master_off.
    IF lv_master_off = abap_false
       OR ( lv_system <> zif_reing_ca_c=>br_user_bypass-system_ds4
        AND lv_system <> zif_reing_ca_c=>br_user_bypass-system_ts4 ).
      RETURN.
    ENDIF.

    TRY.
        DATA lv_user TYPE string.
        TEST-SEAM eba_bypass_user.
          lv_user = cl_abap_context_info=>get_user_technical_name( ).
        END-TEST-SEAM.
        IF normalize_user( lv_user ) IS INITIAL.
          RETURN.
        ENDIF.
        DATA lt_entries TYPE zif_reing_ca_types=>tt_eba_bypass_entries.
        TEST-SEAM eba_bypass_read.
          SELECT sign, opti, low, high FROM zi_tvarvc
            WHERE name = @zif_reing_ca_c=>tvarvc_id-eba_off_bypass_users
              AND type = @zif_reing_ca_c=>br_user_bypass-selection_type
            INTO TABLE @lt_entries.
        END-TEST-SEAM.
        rv_eba_off = evaluate_user_bypass( iv_user = lv_user it_entries = lt_entries ).
      CATCH cx_root.
        " A configuration/read failure never grants the optional bypass.
        rv_eba_off = abap_true.
    ENDTRY.
  ENDMETHOD.

  METHOD normalize_user.
    rv_user = to_upper( shift_right( val = shift_left( val = iv_user sub = ` ` ) sub = ` ` ) ).
  ENDMETHOD.

  METHOD evaluate_user_bypass.
    rv_eba_off = abap_true.
    DATA(lv_user) = normalize_user( iv_user ).
    IF lv_user IS INITIAL. RETURN. ENDIF.
    DATA lv_included TYPE abap_bool.
    LOOP AT it_entries INTO DATA(ls_entry).
      DATA(lv_low) = normalize_user( ls_entry-low ).
      DATA(lv_high) = normalize_user( ls_entry-high ).
      IF lv_low IS INITIAL AND lv_high IS INITIAL
         AND ls_entry-sign IS INITIAL AND ls_entry-opti IS INITIAL.
        CONTINUE.
      ENDIF.
      IF ls_entry-sign <> zif_reing_ca_c=>br_user_bypass-include_sign
         OR ls_entry-opti <> zif_reing_ca_c=>br_user_bypass-equal_option
         OR lv_high IS NOT INITIAL
         OR lv_low CA zif_reing_ca_c=>br_user_bypass-pattern_chars.
        RETURN.
      ENDIF.
      IF lv_low IS NOT INITIAL AND lv_low = lv_user.
        lv_included = abap_true.
      ENDIF.
    ENDLOOP.
    " Validate the complete list before accepting any match; duplicates are idempotent.
    rv_eba_off = xsdbool( lv_included = abap_false ).
  ENDMETHOD.
  METHOD is_eba_enabled.
    rv_enabled = xsdbool( iv_eba_off = abap_false
      AND iv_bukrs_prest = zif_reing_ca_c=>br_isolation-eba_bukrs ).
  ENDMETHOD.

  METHOD fail.
    MESSAGE ID zif_reing_ca_c=>message_class
      TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_number
      WITH iv_v1 iv_v2 INTO DATA(lv_text).
    RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_text.
  ENDMETHOD.

  METHOD precision.
    ASSIGN it_currencies[ currency = iv_currency ] TO FIELD-SYMBOL(<currency>).
    IF iv_currency IS INITIAL OR sy-subrc <> 0.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-currency
            iv_v1 = CONV #( iv_currency ) ).
    ENDIF.
    IF <currency>-decimals < 0
       OR <currency>-decimals > zif_reing_ca_c=>fx_numeric-max_currency_decimals.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-currency
            iv_v1 = CONV #( iv_currency ) ).
    ENDIF.
    rv_decimals = <currency>-decimals.
  ENDMETHOD.

  METHOD amount.
    TRY.
        DATA(lv_rounded) = round( val = iv_amount dec = iv_decimals
          mode = cl_abap_math=>round_half_up ).
        IF iv_message = zif_reing_ca_c=>fx_projection_message-residual AND lv_rounded <> iv_amount.
          fail( iv_number = iv_message iv_v1 = CONV #( iv_currency ) ).
        ENDIF.
        rv_amount = CONV #( lv_rounded ).
        IF CONV decfloat34( rv_amount ) <> lv_rounded.
          fail( iv_number = iv_message
                iv_v1 = COND #( WHEN iv_message = zif_reing_ca_c=>fx_projection_message-residual
                                THEN CONV #( iv_currency ) ELSE CONV #( iv_amount ) )
                iv_v2 = CONV #( iv_currency ) ).
        ENDIF.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        fail( iv_number = iv_message
              iv_v1 = COND #( WHEN iv_message = zif_reing_ca_c=>fx_projection_message-residual
                              THEN CONV #( iv_currency ) ELSE CONV #( iv_amount ) )
              iv_v2 = CONV #( iv_currency ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD inspect_fx.
    rs_state-state = zif_reing_ca_c=>fx_projection_state-legacy.
    IF is_line-bukrs_prest <> zif_reing_ca_c=>br_isolation-eba_bukrs.
      RETURN.
    ENDIF.
    DATA lt_keys TYPE tt_step_keys.
    LOOP AT it_steps INTO DATA(ls_step).
      IF ls_step-calc_run_id <> is_line-calc_run_id OR ls_step-line_num <> is_line-line_num.
        fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
              iv_v1 = CONV #( is_line-line_num ) ).
      ENDIF.
      INSERT ls_step INTO TABLE lt_keys.
      IF sy-subrc <> 0.
        fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
              iv_v1 = CONV #( is_line-line_num ) ).
      ENDIF.
    ENDLOOP.
    ASSIGN lt_keys[ calc_run_id = is_line-calc_run_id line_num = is_line-line_num
      step_num = zif_reing_ca_c=>fx_step-number
      seq = zif_reing_ca_c=>fx_step-local_seq ] TO FIELD-SYMBOL(<local>).
    IF sy-subrc <> 0. RETURN. ENDIF.
    ASSIGN lt_keys[ calc_run_id = is_line-calc_run_id line_num = is_line-line_num
      step_num = zif_reing_ca_c=>fx_step-number
      seq = zif_reing_ca_c=>fx_step-primary_seq ] TO FIELD-SYMBOL(<primary>).
    IF sy-subrc <> 0.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    IF is_line-line_status = zif_reing_ca_c=>line_status-calc_err
       OR is_line-ct_currency IS INITIAL OR is_line-trans_currency IS INITIAL
       OR is_line-exch_rate_1 <= 0
       OR <primary>-step_category <> zif_reing_ca_c=>step_category-fx
       OR <local>-step_category <> zif_reing_ca_c=>step_category-fx
       OR <primary>-input_currency <> is_line-ct_currency
       OR <primary>-output_currency <> is_line-trans_currency
       OR <primary>-input_amt <> is_line-net_amt
       OR <primary>-output_amt <> is_line-net_trans_amt
       OR <primary>-rate_pct <> is_line-exch_rate_1
       OR <local>-input_currency <> is_line-trans_currency
       OR <local>-input_amt <> is_line-net_trans_amt
       OR <local>-output_amt <> is_line-net_local_amt
       OR <local>-rate_pct <> is_line-exch_rate.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    IF is_line-ct_currency = is_line-trans_currency
       AND ( is_line-exch_rate_1 <> zif_reing_ca_c=>fx_projection-identity_rate
             OR is_line-net_trans_amt <> is_line-net_amt ).
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    rs_state-is_v2 = abap_true.
    IF is_line-local_currency IS NOT INITIAL
       AND <local>-output_currency = is_line-local_currency AND is_line-exch_rate > 0.
      IF is_line-local_currency = is_line-trans_currency
         AND ( is_line-exch_rate <> zif_reing_ca_c=>fx_projection-identity_rate
               OR is_line-net_local_amt <> is_line-net_trans_amt ).
        fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
              iv_v1 = CONV #( is_line-line_num ) ).
      ENDIF.
      rs_state-state = zif_reing_ca_c=>fx_projection_state-available.
      rs_state-local_available = abap_true.
    ELSEIF <local>-output_currency IS INITIAL AND is_line-exch_rate = 0
           AND is_line-net_local_amt = 0.
      rs_state-state = zif_reing_ca_c=>fx_projection_state-unavailable.
    ELSE.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
  ENDMETHOD.

  METHOD project_line.
    rs_projection-line = is_line.
    rs_projection-steps = it_steps.
    " Legacy returns its exact snapshot, before applying any new validation.
    IF is_eba_enabled( iv_bukrs_prest = is_line-bukrs_prest iv_eba_off = iv_eba_off ) = abap_false.
      rs_projection-line_pc = CORRESPONDING #( it_line_pc ).
      RETURN.
    ENDIF.
    DATA(ls_state) = inspect_fx( is_line = is_line it_steps = it_steps ).
    IF ls_state-is_v2 = abap_false.
      rs_projection-line_pc = CORRESPONDING #( it_line_pc ).
      RETURN.
    ENDIF.
    IF it_line_pc IS INITIAL.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    DATA lv_sum_calc TYPE decfloat34.
    DATA lv_sum_bruto TYPE decfloat34.
    DATA lv_sum_tax TYPE decfloat34.
    DATA lv_sum_net TYPE decfloat34.
    LOOP AT it_line_pc INTO DATA(ls_pc).
      IF ls_pc-calc_run_id <> is_line-calc_run_id OR ls_pc-line_num <> is_line-line_num
         OR ls_pc-ct_currency <> is_line-ct_currency
         OR line_exists( rs_projection-line_pc[ calc_run_id = ls_pc-calc_run_id
              line_num = ls_pc-line_num pc_seq = ls_pc-pc_seq ] ).
        fail( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
              iv_v1 = CONV #( is_line-line_num ) ).
      ENDIF.
      INSERT CORRESPONDING #( ls_pc ) INTO TABLE rs_projection-line_pc.
      lv_sum_calc += ls_pc-calc_amt.
      lv_sum_bruto += ls_pc-bruto_amt.
      lv_sum_tax += ls_pc-tax_amt.
      lv_sum_net += ls_pc-net_amt.
    ENDLOOP.
    IF lv_sum_calc <> is_line-calc_amt OR lv_sum_bruto <> is_line-bruto_amt
       OR lv_sum_tax <> is_line-tax_amt OR lv_sum_net <> is_line-net_amt.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    DATA(lv_decimals) = precision( iv_currency = is_line-trans_currency it_currencies = it_currencies ).
    rs_projection-use_trans = abap_true.
    rs_projection-local_available = ls_state-local_available.
    DATA lv_net_check TYPE zreing_ca_net_trans_amt.
    IF is_line-ct_currency = is_line-trans_currency.
      rs_projection-calc_trans_amt = is_line-calc_amt.
      rs_projection-bruto_trans_amt = is_line-bruto_amt.
      lv_net_check = is_line-net_amt.
    ELSE.
    rs_projection-calc_trans_amt = amount(
      iv_amount = CONV decfloat34( is_line-calc_amt ) * CONV decfloat34( is_line-exch_rate_1 )
      iv_decimals = lv_decimals iv_currency = is_line-trans_currency
      iv_message = zif_reing_ca_c=>fx_projection_message-amount ).
    rs_projection-bruto_trans_amt = amount(
      iv_amount = CONV decfloat34( is_line-bruto_amt ) * CONV decfloat34( is_line-exch_rate_1 )
      iv_decimals = lv_decimals iv_currency = is_line-trans_currency
      iv_message = zif_reing_ca_c=>fx_projection_message-amount ).
    lv_net_check = amount(
      iv_amount = CONV decfloat34( is_line-net_amt ) * CONV decfloat34( is_line-exch_rate_1 )
      iv_decimals = lv_decimals iv_currency = is_line-trans_currency
      iv_message = zif_reing_ca_c=>fx_projection_message-amount ).
    ENDIF.
    IF lv_net_check <> is_line-net_trans_amt.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-memory
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    DATA(lv_same_currency) = xsdbool( is_line-ct_currency = is_line-trans_currency ).
    IF lv_same_currency = abap_true.
      rs_projection-calc_trans_amt = is_line-calc_amt.
      rs_projection-bruto_trans_amt = is_line-bruto_amt.
    ENDIF.
    DATA lv_local_decimals TYPE i.
    DATA lv_local_failed TYPE abap_bool.
    IF rs_projection-local_available = abap_true.
      TRY.
          lv_local_decimals = precision( iv_currency = is_line-local_currency it_currencies = it_currencies ).
        CATCH zcx_reing_ca_calc_error.
          lv_local_failed = abap_true.
      ENDTRY.
    ENDIF.
    CLEAR: lv_sum_calc, lv_sum_bruto, lv_sum_net.
    DATA lv_sum_local TYPE decfloat34.
    DATA lv_position TYPE i.
    DATA(lv_count) = lines( rs_projection-line_pc ).
    IF is_line-is_delta = abap_false AND is_line-share_pct = 0
       AND is_line-calc_amt <> 0 AND lv_count > 1.
      fail( iv_number = zif_reing_ca_c=>fx_projection_message-breakdown
            iv_v1 = CONV #( is_line-line_num ) ).
    ENDIF.
    LOOP AT rs_projection-line_pc ASSIGNING FIELD-SYMBOL(<pc>).
      lv_position += 1.
      DATA(lv_factor) = COND decfloat34(
        WHEN is_line-is_delta = abap_true AND is_line-calc_amt <> 0
        THEN CONV decfloat34( <pc>-calc_amt ) / CONV decfloat34( is_line-calc_amt )
        WHEN is_line-is_delta = abap_false AND is_line-share_pct <> 0
        THEN CONV decfloat34( <pc>-share_abs ) / CONV decfloat34( is_line-share_pct )
        ELSE 0 ).
      DATA(lv_compensated) = xsdbool( is_line-is_delta = abap_true AND is_line-calc_amt = 0 ).
      DATA(lv_calc) = COND decfloat34(
        WHEN lv_compensated = abap_true THEN CONV decfloat34( <pc>-calc_amt ) * is_line-exch_rate_1
        ELSE CONV decfloat34( rs_projection-calc_trans_amt ) * lv_factor ).
      DATA(lv_bruto) = COND decfloat34(
        WHEN lv_compensated = abap_true THEN CONV decfloat34( <pc>-bruto_amt ) * is_line-exch_rate_1
        ELSE CONV decfloat34( rs_projection-bruto_trans_amt ) * lv_factor ).
      DATA(lv_net) = COND decfloat34(
        WHEN lv_compensated = abap_true THEN CONV decfloat34( <pc>-net_amt ) * is_line-exch_rate_1
        ELSE CONV decfloat34( is_line-net_trans_amt ) * lv_factor ).
      DATA(lv_local) = COND decfloat34(
        WHEN lv_compensated = abap_true THEN CONV decfloat34( <pc>-net_amt ) * is_line-exch_rate_1 * is_line-exch_rate
        ELSE CONV decfloat34( is_line-net_local_amt ) * lv_factor ).
      IF lv_position = lv_count.
        lv_calc = rs_projection-calc_trans_amt - lv_sum_calc.
        lv_bruto = rs_projection-bruto_trans_amt - lv_sum_bruto.
        lv_net = is_line-net_trans_amt - lv_sum_net.
        lv_local = is_line-net_local_amt - lv_sum_local.
      ENDIF.
      DATA(lv_amount_message) = COND symsgno( WHEN lv_position = lv_count
        THEN zif_reing_ca_c=>fx_projection_message-residual
        ELSE zif_reing_ca_c=>fx_projection_message-amount ).
      IF lv_same_currency = abap_true.
        <pc>-calc_trans_amt = <pc>-calc_amt.
        <pc>-bruto_trans_amt = <pc>-bruto_amt.
        <pc>-net_trans_amt = <pc>-net_amt.
      ELSE.
        <pc>-calc_trans_amt = amount( iv_amount = lv_calc iv_decimals = lv_decimals
          iv_currency = is_line-trans_currency iv_message = lv_amount_message ).
        <pc>-bruto_trans_amt = amount( iv_amount = lv_bruto iv_decimals = lv_decimals
          iv_currency = is_line-trans_currency iv_message = lv_amount_message ).
        <pc>-net_trans_amt = amount( iv_amount = lv_net iv_decimals = lv_decimals
          iv_currency = is_line-trans_currency iv_message = lv_amount_message ).
      ENDIF.
      lv_sum_calc += <pc>-calc_trans_amt.
      lv_sum_bruto += <pc>-bruto_trans_amt.
      lv_sum_net += <pc>-net_trans_amt.
      CLEAR <pc>-net_local_amt.
      <pc>-local_currency = is_line-local_currency.
      IF rs_projection-local_available = abap_true AND lv_local_failed = abap_false.
        TRY.
            <pc>-net_local_amt = amount( iv_amount = lv_local iv_decimals = lv_local_decimals
              iv_currency = is_line-local_currency iv_message = lv_amount_message ).
            lv_sum_local += <pc>-net_local_amt.
          CATCH zcx_reing_ca_calc_error.
            lv_local_failed = abap_true.
        ENDTRY.
      ENDIF.
    ENDLOOP.
    IF lv_local_failed = abap_true.
      CLEAR: rs_projection-local_available, rs_projection-line-net_local_amt, rs_projection-line-exch_rate.
      LOOP AT rs_projection-line_pc ASSIGNING <pc>.
        CLEAR <pc>-net_local_amt.
      ENDLOOP.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER zif_reing_ca_c=>fx_projection_message-local_preview
        WITH is_line-line_num INTO rs_projection-local_message.
      ASSIGN rs_projection-steps[ step_num = zif_reing_ca_c=>fx_step-number
        seq = zif_reing_ca_c=>fx_step-local_seq ] TO FIELD-SYMBOL(<local_step>).
      CLEAR: <local_step>-output_amt, <local_step>-output_currency, <local_step>-rate_pct.
      <local_step>-step_desc = CONV #( rs_projection-local_message ).
    ENDIF.
    project_steps( EXPORTING is_line = rs_projection-line iv_decimals = lv_decimals
                   CHANGING ct_steps = rs_projection-steps ).
  ENDMETHOD.

  METHOD project_steps.
    LOOP AT ct_steps ASSIGNING FIELD-SYMBOL(<step>).
      IF <step>-step_num = zif_reing_ca_c=>fx_step-number
         AND <step>-seq = zif_reing_ca_c=>fx_step-primary_seq.
        <step>-output_trans_amt = is_line-net_trans_amt.
      ELSEIF <step>-step_num = zif_reing_ca_c=>fx_step-number
             AND <step>-seq = zif_reing_ca_c=>fx_step-local_seq.
        " Nominal value crossing the bridge remains TRANS even without LOCAL.
        <step>-output_trans_amt = <step>-input_amt.
      ELSEIF <step>-step_category = zif_reing_ca_c=>step_category-validate
          OR <step>-step_category = zif_reing_ca_c=>step_category-distribute
          OR <step>-step_category = zif_reing_ca_c=>step_category-delta
          OR <step>-step_category = zif_reing_ca_c=>step_category-gross_up
          OR <step>-step_category = zif_reing_ca_c=>step_category-tax
          OR <step>-step_category = zif_reing_ca_c=>step_category-net.
        IF <step>-output_currency IS NOT INITIAL AND <step>-output_currency <> is_line-ct_currency.
          fail( iv_number = zif_reing_ca_c=>fx_projection_message-step_currency
                iv_v1 = CONV #( <step>-step_num ) iv_v2 = CONV #( <step>-seq ) ).
        ENDIF.
        IF is_line-ct_currency = is_line-trans_currency.
          <step>-output_trans_amt = <step>-output_amt.
        ELSE.
          <step>-output_trans_amt = amount(
            iv_amount = CONV decfloat34( <step>-output_amt ) * CONV decfloat34( is_line-exch_rate_1 )
            iv_decimals = iv_decimals iv_currency = is_line-trans_currency
            iv_message = zif_reing_ca_c=>fx_projection_message-amount ).
        ENDIF.
      ELSEIF <step>-output_amt = 0.
        CLEAR <step>-output_trans_amt.
      ELSE.
        fail( iv_number = zif_reing_ca_c=>fx_projection_message-step_currency
              iv_v1 = CONV #( <step>-step_num ) iv_v2 = CONV #( <step>-seq ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

