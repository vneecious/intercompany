CLASS lsc_zi_intercocompanyrelprodr DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_intercocompanyrelprodr IMPLEMENTATION.
  METHOD save_modified.
    DATA lt_md003 TYPE STANDARD TABLE OF zint_a_md003.

    DATA(lref_cdo) = NEW zcl_interco_cdo( ).
    IF create-zi_intercocompanyrelprodrate IS NOT INITIAL.
      lt_md003 = CORRESPONDING #( create-zi_intercocompanyrelprodrate ).
      SORT lt_md003 BY uuid.

      SELECT client, uuid, providercompanycode, providercompanycodeName, recipientcompanycode, recipientcompanyName, "#EC CI_FAE_NO_LINES_OK
             product, productName, payment_type, validfrom, validto, markup, grossingupbase, grossingupmargin, latepaymentinterest,
             providergrossingup, fixedrate, taxcredit, isdeleted, authorizationgroup, createdat, createdby, lastchangedat
        FROM zint_a_md003
        FOR ALL ENTRIES IN @lt_md003
        WHERE uuid = @lt_md003-uuid
        INTO TABLE @DATA(lt_md003_orig).
      IF sy-subrc = 0.
        SORT lt_md003_orig BY uuid.
      ENDIF.

      LOOP AT lt_md003 ASSIGNING FIELD-SYMBOL(<fs_md003>).
        READ TABLE lt_md003_orig INTO DATA(ls_data_old) WITH KEY uuid = <fs_md003>-uuid BINARY SEARCH.

        lref_cdo->write_md003_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-create
                                              is_data     = <fs_md003>
                                              is_data_old = ls_data_old
                                    " TODO: variable is assigned but never used (ABAP cleaner)
                                    IMPORTING ev_error    = DATA(lv_error) ).

        CLEAR ls_data_old.
      ENDLOOP.

    ENDIF.
    IF update-zi_intercocompanyrelprodrate IS NOT INITIAL.
      lt_md003 = CORRESPONDING #( update-zi_intercocompanyrelprodrate ).
      SORT lt_md003 BY uuid.

      SELECT client, uuid, providercompanycode, providercompanycodeName, recipientcompanycode, recipientcompanyName, "#EC CI_FAE_NO_LINES_OK
             product, productName, payment_type, validfrom, validto, markup, grossingupbase, grossingupmargin, latepaymentinterest,
             providergrossingup,fixedrate, taxcredit, isdeleted, authorizationgroup, createdat, createdby, lastchangedat
        FROM zint_a_md003
        FOR ALL ENTRIES IN @lt_md003
        WHERE uuid = @lt_md003-uuid
        INTO TABLE @lt_md003_orig.
      IF sy-subrc = 0.
        SORT lt_md003_orig BY uuid.
      ENDIF.

      LOOP AT lt_md003 ASSIGNING <fs_md003>.
        READ TABLE lt_md003_orig INTO ls_data_old WITH KEY uuid = <fs_md003>-uuid BINARY SEARCH.

        lref_cdo->write_md003_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-update
                                              is_data     = <fs_md003>
                                              is_data_old = ls_data_old
                                    IMPORTING ev_error    = lv_error ).
        CLEAR ls_data_old.
      ENDLOOP.
    ENDIF.

    IF delete-zi_intercocompanyrelprodrate IS NOT INITIAL.
      lt_md003 = CORRESPONDING #( delete-zi_intercocompanyrelprodrate ).
      SORT lt_md003 BY uuid.

      SELECT client, uuid, providercompanycode, providercompanycodeName, recipientcompanycode, recipientcompanyName, "#EC CI_FAE_NO_LINES_OK
             product, productName, payment_type, validfrom, validto, markup, grossingupbase, grossingupmargin, latepaymentinterest,
             providergrossingup,fixedrate, taxcredit, isdeleted, authorizationgroup, createdat, createdby, lastchangedat
        FROM zint_a_md003
        FOR ALL ENTRIES IN @lt_md003
        WHERE uuid = @lt_md003-uuid
        INTO TABLE @lt_md003_orig.
      IF sy-subrc = 0.
        SORT lt_md003_orig BY uuid.
      ENDIF.

      LOOP AT lt_md003 ASSIGNING <fs_md003>.
        READ TABLE lt_md003_orig INTO ls_data_old WITH KEY uuid = <fs_md003>-uuid BINARY SEARCH.

        lref_cdo->write_md003_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-delete
                                              is_data     = <fs_md003>
                                              is_data_old = ls_data_old
                                    IMPORTING ev_error    = lv_error ).
        CLEAR ls_data_old.
      ENDLOOP.

    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_ZI_INTERCOCOMPANYRELPRODRA DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_intercocompanyrelprodrate RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_intercocompanyrelprodrate RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_intercocompanyrelprodrate RESULT result.
    METHODS validatedata FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodrate~validatedata.
    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE zi_intercocompanyrelprodrate.
    METHODS zetdelete FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelprodrate~zetdelete RESULT result.
    METHODS getcompanynames FOR DETERMINE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodrate~getcompanynames.

    METHODS getproductname FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_intercocompanyrelprodrate~getproductname.
    METHODS validatedates FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodrate~validatedates.
    METHODS validatemandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodrate~validatemandatory.
    METHODS validatecompany FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodrate~validatecompany.

    METHODS validateproduct FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodrate~validateproduct.
    METHODS detervalidfrom FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_intercocompanyrelprodrate~detervalidfrom.

    METHODS detervalidto FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_intercocompanyrelprodrate~detervalidto.
