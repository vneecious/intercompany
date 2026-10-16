"! <p><strong>Propósito:</strong></p>
"! Este documento tiene como objetivo registrar las líneas de reclasificacion de
"! impuestos.
"!
"! <p><strong>Contexto Meli:</strong></p>
"! En Meli, los impuestos relacionados con operaciones intercompany
"! (PIS, COFINS, etc.) se contabilizan en documentos separados,
"! y no en el propio documento de ventas generado por la clase
"! ZCL_PROPOSAL_BO_AP.
"!
"! Una vez generado el asiento contable del impuesto por la clase
"! ZCL_PROPOSAL_BO_AP_TAXBR, es requerido reclasificarlo.
CLASS zcl_proposal_bo_ar_taxbr_recl DEFINITION
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
           END OF ty_origin_documents,

           BEGIN OF ty_internal_codes,
             companycode   TYPE zi_intercocompanycode-companycode,
             internalcodes TYPE zi_intercocompanycode-internalcode,
           END OF ty_internal_codes.

  PROTECTED SECTION.
    DATA: mt_origin_documents TYPE TABLE OF ty_origin_documents.
    DATA mt_internal_codes TYPE TABLE OF ty_internal_codes.
    DATA mv_contingency TYPE abap_boolean.

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



CLASS zcl_proposal_bo_ar_taxbr_recl IMPLEMENTATION.


  METHOD preparedata.
    " Prepara los datos necesarios para la generación de este tipo de asiento contable.
    " Como el documento se basa en el AP, debemos asegurarnos de que haya sido generado
    " correctamente antes de continuar con este proceso.
    "
    " También se filtran únicamente los ítems relevantes de la propuesta,
    " es decir, aquellos correspondientes a operaciones BR → BR.

    DATA:
      lv_taxbr_gl TYPE hkont.

    mv_posting_doctype = c_document_type-taxbr_sales_reclassif.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_reclassif.
    mv_parent_doctype  = c_document_type-je_purchase.
    mv_contingency     = abap_false.

*Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: ICSRV30/ICSRV31 no tienen configuración TaxBR
    " zi_intercotaxbr no tiene registros para CS → zcl_interco_taxbr lanza zcx_interco_taxbr
    " ZCL_PROPOSAL_BO_AP_TAXBR_RECL retorna via gtd_doc IS INITIAL (parent=taxbr_purchases,
    " que CS no genera). Esta clase usa parent=je_purchase que CS SÍ genera → RETURN explícito.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_CS_PRODUCT'
        AND type = 'S'
        AND low  = @gs_header-product
      INTO @DATA(lv_cs_prod_check).
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
*Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing

    " Mantiene únicamente los ítems relevantes de la propuesta (BR → BR).
    DELETE gtd_items_add WHERE NOT (
            with_ar_taxbr_rec IS INITIAL
        AND interdivisional   IS INITIAL
        AND recipientcountry  = 'BR'
        AND providercountry   = 'BR'
    ).

    IF gtd_items_add IS NOT INITIAL.
      SELECT DISTINCT companycode, internalcode FROM zi_intercocompanycode
        FOR ALL ENTRIES IN @gtd_items_add
        WHERE companycode = @gtd_items_add-recipientcompanycode
        INTO TABLE @mt_internal_codes.
    ENDIF.

    " Mantiene únicamente los documentos padres.
    DELETE gtd_doc WHERE documenttype <> mv_parent_doctype
                      OR status       <> zcl_proposal_bo_abs=>c_document_status-commit.

    " Por las dudas...
    LOOP AT gtd_doc REFERENCE INTO DATA(lr_doc).
      IF NOT line_exists( gtd_items_add[ id           = lr_doc->id
                                         item_id      = lr_doc->item_id
                                         itembasis_id = lr_doc->itembasis_id
                                         itemcalc_id  = lr_doc->itemcalc_id ] ).
        DELETE gtd_doc INDEX sy-tabix.
      ENDIF.
    ENDLOOP.

    IF gtd_doc IS INITIAL.
      RETURN.
    ENDIF.

    TYPES: BEGIN OF ty_dockeys,
             companycode TYPE bukrs,
             fiscalyear  TYPE gjahr,
             documentkey TYPE belnr_d,
           END OF ty_dockeys,
           tt_dockeys TYPE TABLE OF ty_dockeys.

    DATA(lt_dockeys) = CORRESPONDING tt_dockeys( gtd_doc DISCARDING DUPLICATES ).

    "***Begin of Change - COA_MIGRATION: TVARVC parameterization of GL account
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZWT_GLACCOUNT_REDONDEO'
      INTO @lv_taxbr_gl.

    lv_taxbr_gl = |{ lv_taxbr_gl ALPHA = IN }|.
    "***End of Change - COA_MIGRATION

    IF lt_dockeys IS INITIAL.
      RETURN.
    ENDIF.

