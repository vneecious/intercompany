CLASS zcl_interco_doc_glaccount DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF co_doc_type,
        ar                  TYPE zint_txbr_doctype VALUE 'AR',
        ap                  TYPE zint_txbr_doctype VALUE 'AP',
        reclassification_ar TYPE zint_txbr_doctype VALUE 'RR',
        reclassification_ap TYPE zint_txbr_doctype VALUE 'RP',
        accural_ar          TYPE zint_txbr_doctype VALUE 'PR',
        accural_ap          TYPE zint_txbr_doctype VALUE 'PP',
        interdivisinoal     TYPE zint_txbr_doctype VALUE 'ID',
        accural_pi          TYPE zint_txbr_doctype VALUE 'PI',
        exchange_difference TYPE zint_txbr_doctype VALUE 'RE',
        taxbr_reclas_ar     TYPE zint_txbr_doctype VALUE 'TR',
        taxbr_reclas_ap     TYPE zint_txbr_doctype VALUE 'TP',
      END OF co_doc_type,

      BEGIN OF co_tariff_type,
        markup                 TYPE zint_tariff_type VALUE '01',
        grossup_basis          TYPE zint_tariff_type VALUE '02',
        grossup_margin         TYPE zint_tariff_type VALUE '03',
        late_payment_intereset TYPE zint_tariff_type VALUE '04',
        provider_grossup       TYPE zint_tariff_type VALUE '05',
        basis                  TYPE zint_tariff_type VALUE '06',
        withholding            TYPE zint_tariff_type VALUE '91',
        withgolding_prov       TYPE zint_tariff_type VALUE '92',
      END OF co_tariff_type,

      BEGIN OF co_operation_type,
        local   TYPE zint_operation_type VALUE 'L',
        foreign TYPE zint_operation_type VALUE 'F',
      END OF co_operation_type.


    TYPES: BEGIN OF ty_data,
             validfrom            TYPE zi_intercoglacctdetermination-validfrom,
             validto              TYPE zi_intercoglacctdetermination-validto,
             doctype              TYPE zi_intercoglacctdetermination-doctype,
             providercompanycode  TYPE zi_intercoglacctdetermination-providercompanycode,
             recipientcompanycode TYPE zi_intercoglacctdetermination-recipientcompanycode,
             product              TYPE zi_intercoglacctdetermination-product,
             department           TYPE zi_intercoglacctdetermination-department,
             pandlid              TYPE zi_intercoglacctdetermination-pandlid,
             tarifftype           TYPE zi_intercoglacctdetermination-tarifftype,
             operationtype        TYPE zi_intercoglacctdetermination-operationtype,
             glaccount1           TYPE zi_intercoglacctdetermination-glaccount1,
             glaccount2           TYPE zi_intercoglacctdetermination-glaccount2,
           END OF ty_data,

           BEGIN OF ty_glaccounts,
             glaccount1 TYPE zi_intercoglacctdetermination-glaccount1,
             glaccount2 TYPE zi_intercoglacctdetermination-glaccount2,
           END OF ty_glaccounts.




    DATA data TYPE TABLE OF ty_data READ-ONLY.

    METHODS constructor
      IMPORTING
        i_valid_at              TYPE sy-datum DEFAULT sy-datum
        i_doctype               TYPE zint_txbr_doctype
        i_provider_company_code TYPE bukrs
        i_product               TYPE matnr.

    METHODS get
      IMPORTING
                i_tarifftype           TYPE zi_intercoglacctdetermination-tarifftype OPTIONAL
                i_recipientcompanycode TYPE zi_intercoglacctdetermination-recipientcompanycode OPTIONAL
                i_department           TYPE zi_intercoglacctdetermination-department OPTIONAL
                i_pandlid              TYPE zi_intercoglacctdetermination-pandlid OPTIONAL
                i_operationtype        TYPE zi_intercoglacctdetermination-operationtype OPTIONAL
      RETURNING VALUE(result)          TYPE ty_glaccounts.



ENDCLASS.



CLASS zcl_interco_doc_glaccount IMPLEMENTATION.

  METHOD constructor.

    SELECT validfrom, validto, doctype, providercompanycode, recipientcompanycode, product, department, pandlid, tarifftype, operationtype, glaccount1, glaccount2 FROM zi_intercoglacctdetermination
      WHERE validfrom <= @i_valid_at
        AND validto >= @i_valid_at
        AND providercompanycode = @i_provider_company_code
        AND doctype = @i_doctype
        AND product = @i_product
        AND isdeleted IS INITIAL
              INTO TABLE @data.

  ENDMETHOD.

  METHOD get.

    DATA range_department TYPE RANGE OF zi_intercoglacctdetermination-department.
    DATA range_recipient_company_code TYPE RANGE OF zi_intercoglacctdetermination-recipientcompanycode.
    DATA range_pandlid TYPE RANGE OF zi_intercoglacctdetermination-pandlid.
    DATA range_operationtype TYPE RANGE OF zi_intercoglacctdetermination-operationtype.
    DATA range_tarifftype TYPE RANGE OF zi_intercoglacctdetermination-tarifftype.

    IF i_department IS SUPPLIED.
      range_department = VALUE #( sign = 'I' option = 'EQ'
                                  ( low = space )
                                  ( low = i_department ) ).
    ENDIF.

    IF i_recipientcompanycode IS SUPPLIED.
      range_recipient_company_code = VALUE #( sign = 'I' option = 'EQ'
                                  ( low = space )
                                  ( low = i_recipientcompanycode ) ).
    ENDIF.

    IF i_pandlid IS SUPPLIED.
      range_pandlid = VALUE #( sign = 'I' option = 'EQ'
                               ( low = space )
                               ( low = i_pandlid ) ).
    ENDIF.

    IF i_operationtype IS SUPPLIED.
      range_operationtype = VALUE #( sign = 'I' option = 'EQ'
                               ( low = space )
                               ( low = i_operationtype ) ).
    ENDIF.

    IF i_tarifftype IS SUPPLIED.
      range_tarifftype = VALUE #( sign = 'I' option = 'EQ'
                               ( low = space )
                               ( low = i_tarifftype ) ).
    ENDIF.

    SELECT SINGLE data~glaccount1, data~glaccount2 FROM @data AS data
    WHERE tarifftype IN @range_tarifftype
    AND department IN @range_department
    AND pandlid IN @range_pandlid
    AND operationtype IN @range_operationtype
    AND recipientcompanycode IN @range_recipient_company_code
    INTO @result.

    IF sy-subrc <> 0.
      " TODO: handle error
    ENDIF.

  ENDMETHOD.
ENDCLASS.
