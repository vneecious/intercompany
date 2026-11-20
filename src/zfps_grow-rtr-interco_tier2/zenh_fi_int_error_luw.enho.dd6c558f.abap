"Name: \FU:FI_INT_ERROR_HANDLING\SE:END\EI
ENHANCEMENT 0 ZENH_FI_INT_ERROR_LUW.
IF sy-msgty = 'A' OR sy-msgty = 'E'.
  zcl_fi_int_luw_coordinator=>on_group_error(
    is_ipf      = cs_ipf
    it_items    = ct_intit_extf[]
    iv_message  = |FINT error { sy-msgid }-{ sy-msgno }: { sy-msgv1 } { sy-msgv2 }| ).
ENDIF.
ENDENHANCEMENT.
