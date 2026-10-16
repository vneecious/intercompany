    CLASS zcl_boproposal_tools DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

      PUBLIC SECTION.

        INTERFACES if_serializable_object .
        INTERFACES if_abap_parallel .

        TYPES:
          gtty_proposal_upd TYPE TABLE FOR UPDATE zi_intercoproposal .
        TYPES:
          BEGIN OF gty_comprelprod.
        TYPES providercompanycode   TYPE zi_intercocompanyrelproduct-providercompanycode.
        TYPES recipientcompanycode  TYPE zi_intercocompanyrelproduct-recipientcompanycode.
        TYPES product               TYPE zi_intercocompanyrelproduct-product.
        TYPES profitcenter          TYPE zi_intercocompanyrelproduct-profitcenter.
        TYPES flow                  TYPE zi_intercocompanyrelproduct-flow.
        TYPES END OF gty_comprelprod .
        TYPES:
          BEGIN OF gty_intercorela.
        TYPES providercompanycode   TYPE zi_intercorelationship-providercompanycode.
        TYPES recipientcompanycode  TYPE zi_intercorelationship-recipientcompanycode.
        TYPES providercustomer      TYPE zi_intercorelationship-providercustomer.
        TYPES providervendor        TYPE zi_intercorelationship-providervendor.
        TYPES recipientcustomer     TYPE zi_intercorelationship-recipientcustomer.
        TYPES recipientvendor       TYPE zi_intercorelationship-recipientvendor.
        TYPES END OF gty_intercorela .
        TYPES:
          gtsty_comprelprod TYPE SORTED TABLE OF gty_comprelprod WITH NON-UNIQUE KEY primary_key COMPONENTS providercompanycode recipientcompanycode product profitcenter .
        TYPES:
          gtsty_intercorela TYPE SORTED TABLE OF gty_intercorela WITH UNIQUE KEY primary_key COMPONENTS providercompanycode recipientcompanycode .

        CONSTANTS gc_create_doc TYPE c VALUE 'C' ##NO_TEXT.
        CONSTANTS gc_reverse_doc TYPE c VALUE 'R' ##NO_TEXT.
        CONSTANTS gc_reprocess_doc TYPE c VALUE 'P' ##NO_TEXT.
        DATA gv_with_error TYPE c .
        CONSTANTS gc_simulate_doc TYPE c VALUE 'S' ##NO_TEXT.

        METHODS constructor
          IMPORTING
            !is_header    TYPE zi_intercoproposal OPTIONAL
            !it_items     TYPE zcl_proposal_bo_abs=>gtty_items OPTIONAL
            !it_bases     TYPE zcl_proposal_bo_abs=>gtty_bases OPTIONAL
            !it_baogl     TYPE zcl_proposal_bo_abs=>gtty_baogl OPTIONAL
            !it_baogl_mla TYPE zcl_proposal_bo_abs=>gtty_baogl OPTIONAL
            !it_calc      TYPE zcl_proposal_bo_abs=>gtty_calc OPTIONAL
            !it_doc       TYPE zcl_proposal_bo_abs=>gtty_doc OPTIONAL
            !iv_process   TYPE c OPTIONAL .
        METHODS preparedata
          RAISING
            zcx_calc_exit .
        METHODS createdocs
          RAISING
            zcx_calc_exit .
        METHODS reversedocs
          RAISING
            zcx_calc_exit .
        METHODS set_invoicinginprogress .
        METHODS set_invoicingerror .
        METHODS set_invoiced .
        METHODS set_annulationinprogress .
        METHODS set_annulationerror .
        METHODS set_annulated .
        METHODS set_calculated . "to reset Proposal Status
        METHODS set_startedreinvoinced . "to Reprocess
        METHODS prepareproposaltoupd
          IMPORTING
            !iv_proposal_status TYPE zint_dte_cph_status .
        METHODS set_simulated .
        METHODS set_simulated_error .
        METHODS delete_log_simulated .
        METHODS set_simulationinprogress .
      PROTECTED SECTION.
      PRIVATE SECTION.

        DATA gs_header TYPE zi_intercoproposal .
        DATA gtd_items_add TYPE ztt_proposalitem_add .
        DATA gtd_bases TYPE zcl_proposal_bo_abs=>gtty_bases .
        DATA gtd_baogl TYPE zcl_proposal_bo_abs=>gtty_baogl .
        DATA gtd_baogl_mla TYPE zcl_proposal_bo_abs=>gtty_baogl .
        DATA gtd_calc TYPE zcl_proposal_bo_abs=>gtty_calc .
        DATA gtd_doc TYPE zcl_proposal_bo_abs=>gtty_doc .
        DATA gts_bases TYPE zcl_proposal_bo_abs=>gtsty_bases .
        DATA gts_baogl TYPE zcl_proposal_bo_abs=>gtsty_baogl .
        DATA gts_baogl_mla TYPE zcl_proposal_bo_abs=>gtsty_baogl .
        DATA gts_calc TYPE zcl_proposal_bo_abs=>gtsty_calc .
        DATA gts_doc TYPE zcl_proposal_bo_abs=>gtsty_doc .
        DATA gtd_docs_gen TYPE zcl_proposal_bo_abs=>gtty_doc .
        DATA gtd_glaccounts TYPE ztt_proposal_reclassif .
        DATA gts_glaccounts TYPE zcl_proposal_bo_abs=>gtsty_glaccount .
        DATA gv_process TYPE c .
        DATA gts_comprelprod TYPE gtsty_comprelprod .
        DATA gts_intercorela TYPE gtsty_intercorela .
    ENDCLASS.



    CLASS zcl_boproposal_tools IMPLEMENTATION.


      METHOD constructor.
        DATA: lref_s_data TYPE REF TO data.

        FIELD-SYMBOLS <lt_data> TYPE ANY TABLE.
        TRY.
            IF is_header IS SUPPLIED.
              gs_header = is_header.
            ENDIF.

            IF it_items IS SUPPLIED.
              CREATE DATA lref_s_data LIKE it_items.
              ASSIGN lref_s_data->* TO <lt_data>.
              IF <lt_data> IS ASSIGNED.
                <lt_data> = it_items.
                MOVE-CORRESPONDING <lt_data> TO gtd_items_add.
              ENDIF.

              FREE: lref_s_data.
            ENDIF.

            IF it_bases IS SUPPLIED.
              UNASSIGN <lt_data>.
              CREATE DATA lref_s_data LIKE it_bases.
              ASSIGN lref_s_data->* TO <lt_data>.
              IF <lt_data> IS ASSIGNED.
                <lt_data> = it_bases.
                MOVE-CORRESPONDING <lt_data> TO gtd_bases.
                MOVE-CORRESPONDING <lt_data> TO gts_bases.
              ENDIF.

              FREE: lref_s_data.
            ENDIF.

            IF it_baogl IS SUPPLIED.
              UNASSIGN <lt_data>.
              CREATE DATA lref_s_data LIKE it_baogl.
              ASSIGN lref_s_data->* TO <lt_data>.
              IF <lt_data> IS ASSIGNED.
                <lt_data> = it_baogl.
                MOVE-CORRESPONDING <lt_data> TO gtd_baogl.
                MOVE-CORRESPONDING <lt_data> TO gts_baogl.
              ENDIF.

              FREE: lref_s_data.
            ENDIF.

            IF it_baogl_mla IS SUPPLIED.
              UNASSIGN <lt_data>.
              CREATE DATA lref_s_data LIKE it_baogl_mla.
              ASSIGN lref_s_data->* TO <lt_data>.
              IF <lt_data> IS ASSIGNED.
                <lt_data> = it_baogl_mla.
                MOVE-CORRESPONDING <lt_data> TO gtd_baogl_mla.
                MOVE-CORRESPONDING <lt_data> TO gts_baogl_mla.
              ENDIF.

              FREE: lref_s_data.
            ENDIF.

            IF it_calc IS SUPPLIED.
              UNASSIGN <lt_data>.
              CREATE DATA lref_s_data LIKE it_calc.
              ASSIGN lref_s_data->* TO <lt_data>.
              IF <lt_data> IS ASSIGNED.
                <lt_data> = it_calc.
                MOVE-CORRESPONDING <lt_data> TO gtd_calc.
                MOVE-CORRESPONDING <lt_data> TO gts_calc.
              ENDIF.

              FREE: lref_s_data.
            ENDIF.

            IF it_doc IS SUPPLIED.
              UNASSIGN <lt_data>.
              CREATE DATA lref_s_data LIKE it_doc.
              ASSIGN lref_s_data->* TO <lt_data>.
              IF <lt_data> IS ASSIGNED.
                <lt_data> = it_doc.
                MOVE-CORRESPONDING <lt_data> TO gtd_doc.
                MOVE-CORRESPONDING <lt_data> TO gts_doc.
              ENDIF.

              FREE: lref_s_data.
            ENDIF.

            IF iv_process IS SUPPLIED.
              gv_process = iv_process.
            ENDIF.

          CATCH cx_sy_create_data_error
                            cx_sy_assign_cast_illegal_cast
                            cx_sy_assign_cast_unknown_type
                            cx_sy_assign_out_of_range INTO DATA(lref_dynamic_cx).
            "Save log error
            "ID = gs_header-ID
            "MSG = lref_dynamic_cx->get_text( )
            "TYPE =  if_abap_behv_message=>severity-success
        ENDTRY.
      ENDMETHOD.


      METHOD preparedata.
        " Lines comments to use in  Behavior process~commit
        " Select type doc flow
        " TODO: variable is assigned but only used in commented-out code (ABAP cleaner)