ENDCLASS.

CLASS lhc_ZI_INTERCOCOMPANYRELPRODRA IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
    "    DATA(lo_oauth) = NEW zcl_check_interco_oauth( sy-uname  ).
    "
    "    " Agregar logica de validacion de roles.
    "    IF requested_authorizations-%create = if_abap_behv=>mk-on.
    "      IF lo_oauth->check_user( ) = abap_True.
    "
    "      ENDIF.
    "    ENDIF.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '01'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%create = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '02'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%update = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '06'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%delete = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-Edit = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '02'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%action-Edit = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                    ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-ZetDelete = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '06'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%action-ZetDelete = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                         ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
   ENTITY zi_intercocompanyrelprodrate ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_prodrate).
    LOOP AT lt_prodrate ASSIGNING FIELD-SYMBOL(<fs_rate>).

      APPEND VALUE #(
           %tky = <fs_rate>-%tky
           %delete  = COND #( WHEN  <fs_rate>-Isdeleted = 'X' THEN if_abap_behv=>fc-o-enabled

                                                            ELSE if_abap_behv=>fc-o-disabled  )
                     ) TO result.
    ENDLOOP.

  ENDMETHOD.

  METHOD precheck_delete.
    DATA lv_attr1 TYPE zint_dte_msgv.

    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate
         FIELDS ( uuid Isdeleted )
         WITH VALUE #( FOR ls_key IN keys
                       ( %key = ls_key-%key
                         %tky = ls_key-%tky ) )
         RESULT DATA(lt_result)
         FAILED failed.
    "
    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<FS_result>).
      CHECK <FS_result>-Isdeleted = abap_false.
      READ TABLE keys REFERENCE INTO DATA(ls_keyaux) WITH KEY Uuid = <fs_result>-Uuid. "#EC CI_STDSEQ

      lv_Attr1 = <fs_result>-Uuid.
      "
      APPEND VALUE #( %key = ls_keyaux->%key ) TO failed-zi_intercocompanyrelprodrate.
      APPEND VALUE #( %key = ls_keyaux->%key
                      %msg = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                             textid   = zintercocx=>row_deleted
                                             iv_attr1 = lv_attr1 ) )
             TO reported-zi_intercocompanyrelprodrate.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateData.
    DATA lt_prodrate TYPE TABLE OF zi_intercocompanyrelprodrate.
    DATA lv_attr1    TYPE zint_dte_msgv.

    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(prodrate).

    READ TABLE prodrate  REFERENCE INTO DATA(ls_prodrate2) INDEX 1.

    lt_prodrate = CORRESPONDING #( prodrate ).

    READ TABLE lt_prodrate INTO DATA(ls_prodrate) INDEX 1.

    IF ls_prodrate IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE Id, ProviderCompanyCode, RecipientCompanyCode, Product  FROM ZC_IntercoCompanyRelProduct
        WHERE ProviderCompanyCode = @ls_prodrate-Providercompanycode
          AND RecipientCompanyCode = @ls_prodrate-Recipientcompanycode
          AND Product = @ls_prodrate-Product
