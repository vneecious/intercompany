CLASS zcl_interco_brf_wht DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_sadl_exit .
    INTERFACES if_sadl_exit_calc_element_read .
    INTERFACES if_amdp_marker_hdb.

    TYPES: ty_doctype TYPE c LENGTH 2.

    CONSTANTS: BEGIN OF co_with_doctype,
                 sales           TYPE ty_doctype VALUE 'AR',
                 purchase        TYPE ty_doctype VALUE 'AP',
                 interdivisional TYPE ty_doctype VALUE 'ID',
                 inc_reclassif   TYPE ty_doctype VALUE 'RR',
                 exp_reclassif   TYPE ty_doctype VALUE 'RP',
                 sales_tax       TYPE ty_doctype VALUE 'XR',
                 purchases_tax   TYPE ty_doctype VALUE 'XP',
               END OF co_with_doctype.

    METHODS get_wht_code
      IMPORTING
        !iv_doctype       TYPE ty_doctype DEFAULT co_with_doctype-purchase
        !iv_provider      TYPE bukrs
        !iv_recipient     TYPE bukrs
        !iv_product       TYPE matnr
        !iv_whttype       TYPE zde_witht
      RETURNING
        VALUE(rv_whtcode) TYPE zde_wt_withcd .
    METHODS get_cc_code
      IMPORTING
        !iv_product       TYPE matnr OPTIONAL
        !iv_cuenta        TYPE hkont OPTIONAL
        !iv_cc_origen     TYPE c1 OPTIONAL
        !iv_departamento  TYPE zint_depto OPTIONAL
        !iv_tipo_doc      TYPE zint_txbr_doctype
      RETURNING
        VALUE(rv_cc_code) TYPE kostl .
    METHODS get_tax_code
      IMPORTING
        !iv_provider   TYPE bukrs
        !iv_recipient  TYPE bukrs
        !iv_product    TYPE matnr
      EXPORTING
*        !ea_value      TYPE zstr_tax_code
        !ev_taxcode_ap TYPE zde_witht
        !ev_taxcode_ar TYPE zde_witht .
    CLASS-METHODS get_ampd_cc_code
        FOR TABLE FUNCTION zi_costcentercode_brf.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_brf_wht IMPLEMENTATION.


  METHOD get_wht_code.

    DATA: lo_factory                  TYPE REF TO if_fdt_factory.

    lo_factory = cl_fdt_factory=>get_instance( EXPORTING iv_application_id = '42010A5501381FE092A5FB86C30EAF20' ).
    DATA(lo_fuction) = lo_factory->get_function( '42010A5501381FE092A60946B2F90F20' ).
    DATA(lo_context) = lo_fuction->get_process_context( ).

    lo_context->set_value( iv_name = 'DOCTYPE' ia_value = iv_doctype ).
    lo_context->set_value( iv_name = 'PROVIDER' ia_value = iv_provider ).
    lo_context->set_value( iv_name = 'RECIPIENT' ia_value = iv_recipient ).
    lo_context->set_value( iv_name = 'PRODUCT' ia_value = iv_product ).
    lo_context->set_value( iv_name = 'WHTTYPE' ia_value = iv_whttype ).

    lo_fuction->process( EXPORTING io_context = lo_context
                         IMPORTING eo_result  = DATA(lo_result) ).

    IF lo_result IS NOT INITIAL.
      DATA(lo_object) = lo_result->get_data_object(      ).
      lo_result->get_value( IMPORTING ea_value = rv_whtcode ).
    ENDIF.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.

    READ TABLE it_requested_calc_elements INTO DATA(lv_element_name) INDEX 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE lv_element_name.
      WHEN 'WITHHOLDINGTAX'.

        DATA: lt_wht_data TYPE STANDARD TABLE OF zc_withholding_taxes WITH DEFAULT KEY.
        MOVE-CORRESPONDING it_original_data TO lt_wht_data.

        LOOP AT lt_wht_data ASSIGNING FIELD-SYMBOL(<wht_interco>).
          <wht_interco>-withholdingtax = me->get_wht_code(
            iv_provider  = <wht_interco>-companycode
            iv_recipient = <wht_interco>-companycode
            iv_product   = 'ICSRV24'
            iv_whttype   = <wht_interco>-withholdingtaxtype ).
        ENDLOOP.

        MOVE-CORRESPONDING lt_wht_data TO ct_calculated_data.
      WHEN 'COSTCENTERCODE'.

        DATA: lt_cost_data TYPE STANDARD TABLE OF zc_intecoproposalitembaogl2 WITH DEFAULT KEY.
*        MOVE-CORRESPONDING it_original_data TO lt_cost_data.
*
*        LOOP AT lt_cost_data ASSIGNING FIELD-SYMBOL(<cost_item>).
*          <cost_item>-CostCenterCode = me->get_cc_code(
*            iv_product       = <cost_item>-Product
*            iv_consolidation = <cost_item>-ccconsolidation ).
*        ENDLOOP.
      WHEN 'TAXCODE'.


    ENDCASE.
