"! <p><strong>Propósito:</strong></p>
"! Este documento tiene como objetivo registrar las líneas de impuestos
"! cuando se realiza una transacción intercompany entre compañías de Brasil
"! (Provider BR → Recipient BR).
"!
"! <p><strong>Contexto Meli:</strong></p>
"! En Meli, los impuestos relacionados con operaciones intercompany
"! (PIS, COFINS, etc.) se contabilizan en documentos separados,
"! y no en el propio documento de ventas generado por la clase
"! ZCL_PROPOSAL_BO_AR.
CLASS zcl_proposal_bo_ar_taxbr DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_abs
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_origin_documents,
             companycode                  TYPE i_journalentry-companycode,
             accountingdocument           TYPE i_journalentry-accountingdocument,
             fiscalyear                   TYPE i_journalentry-fiscalyear,
             accountingdocumenttype       TYPE i_journalentry-accountingdocumenttype,
             accountingdocumentheadertext TYPE i_journalentry-accountingdocumentheadertext,
             documentreferenceid          TYPE i_journalentry-documentreferenceid,
             documentdate                 TYPE i_journalentry-documentdate,
             postingdate                  TYPE i_journalentry-postingdate,
             glaccount                    TYPE i_journalentryitem-glaccount,
             accountingdocumentitem       TYPE i_journalentryitem-accountingdocumentitem,
             assignmentreference          TYPE i_journalentryitem-assignmentreference,
             documentitemtext             TYPE i_journalentryitem-documentitemtext,
             costcenter                   TYPE i_journalentryitem-costcenter,
             product                      TYPE i_journalentryitem-product,
             quantity                     TYPE i_journalentryitem-quantity,
             baseunit                     TYPE i_journalentryitem-baseunit,
             amountintransactioncurrency  TYPE i_journalentryitem-amountintransactioncurrency,
             transactioncurrency          TYPE i_journalentryitem-transactioncurrency,
             partnercompany               TYPE i_journalentryitem-partnercompany,
             absoluteexchangerate         TYPE i_journalentry-absoluteexchangerate,
             department                   TYPE zi_intercoproposalitemdetail-department,
           END OF ty_origin_documents.

  PROTECTED SECTION.
    DATA: mv_contingency TYPE abap_boolean.
    DATA: mt_origin_documents TYPE TABLE OF ty_origin_documents.

    METHODS:
      preparedata REDEFINITION,
      preparedata_reverse REDEFINITION,
      mapping_bo_sec REDEFINITION.
  PRIVATE SECTION.
    TYPES tt_journal_entry TYPE TABLE FOR ACTION IMPORT i_journalentrytp~post.

    METHODS post_journalentry
      IMPORTING
        iv_parent_documentkey TYPE i_journalentry-accountingdocument
        it_journal_entry      TYPE tt_journal_entry.
ENDCLASS.