*    DATA(ld_today) = cl_abap_context_info=>get_system_date( ).
        "Fecha para validación de vigencia de relaciones intercompañía, se toma el último día del mes de la propuesta para evitar problemas de validación por diferencias de fecha entre sistemas
        FINAL(ld_today) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

        IF lines( gtd_items_add ) <= 0.
          RETURN.
        ENDIF.

        """
        SORT gtd_items_add  BY id  item_id.
        DELETE ADJACENT DUPLICATES FROM gtd_items_add COMPARING id item_id.

        SORT gtd_items_add BY interdivisional
                              providercompanycode
                              product
                              recipientcompanycode
                              profitcenter.

*   "Get flow to validate after
        SELECT providercompanycode, recipientcompanycode, product, profitcenter, flow
          FROM zi_intercocompanyrelproduct
          FOR ALL ENTRIES IN @gtd_items_add
          WHERE providercompanycode   = @gtd_items_add-providercompanycode
            AND recipientcompanycode  = @gtd_items_add-recipientcompanycode
            AND product               = @gtd_items_add-product
            AND profitcenter          = @gtd_items_add-profitcenter
            AND isdeleted             = @space
            AND validfrom            <= @ld_today
            AND validto              >= @ld_today
          INTO TABLE @gts_comprelprod.
        IF sy-subrc <> 0.
          " Create log and throw exception
        ENDIF.

        DATA(lt_items_aux) = gtd_items_add[].
        SORT lt_items_aux BY providercompanycode
                             recipientcompanycode.
        DELETE ADJACENT DUPLICATES FROM lt_items_aux COMPARING providercompanycode recipientcompanycode.
*
*   "Get Customer info
        SELECT DISTINCT providercompanycode, recipientcompanycode, providercustomer, providervendor, recipientcustomer, recipientvendor
          FROM zi_intercorelationship
          FOR ALL ENTRIES IN @lt_items_aux
          WHERE providercompanycode  = @lt_items_aux-providercompanycode
            AND recipientcompanycode = @lt_items_aux-recipientcompanycode
          INTO TABLE @gts_intercorela.
        IF sy-subrc = 0.
*      SORT lt_intercoRela BY ProviderCompanyCode RecipientCompanyCode.
        ENDIF.

        SELECT _baogl~providercompanycode,
               _baogl~product,
               _baogl~plant,
               _baogl~valuationclass,
               _glacct~chartofaccounts,
               _glacct~transactiontypedetermination,
               _glacct~valuationareagroup,
               _glacct~glacctdetndifferentiation,
               _glacct~debitglaccount,
               _glacct~creditglaccount
        FROM zi_transactiontypestdglacct AS _glacct
        INNER JOIN @gts_baogl AS _baogl ON _glacct~chartofaccounts = _baogl~chartofaccounts
                                                  AND _glacct~transactiontypedetermination IN ( 'ZIN', 'ZRI', 'ZRE' )
                                                  AND _glacct~valuationareagroup IN ( 'BASE', 'MKUP', 'GUPK', 'GUPM', 'GUPB', 'GUPP', 'INTM', 'ZBAS', 'ZMUP', 'ZGUB', 'ZGUM', 'PR00' )
                                                  AND _glacct~valuationclass = _baogl~valuationclass
        INTO TABLE @gtd_glaccounts.
        IF sy-subrc = 0.
          gts_glaccounts = gtd_glaccounts.
          " Create log and throw exception
        ENDIF.


        " Complete data to validate flow
        LOOP AT gtd_items_add ASSIGNING FIELD-SYMBOL(<fs_items_add>).
          TRY.
              DATA(gs_doc) =  gts_doc[ id           = <fs_items_add>-id
                                       item_id       = <fs_items_add>-item_id
                                       itembasis_id  = <fs_items_add>-itembasis_id
                                       itemcalc_id   = <fs_items_add>-itemcalc_id
                                       documenttype = zcl_proposal_bo_abs=>c_document_type-interdiv
                                       status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_interdiv = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-salesorder
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_so = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-billingdocument
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_billdoc = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_bd_wthpost = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_so = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
*                             documenttype = zcl_proposal_bo_abs=>c_document_type-purchaseorder
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_po = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-invoicesupplier
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_invsupp = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_si_wthpost = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_grossingup_rec = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-incomereclassif
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_incomerec = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

          TRY.
              gs_doc = gts_doc[ id           = <fs_items_add>-id
                                 item_id      = <fs_items_add>-item_id
                                 itembasis_id = <fs_items_add>-itembasis_id
                                 itemcalc_id  = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-journalentry_ic
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_journalentry_ic = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
          " ext_vinbarri - tax br documents ->
          <fs_items_add>-with_ar_taxbr = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                         item_id       = <fs_items_add>-item_id
                                                                         itembasis_id  = <fs_items_add>-itembasis_id
                                                                         itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                         documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales
                                                                         status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ar_taxbrc = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                         item_id       = <fs_items_add>-item_id
                                                                         itembasis_id  = <fs_items_add>-itembasis_id
                                                                         itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                         documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_contingency
                                                                         status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ar_taxbr_rec = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                         item_id       = <fs_items_add>-item_id
                                                                         itembasis_id  = <fs_items_add>-itembasis_id
                                                                         itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                         documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_reclassif
                                                                         status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ar_taxbrc_rec = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                               item_id       = <fs_items_add>-item_id
                                                                               itembasis_id  = <fs_items_add>-itembasis_id
                                                                               itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                               documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_cont_reclassif
                                                                               status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ap_taxbr = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                         item_id       = <fs_items_add>-item_id
                                                                         itembasis_id  = <fs_items_add>-itembasis_id
                                                                         itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                         documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases
                                                                         status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ap_taxbrc = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                         item_id       = <fs_items_add>-item_id
                                                                         itembasis_id  = <fs_items_add>-itembasis_id
                                                                         itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                         documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_contingency
                                                                         status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ap_taxbr_rec = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                         item_id       = <fs_items_add>-item_id
                                                                         itembasis_id  = <fs_items_add>-itembasis_id
                                                                         itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                         documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_reclassif
                                                                         status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).

          <fs_items_add>-with_ap_taxbrc_rec = xsdbool( line_exists(  gts_doc[ id = <fs_items_add>-id
                                                                               item_id       = <fs_items_add>-item_id
                                                                               itembasis_id  = <fs_items_add>-itembasis_id
                                                                               itemcalc_id   = <fs_items_add>-itemcalc_id
                                                                               documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_cont_reclassif
                                                                               status       = zcl_proposal_bo_abs=>c_document_status-commit ] ) ).
          " ext_vinbarri - tax br documents <-
          TRY.
              gs_doc =  gts_doc[ id           = <fs_items_add>-id
                                 item_id       = <fs_items_add>-item_id
                                 itembasis_id  = <fs_items_add>-itembasis_id
                                 itemcalc_id   = <fs_items_add>-itemcalc_id
                                 documenttype = zcl_proposal_bo_abs=>c_document_type-expensreclassif
                                 status       = zcl_proposal_bo_abs=>c_document_status-commit ].
              <fs_items_add>-with_expensrec = abap_true.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
          IF <fs_items_add>-providercompanycode = <fs_items_add>-recipientcompanycode.
            <fs_items_add>-interdivisional = abap_true.
          ENDIF.
          TRY.
              " O - Outflow
              IF gts_comprelprod[ providercompanycode  = <fs_items_add>-providercompanycode
                                 recipientcompanycode = <fs_items_add>-recipientcompanycode
                                 product              = <fs_items_add>-product
                                 profitcenter         = <fs_items_add>-profitcenter
                               ]-flow = zcl_proposal_bo_abs=>gc_outflow.
                " Venta en PRoviderCompnany / Compra en ReceiverCompany
                <fs_items_add>-flow = zcl_proposal_bo_abs=>gc_outflow.
              ELSE. " I - InFlow
                " Venta en ReceiverCompany / Compra en PRoviderCompnany
                <fs_items_add>-flow = zcl_proposal_bo_abs=>gc_inflow.
              ENDIF.

            CATCH cx_sy_itab_line_not_found.
*          <fs_items_add>-flow = zcl_proposal_bo_abs=>gc_inflow."bY DEFAULT
*Ini EXT_OSCUGALD - sin configuración de flujo para el ítem — no existe registro activo en ZI_INTERCOCOMPANYRELPRODUCT
              " Combinación específica sin configuración de flujo — no procesar como inflow por defecto
              RAISE EXCEPTION TYPE zcx_calc_exit
                EXPORTING
                  textid          = zcx_calc_exit=>flow_config_not_found
                  mv_provider     = <fs_items_add>-providercompanycode
                  mv_recipient    = <fs_items_add>-recipientcompanycode
                  mv_product      = <fs_items_add>-product
                  mv_profitcenter = <fs_items_add>-profitcenter.
*Fin EXT_OSCUGALD
          ENDTRY.
          TRY.
              DATA(ls_reclassif) = gtd_glaccounts[ product         = <fs_items_add>-product
                                                   plant           = <fs_items_add>-providerplant
                                                   companycode     = <fs_items_add>-providercompanycode
                                                   chartofaccounts = <fs_items_add>-chartofaccounts ].

              <fs_items_add>-valuationclass = ls_reclassif-valuationclass.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
          TRY.
              DATA(ls_intercorela) = gts_intercorela[ providercompanycode    = <fs_items_add>-providercompanycode
                                                       recipientcompanycode = <fs_items_add>-recipientcompanycode ].
              <fs_items_add>-providercustomer   = ls_intercorela-providercustomer.
              <fs_items_add>-providervendor     = ls_intercorela-providervendor.
              <fs_items_add>-recipientcustomer  = ls_intercorela-recipientcustomer.
              <fs_items_add>-recipientvendor    = ls_intercorela-recipientvendor.
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.

        ENDLOOP.
      ENDMETHOD.


      METHOD createdocs.


        TYPES: BEGIN OF ty_document_type,
                 doctype   TYPE zint_dte_doctype,
                 order     TYPE i,
                 classname TYPE c LENGTH 40,
               END OF ty_document_type,
               tt_document_types TYPE TABLE OF ty_document_type WITH KEY doctype.

        DATA(lt_document_types) = VALUE tt_document_types(
          ( doctype = zcl_proposal_bo_abs=>c_document_type-interdiv order = 1 classname = 'ZCL_PROPOSAL_BO_INTERDIV' )
          ( doctype = zcl_proposal_bo_abs=>c_document_type-je_sales order = 2 classname = 'ZCL_PROPOSAL_BO_AR' )
          ( doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales order = 3 classname = 'ZCL_PROPOSAL_BO_AR_TAXBR' )
          ( doctype = zcl_proposal_bo_abs=>c_document_type-je_purchase order = 4 classname = 'ZCL_PROPOSAL_BO_AP' )
          ( doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases order = 5 classname = 'ZCL_PROPOSAL_BO_AP_TAXBR' )
       ).

*    IF sy-uname = 'EXT_VINBARRI'.
*      LOOP AT lt_document_types REFERENCE INTO DATA(lr_document_type).
*        DATA lo_document_processor TYPE REF TO zcl_proposal_bo_abs.
*        TRY.
*            CREATE OBJECT lo_document_processor TYPE (lr_document_type->classname)
*              EXPORTING
*                iv_doctype = lr_document_type->doctype
*                is_header = gs_header
*                it_items = gtd_items_add
*                it_bases = gtd_bases
*                it_calc = gtd_calc
*                it_glaccount = gtd_glaccounts
*                it_doc = gtd_doc
*                its_bases    = gts_bases
*                its_calc     = gts_calc
*                its_glaccount = gts_glaccounts
*                its_doc       = gts_doc
*                iv_process = gv_process.
*
*            lo_document_processor->process_bo_sec( IMPORTING et_doc_map = DATA(lt_docs_gen) ).
*            APPEND LINES OF lt_docs_gen TO gtd_doc.
*          CATCH zcx_calc_exit.
*            gv_with_error = abap_true.
*        ENDTRY.
*      ENDLOOP.
*    ENDIF.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Interdivision
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_interdiv) = NEW zcl_proposal_bo_interdiv(
                                        is_header    = gs_header
                                      it_items     = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                 WHERE ( interdivisional = abap_true
                                                                                 AND     with_interdiv   = abap_false
                                                                                 AND   baseamountprofitcenter <> 0 ) "Genova MLA
                                                                                 (                       lwa_item ) )
*                                    it_bases     = gtd_bases
*                                    it_calc      = gtd_calc
*                                    it_GLAccount = gtd_GLAccounts
                                        its_bases    = gts_bases
                                        its_calc     = gts_calc
                                        its_glaccount = gts_glaccounts
                                        its_doc       = gts_doc
                                        iv_process = gv_process
                                         ).
*    lo_interdiv->process_bo( ).
            lo_interdiv->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.


        """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Factura de Cliente (Venta)
        """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_jeitem_ar) = NEW zcl_proposal_bo_ar(
                                          is_header    = gs_header
                                        it_items     = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                   WHERE ( interdivisional = abap_false
                                                                                   AND     with_so         = abap_false
                                                                                   AND   baseamountprofitcenter <> 0 ) "Genova MLA
                                                                                   (                       lwa_item ) )
                                          it_bases     = gtd_bases
                                          it_calc      = gtd_calc
                                          it_glaccount = gtd_glaccounts
                                          it_doc       = gtd_doc
                                          its_doc      = gts_doc
                                          iv_process = gv_process
                                           ).

            lo_jeitem_ar->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.


          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

*Ini EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
*   WHT Ventas (190) y WHT Compras (200) NO aplican a Bermudas: el material
*   ICSRV38/Regalias no tiene retenciones configuradas para MIC/USA. El
*   guard verifica el producto via TVARVC (mismo patron que mapping_bo_sec)
*   y salta ambos bloques completos cuando es Bermudas.
        SELECT SINGLE low FROM zi_tvarvc
          WHERE name = 'ZINTERCO_MIC_PRODUCT' AND type = 'S' AND low = @gs_header-product
          INTO @DATA(lv_mic_prod_found_wht).

        IF lv_mic_prod_found_wht IS INITIAL.
*Fin EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
*    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    VENTAS
*    "Documentos fi para tratamiento posterior de retenciones
*    """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
          TRY.
              DATA(lo_fi_wt_post_so) = NEW zcl_proposal_bo_wt_post( is_header = gs_header
                                                                    it_items  = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                                            WHERE ( with_bd_wthpost = abap_false ) ( lwa_item ) )

                                                                    it_doc    = VALUE zcl_proposal_bo_abs=>gtty_doc( FOR lwa_doc IN gtd_doc
                                                                                                                     WHERE ( ( documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales
                                                                                                                     AND     status         = zcl_proposal_bo_abs=>c_document_status-commit
                                                                                                                     AND     isdeleted      = abap_false )
                                                                                                                     OR (    documenttype   = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                                     AND     status         = zcl_proposal_bo_abs=>c_document_status-error
                                                                                                                     AND     isdeleted      = abap_false ) ) (  lwa_doc ) )
               it_doc_map = gtd_docs_gen
               iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
               iv_process       = gv_process ).

              lo_fi_wt_post_so->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
              APPEND LINES OF gtd_docs_gen TO gtd_doc.
            CATCH zcx_calc_exit.
              gv_with_error = abap_true.
          ENDTRY.
