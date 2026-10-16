class zcl_intrc_proposal_doccat_ve definition
  public
  final
  create public .

  public section.

    interfaces if_sadl_exit_calc_element_read .
  protected section.
  private section.
endclass.



class zcl_intrc_proposal_doccat_ve implementation.


  method if_sadl_exit_calc_element_read~calculate.
    data _categories type table of ZI_IntercoProposalDocCategory.
    _categories = corresponding #( it_original_data ).

    sort _categories by TypeID.
    loop at _categories reference into data(category).
      category->Postion = sy-tabix.
      category->Icon = switch #( category->typeid
                                    when 10 then 'sap-icon://receipt'
                                    when 20 then 'sap-icon://customer-order-entry'
                                    when 30 then 'sap-icon://sales-order-item'
                                    when 60 then 'sap-icon://measurement-document' ).
    endloop.

    ct_calculated_data = corresponding #( _categories ).

  endmethod.


  method if_sadl_exit_calc_element_read~get_calculation_info.
  endmethod.
endclass.
