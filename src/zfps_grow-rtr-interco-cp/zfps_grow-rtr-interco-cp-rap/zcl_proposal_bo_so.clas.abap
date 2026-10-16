CLASS zcl_proposal_bo_so DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: gsty_SOItem  TYPE STRUCTURE FOR CREATE I_SalesOrderTP\_Item,
           gsty_glitems TYPE LINE OF gsty_SOItem-%target.
    DATA gtc_salesorder   TYPE TABLE FOR CREATE I_SalesOrderTP.
    DATA gtc_SOitemcba    TYPE TABLE FOR CREATE I_SalesOrderTP\_Item.
    DATA gtc_SOPricingcba TYPE TABLE FOR CREATE i_salesorderitemtp\_ItemPricingElement.
    DATA gtd_documents    TYPE STANDARD TABLE OF I_SalesOrderTP-SalesOrder.
    DATA gtd_documentkey  TYPE STANDARD TABLE OF zfi_a_intrc_cpid-DocumentKey.
    DATA gt_doc_map_bd    TYPE gtty_doc.
    DATA gtd_list_bo      TYPE cl_abap_parallel=>t_in_inst_tab.

  PROTECTED SECTION.
    METHODS exe_bo         REDEFINITION.
    METHODS exe_anulation_bo_sec REDEFINITION.
    METHODS mapping_bo_sec REDEFINITION.
    METHODS mapping_reverse_sec REDEFINITION.
    METHODS preparedata_reverse REDEFINITION.

  PRIVATE SECTION.

    METHODS get_salesorderdata
      IMPORTING
                !is_proposalheader TYPE zi_intercoproposal
                !it_proposalitems  LIKE gtd_items_add
      EXPORTING
                !et_soheader       LIKE gtc_salesorder
                !et_soitems        LIKE gtc_soitemcba
                !et_soprincing     LIKE gtc_sopricingcba
                !et_doc_map        TYPE gtty_doc
      RAISING   zcx_calc_exit.
    METHODS add_item_pricing
      IMPORTING
        !iv_salesorder_cid TYPE abp_behv_cid OPTIONAL
        !iv_items_cid      TYPE abp_behv_cid
        !iv_pricing_cid    TYPE abp_behv_cid
*        !iv_soh_idx        TYPE gsty_glitems-SalesOrderItem
        !IV_soi_idx        TYPE gsty_glitems-SalesOrderItem
        !iv_soip_idx       TYPE gsty_glitems-SalesOrderItem
        !iv_condtype       TYPE i_salesorderitemprcgelmnttp-conditiontype
        !iv_rate           TYPE i_salesorderitemprcgelmnttp-conditionrateamount
        !iv_currency       TYPE i_salesorderitemprcgelmnttp-conditioncurrency OPTIONAL
        !iv_CondQuan       TYPE i_salesorderitemprcgelmnttp-ConditionQuantity
      EXPORTING
        !et_soprincing     LIKE gtc_sopricingcba .
ENDCLASS.



