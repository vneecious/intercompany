" Ini EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C17: clase nueva
" Determina el AccountingDocumentType (BLART) a aplicar en los documentos contables
" de Facturación Local (CH/ARG), buscando la fila más específica en
" ZI_IntercoDocTypeDetermination (tabla ZINT_A_MD_BLART) por Sociedad Proveedora +
" Sociedad Prestataria (opcional) + DocType + PaymentType (opcional) + signo del importe
" (calculado internamente a partir de i_amount). Replica el patrón de
" ZCL_INTERCO_DOC_GLACCOUNT (constructor + get con precedencia "match exacto o vacío"
" vía RANGE), sin el parámetro i_product (ZINT_A_MD_BLART no tiene esa dimensión) y
" sin desempate determinístico por score — opción (a) aceptada, ver nota de riesgo
" en Fase 6 de la ET (carga de datos no debe generar combinaciones ambiguas).
" Usada por las 9 clases ZCL_PROPOSAL_BO_* (Fase 2/C20) como fallback-first: si no
" encuentra fila, el llamador cae a la lógica hardcodeada que ya existía antes.
CLASS zcl_interco_doc_blart DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_data,
             validfrom              TYPE zi_intercodoctypedetermination-validfrom,
             validto                TYPE zi_intercodoctypedetermination-validto,
             doctype                TYPE zi_intercodoctypedetermination-doctype,
             providercompanycode    TYPE zi_intercodoctypedetermination-providercompanycode,
             recipientcompanycode   TYPE zi_intercodoctypedetermination-recipientcompanycode,
             paymenttype            TYPE zi_intercodoctypedetermination-paymenttype,
             amountsign             TYPE zi_intercodoctypedetermination-amountsign,
             accountingdocumenttype TYPE zi_intercodoctypedetermination-accountingdocumenttype,
           END OF ty_data.

    DATA data TYPE TABLE OF ty_data READ-ONLY.

    METHODS constructor
      IMPORTING
        i_valid_at              TYPE sy-datum DEFAULT sy-datum
        i_doctype               TYPE zi_intercodoctypedetermination-doctype
        i_provider_company_code TYPE zi_intercodoctypedetermination-providercompanycode.

    METHODS get
      IMPORTING
                i_recipientcompanycode TYPE zi_intercodoctypedetermination-recipientcompanycode OPTIONAL
                i_paymenttype          TYPE zi_intercodoctypedetermination-paymenttype OPTIONAL
                i_amount               TYPE fis_wsl
      RETURNING VALUE(result)          TYPE zi_intercodoctypedetermination-accountingdocumenttype.

ENDCLASS.



CLASS zcl_interco_doc_blart IMPLEMENTATION.

  METHOD constructor.

    SELECT validfrom, validto, doctype, providercompanycode, recipientcompanycode,
           paymenttype, amountsign, accountingdocumenttype
      FROM zi_intercodoctypedetermination
      WHERE validfrom <= @i_valid_at
        AND validto >= @i_valid_at
        AND providercompanycode = @i_provider_company_code
        AND doctype = @i_doctype
        AND isdeleted IS INITIAL
      INTO TABLE @data.

  ENDMETHOD.

  METHOD get.

    DATA range_recipient_company_code TYPE RANGE OF zi_intercodoctypedetermination-recipientcompanycode.
    DATA range_paymenttype            TYPE RANGE OF zi_intercodoctypedetermination-paymenttype.
    DATA range_amountsign             TYPE RANGE OF zi_intercodoctypedetermination-amountsign.
    DATA lv_amount_sign               TYPE zi_intercodoctypedetermination-amountsign.

    IF i_recipientcompanycode IS SUPPLIED.
      range_recipient_company_code = VALUE #( sign = 'I' option = 'EQ'
                                  ( low = space )
                                  ( low = i_recipientcompanycode ) ).
    ENDIF.

    IF i_paymenttype IS SUPPLIED.
      range_paymenttype = VALUE #( sign = 'I' option = 'EQ'
                               ( low = space )
                               ( low = i_paymenttype ) ).
    ENDIF.

    " El signo se calcula siempre a partir del importe (no es un parámetro que el llamador decida)
    lv_amount_sign = COND #( WHEN i_amount < 0 THEN '-' ELSE '+' ).
    range_amountsign = VALUE #( sign = 'I' option = 'EQ'
                             ( low = space )
                             ( low = lv_amount_sign ) ).

    SELECT SINGLE data~accountingdocumenttype FROM @data AS data
      WHERE recipientcompanycode IN @range_recipient_company_code
        AND paymenttype IN @range_paymenttype
        AND amountsign IN @range_amountsign
      INTO @result.

    IF sy-subrc <> 0.
      " TODO: handle error
    ENDIF.

  ENDMETHOD.

ENDCLASS.
" Fin EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C17
