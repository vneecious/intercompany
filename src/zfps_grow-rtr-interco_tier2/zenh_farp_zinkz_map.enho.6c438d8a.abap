"Name: \TY:CL_FARP_ITEM_MASS_CHANGE\ME:MAP_EXT_PARAM_TO_INT\SE:BEGIN\EI
ENHANCEMENT 0 ZENH_FARP_ZINKZ_MAP.

" Enhancement: soporte para campo Bloqueo de Intereses (ZINKZ)
" Ticket: SDFPSINIC-23382 - Intereses por Mora Intercompany MLA
DATA lv_mora_active TYPE tvarvc-low.
TRY.
    NEW zcl_tvarvc( )->get_parameter(
      EXPORTING i_name  = 'ZFI_MORA_INT_ACTIVE'
      IMPORTING e_value = lv_mora_active ).
  CATCH zcx_tvarvc.
    CLEAR lv_mora_active.
ENDTRY.

IF lv_mora_active = 'X' AND iv_ext_name = 'InterestBlockIndicator'.
  rv_ext_name = 'ZINKZ'.
  RETURN.
ENDIF.

ENDENHANCEMENT.