CLASS zcl_proposal_bo_so IMPLEMENTATION.
  METHOD exe_bo.
    DATA lv_debug TYPE abap_boolean.
    DATA lo_so_parallel TYPE REF TO zcl_proposal_bo_so_paralel.
    DATA lv_status_log TYPE c.
    DATA lt_salesorder TYPE TABLE FOR REPORTED LATE i_salesordertp\\salesorder.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    CHECK gtd_list_bo IS NOT INITIAL.

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst( EXPORTING p_in_tab  = gtd_list_bo
                               p_debug   = lv_debug
                     IMPORTING p_out_tab = DATA(L_out_tab) ).

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>)." WHERE inst IS NOT INITIAL.
      IF <l_out>-inst IS NOT INITIAL.
        lo_so_parallel ?= <l_out>-inst.
      ELSE.
        lo_so_parallel ?= gtd_list_bo[ <l_out>-index ].
        lt_salesorder = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                       number   = '022'
                                                       severity = if_abap_behv_message=>severity-error ) ) ).

        mapping_doc_log(
          EXPORTING
*           iv_dockey     =
            iv_doctype    = zcl_proposal_bo_abs=>c_document_type-salesorder
            it_reported   = lt_salesorder
          CHANGING
            ct_map_id_doc = lo_so_parallel->gt_doc_map_so
            cv_status     = lv_status_log
        ).
        mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                               iv_doctype      = zcl_proposal_bo_abs=>c_document_type-salesorder
                               iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                               iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                               iv_isadjustment = space
                               its_doc         = gts_doc
                               iv_byuser       = lv_byuser
                               iv_attime       = lv_attime
                     CHANGING  ct_map_id_doc   = lo_so_parallel->gt_doc_map_so ).
      ENDIF.

      APPEND LINES OF lo_so_parallel->gt_doc_map_so TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_salesorderdata.
    " TODO: parameter ET_LOG is never cleared or assigned (ABAP cleaner)

    CONSTANTS lc_ze          TYPE I_SalesOrderTP-DistributionChannel        VALUE 'ZE'.
    CONSTANTS lc_zi          TYPE I_SalesOrderTP-DistributionChannel        VALUE 'ZI'.
    CONSTANTS lc_Factura     TYPE I_SalesOrderTP-SalesOrderType             VALUE 'ZINT'.
    CONSTANTS lc_NotadeCredito  TYPE I_SalesOrderTP-SalesOrderType          VALUE 'ZCIN'.
    CONSTANTS lc_orgdivision TYPE I_SalesOrderTP-OrganizationDivision       VALUE 'ZI'.
    CONSTANTS lc_ztad        TYPE I_SalesOrderItemTP-SalesOrderItemCategory VALUE 'ZTAD'.
    CONSTANTS lc_g2n         TYPE I_SalesOrderItemTP-SalesOrderItemCategory VALUE 'G2N'.
    CONSTANTS lc_100         TYPE I_SalesOrderItemTP-RequestedQuantity      VALUE '100'.
    CONSTANTS lc_percentage  TYPE I_SalesOrderItemTP-RequestedQuantityUnit  VALUE '%'.
    CONSTANTS lc_zbas        TYPE I_SalesOrderItemPrcgElmntTP-ConditionType VALUE 'ZBAS'.
    CONSTANTS lc_zmup        TYPE I_SalesOrderItemPrcgElmntTP-ConditionType VALUE 'ZMUP'.
    CONSTANTS lc_zgub        TYPE I_SalesOrderItemPrcgElmntTP-ConditionType VALUE 'ZGUB'.
    CONSTANTS lc_zgum        TYPE I_SalesOrderItemPrcgElmntTP-ConditionType VALUE 'ZGUM'.
    CONSTANTS lc_pr00        TYPE I_SalesOrderItemPrcgElmntTP-ConditionType VALUE 'PR00'.
    TYPES lty_SalesOrderItem    TYPE STRUCTURE FOR CREATE I_SalesOrderTP\_Item.
    TYPES lty_salesorderPricing TYPE STRUCTURE FOR CREATE I_SalesOrderTP\_PricingElement.
    TYPES lty_itemtarget        TYPE LINE OF lty_SalesOrderItem-%target.
    TYPES lty_PricingTarget     TYPE LINE OF lty_salesorderPricing-%target.

    DATA li_SOIdx                TYPE gsty_glitems-SalesOrderItem VALUE 0.
    DATA li_SOitem_idx            TYPE gsty_glitems-SalesOrderItem VALUE 0.
    DATA li_SOPricingIdx         TYPE gsty_glitems-SalesOrderItem VALUE 0.
    DATA lc_salesorder_cid       TYPE abp_behv_cid.
    DATA lc_items_cid            TYPE abp_behv_cid.
    DATA lc_pricing_cid          TYPE abp_behv_cid.
    DATA lv_billingDate          TYPE I_SalesOrderItemTP-BillingDocumentDate.
    DATA lv_providercompanycode  TYPE zfi_proposalitem_add-providercompanycode.
    DATA lv_product              TYPE zfi_proposalitem_add-product.
    DATA lv_recipientcompanycode TYPE zfi_proposalitem_add-recipientcompanycode.
    DATA lv_flow                 TYPE zfi_proposalitem_add-flow.
    DATA lv_NetAmount TYPE i_salesorderitemprcgelmnttp-ConditionRateAmount.
    DATA gv_QuantityUnit  TYPE gsty_glitems-RequestedQuantityUnit.
    DATA lv_totalrate  TYPE  i_salesorderitemprcgelmnttp-ConditionRateAmount.
