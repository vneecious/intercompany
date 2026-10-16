CLASS zcl_reing_cm_ve_prev DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS prev_period
      IMPORTING iv_year   TYPE zreing_cm_h_a-period_year
                iv_month  TYPE zreing_cm_h_a-period_month
                iv_offset TYPE i
      EXPORTING ev_year   TYPE zreing_cm_h_a-period_year
                ev_month  TYPE zreing_cm_h_a-period_month.

    TYPES: BEGIN OF ty_libd,
             ct_uuid      TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid     TYPE zreing_cm_h_a-mat_uuid,
             op_type      TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type   TYPE zreing_cm_h_a-defer_type,
             period_year  TYPE zreing_cm_h_a-period_year,
             period_month TYPE zreing_cm_h_a-period_month,
             load_seq     TYPE zreing_cm_h_a-load_seq,
             delta_flag   TYPE zreing_cm_h_a-delta_flag,
             amount       TYPE zreing_cm_h_a-amount,
           END OF ty_libd.
    TYPES tt_libd TYPE SORTED TABLE OF ty_libd
            WITH NON-UNIQUE KEY ct_uuid mat_uuid op_type op_instance_num defer_type
                                period_year period_month load_seq.

    METHODS calc_prev_amount
      IMPORTING it_libd          TYPE tt_libd
                iv_ct            TYPE zreing_cm_h_a-ct_uuid
                iv_mat           TYPE zreing_cm_h_a-mat_uuid
                iv_op            TYPE zreing_cm_h_a-op_type
                iv_instance_num  TYPE zreing_cm_h_a-op_instance_num
                iv_defer         TYPE zreing_cm_h_a-defer_type
                iv_year          TYPE zreing_cm_h_a-period_year
                iv_month         TYPE zreing_cm_h_a-period_month
      RETURNING VALUE(rv_amount) TYPE zreing_cm_h_a-amount.
ENDCLASS.



