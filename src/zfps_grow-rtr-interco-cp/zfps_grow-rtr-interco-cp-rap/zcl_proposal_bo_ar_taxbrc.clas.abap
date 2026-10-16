CLASS zcl_proposal_bo_ar_taxbrc DEFINITION
  PUBLIC
  INHERITING FROM zcl_proposal_bo_ar_taxbr
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
  PROTECTED SECTION.
    METHODS: preparedata_reverse REDEFINITION.
    METHODS: preparedata REDEFINITION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_PROPOSAL_BO_AR_TAXBRC IMPLEMENTATION.


  METHOD preparedata_reverse.
    gv_process = 'R'.
    mv_posting_doctype = c_document_type-taxbr_sales_contingency.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_cont.
    mv_parent_doctype = c_document_type-je_sales.
  ENDMETHOD.


  METHOD preparedata.
    DATA lv_taxbr_gl TYPE hkont.
    " Prepara los datos necesarios para la generación de este tipo de asiento contable.
    " Como el documento se basa en el AR, debemos asegurarnos de que haya sido generado
    " correctamente antes de continuar con este proceso.
    "
    " También se filtran únicamente los ítems relevantes de la propuesta,
    " es decir, aquellos correspondientes a operaciones BR → BR.

    mv_posting_doctype = c_document_type-taxbr_sales_contingency.
    mv_reverse_doctype = c_document_type-reverse_taxbr_sales_cont.
    mv_parent_doctype = c_document_type-je_sales.
    mv_contingency = abap_true.

    " Mantiene únicamente los ítems relevantes de la propuesta (BR → BR).
    DELETE gtd_items_add WHERE NOT (
            with_ar_taxbrc IS INITIAL
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

    SELECT companycode, accountingdocument, fiscalyear,
    accountingdocumentheadertext, documentreferenceid, documentdate, postingdate, absoluteexchangerate
    FROM i_journalentry
    FOR ALL ENTRIES IN @lt_dockeys
    WHERE companycode = @lt_dockeys-companycode
    AND accountingdocument = @lt_dockeys-documentkey
    AND fiscalyear = @lt_dockeys-fiscalyear
    INTO TABLE @DATA(lt_journalentry).

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
      partnercompany
    FROM i_journalentryitem
    FOR ALL ENTRIES IN @lt_journalentry
    WHERE sourceledger = '0L'
    AND fiscalyear = @lt_journalentry-fiscalyear
    AND accountingdocument = @lt_journalentry-accountingdocument
    AND companycode = @lt_journalentry-companycode
    AND sourceledger = '0L'
*    AND financialaccounttype = 'S' AND glaccount <> '0000780010'
    AND financialaccounttype = 'S' AND glaccount <> @lv_taxbr_gl
    AND accountingdocumentitem > 0
    INTO TABLE @DATA(lt_journalentryitem).

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
ENDCLASS.
