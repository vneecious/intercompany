CLASS zcl_proposal_bo_po DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    DATA gtc_PurchaseOrder   TYPE TABLE FOR CREATE I_PurchaseOrderTP_2 .
    DATA gtc_POItem          TYPE TABLE FOR CREATE i_purchaseordertp_2\_purchaseorderitem .
    DATA gtc_POItem_AccAssig TYPE TABLE FOR CREATE I_PurchaseOrderItemTP_2\_PurOrdAccountAssignment .
    DATA gtc_POItem_PricElem TYPE TABLE FOR CREATE I_PurchaseOrderItemTP_2\_PurOrdPricingElement .
    DATA gtd_documentkey     TYPE TABLE OF zfi_a_intrc_cpid-documentkey .
    DATA gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab .
    DATA gs_header_po TYPE zi_intercoproposal .
    DATA gt_CancelInvoice    TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~cancel .
    DATA gt_doc_map_si    TYPE gtty_doc.

    METHODS call_bapi_po_create
      IMPORTING
        !is_header TYPE zi_intercoproposal OPTIONAL
        !it_items  LIKE gtd_items_add OPTIONAL
      EXPORTING
        !et_log    TYPE gtty_logs .
  PROTECTED SECTION.

    METHODS exe_anulation_bo_sec REDEFINITION .
    METHODS exe_bo REDEFINITION .
    METHODS mapping_bo REDEFINITION .
    METHODS mapping_bo_sec REDEFINITION .
    METHODS preparedata REDEFINITION .
    METHODS supplier_inv REDEFINITION .
    METHODS mapping_reverse_sec REDEFINITION .
  PRIVATE SECTION.

    METHODS get_last_day_of_month
      IMPORTING
        VALUE(day_in)            TYPE sy-datum
      EXPORTING
        VALUE(last_day_of_month) TYPE sy-datum .
    METHODS get_po_data
      IMPORTING
        !is_header        TYPE zi_intercoproposal
        !it_items         LIKE gtd_items_add
        !it_bases         LIKE gtd_bases
        !it_calc          LIKE gtd_calc
      EXPORTING
        !et_purchaseorder LIKE gtc_purchaseorder
        !et_poitems       LIKE gtc_poitem
        !et_poaccassig    LIKE gtc_poitem_accassig
        !et_popricing     LIKE gtc_poitem_pricelem.
*        !et_log           TYPE gtty_c_log .
    METHODS get_po_data_paralell
      IMPORTING
                !is_header        TYPE zi_intercoproposal
                !it_items         LIKE gtd_items_add
                !it_bases         LIKE gtd_bases
                !it_calc          LIKE gtd_calc
      EXPORTING
                !et_purchaseorder LIKE gtc_purchaseorder
                !et_poitems       LIKE gtc_poitem
                !et_poaccassig    LIKE gtc_poitem_accassig
                !et_popricing     LIKE gtc_poitem_pricelem
                !et_doc_map       TYPE gtty_doc
      RAISING   zcx_calc_exit.
*        !et_log           TYPE gtty_c_log .
ENDCLASS.



