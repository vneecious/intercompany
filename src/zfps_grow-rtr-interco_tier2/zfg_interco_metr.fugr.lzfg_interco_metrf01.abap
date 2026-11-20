*----------------------------------------------------------------------*
***INCLUDE LZFG_INTERCO_METRF01.
*----------------------------------------------------------------------*
" Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - G02A: alta SM30 de métrica
" FORM g02a_crear_entrada.
" ENDFORM.
FORM g02a_crear_entrada RAISING cx_uuid_error.

  zint_a_md_metric-id =
    cl_system_uuid=>create_uuid_x16_static( ).

  GET TIME STAMP FIELD zint_a_md_metric-created_at.
  zint_a_md_metric-created_by = sy-uname.

ENDFORM.
" Fin EXT_OSCUGALD 25.10.2026 - G02A
