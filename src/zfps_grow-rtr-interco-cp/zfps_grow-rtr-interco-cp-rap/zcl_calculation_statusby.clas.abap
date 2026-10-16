CLASS zcl_calculation_statusby DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

*    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_calculation_statusby IMPLEMENTATION.


  METHOD if_sadl_exit_calc_element_read~calculate.
    TYPES: "#EC_CHAIN_DECL_USAG
      BEGIN OF lty_datagrp,
        status     TYPE ZI_IntercoProposalStatus_SH-Status,
        statusname TYPE ZI_IntercoProposalStatus_SH-StatusName,
        count      TYPE int4,
      END OF lty_datagrp,
      ltty_datagrp TYPE STANDARD TABLE OF lty_datagrp WITH EMPTY KEY.
    DATA: lt_calculated_data TYPE STANDARD TABLE OF ZC_IntercoProposalTP WITH EMPTY KEY,
          lt_datagrp         TYPE STANDARD TABLE OF lty_datagrp WITH NON-UNIQUE KEY status, statusname.

    CHECK NOT it_original_data IS INITIAL.
    MOVE-CORRESPONDING it_original_data TO lt_calculated_data.

    CHECK ( lt_calculated_data[] IS NOT INITIAL )."Used for ATC
    SELECT _sh~status, _sh~statusname, COUNT( _h~id ) AS count
    FROM zfi_a_intrc_cph AS _h
    INNER JOIN ZI_IntercoProposalStatus_SH AS _sh ON _h~status EQ _sh~status
    GROUP BY _sh~status, _sh~StatusName
    INTO TABLE @lt_datagrp.

    IF sy-subrc NE 0.
*      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>entity_not_known.
    ENDIF.

*    DATA(lt_sum) = VALUE ltty_datagrp( FOR GROUPS <groups> OF <group_line> IN lt_calculated_data
*                                               GROUP BY (                           status     = <group_line>-Status
*                                                                                    statusname = <group_line>-statusname )
*                                               LET coll_line = REDUCE #( INIT line TYPE lty_datagrp
*                                                                         FOR <m> IN GROUP <groups>
*                                                                         NEXT       line-status = <m>-status
*                                                                                    line-statusname = <m>-statusname
*                                                                                    line-count = line-count + 1 )
*                                               IN (                                            coll_line )
*    ).


    LOOP AT lt_calculated_data ASSIGNING FIELD-SYMBOL(<ls_calculated_data>).
*        Validate double currency
      TRY.
          DATA(ls_summarized) = lt_datagrp[ status = <ls_calculated_data>-status ].
*          CASE <ls_calculated_data>-Status.
*            WHEN space.
*              <ls_calculated_data>-SumPending = ls_summarized-count.
*            WHEN 'C'.
*              <ls_calculated_data>-SumCalculated = ls_summarized-count.
*            WHEN 'I'.
*              <ls_calculated_data>-SumInvoiced = ls_summarized-count.
*            WHEN 'A'.
*              <ls_calculated_data>-SumAnulated = ls_summarized-count.
*          ENDCASE.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.
    ENDLOOP.
    MOVE-CORRESPONDING lt_calculated_data TO ct_calculated_data.

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    IF iv_entity <> 'ZC_INTERCOPROPOSALTP'.
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>entity_not_known.
    ENDIF.
*    IF line_exists( it_requested_calc_elements[ table_line = 'GROSSAMOUNTWITHDISCOUNT' ] ).
*      APPEND 'CONVERTEDGROSSAMOUNT' TO et_requested_orig_elements.
*    ENDIF.
  ENDMETHOD.
ENDCLASS.