*    " TODO: variable is assigned but never used (ABAP cleaner)

    FREE gtd_list_bo.

    DATA(lt_propitems) = it_proposalitems[].
    SORT lt_propitems BY providercompanycode
                         product
                         recipientcompanycode
*                         profitcenter
                         flow.
    TRY.
        lv_billingDate = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-FiscalYear }{ gs_header-FiscalPeriod+1 }01| ).
*        zcl_interco_utils=>unit_code_outbound( EXPORTING im_value = '%'
*                                               IMPORTING ex_value = gv_QuantityUnit ).
        gv_QuantityUnit = '%'.

        CHECK lt_propitems IS NOT INITIAL.
        LOOP AT lt_propitems ASSIGNING FIELD-SYMBOL(<fs_items>).
          " Valido que el monto no sea 0
          lv_NetAmount = <fs_items>-amountintrasactioncurrency + <fs_items>-markupamount + <fs_items>-grossingupbaseamount + <fs_items>-grossingupmarginamount.
          IF lv_netamount = 0.
            CONTINUE.
          ENDIF.

          " Verifico si corresponde nueva cabecera e inicializacion de items.
          IF lv_providercompanycode <> <fs_items>-providercompanycode OR lv_product <> <fs_items>-product OR lv_recipientcompanycode <> <fs_items>-recipientcompanycode OR lv_flow <> <fs_items>-flow.
            lv_providercompanycode  = <fs_items>-providercompanycode.
            lv_product              = <fs_items>-product.
            lv_recipientcompanycode = <fs_items>-recipientcompanycode.
            lv_flow                 = <fs_items>-flow.

            " Al ser ejecución secuencial se puede inicializar el contador por cada documento a generar.
            li_SOIdx = 0.
            li_sopricingidx = 0.
            li_SOitem_idx = 0.

            li_SOIdx += 1.
            lc_salesorder_cid = |H{ li_SOIdx }|.

            IF     et_soheader[] IS NOT INITIAL
               AND et_soitems[]  IS NOT INITIAL.
              IF lv_totalrate GE 0.
                et_soheader[ 1 ]-SalesOrderType = lc_Factura.
              ELSE.
                et_soheader[ 1 ]-SalesOrderType = lc_notadecredito.
              ENDIF.

              " llamo a la clase que ejecuta en paralelo.
              DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_so_paralel(
                is_header    = gs_header
                it_items     = gtd_items_add
                it_bases     = gtd_bases
                it_calc      = gtd_calc
                it_doc       = gtd_doc
*               its_bases    = gts_bases
*               its_calc     = gts_calc
                its_doc      = gts_doc
                it_doc_map   = gt_doc_map
                it_soheader  = et_soheader
                it_soitems   = et_soitems
                it_sopricing = et_soprincing
                iv_process   = zcl_boproposal_tools=>gc_create_doc ).

              INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

              FREE: et_soheader,
                    et_soitems,
                    et_soprincing,
                    gt_doc_map.
              CLEAR lv_totalrate.

            ENDIF.

            IF is_proposalheader-ProviderCountry <> <fs_items>-recipientcountry.
              DATA(lv_distributionChannel) = lc_ze.
            ELSE.
              lv_distributionChannel = lc_zi.
            ENDIF.

            " companycode
            IF <fs_items>-flow = gc_inflow.
              DATA(lv_salesorganization) = <fs_items>-salesorganization.
              DATA(lv_soldtoparty) = <fs_items>-providercustomer.
              DATA(lv_plant) = <fs_items>-plant.
            ELSE.
              lv_salesorganization = is_proposalheader-SalesOrganization.
              lv_soldtoparty = <fs_items>-recipientcustomer.
              lv_plant = is_proposalheader-Plant.
            ENDIF.

            et_soheader = VALUE #( BASE et_soheader
                                   ( %cid                          = lc_salesorder_cid
                                     SalesOrganization             = lv_salesorganization
                                     %control-SalesOrganization    = if_abap_behv=>mk-on
                                     DistributionChannel           = lv_distributionchannel
                                     %control-DistributionChannel  = if_abap_behv=>mk-on
                                     OrganizationDivision          = lc_orgDivision
                                     %control-OrganizationDivision = if_abap_behv=>mk-on
*                                     SalesOrderType                = LV_SalesOT
                                     %control-SalesOrderType       = if_abap_behv=>mk-on
                                     TransactionCurrency           = <fs_items>-transactioncurrency
                                     %control-TransactionCurrency  = if_abap_behv=>mk-on
                                     SoldToParty                   = lv_soldtoparty
                                     %control-SoldToParty          = if_abap_behv=>mk-on
                                     CustomerGroup                 = '03' "??
                                     %control-CustomerGroup        = if_abap_behv=>mk-on ) ).
          ENDIF.

          APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc>).
          <fs_doc>-id          = <fs_items>-id.
          <fs_doc>-item_id      = <fs_items>-item_id.
          <fs_doc>-itembasis_id = <fs_items>-itembasis_id.
          <fs_doc>-Itemcalc_Id  = <fs_items>-itemcalc_id.
          <fs_doc>-Documenttype  = zcl_proposal_bo_abs=>c_document_type-salesorder.
          <fs_doc>-Documentkey = |DUMMY{ lv_salesorganization }{ lv_distributionchannel }{ lv_soldtoparty }|.


          li_SOitem_idx += 1.
          lc_items_cid = |I{ li_SOitem_idx }|.

          IF <fs_items>-amountintrasactioncurrency > 0." positivo ZTAD para factura
            DATA(lv_ItemCategory) = lc_ztad.
          ELSE.
            lv_ItemCategory = lc_g2n.
          ENDIF. " Negativo G2N para Nota de crédito.

          APPEND INITIAL LINE TO et_soitems ASSIGNING FIELD-SYMBOL(<fs_soitem>).
          <fs_soitem>-%cid_ref = lc_salesorder_cid.

          <fs_soitem>-%target  = VALUE #( BASE <fs_soitem>-%target
                                          ( %cid                            = lc_items_cid
                                            SalesOrderItem                  = li_SOitem_idx
                                            %control-SalesOrderItem         = if_abap_behv=>mk-off
                                            SalesOrderItemCategory          = lv_itemCategory
                                            %control-SalesOrderItemCategory = if_abap_behv=>mk-on
                                            Product                         = <fs_items>-product
                                            %control-Product                = if_abap_behv=>mk-on
                                            ProfitCenter                    = <fs_items>-profitcenter
                                            %control-ProfitCenter           = if_abap_behv=>mk-on
                                            BillingDocumentDate             = lv_billingDate
                                            %control-BillingDocumentDate    = if_abap_behv=>mk-on
                                            RequestedQuantity               = lc_100
                                            %control-RequestedQuantity      = if_abap_behv=>mk-on
                                            RequestedQuantityUnit           = gv_QuantityUnit "lc_percentage
                                            %control-RequestedQuantityUnit  = if_abap_behv=>mk-on
*                                        NetAmount                       = lv_NetAmount
*                                        %control-NetAmount              = if_abap_behv=>mk-on
                                            Plant                           = lv_plant
                                            %control-Plant                  = if_abap_behv=>mk-on ) ).

          UNASSIGN <fs_soitem>.
          IF lv_NetAmount <> 0.
            lv_totalrate = lv_totalrate + lv_NetAmount.

            li_sopricingidx += 1.
            lc_pricing_cid = |IP{ li_SOPricingIdx }|.

            add_item_pricing( EXPORTING " iv_salesorder_cid = lc_salesorder_cid
                                        iv_items_cid   = lc_items_cid
                                        iv_soi_idx     = li_SOitem_idx
                                        iv_pricing_cid = lc_pricing_cid
                                        iv_soip_idx    = li_sopricingidx
                                        iv_condtype    = lc_pr00
                                        iv_rate        = lv_NetAmount
                                        iv_currency    = <fs_items>-transactioncurrency "globalcurrency
                                        iv_condquan    = CONV #( lc_100 )
                              IMPORTING et_soprincing  = et_soprincing ).

            CLEAR lv_NetAmount.

          ENDIF.

          " ProposalItemTotalAmount
          DATA(lv_CondRate) = CONV i_salesorderitemprcgelmnttp-ConditionRateAmount( <fs_items>-amountintrasactioncurrency ).
          IF lv_CondRate <> 0.
            lv_totalrate = lv_totalrate + lv_CondRate.

            li_sopricingidx += 1.
            lc_pricing_cid = |IP{ li_SOPricingIdx }|.

            add_item_pricing( EXPORTING " iv_salesorder_cid = lc_salesorder_cid
                                        iv_items_cid   = lc_items_cid
                                        iv_soi_idx     = li_SOitem_idx
                                        iv_pricing_cid = lc_pricing_cid
                                        iv_soip_idx    = li_sopricingidx
                                        iv_condtype    = lc_zbas
                                        iv_rate        = lv_CondRate
                                        iv_currency    = <fs_items>-c_codecurrency "globalcurrency
                                        iv_condquan    = CONV #( lc_100 )
                              IMPORTING et_soprincing  = et_soprincing ).

            CLEAR lv_CondRate.

          ENDIF.

          lv_CondRate = CONV i_salesorderitemprcgelmnttp-ConditionRateAmount( <fs_items>-markupamount ).
          IF lv_CondRate <> 0.
            lv_totalrate = lv_totalrate + lv_CondRate.

            li_sopricingidx += 1.
            lc_pricing_cid = |IP{ li_SOPricingIdx }|.

            add_item_pricing( EXPORTING " iv_salesorder_cid = lc_salesorder_cid
                                        iv_items_cid   = lc_items_cid
                                        iv_soi_idx     = li_SOitem_idx
                                        iv_pricing_cid = lc_pricing_cid
                                        iv_soip_idx    = li_sopricingidx
                                        iv_condtype    = lc_zmup
                                        iv_rate        = lv_CondRate
                                        iv_currency    = <fs_items>-c_codecurrency "globalcurrency
                                        iv_condquan    = CONV #( lc_100 )
                              IMPORTING et_soprincing  = et_soprincing ).

            CLEAR lv_CondRate.

          ENDIF.

          lv_CondRate = CONV i_salesorderitemprcgelmnttp-ConditionRateAmount( <fs_items>-grossingupbaseamount ).
          IF lv_CondRate <> 0.
            lv_totalrate = lv_totalrate + lv_CondRate.

            li_sopricingidx += 1.
            lc_pricing_cid = |IP{ li_SOPricingIdx }|.

            add_item_pricing( EXPORTING " iv_salesorder_cid = lc_salesorder_cid
                                        iv_items_cid   = lc_items_cid
                                        iv_soi_idx     = li_SOitem_idx
                                        iv_pricing_cid = lc_pricing_cid
                                        iv_soip_idx    = li_sopricingidx
                                        iv_condtype    = lc_zgub
                                        iv_rate        = lv_CondRate
                                        iv_currency    = <fs_items>-c_codecurrency "globalcurrency
                                        iv_condquan    = CONV #( lc_100 )
                              IMPORTING et_soprincing  = et_soprincing ).

            CLEAR lv_CondRate.

          ENDIF.

          lv_CondRate = CONV i_salesorderitemprcgelmnttp-ConditionRateAmount( <fs_items>-grossingupmarginamount ).
          IF lv_CondRate <> 0.
            lv_totalrate = lv_totalrate + lv_CondRate.

            li_sopricingidx += 1.
            lc_pricing_cid = |IP{ li_SOPricingIdx }|.

            add_item_pricing( EXPORTING " iv_salesorder_cid = lc_salesorder_cid
                                        iv_items_cid   = lc_items_cid
                                        iv_soi_idx     = li_SOitem_idx
                                        iv_pricing_cid = lc_pricing_cid
                                        iv_soip_idx    = li_sopricingidx
                                        iv_condtype    = lc_zgum
                                        iv_rate        = lv_CondRate
                                        iv_currency    = <fs_items>-c_codecurrency "globalcurrency
                                        iv_condquan    = CONV #( lc_100 )
                              IMPORTING et_soprincing  = et_soprincing ).
            CLEAR lv_CondRate.

          ENDIF.
        ENDLOOP.

        IF     et_soheader[] IS NOT INITIAL
           AND et_soitems[]  IS NOT INITIAL.

          IF lv_totalrate GE 0.
            et_soheader[ 1 ]-SalesOrderType = lc_Factura.
          ELSE.
            et_soheader[ 1 ]-SalesOrderType = lc_notadecredito.
          ENDIF.
          " llamo a la clase que ejecuta en paralelo.
          lo_proposal_paralel = NEW zcl_proposal_bo_so_paralel(
            is_header    = gs_header
            it_items     = gtd_items_add
            it_bases     = gtd_bases
            it_calc      = gtd_calc
            it_doc       = gtd_doc
*           its_bases    = gts_bases
*           its_calc     = gts_calc
            its_doc      = gts_doc
            it_doc_map   = gt_doc_map
            it_soheader  = et_soheader
            it_soitems   = et_soitems
            it_sopricing = et_soprincing
            iv_process   = zcl_boproposal_tools=>gc_create_doc ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

          FREE: et_soheader,
                et_soitems,
                et_soprincing,
                gt_doc_map.
          CLEAR lv_totalrate.
        ENDIF.
        exe_bo( )."Return the data on me->gt_doc_map
        et_doc_map = me->gt_doc_map.
        IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ).
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
      CATCH cx_sy_conversion_no_date INTO DATA(cx_date).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      CATCH cx_sy_itab_line_not_found INTO DATA(cx_line_not_found).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDTRY.
  ENDMETHOD.

  METHOD add_item_pricing.

    ASSIGN et_soprincing[ %cid_ref = iv_items_cid ] TO FIELD-SYMBOL(<fs_sopricing>).
    IF sy-subrc NE 0.
      APPEND INITIAL LINE TO et_soprincing ASSIGNING <fs_sopricing>.
      <fs_sopricing>-%cid_ref = iv_items_cid.
      <fs_sopricing>-SalesOrderItem = iv_soi_idx.
    ENDIF.

    <fs_sopricing>-%target = VALUE #( BASE <fs_sopricing>-%target
                                      ( %cid                             = iv_pricing_cid
                                        SalesOrderItem                   = iv_soi_idx
                                        %control-SalesOrderItem          = if_abap_behv=>mk-off
                                        %control-PricingProcedureStep    = if_abap_behv=>mk-off
                                        %control-PricingProcedureCounter = if_abap_behv=>mk-off
                                        ConditionType                    = iv_condtype
                                        %control-ConditionType           = if_abap_behv=>mk-on
                                        ConditionRateAmount              = iv_rate
                                        %control-ConditionRateAmount     = if_abap_behv=>mk-on
                                        ConditionCurrency                = iv_currency
                                        %control-ConditionCurrency       = if_abap_behv=>mk-on
                                        ConditionQuantity                = iv_CondQuan
                                        %control-ConditionQuantity       = if_abap_behv=>mk-on ) ).
    UNASSIGN <fs_sopricing>.
  ENDMETHOD.

  METHOD mapping_bo_sec.

    TYPES lty_SalesOrderItem    TYPE STRUCTURE FOR CREATE I_SalesOrderTP\_Item.
    TYPES lty_salesorderPricing TYPE STRUCTURE FOR CREATE I_SalesOrderTP\_PricingElement.

    FREE: gtc_salesorder,
          gtc_soitemcba,
          gtc_sopricingcba.

    get_salesorderdata( EXPORTING is_proposalheader = gs_header
                                  it_proposalitems  = gtd_items_add
                        IMPORTING et_soheader       = gtc_salesorder[]
                                  et_soitems        = gtc_soitemcba[]
                                  et_soprincing     = gtc_sopricingcba[]
                                  et_doc_map        = et_doc_map ).
  ENDMETHOD.

  METHOD mapping_reverse_sec.