CLASS zcl_proposal_bo_ar_taxbr IMPLEMENTATION.


  METHOD preparedata.
    " Prepara los datos necesarios para la generación de este tipo de asiento contable.
    " Como el documento se basa en el AR, debemos asegurarnos de que haya sido generado
    " correctamente antes de continuar con este proceso.
    "
    " También se filtran únicamente los ítems relevantes de la propuesta,
    " es decir, aquellos correspondientes a operaciones BR → BR.

    mv_posting_doctype = c_document_type-taxbr_sales.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales.
    mv_parent_doctype = c_document_type-je_sales.
    mv_contingency = abap_false.

    " Mantiene únicamente los ítems relevantes de la propuesta (BR → BR).
    DELETE gtd_items_add WHERE NOT (
            with_ar_taxbr IS INITIAL
        AND interdivisional IS INITIAL
        AND recipientcountry = 'BR'
        AND providercountry = 'BR'
    ).

    " Mantiene únicamente los documentos padres.
    DELETE gtd_doc WHERE documenttype <> mv_parent_doctype
                 OR status <> zcl_proposal_bo_abs=>c_document_status-commit.

    " Por las dudas...
    LOOP AT gtd_doc REFERENCE INTO DATA(lr_doc).
      IF NOT line_exists( gtd_items_add[ id = lr_doc->id item_id = lr_doc->item_id itembasis_id = lr_doc->itembasis_id itemcalc_id = lr_doc->itemcalc_id ] ).
        DELETE gtd_doc INDEX sy-tabix.
      ENDIF.
    ENDLOOP.



    " Buscamos todos los datos relevantes de los documentos padres.

    TYPES: BEGIN OF ty_dockeys,
             companycode TYPE bukrs,
             fiscalyear  TYPE gjahr,
             documentkey TYPE belnr_d,
           END OF ty_dockeys,
           tt_dockeys TYPE TABLE OF ty_dockeys.


    DATA(lt_dockeys) = CORRESPONDING tt_dockeys( gtd_doc DISCARDING DUPLICATES ).

    IF lt_dockeys IS INITIAL.
      RETURN.
    ENDIF.

    "***Begin of Change - EXT_EDUARGAS - 23/06/2026 - COA Migration: TVARVC parameterization of GL account
    CONSTANTS lc_taxbr_gl TYPE c LENGTH 30 VALUE 'ZCL_PROPOSAL_BO_AR_TAXBR_GL'.
    SELECT SINGLE low
      FROM zi_tvarvc
      WHERE name = @lc_taxbr_gl
        AND type = 'P'
      INTO @DATA(lv_taxbr_gl).
    "***End of Change - EXT_EDUARGAS - 23/06/2026

    SELECT companycode, accountingdocument, fiscalyear,
    accountingdocumentheadertext, documentreferenceid, documentdate, postingdate, absoluteexchangerate
    FROM i_journalentry
    FOR ALL ENTRIES IN @lt_dockeys
    WHERE companycode = @lt_dockeys-companycode
    AND accountingdocument = @lt_dockeys-documentkey
    AND fiscalyear = @lt_dockeys-fiscalyear
    INTO TABLE @DATA(lt_journalentry).

    IF lt_journalentry IS  INITIAL.
      RETURN.
    ENDIF.

    SELECT companycode, accountingdocument, fiscalyear,
      glaccount,
      accountingdocumentitem,
      assignmentreference,
      documentitemtext,
      costcenter,
      product,
      quantity,
      baseunit,
      amountintransactioncurrency,
      transactioncurrency,
      partnercompany
    FROM i_journalentryitem
    FOR ALL ENTRIES IN @lt_journalentry
    WHERE sourceledger = '0L'
      AND fiscalyear = @lt_journalentry-fiscalyear
      AND accountingdocument = @lt_journalentry-accountingdocument
      AND companycode = @lt_journalentry-companycode
      AND sourceledger = '0L'
    "***Begin of Change - EXT_EDUARGAS - 23/06/2026 - COA Migration: TVARVC parameterization of GL account
      AND financialaccounttype = 'S' AND glaccount <> @lv_taxbr_gl
