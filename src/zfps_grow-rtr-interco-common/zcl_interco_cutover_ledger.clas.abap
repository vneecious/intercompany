CLASS zcl_interco_cutover_ledger DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.

CLASS zcl_interco_cutover_ledger IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    CONSTANTS gc_step TYPE c length 40 VALUE 'LEDGER_MD_CR_BACKFILL'.

    SELECT SINGLE * FROM zint_a_cutover
      WHERE cutover_step = @gc_step
      INTO @DATA(ls_log).

    IF sy-subrc = 0.
      out->write( 'Este cutover ya fue ejecutado.' ).
      out->write( |Fecha/hora (UTC): { ls_log-executed_at }| ).
      out->write( |Usuario: { ls_log-executed_by }| ).
      out->write( |Filas actualizadas en su momento: { ls_log-rows_affected }| ).
      out->write( 'No se puede volver a ejecutar.' ).
      RETURN.
    ENDIF.

    UPDATE zint_a_md_cr SET ledger = '0L' WHERE ledger = ''.
    DATA(lv_rows) = sy-dbcnt.

    INSERT zint_a_cutover FROM @( VALUE #(
      cutover_step  = gc_step
      executed_at   = utclong_current( )
      executed_by   = cl_abap_context_info=>get_user_technical_name( )
      rows_affected = lv_rows ) ).

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      out->write( 'Error: el control de cutover ya fue registrado por otra ejecucion concurrente - se revirtio el UPDATE.' ).
      RETURN.
    ENDIF.

    COMMIT WORK.

    out->write( 'Cutover ejecutado correctamente.' ).
    out->write( |{ lv_rows } filas actualizadas en ZINT_A_MD_CR (ledger = '0L').| ).

  ENDMETHOD.

ENDCLASS.
