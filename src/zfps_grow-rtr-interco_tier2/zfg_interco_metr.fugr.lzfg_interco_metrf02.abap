*----------------------------------------------------------------------*
***INCLUDE LZFG_INTERCO_METRF02.
*----------------------------------------------------------------------*
" Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - G02A: auditoría y unicidad SM30
" FORM g02a_antes_grabar.
" ENDFORM.
FORM g02a_antes_grabar.

  TYPES: BEGIN OF ty_metric_check,
           id                    TYPE zint_a_md_metric-id,
           valid_from            TYPE zint_a_md_metric-valid_from,
           valid_to              TYPE zint_a_md_metric-valid_to,
           provider_company_code TYPE zint_a_md_metric-provider_company_code,
           product               TYPE zint_a_md_metric-product,
           payment_type          TYPE zint_a_md_metric-payment_type,
           metric                TYPE zint_a_md_metric-metric,
           is_deleted            TYPE zint_a_md_metric-is_deleted,
         END OF ty_metric_check.

  DATA lt_metric_check TYPE SORTED TABLE OF ty_metric_check
    WITH UNIQUE KEY id.
  DATA lt_compare TYPE STANDARD TABLE OF ty_metric_check WITH EMPTY KEY.
  DATA lv_changed_at TYPE zint_a_md_metric-last_changed_at.
  FIELD-SYMBOLS <ls_metric> TYPE zint_a_md_metric.

  " Incluir también las filas que no se cargaron por filtros de SM30
  SELECT id,
         valid_from,
         valid_to,
         provider_company_code,
         product,
         payment_type,
         metric,
         is_deleted
    FROM zint_a_md_metric
    WHERE is_deleted = @abap_false
    INTO TABLE @lt_metric_check.

  " Superponer las altas, modificaciones y borrados pendientes
  LOOP AT total.
    CHECK <action> = neuer_eintrag
       OR <action> = aendern
       OR <action> = geloescht
       OR <action> = update_geloescht
       OR <action> = neuer_geloescht.

    ASSIGN <vim_total_struc> TO <ls_metric> CASTING.

    DELETE TABLE lt_metric_check
      WITH TABLE KEY id = <ls_metric>-id.

    IF <action> <> geloescht
       AND <action> <> update_geloescht
       AND <action> <> neuer_geloescht
       AND <ls_metric>-is_deleted = abap_false.
      INSERT CORRESPONDING ty_metric_check( <ls_metric> )
        INTO TABLE lt_metric_check.
    ENDIF.
  ENDLOOP.

  lt_compare = lt_metric_check.
  SORT lt_compare BY product valid_from.

  " Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - G02A: ATC prioridad 2, recorrido por índices
  "   LOOP AT lt_compare INTO DATA(ls_left).
  "     DATA(lv_next) = sy-tabix + 1.
  "
  "     LOOP AT lt_compare INTO DATA(ls_right) FROM lv_next.
  "       IF ls_right-product <> ls_left-product
  "          OR ls_right-valid_from > ls_left-valid_to.
  "         EXIT.
  "       ENDIF.
  "
  "       IF ls_left-valid_from <= ls_right-valid_to
  "          AND ( ls_left-provider_company_code = ls_right-provider_company_code
  "             OR ls_left-provider_company_code IS INITIAL
  "             OR ls_right-provider_company_code IS INITIAL )
  "          AND ( ls_left-payment_type = ls_right-payment_type
  "             OR ls_left-payment_type IS INITIAL
  "             OR ls_right-payment_type IS INITIAL ).
  "
  "         DATA(lv_row_left) =
  "           |{ ls_left-provider_company_code }/{ ls_left-payment_type }/{ ls_left-metric } | &&
  "           |{ ls_left-valid_from DATE = ISO }-{ ls_left-valid_to DATE = ISO }|.
  "         DATA(lv_row_right) =
  "           |{ ls_right-provider_company_code }/{ ls_right-payment_type }/{ ls_right-metric } | &&
  "           |{ ls_right-valid_from DATE = ISO }-{ ls_right-valid_to DATE = ISO }|.
  "
  "         vim_abort_saving = abap_true.
  "         MESSAGE s398(00)
  "           WITH |Material { ls_left-product ALPHA = OUT }|
  "                lv_row_left
  "                lv_row_right
  "                'Vigencias superpuestas'
  "           DISPLAY LIKE 'E'.
  "         sy-subrc = 4.
  "         RETURN.
  "       ENDIF.
  "     ENDLOOP.
  "   ENDLOOP.

  DATA lv_left_index TYPE sy-tabix VALUE 1.
  DATA lv_right_index TYPE sy-tabix VALUE 2.
  DATA(lv_row_count) = lines( lt_compare ).

  WHILE lv_left_index < lv_row_count.
    IF lv_right_index > lv_row_count.
      lv_left_index = lv_left_index + 1.
      lv_right_index = lv_left_index + 1.
      CONTINUE.
    ENDIF.

    READ TABLE lt_compare INDEX lv_left_index INTO DATA(ls_left).
    READ TABLE lt_compare INDEX lv_right_index INTO DATA(ls_right).

    IF ls_right-product <> ls_left-product
       OR ls_right-valid_from > ls_left-valid_to.
      lv_left_index = lv_left_index + 1.
      lv_right_index = lv_left_index + 1.
      CONTINUE.
    ENDIF.

    IF ls_left-valid_from <= ls_right-valid_to
       AND ( ls_left-provider_company_code = ls_right-provider_company_code
          OR ls_left-provider_company_code IS INITIAL
          OR ls_right-provider_company_code IS INITIAL )
       AND ( ls_left-payment_type = ls_right-payment_type
          OR ls_left-payment_type IS INITIAL
          OR ls_right-payment_type IS INITIAL ).

      DATA(lv_row_left) =
        |{ ls_left-provider_company_code }/{ ls_left-payment_type }/{ ls_left-metric } | &&
        |{ ls_left-valid_from DATE = ISO }-{ ls_left-valid_to DATE = ISO }|.
      DATA(lv_row_right) =
        |{ ls_right-provider_company_code }/{ ls_right-payment_type }/{ ls_right-metric } | &&
        |{ ls_right-valid_from DATE = ISO }-{ ls_right-valid_to DATE = ISO }|.

      vim_abort_saving = abap_true.
      MESSAGE s398(00)
        WITH |Material { ls_left-product ALPHA = OUT }|
             lv_row_left
             lv_row_right
             'Vigencias superpuestas'
        DISPLAY LIKE 'E'.
      sy-subrc = 4.
      RETURN.
    ENDIF.

    lv_right_index = lv_right_index + 1.
  ENDWHILE.
  " Fin EXT_OSCUGALD 25.10.2026 - G02A

  GET TIME STAMP FIELD lv_changed_at.

  " Actualizar la auditoría en ambos buffers del generador
  LOOP AT total.
    IF <action> = neuer_eintrag OR <action> = aendern.
      DATA(lv_total_index) = sy-tabix.
      ASSIGN <vim_total_struc> TO <ls_metric> CASTING.

      READ TABLE extract WITH KEY <vim_xtotal_key>.
      IF sy-subrc = 0.
        DATA(lv_extract_index) = sy-tabix.
      ELSE.
        CLEAR lv_extract_index.
      ENDIF.

      <ls_metric>-last_changed_at = lv_changed_at.
      <ls_metric>-last_changed_by = sy-uname.
      <ls_metric>-local_last_changed_at = lv_changed_at.
      MODIFY total INDEX lv_total_index.

      IF lv_extract_index > 0.
        extract = total.
        MODIFY extract INDEX lv_extract_index.
      ENDIF.
    ENDIF.
  ENDLOOP.

  sy-subrc = 0.

ENDFORM.
" Fin EXT_OSCUGALD 25.10.2026 - G02A