*    AND financialaccounttype = 'S' AND glaccount <> '0000780010'
    "***End of Change - EXT_EDUARGAS - 23/06/2026
      AND accountingdocumentitem > 0
    INTO TABLE @DATA(lt_journalentryitem).         "#EC CI_NO_TRANSFORM

    SELECT
        je~companycode,
        je~accountingdocument,
        je~fiscalyear,
        'CH' AS accountingdocumenttype,
        je~accountingdocumentheadertext,
        je~documentreferenceid,
        je~documentdate,
        je~postingdate,
        jeitem~glaccount,
        jeitem~accountingdocumentitem,
        jeitem~assignmentreference,
        jeitem~documentitemtext,
        jeitem~costcenter,
        jeitem~product,
        jeitem~quantity,
        jeitem~baseunit,
        jeitem~amountintransactioncurrency,
        jeitem~transactioncurrency,
        jeitem~partnercompany,
        je~absoluteexchangerate
      FROM @lt_journalentry AS je
        INNER JOIN @lt_journalentryitem AS jeitem ON je~companycode = jeitem~companycode
        AND  je~fiscalyear = jeitem~fiscalyear
        AND je~accountingdocument = jeitem~accountingdocument
      INTO TABLE @mt_origin_documents.

  ENDMETHOD.


  METHOD preparedata_reverse.
    gv_process = 'R'.
    mv_posting_doctype = c_document_type-taxbr_sales.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales.
    mv_parent_doctype = c_document_type-je_sales.
  ENDMETHOD.


  METHOD mapping_bo_sec.
    " Mapeo de I_JournalENtryTP~Post

    DATA lt_journal_entry TYPE tt_journal_entry.

    IF gv_process = 'S' OR mt_origin_documents IS INITIAL.
      RETURN.
    ENDIF.
    DATA(brf_helper) = NEW zcl_interco_brf_wht( ).
    LOOP AT mt_origin_documents REFERENCE INTO DATA(lr_origin_document)
      GROUP BY lr_origin_document->accountingdocument INTO FINAL(lv_document_key).

      lr_origin_document = REF #( mt_origin_documents[ accountingdocument = lv_document_key ] ).
      DATA(lt_docs) = gtd_doc.
      DELETE lt_docs WHERE documentkey <> lv_document_key.

      APPEND INITIAL LINE TO lt_journal_entry REFERENCE INTO DATA(lr_journal_entry).
      lr_journal_entry->%cid = lr_origin_document->accountingdocument && gs_header-product && sy-datum && sy-index.
      lr_journal_entry->%param-accountingdocumenttype = lr_origin_document->accountingdocumenttype.
      lr_journal_entry->%param-createdbyuser = sy-uname.
      lr_journal_entry->%param-accountingdocumentheadertext = lr_origin_document->accountingdocumentheadertext.
      lr_journal_entry->%param-companycode = lr_origin_document->companycode.
      lr_journal_entry->%param-documentreferenceid = lr_origin_document->documentreferenceid.
      lr_journal_entry->%param-documentdate = lr_origin_document->documentdate.
      lr_journal_entry->%param-postingdate = lr_origin_document->postingdate.

      " Mapea una estructura temporal gl_item con los mismos datos del documento de origen.
      LOOP AT GROUP lv_document_key REFERENCE INTO FINAL(lr_origin_item).


        DATA(lr_proposal_document) = REF #( gtd_doc[ companycode = lr_origin_item->companycode fiscalyear = lr_origin_item->fiscalyear documentkey = lr_origin_item->accountingdocument ] ).
        DATA(lr_proposal_item) = REF #( gtd_items_add[ id = lr_proposal_document->id item_id = lr_proposal_document->item_id ] ).

        DATA lt_origin_glitems LIKE lr_journal_entry->%param-_glitems.

        APPEND INITIAL LINE TO lt_origin_glitems REFERENCE INTO DATA(lr_origin_glitem).
        lr_origin_glitem->glaccountlineitem = lr_origin_item->accountingdocumentitem.
        lr_origin_glitem->glaccount = lr_origin_item->glaccount.
        lr_origin_glitem->glaccountlineitem = lr_origin_item->accountingdocumentitem.
        lr_origin_glitem->assignmentreference = lr_origin_item->assignmentreference.
        lr_origin_glitem->documentitemtext = lr_origin_item->documentitemtext.
        lr_origin_glitem->costcenter = lr_origin_item->costcenter.
        lr_origin_glitem->material = lr_origin_item->product.
        lr_origin_glitem->quantity = lr_origin_item->quantity.
        lr_origin_glitem->baseunit = lr_origin_item->baseunit.
        lr_origin_glitem->partnercompany = lr_origin_item->partnercompany.

        APPEND INITIAL LINE TO lr_origin_glitem->_currencyamount REFERENCE INTO DATA(gl_item_amount).
        gl_item_amount->currencyrole = '00'.
        gl_item_amount->currency = lr_origin_item->transactioncurrency.
        gl_item_amount->journalentryitemamount = lr_origin_item->amountintransactioncurrency * -1.
        gl_item_amount->exchangerate  = lr_origin_item->absoluteexchangerate.
      ENDLOOP.

      TRY.
          DATA(taxbr) = NEW zcl_interco_taxbr(
            i_doctype              = zcl_interco_taxbr=>co_doctype-sales
            i_providercompanycode  = lr_proposal_item->providercompanycode
            i_recipientcompanycode = lr_proposal_item->recipientcompanycode
            i_product              = lr_proposal_item->product
            i_department           = lr_origin_item->department
            i_valid_at             = lr_origin_item->postingdate
            i_contingency = mv_contingency ).

          taxbr->calculate_taxes_net(
            EXPORTING
              it_glitems = lt_origin_glitems
            IMPORTING
              et_glitems = DATA(new_glitems)
          ).
        CATCH zcx_interco_taxbr.
          CLEAR: lt_journal_entry, lt_origin_glitems, new_glitems.
          CONTINUE.
      ENDTRY.

      " Reasignamos los line items:
      DO lines( new_glitems ) TIMES.
        DATA(lr_new_glitem) = REF #( new_glitems[ sy-index ] ).
        lr_new_glitem->glaccountlineitem = CONV #( sy-index ).

        DATA(target_costcenter) = brf_helper->get_cc_code(
                                    iv_tipo_doc = brf_helper->co_with_doctype-sales_tax
                                    iv_cuenta = lr_new_glitem->glaccount ).
        IF target_costcenter IS NOT INITIAL.
          DATA(target_cc_length) = strlen( target_costcenter ).
          lr_new_glitem->costcenter(target_cc_length) = target_costcenter.
        ELSE.
          CLEAR lr_new_glitem->costcenter.
        ENDIF.

      ENDDO.