*    FREE gtd_list_bo.
*
*    DATA(lt_billdoc) = VALUE gtty_doc( FOR lwa_doc IN gtd_doc WHERE ( DocumentType = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                       AND Status <> zcl_proposal_bo_abs=>c_document_status-anulated )
*                                       (                                           lwa_doc ) ).
*    " Anulo todas las facturas.
*    exe_anulation_bo_sec( CHANGING ct_map_id_doc = lt_billdoc ).
*
*    " Reverse sales orders.
*    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>) WHERE DocumentType = zcl_proposal_bo_abs=>c_document_type-salesorder AND Status <> zcl_proposal_bo_abs=>c_document_status-anulated.
*      FREE gt_doc_map.
*
*      APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
*      <fs_doc_map> = <fs_doc>.
*
*      DATA(lo_exe_bo) = NEW zcl_proposal_bo_so_paralel( it_doc_map = gt_doc_map
*                                                        iv_process = zcl_boproposal_tools=>gc_reverse_doc ).
*
*      APPEND INITIAL LINE TO gtd_list_bo ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
*      <fs_list_bo> = lo_exe_bo.
*    ENDLOOP.
    DATA ls_doc_bd TYPE LINE OF gtty_doc.
    DATA lv_prevdockey TYPE zfi_a_intrc_cpid-documentkey.
    gt_doc_map_bd = gt_doc_map.
    CHECK gtd_doc IS NOT INITIAL.
    "TODOS LOS DOCUMENTOS YA DEBEN VENIR FILTRADOS (NO DUMMY)
    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>) WHERE Documenttype EQ zcl_proposal_bo_abs=>c_document_type-salesorder.
