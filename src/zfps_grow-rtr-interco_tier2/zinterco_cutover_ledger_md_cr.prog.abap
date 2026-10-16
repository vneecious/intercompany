REPORT zinterco_cutover_ledger_md_cr.

CONSTANTS: gc_step_eba TYPE char40 VALUE 'LEDGER_MD_CR_EBA_L1',
           gc_step_all TYPE char40 VALUE 'LEDGER_MD_CR_BACKFILL'.

START-OF-SELECTION.

  " ═══ PASO 1 — EBA + ICSRV52/53/54/55 → Ledger 'L1' (debe ejecutarse ANTES del backfill general) ═══
  SELECT SINGLE * FROM zint_a_cutover
    WHERE cutover_step = @gc_step_eba
    INTO @DATA(ls_log_eba).

  IF sy-subrc = 0.
    WRITE: / 'Paso 1 (EBA -> L1) ya fue ejecutado. Se omite.'.
    WRITE: / '  Fecha/hora (UTC):', ls_log_eba-executed_at.
    WRITE: / '  Usuario:', ls_log_eba-executed_by.
    WRITE: / '  Filas actualizadas en su momento:', ls_log_eba-rows_affected.
  ELSE.
    UPDATE zint_a_md_cr SET ledger = 'L1'
      WHERE ledger = ''
        AND company_code = 'EBA'
        AND product IN ( 'ICSRV52', 'ICSRV53', 'ICSRV54', 'ICSRV55' ).
    DATA(lv_rows_eba) = sy-dbcnt.

    INSERT zint_a_cutover FROM @( VALUE #(
      cutover_step  = gc_step_eba
      executed_at   = utclong_current( )
      executed_by   = cl_abap_context_info=>get_user_technical_name( )
      rows_affected = lv_rows_eba ) ).

    IF sy-subrc <> 0.
      ROLLBACK WORK.
      WRITE: / 'Error en Paso 1: el control de cutover ya fue registrado por otra ejecucion concurrente - se revirtio el UPDATE.'.
      RETURN.
    ENDIF.

    COMMIT WORK.
    WRITE: / 'Paso 1 (EBA -> L1) ejecutado correctamente.'.
    WRITE: / '  ', lv_rows_eba, 'filas actualizadas en ZINT_A_MD_CR (ledger = ''L1'').'.
  ENDIF.

  SKIP.

  " ═══ PASO 2 — Backfill general: resto de las reglas → Ledger '0L' ═══
  SELECT SINGLE * FROM zint_a_cutover
    WHERE cutover_step = @gc_step_all
    INTO @DATA(ls_log_all).

  IF sy-subrc = 0.
    WRITE: / 'Paso 2 (backfill general -> 0L) ya fue ejecutado. Se omite.'.
    WRITE: / '  Fecha/hora (UTC):', ls_log_all-executed_at.
    WRITE: / '  Usuario:', ls_log_all-executed_by.
    WRITE: / '  Filas actualizadas en su momento:', ls_log_all-rows_affected.
    RETURN.
  ENDIF.

  UPDATE zint_a_md_cr SET ledger = '0L' WHERE ledger = ''.
  DATA(lv_rows_all) = sy-dbcnt.

  INSERT zint_a_cutover FROM @( VALUE #(
    cutover_step  = gc_step_all
    executed_at   = utclong_current( )
    executed_by   = cl_abap_context_info=>get_user_technical_name( )
    rows_affected = lv_rows_all ) ).

  IF sy-subrc <> 0.
    ROLLBACK WORK.
    WRITE: / 'Error en Paso 2: el control de cutover ya fue registrado por otra ejecucion concurrente - se revirtio el UPDATE.'.
    RETURN.
  ENDIF.

  COMMIT WORK.

  WRITE: / 'Paso 2 (backfill general -> 0L) ejecutado correctamente.'.
  WRITE: / '  ', lv_rows_all, 'filas actualizadas en ZINT_A_MD_CR (ledger = ''0L'').'.