*Ini EXT_OSCUGALD 15.06.2026 - ATC: fusionar 2 FOR ALL ENTRIES en un solo JOIN directo
    " CL_CI_TEST_FOR_ALL_ENTR_HANA/TRANSFORM (Priority 2): los dos FOR ALL ENTRIES
    " encadenados (i_journalentry → i_journalentryitem) + JOIN en memoria se reemplazan
    " por un único SELECT con INNER JOIN en SQL. Resultado en mt_origin_documents idéntico:
    " mismos campos, mismos filtros, mismo tipo de JOIN. Verificado campo a campo.
    " Nota: 'CH' AS accountingdocumenttype no permitido en FOR ALL ENTRIES →
    "        se asigna en LOOP posterior (misma semántica que el código original).
    " Código original dejado comentado como backup.

    SELECT
        _je~companycode,
        _je~accountingdocument,
        _je~fiscalyear,
        _je~accountingdocumentheadertext,
        _je~documentreferenceid,
        _je~documentdate,
        _je~postingdate,
        _jeitem~glaccount,
        _jeitem~accountingdocumentitem,
        _jeitem~assignmentreference,
        _jeitem~documentitemtext,
        _jeitem~costcenter,
        _jeitem~product,
        _jeitem~quantity,
        _jeitem~baseunit,
        _jeitem~amountintransactioncurrency,
        _jeitem~transactioncurrency,
        _jeitem~partnercompany,
        _je~absoluteexchangerate
      FROM i_journalentry AS _je
        INNER JOIN i_journalentryitem AS _jeitem
          ON  _jeitem~companycode        = _je~companycode
          AND _jeitem~fiscalyear         = _je~fiscalyear
          AND _jeitem~accountingdocument = _je~accountingdocument
      FOR ALL ENTRIES IN @lt_dockeys
      WHERE _je~companycode                  = @lt_dockeys-companycode
        AND _je~accountingdocument           = @lt_dockeys-documentkey
        AND _je~fiscalyear                   = @lt_dockeys-fiscalyear
        AND _jeitem~sourceledger             = '0L'
        AND _jeitem~financialaccounttype     = 'S'
*        AND _jeitem~glaccount               <> '0000780010'
        AND _jeitem~glaccount               <> @lv_taxbr_gl
        AND _jeitem~accountingdocumentitem   > 0
      INTO CORRESPONDING FIELDS OF TABLE @mt_origin_documents.

    " 'CH' no permitido como literal en FOR ALL ENTRIES → se asigna post-SELECT.
    " Comportamiento idéntico al código original donde también se hardcodeaba 'CH'.
    LOOP AT mt_origin_documents ASSIGNING FIELD-SYMBOL(<ls_origin>).
      <ls_origin>-accountingdocumenttype = 'CH'.
    ENDLOOP.
*Fin EXT_OSCUGALD 15.06.2026 - ATC