CLASS zcl_reing_cm_ve_prev IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    LOOP AT it_requested_calc_elements ASSIGNING FIELD-SYMBOL(<fs_elem>).
      CASE <fs_elem>.
        WHEN `AMOUNTPREV1` OR `AMOUNTPREV2`.
          INSERT `PERIODYEAR`  INTO TABLE et_requested_orig_elements.
          INSERT `PERIODMONTH` INTO TABLE et_requested_orig_elements.
          INSERT `CTUUID`      INTO TABLE et_requested_orig_elements.
          INSERT `MATUUID`     INTO TABLE et_requested_orig_elements.
          INSERT `OPTYPE`      INTO TABLE et_requested_orig_elements.
          " V001 (CC) - #111: isolate previous CM amounts by operation instance.
          INSERT `OPINSTANCENUM` INTO TABLE et_requested_orig_elements.
          INSERT `DEFERTYPE`   INTO TABLE et_requested_orig_elements.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.

    TYPES: BEGIN OF ty_row,
             cmhid      TYPE zreing_cm_h_a-cm_h_id,
             periodyear  TYPE zreing_cm_h_a-period_year,
             periodmonth TYPE zreing_cm_h_a-period_month,
             ctuuid      TYPE zreing_cm_h_a-ct_uuid,
             matuuid     TYPE zreing_cm_h_a-mat_uuid,
             optype      TYPE zreing_cm_h_a-op_type,
             opinstancenum TYPE zreing_cm_h_a-op_instance_num,
             defertype   TYPE zreing_cm_h_a-defer_type,
             amountprev1  TYPE zreing_cm_h_a-amount,
             amountprev2  TYPE zreing_cm_h_a-amount,
           END OF ty_row.

    DATA lt_data TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
    lt_data = CORRESPONDING #( it_original_data ).

    CHECK lt_data IS NOT INITIAL.

    TYPES: BEGIN OF ty_fae,
             ct_uuid      TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid     TYPE zreing_cm_h_a-mat_uuid,
             op_type      TYPE zreing_cm_h_a-op_type,
             op_instance_num TYPE zreing_cm_h_a-op_instance_num,
             defer_type   TYPE zreing_cm_h_a-defer_type,
             period_year  TYPE zreing_cm_h_a-period_year,
             period_month TYPE zreing_cm_h_a-period_month,
           END OF ty_fae.

    DATA lt_fae TYPE STANDARD TABLE OF ty_fae WITH DEFAULT KEY.
    DATA lv_y1 TYPE zreing_cm_h_a-period_year.
    DATA lv_m1 TYPE zreing_cm_h_a-period_month.
    DATA lv_y2 TYPE zreing_cm_h_a-period_year.
    DATA lv_m2 TYPE zreing_cm_h_a-period_month.

    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<fs>).
      prev_period( EXPORTING iv_year = <fs>-periodyear iv_month = <fs>-periodmonth iv_offset = 1
                   IMPORTING ev_year = lv_y1 ev_month = lv_m1 ).
      prev_period( EXPORTING iv_year = <fs>-periodyear iv_month = <fs>-periodmonth iv_offset = 2
                   IMPORTING ev_year = lv_y2 ev_month = lv_m2 ).

      APPEND VALUE ty_fae( ct_uuid = <fs>-ctuuid mat_uuid = <fs>-matuuid
                           op_type = <fs>-optype defer_type = <fs>-defertype
                           op_instance_num = <fs>-opinstancenum
                           period_year = lv_y1 period_month = lv_m1 ) TO lt_fae.
      APPEND VALUE ty_fae( ct_uuid = <fs>-ctuuid mat_uuid = <fs>-matuuid
                           op_type = <fs>-optype defer_type = <fs>-defertype
                           op_instance_num = <fs>-opinstancenum
                           period_year = lv_y2 period_month = lv_m2 ) TO lt_fae.
    ENDLOOP.

    CHECK lt_fae IS NOT INITIAL.

    " Trae SOLO registros LIBD de los periodos objetivo (T-1 y T-2).
    " Estrategia Vini:
    "  (a) si hay al menos un registro delta (delta_flag = 'X') en LIBD para
    "      la combinacion+periodo: SUMA de todos los amount LIBD.
    "  (b) si solo hay registros base: amount del registro con MAX(load_seq) LIBD.
    DATA lt_raw TYPE STANDARD TABLE OF ty_libd WITH DEFAULT KEY.

    SELECT ct_uuid, mat_uuid, op_type, op_instance_num, defer_type, period_year, period_month,
           load_seq, delta_flag, amount
      FROM zreing_cm_h_a
      FOR ALL ENTRIES IN @lt_fae
      WHERE ct_uuid      = @lt_fae-ct_uuid
        AND mat_uuid     = @lt_fae-mat_uuid
        AND op_type      = @lt_fae-op_type
        AND op_instance_num = @lt_fae-op_instance_num
        AND defer_type   = @lt_fae-defer_type
        AND period_year  = @lt_fae-period_year
        AND period_month = @lt_fae-period_month
        AND cm_status    = 'LIBD'
      INTO TABLE @lt_raw.

    DATA lt_libd TYPE tt_libd.
    lt_libd = CORRESPONDING #( lt_raw ).

    LOOP AT lt_data ASSIGNING <fs>.
      prev_period( EXPORTING iv_year = <fs>-periodyear iv_month = <fs>-periodmonth iv_offset = 1
                   IMPORTING ev_year = lv_y1 ev_month = lv_m1 ).
      prev_period( EXPORTING iv_year = <fs>-periodyear iv_month = <fs>-periodmonth iv_offset = 2
                   IMPORTING ev_year = lv_y2 ev_month = lv_m2 ).

      <fs>-amountprev1 = calc_prev_amount( it_libd = lt_libd
                                           iv_ct = <fs>-ctuuid iv_mat = <fs>-matuuid
                                           iv_op = <fs>-optype iv_defer = <fs>-defertype
                                           iv_instance_num = <fs>-opinstancenum
                                           iv_year = lv_y1 iv_month = lv_m1 ).
      <fs>-amountprev2 = calc_prev_amount( it_libd = lt_libd
                                           iv_ct = <fs>-ctuuid iv_mat = <fs>-matuuid
                                           iv_op = <fs>-optype iv_defer = <fs>-defertype
                                           iv_instance_num = <fs>-opinstancenum
                                           iv_year = lv_y2 iv_month = lv_m2 ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_data ).
  ENDMETHOD.


  METHOD calc_prev_amount.
    DATA lv_has_delta TYPE abap_bool VALUE abap_false.
    DATA lv_sum       TYPE zreing_cm_h_a-amount VALUE 0.
    DATA lv_max_seq   TYPE zreing_cm_h_a-load_seq VALUE '000'.
    DATA lv_base_amt  TYPE zreing_cm_h_a-amount VALUE 0.
    DATA lv_found     TYPE abap_bool VALUE abap_false.

    LOOP AT it_libd ASSIGNING FIELD-SYMBOL(<fs_l>)
         WHERE ct_uuid      = iv_ct
           AND mat_uuid     = iv_mat
           AND op_type      = iv_op
           AND op_instance_num = iv_instance_num
           AND defer_type   = iv_defer
           AND period_year  = iv_year
           AND period_month = iv_month.
      lv_found = abap_true.
      lv_sum = lv_sum + <fs_l>-amount.
      IF <fs_l>-delta_flag = 'X'.
        lv_has_delta = abap_true.
      ENDIF.
      IF <fs_l>-load_seq >= lv_max_seq.
        lv_max_seq  = <fs_l>-load_seq.
        lv_base_amt = <fs_l>-amount.
      ENDIF.
    ENDLOOP.

    IF lv_found = abap_false.
      rv_amount = 0.
    ELSEIF lv_has_delta = abap_true.
      rv_amount = lv_sum.        " (a) suma de deltas LIBD
    ELSE.
      rv_amount = lv_base_amt.   " (b) ultimo base liberado (MAX load_seq)
    ENDIF.
  ENDMETHOD.


  METHOD prev_period.
    DATA lv_total TYPE i.
    lv_total = ( iv_year * 12 ) + ( iv_month - 1 ) - iv_offset.
    ev_year  = lv_total DIV 12.
    ev_month = ( lv_total MOD 12 ) + 1.
  ENDMETHOD.

ENDCLASS.

