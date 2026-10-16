CLASS zcl_chdo_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_chdo_util IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA:
      ls_error      TYPE abap_bool,
      rt_errors     TYPE if_chdo_object_tools_rel=>ty_tr_error_tab,
      lt_errors_err TYPE LINE OF if_chdo_object_tools_rel=>ty_tr_error_tab,
      p_it_tcdob    TYPE if_chdo_object_tools_rel=>ty_tcdobdef_tab,
      p_it_tcdobt   TYPE if_chdo_object_tools_rel=>ty_tcdobtext_tab,
      p_it_tcdrp    TYPE if_chdo_object_tools_rel=>ty_tcdgen,
      lt_tcdobt     TYPE if_chdo_object_tools_rel=>ty_tcdobt_tabtyp,
      ls_tcdob      TYPE LINE OF if_chdo_object_tools_rel=>ty_tcdobdef_tab,
      ls_tcdobt     TYPE LINE OF if_chdo_object_tools_rel=>ty_tcdobtext_tab.
    DATA: lr_err                TYPE REF TO cx_chdo_generation_error.

    p_it_tcdob = VALUE #( ( tabname  = 'ZINT_A_MD002'
                            multcase = ' '
                            docudel  = ' '
                            docuins  = ' '
                            docud_if = ' ' ) ).

    p_it_tcdobt = VALUE #( ( lang_key   = sy-langu
                             object_text  = 'CDO for ZINT_A_MD002' ) ).

    p_it_tcdrp-author   = sy-uname.
    p_it_tcdrp-textcase = 'X'.
*    p_it_tcdrp-devclass = 'ZCL_INT_D_MD003_CHDO'.
    p_it_tcdrp-devclass = 'ZINTERCO_SL_MD_RAP'.
*    p_it_tcdrp-devclass = 'ZINTERCO_SL_MD_DB'.

    CLEAR: rt_errors, lr_err.
    TRY.
      cl_chdo_object_tools_rel=>if_chdo_object_tools_rel~create_and_generate_object(
        EXPORTING
          iv_object          = 'ZINT_A_MD002_CH' " change document object name
          it_cd_object_def   = p_it_tcdob   " change document object definition
          it_cd_object_text  = p_it_tcdobt  " change document object text
          is_cd_object_gen   = p_it_tcdrp   " change document object generation info
          iv_cl_overwrite    = 'X'          " class overwrite flag
          iv_corrnr          = 'DS4K9A352D' " transport request number
        IMPORTING
          et_errors          = rt_errors    " generation message table
*          et_synt_errors     =
*          et_synt_error_long =
      ).
      CATCH cx_chdo_generation_error into lr_err.
        out->write( |Exception occurred: { lr_err->get_text( ) }| ).
        ls_error = 'X'.
    ENDTRY.
      IF ls_error IS INITIAL.
        READ TABLE rt_errors WITH KEY kind = 'E-'
                                 INTO lt_errors_err.
        IF sy-subrc IS INITIAL.
          out->write( |Exception occurred: { lt_errors_err-text } | ).
        ELSE.
          out->write( |Change document object created and generated | ).
        ENDIF.
      ENDIF.

  ENDMETHOD.
ENDCLASS.