*    DATA : lt_calculated_data TYPE STANDARD TABLE OF zc_withholding_taxes WITH DEFAULT KEY.
*
*    MOVE-CORRESPONDING it_original_data TO lt_calculated_data.
*
*    LOOP AT lt_calculated_data ASSIGNING FIELD-SYMBOL(<wht_interco>).
*      <wht_interco>-withholdingtax = me->get_wht_code(
*                                       iv_provider     = <wht_interco>-CompanyCode          " Sociedad
*                                       iv_recipient    = <wht_interco>-CompanyCode          " Sociedad
*                                       iv_product      = 'ICSRV24'                          " Número de material
*                                       iv_whttype      = <wht_interco>-WithholdingTaxType   " Indicador tipo de retenciones BRF+
*                                     ).
*
*    ENDLOOP.
*
*    MOVE-CORRESPONDING lt_calculated_data TO ct_calculated_data.
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
  ENDMETHOD.


  METHOD get_cc_code.
    DATA: lo_factory                  TYPE REF TO if_fdt_factory.

    lo_factory = cl_fdt_factory=>get_instance( EXPORTING iv_application_id = '42010A5501381FE098996E9F3A05B26A' ).
    DATA(lo_fuction) = lo_factory->get_function( '42010A5501381FE0989974727E83526A' ).
    DATA(lo_context) = lo_fuction->get_process_context( ).

    lo_context->set_value( iv_name = 'CC_ORIGEN_4' ia_value = iv_cc_origen ).
    lo_context->set_value( iv_name = 'CUENTA' ia_value = iv_cuenta ).
    lo_context->set_value( iv_name = 'DEPARTAMENTO' ia_value = iv_departamento ).
    lo_context->set_value( iv_name = 'MATERIAL' ia_value = iv_product ).
    lo_context->set_value( iv_name = 'TIPO_DOC' ia_value = iv_tipo_doc ).
    lo_fuction->process( EXPORTING io_context = lo_context
                         IMPORTING eo_result  = DATA(lo_result) ).

    IF lo_result IS NOT INITIAL.
      DATA(lo_object) = lo_result->get_data_object(      ).
      lo_result->get_value( IMPORTING ea_value = rv_cc_code ).
    ENDIF.

  ENDMETHOD.


  METHOD get_tax_code.
    DATA: lo_factory  TYPE REF TO if_fdt_factory,
          lo_function TYPE REF TO if_fdt_function,
          lo_context  TYPE REF TO if_fdt_context,
          lo_result   TYPE REF TO if_fdt_result,
          lv_value    TYPE string.
    DATA: ls_result TYPE zstr_tax_code.


    TRY.
        " Obtener instancia de la fábrica y función BRF+
        lo_factory = cl_fdt_factory=>get_instance(
          EXPORTING
            iv_application_id = '42010A5501381FE09897F49C9A7C3265' ).

        lo_function = lo_factory->get_function( '42010A5501381FE0989903A2C7F99268' ).
        lo_context  = lo_function->get_process_context( ).

        " Setear parámetros de entrada
        lo_context->set_value( iv_name = 'COMPCODE_PROVIDER' ia_value = iv_provider ).
        lo_context->set_value( iv_name = 'COMPCODE_RECIPIENT' ia_value = iv_recipient ).
        lo_context->set_value( iv_name = 'MATERIAL' ia_value = iv_product ).


        " Ejecutar BRF+
        lo_function->process(
          EXPORTING
            io_context = lo_context
          IMPORTING
            eo_result  = lo_result ).

        " Si hay resultado, obtener valor escalar
        IF lo_result IS BOUND.
          lo_result->get_value(
            EXPORTING
              iv_id    = '42010A5501381FE09898AF64CA21D266'
*             iv_name  =
            IMPORTING
*              ea_value = ev_taxcode_ap
              ea_value = ls_result
          ).

          ev_taxcode_ap = ls_result-tax_code_ap.

          lo_result->get_value(
            EXPORTING
              iv_id    = '42010A5501381FE09898B37742969267'
*             iv_name  =
            IMPORTING
*              ea_value = ev_taxcode_ar
              ea_value = ls_result
          ).

          ev_taxcode_ar = ls_result-tax_code_ar.
        ENDIF.
      CATCH cx_root INTO DATA(lx_error).
    ENDTRY.

  ENDMETHOD.
  METHOD get_ampd_cc_code BY DATABASE FUNCTION FOR HDB LANGUAGE SQLSCRIPT OPTIONS READ-ONLY USING zi_intercoproposalitembaogl2.
*    DATA(lv_ceco_code) = me->get_cc_code(
*            iv_product       = <cost_item>-Product
*            iv_consolidation = <cost_item>-ccconsolidation )

    t_main = select _baogl.mandt, _baogl.product, _baogl.ccconsolidation
    from zi_intercoproposalitembaogl2 as _baogl
    where _baogl.mandt = i_mandt
          and _baogl.product = i_product
          and _baogl.ccconsolidation = i_cconsolidation;

    RETURN select _baogl.mandt, _baogl.product, _baogl.ccconsolidation, '' as costcentercode
    from zi_intercoproposalitembaogl2 as _baogl
    where _baogl.mandt = i_mandt
          and _baogl.product = i_product
          and _baogl.ccconsolidation = i_cconsolidation;
*    t_ceco_code = LOOP AT t_main ASSIGNING FIELD-SYMBOL(<cost_item>).
*          <cost_item>-CostCenterCode = me->get_cc_code(
*            iv_product       = <cost_item>-Product
*            iv_consolidation = <cost_item>-ccconsolidation ).
*        ENDLOOP.
  ENDMETHOD.

ENDCLASS.
