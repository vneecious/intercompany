CLASS zcl_proposal_bo_supplierinv DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_wht_aux,
             primary_key        TYPE string,
             WithholdingTaxType TYPE zde_witht,
             WithholdingTaxCode TYPE zde_wt_withcd,
             DocumentCurrency   TYPE waers,
           END OF ty_wht_aux.
    TYPES: tt_wht_aux TYPE STANDARD TABLE OF ty_wht_aux WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_wht_code,
        DocumentCurrency   TYPE waers,
        WithholdingTaxCode TYPE zde_wt_withcd,
        WithholdingTaxType TYPE zde_witht,
      END OF ty_wht_code .
    TYPES:
      ty_t_wht_code TYPE STANDARD TABLE OF ty_wht_code WITH EMPTY KEY .
    TYPES:
      BEGIN OF ty_wht,
        supplier           TYPE lifnr,
        companycode        TYPE bukrs,
        withholdingtaxtype TYPE zde_witht,
        withholdingtaxcode TYPE zde_wt_withcd,
      END OF ty_wht .
    TYPES:
      ty_t_wht TYPE STANDARD TABLE OF ty_wht WITH EMPTY KEY .
    TYPES:
      lty_items   TYPE STRUCTURE FOR ACTION IMPORT i_supplierinvoicetp~create,
      tt_wht_code TYPE lty_items-%param-_withholdingtaxes.

    DATA:
      gta_invoice_create     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~create .
    DATA:
      gta_invoice_cancel     TYPE TABLE FOR ACTION IMPORT i_supplierinvoicetp~Cancel .
    DATA:
      gtc_PurchaseOrder      TYPE TABLE FOR CREATE i_purchaseordertp_2 .
    DATA:
      gtc_POItem             TYPE TABLE FOR CREATE i_purchaseordertp_2\_purchaseorderitem .
    DATA gtd_list_bo TYPE cl_abap_parallel=>t_in_inst_tab .
    DATA gs_header_si TYPE zi_intercoproposal .
    DATA gv_parentdockey_si TYPE zfi_a_intrc_cpid-documentkey .
    DATA gtd_doc_si TYPE gtty_doc .
    DATA gt_doc_map_si TYPE gtty_doc .
    DATA gt_doc_map_po TYPE gtty_doc .
    DATA gts_doc_si TYPE gtsty_doc .
    DATA gv_process_si TYPE c .

    METHODS constructor
      IMPORTING
        !is_header      TYPE zi_intercoproposal OPTIONAL
        !it_items       TYPE ztt_proposalitem_add OPTIONAL
        !it_items_add   TYPE ztt_proposalitem_add OPTIONAL
        !it_bases       TYPE gtty_bases OPTIONAL
        !it_calc        TYPE gtty_calc OPTIONAL
        !it_doc         TYPE gtty_doc OPTIONAL
        !it_anul_doc    TYPE gtty_doc OPTIONAL
        !its_bases      TYPE gtsty_bases OPTIONAL
        !its_calc       TYPE gtsty_calc OPTIONAL
        !its_doc        TYPE gtsty_doc OPTIONAL
        !it_glaccount   TYPE ztt_proposal_reclassif OPTIONAL
        !iv_process     TYPE c OPTIONAL
        !iv_documentkey TYPE zfi_a_intrc_cpid-documentkey OPTIONAL
        !it_doc_map     TYPE gtty_doc OPTIONAL .
  PROTECTED SECTION.

    METHODS exe_bo REDEFINITION .
    METHODS mapping_bo_sec REDEFINITION .
    METHODS mapping_reverse_sec REDEFINITION.
    METHODS preparedata REDEFINITION.
    METHODS mapping_bo REDEFINITION.
  PRIVATE SECTION.

    METHODS get_wht_codes_for_item
      IMPORTING
        !iv_cid_invoice    TYPE string
        !iv_supplier       TYPE zbu_partner
        !iv_companycode    TYPE bukrs
        !iv_provider       TYPE zfi_proposalitem_add-providercompanycode
        !iv_recipient      TYPE zfi_proposalitem_add-recipientcompanycode
        !iv_product        TYPE zfi_proposalitem_add-product
        !iv_currency       TYPE zint_dte_fis_rkcur
        !it_wht            TYPE ty_t_wht
      RETURNING
        VALUE(rt_wht_code) TYPE tt_wht_code.