*Ini EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
        ENDIF.
*Fin EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Provisión de Incobrables PI
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_baddebtprov) = NEW zcl_proposal_bo_pi(
                is_header    = gs_header
                it_items     = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                           WHERE ( interdivisional = abap_false
                                                           AND     with_incomerec  = abap_false
                                                           )
                                                           (                       lwa_item ) )
                its_bases     = gts_bases
                its_calc      = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process
                ).
            lo_baddebtprov->process_bo_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*   Asientos contables IC - Uruguay)
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    IF sy-uname = 'EXT_OSCUGALD'.
        TRY.
            DATA(lo_fi_journalentry_ic) = NEW zcl_proposal_bo_wt_post( is_header = gs_header
                                                                  it_items  = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                                          WHERE ( with_journalentry_ic = abap_false ) ( lwa_item ) )

                                                          it_doc    = VALUE zcl_proposal_bo_abs=>gtty_doc( FOR lwa_doc IN gtd_doc
                                                                                                           WHERE ( ( documenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post
                                                                                                           AND     status         = zcl_proposal_bo_abs=>c_document_status-commit
                                                                                                           AND     isdeleted      = abap_false )
                                                                                                           OR (    documenttype   = zcl_proposal_bo_abs=>c_document_type-journalentry_ic
                                                                                                           AND   ( status         = zcl_proposal_bo_abs=>c_document_status-error
                                                                                                           OR      status         = zcl_proposal_bo_abs=>c_document_status-commit )
                                                                                                           AND     isdeleted      = abap_false ) ) (  lwa_doc ) )
             it_doc_map = gtd_docs_gen
             iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-journalentry_ic
             iv_process       = gv_process ).

            lo_fi_journalentry_ic->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.
