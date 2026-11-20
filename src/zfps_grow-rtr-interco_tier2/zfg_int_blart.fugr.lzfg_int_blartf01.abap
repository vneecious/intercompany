*----------------------------------------------------------------------*
***INCLUDE LZFG_INT_BLARTF01.
*----------------------------------------------------------------------*
FORM m01_crear_entrada RAISING cx_uuid_error.

  " Ini Facturación Local CH/ARG EXT_OSCUGALD 25.10.2026 - M01: UUID
  zint_a_md_blart-id = cl_system_uuid=>create_uuid_x16_static( ).
  " Fin EXT_OSCUGALD 25.10.2026 - M01

ENDFORM.
