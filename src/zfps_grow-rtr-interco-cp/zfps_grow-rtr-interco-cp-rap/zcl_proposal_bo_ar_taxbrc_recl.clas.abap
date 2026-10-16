CLASS zcl_proposal_bo_ar_taxbrc_recl DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_ar_taxbr_recl
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS:
      preparedata REDEFINITION,
      preparedata_reverse REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PROPOSAL_BO_AR_TAXBRC_RECL IMPLEMENTATION.


  METHOD preparedata.
    DATA lv_taxbr_gl TYPE hkont.
    " Prepara los datos necesarios para la generación de este tipo de asiento contable.
    " Como el documento se basa en el AP, debemos asegurarnos de que haya sido generado
    " correctamente antes de continuar con este proceso.
    "
    " También se filtran únicamente los ítems relevantes de la propuesta,
    " es decir, aquellos correspondientes a operaciones BR → BR.

    mv_posting_doctype = c_document_type-taxbr_sales_cont_reclassif.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_cont_recla.
    mv_parent_doctype = c_document_type-taxbr_sales_contingency.

    " Mantiene únicamente los ítems relevantes de la propuesta (BR → BR).
    DELETE gtd_items_add WHERE NOT (
            with_ap_taxbrc_rec IS INITIAL
        AND interdivisional IS INITIAL
        AND recipientcountry = 'BR'
        AND providercountry = 'BR'
    ).

    IF gtd_items_add IS NOT INITIAL.
      SELECT DISTINCT companycode, internalcode FROM zi_intercocompanycode
      FOR ALL ENTRIES IN @gtd_items_add
        WHERE companycode = @gtd_items_add-recipientcompanycode
        INTO TABLE @mt_internal_codes.
    ENDIF.

    " Mantiene únicamente los documentos padres.
    DELETE gtd_doc WHERE documenttype <> mv_parent_doctype
                 OR status <> zcl_proposal_bo_abs=>c_document_status-commit.

    " Por las dudas...
    LOOP AT gtd_doc REFERENCE INTO DATA(lr_doc).
      IF NOT line_exists( gtd_items_add[ id = lr_doc->id item_id = lr_doc->item_id itembasis_id = lr_doc->itembasis_id itemcalc_id = lr_doc->itemcalc_id ] ).
        DELETE gtd_doc INDEX sy-tabix.
      ENDIF.
    ENDLOOP.

    IF gtd_doc IS INITIAL.
      RETURN.
    ENDIF.

    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ gs_header-fiscalyear }{ gs_header-fiscalperiod+1 }01| ).

    DATA range_accounts TYPE RANGE OF saknr.

    SELECT DISTINCT 'I', 'EQ', \_items-glaccount2 AS low FROM zi_intercotaxbr
      WHERE providercompanycode = @gs_header-providercompanycode
        AND product = @gs_header-product
        AND validfrom <= @last_day_of_month
        AND validto >= @last_day_of_month
        AND isdeleted IS INITIAL
        AND documenttype = @zcl_interco_taxbr=>co_doctype-sales
        AND \_items-classif = @abap_true
        AND \_items-Contingency = @abap_true
        INTO TABLE @range_accounts.

    IF range_accounts IS INITIAL.
      RETURN.
    ENDIF.

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

    SELECT companycode, accountingdocument, fiscalyear,
    accountingdocumentheadertext, documentreferenceid, documentdate, postingdate, absoluteexchangerate
    FROM i_journalentry
    FOR ALL ENTRIES IN @lt_dockeys
    WHERE companycode = @lt_dockeys-companycode
    AND accountingdocument = @lt_dockeys-documentkey
    AND fiscalyear = @lt_dockeys-fiscalyear
    INTO TABLE @DATA(lt_journalentry).             "#EC CI_NO_TRANSFORM

    "***Begin of Change - COA_MIGRATION: TVARVC parameterization of GL account
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZWT_GLACCOUNT_REDONDEO'
      INTO @lv_taxbr_gl.

    lv_taxbr_gl = |{ lv_taxbr_gl ALPHA = IN }|.
    "***End of Change - COA_MIGRATION

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
      partnercompany,
      financialaccounttype
    FROM i_journalentryitem
    FOR ALL ENTRIES IN @lt_journalentry
    WHERE sourceledger = '0L'
    AND fiscalyear = @lt_journalentry-fiscalyear
    AND accountingdocument = @lt_journalentry-accountingdocument
    AND companycode = @lt_journalentry-companycode
*    AND financialaccounttype = 'S' AND glaccount <> '0000780010'
    AND financialaccounttype = 'S' AND glaccount <> @lv_taxbr_gl
    AND accountingdocumentitem > 0
        AND glaccount IN @range_accounts
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
*        jeitem~financialaccounttype,
        je~absoluteexchangerate
      FROM @lt_journalentry AS je
        INNER JOIN @lt_journalentryitem AS jeitem ON je~companycode = jeitem~companycode
        AND  je~fiscalyear = jeitem~fiscalyear
        AND je~accountingdocument = jeitem~accountingdocument
      INTO TABLE @mt_origin_documents.


  ENDMETHOD.


  METHOD preparedata_reverse.
    gv_process = 'R'.
    mv_posting_doctype = c_document_type-taxbr_sales_cont_reclassif.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_cont_recla.
    mv_parent_doctype = c_document_type-taxbr_sales_contingency.
  ENDMETHOD.
ENDCLASS.