*    ENDIF.
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Accounts payable AP
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_jeitem_ap) = NEW zcl_proposal_bo_ap(
                                          is_header    = gs_header
                                          it_items     = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                     WHERE ( interdivisional = abap_false
                                                                                     AND     with_po         = abap_false
                                                                                     AND   baseamountprofitcenter <> 0 ) "Genova MLA
                                                                                     (                       lwa_item ) )
                                          it_bases      = gtd_bases
                                          it_calc       = gtd_calc
                                          it_glaccount  = gtd_glaccounts
                                          it_doc        = gtd_doc
                                          its_doc       = gts_doc
                                          it_baogl      = gtd_baogl
                                          its_baogl     = gts_baogl
                                          it_baogl_mla  = gtd_baogl_mla
                                          its_baogl_mla = gts_baogl_mla
                                          iv_process    = gv_process
                                           ).

            lo_jeitem_ap->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.
*Ini EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
        IF lv_mic_prod_found_wht IS INITIAL.
*Fin EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
          """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*       COMPRAS
*       Documentos fi para tratamiento posterior de retenciones
          """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
          TRY.
              DATA(lo_fi_wt_post_po) = NEW zcl_proposal_bo_wt_post( is_header = gs_header
                                                                    it_items  = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                                            WHERE ( with_si_wthpost = abap_false
                                                                                                              AND   baseamountprofitcenter <> 0 ) "Genova MLA)
                                                                                                              ( lwa_item ) )
                                                                    it_doc    = VALUE zcl_proposal_bo_abs=>gtty_doc( FOR lwa_doc IN gtd_doc
                                                                                                                     WHERE ( ( documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                                                                                                                     AND     status         = zcl_proposal_bo_abs=>c_document_status-commit
                                                                                                                     AND     isdeleted      = abap_false )
                                                                                                                     OR ( documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                     AND     status    = zcl_proposal_bo_abs=>c_document_status-error
                                                                                                                     AND     isdeleted = abap_false ) ) ( lwa_doc ) )
                                                                    it_doc_map = gtd_docs_gen
                                                                    iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                    iv_process       =  gv_process ).
              lo_fi_wt_post_po->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
              APPEND LINES OF gtd_docs_gen TO gtd_doc.
            CATCH zcx_calc_exit.
              gv_with_error = abap_true.
          ENDTRY.