*      FREE: gt_doc_map.
      "Validaciones para reprocesar anulaciones
      CHECK NOT line_exists( gtd_anul_doc[ ParentDocumentKey = <fs_doc>-Documentkey ] )
      OR gtd_anul_doc[ ParentDocumentKey = <fs_doc>-Documentkey ]-Documentkey(5) EQ 'DUMMY'.
      "Validaciones para primer procesamiento
      "Si la orden aun no tiene factura, no deberiamos anular?
      DATA(lv_bd_dockey) = VALUE #( gtd_doc[ Documenttype       = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                             ParentDocumentKey  = <fs_doc>-Documentkey
                                             ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-salesorder ]-Documentkey OPTIONAL ).

      DATA(lv_anul_bd_dk) = VALUE #( gtd_anul_doc[ Documenttype       = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                                   ParentDocumentKey  = lv_bd_dockey
                                                   ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-billingdocument ]-Documentkey OPTIONAL ).
      IF lv_anul_bd_dk IS INITIAL.
        lv_anul_bd_dk = VALUE #( gt_doc_map_bd[ Documenttype       = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
                                                ParentDocumentKey  = lv_bd_dockey
                                                ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-billingdocument ]-Documentkey OPTIONAL ).
        "Si la factura de venta aun no se anula, no se puede anular la orden
        IF lv_anul_bd_dk IS INITIAL AND lv_bd_dockey IS NOT INITIAL.
          CONTINUE.
        ENDIF.
      ENDIF.
      IF NOT line_exists( gt_doc_map[ ParentDocumentKey = <fs_doc>-Documentkey ] ).
        IF lv_prevdockey IS NOT INITIAL
        AND lv_prevdockey NE <fs_doc>-Documentkey.
          DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_so_paralel(
            it_doc               = gtd_doc
            its_doc              = gts_doc
            it_doc_map           = gt_doc_map
            iv_parentdocumentkey = lv_prevdockey
            iv_process           = gv_process ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.
          CLEAR lv_prevdockey.
        ENDIF.
        FREE: gt_doc_map.
        lv_prevdockey = <fs_doc>-Documentkey.
      ENDIF.
      ls_doc_bd-id          = <fs_doc>-id.
      ls_doc_bd-item_id      = <fs_doc>-item_id.
      ls_doc_bd-itembasis_id = <fs_doc>-itembasis_id.
      ls_doc_bd-Itemcalc_Id  = <fs_doc>-Itemcalc_Id.
      ls_doc_bd-Documenttype  = zcl_proposal_bo_abs=>c_document_type-anul_salesorder.
      ls_doc_bd-ParentDocumentType  = zcl_proposal_bo_abs=>c_document_type-salesorder.
      ls_doc_bd-Documentkey = |DUMMY{ <fs_doc>-Documentkey }|.
      ls_doc_bd-ParentDocumentKey  = <fs_doc>-Documentkey.
      APPEND ls_Doc_bd TO gt_doc_map.
    ENDLOOP.
    IF gt_doc_map[] IS NOT INITIAL.
      lo_proposal_paralel = NEW zcl_proposal_bo_so_paralel(
        it_doc               = gtd_doc
        its_doc              = gts_doc
        it_doc_map           = gt_doc_map
        iv_parentdocumentkey = ls_doc_bd-ParentDocumentKey
        iv_process           = gv_process ).

      INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

      FREE: gt_doc_map.
    ENDIF.
    CHECK gtd_list_bo IS NOT INITIAL.
    exe_bo( )."Return the data on me->gt_doc_map
    et_doc_map = me->gt_doc_map.
    IF gt_doc_map[] IS INITIAL OR
        line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] )
        OR line_exists( gt_doc_map[ status = abap_false ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.
  ENDMETHOD.

  METHOD exe_anulation_bo_sec.
*    DATA lv_status_doc TYPE zfi_a_intrc_cpid-status.
*    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.
*
*    " Reversal reason is: wrong prices and conditions.
*    DATA(lv_revreason) = '01'.
*
*    MODIFY ENTITY I_BillingDocumentTP
*           EXECUTE CreateCancellationDocument AUTO FILL CID
*           WITH VALUE #( FOR ls_key IN ct_map_id_doc
*                         ( BillingDocument       = ls_key-Documentkey
*                           %param-ReversalReason = lv_revreason ) )
*           FAILED DATA(ls_failed)
*           REPORTED DATA(lsreported).
*
*    IF ls_failed IS NOT INITIAL.
*      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error_anulated.
*
*      mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                 it_reported   = lsreported-billingdocument
*                       CHANGING  ct_map_id_doc = ct_map_id_doc
*                                 cv_status     = lv_status_log ).
*
*      RETURN.
*    ELSE.
*      " The below method saves the billing documents.
*      COMMIT ENTITIES
*             RESPONSE OF I_BillingDocumentTP
*             " TODO: variable is assigned but never used (ABAP cleaner)
*             REPORTED DATA(ls_reported_commit).
*
*      IF sy-subrc <> 0.
*        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error_anulated.
*
*        mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                   it_reported   = ls_reported_commit-billingdocument
*                         CHANGING  ct_map_id_doc = ct_map_id_doc
*                                   cv_status     = lv_status_log ).
*      ELSE.
*        lv_status_doc = zcl_proposal_bo_abs=>c_document_status-anulated.
*
*        mapping_doc_log( EXPORTING iv_doctype    = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                   it_reported   = ls_reported_commit-billingdocument
*                         CHANGING  ct_map_id_doc = ct_map_id_doc
*                                   cv_status     = lv_status_log ).
*      ENDIF.
*
*    ENDIF.
*    IF lv_status_log EQ 'E'.
*      lv_status_doc = zcl_proposal_bo_abs=>c_document_status-error_anulated.
*    ENDIF.
*
*    mapping_doc( EXPORTING iv_doctype       = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                           iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-salesorder
*                           iv_status        = lv_status_doc
*                           iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
*                           iv_isadjustment  = space
*                 CHANGING  ct_map_id_doc    = ct_map_id_doc ).
  ENDMETHOD.
  METHOD preparedata_reverse.
*    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
*      TRY.
*          DATA(ls_billdoc) = gtd_doc[ Documenttype = zcl_proposal_bo_abs=>c_document_type-billingdocument
*                                      ParentDocumentKey = <fs_doc>-Documentkey
*                                      ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-salesorder ].
*          DATA(ls_anul_billdoc) = gt_doc_map[ Documenttype = zcl_proposal_bo_abs=>c_document_type-anul_billdoc
*                                              ParentDocumentKey = ls_billdoc-Documentkey
*                                              ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-billingdocument ].
*        CATCH cx_sy_itab_line_not_found.
*          "Si la factura de venta aun no se anula, no se puede anular la orden
*          <fs_doc>-IsDeleted = abap_true.
*      ENDTRY.
*    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
