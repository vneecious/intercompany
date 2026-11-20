*&---------------------------------------------------------------------*
*& Include          LZFG_INTERCO_METRO01
*&---------------------------------------------------------------------*
" Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - G02A: ocultar columnas técnicas SM30
MODULE g02a_ocultar_columnas OUTPUT.

  LOOP AT tctrl_zint_a_md_metric-cols
    ASSIGNING FIELD-SYMBOL(<ls_column>).
    CASE <ls_column>-screen-name.
      WHEN 'ZINT_A_MD_METRIC-ID'
        OR 'ZINT_A_MD_METRIC-CREATED_AT'
        OR 'ZINT_A_MD_METRIC-CREATED_BY'
        OR 'ZINT_A_MD_METRIC-LAST_CHANGED_AT'
        OR 'ZINT_A_MD_METRIC-LAST_CHANGED_BY'
        OR 'ZINT_A_MD_METRIC-LOCAL_LAST_CHANGED_AT'.
        <ls_column>-invisible = abap_true.
    ENDCASE.
  ENDLOOP.

ENDMODULE.
" Fin EXT_OSCUGALD 25.10.2026 - G02A