*{ Insert Mod 001 RAR - Validar existencia
*          AND ( ( validto BETWEEN  @ls_prodrate-validfrom AND @ls_prodrate-validto )
*             OR ( validfrom BETWEEN @ls_prodrate-validfrom AND @ls_prodrate-validto ) )
          AND validto              >= @ls_prodrate-validto
          AND validfrom            <= @ls_prodrate-ValidFrom
*} End Mod 001
          AND isdeleted = @abap_false
          INTO @DATA(ls_CompanyRelProduct_aux).

    IF ls_CompanyRelProduct_aux IS INITIAL.
      APPEND VALUE #( %tky = ls_prodrate2->%tky ) TO failed-zi_intercocompanyrelprodrate.
      APPEND VALUE #( %key = ls_prodrate2->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '027' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodrate.
    ENDIF.

*    SELECT SINGLE uuid, providercompanycode, recipientcompanycode, product
*      FROM zint_a_md003
*      WHERE Uuid                 NE @ls_prodrate-Uuid
*        AND Providercompanycode  EQ @ls_prodrate-Providercompanycode
*        AND Recipientcompanycode EQ @ls_prodrate-Recipientcompanycode
*        AND Product              EQ @ls_prodrate-Product
*        AND ( validto            LE @ls_prodrate-Validfrom OR validfrom LE @ls_prodrate-Validto )
*        AND isdeleted EQ @abap_false
*      INTO @DATA(ls_duplicate).

    " CÓDIGO PROPUESTO (Claude)
    SELECT SINGLE uuid, providercompanycode, recipientcompanycode, product
    FROM zint_a_md003
    WHERE Uuid NE @ls_prodrate-Uuid
    AND Providercompanycode EQ @ls_prodrate-Providercompanycode
    AND Recipientcompanycode EQ @ls_prodrate-Recipientcompanycode
    AND Product EQ @ls_prodrate-Product
    AND validfrom < @ls_prodrate-Validto " existente empieza antes de que
    AND validto > @ls_prodrate-Validfrom " existente termina después de que
    AND isdeleted EQ @abap_false " el nuevo comience
    INTO @DATA(ls_duplicate).

    IF sy-subrc = 0.
      APPEND VALUE #( %tky = ls_prodrate2->%tky ) TO failed-zi_intercocompanyrelprodrate.

      lv_attr1 = ls_duplicate-Uuid.

      APPEND VALUE #( %tky        = ls_prodrate2->%tky
                      %state_area = 'VALIDATE_DUPLICATE'
                      %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                                    textid   = zintercocx=>duplicate_prodrate
                                                    iv_attr1 = lv_attr1  ) )
             TO reported-zi_intercocompanyrelprodrate.
    ENDIF.
  ENDMETHOD.


  METHOD validateDates.
    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
        ENTITY zi_intercocompanyrelprodrate
        FIELDS ( Validfrom Validto ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_prodrate).

    LOOP AT lt_prodrate INTO DATA(ls_prodrate).

      IF ls_prodrate-Validfrom IS NOT INITIAL AND ls_prodrate-Validto IS NOT INITIAL.
        IF ls_prodrate-validfrom GT ls_prodrate-validto.
          APPEND VALUE #( %tky = ls_prodrate-%tky ) TO failed-zi_intercocompanyrelprodrate.
          APPEND VALUE #( %tky = ls_prodrate-%tky
                          %msg = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                                        textid   = zintercocx=>wrong_dates )
                         ) TO reported-zi_intercocompanyrelprodrate .
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateMandatory.
    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
        ENTITY zi_intercocompanyrelprodrate
        FIELDS ( Validfrom Validto ) WITH CORRESPONDING #( keys )
        RESULT DATA(lt_prodrate).

    LOOP AT lt_prodrate INTO DATA(ls_prodrate).

      IF ls_prodrate-Product IS INITIAL OR  ls_prodrate-Providercompanycode  IS INITIAL OR
      ls_prodrate-Recipientcompanycode IS INITIAL OR ls_prodrate-Validfrom IS INITIAL OR ls_prodrate-validfrom IS INITIAL.
        APPEND VALUE #( %key = ls_prodrate-%key ) TO failed-zi_intercocompanyrelprodrate.


        APPEND VALUE #( %key        = ls_prodrate-%key
                        %state_area = 'WRONG_MANDATORIES'
                        %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                                      textid   = zintercocx=>wrong_mandatories ) )
               TO reported-zi_intercocompanyrelprodrate.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateCompany.
    DATA lv_attr1 TYPE zint_dte_msgv.

    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate
         FIELDS ( Validfrom Validto ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_prodrate).

    DATA(lt_rates_aux) = lt_prodrate[].
    SORT lt_rates_aux BY Providercompanycode.
    DELETE ADJACENT DUPLICATES FROM lt_rates_aux COMPARING Providercompanycode.

    SELECT FROM ZI_IntercoCompanyCode
      FIELDS CompanyCode                      "#EC CI_FAE_LINES_ENSURED
      FOR ALL ENTRIES IN @lt_rates_aux
      WHERE CompanyCode = @lt_rates_aux-Providercompanycode
      INTO TABLE @DATA(lt_company).
    IF sy-subrc = 0.
      SORT lt_company BY CompanyCode.
      DELETE ADJACENT DUPLICATES FROM lt_company COMPARING CompanyCode.
    ENDIF.

    lt_rates_aux = lt_prodrate[].
    SORT lt_rates_aux BY Recipientcompanycode.
    DELETE ADJACENT DUPLICATES FROM lt_rates_aux COMPARING Recipientcompanycode.

    SELECT FROM ZI_IntercoCompanyCode
      FIELDS CompanyCode                      "#EC CI_FAE_LINES_ENSURED
      FOR ALL ENTRIES IN @lt_rates_aux
      WHERE CompanyCode = @lt_rates_aux-Recipientcompanycode
      APPENDING TABLE @lt_Company.
    IF sy-subrc = 0.
      SORT lt_company BY CompanyCode.
      DELETE ADJACENT DUPLICATES FROM lt_company COMPARING CompanyCode.
    ENDIF.

    LOOP AT lt_prodrate INTO DATA(ls_prodrate).
      IF ls_prodrate-Recipientcompanycode IS NOT INITIAL.
        READ TABLE lt_company TRANSPORTING NO FIELDS WITH KEY CompanyCode = ls_prodrate-Recipientcompanycode BINARY SEARCH.
        IF sy-subrc <> 0.
          APPEND VALUE #( %key = ls_prodrate-%key ) TO failed-zi_intercocompanyrelprodrate.

          lv_attr1 = ls_prodrate-Recipientcompanycode.

          APPEND VALUE #( %key        = ls_prodrate-%key
                          %state_area = 'WRONG_COMPANY'
                          %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                                        textid   = zintercocx=>wrong_company
                                                        iv_attr1 = lv_attr1 ) )

                 TO reported-zi_intercocompanyrelprodrate.
          EXIT.
        ENDIF.
      ENDIF.
      IF ls_prodrate-Providercompanycode IS NOT INITIAL.
        READ TABLE lt_company TRANSPORTING NO FIELDS WITH KEY CompanyCode = ls_prodrate-Providercompanycode BINARY SEARCH.
        IF sy-subrc <> 0.
          APPEND VALUE #( %key = ls_prodrate-%key ) TO failed-zi_intercocompanyrelprodrate.

          lv_attr1 = ls_prodrate-Providercompanycode.

          APPEND VALUE #( %key        = ls_prodrate-%key
                          %state_area = 'WRONG_COMPANY'
                          %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                                        textid   = zintercocx=>wrong_company
                                                        iv_attr1 = lv_attr1 ) )
                 TO reported-zi_intercocompanyrelprodrate.
          EXIT.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateProduct.
    DATA lv_attr1 TYPE zint_dte_msgv.

    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate
         FIELDS ( Product ) WITH CORRESPONDING #( keys )
         RESULT DATA(lt_prodrate).

    DATA(lt_rates_aux) = lt_prodrate[].
    SORT lt_rates_aux BY Product.
    DELETE ADJACENT DUPLICATES FROM lt_rates_aux COMPARING product.

    SELECT FROM ZI_IntercoProduct
      FIELDS Product, ProductName
      FOR ALL ENTRIES IN @lt_rates_aux
      WHERE Product = @lt_rates_aux-Product
      INTO TABLE @DATA(lt_products).
    IF sy-subrc = 0.
      SORT lt_products BY Product.
    ENDIF.

    LOOP AT lt_prodrate ASSIGNING FIELD-SYMBOL(<fs_rate>).
      READ TABLE lt_products TRANSPORTING NO FIELDS WITH KEY Product = <fs_rate>-Product BINARY SEARCH.
      IF sy-subrc <> 0.
        APPEND VALUE #( %key = <fs_rate>-%key ) TO failed-zi_intercocompanyrelprodrate.

        lv_attr1 = <fs_rate>-Product.

        APPEND VALUE #( %key        = <fs_rate>-%key
                        %state_area = 'WRONG_PRODUCT'
                        %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
                                                      textid   = zintercocx=>wrong_product
                                                      iv_attr1 = lv_attr1 ) )
               TO reported-zi_intercocompanyrelprodrate.

        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zetdelete.
    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_CompanyRelProdRate).

    READ TABLE lt_CompanyRelProdRate ASSIGNING FIELD-SYMBOL(<fs_relprod>) INDEX 1.

    IF <fs_relprod>-IsDeleted = abap_true.
      <fs_relprod>-IsDeleted = abap_false.
    ELSE.
      <fs_relprod>-IsDeleted = abap_true.
    ENDIF.

    MODIFY ENTITIES OF ZI_IntercoCompanyRelProdRate IN LOCAL MODE
           ENTITY ZI_IntercoCompanyRelProdRate
           UPDATE FIELDS ( Isdeleted )
           WITH CORRESPONDING #( lt_companyrelprodrate )
           MAPPED mapped
           FAILED failed
           REPORTED reported.

    READ ENTITIES OF ZI_IntercoCompanyRelProdRate IN LOCAL MODE
    ENTITY zi_intercocompanyrelprodrate ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result) .

    result = VALUE #( FOR <fs> IN lt_result ( %tky = <fs>-%tky %param = <fs> ) ) .
  ENDMETHOD.