ENDCLASS.



CLASS zcl_proposal_bo_supplierinv IMPLEMENTATION.


  METHOD exe_bo.
    DATA lv_debug TYPE abap_boolean.
    DATA lo_si_parallel TYPE REF TO zcl_proposal_bo_suppinv_par.
    DATA lv_status_log TYPE c.
    DATA lt_supplinv TYPE TABLE FOR REPORTED LATE i_supplierinvoicetp\\supplierinvoice.
    DATA lv_byuser     TYPE zfi_a_intrc_cpid-createdby.
    DATA lv_attime     TYPE zfi_a_intrc_cpid-createdat.
    lv_byuser = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_attime.

    CHECK gtd_list_bo IS NOT INITIAL.

    DATA(l_ref) = NEW cl_abap_parallel( ).
    l_ref->run_inst( EXPORTING p_in_tab  = gtd_list_bo
                               p_debug   = lv_debug
                     IMPORTING p_out_tab = DATA(l_out_tab) ).

    LOOP AT l_out_tab ASSIGNING FIELD-SYMBOL(<l_out>).
      IF <l_out>-inst IS NOT INITIAL.
        lo_si_parallel ?= <l_out>-inst.
      ELSE.
        IF <l_out>-message IS NOT INITIAL.
          lo_si_parallel ?= gtd_list_bo[ <l_out>-index ].
          lt_supplinv = VALUE #( ( %msg = new_message( id       = 'ZINT_MSG_INTERCO_CP'
                                                       number   = '022'
                                                       severity = if_abap_behv_message=>severity-error ) ) ).

          mapping_doc_log(
            EXPORTING
              iv_doctype    = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
              it_reported   = lt_supplinv
            CHANGING
              ct_map_id_doc = lo_si_parallel->gt_doc_map_si
              cv_status     = lv_status_log
          ).
          mapping_doc( EXPORTING "iv_dockey       = iv_dockey
                                 iv_doctype       = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                                 iv_parentdockey  = lo_si_parallel->gt_doc_map_si[ 1 ]-parentdocumentkey
                                 iv_parentdoctype = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                 iv_status        = zcl_proposal_bo_abs=>c_document_status-error
                                 iv_cat_id        = zcl_proposal_bo_abs=>c_document_category-invoicing
                                 iv_isadjustment  = space
                                 its_doc          = gts_doc
                                 iv_byuser        = lv_byuser
                                 iv_attime        = lv_attime
                                 iv_process       = gv_process_si
                       CHANGING  ct_map_id_doc    = lo_si_parallel->gt_doc_map_si ).
        ENDIF.
      ENDIF.
      APPEND LINES OF lo_si_parallel->gt_doc_map_si TO me->gt_doc_map.
    ENDLOOP.
  ENDMETHOD.


  METHOD mapping_reverse_sec.
    DATA ls_doc_map_si TYPE LINE OF gtty_doc.
    DATA lv_prevdockey TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_prevfiscalyear TYPE zfi_a_intrc_cpid-fiscalyear.
    DATA lv_prevparentdockey TYPE zfi_a_intrc_cpid-parentdocumentkey.
    TRY.
        "Esta acción no esta permitida para proceso masivo, se implementa ejecución en paralelo
        LOOP AT gtd_doc_si INTO DATA(ls_doc_si)." ASSIGNING FIELD-SYMBOL(<fs_doc_si>).

          CHECK NOT line_exists( gtd_anul_doc[ ParentDocumentKey = ls_doc_si-Documentkey ] )
                OR gtd_anul_doc[ ParentDocumentKey = ls_doc_si-Documentkey ]-Documentkey(5) EQ 'DUMMY'.

          IF NOT line_exists( gt_doc_map_si[ ParentDocumentKey = ls_doc_si-Documentkey ] ).
            IF gta_invoice_cancel[] IS NOT INITIAL.
              DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_suppinv_par(
*            it_doc               = gtd_doc_si
                its_doc              = gts_doc_si
                it_doc_map           = gt_doc_map_si
                iv_documentkey       = lv_prevdockey
                iv_fiscalyear        = lv_prevfiscalyear
                iv_parentdocumentkey = lv_prevparentdockey
                ita_invoice_cancel   = gta_invoice_cancel
                iv_process           = gv_process_si "gv_process
              ).

              INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.
              FREE: gta_invoice_cancel.
            ENDIF.
            DATA(ld_lastday) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header_si-FiscalYear }{ gs_header_si-FiscalPeriod+1 }01| ).
            gta_invoice_cancel = VALUE #( ( %cid                      = |BD{ sy-tabix }|
                                            SupplierInvoice           = CONV #( ls_doc_si-Documentkey )
                                            SupplierInvoiceFiscalYear = ls_doc_si-FiscalYear
                                            %param-ReversalReason     = '01' "Reversal in current period
                                            %param-PostingDate        = ld_lastday )
                                        ).

            FREE: gt_doc_map_si.
            lv_prevdockey = ls_doc_si-Documentkey."SI
            lv_prevfiscalyear = ls_doc_si-FiscalYear."SIFY
            lv_prevparentdockey = ls_doc_si-ParentDocumentKey."PO
          ENDIF.
          ls_doc_map_si-id          = ls_doc_si-id.
          ls_doc_map_si-item_id      = ls_doc_si-item_id.
          ls_doc_map_si-itembasis_id = ls_doc_si-itembasis_id.
          ls_doc_map_si-itemcalc_id  = ls_doc_si-itemcalc_id.
          ls_doc_map_si-Documenttype  = zcl_proposal_bo_abs=>c_document_type-anul_suppinv.
          ls_doc_map_si-ParentDocumentType  = zcl_proposal_bo_abs=>c_document_type-invoicesupplier.
          ls_doc_map_si-Documentkey = |DUMMY{ ls_doc_si-Documentkey }|.
          ls_doc_map_si-ParentDocumentKey  = ls_doc_si-Documentkey.
          ls_doc_map_si-ParentFiscalyear  = ls_doc_si-FiscalYear.
          APPEND ls_doc_map_si TO gt_doc_map_si.
        ENDLOOP.
        IF gta_invoice_cancel[] IS NOT INITIAL.
          lo_proposal_paralel = NEW zcl_proposal_bo_suppinv_par(
*        it_doc               = gtd_doc_si
            its_doc              = gts_doc_si
            it_doc_map           = gt_doc_map_si
            iv_documentkey       = ls_doc_si-Documentkey
            iv_fiscalyear        = ls_doc_si-FiscalYear
            iv_parentdocumentkey = ls_doc_si-ParentDocumentKey
            ita_invoice_cancel   = gta_invoice_cancel
            iv_process           = gv_process_si ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

          FREE: gta_invoice_cancel,
                gt_doc_map_si.
        ENDIF.
        CHECK gtd_list_bo IS NOT INITIAL.
        exe_bo( ).
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


  METHOD mapping_bo_sec.

    "Creación factura de compras
    TYPES: lty_poitem  TYPE STRUCTURE FOR CREATE i_purchaseordertp_2\_purchaseorderitem,
           lty_itemacc TYPE STRUCTURE FOR CREATE i_purchaseorderitemtp_2\_purordaccountassignment,
           lty_itempri TYPE STRUCTURE FOR CREATE i_purchaseorderitemtp_2\_purordpricingelement,
           lty_po      TYPE STRUCTURE FOR CREATE i_purchaseordertp_2.

    TYPES: lty_items TYPE STRUCTURE FOR ACTION IMPORT i_supplierinvoicetp~create.

    TYPES: BEGIN OF ty_key,
             supplier    TYPE zbu_partner,
             companycode TYPE bukrs,
           END OF ty_key.

    DATA: lt_keys TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.
    DATA: ls_invoice    TYPE lty_items,
          lt_items      TYPE lty_items-%param-_itemswithporeference,
          ls_items      TYPE LINE OF lty_items-%param-_itemswithporeference,
          lt_acctarget  TYPE lty_itemacc-%target,
          ls_acctarget  TYPE LINE OF lty_itemacc-%target,
          lt_dockey     TYPE gtty_parentkey,
          lt_itemtarget TYPE lty_poitem-%target,
          ls_itemtarget TYPE LINE OF lty_poitem-%target,
          ls_wht_code   TYPE LINE OF lty_items-%param-_withholdingtaxes.
*          lt_wht_code   TYPE lty_items-%param-_withholdingtaxes.

    DATA: lv_doc         TYPE ebeln,
          lv_lastday     TYPE d,
          lv_orderitem   TYPE n LENGTH 4 VALUE 0,
          lv_suppitem    TYPE n LENGTH 2,
          lv_amount      TYPE p DECIMALS 2,
          lv_netprice    TYPE p DECIMALS 2,
          lv_count       TYPE n,
          lv_date        TYPE d,
          lv_taxcode     TYPE c LENGTH 2,
          lv_parent      TYPE zfi_a_intrc_cpid-documentkey,
          lv_supplier    TYPE zbu_partner,
          lv_companycode TYPE bukrs.

    DATA lv_providercompanycode  TYPE zfi_proposalitem_add-providercompanycode.
    DATA lv_product              TYPE zfi_proposalitem_add-product.
    DATA lv_recipientcompanycode TYPE zfi_proposalitem_add-recipientcompanycode.
    DATA lv_flow                 TYPE zfi_proposalitem_add-flow.
    DATA lv_line_exists TYPE c.
    DATA ls_doc_si TYPE LINE OF gtty_doc.
*    DATA lt_po_fixed TYPE SORTED TABLE OF ebeln WITH UNIQUE KEY table_line.
    TYPES: BEGIN OF ty_id,
             purchaseorder TYPE ebeln, "Tipo correcto (10 caracteres)
           END OF ty_id.
    TYPES: ty_t_po_fixed TYPE HASHED TABLE OF ty_id WITH UNIQUE KEY purchaseorder.
    TYPES: BEGIN OF ty_wht,
             supplier           TYPE lifnr,
             companycode        TYPE bukrs,
             withholdingtaxtype TYPE zde_witht,
             withholdingtaxcode TYPE zde_wt_withcd,
           END OF ty_wht.
    TYPES: ty_t_wht TYPE STANDARD TABLE OF ty_wht WITH EMPTY KEY.
    DATA: lt_wht TYPE ty_t_wht.
    DATA: lt_wht_for_item TYPE ty_t_wht.
**********************************************************************

    " Tabla de pedidos únicos
    DATA: lt_po_fixed TYPE ty_t_po_fixed.
    " Variable temporal para extraer el PO
    DATA: lv_po TYPE ebeln.

    CLEAR gt_doc_map.
    TRY.
        CHECK gt_doc_map_po IS NOT INITIAL.
        SORT gtd_items_add BY providercompanycode
                              product
                              recipientcompanycode
                              flow.

        SORT gt_doc_map_po BY documentkey.

        LOOP AT gt_doc_map_po ASSIGNING FIELD-SYMBOL(<fs_doc_map_po>).

          " Omitir registros dummy de tipo purchase order
          IF <fs_doc_map_po>-Documentkey(5) EQ 'DUMMY'
             AND <fs_doc_map_po>-Documenttype = zcl_proposal_bo_abs=>c_document_type-purchaseorder.
            CONTINUE.
          ENDIF.

          " Determinar el número de pedido de compras
          lv_po = COND ebeln(
                    WHEN <fs_doc_map_po>-documenttype = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                    THEN <fs_doc_map_po>-documentkey+5(10)
                    ELSE <fs_doc_map_po>-documentkey(10)
                  ).

          " Insertar solo si es único
          READ TABLE lt_po_fixed WITH TABLE KEY purchaseorder = lv_po TRANSPORTING NO FIELDS.
          IF sy-subrc <> 0.
            INSERT VALUE #( purchaseorder = lv_po ) INTO TABLE lt_po_fixed.
          ENDIF.

        ENDLOOP.

        IF lt_po_fixed[] IS NOT INITIAL.
          "Obtenemos taxcode de PO para mapear a la factura
          SELECT purchaseorder,
                 purchaseorderitem,
                 taxcode
                 FROM i_purchaseorderitemtp_2
                 WITH PRIVILEGED ACCESS
                 FOR ALL ENTRIES IN @lt_po_fixed
                 WHERE purchaseorder = @lt_po_fixed-purchaseorder
                 INTO TABLE @DATA(lt_poitems).
        ENDIF.

        IF gtd_items_add[] IS NOT INITIAL.
          LOOP AT gtd_items_add INTO DATA(ls_item).
            APPEND VALUE #( supplier = ls_item-providervendor
                            companycode = ls_item-recipientcompanycode ) TO lt_keys.
            APPEND VALUE #( supplier = ls_item-recipientcustomer
                            companycode = ls_item-providercompanycode ) TO lt_keys.
          ENDLOOP.

          SORT lt_keys BY supplier companycode.
          DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING ALL FIELDS.
          "Obtiene tipos de retención
          SELECT supplier,
                 companycode,
                 withholdingtaxtype,
                 withholdingtaxcode
            FROM i_supplierwithholdingtax
            WITH PRIVILEGED ACCESS
            FOR ALL ENTRIES IN @lt_keys
                 WHERE supplier = @lt_keys-supplier
                   AND companycode = @lt_keys-companycode
            INTO TABLE @lt_wht.

        ENDIF.

        LOOP AT gtd_items_add INTO DATA(ls_items_rep).
          CLEAR: gs_bases,
                 gs_calc,
                 lv_netprice.

          DATA(lv_tabix) = sy-tabix.

          IF lv_providercompanycode  <> ls_items_rep-providercompanycode  OR
             lv_product              <> ls_items_rep-product              OR
             lv_recipientcompanycode <> ls_items_rep-recipientcompanycode OR
             lv_flow                 <> ls_items_rep-flow.

            IF lt_items[] IS NOT INITIAL.