*Ini EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
        ENDIF.
*Fin EXT_OSCUGALD 2026-08-25 - Bermudas MIC (SDFPSINIC-23362)
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
*    Reclasificación Grossing Up Prestatario
*    Solo se ejecuta si hubo retenciones flujo document_type = 200
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_fi_recl_gross) = NEW zcl_proposal_bo_wt_post( is_header = gs_header
                                                                  it_items  = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                                                                          WHERE ( with_grossingup_rec = abap_false ) ( lwa_item ) )
                                                                  it_doc    = VALUE zcl_proposal_bo_abs=>gtty_doc( FOR lwa_doc IN gtd_doc
                                                                                                                   WHERE ( ( documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post
                                                                                                                   AND     status         = zcl_proposal_bo_abs=>c_document_status-commit
                                                                                                                   AND     isdeleted      = abap_false )
                                                                                                                   OR ( documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif
                                                                                                                   AND     status    = zcl_proposal_bo_abs=>c_document_status-error
                                                                                                                   AND     isdeleted = abap_false ) ) ( lwa_doc ) )
                                                                  it_doc_map = gtd_docs_gen
                                                                  iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif
                                                                  iv_process       =  gv_process ).
            lo_fi_recl_gross->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Incoming Reclassification
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_incomingreclassif) = NEW zcl_proposal_bo_recl_comp(
                is_header    = gs_header
                it_items     = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                           WHERE ( interdivisional = abap_false
                                                           AND     with_incomerec  = abap_false
                                                           AND   baseamountprofitcenter <> 0 ) "Genova MLA)
                                                           (                       lwa_item ) )
*            it_bases     = gtd_bases
*            it_calc      = gtd_calc
*            it_GLAccount = gtd_GLAccounts
                its_bases     = gts_bases
                its_calc      = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process
                ).
            lo_incomingreclassif->process_bo_sec( ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Expenses Reclassification
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_expensesreclassif) = NEW zcl_proposal_bo_recl_gasto(
                is_header    = gs_header
                it_items     = VALUE ztt_proposalitem_add( FOR lwa_item IN gtd_items_add
                                                           WHERE ( interdivisional = abap_false
                                                           AND     with_expensrec  = abap_false
                                                           AND   baseamountprofitcenter <> 0 ) "Genova MLA)
                                                           (                       lwa_item ) )
*            it_bases     = gtd_bases
*            it_calc      = gtd_calc
*            it_GLAccount = gtd_GLAccounts
                its_bases     = gts_bases
                its_calc      = gts_calc
                its_baogl     = gts_baogl
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process ).
            lo_expensesreclassif->process_bo_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.


        "  ext_vinbarri - TAX BR ->

        TRY.
            DATA(lo_ar_taxbr) = NEW zcl_proposal_bo_ar_taxbr(
                iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales
                is_header = gs_header
                it_items = gtd_items_add
                it_bases = gtd_bases
                it_calc = gtd_calc
                it_glaccount = gtd_glaccounts
                it_doc = gtd_doc
                its_bases    = gts_bases
                its_calc     = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process ).

            lo_ar_taxbr->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ar_taxbrc) = NEW zcl_proposal_bo_ar_taxbrc(
                iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales
                is_header = gs_header
                it_items = gtd_items_add
                it_bases = gtd_bases
                it_calc = gtd_calc
                it_glaccount = gtd_glaccounts
                it_doc = gtd_doc
                its_bases    = gts_bases
                its_calc     = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process ).

            lo_ar_taxbrc->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ap_taxbr) = NEW zcl_proposal_bo_ap_taxbr(
                iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases
                is_header = gs_header
                it_items = gtd_items_add
                it_bases = gtd_bases
                it_calc = gtd_calc
                it_glaccount = gtd_glaccounts
                it_doc = gtd_doc
                its_bases    = gts_bases
                its_calc     = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process ).

            lo_ap_taxbr->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ar_taxbr_recl) = NEW zcl_proposal_bo_ar_taxbr_recl(
                iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_reclassif
                is_header = gs_header
                it_items = gtd_items_add
                it_bases = gtd_bases
                it_calc = gtd_calc
                it_glaccount = gtd_glaccounts
                it_doc = gtd_doc
                its_bases    = gts_bases
                its_calc     = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process ).

            lo_ar_taxbr_recl->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ap_taxbr_recl) = NEW zcl_proposal_bo_ap_taxbr_recl(
                iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_reclassif
                is_header = gs_header
                it_items = gtd_items_add
                it_bases = gtd_bases
                it_calc = gtd_calc
                it_glaccount = gtd_glaccounts
                it_doc = gtd_doc
                its_bases    = gts_bases
                its_calc     = gts_calc
                its_glaccount = gts_glaccounts
                its_doc       = gts_doc
                iv_process = gv_process ).

            lo_ap_taxbr_recl->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
            APPEND LINES OF gtd_docs_gen TO gtd_doc.
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