*  METHOD precheck_create.
**    DATA lv_attr1    TYPE zint_dte_msgv.
**    DATA lv_attr2    TYPE zint_dte_msgv.
**    DATA lv_attr3    TYPE zint_dte_msgv.
**
**    READ TABLE entities ASSIGNING FIELD-SYMBOL(<fs_entity>) INDEX 1.
**    IF <fs_entity> IS ASSIGNED.
**
**
**      IF  <fs_entity>-%is_draft NE if_abap_behv=>mk-on.
**
**        SELECT SINGLE product  FROM ZI_IntercoCompanyRelProduct
**          WHERE product              = @<fs_entity>-Product
**            AND providercompanycode  = @<fs_entity>-Providercompanycode
**            AND RecipientCompanyCode = @<fs_entity>-Recipientcompanycode
**          INTO @DATA(ls_product).
**        IF ls_product IS INITIAL.
**          APPEND VALUE #( %key = <fs_entity>-%key ) TO failed-zi_intercocompanyrelprodrate.
**
**          lv_attr1 = <fs_entity>-Product.
**          lv_attr2 = <fs_entity>-Providercompanycode.
**          lv_attr3 = <fs_entity>-Recipientcompanycode.
**
**          APPEND VALUE #( %key        = <fs_entity>-%key
**                          %state_area = 'WRONG_PRODUCTCOMPANY'
**                          %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
**                                                        textid   = zintercocx=>wrong_productCompany
**                                                        iv_attr1 = lv_attr1
**                                                        iv_attr2 = lv_attr2
**                                                        iv_attr3 = lv_attr3 ) )
**                 TO reported-zi_intercocompanyrelprodrate.
**
**        ENDIF.
**      ENDIF.
**    ENDIF.
*  ENDMETHOD.