**********************************************************************
              "Determinación de impuesto de retención
              DATA(lt_wht_code) = me->get_wht_codes_for_item(
                                    iv_cid_invoice = ls_invoice-%cid
                                    iv_supplier    = lv_supplier
                                    iv_companycode = lv_companycode
                                    iv_provider    = lv_providercompanycode
                                    iv_recipient   = lv_recipientcompanycode
                                    iv_product     = gs_header-product
                                    iv_currency    = ls_items_rep-transactioncurrency
                                    it_wht         = lt_wht ).

              IF lt_wht_code IS NOT INITIAL.
                ls_invoice-%param-_withholdingtaxes = lt_wht_code.
              ENDIF.

**********************************************************************
              ls_invoice-%param-invoicegrossamount = lv_amount.
              INSERT ls_invoice INTO TABLE gta_invoice_create.

              lv_parent = lv_doc.

              " llamo a la clase que ejecuta en paralelo.
              DATA(lo_proposal_paralel) = NEW zcl_proposal_bo_suppinv_par( iv_process           = zcl_boproposal_tools=>gc_create_doc
                                                                           iv_parentdocumentkey = lv_parent
                                                                           it_doc_map           = gt_doc_map
                                                                           ita_invoice_create   = gta_invoice_create
                                                                           ).

              INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.

              FREE: lt_items,
                    lt_wht_code,
                    gta_invoice_create,
                    gt_doc_map,
                    ls_invoice,
