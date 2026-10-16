CLASS zcl_interco_brf_exemptions DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_sadl_exit_calc_element_read.

    METHODS get_exemptions
      IMPORTING
        !iv_payment_date         TYPE sy-datum
        !iv_provider_company     TYPE bukrs
        !iv_recipient_company    TYPE bukrs OPTIONAL
        !iv_product_concept      TYPE matnr OPTIONAL
        !iv_p_and_l_id           TYPE hrynode OPTIONAL
        !iv_profit_center        TYPE prctr OPTIONAL
        !iv_cost_center          TYPE kostl OPTIONAL
        !iv_account_number       TYPE saknr
        !iv_payment_allocation   TYPE zint_dte_pay_allocation OPTIONAL
      RETURNING
        VALUE(rv_is_not_bilable) TYPE abap_boolean .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_brf_exemptions IMPLEMENTATION.


  METHOD get_exemptions.
    DATA: lo_factory                  TYPE REF TO if_fdt_factory.

    lo_factory = cl_fdt_factory=>get_instance( EXPORTING iv_application_id = '42010A5501381EDFA2F7C06FCB76409C' ).
    DATA(lo_fuction) = lo_factory->get_function( '42010A5501381EDFA3AE205F45EF445C' ).
    DATA(lo_context) = lo_fuction->get_process_context( ).

    lo_context->set_value( iv_name = 'PAYMENT_DATE' ia_value = iv_payment_date ).
    lo_context->set_value( iv_name = 'PROVIDER_COMPANY_CODE' ia_value = iv_provider_company ).
    lo_context->set_value( iv_name = 'RECIPIENT_COMPANY_CODE' ia_value = iv_recipient_company ).
    lo_context->set_value( iv_name = 'PRODUCT_CONCEPT' ia_value = iv_product_concept ).
    lo_context->set_value( iv_name = 'P_L_ID' ia_value = iv_p_and_l_id ).
    lo_context->set_value( iv_name = 'PROFIT_CENTER' ia_value = iv_profit_center ).
    lo_context->set_value( iv_name = 'COST_CENTER' ia_value = iv_cost_center ).
    lo_context->set_value( iv_name = 'ACCOUNT_NUMBER' ia_value = iv_account_number ).
    lo_context->set_value( iv_name = 'PAYMENT_ALLOCATION' ia_value = iv_payment_allocation ).

    lo_fuction->process( EXPORTING io_context =  lo_context
                         IMPORTING eo_result  =  DATA(lo_result) ).

    IF lo_result IS NOT INITIAL.
      DATA(lo_object) = lo_result->get_data_object(      ).
      lo_result->get_value( IMPORTING ea_value = rv_is_not_bilable ).
    ENDIF.

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.
    DATA : lt_calculated_data TYPE STANDARD TABLE OF zc_test_interco_statement_2 WITH DEFAULT KEY.

    MOVE-CORRESPONDING it_original_data TO lt_calculated_data.

    LOOP AT lt_calculated_data ASSIGNING FIELD-SYMBOL(<interco>).
      <interco>-IsNotBilabeExemptions = me->get_exemptions(
                                                iv_payment_date = sy-datum
                                                iv_provider_company =  <interco>-SapEntity "'MLA'
                                                iv_recipient_company =  'MLC'
                                                iv_product_concept = <interco>-Concept
                                                iv_p_and_l_id = <interco>-IdL0
                                                iv_profit_center = <interco>-ProfitCenter
                                                iv_cost_center = <interco>-CostCenter
                                                iv_account_number = <interco>-GLAccount
                                                "iv_payment_allocation = <interco>-Allocation
      ).
    ENDLOOP.

    MOVE-CORRESPONDING lt_calculated_data TO ct_calculated_data.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
*    et_requested_orig_elements = VALUE #( BASE IT_REQUESTED_CALC_ELEMENTS
*                                          ( CONV #( 'ISNOTBILABEEXEMPTIONS' ) )
*                                        ).
  ENDMETHOD.
ENDCLASS.