*    " Prepara los datos necesarios para la generación de este tipo de asiento contable.
*    " Como el documento se basa en el AP, debemos asegurarnos de que haya sido generado
*    " correctamente antes de continuar con este proceso.
*    "
*    " También se filtran únicamente los ítems relevantes de la propuesta,
*    " es decir, aquellos correspondientes a operaciones BR → BR.
*
*    mv_posting_doctype = c_document_type-taxbr_sales_reclassif.
*    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_reclassif.
*    mv_parent_doctype = c_document_type-je_purchase.
*    mv_contingency = abap_false.
*
**Ini EXT_OSCUGALD 29.05.2026 - Cost Sharing: ICSRV30/ICSRV31 no tienen configuración TaxBR
*    " AP_TAXBR_RECL retorna via gtd_doc IS INITIAL (parent=taxbr_purchases, CS no lo genera)
*    " AR_TAXBR_RECL usa parent=je_purchase que CS SÍ genera → sin este RETURN llega al try-catch
*    " zi_intercotaxbr no tiene registros para ICSRV30/ICSRV31 → zcx_interco_taxbr siempre
*    SELECT SINGLE low FROM zi_tvarvc
*      WHERE name = 'ZINTERCO_CS_PRODUCT'
*        AND type = 'S'
*        AND low  = @gs_header-product
*      INTO @DATA(lv_cs_prod_check).
*    IF sy-subrc = 0.
*      RETURN.
*    ENDIF.
**Fin EXT_OSCUGALD 29.05.2026 - Cost Sharing
*
*    " Mantiene únicamente los ítems relevantes de la propuesta (BR → BR).
*    DELETE gtd_items_add WHERE NOT (
*            with_ar_taxbr_rec IS INITIAL
*        AND interdivisional IS INITIAL
*        AND recipientcountry = 'BR'
*        AND providercountry = 'BR'
*    ).
*
*    IF gtd_items_add IS NOT INITIAL.
*      SELECT DISTINCT companycode, internalcode FROM zi_intercocompanycode
*      FOR ALL ENTRIES IN @gtd_items_add
*        WHERE companycode = @gtd_items_add-recipientcompanycode
*        INTO TABLE @mt_internal_codes.
*    ENDIF.
*
*    " Mantiene únicamente los documentos padres.
*    DELETE gtd_doc WHERE documenttype <> mv_parent_doctype
*                 OR status <> zcl_proposal_bo_abs=>c_document_status-commit.
*
*    " Por las dudas...
*    LOOP AT gtd_doc REFERENCE INTO DATA(lr_doc).
*      IF NOT line_exists( gtd_items_add[ id = lr_doc->id item_id = lr_doc->item_id itembasis_id = lr_doc->itembasis_id itemcalc_id = lr_doc->itemcalc_id ] ).
*        DELETE gtd_doc INDEX sy-tabix.
*      ENDIF.
*    ENDLOOP.
*
*    IF gtd_doc IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).
*
**    TYPES:
**      BEGIN OF ty_dockey,
**        companycode          TYPE bukrs,
**        fiscalyear           TYPE gjahr,
**        documentkey          TYPE belnr_d,
**        recipientcompanycode TYPE bukrs,
**      END OF ty_dockey.
**    DATA lt_dockeys TYPE TABLE OF ty_dockey.
**
**    " Tabla auxiliar para filtro de documents / cuentas relevantes para el proceso actual
**    SELECT gtd_doc~companycode, gtd_doc~fiscalyear, gtd_doc~documentkey, recipientcompanycode
**      FROM @gtd_doc AS gtd_doc
**        INNER JOIN @gtd_items_add AS gtd_items_add
**          ON gtd_items_add~id = gtd_doc~id
**         AND gtd_items_add~item_id = gtd_doc~item_id
**         AND gtd_items_add~itembasis_id = gtd_doc~itembasis_id
**         AND gtd_items_add~itemcalc_id = gtd_doc~itemcalc_id
**        INTO TABLE @lt_dockeys.
**
**    IF lt_dockeys IS INITIAL.
**      RETURN.
**    ENDIF.
**
**    SORT lt_dockeys.
**    DELETE ADJACENT DUPLICATES FROM lt_dockeys.
**
**    " Se buscan las parametrizaciones relevantes para el proceso actual y relacionandolas a los documents de origen
**    SELECT DISTINCT dockeys~companycode, dockeys~fiscalyear, dockeys~documentkey AS accountingdocument, \_items-glaccount2 AS glaccount FROM zi_intercotaxbr
**    INNER JOIN @lt_dockeys AS dockeys ON dockeys~recipientcompanycode = zi_intercotaxbr~recipientcompanycode
**      WHERE providercompanycode = @gs_header-providercompanycode
**        AND product = @gs_header-product
**        AND validfrom <= @last_day_of_month
**        AND validto >= @last_day_of_month
**        AND isdeleted IS INITIAL
**        AND documenttype = @zcl_interco_taxbr=>co_doctype-sales
**        AND \_items-classif = @abap_true
**        INTO TABLE @DATA(taxbr_items).
**
**    " si no hay ninguna, nada que hacer...
**    IF taxbr_items IS INITIAL.
**      RETURN.
**    ENDIF.
**
**    " Se buscan los documentos cotables de origen (doctype 401 - ZCL_PROPOSAL_BO_AR_TAXBR)
**    SELECT companycode, accountingdocument, fiscalyear,
**    accountingdocumentheadertext, documentreferenceid, documentdate, postingdate, absoluteexchangerate
**    FROM i_journalentry
**    FOR ALL ENTRIES IN @lt_dockeys
**    WHERE companycode = @lt_dockeys-companycode
**    AND accountingdocument = @lt_dockeys-documentkey
**    AND fiscalyear = @lt_dockeys-fiscalyear
**    INTO TABLE @DATA(lt_journalentry).
**
**    IF lt_journalentry IS  INITIAL.
**      RETURN.
**    ENDIF.
**
**    " Se buscan los items relevantes de los documentos contables de origen
**    SELECT companycode, accountingdocument, fiscalyear,
**      glaccount,
**      accountingdocumentitem,
**      assignmentreference,
**      documentitemtext,
**      costcenter,
**      product,
**      quantity,
**      baseunit,
**      amountintransactioncurrency,
**      transactioncurrency,
**      partnercompany,
**      financialaccounttype
**    FROM i_journalentryitem
**    FOR ALL ENTRIES IN @lt_journalentry
**    WHERE sourceledger = '0L'
**    AND fiscalyear = @lt_journalentry-fiscalyear
**    AND accountingdocument = @lt_journalentry-accountingdocument
**    AND companycode = @lt_journalentry-companycode
**    AND sourceledger = '0L'
**    AND financialaccounttype = 'S' AND glaccount <> '0000780010' " cuenta de redondeo
**    AND accountingdocumentitem > 0 " te juro que fue necesario
**    INTO TABLE @DATA(lt_journalentryitem).
**
**    " por fin, se genera la tabla completa de documentos de origen que se va utilizar para generar el asiento de reclasificacion
**    SELECT
**        je~companycode,
**        je~accountingdocument,
**        je~fiscalyear,
**        'CH' AS accountingdocumenttype,
**        je~accountingdocumentheadertext,
**        je~documentreferenceid,
**        je~documentdate,
**        je~postingdate,
**        jeitem~glaccount,
**        jeitem~accountingdocumentitem,
**        jeitem~assignmentreference,
**        jeitem~documentitemtext,
**        jeitem~costcenter,
**        jeitem~product,
**        jeitem~quantity,
**        jeitem~baseunit,
**        jeitem~amountintransactioncurrency,
**        jeitem~transactioncurrency,
**        jeitem~partnercompany,
**        jeitem~financialaccounttype,
**        je~absoluteexchangerate
**      FROM @lt_journalentry AS je
**        INNER JOIN @lt_journalentryitem AS jeitem
**          ON je~companycode = jeitem~companycode
**         AND je~fiscalyear = jeitem~fiscalyear
**         AND je~accountingdocument = jeitem~accountingdocument
**        " aca filtramos solamente los documentos relevantes / cuentas contables parametrizadas como reclasificables
**        INNER JOIN @taxbr_items AS taxbr_items
**          ON je~companycode = taxbr_items~companycode
**         AND je~fiscalyear = taxbr_items~fiscalyear
**         AND je~accountingdocument  = taxbr_items~accountingdocument
**         AND jeitem~glaccount = taxbr_items~glaccount
**      INTO TABLE @mt_origin_documents.
**
**    SORT mt_origin_documents.
**    DELETE ADJACENT DUPLICATES FROM mt_origin_documents.
*
*    TYPES: BEGIN OF ty_dockeys,
*             companycode TYPE bukrs,
*             fiscalyear  TYPE gjahr,
*             documentkey TYPE belnr_d,
*           END OF ty_dockeys,
*           tt_dockeys TYPE TABLE OF ty_dockeys.
*
*
*    DATA(lt_dockeys) = CORRESPONDING tt_dockeys( gtd_doc DISCARDING DUPLICATES ).
*
*    IF lt_dockeys IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    SELECT companycode, accountingdocument, fiscalyear,
*    accountingdocumentheadertext, documentreferenceid, documentdate, postingdate, absoluteexchangerate
*    FROM i_journalentry
*    FOR ALL ENTRIES IN @lt_dockeys
*    WHERE companycode = @lt_dockeys-companycode
*    AND accountingdocument = @lt_dockeys-documentkey
*    AND fiscalyear = @lt_dockeys-fiscalyear
*    INTO TABLE @DATA(lt_journalentry).
*
*    IF lt_journalentry IS  INITIAL.
*      RETURN.
*    ENDIF.
*
*    SELECT companycode, accountingdocument, fiscalyear,
*      glaccount,
*      accountingdocumentitem,
*      assignmentreference,
*      documentitemtext,
*      costcenter,
*      product,
*      quantity,
*      baseunit,
*      amountintransactioncurrency,
*      transactioncurrency,
*      partnercompany
*    FROM i_journalentryitem
*    FOR ALL ENTRIES IN @lt_journalentry
*    WHERE sourceledger = '0L'
*    AND fiscalyear = @lt_journalentry-fiscalyear
*    AND accountingdocument = @lt_journalentry-accountingdocument
*    AND companycode = @lt_journalentry-companycode
*    AND sourceledger = '0L'
*    AND financialaccounttype = 'S' AND glaccount <> '0000780010'
*    AND accountingdocumentitem > 0
*    INTO TABLE @DATA(lt_journalentryitem).
*
*    SELECT
*        je~companycode,
*        je~accountingdocument,
*        je~fiscalyear,
*        'CH' AS accountingdocumenttype,
*        je~accountingdocumentheadertext,
*        je~documentreferenceid,
*        je~documentdate,
*        je~postingdate,
*        jeitem~glaccount,
*        jeitem~accountingdocumentitem,
*        jeitem~assignmentreference,
*        jeitem~documentitemtext,
*        jeitem~costcenter,
*        jeitem~product,
*        jeitem~quantity,
*        jeitem~baseunit,
*        jeitem~amountintransactioncurrency,
*        jeitem~transactioncurrency,
*        jeitem~partnercompany,
*        je~absoluteexchangerate
*      FROM @lt_journalentry AS je
*        INNER JOIN @lt_journalentryitem AS jeitem ON je~companycode = jeitem~companycode
*        AND  je~fiscalyear = jeitem~fiscalyear
*        AND je~accountingdocument = jeitem~accountingdocument
*      INTO TABLE @mt_origin_documents.

  ENDMETHOD.


  METHOD preparedata_reverse.
    gv_process = 'R'.
    mv_posting_doctype = c_document_type-taxbr_sales_reclassif.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_reclassif.
    mv_parent_doctype = c_document_type-taxbr_sales.
  ENDMETHOD.


  METHOD mapping_bo_sec.
    " Mapeo de I_JournalENtryTP~Post

    DATA lt_journal_entry TYPE tt_journal_entry.

    IF gv_process = 'S' OR mt_origin_documents IS INITIAL.
      RETURN.
    ENDIF.

    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).


    DATA(brf_helper) = NEW zcl_interco_brf_wht( ).

    LOOP AT mt_origin_documents REFERENCE INTO DATA(lr_origin_document)
      GROUP BY lr_origin_document->accountingdocument INTO FINAL(lv_document_key).

      lr_origin_document = REF #( mt_origin_documents[ accountingdocument = lv_document_key ] ).
      DATA(lt_docs) = gtd_doc.
      DELETE lt_docs WHERE documentkey <> lv_document_key.

      DATA(lr_proposal_doc) = REF #( lt_docs[ 1 ] ).
      DATA(lr_proposal_item) = REF #( gtd_items_add[ id = lr_proposal_doc->id item_id = lr_proposal_doc->item_id itembasis_id = lr_proposal_doc->itembasis_id ] ).
      DATA(lv_internal_code) = mt_internal_codes[ companycode = lr_proposal_item->recipientcompanycode ]-internalcodes.

      APPEND INITIAL LINE TO lt_journal_entry REFERENCE INTO DATA(lr_journal_entry).
      lr_journal_entry->%cid = lr_origin_document->accountingdocument && gs_header-product && sy-datum && sy-index.
      lr_journal_entry->%param-accountingdocumenttype = lr_origin_document->accountingdocumenttype.
      lr_journal_entry->%param-ledgergroup = 'INUS'.
      lr_journal_entry->%param-createdbyuser = sy-uname.
      lr_journal_entry->%param-accountingdocumentheadertext = lr_origin_document->accountingdocumentheadertext.
      lr_journal_entry->%param-companycode = lr_proposal_item->recipientcompanycode.
      lr_journal_entry->%param-documentreferenceid = lr_origin_document->documentreferenceid.
      lr_journal_entry->%param-documentdate = lr_origin_document->documentdate.
      lr_journal_entry->%param-postingdate = lr_origin_document->postingdate.

      " Mapea una estructura temporal gl_item con los mismos datos del documento de origen.
      DATA lt_origin_glitems LIKE lr_journal_entry->%param-_glitems.

      LOOP AT GROUP lv_document_key REFERENCE INTO DATA(lr_origin_item).

        DATA(lr_proposal_document) = REF #( gtd_doc[ companycode = lr_origin_item->companycode fiscalyear = lr_origin_item->fiscalyear documentkey = lr_origin_item->accountingdocument ] ).
        lr_proposal_item = REF #( gtd_items_add[ id = lr_proposal_document->id item_id = lr_proposal_document->item_id ] ).

        APPEND INITIAL LINE TO lt_origin_glitems REFERENCE INTO DATA(lr_origin_glitem).
        lr_origin_glitem->glaccountlineitem = lr_origin_item->accountingdocumentitem.
        lr_origin_glitem->glaccount = lr_origin_item->glaccount.
        lr_origin_glitem->glaccountlineitem = lr_origin_item->accountingdocumentitem.
        lr_origin_glitem->assignmentreference = lr_origin_item->assignmentreference.
        lr_origin_glitem->documentitemtext = lr_origin_item->documentitemtext.
        lr_origin_glitem->costcenter =  lr_origin_item->costcenter.

        DATA(target_costcenter) = brf_helper->get_cc_code(
        iv_tipo_doc     = brf_helper->co_with_doctype-purchases_tax ).
        IF target_costcenter IS NOT INITIAL.
          DATA(target_cc_length) = strlen( target_costcenter ).
          lr_origin_glitem->costcenter(target_cc_length) = target_costcenter.
        ELSE.
          CLEAR lr_origin_glitem->costcenter.
        ENDIF.

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
          DATA(taxbr_purchases) = NEW zcl_interco_taxbr(
               i_doctype              = zcl_interco_taxbr=>co_doctype-purchase
               i_providercompanycode  = lr_proposal_item->providercompanycode
               i_recipientcompanycode = lr_proposal_item->recipientcompanycode
               i_product              = lr_proposal_item->product
               i_department           = lr_origin_item->department
               i_valid_at             = lr_origin_item->postingdate
               i_skip_glaccount2      = abap_true
               i_contingency = mv_contingency ).

          taxbr_purchases->calculate_taxes_net(
            EXPORTING
              it_glitems = lt_origin_glitems
            IMPORTING
              et_glitems_custom = DATA(lt_calculated_origin_glitems)
          ).