*                    lv_tax_code,
                    lv_netprice,
                    lv_amount,
                    lv_orderitem,
                    lv_suppitem.
            ENDIF.

            "CompanyCode / Supplier
            IF ls_items_rep-flow EQ gc_outflow.
              lv_companycode = ls_items_rep-recipientcompanycode.
              lv_supplier = ls_items_rep-providervendor.
            ELSEIF ls_items_rep-flow EQ gc_inflow.
              lv_companycode = ls_items_rep-providercompanycode.
              lv_supplier = ls_items_rep-recipientcustomer.
            ENDIF.

            ls_invoice-%cid = |SI{ lv_tabix }|.
            ls_invoice-%param-companycode = lv_companycode.
            IF gs_header-amountinglobalcurrency GT 0.
              ls_invoice-%param-supplierinvoiceiscreditmemo = space.   ""
            ELSE.
              ls_invoice-%param-supplierinvoiceiscreditmemo = abap_true.
            ENDIF.

            READ TABLE gt_doc_map_po INTO DATA(ls_doc) WITH KEY id = ls_items_rep-id
                                                          item_id      = ls_items_rep-item_id
                                                          itembasis_id = ls_items_rep-itembasis_id
                                                          itemcalc_id  = ls_items_rep-itemcalc_id.
            IF ls_doc-Documentkey(5) EQ 'DUMMY'.
              lv_doc = ls_doc-documentkey+5(10).
            ELSE.
              lv_doc = ls_doc-documentkey(10).
            ENDIF.

            ls_invoice-%param-accountingdocumenttype       = 'IR'.

            lv_lastday = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

            ls_invoice-%param-documentdate                 = lv_lastday.
            ls_invoice-%param-postingdate                  = lv_lastday.
            ls_invoice-%param-supplierinvoicestatus        = space.
            ls_invoice-%param-documentheadertext           = |{ gs_header-providercompanycode } { gs_header-product }|.
            ls_invoice-%param-supplierpostinglineitemtext  = |Fact { gs_header-providercompanycode } { gs_header-product } { gs_header-fiscalperiod+1 } { gs_header-fiscalyear }|.
            ls_invoice-%param-invoicingparty               = lv_supplier.
            ls_invoice-%param-documentcurrency             = ls_items_rep-transactioncurrency.
            ls_invoice-%param-taxiscalculatedautomatically = space.
          ENDIF.

          APPEND INITIAL LINE TO gt_doc_map ASSIGNING FIELD-SYMBOL(<fs_doc>).
          <fs_doc>-id                 = ls_items_rep-id.
          <fs_doc>-item_id             = ls_items_rep-item_id.
          <fs_doc>-itembasis_id        = ls_items_rep-itembasis_id.
          <fs_doc>-itemcalc_id         = ls_items_rep-itemcalc_id.
          <fs_doc>-documentkey        = |DUMMY{ lv_doc }|.
          <fs_doc>-documenttype       = zcl_proposal_bo_abs=>c_document_type-invoicesupplier.
          IF ls_doc-Documentkey(5) EQ 'DUMMY'.
            <fs_doc>-parentdocumentkey = ls_doc-documentkey+5(10).
          ELSE.
            <fs_doc>-parentdocumentkey  = ls_doc-documentkey.
          ENDIF.
          <fs_doc>-parentdocumenttype = zcl_proposal_bo_abs=>c_document_type-purchaseorder.
          UNASSIGN <fs_doc>.

          lv_orderitem += 10.
          lv_suppitem  += 1.

          READ TABLE lt_poitems INTO DATA(ls_poitems) WITH KEY purchaseorder = lv_doc.
          lv_taxcode = ls_poitems-taxcode.

          ls_items = VALUE #( purchaseorder             = lv_doc
                              purchaseorderitem         = lv_orderitem
                              supplierinvoiceitem       = lv_suppitem
                              taxcode                   = lv_taxcode
                              documentcurrency          = ls_items_rep-transactioncurrency
                              purchaseorderquantityunit = '%'
                              supplierinvoiceitemtext   = |Fact { gs_header_si-providercompanycode } { gs_header_si-product } { gs_header_si-fiscalperiod+1 } { gs_header_si-fiscalyear }| ).

          lv_netprice = ls_items_rep-amountintrasactioncurrency + ls_items_rep-markupamount + ls_items_rep-grossingupbaseamount + ls_items_rep-grossingupmarginamount.
          ls_items-supplierinvoiceitemamount   = lv_netprice.
          ls_items-quantityinpurchaseorderunit = 100.
          lv_amount                            = lv_amount + lv_netprice.

          APPEND ls_items TO lt_items.
          ls_invoice-%param-_itemswithporeference = lt_items.

          lv_providercompanycode  = ls_items_rep-providercompanycode.
          lv_product              = ls_items_rep-product.
          lv_recipientcompanycode = ls_items_rep-recipientcompanycode.
          lv_flow                 = ls_items_rep-flow.
        ENDLOOP.

        IF lt_items[] IS NOT INITIAL.

