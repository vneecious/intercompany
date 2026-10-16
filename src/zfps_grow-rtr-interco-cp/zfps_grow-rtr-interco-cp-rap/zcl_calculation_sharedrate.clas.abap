class zcl_calculation_sharedrate definition
  public
  final
  create public .

  public section.

*    INTERFACES if_sadl_exit .
    interfaces if_sadl_exit_calc_element_read .
  protected section.
  private section.
endclass.



class zcl_calculation_sharedrate implementation.


  method if_sadl_exit_calc_element_read~calculate.
    types: "#EC_CHAIN_DECL_USAG
      begin of lty_datagrp,
        id                          type zfi_a_intrc_cpib-id,
        item_id                     type zfi_a_intrc_cpib-item_id,
        itembasis_id                type zfi_a_intrc_cpib-itembasis_id,
        sharedrate                  type zfi_a_intrc_cpib-sharedrate,
        globalcurrency              type zfi_a_intrc_cpib-globalcurrency,
        amountinglobalcurrency      type zfi_a_intrc_cpib-amountinglobalcurrency,
        companycodecurrency         type zfi_a_intrc_cpib-companycodecurrency,
        amountincompanycodecurrency type zfi_a_intrc_cpib-amountincompanycodecurrency,
        avgrate                     type zfi_a_intrc_cpib-sharedrate,
      end of lty_datagrp,
      ltty_datagrp type standard table of lty_datagrp with empty key.
    data: lt_calculated_data type standard table of ZC_IntercoProposalItemTP with empty key,
          "lt_calculated_data TYPE STANDARD TABLE OF ZI_IntercoProposalItem WITH EMPTY KEY,
          lt_datagrp         type standard table of lty_datagrp with non-unique key id, item_id, itembasis_id.

    check not it_original_data is initial.
    move-corresponding it_original_data to lt_calculated_data.

    check ( lt_calculated_data[] is not initial )."Used for ATC
    select id, item_id, itembasis_id, sharedrate, globalcurrency,
    amountinglobalcurrency, companycodecurrency, amountincompanycodecurrency
    from zfi_a_intrc_cpib
    for all entries in @lt_calculated_data
    where id eq @lt_calculated_data-id
     and item_id eq @lt_calculated_data-item_id
    order by primary key
    into table @lt_datagrp.

    if sy-subrc ne 0.
*      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>entity_not_known.
    endif.

    data(lt_summarized) = value ltty_datagrp( for groups <groups> of <group_line> in lt_datagrp
                                              group by (                           id                               = <group_line>-id
                                                                                   item_id                          = <group_line>-item_id
                                                                                   globalcurrency                   = <group_line>-globalcurrency
                                                                                   companycodecurrency              = <group_line>-companycodecurrency )
                                              let coll_line = reduce #( init line type lty_datagrp
                                              cntl type i
                                              sumrate type zfi_a_intrc_cpib-sharedrate
                                                                        for <m> in group <groups>
                                                                        next       line-id                          = <m>-id
                                                                                   line-item_id                     = <m>-item_id
                                                                                   cntl                             = cntl + 1
                                                                                   sumrate                          = sumrate + <m>-sharedrate
                                                                                   line-avgrate                     = sumrate / cntl
                                                                                   line-globalcurrency              = <m>-globalcurrency
                                                                                   line-amountinglobalcurrency      = line-amountinglobalcurrency + <m>-amountinglobalcurrency
                                                                                   line-companycodecurrency         = <m>-companycodecurrency
                                                                                   line-amountincompanycodecurrency = line-amountincompanycodecurrency + <m>-amountincompanycodecurrency )
                                              in (                                                                  coll_line )
    ).


    loop at lt_calculated_data assigning field-symbol(<ls_calculated_data>).
*        Validate double currency
      try.
          data(ls_summarized) = lt_summarized[ id = <ls_calculated_data>-Id
                                      item_id = <ls_calculated_data>-Item_Id ].
          <ls_calculated_data>-sharedrate = ls_summarized-avgrate.
          if <ls_calculated_data>-ProviderCountry eq <ls_calculated_data>-RecipientCountry.
            " VINICIUS: INSERT - para mejor visualizacion, se genero un campo unico en la vista para ambos escenarios ->
*            <ls_calculated_data>-amountinsharecurrency = ls_summarized-amountincompanycodecurrency.
*            <ls_calculated_data>-sharecurrency =  ls_summarized-companycodecurrency.
            " VINICIUS: INSERT <-
            <ls_calculated_data>-companycodecurrency = ls_summarized-companycodecurrency.
            <ls_calculated_data>-amountincompanycodecurrency = ls_summarized-amountincompanycodecurrency.
          else.
            " VINICIUS: INSERT - para mejor visualizacion, se genero un campo unico en la vista para ambos escenarios ->
*            <ls_calculated_data>-amountinsharecurrency = ls_summarized-amountinglobalcurrency.
*            <ls_calculated_data>-sharecurrency =  ls_summarized-globalcurrency.
            " VINICIUS: INSERT <-
            <ls_calculated_data>-globalcurrency = ls_summarized-globalcurrency.
            <ls_calculated_data>-amountinglobalcurrency = ls_summarized-amountinglobalcurrency.
          endif.
        catch cx_sy_itab_line_not_found.
      endtry.
    endloop.
    move-corresponding lt_calculated_data to ct_calculated_data.

  endmethod.


  method if_sadl_exit_calc_element_read~get_calculation_info.
    if iv_entity <> 'ZC_INTERCOPROPOSALITEMTP'.
      raise exception type zcx_calc_exit exporting textid = zcx_calc_exit=>entity_not_known.
    endif.
*    IF line_exists( it_requested_calc_elements[ table_line = 'GROSSAMOUNTWITHDISCOUNT' ] ).
*      APPEND 'CONVERTEDGROSSAMOUNT' TO et_requested_orig_elements.
*    ENDIF.
  endmethod.
endclass.