*  METHOD precheck_update.
*
**    DATA lv_attr1    TYPE zint_dte_msgv.
**    DATA lv_attr2    TYPE zint_dte_msgv.
**    DATA lv_attr3    TYPE zint_dte_msgv.
**
**    READ TABLE entities ASSIGNING FIELD-SYMBOL(<fs_entity>) INDEX 1.
**    IF <fs_entity> IS ASSIGNED.
**
**      IF <fs_entity>-%control-Isdeleted NE '01' AND <fs_entity>-%is_draft NE if_abap_behv=>mk-on.
**
**        SELECT SINGLE product  FROM ZI_IntercoCompanyRelProduct
**          WHERE product              = @<fs_entity>-Product
**            AND providercompanycode  = @<fs_entity>-Providercompanycode
**            AND RecipientCompanyCode = @<fs_entity>-Recipientcompanycode
**          INTO @DATA(ls_product).
**        IF ls_product IS INITIAL.
**          APPEND VALUE #( %tky = <fs_entity>-%tky ) TO failed-zi_intercocompanyrelprodrate.
**
**          lv_attr1 = <fs_entity>-Product.
**          lv_attr2 = <fs_entity>-Providercompanycode.
**          lv_attr3 = <fs_entity>-Recipientcompanycode.
**
**          APPEND VALUE #( %tky        = <fs_entity>-%tky
**                          %state_area = 'WRONG_PRODUCTCOMPANY'
**                          %msg        = NEW zintercocx( severity = if_abap_behv_message=>severity-error
**                                                        textid   = zintercocx=>wrong_productCompany
**                                                        iv_attr1 = lv_attr1
**                                                        iv_attr2 = lv_attr2
**                                                        iv_attr3 = lv_attr3 ) )
**                 TO reported-zi_intercocompanyrelprodrate.
**
**        ENDIF.
**      ENDIF.
**
**    ENDIF.
*  ENDMETHOD.

  METHOD GetCompanyNames.
    DATA: lt_rates TYPE TABLE FOR READ RESULT zi_intercocompanyrelprodrate.
    DATA: lt_update TYPE TABLE FOR UPDATE zi_intercocompanyrelprodrate.
    DATA: lv_langu TYPE sy-langu VALUE 'S'.



    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
    ENTITY zi_intercocompanyrelprodrate FIELDS ( uuid Recipientcompanycode Providercompanycode )
    WITH CORRESPONDING #( keys ) RESULT lt_rates.

    IF lt_rates[] IS NOT INITIAL.

      DATA(lt_rates_aux) = lt_rates[].
      SORT lt_rates_aux BY Providercompanycode.
      DELETE ADJACENT DUPLICATES FROM lt_rates_aux COMPARING Providercompanycode.

      SELECT FROM  ZI_IntercoCompanyCode FIELDS CompanyCode, CompanyCodeName "#EC CI_FAE_LINES_ENSURED
      FOR ALL ENTRIES IN @lt_rates_aux
      WHERE CompanyCode = @lt_rates_aux-Providercompanycode
      AND Language = @lv_langu
      INTO TABLE @DATA(lt_provCompname).
      IF sy-subrc EQ 0.
        SORT lt_provcompname BY CompanyCode.
      ENDIF.

      lt_rates_aux = lt_rates[].
      SORT lt_rates_aux BY Recipientcompanycode.
      DELETE ADJACENT DUPLICATES FROM lt_rates_aux COMPARING Recipientcompanycode.

      SELECT FROM  ZI_IntercoCompanyCode FIELDS CompanyCode, CompanyCodeName "#EC CI_FAE_LINES_ENSURED
      FOR ALL ENTRIES IN @lt_rates_aux
      WHERE CompanyCode = @lt_rates_aux-Recipientcompanycode
      AND Language = @lv_langu
      INTO TABLE @DATA(lt_recipCompname).
      IF sy-subrc EQ 0.
        SORT lt_recipCompname BY CompanyCode.
      ENDIF.

      LOOP AT lt_rates ASSIGNING FIELD-SYMBOL(<fs_rate>).
        READ TABLE lt_provCompname INTO DATA(ls_pcompname) WITH KEY CompanyCode = <fs_rate>-Providercompanycode BINARY SEARCH.
        IF sy-subrc = 0.
          <fs_rate>-ProvidercompanycodeName = ls_pcompname-CompanyCodeName.
        ENDIF.

        READ TABLE lt_recipCompname INTO DATA(ls_rcompname) WITH KEY CompanyCode = <fs_rate>-Recipientcompanycode  BINARY SEARCH.
        IF sy-subrc = 0.
          <fs_rate>-RecipientCompanyName  = ls_rcompname-CompanyCodeName.
        ENDIF.

        CLEAR: ls_pcompname, ls_rcompname.
      ENDLOOP.

      lt_update = CORRESPONDING #( lt_rates ).


      MODIFY ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
             ENTITY zi_intercocompanyrelprodrate UPDATE FIELDS ( ProvidercompanycodeName RecipientCompanyName )
             WITH CORRESPONDING #( lt_update  )
             REPORTED DATA(lt_reported).

      reported-zi_intercocompanyrelprodrate = CORRESPONDING #( lt_reported-zi_intercocompanyrelprodrate  ).

    ENDIF.
  ENDMETHOD.

  METHOD GetProductName.
    DATA lt_rates  TYPE TABLE FOR READ RESULT zi_intercocompanyrelprodrate.
    DATA lt_update TYPE TABLE FOR UPDATE zi_intercocompanyrelprodrate.

    "
    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate FIELDS ( uuid Recipientcompanycode Providercompanycode )
         WITH CORRESPONDING #( keys ) RESULT lt_rates.

    DATA(lt_rates_aux) = lt_rates[].
    SORT lt_rates_aux BY Product.
    DELETE ADJACENT DUPLICATES FROM lt_rates_aux COMPARING product.

    SELECT FROM ZI_IntercoProduct
      FIELDS Product, ProductName
      FOR ALL ENTRIES IN @lt_rates_aux
      WHERE Product = @lt_rates_aux-Product
      INTO TABLE @DATA(lt_products).
    IF sy-subrc = 0.
      SORT lt_products BY Product.
    ENDIF.

    LOOP AT lt_rates ASSIGNING FIELD-SYMBOL(<fs_rate>).
      READ TABLE lt_products INTO DATA(ls_product) WITH KEY Product = <fs_rate>-Product BINARY SEARCH.
      IF sy-subrc = 0.
        <fs_rate>-ProductName = ls_product-ProductName.
      ENDIF.
    ENDLOOP.

    lt_update = CORRESPONDING #( lt_rates ).


    MODIFY ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
           ENTITY zi_intercocompanyrelprodrate UPDATE FIELDS ( ProductName )
           WITH CORRESPONDING #( lt_update  )
           REPORTED DATA(lt_reported).

    reported-zi_intercocompanyrelprodrate = CORRESPONDING #( lt_reported-zi_intercocompanyrelprodrate  ).
  ENDMETHOD.

  METHOD DeterValidFrom.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).

    IF <fs_key> IS NOT ASSIGNED.
      RETURN.
    ENDIF.
    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate
         FIELDS ( ValidFrom ValidTo )
         WITH CORRESPONDING #( keys )
         RESULT DATA(lt_companyProdrate).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN lt_companyProdrate[ 1 ] TO FIELD-SYMBOL(<fs_prod>).
    IF sy-subrc = 0.
      IF <fs_prod>-ValidFrom+6(2) <> '01' OR <fs_prod>-ValidTo IS INITIAL.
        <fs_prod>-ValidFrom+6(2) = '01'.
        IF <fs_prod>-ValidTo <> '99991231'.