*          LOOP AT lt_calculated_origin_glitems REFERENCE INTO DATA(calculated_origin_glitem).
*            IF calculated_origin_glitem->glaccount_origin = calculated_origin_glitem->glaccount.
*              CONTINUE.
*            ENDIF.
*
*            DATA(account_determination) = NEW zcl_interco_doc_glaccount(
*                                            i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-taxbr_reclas_ar
*                                            i_product               = gs_header-product
*                                            i_provider_company_code = gs_header-providercompanycode
*                                            i_valid_at              = last_day_of_month ).
*            DATA(new_glaccount) = account_determination->get( ).
*            calculated_origin_glitem->glaccount = new_glaccount-glaccount1.
*          ENDLOOP.
* Ini EXT_OSCUGALD 10.08.2026 - Fix F5727: refactor loop anidado a DO (ATC clean core, sin cambio funcional)
          DATA(lv_lines_calc) = lines( lt_calculated_origin_glitems ).
          DO lv_lines_calc TIMES.
            DATA(calculated_origin_glitem) = REF #( lt_calculated_origin_glitems[ sy-index ] ).
            IF calculated_origin_glitem->glaccount_origin = calculated_origin_glitem->glaccount.
              CONTINUE.
            ENDIF.

            DATA(account_determination) = NEW zcl_interco_doc_glaccount(
                                            i_doctype               = zcl_interco_doc_glaccount=>co_doc_type-taxbr_reclas_ar
                                            i_product               = gs_header-product
                                            i_provider_company_code = gs_header-providercompanycode
                                            i_valid_at              = last_day_of_month ).
            DATA(new_glaccount) = account_determination->get( ).
            calculated_origin_glitem->glaccount = new_glaccount-glaccount1.
          ENDDO.