CLASS zcl_proposal_bo_po IMPLEMENTATION.


  METHOD mapping_bo_sec.

    FREE: gtc_purchaseorder,
          gtc_POItem,
          gtc_POItem_AccAssig,
          gtc_POItem_PricElem.

    get_po_data_paralell(
      EXPORTING
        is_header        = gs_header
        it_items         = gtd_items_add
        it_bases         = gtd_bases
        it_calc          = gtd_calc
      IMPORTING
        et_purchaseorder = gtc_purchaseorder
        et_poitems       = gtc_POItem
        et_poaccassig    = gtc_POItem_AccAssig
        et_popricing     = gtc_POItem_PricElem
        et_doc_map       = et_doc_map
    ).

  ENDMETHOD.


  METHOD exe_bo.

    DATA lv_debug TYPE abap_boolean.
    DATA lo_po_parallel TYPE REF TO zcl_proposal_bo_po_paralel.
    DATA lv_status_log TYPE c.
    DATA lt_po TYPE TABLE FOR REPORTED LATE i_purchaseordertp_2\\purchaseorder.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    CHECK gtd_list_bo IS NOT INITIAL.

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst( EXPORTING p_in_tab  = gtd_list_bo
                               p_debug   = lv_debug
                     IMPORTING p_out_tab = DATA(L_out_tab) ).

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>).
      IF <l_out>-inst IS NOT INITIAL.
        lo_po_parallel ?= <l_out>-inst.
      ELSE.
        lo_po_parallel ?= gtd_list_bo[ <l_out>-index ].
        IF <l_out>-message IS NOT INITIAL.
          lt_po = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                 number   = '022'
                                                 severity = if_abap_behv_message=>severity-error ) ) ).

          mapping_doc_log(
            EXPORTING
*             iv_dockey     =
              iv_doctype    = zcl_proposal_bo_abs=>c_document_type-purchaseorder
              it_reported   = lt_po
            CHANGING
              ct_map_id_doc = lo_po_parallel->gt_doc_map_po
              cv_status     = lv_status_log
          ).
          mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                                 iv_doctype      = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                 iv_status       = zcl_proposal_bo_abs=>c_document_status-error
                                 iv_cat_id       = zcl_proposal_bo_abs=>c_document_category-order
                                 iv_isadjustment = space
                                 its_doc         = gts_doc
                                 iv_byuser       = lv_byuser
                                 iv_attime       = lv_attime
                       CHANGING  ct_map_id_doc   = lo_po_parallel->gt_doc_map_po ).
        ENDIF.
      ENDIF.
      APPEND LINES OF lo_po_parallel->gt_doc_map_po TO me->gt_doc_map.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_po_data_paralell.

    TYPES: lty_POItem  TYPE STRUCTURE FOR CREATE I_PurchaseOrderTP_2\_purchaseorderitem,
           lty_ItemAcc TYPE STRUCTURE FOR CREATE I_PurchaseOrderItemTP_2\_PurOrdAccountAssignment,
           lty_ItemPri TYPE STRUCTURE FOR CREATE I_PurchaseOrderItemTP_2\_PurOrdPricingElement,
           lty_PO      TYPE STRUCTURE FOR CREATE I_PurchaseOrderTP_2.

    DATA: lt_ItemTarget TYPE lty_POItem-%target,
          lt_AccTarget  TYPE lty_ItemAcc-%target,
          lt_PriTarget  TYPE lty_ItemPri-%target,
          lt_PO         TYPE lty_po-%cid,
          ls_ItemTarget LIKE LINE OF lt_ItemTarget,
          ls_AccTarget  LIKE LINE OF lt_AccTarget,
          ls_PricTarget LIKE LINE OF lt_PriTarget,
          li_POidx      TYPE n LENGTH 3 VALUE 0,
          li_POitem_idx TYPE n LENGTH 3 VALUE 0,
          li_POIAccIdx  TYPE n LENGTH 3 VALUE 0,
          li_POIPriIdx  TYPE n LENGTH 3 VALUE 0,
          li_POItmPrice TYPE n LENGTH 6 VALUE 0,
          lv_date       TYPE d,
          lv_netprice   TYPE p DECIMALS 2,
          lv_shamount   TYPE p DECIMALS 2,
          lv_secuencial TYPE n.
    DATA lv_dockey TYPE zfi_a_intrc_cpid-documentkey.
    CONSTANTS lc_zint       TYPE I_PurchaseOrderTP_2-PurchaseOrderType             VALUE 'ZINT'.
    CONSTANTS lc_zic        TYPE I_PurchaseOrderTP_2-PurchasingGroup               VALUE 'ZIC'.
    CONSTANTS lc_100        TYPE I_PurchaseOrderItemTP_2-OrderQuantity             VALUE '100'.
    CONSTANTS lc_percentage TYPE I_PurchaseOrderItemTP_2-PurchaseOrderQuantityUnit VALUE '%'.
    CONSTANTS lc_k          TYPE I_PurchaseOrderItemTP_2-AccountAssignmentCategory VALUE 'K'.
    CONSTANTS lc_x          TYPE I_PurchaseOrderItemTP_2-InvoiceIsExpected         VALUE 'X'.
    CONSTANTS lc_zbas       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'ZBAS'.
    CONSTANTS lc_zmup       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'ZMUP'.
    CONSTANTS lc_zgub       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'ZGUB'.
    CONSTANTS lc_zgum       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'ZGUM'.
    CONSTANTS lc_BASE       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'BASE'.
    CONSTANTS lc_mkup       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'MKUP'.
    CONSTANTS lc_GUPK       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'GUPK'.
    CONSTANTS lc_GUPB       TYPE I_PurOrdPricingElementTP_2-ConditionType          VALUE 'GUPB'.

    DATA lv_providercompanycode  TYPE zfi_proposalitem_add-providercompanycode.
    DATA lv_product              TYPE zfi_proposalitem_add-product.
    DATA lv_recipientcompanycode TYPE zfi_proposalitem_add-recipientcompanycode.
    DATA lv_flow                 TYPE zfi_proposalitem_add-flow.

    gs_header_po   = is_header.
    DATA(lt_items) = it_items[].
    DATA(lt_bases) = it_bases[].
    DATA(lt_calc)  = it_calc[].

    SORT lt_items BY providercompanycode
                     product
                     recipientcompanycode
                     flow.
    TRY.
        CHECK it_items IS NOT INITIAL.
        LOOP AT lt_items INTO DATA(ls_items).

          "Solo procesa aquellos montos > 0.
          lv_netprice = ls_items-amountintrasactioncurrency + ls_items-markupamount + ls_items-grossingupbaseamount + ls_items-grossingupmarginamount.
          IF lv_netprice LE 0.
            CONTINUE.
          ENDIF.
          " Verifico si corresponde nueva cabecera e inicializacion de items.
          IF lv_providercompanycode <> ls_items-providercompanycode   OR
             lv_product <> ls_items-product                           OR
             lv_recipientcompanycode <> ls_items-recipientcompanycode OR
             lv_flow <> ls_items-flow.

            lv_providercompanycode  = ls_items-providercompanycode.
            lv_product              = ls_items-product.
            lv_recipientcompanycode = ls_items-recipientcompanycode.
            lv_flow                 = ls_items-flow.

            CLEAR: li_POidx, li_POitem_idx, li_POIAccIdx, li_POIPriIdx, li_POItmPrice.
            IF gtc_purchaseorder[] IS NOT INITIAL AND
               gtc_POItem[] IS NOT INITIAL.

              " llamo a la clase que ejecuta en paralelo.
              DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_po_paralel( is_header    = gs_header
                                                                          it_doc       = gtd_doc
                                                                          its_doc      = gts_doc
                                                                          it_doc_map   = gt_doc_map
                                                                          it_poheader  = et_purchaseorder
                                                                          it_poitems   = et_poitems
                                                                          it_poaccount = et_poaccassig
                                                                          it_popricing = et_popricing
*                                                                          iv_parentdocumentkey = lv_dockey
                                                                          iv_process   = zcl_boproposal_tools=>gc_create_doc ).

              INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

              FREE: et_purchaseorder,
                    et_poitems,
                    et_poaccassig,
                    et_popricing,
                    gt_doc_map.

            ENDIF.

            li_POidx += 10.

            "CompanyCode / Plant
            IF ls_items-flow EQ gc_outflow.
              ls_ItemTarget-CompanyCode = ls_items-recipientcompanycode.
              DATA(lv_plant) = ls_items-plant.