*    TRY.
*        DATA(lo_ar_taxbrc_recl) = NEW zcl_proposal_bo_ar_taxbrc_recl(
*            iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_reclassif
*            is_header = gs_header
*            it_items = gtd_items_add
*            it_bases = gtd_bases
*            it_calc = gtd_calc
*            it_glaccount = gtd_glaccounts
*            it_doc = gtd_doc
*            its_bases    = gts_bases
*            its_calc     = gts_calc
*            its_glaccount = gts_glaccounts
*            its_doc       = gts_doc
*            iv_process = gv_process ).
*
*        lo_ar_taxbrc_recl->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
*        APPEND LINES OF gtd_docs_gen TO gtd_doc.
*      CATCH zcx_calc_exit.
*        gv_with_error = abap_true.
*    ENDTRY.
*
*    TRY.
*        DATA(lo_ap_taxbrc_recl) = NEW zcl_proposal_bo_ap_taxbrc_recl(
*            iv_doctype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_reclassif
*            is_header = gs_header
*            it_items = gtd_items_add
*            it_bases = gtd_bases
*            it_calc = gtd_calc
*            it_glaccount = gtd_glaccounts
*            it_doc = gtd_doc
*            its_bases    = gts_bases
*            its_calc     = gts_calc
*            its_glaccount = gts_glaccounts
*            its_doc       = gts_doc
*            iv_process = gv_process ).
*
*        lo_ap_taxbrc_recl->process_bo_sec( IMPORTING et_doc_map = gtd_docs_gen ).
*        APPEND LINES OF gtd_docs_gen TO gtd_doc.
*      CATCH zcx_calc_exit.
*        gv_with_error = abap_true.
*    ENDTRY.
        "  ext_vinbarri - TAX BR <-

        IF gv_with_error = abap_true.
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
      ENDMETHOD.


      METHOD reversedocs.
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        "Interdivision
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_interdiv) = NEW zcl_proposal_bo_interdiv(
              is_header   = gs_header
              it_doc      = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-interdiv )
                                     (                                           lwa_doc ) )
              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-anul_interdiv )
                                     (                                           lwa_doc ) )
              its_doc     = gts_doc
              iv_process  = gv_process
            ).
            lo_interdiv->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        "Bad debt provisions
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_baddebtprov) = NEW zcl_proposal_bo_pi(
              is_header   = gs_header
              it_doc      = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-debtprovision )
                                     (                                           lwa_doc ) )
              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-anul_debtprovision )
                                     (                                           lwa_doc ) )
              its_doc     = gts_doc
              iv_process  = gv_process
            ).
            lo_baddebtprov->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        "Incoming Reclassification
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_incomingreclassif) = NEW zcl_proposal_bo_recl_comp(
              is_header   = gs_header
              it_doc      = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-incomereclassif )
                                     (                                           lwa_doc ) )
              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-anul_incomerec )
                                     (                                           lwa_doc ) )
              its_doc     = gts_doc
              iv_process  = gv_process
            ).
            lo_incomingreclassif->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        "Expenses Reclassification
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_expensesreclassif) = NEW zcl_proposal_bo_recl_gasto(
              is_header   = gs_header
              it_items    = gtd_items_add
              it_doc      = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-expensreclassif )
                                     (                                           lwa_doc ) )
              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-anul_expensrec )
                                     (                                           lwa_doc ) )
              its_doc     = gts_doc
              iv_process  = gv_process
            ).
            lo_expensesreclassif->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Anulación doc FI Cuentas por Receber
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_jeitem_ar) = NEW zcl_proposal_bo_ar(
              is_header   = gs_header
              it_doc      = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-je_sales )
                                     (                                           lwa_doc ) )
              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-anul_je_sales )
                                     (                                           lwa_doc ) )
              its_doc     = gts_doc
              iv_process  = gv_process
            ).
            lo_jeitem_ar->process_reverse_sec( IMPORTING et_doc_map = gtd_docs_gen ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        " Anulación doc FI Cuentas por Pagar
        """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
        TRY.
            DATA(lo_jeitem_ap) = NEW zcl_proposal_bo_ap(
              is_header   = gs_header
              it_doc      = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase )
                                     (                                           lwa_doc ) )
              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-anul_je_purch )
                                     (                                           lwa_doc ) )
              its_doc     = gts_doc
              iv_process  = gv_process
            ).
            lo_jeitem_ap->process_reverse_sec( IMPORTING et_doc_map = gtd_docs_gen ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        "Anulación Documento Retenciones COMPRAS
        TRY.
            DATA(lo_fi_wt_post_po) = NEW zcl_proposal_bo_wt_post( is_header        = gs_header
                                                                  it_doc           = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-si_withholding_post OR
                                                                                                                             documenttype = zcl_proposal_bo_abs=>c_document_type-anul_si_withholding ) ( lwa_doc ) )
                                                                  iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-anul_si_withholding ).
            lo_fi_wt_post_po->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        "Anulación Reclasificación Grossing Up Prestataria
        TRY.
            DATA(lo_fi_recl_gross) = NEW zcl_proposal_bo_wt_post( is_header        = gs_header
                                                                  it_doc           = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-grossingupreclassif OR
                                                                                                                             documenttype = zcl_proposal_bo_abs=>c_document_type-anul_grossingup_reclassif ) ( lwa_doc ) )
                                                                  iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-anul_grossingup_reclassif ).
            lo_fi_recl_gross->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        "Anulación Asientos contables IC - Uruguay
        TRY.
            DATA(lo_fi_wt_journarentry_uy) = NEW zcl_proposal_bo_wt_post( is_header        = gs_header
                                                                  it_doc           = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-journalentry_ic OR
                                                                                                                             documenttype = zcl_proposal_bo_abs=>c_document_type-anul_journalentry_ic ) ( lwa_doc ) )
                                                                  iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-anul_journalentry_ic ).
            lo_fi_wt_journarentry_uy->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        "Anulación Documento Retenciones VENTAS
        TRY.
            DATA(lo_fi_wt_post_so) = NEW zcl_proposal_bo_wt_post( is_header        = gs_header
                                                                  it_doc           = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-bd_withholding_post OR
                                                                                                                             documenttype = zcl_proposal_bo_abs=>c_document_type-anul_bd_withholding ) ( lwa_doc ) )
                                                                  iv_proposal_type = zcl_proposal_bo_abs=>c_document_type-anul_bd_withholding ).
            lo_fi_wt_post_so->process_reverse_sec( ).
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.


        "  ext_vinbarri - TAX BR ->

        TRY.
            DATA(lo_ar_taxbr) = NEW zcl_proposal_bo_ar_taxbr(
                                  is_header  = gs_header
                                  it_doc = VALUE #( FOR lwa_doc IN gtd_doc
                                                      WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales ) ( lwa_doc ) )
                                  it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_sales )
                                                                   ( lwa_doc ) )
                               ).
            lo_ar_taxbr->process_reverse_sec( )..
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ap_taxbr) = NEW zcl_proposal_bo_ap_taxbr(
                                is_header  = gs_header
                                it_doc = VALUE #( FOR lwa_doc IN gtd_doc
                                                    WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases ) ( lwa_doc ) )
                                it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_purchases )
                                                                                                 ( lwa_doc ) )
                             ).
            lo_ap_taxbr->process_reverse_sec( )..
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ar_taxbrc) = NEW zcl_proposal_bo_ar_taxbrc(
                                  is_header  = gs_header
                                  it_doc = VALUE #( FOR lwa_doc IN gtd_doc
                                                      WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_contingency ) ( lwa_doc ) )
                                  it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_sales_cont )
                                                                   ( lwa_doc ) )
                               ).
            lo_ar_taxbrc->process_reverse_sec( )..
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ap_taxbrc) = NEW zcl_proposal_bo_ap_taxbrc(
                                is_header  = gs_header
                                it_doc = VALUE #( FOR lwa_doc IN gtd_doc
                                                    WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_contingency ) ( lwa_doc ) )
                                it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_purchases_cont )
                                                                                                 ( lwa_doc ) )
                             ).
            lo_ap_taxbrc->process_reverse_sec( )..
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ar_taxbr_recl) = NEW zcl_proposal_bo_ar_taxbr_recl(
                                is_header  = gs_header
                                it_doc = VALUE #( FOR lwa_doc IN gtd_doc
                                                    WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_reclassif ) ( lwa_doc ) )
                                it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_sales_reclassif )
                                                                                                 ( lwa_doc ) )
                             ).
            lo_ar_taxbr_recl->process_reverse_sec( )..
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

        TRY.
            DATA(lo_ap_taxbr_recl) = NEW zcl_proposal_bo_ap_taxbr_recl(
                                is_header  = gs_header
                                it_doc = VALUE #( FOR lwa_doc IN gtd_doc
                                                    WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_reclassif ) ( lwa_doc ) )
                                it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_purchases_reclas )
                                                                                                 ( lwa_doc ) )
                             ).
            lo_ap_taxbr_recl->process_reverse_sec( )..
          CATCH zcx_calc_exit.
            gv_with_error = abap_true.
        ENDTRY.

*      TRY.
*          DATA(lo_ar_taxbrc_recl) = NEW zcl_proposal_bo_ar_taxbrc_recl(
*                              is_header  = gs_header
*                              it_doc = VALUE #( FOR lwa_doc IN gtd_doc
*                                                  WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_sales_cont_reclassif ) ( lwa_doc ) )
*                              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_sales_cont_recla )
*                                                                                               ( lwa_doc ) )
*                           ).
*          lo_ar_taxbrc_recl->process_reverse_sec( )..
*        CATCH zcx_calc_exit.
*          gv_with_error = abap_true.
*      ENDTRY.
*
*      TRY.
*          DATA(lo_ap_taxbrc_recl) = NEW zcl_proposal_bo_ap_taxbrc_recl(
*                              is_header  = gs_header
*                              it_doc = VALUE #( FOR lwa_doc IN gtd_doc
*                                                  WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-taxbr_purchases_cont_reclassif ) ( lwa_doc ) )
*                              it_anul_doc = VALUE #( FOR lwa_doc IN gtd_doc WHERE ( documenttype = zcl_proposal_bo_abs=>c_document_type-reverse_taxbr_purchases_cont_r )
*                                                                                               ( lwa_doc ) )
*                           ).
*          lo_ap_taxbrc_recl->process_reverse_sec( )..
*        CATCH zcx_calc_exit.
*          gv_with_error = abap_true.
*      ENDTRY.

        "  ext_vinbarri - TAX BR <-


        IF gv_with_error = abap_true.
          RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.

      ENDMETHOD.


      METHOD if_abap_parallel~do.

        CASE gv_process.
          WHEN gc_create_doc.
            TRY.
                me->set_invoicinginprogress( ).
                me->delete_log_simulated( ).
                me->preparedata( ).
                me->createdocs( ).
                me->set_invoiced( ).
              CATCH zcx_calc_exit .
                me->set_invoicingerror( ).
            ENDTRY.
          WHEN gc_reverse_doc.
            TRY.
                me->set_annulationinprogress( ).
*Ini EXT_OSCUGALD 25.03.2026 - Anulación sin documentos: skip reversedocs si no hay docs
                IF gtd_doc IS NOT INITIAL.
                  me->reversedocs( ).
                ENDIF.
*Fin EXT_OSCUGALD 25.03.2026
                me->set_annulated( ).
              CATCH zcx_calc_exit .
                me->set_annulationerror( ).
            ENDTRY.
          WHEN gc_simulate_doc.
            TRY.
*            me->set_invoicinginprogress( ).
                me->set_simulationinprogress( ).
                me->delete_log_simulated( ).
                me->preparedata( ).
                me->createdocs( ).
                me->set_simulated( ).
*          CATCH zcx_calc_exit .
*            me->set_simulated_error( ).
*Ini EXT_OSCUGALD 13.04.2026 - Solo escribir log si es error 031 (flow config no encontrado)
              CATCH zcx_calc_exit INTO DATA(lx_error).
                " Solo escribir log si es error 031 (flow config no encontrado).
                " Para otros zcx_calc_exit que vienen de CREATEDOCS, los BO AR/AP/INTERDIV
                " ya escriben su propio CPDL — no tocar ese flujo existente.
                IF lx_error->if_t100_message~t100key = zcx_calc_exit=>flow_config_not_found
                  AND gtd_items_add IS NOT INITIAL.
                  DATA(lv_byuser_err) = cl_abap_context_info=>get_user_technical_name( ).
                  GET TIME STAMP FIELD DATA(lv_tstmpl_err).
                  DATA(ls_cpid_err) = VALUE zfi_a_intrc_cpid(
                    id           = gs_header-id
                    item_id      = gtd_items_add[ 1 ]-item_id
                    itembasis_id = gtd_items_add[ 1 ]-itembasis_id
                    itemcalc_id  = gtd_items_add[ 1 ]-itemcalc_id
                    documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                    documentkey  = ''
                    companycode  = gtd_items_add[ 1 ]-recipientcompanycode
                    fiscalyear   = gs_header-fiscalyear
                    cat_id       = zcl_proposal_bo_abs=>c_document_category-financial
                    status       = zcl_proposal_bo_abs=>c_document_status-error
                    createdby    = lv_byuser_err
                    createdat    = lv_tstmpl_err ).
                  MODIFY zfi_a_intrc_cpid FROM @ls_cpid_err.
                  DATA(ls_cpdl_err) = VALUE zfi_a_intrc_cpdl(
                    id           = gs_header-id
                    documenttype = zcl_proposal_bo_abs=>c_document_type-je_purchase
                    documentkey  = ''
                    companycode  = gtd_items_add[ 1 ]-recipientcompanycode
                    fiscalyear   = gs_header-fiscalyear
                    tstmpl       = lv_tstmpl_err
                    spras        = sy-langu
                    msgid        = lx_error->if_t100_message~t100key-msgid
                    msgno        = lx_error->if_t100_message~t100key-msgno
                    msgty        = 'E'
                    msgv1        = lx_error->mv_provider
                    msgv2        = lx_error->mv_recipient
                    msgv3        = lx_error->mv_product
                    msgv4        = lx_error->mv_profitcenter
                    message      = lx_error->get_text( ) ).
                  MODIFY zfi_a_intrc_cpdl FROM @ls_cpdl_err.
                ENDIF.
                me->set_simulated_error( ).
            ENDTRY.
*Fin
        ENDCASE.
        "Reset status only for test o reprocesing
*    me->set_calculated( ).
      ENDMETHOD.


      METHOD set_annulated.

        prepareproposaltoupd( 'A' ).
      ENDMETHOD.


      METHOD set_annulationerror.

        prepareproposaltoupd( 'F' ).
      ENDMETHOD.


      METHOD set_annulationinprogress.

        prepareproposaltoupd( 'D' ).
      ENDMETHOD.


      METHOD set_invoiced.

        prepareproposaltoupd( 'I' ).
      ENDMETHOD.


      METHOD set_invoicingerror.

        prepareproposaltoupd( 'E' ).
      ENDMETHOD.


      METHOD set_invoicinginprogress.

        prepareproposaltoupd( 'P' ).
      ENDMETHOD.

      METHOD set_simulationinprogress.

        prepareproposaltoupd( 'L' ).
      ENDMETHOD.

      METHOD set_calculated.

        prepareproposaltoupd( 'C' ).
      ENDMETHOD.


      METHOD set_startedreinvoinced.

        prepareproposaltoupd( 'T' ).
      ENDMETHOD.


      METHOD prepareproposaltoupd.

        READ ENTITIES OF zi_intercoproposal
             ENTITY zi_intercoproposal ALL FIELDS WITH VALUE #( ( %key-id = gs_header-id ) ) RESULT DATA(lt_proposal)
             FAILED DATA(header_fail).

        DATA(lt_proposal_upd) = CORRESPONDING gtty_proposal_upd( lt_proposal[] ).
        LOOP AT lt_proposal_upd ASSIGNING FIELD-SYMBOL(<fs_proposal>).
          <fs_proposal>-status = iv_proposal_status.
          <fs_proposal>-%control-status = '01'.
        ENDLOOP.

        MODIFY ENTITIES OF zi_intercoproposal
               ENTITY zi_intercoproposal UPDATE FROM lt_proposal_upd
               REPORTED DATA(lt_reported)
               FAILED DATA(lt_failed).

        COMMIT ENTITIES.

      ENDMETHOD.


      METHOD set_simulated.

        prepareproposaltoupd( 'J' ).

      ENDMETHOD.


      METHOD set_simulated_error.

        prepareproposaltoupd( 'H' ).

      ENDMETHOD.


      METHOD delete_log_simulated.

        IF gs_header-id IS INITIAL.
          RETURN.
        ENDIF.

        SELECT COUNT( * )
        FROM zfi_a_intrc_cpid
        WHERE ( status = @zcl_proposal_bo_abs=>c_document_status-simulated_error OR
                status = @zcl_proposal_bo_abs=>c_document_status-simulated_ok )  AND
                id = @gs_header-id.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.

        DELETE FROM zfi_a_intrc_cpid
          WHERE id = @gs_header-id AND
                status IN ( @zcl_proposal_bo_abs=>c_document_status-simulated_error,
                            @zcl_proposal_bo_abs=>c_document_status-simulated_ok ).

        DELETE FROM zfi_a_intrc_cpd
          WHERE id = @gs_header-id AND
                status IN ( @zcl_proposal_bo_abs=>c_document_status-simulated_error,
                            @zcl_proposal_bo_abs=>c_document_status-simulated_ok ).

        DELETE FROM zfi_a_intrc_cpdl
               WHERE id = @gs_header-id.

      ENDMETHOD.
    ENDCLASS.