*          get_last_day_of_month( EXPORTING day_in            = <fs_prod>-ValidFrom
*                                 IMPORTING last_day_of_month = <fs_prod>-ValidTo ).
          zcl_amdp_interco_relationships=>get_last_day( EXPORTING iv_date = <fs_prod>-ValidFrom
                                                        IMPORTING ev_date = <fs_prod>-ValidTo ).
        ENDIF.

        UNASSIGN <fs_prod>.

        MODIFY ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
               ENTITY zi_intercocompanyrelprodrate
               UPDATE FIELDS ( ValidFrom ValidTo )
               WITH CORRESPONDING #( lt_companyProdrate ).
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD DeterValidTo.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).

    IF <fs_key> IS NOT ASSIGNED.
      RETURN.
    ENDIF.
    READ ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodrate
         FIELDS ( ValidTo )
         WITH CORRESPONDING #( keys )
         RESULT DATA(lt_companyProdrate).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN lt_companyProdrate[ 1 ] TO FIELD-SYMBOL(<fs_prod>).
    IF sy-subrc = 0.
      IF <fs_prod>-ValidTo <> '99991231'.
*        get_last_day_of_month( EXPORTING day_in            = <fs_prod>-ValidTo
*                               IMPORTING last_day_of_month = DATA(lv_validTo) ).
        zcl_amdp_interco_relationships=>get_last_day( EXPORTING iv_date = <fs_prod>-ValidTo
                                                      IMPORTING ev_date = DATA(lv_validTo) ).
        IF lv_validTo <> <fs_prod>-ValidTo.
          <fs_prod>-ValidTo = lv_validTo.
          MODIFY ENTITIES OF zi_intercocompanyrelprodrate IN LOCAL MODE
                 ENTITY zi_intercocompanyrelprodrate
                 UPDATE FIELDS ( ValidTo )
                 WITH CORRESPONDING #( lt_companyProdrate ).
        ENDIF.
      ENDIF.

    ENDIF.
  ENDMETHOD.

ENDCLASS.