*          DATA(lv_supplier) = ls_items-recipientcompanycode.
            ELSEIF ls_items-flow EQ gc_inflow.
              ls_ItemTarget-CompanyCode = ls_items-providercompanycode.
              lv_plant = ls_items-providerplant.
*          lv_supplier = ls_items-providercompanycode.
            ENDIF.

            "Supplier
            IF ls_items-flow EQ gc_outflow.
              DATA(lv_supplier) = ls_items-providervendor.
            ELSEIF ls_items-flow EQ gc_inflow.
              lv_supplier = ls_items-recipientcustomer.
            ENDIF.

            "PurchaseOrderDate
            lv_date = |{ gs_header-FiscalYear }{ gs_header-FiscalPeriod+1(2) }01|.
            get_last_day_of_month( EXPORTING day_in            = lv_date
                                   IMPORTING last_day_of_month = lv_date ).

            et_purchaseorder = VALUE #( BASE et_purchaseorder
                                        ( %cid                   = |POH{ li_POidx }|
                                          CompanyCode            = ls_ItemTarget-CompanyCode
                                          PurchaseOrderType      = lc_zint           "ZINT
                                          Supplier               = lv_supplier
                                          PurchasingOrganization = ls_items-purchasingorganization
                                          PurchasingGroup        = lc_zic
*                                          DocumentCurrency       = gs_header-GlobalCurrency
                                          DocumentCurrency       = ls_items-transactioncurrency
                                          PurchaseOrderDate      = lv_date
                                          %control               = VALUE #( CompanyCode            = if_abap_behv=>mk-on
                                                                            PurchaseOrderType      = if_abap_behv=>mk-on
                                                                            Supplier               = if_abap_behv=>mk-on
                                                                            PurchasingOrganization = if_abap_behv=>mk-on
                                                                            PurchasingGroup        = if_abap_behv=>mk-on
                                                                            DocumentCurrency       = if_abap_behv=>mk-on
                                                                            PurchaseOrderDate      = if_abap_behv=>mk-on ) ) ).

          ENDIF.

          APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc>).
          <fs_doc>-id          = ls_items-id.
          <fs_doc>-item_id      = ls_items-item_id.
          <fs_doc>-Itembasis_Id = ls_items-itembasis_id.
          <fs_doc>-Itemcalc_Id  = ls_items-itemcalc_id.
          <fs_doc>-documentkey = |DUMMY{ ls_items-providercompanycode }{ lv_supplier }{ ls_items-purchasingorganization }|.
          <fs_doc>-Documenttype  = zcl_proposal_bo_abs=>c_document_type-purchaseorder.
          UNASSIGN <fs_doc>.

          li_POitem_idx += 10.
          li_POItmPrice += 10.

          "PurgDocNetAmount
          lv_shamount = ls_items-amountintrasactioncurrency.

          IF lv_shamount IS NOT INITIAL AND
             ls_items-markupamount IS INITIAL AND
             ls_items-grossingupbaseamount IS INITIAL AND
             ls_items-grossingupmarginamount IS INITIAL.
            et_poitems = VALUE #( BASE et_poitems
                                  ( %cid_ref = |POH{ li_POidx }|
                                    %target  = VALUE #( ( %cid                       = |POI{ li_POitem_idx }|
                                                          PurchaseOrderItem          = li_POitem_idx
                                                          material                   = gs_header-Product
                                                          Plant                      = lv_plant
                                                          OrderQuantity              = lc_100             "100
                                                          NetPriceAmount             = lv_netprice
                                                          NetPriceQuantity           = lc_100             "100
                                                          PurchaseOrderItemCategory  = 0
                                                          AccountAssignmentCategory  = lc_k               "K
*                                                        MultipleAcctAssgmtDistribution = 3
*                                                        PartialInvoiceDistribution     = 2
                                                          GoodsReceiptIsExpected     = '0'
                                                          InvoiceIsExpected          = lc_x               "X
                                                          InvoiceIsGoodsReceiptBased = '0'
                                                          %control                   = VALUE #( PurchaseOrderItem          = if_abap_behv=>mk-on
                                                                                                material                   = if_abap_behv=>mk-on
                                                                                                plant                      = if_abap_behv=>mk-on
                                                                                                OrderQuantity              = if_abap_behv=>mk-on
                                                                                                NetPriceAmount             = if_abap_behv=>mk-on
                                                                                                NetPriceQuantity           = if_abap_behv=>mk-on
                                                                                                PurchaseOrderItemCategory  = if_abap_behv=>mk-on
                                                                                                AccountAssignmentCategory  = if_abap_behv=>mk-on
*                                                                                                  MultipleAcctAssgmtDistribution = if_abap_behv=>mk-on
*                                                                                                  PartialInvoiceDistribution     = if_abap_behv=>mk-on
                                                                                                GoodsReceiptIsExpected     = if_abap_behv=>mk-on
                                                                                                InvoiceIsExpected          = if_abap_behv=>mk-on
                                                                                                InvoiceIsGoodsReceiptBased = if_abap_behv=>mk-on ) ) ) ) ).


          ELSE.
            et_poitems = VALUE #( BASE et_poitems
                                  ( %cid_ref = |POH{ li_POidx }|
                                    %target  = VALUE #( ( %cid                           = |POI{ li_POitem_idx }|
                                                          PurchaseOrderItem              = li_POitem_idx
                                                          material                       = gs_header-Product
                                                          Plant                          = lv_plant
                                                          OrderQuantity                  = lc_100         "100
                                                          NetPriceAmount                 = lv_netprice
                                                          NetPriceQuantity               = lc_100         "100
                                                          PurchaseOrderItemCategory      = 0
                                                          AccountAssignmentCategory      = lc_k           "K
                                                          MultipleAcctAssgmtDistribution = 3
                                                          PartialInvoiceDistribution     = 2
                                                          GoodsReceiptIsExpected         = '0'
                                                          InvoiceIsExpected              = lc_x           "X
                                                          InvoiceIsGoodsReceiptBased     = '0'
                                                          %control                       = VALUE #( PurchaseOrderItem              = if_abap_behv=>mk-on
                                                                                                    material                       = if_abap_behv=>mk-on
                                                                                                    plant                          = if_abap_behv=>mk-on
                                                                                                    OrderQuantity                  = if_abap_behv=>mk-on
                                                                                                    NetPriceAmount                 = if_abap_behv=>mk-on
                                                                                                    NetPriceQuantity               = if_abap_behv=>mk-on
                                                                                                    PurchaseOrderItemCategory      = if_abap_behv=>mk-on
                                                                                                    AccountAssignmentCategory      = if_abap_behv=>mk-on
                                                                                                    MultipleAcctAssgmtDistribution = if_abap_behv=>mk-on
                                                                                                    PartialInvoiceDistribution     = if_abap_behv=>mk-on
                                                                                                    GoodsReceiptIsExpected         = if_abap_behv=>mk-on
                                                                                                    InvoiceIsExpected              = if_abap_behv=>mk-on
                                                                                                    InvoiceIsGoodsReceiptBased     = if_abap_behv=>mk-on ) ) ) ) ).


          ENDIF.

          IF lv_shamount <> 0.
            IF line_exists( gtd_glaccount[ ChartOfAccounts = ls_items-ChartOfAccounts
                                           transactiontypedetermination = 'ZIN'
                                           valuationareagroup = lc_BASE
                                           Product = ls_items-Product
                                           Plant = ls_items-ProviderPlant
                                           CompanyCode = ls_items-providercompanycode
                                         ] ).
              DATA(ls_glaccount) = gtd_glaccount[ ChartOfAccounts = ls_items-ChartOfAccounts
                                                  transactiontypedetermination = 'ZIN'
                                                  valuationareagroup = lc_BASE
                                                  Product = ls_items-Product
                                                  Plant = ls_items-ProviderPlant
                                                  CompanyCode = ls_items-providercompanycode
                                                ].