* Fin EXT_OSCUGALD 10.08.2026 - Fix F5727: refactor loop anidado a DO (ATC clean core, sin cambio funcional)

          DATA(taxbr_sales) = NEW zcl_interco_taxbr(
               i_doctype              = zcl_interco_taxbr=>co_doctype-sales
               i_providercompanycode  = lr_proposal_item->providercompanycode
               i_recipientcompanycode = lr_proposal_item->recipientcompanycode
               i_product              = lr_proposal_item->product
               i_department           = lr_origin_item->department
               i_valid_at             = lr_origin_item->postingdate
               i_skip_glaccount2      = abap_false
               i_contingency = mv_contingency ).

          taxbr_sales->replace_accounts(
            EXPORTING
            it_glitems = lt_calculated_origin_glitems
            IMPORTING
            et_glitems = DATA(lt_completed_origin_glitems)
          ).

        CATCH zcx_interco_taxbr.
          CLEAR: lt_journal_entry, lt_origin_glitems, lt_completed_origin_glitems.
          CONTINUE.
      ENDTRY.

      DATA lt_new_glitems LIKE lr_journal_entry->%param-_glitems.
      lt_new_glitems = CORRESPONDING #( lt_completed_origin_glitems ).

      DO lines( lt_new_glitems ) TIMES.
        DATA(lr_new_glitem) = REF #( lt_new_glitems[ sy-index ] ).
      ENDDO.

* Ini EXT_OSCUGALD 10.08.2026 - Fix F5727: agrupamiento previo al posting de _glitems
      IF zcl_interco_taxbr=>use_new_aggregation( ) = abap_true.
        DATA(lt_glitems_detail) = lt_new_glitems.
        zcl_interco_taxbr=>aggregate_glitems( CHANGING ct_glitems = lt_new_glitems ).
        IF lines( lt_new_glitems ) > zcl_interco_taxbr=>mc_max_glitems_threshold.
          save_log( ).
          RAISE EXCEPTION TYPE zcx_calc_exit
            EXPORTING
              textid = zcx_calc_exit=>error_generating_documents.
        ENDIF.
      ENDIF.
* Fin EXT_OSCUGALD 10.08.2026 - Fix F5727: agrupamiento previo al posting de _glitems
      lr_journal_entry->%param-_glitems = CORRESPONDING #( lt_new_glitems ).

      DATA(dummy_documentkey) = 'DUMMY' && gs_header-providercompanycode && gs_header-product
                                             && lr_origin_item->accountingdocument.

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
      CLEAR: gts_doc, gt_doc_map, lt_journal_entry, lt_completed_origin_glitems, lt_calculated_origin_glitems, lt_new_glitems, lt_origin_glitems.

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