**********************************************************************
          "Determinación de impuesto de retención
          lt_wht_code = me->get_wht_codes_for_item(
                                iv_cid_invoice = ls_invoice-%cid
                                iv_supplier    = lv_supplier
                                iv_companycode = lv_companycode
                                iv_provider    = lv_providercompanycode
                                iv_recipient   = lv_recipientcompanycode
                                iv_product     = gs_header-product
                                iv_currency    = ls_items_rep-transactioncurrency
                                it_wht         = lt_wht ).

          IF lt_wht_code IS NOT INITIAL.
            ls_invoice-%param-_withholdingtaxes = lt_wht_code.
          ENDIF.
**********************************************************************
          ls_invoice-%param-invoicegrossamount = lv_amount.
          INSERT ls_invoice INTO TABLE gta_invoice_create.

          lv_parent = lv_doc.

          " llamo a la clase que ejecuta en paralelo.
          lo_proposal_paralel = NEW zcl_proposal_bo_suppinv_par(
            iv_process           = zcl_boproposal_tools=>gc_create_doc
            iv_parentdocumentkey = lv_parent
            it_doc_map           = gt_doc_map
            ita_invoice_create   = gta_invoice_create
          ).

          INSERT lo_proposal_paralel INTO TABLE gtd_list_bo.
          FREE: lt_items,
                gta_invoice_create,
                lt_wht_code,
                gt_doc_map,
                lv_amount.
        ENDIF.
        CHECK gtd_list_bo IS NOT INITIAL.
        exe_bo( ).
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


  METHOD constructor.

    super->constructor( is_header      = is_header
                        it_items       = it_items
                        it_bases       = it_bases
                        it_calc        = it_calc
                        it_doc         = it_doc
                        it_anul_doc    = it_anul_doc
                        its_doc        = its_doc
                        it_doc_map     = it_doc_map
                        iv_process     = iv_process
                        iv_documentkey = iv_documentkey ).
    gs_header_si          = is_header.
    gv_process_si         = iv_process.
    gtd_doc_si    = it_doc.
    gts_doc_si    = its_doc.
    gt_doc_map_po = it_doc_map.
    gv_process_si = iv_process.