*              li_POIAccIdx = li_POIAccIdx + 10.
*              li_POIPriIdx = li_POIPriIdx + 10.
              lv_secuencial = lv_secuencial + 1.

              "ShareAmount / SharedRateGLAccount
              ASSIGN et_poaccassig[ %cid_ref = |POI{ li_POitem_idx }| ] TO FIELD-SYMBOL(<fs_poaccassig>).
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_poaccassig ASSIGNING <fs_poaccassig>.
                <fs_poaccassig>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_poaccassig>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIAccIdx = li_POIAccIdx + 10.
              <fs_poaccassig>-%target = VALUE #( BASE <fs_poaccassig>-%target
                                                 ( %cid                    = |POIA{ li_POIAccIdx }|
                                                   PurchaseOrderItem       = li_POitem_idx
                                                   AccountAssignmentNumber = lv_secuencial
                                                   CostCenter              = |9541{ ls_items-internalcode }{ ls_items-profitcenter ALPHA = OUT }|
                                                   Quantity                = lc_100
                                                   PurgDocNetAmount        = lv_shamount                          "ShareAmount
                                                   GLAccount               = ls_glaccount-debitglaccount          "SharedRateGLAccount
                                                   %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                      AccountAssignmentNumber = if_abap_behv=>mk-on
                                                                                      CostCenter              = if_abap_behv=>mk-on
                                                                                      PurgDocNetAmount        = if_abap_behv=>mk-on
                                                                                      Quantity                = if_abap_behv=>mk-on
                                                                                      GLAccount               = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_poaccassig>.

**********************************************************************
              "Condition Type PBXX Necesary for a PO to include custom price condition in create process
              ASSIGN et_popricing[ %cid_ref = |POI{ li_POitem_idx }| ] TO FIELD-SYMBOL(<fs_popricing>).
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_popricing ASSIGNING <fs_popricing>.
                <fs_popricing>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_popricing>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIPriIdx = li_POIPriIdx + 10.
              <fs_popricing>-%target = VALUE #( BASE <fs_popricing>-%target
                                                ( %cid                    = |POIP{ li_POIPriIdx }|
                                                  PurchaseOrderItem       = li_POitem_idx
                                                  ConditionType           = 'PBXX'
                                                  ConditionRateAmount     = lv_netprice   "Net Price Amount
                                                  ConditionCurrency       = ls_items-transactioncurrency
*                                                  ConditionCurrency       = gs_header-GlobalCurrency
                                                  ConditionQuantity       = lc_100
                                                  PricingProcedureStep    = '001'
                                                  PricingProcedureCounter = '001'
                                                  PricingDocumentItem     = li_POItmPrice
                                                  %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                     ConditionType           = if_abap_behv=>mk-on
                                                                                     ConditionRateAmount     = if_abap_behv=>mk-on
                                                                                     ConditionCurrency       = if_abap_behv=>mk-on
                                                                                     ConditionQuantity       = if_abap_behv=>mk-on
                                                                                     PricingDocumentItem     = if_abap_behv=>mk-on
                                                                                     PricingProcedureStep    = if_abap_behv=>mk-on
                                                                                     PricingProcedureCounter = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_popricing>.
*              li_POIPriIdx = li_POIPriIdx + 10.
**********************************************************************
              "SharedRate
*          ASSIGN et_popricing[ %cid_ref = |POI{ li_POitem_idx }| ] TO FIELD-SYMBOL(<fs_popricing>).
              ASSIGN et_popricing[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_popricing>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_popricing ASSIGNING <fs_popricing>.
                <fs_popricing>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_popricing>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIPriIdx = li_POIPriIdx + 10.
              <fs_popricing>-%target = VALUE #( BASE <fs_popricing>-%target
                                                ( %cid                    = |POIP{ li_POIPriIdx }|
                                                  PurchaseOrderItem       = li_POitem_idx
                                                  ConditionType           = lc_zbas
                                                  ConditionRateAmount     = lv_shamount
                                                  ConditionCurrency       = ls_items-transactioncurrency
*                                                  ConditionCurrency       = gs_header-GlobalCurrency
                                                  ConditionQuantity       = lc_100
                                                  PricingProcedureStep    = '090'
                                                  PricingProcedureCounter = '001'
                                                  PricingDocumentItem     = li_POItmPrice
                                                  %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                     ConditionType           = if_abap_behv=>mk-on
                                                                                     ConditionRateAmount     = if_abap_behv=>mk-on
                                                                                     ConditionCurrency       = if_abap_behv=>mk-on
                                                                                     ConditionQuantity       = if_abap_behv=>mk-on
                                                                                     PricingDocumentItem     = if_abap_behv=>mk-on
                                                                                     PricingProcedureStep    = if_abap_behv=>mk-on
                                                                                     PricingProcedureCounter = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_popricing>.
            ENDIF.
          ENDIF.

          IF ls_items-markupamount <> 0.
            IF line_exists( gtd_glaccount[ ChartOfAccounts = gs_header-ChartOfAccounts
                                           transactiontypedetermination = 'ZIN'
                                           valuationareagroup = lc_mkup
                                           Product = ls_items-Product
                                           Plant = ls_items-ProviderPlant
                                           CompanyCode = ls_items-providercompanycode
                                         ] ).
              ls_glaccount = gtd_glaccount[ ChartOfAccounts = gs_header-ChartOfAccounts
                                            transactiontypedetermination = 'ZIN'
                                            valuationareagroup = lc_MKUP
                                            Product = ls_items-Product
                                            Plant = ls_items-ProviderPlant
                                            CompanyCode = ls_items-providercompanycode
                                            ].

*              li_POIAccIdx = li_POIAccIdx + 10.
*              li_POIPriIdx = li_POIPriIdx + 10.
              lv_secuencial = lv_secuencial + 1.
              "MarkUpAmount / MarkUpGLAccount
              ASSIGN et_poaccassig[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_poaccassig>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_poaccassig ASSIGNING <fs_poaccassig>.
                <fs_poaccassig>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_poaccassig>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIAccIdx = li_POIAccIdx + 10.
              <fs_poaccassig>-%target = VALUE #( BASE <fs_poaccassig>-%target
                                                 ( %cid                    = |POIA{ li_POIAccIdx }|
                                                   PurchaseOrderItem       = li_POitem_idx
                                                   AccountAssignmentNumber = lv_secuencial
                                                   CostCenter              = |9541{ ls_items-internalcode }{ ls_items-profitcenter ALPHA = OUT }|
                                                   Quantity                = lc_100
                                                   PurgDocNetAmount        = ls_items-markupamount                 "MarkUpAmount
                                                   GLAccount               = ls_glaccount-debitglaccount          "MarkUpGLAccount
                                                   %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                      AccountAssignmentNumber = if_abap_behv=>mk-on
                                                                                      CostCenter              = if_abap_behv=>mk-on
                                                                                      PurgDocNetAmount        = if_abap_behv=>mk-on
                                                                                      Quantity                = if_abap_behv=>mk-on
                                                                                      GLAccount               = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_poaccassig>.

              "MarkUp
              ASSIGN et_popricing[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_popricing>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_popricing ASSIGNING <fs_popricing>.
                <fs_popricing>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_popricing>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIPriIdx = li_POIPriIdx + 10.
              <fs_popricing>-%target = VALUE #( BASE <fs_popricing>-%target
                                                ( %cid                    = |POIP{ li_POIPriIdx }|
                                                  PurchaseOrderItem       = li_POitem_idx
                                                  ConditionType           = lc_zmup
                                                  ConditionRateAmount     = ls_items-markupamount
                                                  ConditionCurrency       = ls_items-transactioncurrency
*                                                  ConditionCurrency       = gs_header-GlobalCurrency
                                                  ConditionQuantity       = lc_100
                                                  PricingProcedureStep    = '092'
                                                  PricingProcedureCounter = '001'
                                                  PricingDocumentItem     = li_POItmPrice
                                                  %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                     ConditionType           = if_abap_behv=>mk-on
                                                                                     ConditionRateAmount     = if_abap_behv=>mk-on
                                                                                     ConditionCurrency       = if_abap_behv=>mk-on
                                                                                     ConditionQuantity       = if_abap_behv=>mk-on
                                                                                     PricingDocumentItem     = if_abap_behv=>mk-on
                                                                                     PricingProcedureStep    = if_abap_behv=>mk-on
                                                                                     PricingProcedureCounter = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_popricing>.
            ENDIF.
          ENDIF.


          IF ls_items-grossingupbaseamount  <> 0.
            IF line_exists( gtd_glaccount[ ChartOfAccounts = gs_header-ChartOfAccounts
                                           transactiontypedetermination = 'ZIN'
                                           valuationareagroup = lc_gupb
                                           Product = ls_items-Product
                                           Plant = ls_items-ProviderPlant
                                           CompanyCode = ls_items-providercompanycode
                                         ] ).
              ls_glaccount = gtd_glaccount[ ChartOfAccounts = gs_header-ChartOfAccounts
                                            transactiontypedetermination = 'ZIN'
                                            valuationareagroup = lc_GUPb
                                            Product = ls_items-Product
                                            Plant = ls_items-ProviderPlant
                                            CompanyCode = ls_items-providercompanycode
                                            ].

*              li_POIAccIdx = li_POIAccIdx + 10.
*              li_POIPriIdx = li_POIPriIdx + 10.
              lv_secuencial = lv_secuencial + 1.
              "GrossingUpBaseAmount / GrossingUpBaseGLAccount
              ASSIGN et_poaccassig[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_poaccassig>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_poaccassig ASSIGNING <fs_poaccassig>.
                <fs_poaccassig>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_poaccassig>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIAccIdx = li_POIAccIdx + 10.
              <fs_poaccassig>-%target = VALUE #( BASE <fs_poaccassig>-%target
                                                 ( %cid                    = |POIA{ li_POIAccIdx }|
                                                   PurchaseOrderItem       = li_POitem_idx
                                                   AccountAssignmentNumber = lv_secuencial
                                                   CostCenter              = |9541{ ls_items-internalcode }{ ls_items-profitcenter ALPHA = OUT }|
                                                   Quantity                = lc_100
                                                   PurgDocNetAmount        = ls_items-grossingupbaseamount                "GrossingUpBaseAmount
                                                   GLAccount               = ls_glaccount-debitglaccount                 "GrossingUpBaseGLAccount
                                                   %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                      AccountAssignmentNumber = if_abap_behv=>mk-on
                                                                                      CostCenter              = if_abap_behv=>mk-on
                                                                                      PurgDocNetAmount        = if_abap_behv=>mk-on
                                                                                      Quantity                = if_abap_behv=>mk-on
                                                                                      GLAccount               = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_poaccassig>.

              "GrossingUpBase
              ASSIGN et_popricing[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_popricing>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_popricing ASSIGNING <fs_popricing>.
                <fs_popricing>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_popricing>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIPriIdx = li_POIPriIdx + 10.
              <fs_popricing>-%target = VALUE #( BASE <fs_popricing>-%target
                                                ( %cid                    = |POIP{ li_POIPriIdx }|
                                                  PurchaseOrderItem       = li_POitem_idx
                                                  ConditionType           = lc_zgub
                                                  ConditionRateAmount     = ls_items-grossingupbaseamount
                                                  ConditionCurrency       = ls_items-transactioncurrency
*                                                  ConditionCurrency       = gs_header-GlobalCurrency
                                                  ConditionQuantity       = lc_100
                                                  PricingProcedureStep    = '091'
                                                  PricingProcedureCounter = '001'
                                                  PricingDocumentItem     = li_POItmPrice
                                                  %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                     ConditionType           = if_abap_behv=>mk-on
                                                                                     ConditionRateAmount     = if_abap_behv=>mk-on
                                                                                     ConditionCurrency       = if_abap_behv=>mk-on
                                                                                     ConditionQuantity       = if_abap_behv=>mk-on
                                                                                     PricingDocumentItem     = if_abap_behv=>mk-on
                                                                                     PricingProcedureStep    = if_abap_behv=>mk-on
                                                                                     PricingProcedureCounter = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_popricing>.
            ENDIF.
          ENDIF.

          IF ls_items-grossingupmarginamount <> 0.
            IF line_exists( gtd_glaccount[ ChartOfAccounts = gs_header-ChartOfAccounts
                                           transactiontypedetermination = 'ZIN'
                                           valuationareagroup = lc_gupk
                                           Product = ls_items-Product
                                           Plant = ls_items-ProviderPlant
                                           CompanyCode = ls_items-providercompanycode
                                         ] ).
              ls_glaccount = gtd_glaccount[ ChartOfAccounts = gs_header-ChartOfAccounts
                                            transactiontypedetermination = 'ZIN'
                                            valuationareagroup = lc_gupk
                                            Product = ls_items-Product
                                            Plant = ls_items-ProviderPlant
                                            CompanyCode = ls_items-providercompanycode
                                            ].

*              li_POIAccIdx = li_POIAccIdx + 10.
*              li_POIPriIdx = li_POIPriIdx + 10.
              lv_secuencial = lv_secuencial + 1.
              "GrossingUpMarginAmount / GrossingUpMarginGLAccount
              ASSIGN et_poaccassig[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_poaccassig>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_poaccassig ASSIGNING <fs_poaccassig>.
                <fs_poaccassig>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_poaccassig>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIAccIdx = li_POIAccIdx + 10.
              <fs_poaccassig>-%target = VALUE #( BASE <fs_poaccassig>-%target
                                                 ( %cid                    = |POIA{ li_POIAccIdx }|
                                                   PurchaseOrderItem       = li_POitem_idx
                                                   AccountAssignmentNumber = lv_secuencial
                                                   CostCenter              = |9541{ ls_items-internalcode }{ ls_items-profitcenter ALPHA = OUT }|
                                                   Quantity                = lc_100
                                                   PurgDocNetAmount        = ls_items-grossingupmarginamount                "GrossingUpMarginAmount
                                                   GLAccount               = ls_glaccount-debitglaccount                 "GrossingUpMarginGLAccount
                                                   %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                      AccountAssignmentNumber = if_abap_behv=>mk-on
                                                                                      CostCenter              = if_abap_behv=>mk-on
                                                                                      Quantity                = if_abap_behv=>mk-on
                                                                                      PurgDocNetAmount        = if_abap_behv=>mk-on
                                                                                      GLAccount               = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_poaccassig>.

              "GrossingUpMarkup
              ASSIGN et_popricing[ %cid_ref = |POI{ li_POitem_idx }| ] TO <fs_popricing>.
              IF sy-subrc NE 0.
                APPEND INITIAL LINE TO et_popricing ASSIGNING <fs_popricing>.
                <fs_popricing>-%cid_ref = |POI{ li_POitem_idx }|.
                <fs_popricing>-PurchaseOrderItem = li_POitem_idx.
              ENDIF.
              li_POIPriIdx = li_POIPriIdx + 10.
              <fs_popricing>-%target = VALUE #( BASE <fs_popricing>-%target
                                                ( %cid                    = |POIP{ li_POIPriIdx }|
                                                  PurchaseOrderItem       = li_POitem_idx
                                                  ConditionType           = lc_zgum
                                                  ConditionRateAmount     = ls_items-grossingupmarginamount
                                                  ConditionCurrency       = ls_items-transactioncurrency
*                                                  ConditionCurrency       = gs_header-GlobalCurrency
                                                  PricingProcedureStep    = '093'
                                                  PricingProcedureCounter = '001'
                                                  PricingDocumentItem     = li_POItmPrice
                                                  %control                = VALUE #( PurchaseOrderItem       = if_abap_behv=>mk-on
                                                                                     ConditionType           = if_abap_behv=>mk-on
                                                                                     ConditionRateAmount     = if_abap_behv=>mk-on
                                                                                     ConditionCurrency       = if_abap_behv=>mk-on
                                                                                     PricingDocumentItem     = if_abap_behv=>mk-on
                                                                                     PricingProcedureStep    = if_abap_behv=>mk-on
                                                                                     PricingProcedureCounter = if_abap_behv=>mk-on ) ) ).
              UNASSIGN <fs_popricing>.
            ENDIF.
          ENDIF.

          CLEAR lv_secuencial.

        ENDLOOP.

        IF gtc_purchaseorder[] IS NOT INITIAL AND
           gtc_POItem[] IS NOT INITIAL.

          " llamo a la clase que ejecuta en paralelo.
          lo_proposal_paralel = NEW zcl_proposal_bo_po_paralel( is_header    = gs_header
                                                                it_doc       = gtd_doc
                                                                its_doc      = gts_doc
                                                                it_doc_map   = gt_doc_map
                                                                it_poheader  = et_purchaseorder
                                                                it_poitems   = et_poitems
                                                                it_poaccount = et_poaccassig
                                                                it_popricing = et_popricing
                                                                iv_process   = zcl_boproposal_tools=>gc_create_doc ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

          FREE: et_purchaseorder,
                et_poitems,
                et_poaccassig,
                et_popricing,
                gt_doc_map.
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


  METHOD exe_anulation_bo_sec.

    DATA lv_status TYPE zfi_a_intrc_cpid-status.
    DATA lv_date   TYPE d.

    "Esta acción no esta permitida para proceso masivo, se implementa ejecución en paralelo
    LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>).
      CLEAR: gt_cancelinvoice, gt_doc_map.

      " The %cid (temporary primary key) has always to be supplied
      TRY.
          DATA(lv_cid) = cl_uuid_factory=>create_system_uuid( )->create_uuid_x16( ).
        CATCH cx_uuid_error.
          "Error handling
      ENDTRY.

      APPEND INITIAL LINE TO gt_cancelinvoice ASSIGNING FIELD-SYMBOL(<fs_cancelinvoice>).
      " Fill Parameters for Action
      <fs_cancelinvoice>-%cid                       = lv_cid.
      <fs_cancelinvoice>-SupplierInvoice            = <fs_doc>-Documentkey(10).
      <fs_cancelinvoice>-SupplierInvoiceFiscalYear  = gs_header-FiscalYear.
      <fs_cancelinvoice>-%param-ReversalReason      = '01'.     "Reversal in current period

      lv_date = |{ gs_header-FiscalYear }{ gs_header-FiscalPeriod+1(2) }01|.
      get_last_day_of_month( EXPORTING day_in            = lv_date
                             IMPORTING last_day_of_month = lv_date ).
      <fs_cancelinvoice>-%param-PostingDate         = lv_date.

      APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
      <fs_doc_map> = <fs_doc>.

      DATA(lo_exe_bo) = NEW zcl_proposal_bo_po_paralel( it_doc_map = gt_doc_map
                                                        iv_process = zcl_boproposal_tools=>gc_reverse_doc ).

      APPEND INITIAL LINE TO gtd_list_bo ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
      <fs_list_bo> = lo_exe_bo.
    ENDLOOP.
    exe_bo( ).

  ENDMETHOD.


  METHOD mapping_reverse_sec.
    DATA ls_doc_si TYPE LINE OF gtty_doc.
    DATA lv_prevdockey TYPE zfi_a_intrc_cpid-documentkey.
    gt_doc_map_si = gt_doc_map.
    CHECK gtd_doc IS NOT INITIAL.
    "TODOS LOS DOCUMENTOS YA DEBEN VENIR FILTRADOS (NO DUMMY)
    FREE gtd_list_bo.
    TRY.
        " Deletion Indicator in Purchasing Document
        LOOP AT gtd_doc ASSIGNING FIELD-SYMBOL(<fs_doc>) WHERE DocumentType = zcl_proposal_bo_abs=>c_document_type-purchaseorder.
*                                                           AND Status <> zcl_proposal_bo_abs=>c_document_status-anulated.
*          FREE gt_doc_map.
*
*          APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc_map>).
*          <fs_doc_map> = <fs_doc>.
*
*          DATA(lo_exe_bo) = NEW zcl_proposal_bo_po_paralel( it_doc_map = gt_doc_map
*                                                            iv_process = zcl_boproposal_tools=>gc_reverse_doc ).
*
*          APPEND INITIAL LINE TO gtd_list_bo ASSIGNING FIELD-SYMBOL(<fs_list_bo>).
*          <fs_list_bo> = lo_exe_bo.
          "Validaciones para reprocesar anulaciones
          CHECK NOT line_exists( gtd_anul_doc[ ParentDocumentKey = <fs_doc>-Documentkey ] )
          OR gtd_anul_doc[ ParentDocumentKey = <fs_doc>-Documentkey ]-Documentkey(5) EQ 'DUMMY'.
          "Validaciones para primer procesamiento
          "Si la orden aun no tiene factura, no deberiamos anular?
          DATA(lv_si_dockey) = VALUE #( gtd_doc[ Documenttype       = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                                                 ParentDocumentKey  = <fs_doc>-Documentkey
                                                 ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-purchaseorder ]-Documentkey OPTIONAL ).

          DATA(lv_anul_si_dk) = VALUE #( gtd_anul_doc[ Documenttype       = zcl_proposal_bo_abs=>c_document_type-anul_suppinv
                                                       ParentDocumentKey  = lv_si_dockey
                                                       ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-invoicesupplier ]-Documentkey OPTIONAL ).
          IF lv_anul_si_dk IS INITIAL.
            lv_anul_si_dk = VALUE #( gt_doc_map_si[ Documenttype       = zcl_proposal_bo_abs=>c_document_type-anul_suppinv
                                                    ParentDocumentKey  = lv_si_dockey
                                                    ParentDocumentType = zcl_proposal_bo_abs=>c_document_type-invoicesupplier ]-Documentkey OPTIONAL ).
            "Si la factura de venta aun no se anula, no se puede anular la orden
            IF lv_anul_si_dk IS INITIAL AND lv_si_dockey IS NOT INITIAL.
              CONTINUE.
            ENDIF.
          ENDIF.
          IF NOT line_exists( gt_doc_map[ ParentDocumentKey = <fs_doc>-Documentkey ] ).
            IF lv_prevdockey IS NOT INITIAL
            AND lv_prevdockey NE <fs_doc>-Documentkey.
              DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_po_paralel(
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
          ls_doc_si-id          = <fs_doc>-id.
          ls_doc_si-item_id      = <fs_doc>-item_id.
          ls_doc_si-Itembasis_Id = <fs_doc>-Itembasis_Id.
          ls_doc_si-Itemcalc_Id  = <fs_doc>-Itemcalc_Id.
          ls_doc_si-Documenttype  = zcl_proposal_bo_abs=>c_document_type-anul_purchorder.
          ls_doc_si-ParentDocumentType  = zcl_proposal_bo_abs=>c_document_type-purchaseorder.
          ls_doc_si-Documentkey = |DUMMY{ <fs_doc>-Documentkey }|.
          ls_doc_si-ParentDocumentKey  = <fs_doc>-Documentkey.
          APPEND ls_doc_si TO gt_doc_map.
        ENDLOOP.
        IF gt_doc_map[] IS NOT INITIAL.
          lo_proposal_paralel = NEW zcl_proposal_bo_po_paralel(
            it_doc               = gtd_doc
            its_doc              = gts_doc
            it_doc_map           = gt_doc_map
            iv_parentdocumentkey = ls_doc_si-ParentDocumentKey
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
      CATCH cx_sy_conversion_no_date INTO DATA(cx_date).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
      CATCH cx_sy_itab_line_not_found INTO DATA(cx_line_not_found).
        save_log( ).
        RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDTRY.
  ENDMETHOD.


  METHOD get_last_day_of_month.

    CONSTANTS december TYPE c LENGTH 2 VALUE '12'.
    CONSTANTS first    TYPE c LENGTH 2 VALUE '01'.

    CONSTANTS: BEGIN OF highdate,
                 j TYPE c LENGTH 4 VALUE '9999',
                 m TYPE c LENGTH 2 VALUE '12',
                 t TYPE c LENGTH 2 VALUE '31',
               END OF highdate.

    DATA: BEGIN OF date,
            j TYPE c LENGTH 4,
            m TYPE c LENGTH 2,
            t TYPE c LENGTH 2,
          END OF date.

    DATA: zahl TYPE n LENGTH 2.

    date = day_in.

    IF date-j = highdate-j AND
       date-m = highdate-m.

      last_day_of_month = highdate.

    ELSE.
      IF date-m = december.
        zahl = date-j + 1.
        date-j = zahl.
        date-m = first.
      ELSE.
        zahl = date-m + 1.
        date-m = zahl.
      ENDIF.

      date-t = first.
      last_day_of_month = date.
      last_day_of_month -= 1.
    ENDIF.

  ENDMETHOD.


  METHOD mapping_bo.

  ENDMETHOD.


  METHOD preparedata.
    " Agregar lógica para todos aquellos campos que no esten en la cabecera principal
  ENDMETHOD.


  METHOD get_po_data.

  ENDMETHOD.


  METHOD call_bapi_po_create.

***    zcl_mm_create_po=>call_bapi_mock(
***      IMPORTING
***        ev_purchaseorder  = DATA(lv_po)
***    ).

  ENDMETHOD.


  METHOD supplier_inv.

  ENDMETHOD.
ENDCLASS.