* Ini EXT_OSCUGALD 10.08.2026 - Fix F5727: agrupamiento previo al posting de _glitems
      IF zcl_interco_taxbr=>use_new_aggregation( ) = abap_true.
        DATA(lt_glitems_detail) = new_glitems.
        zcl_interco_taxbr=>aggregate_glitems( CHANGING ct_glitems = new_glitems ).
        IF lines( new_glitems ) > zcl_interco_taxbr=>mc_max_glitems_threshold.
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit
            EXPORTING
              textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
      ENDIF.
* Fin EXT_OSCUGALD 10.08.2026 - Fix F5727: agrupamiento previo al posting de _glitems
      lr_journal_entry->%param-_glitems = new_glitems.

      DATA(dummy_documentkey) = 'DUMMY' && gs_header-providercompanycode && gs_header-product
                                       && lr_proposal_document->documentkey.

*ext_oscugald
      DO lines( lt_docs ) TIMES.
        DATA(lr_doc) = REF #( lt_docs[ sy-index ] ).
        IF NOT line_exists( gt_doc_map[
                  id           = lr_doc->id
                  item_id      = lr_doc->item_id
                  documenttype = mv_posting_doctype
                  documentkey  = dummy_documentkey ] ).
          APPEND VALUE #(
            id           = lr_doc->id
            item_id      = lr_doc->item_id
            itembasis_id = lr_doc->itembasis_id
            itemcalc_id  = lr_doc->itemcalc_id
            documenttype = mv_posting_doctype
            documentkey  = dummy_documentkey
            companycode = lr_proposal_document->companycode
            fiscalyear = lr_proposal_document->fiscalyear
            parentdocumentkey = lr_proposal_document->documentkey
            parentdocumentname = lr_proposal_document->documentname
            parentdocumenttype = lr_proposal_document->documenttype
            parentcompanycode = lr_proposal_document->companycode
            parentfiscalyear = lr_proposal_document->fiscalyear
          ) TO gt_doc_map.
        ENDIF.
      ENDDO.

      DATA(lo_parallel) = NEW zcl_proposal_bo_parallel(
                                iv_process = gv_process
                                iv_documenttype = mv_posting_doctype
                                iv_parent_dockey = CONV #( lv_document_key )
                                iv_parent_doctype = CONV #( mv_parent_doctype )
                                it_doc    = gts_doc
                                it_doc_map = gt_doc_map
                                it_post = lt_journal_entry ).

      APPEND lo_parallel TO mt_parallel_processing_list.
      CLEAR: gts_doc, gt_doc_map, lt_journal_entry, lt_origin_glitems, new_glitems.

    ENDLOOP.

    IF mt_parallel_processing_list IS INITIAL.
      RETURN.
    ENDIF.

    exe_bo( ).
    et_doc_map = me->gt_doc_map.

    IF gt_doc_map[] IS INITIAL OR
       line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-error ] ) OR
       line_exists( gt_doc_map[ status = abap_false ] ) OR
       line_exists( gt_doc_map[ status = zcl_proposal_bo_abs=>c_document_status-simulated_error ] ).
      save_log( ).
      RAISE EXCEPTION TYPE zcx_calc_exit EXPORTING textid = zcx_calc_exit=>error_generating_documents.
    ENDIF.

  ENDMETHOD.


  METHOD post_journalentry.
    DATA lv_dockey     TYPE zfi_a_intrc_cpid-documentkey.
    DATA lv_status_log TYPE zfi_a_intrc_cpdl-msgty.

    DATA lv_created_at TYPE abp_creation_tstmpl .
    GET TIME STAMP FIELD lv_created_at.
    DATA(lv_created_by) = CONV abp_creation_user( cl_abap_context_info=>get_user_technical_name( ) ).
    DATA(lv_companycode) = it_journal_entry[ 1 ]-%param-companycode.
    DATA(lv_fiscalyear) = CONV gjahr( it_journal_entry[ 1 ]-%param-documentdate(4) ).
    DATA(lv_accounting_document_type) = it_journal_entry[ 1 ]-%param-accountingdocumenttype.

    DATA(lt_doc_map) = gt_doc_map.
    DELETE lt_doc_map WHERE parentdocumentkey <> iv_parent_documentkey.

    MODIFY ENTITIES OF i_journalentrytp
        ENTITY journalentry
        EXECUTE post FROM it_journal_entry
        FAILED DATA(early_failed)
        REPORTED DATA(early_reported)
        MAPPED DATA(early_mapped).

    IF early_failed-journalentry IS NOT INITIAL.
      DATA(v_status_doc) = zcl_proposal_bo_abs=>c_document_status-error.
      CLEAR lv_dockey.

      mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                 iv_companycode = lv_companycode
                                 iv_fiscalyear  = lv_fiscalyear
                                 iv_doctype     = mv_posting_doctype
                                 it_reported    = early_reported-journalentry
                       CHANGING  ct_map_id_doc  = lt_doc_map
                                 cv_status      = lv_status_log ).

      mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                                  iv_companycode            = lv_companycode
                                  iv_fiscalyear             = lv_fiscalyear
                                  iv_doctype                = mv_posting_doctype
                                  iv_status                 = lv_status_log
                                  iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                                  iv_accountingdocumenttype = lv_accounting_document_type
                                  iv_isadjustment           = space
                                  iv_parentcompanycode = lv_companycode
                                  iv_parentfiscalyear = lv_fiscalyear
                                  iv_parentdockey = CONV #( iv_parent_documentkey )
                                  its_doc                   = CORRESPONDING #( lt_doc_map )
                                  iv_byuser                 = lv_created_by
                                  iv_attime                 = lv_created_at
                        CHANGING  ct_map_id_doc             = lt_doc_map ).
    ELSE.

      COMMIT ENTITIES BEGIN
      RESPONSE OF i_journalentrytp
      FAILED DATA(ls_save_failed)
      REPORTED DATA(ls_save_reported).

      LOOP AT early_mapped-journalentry REFERENCE INTO DATA(mapped_journalentry).

        CONVERT KEY OF i_journalentrytp FROM mapped_journalentry->%pid TO DATA(ls_so_final_key).
        DATA(lv_status_doc) = zcl_proposal_bo_abs=>c_document_status-commit.
        lv_dockey = ls_so_final_key-accountingdocument.
        lv_companycode = ls_so_final_key-companycode.
        lv_fiscalyear = ls_so_final_key-fiscalyear.

        mapping_doc_log( EXPORTING iv_dockey      = lv_dockey
                                   iv_companycode = lv_companycode
                                   iv_fiscalyear  = lv_fiscalyear
                                   iv_doctype     = mv_posting_doctype
                                   it_reported    = ls_save_reported-journalentry
                         CHANGING  ct_map_id_doc  = lt_doc_map
                                   cv_status      = lv_status_log ).

        mapping_doc( EXPORTING iv_dockey                 = lv_dockey
                                    iv_companycode            = lv_companycode
                                    iv_fiscalyear             = lv_fiscalyear
                                    iv_doctype                = mv_posting_doctype
                                    iv_status                 = lv_status_doc
                                    iv_cat_id                 = zcl_proposal_bo_abs=>c_document_category-financial
                                    iv_accountingdocumenttype = lv_accounting_document_type
                                    iv_isadjustment           = space
                                    iv_parentcompanycode = lv_companycode
                                    iv_parentfiscalyear = lv_fiscalyear
                                    iv_parentdockey = CONV #( iv_parent_documentkey )
                                    its_doc                   = CORRESPONDING #( lt_doc_map )
                                    iv_byuser                 = lv_created_by
                                    iv_attime                 = lv_created_at
                          CHANGING  ct_map_id_doc             = lt_doc_map ).
      ENDLOOP.
      COMMIT ENTITIES END.
    ENDIF.

    DELETE gt_doc_map WHERE parentdocumentkey = iv_parent_documentkey.
    lt_doc_map = CORRESPONDING #( gt_intrc_cpid ).
    DELETE lt_doc_map WHERE isdeleted = abap_true.
    APPEND LINES OF lt_doc_map TO gt_doc_map.

  ENDMETHOD.
ENDCLASS.
