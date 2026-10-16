CLASS zcl_interco_cph_change_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_cph_change_status IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

*    SELECT * FROM zfi_a_intrc_cph
*        WHERE id IS NOT INITIAL
*        INTO TABLE @DATA(lt_proposal).
*
*    IF lt_proposal IS NOT INITIAL.
*
*      LOOP AT lt_proposal ASSIGNING FIELD-SYMBOL(<ls_cph>).
*        IF <ls_cph>-status = 'S'.
*            <ls_cph>-status = 'V'.
*        ENDIF.
*      ENDLOOP.
*
*      MODIFY zfi_a_intrc_cph FROM TABLE @lt_proposal.
*      COMMIT WORK.
*
*    ENDIF.
    TRY.
        DATA(gd_lastday) = zcl_interco_utils=>rp_last_day_of_months( day_in = |99999999| ).
      CATCH cx_sy_dynamic_osql_semantics INTO DATA(exc).
        DATA(lv_txt) = exc->get_text( ).
      CATCH cx_sy_conversion_no_date INTO DATA(NO_DATE).
        LV_TXT = NO_DATE->get_text( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