*    gtd_items_add  = it_items_add.

  ENDMETHOD.


  METHOD mapping_bo.

  ENDMETHOD.


  METHOD preparedata.
    LOOP AT gt_doc_map_po INTO DATA(ls_doc_map_po) WHERE Documenttype = c_document_type-purchaseorder
                                                     AND       Status = 'E'.
      DELETE gtd_items_add WHERE item_id = ls_doc_map_po-item_id.
    ENDLOOP.

    DELETE gtd_items_add WHERE with_po         = abap_true  AND
                               with_invsupp    = abap_true.
    LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items>).
      DATA(ls_doc_si) = VALUE #( gtd_doc_si[ id           = <fs_items>-id
                                             item_id       = <fs_items>-item_id
                                             itembasis_id  = <fs_items>-itembasis_id
                                             itemcalc_id   = <fs_items>-itemcalc_id
                                             documenttype = zcl_proposal_bo_abs=>c_document_type-invoicesupplier ] OPTIONAL ).
      IF ls_doc_si IS INITIAL."Si no tiene factura a reprocesar se tiene que buscar la orden
        ls_doc_si = VALUE #( gtd_doc_si[ id           = <fs_items>-id
                                         item_id       = <fs_items>-item_id
                                         itembasis_id  = <fs_items>-itembasis_id
                                         itemcalc_id   = <fs_items>-itemcalc_id
                                         documenttype = zcl_proposal_bo_abs=>c_document_type-purchaseorder ] OPTIONAL ).
        IF ls_doc_si IS NOT INITIAL."Si encuentra orden de compra
          APPEND INITIAL LINE TO gt_doc_map_po ASSIGNING FIELD-SYMBOL(<fs_doc_map_po>).
          <fs_doc_map_po>-id          = <fs_items>-id.
          <fs_doc_map_po>-item_id      = <fs_items>-item_id.
          <fs_doc_map_po>-itembasis_id = <fs_items>-itembasis_id.
          <fs_doc_map_po>-itemcalc_id  = <fs_items>-itemcalc_id.
          <fs_doc_map_po>-documentkey = ls_doc_si-documentkey.
          <fs_doc_map_po>-documenttype  = ls_doc_si-documenttype.
        ENDIF.
      ELSEIF ls_doc_si-documentkey(5) = 'DUMMY'."Si existe una factura a reprocesar (creada pero no facturada) se tiene que validar que sea una factura DUMMY
        APPEND INITIAL LINE TO gt_doc_map_po ASSIGNING <fs_doc_map_po>.
        <fs_doc_map_po>-id          = <fs_items>-id.
        <fs_doc_map_po>-item_id      = <fs_items>-item_id.
        <fs_doc_map_po>-itembasis_id = <fs_items>-itembasis_id.
        <fs_doc_map_po>-itemcalc_id     = <fs_items>-itemcalc_id.
        <fs_doc_map_po>-documentkey    = ls_doc_si-documentkey.
        <fs_doc_map_po>-documenttype  = ls_doc_si-documenttype.

      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_wht_codes_for_item.

    DATA: ls_target TYPE LINE OF lty_items-%param-_withholdingtaxes.
    DATA: lt_filtered TYPE ty_t_wht.
    DATA: lt_wht_input TYPE tt_wht_aux.

    CLEAR rt_wht_code.

    LOOP AT it_wht INTO DATA(ls_wht)
      WHERE supplier = iv_supplier AND companycode = iv_companycode.
      APPEND ls_wht TO lt_filtered.
    ENDLOOP.

    IF lt_filtered IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_brf_helper) = NEW zcl_interco_brf_wht( ).
    LOOP AT lt_filtered INTO DATA(ls_filt).
      DATA(lv_tax_code) = lo_brf_helper->get_wht_code(
                            iv_provider  = iv_provider
                            iv_recipient = iv_recipient
                            iv_product   = iv_product
                            iv_whttype   = ls_filt-withholdingtaxtype ).

      IF lv_tax_code IS NOT INITIAL.

        DATA(ls_wht_input) = VALUE zcl_proposal_bo_supplierinv=>ty_wht_aux(
            primary_key         = iv_cid_invoice
            WithholdingTaxType  = ls_filt-withholdingtaxtype
            WithholdingTaxCode  = lv_tax_code
            DocumentCurrency    = iv_currency
        ).

        CLEAR ls_target.
        MOVE-CORRESPONDING ls_wht_input TO ls_target.

        " Truco para que RAP lo enlace al %cid:
        " Aquí se hace el CAST explícito
        DATA(lo_structdescr) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( ls_target ) ).
        DATA(lt_comp_tab) = lo_structdescr->components.
        READ TABLE lt_comp_tab INTO DATA(ls_comp) WITH KEY name = 'PRIMARY_KEY'.
        IF sy-subrc EQ 0.
          ASSIGN COMPONENT ls_comp-name OF STRUCTURE ls_target TO FIELD-SYMBOL(<fs_pk>).
          IF <fs_pk> IS ASSIGNED.
            <fs_pk> = ls_wht_input-primary_key.
          ENDIF.
        ENDIF.

        APPEND ls_target TO rt_wht_code.

*        APPEND VALUE #(
*
*          DocumentCurrency    = iv_currency
*          WithholdingTaxCode  = lv_tax_code
*          WithholdingTaxType  = ls_filt-withholdingtaxtype
*        ) TO rt_wht_code.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
