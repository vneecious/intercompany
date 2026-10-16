CLASS lsc_zi_intercocompanyrelprodbi DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_intercocompanyrelprodbi IMPLEMENTATION.
  METHOD save_modified.
    DATA lt_md002 TYPE STANDARD TABLE OF zint_a_md002.

    DATA(lref_cdo) = NEW zcl_interco_cdo( ).
    IF create-zi_intercocompanyrelprodbill IS NOT INITIAL.
      lt_md002 = CORRESPONDING #( create-zi_intercocompanyrelprodbill ).

      SORT lt_md002 BY id.

      SELECT client, id, validfrom, validto, product, providercompanycode, pandlid, profitcenter, costcentersubarea,
             costcenterallocation, isnotbilable, isdeleted, zindex, createdat, createdby, lastchangedat
        FROM zint_a_md002
        FOR ALL ENTRIES IN @lt_md002
        WHERE id = @lt_md002-id
        INTO TABLE @DATA(lt_md002_orig).
      IF sy-subrc = 0.
        SORT lt_md002_orig BY id.
      ENDIF.

      LOOP AT lt_md002 ASSIGNING FIELD-SYMBOL(<fs_md002>).
        READ TABLE lt_md002_orig INTO DATA(ls_data_old) WITH KEY id = <fs_md002>-id BINARY SEARCH.

        lref_cdo->write_md002_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-create
                                              is_data     = <fs_md002>
                                              is_data_old = ls_data_old
                                    " TODO: variable is assigned but never used (ABAP cleaner)
                                    IMPORTING ev_error    = DATA(lv_error) ).
      ENDLOOP.
      lref_cdo->save_md002( iv_chin = lref_cdo->cs_chdo-create
                            it_data = lt_md002 ).
    ENDIF.
    IF update-zi_intercocompanyrelprodbill IS NOT INITIAL.
      lt_md002 = CORRESPONDING #( update-zi_intercocompanyrelprodbill ).
      SORT lt_md002 BY id.

      SELECT client, id, validfrom, validto, product, providercompanycode, pandlid, profitcenter, costcentersubarea,
             costcenterallocation, isnotbilable, isdeleted, zindex, createdat, createdby, lastchangedat
        FROM zint_a_md002
        FOR ALL ENTRIES IN @lt_md002
        WHERE id = @lt_md002-id
        INTO TABLE @lt_md002_orig.
      IF sy-subrc = 0.
        SORT lt_md002_orig BY id.
      ENDIF.

      LOOP AT lt_md002 ASSIGNING <fs_md002>.
        READ TABLE lt_md002_orig INTO ls_data_old WITH KEY id = <fs_md002>-id BINARY SEARCH.

        lref_cdo->write_md002_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-update
                                              is_data     = <fs_md002>
                                              is_data_old = ls_data_old
                                    IMPORTING ev_error    = lv_error ).
      ENDLOOP.
      lref_cdo->save_md002( iv_chin = lref_cdo->cs_chdo-update
                            it_data = lt_md002 ).
    ENDIF.
    IF delete-zi_intercocompanyrelprodbill IS NOT INITIAL.
      lt_md002 = CORRESPONDING #( delete-zi_intercocompanyrelprodbill ).
      SORT lt_md002 BY id.

      SELECT client, id, validfrom, validto, product, providercompanycode, pandlid, profitcenter, costcentersubarea,
             costcenterallocation, isnotbilable, isdeleted, zindex, createdat, createdby, lastchangedat
        FROM zint_a_md002
        FOR ALL ENTRIES IN @lt_md002
        WHERE id = @lt_md002-id
        INTO TABLE @lt_md002_orig.
      IF sy-subrc = 0.
        SORT lt_md002_orig BY id.
      ENDIF.

      LOOP AT lt_md002 ASSIGNING <fs_md002>.
        READ TABLE lt_md002_orig INTO ls_data_old WITH KEY id = <fs_md002>-id BINARY SEARCH.

        lref_cdo->write_md002_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-delete
                                              is_data     = <fs_md002>
                                              is_data_old = ls_data_old
                                    IMPORTING ev_error    = lv_error ).
      ENDLOOP.
      lref_cdo->save_md002( iv_chin = lref_cdo->cs_chdo-delete
                            it_data = lt_md002 ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_intercocompanyrelprodbi DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_intercocompanyrelprodbill RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_intercocompanyrelprodbill RESULT result.

    " METHODS precheck FOR PRECHECK
    "  IMPORTING entities_create FOR CREATE ZI_IntercoCompanyRelProdBill
    "            entities_update FOR UPDATE ZI_IntercoCompanyRelProdBill.

    METHODS get_instance_features FOR FEATURES
      IMPORTING keys   REQUEST requested_features FOR zi_intercocompanyrelprodbill
      RESULT    result.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE zi_intercocompanyrelprodbill.

    METHODS validatedata FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodbill~validatedata.

    METHODS setdeletebbill FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelprodbill~setdeletebbill.
    METHODS getcostcenterarea FOR DETERMINE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelprodbill~getcostcenterarea.
    METHODS uploadProdBill FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelprodbill~uploadProdBill .

    "    METHODS SetCostCenterAllocation FOR DETERMINE ON SAVE
    "      IMPORTING keys FOR ZI_IntercoCompanyRelProdBill~SetCostCenterAllocation.

ENDCLASS.

CLASS lhc_zi_intercocompanyrelprodbi IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
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
    IF requested_authorizations-%action-SetDeletebBill = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '06'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%action-SetDeletebBill = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                              ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  "METHOD precheck.
  "ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_intercocompanyrelprodbill IN LOCAL MODE
      ENTITY zi_intercocompanyrelprodbill ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_compprodbill).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    IF lt_compprodbill IS NOT INITIAL.
      SELECT DISTINCT providercompanycode, product, flow FROM zc_intercocompanyrelproduct
          FOR ALL ENTRIES IN @lt_compprodbill
             WHERE providercompanycode = @lt_compprodbill-providercompanycode
              AND product = @lt_compprodbill-product
              AND isdeleted = @abap_false
              AND validfrom <= @lv_today
              AND  validto >= @lv_today
              INTO TABLE @DATA(lt_product_flow).
    ENDIF.



    LOOP AT lt_compprodbill ASSIGNING FIELD-SYMBOL(<fs_billing>).

      APPEND VALUE #(
           %tky = <fs_billing>-%tky
           %delete  = COND #( WHEN  <fs_billing>-isdeleted = 'X' THEN if_abap_behv=>fc-o-enabled

                                                            ELSE if_abap_behv=>fc-o-disabled  )
                     ) TO result.

      TRY.
          DATA(ls_product_flow) = lt_product_flow[ providercompanycode = <fs_billing>-providercompanycode product = <fs_billing>-product ].
          APPEND VALUE #(
              %tky = <fs_billing>-%tky
              %field-profitcenter  = COND #( WHEN ls_product_flow-flow = 'I'
                                      THEN if_abap_behv=>fc-f-mandatory
                                      ELSE if_abap_behv=>fc-f-read_only )
              %field-costcentersubarea  = COND #( WHEN ls_product_flow-flow = 'O'
                                      THEN if_abap_behv=>fc-f-mandatory
                                      ELSE if_abap_behv=>fc-f-read_only )
                 ) TO result.
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

    ENDLOOP.
  ENDMETHOD.

  METHOD validatedata.
    TYPES: BEGIN OF lty_allocation,
             allocation TYPE zi_intercocostcenter-Allocation,
           END OF lty_allocation.

    DATA lt_companyproductbilling TYPE TABLE OF zi_intercocompanyrelprodbill.
    DATA lt_intercocostcenter     TYPE TABLE OF ZI_IntercoCostCenterSubArea.
    DATA lt_allocation            TYPE TABLE OF lty_allocation.
    DATA lv_index                 TYPE symsg-msgv1.

    READ ENTITIES OF zi_intercocompanyrelprodbill IN LOCAL MODE
         ENTITY zi_intercocompanyrelprodbill ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_compprodbill).

    READ TABLE lt_compprodbill  REFERENCE INTO DATA(ls_compprodbill) INDEX 1.
    IF ls_compprodbill->zindex IS INITIAL.
      lt_companyproductbilling = CORRESPONDING #( lt_compprodbill ).
      READ TABLE lt_companyproductbilling REFERENCE INTO DATA(ls_companyproductbilling) INDEX 1.

      IF ls_companyproductbilling IS INITIAL OR ls_companyproductbilling->isdeleted = abap_true.
        RETURN.
      ENDIF.

      IF ls_companyproductbilling->validfrom IS INITIAL.
        APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
        APPEND VALUE #( %key = ls_compprodbill->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '012'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      ENDIF.

      IF ls_companyproductbilling->validto IS INITIAL.
        APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
        APPEND VALUE #( %key = ls_compprodbill->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '013'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      ENDIF.

      IF     ls_companyproductbilling->validfrom IS NOT INITIAL
         AND ls_companyproductbilling->validto   IS NOT INITIAL
         AND ls_companyproductbilling->validfrom >= ls_companyproductbilling->validto.
        APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
        APPEND VALUE #( %key = ls_compprodbill->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '014'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      ENDIF.

      IF ls_companyproductbilling->product IS INITIAL.
        APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
        APPEND VALUE #( %key = ls_compprodbill->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '006'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      ELSE.
        SELECT SINGLE product FROM zi_intercoproduct
          WHERE product = @ls_companyproductbilling->product
          INTO @DATA(lv_product).
        IF lv_product IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '007'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      IF ls_companyproductbilling->providercompanycode IS INITIAL.
        "  APPEND VALUE #( %key = ls_CompProdBill->%key ) TO failed-ZI_IntercoCompanyRelProdBill.
        "  APPEND VALUE #( %key = ls_CompProdBill->%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'ProviderCompanyCode Required' ) ) TO reported-ZI_IntercoCompanyRelProdBill.
      ELSE.
        SELECT SINGLE zi_intercorelationship~providercompanycode
          FROM zi_intercorelationship
          WHERE zi_intercorelationship~providercompanycode = @ls_companyproductbilling->providercompanycode
          INTO @DATA(ls_company).
        IF ls_company IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '002'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      IF ls_companyproductbilling->PandLID IS INITIAL.
        APPEND VALUE #( %key = ls_CompProdBill->%key ) TO failed-ZI_IntercoCompanyRelProdBill.
        APPEND VALUE #( %key = ls_CompProdBill->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '025'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-ZI_IntercoCompanyRelProdBill.
      ELSE.
        SELECT SINGLE PandLId FROM ZI_IntercoPandL
          WHERE PandLId = @ls_companyproductbilling->PandLID
          INTO @DATA(lv_pandl).
        IF lv_pandl IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '026'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      IF ls_companyproductbilling->profitcenter IS INITIAL.
        " Paola Rojo pide que se elimine el campo obligatorio - 26/11/2024 - Gabriel
        " APPEND VALUE #( %key = ls_CompProdBill->%key ) TO failed-ZI_IntercoCompanyRelProdBill.
        " APPEND VALUE #( %key = ls_CompProdBill->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '008' severity = if_abap_behv_message=>severity-error ) ) TO reported-ZI_IntercoCompanyRelProdBill.
      ELSE.
        SELECT SINGLE ProfitCenter FROM zi_intercoprofitcenter
          WHERE ProfitCenter = @ls_companyproductbilling->profitcenter
          INTO @DATA(lv_profitcenter).
        IF lv_profitcenter IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '009'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      "   Solicitado por Paola Rojo para eliminar la validación ProfitCenter, ya que el profitcenter IC02D ya no es obligatorio. - Gabriel Ribeiro - 02/12/204
      IF     ls_companyproductbilling->product             IS NOT INITIAL
         AND ls_companyproductbilling->providercompanycode IS NOT INITIAL.
        " AND ls_CompanyProductBilling->ProfitCenter IS NOT INITIAL.

        SELECT SINGLE * FROM zi_intercocompanyrelproduct
          WHERE product             = @ls_companyproductbilling->product
            AND providercompanycode = @ls_companyproductbilling->providercompanycode
             " AND ProfitCenter = @ls_CompanyProductBilling->ProfitCenter
          INTO @DATA(ls_companyrelproduc).
        IF ls_companyrelproduc IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '021'
                                              severity = if_abap_behv_message=>severity-error ) )
                 TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      IF ls_companyproductbilling->costcentersubarea IS INITIAL.
        APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
        APPEND VALUE #( %key = ls_compprodbill->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '022'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      ELSE.
        SELECT SINGLE * FROM zi_intercocostcentersubarea
          WHERE costcentersubarea = @ls_companyproductbilling->costcentersubarea
          INTO @DATA(ls_costcentersubarea).
        IF ls_costcentersubarea IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '023'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      IF ls_companyproductbilling->costcenterallocation IS NOT INITIAL.
        DATA(lv_costcenterallocation) = ls_companyproductbilling->costcenterallocation.
        SHIFT lv_costcenterallocation LEFT DELETING LEADING '0'.

        SELECT SINGLE * FROM zi_intercocostcenter
          WHERE allocation = @lv_costcenterallocation
          INTO @DATA(ls_costcenterallocation).
        IF ls_costcenterallocation IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '024'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

      " Validação se já existe um registro Igual
      IF ls_companyproductbilling->id IS NOT INITIAL.

        SELECT SINGLE * FROM zi_intercocompanyrelprodbill
          WHERE id                  <> @ls_companyproductbilling->id
            AND providercompanycode  = @ls_companyproductbilling->providercompanycode
            AND product              = @ls_companyproductbilling->product
            AND pandlid              = @ls_companyproductbilling->pandlid
            AND profitcenter         = @ls_companyproductbilling->profitcenter
            AND costcentersubarea    = @ls_companyproductbilling->costcentersubarea
            AND (    ( validto   BETWEEN @ls_companyproductbilling->validfrom AND @ls_companyproductbilling->validto )
                  OR ( validfrom BETWEEN @ls_companyproductbilling->validfrom AND @ls_companyproductbilling->validto ) )
            AND isdeleted = @abap_false
          INTO @DATA(ls_companyproductbilling_aux).

        IF ls_companyproductbilling_aux IS NOT INITIAL.
          APPEND VALUE #( %tky = ls_compprodbill->%tky ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '016'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.
      ENDIF.

    ELSE.
      DATA(lt_data_aux) = lt_compprodbill[].

      SORT lt_data_aux BY product.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING product.
      IF lt_data_aux IS NOT INITIAL.
        SELECT product FROM zi_intercoproduct
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE product = @lt_data_aux-product
          INTO TABLE @DATA(lt_product).
        IF sy-subrc = 0.
          SORT lt_product BY product.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_compprodbill[].

      SORT lt_data_aux BY providercompanycode.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING providercompanycode.
      IF lt_data_aux IS NOT INITIAL.
        SELECT zi_intercorelationship~providercompanycode
          FROM zi_intercorelationship
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE zi_intercorelationship~providercompanycode = @lt_data_aux-providercompanycode
          INTO TABLE @DATA(lt_company).
        IF sy-subrc = 0.
          SORT lt_company BY ProviderCompanyCode.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_compprodbill[].

      SORT lt_data_aux BY PandLID.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING PandLID.
      IF lt_data_aux IS NOT INITIAL.
        SELECT PandLId FROM ZI_IntercoPandL
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE ZI_IntercoPandL~PandLId = @lt_data_aux-PandLID
          INTO TABLE @DATA(lt_pandl).
        IF sy-subrc = 0.
          SORT lt_pandl BY PandLId.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_compprodbill[].

      SORT lt_data_aux BY ProfitCenter.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING profitcenter.
      IF lt_data_aux IS NOT INITIAL.
        SELECT ProfitCenter FROM zi_intercoprofitcenter
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE zi_intercoprofitcenter~ProfitCenter = @lt_data_aux-profitcenter
          INTO TABLE @DATA(lt_profitcenter).
        IF sy-subrc = 0.
          SORT lt_profitcenter BY ProfitCenter.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_compprodbill[].

      SORT lt_data_aux BY Product
                          ProviderCompanyCode.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING Product ProviderCompanyCode.
      IF lt_data_aux IS NOT INITIAL.
        SELECT Product, ProviderCompanyCode
          FROM zi_intercocompanyrelproduct
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE product             = @lt_data_aux-product
            AND providercompanycode = @lt_data_aux-providercompanycode
          INTO TABLE @DATA(lt_companyproduct).
        IF sy-subrc = 0.
          SORT lt_companyproduct BY Product
                                    ProviderCompanyCode.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_compprodbill[].

      SORT lt_data_aux BY CostCenterSubArea.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING CostCenterSubArea.
      IF lt_data_aux IS NOT INITIAL.
        lt_intercocostcenter = CORRESPONDING #( lt_data_aux ).

        SELECT costcentersubarea FROM zi_intercocostcentersubarea
          FOR ALL ENTRIES IN @lt_intercocostcenter
          WHERE CostCenterSubArea = @lt_intercocostcenter-CostCenterSubArea
          INTO TABLE @DATA(lt_costcentersubarea).
        IF sy-subrc = 0.
          SORT lt_costcentersubarea BY CostCenterSubArea.
        ENDIF.
      ENDIF.

      SORT lt_data_aux BY CostCenterSubArea.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING CostCenterSubArea.
      IF lt_data_aux IS NOT INITIAL.
        lt_allocation = CORRESPONDING #( lt_data_aux ).

        SELECT allocation FROM zi_intercocostcenter
          FOR ALL ENTRIES IN @lt_allocation
          WHERE allocation = @lt_allocation-allocation
          INTO TABLE @DATA(lt_costcenterallocation).
        IF sy-subrc = 0.
          SORT lt_costcenterallocation BY allocation.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_compprodbill[].

      SORT lt_data_aux BY id
                          providercompanycode
                          product
                          pandlid
                          profitcenter
                          CostCenterSubArea
                          validfrom
                          validto.
      DELETE ADJACENT DUPLICATES FROM lt_data_aux COMPARING Product ProviderCompanyCode.
      IF lt_data_aux IS NOT INITIAL.

        SELECT * FROM zi_intercocompanyrelprodbill
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE id                  <> @lt_data_aux-id
            AND providercompanycode  = @lt_data_aux-providercompanycode
            AND product              = @lt_data_aux-product
            AND pandlid              = @lt_data_aux-pandlid
            AND profitcenter         = @lt_data_aux-profitcenter
            AND costcentersubarea    = @lt_data_aux-costcentersubarea
            AND isdeleted            = @abap_false
          INTO TABLE @DATA(lT_companyproductbilling_aux).
      ENDIF.

      LOOP AT lt_compprodbill REFERENCE INTO ls_compprodbill.
        lv_index = ls_compprodbill->zindex.
        CONDENSE lv_index NO-GAPS.

        lt_companyproductbilling = CORRESPONDING #( lt_compprodbill ).
        READ TABLE lt_companyproductbilling REFERENCE INTO ls_companyproductbilling INDEX 1.

        IF ls_companyproductbilling IS INITIAL OR ls_companyproductbilling->isdeleted = abap_true.
          RETURN.
        ENDIF.

        IF ls_companyproductbilling->validfrom IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '028'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.

        IF ls_companyproductbilling->validto IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '029'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.

        IF     ls_companyproductbilling->validfrom IS NOT INITIAL
           AND ls_companyproductbilling->validto   IS NOT INITIAL
           AND ls_companyproductbilling->validfrom >= ls_companyproductbilling->validto.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '030'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.

        IF ls_companyproductbilling->product IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '031'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ELSE.

          READ TABLE lt_product TRANSPORTING NO FIELDS WITH KEY Product = ls_companyproductbilling->product BINARY SEARCH.
          IF sy-subrc IS NOT INITIAL.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '032'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        IF ls_companyproductbilling->providercompanycode IS NOT INITIAL.

          READ TABLE lt_company TRANSPORTING NO FIELDS WITH KEY ProviderCompanyCode = ls_companyproductbilling->providercompanycode BINARY SEARCH.
          IF sy-subrc IS NOT INITIAL.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '033'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        IF ls_companyproductbilling->PandLID IS INITIAL.
          APPEND VALUE #( %key = ls_CompProdBill->%key ) TO failed-ZI_IntercoCompanyRelProdBill.
          APPEND VALUE #( %key = ls_CompProdBill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '034'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-ZI_IntercoCompanyRelProdBill.
        ELSE.

          READ TABLE lt_pandl TRANSPORTING NO FIELDS WITH KEY PandLId = ls_companyproductbilling->PandLID BINARY SEARCH.
          IF sy-subrc IS NOT INITIAL.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '035'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        IF ls_companyproductbilling->profitcenter IS INITIAL.
          " Paola Rojo pide que se elimine el campo obligatorio - 26/11/2024 - Gabriel
          " APPEND VALUE #( %key = ls_CompProdBill->%key ) TO failed-ZI_IntercoCompanyRelProdBill.
          " APPEND VALUE #( %key = ls_CompProdBill->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '008' severity = if_abap_behv_message=>severity-error ) ) TO reported-ZI_IntercoCompanyRelProdBill.
        ELSE.

          READ TABLE lt_profitcenter TRANSPORTING NO FIELDS WITH KEY ProfitCenter = ls_companyproductbilling->profitcenter BINARY SEARCH.
          IF sy-subrc IS NOT INITIAL.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '036'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        "   Solicitado por Paola Rojo para eliminar la validación ProfitCenter, ya que el profitcenter IC02D ya no es obligatorio. - Gabriel Ribeiro - 02/12/204
        IF     ls_companyproductbilling->product             IS NOT INITIAL
           AND ls_companyproductbilling->providercompanycode IS NOT INITIAL.

          READ TABLE lt_companyproduct TRANSPORTING NO FIELDS WITH KEY Product             = ls_companyproductbilling->product
                                                                       providercompanycode = ls_companyproductbilling->providercompanycode
               BINARY SEARCH.
          IF sy-subrc IS NOT INITIAL.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '037'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) )
                   TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        IF ls_companyproductbilling->costcentersubarea IS INITIAL.
          APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '038'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ELSE.

          READ TABLE lt_costcentersubarea TRANSPORTING NO FIELDS WITH KEY CostCenterSubArea = ls_companyproductbilling->costcentersubarea BINARY SEARCH.

          IF sy-subrc IS NOT INITIAL.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '039'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        IF ls_companyproductbilling->costcenterallocation IS NOT INITIAL.
          lv_costcenterallocation = ls_companyproductbilling->costcenterallocation.
          SHIFT lv_costcenterallocation LEFT DELETING LEADING '0'.

          READ TABLE lt_costcenterallocation TRANSPORTING NO FIELDS WITH KEY Allocation = lv_costcenterallocation BINARY SEARCH.
          IF sy-subrc <> 0.
            APPEND VALUE #( %key = ls_compprodbill->%key ) TO failed-zi_intercocompanyrelprodbill.
            APPEND VALUE #( %key = ls_compprodbill->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '040'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
          ENDIF.
        ENDIF.

        " Validação se já existe um registro Igual

        READ TABLE lt_companyproductbilling_aux INTO ls_companyproductbilling_aux WITH KEY providercompanycode = ls_companyproductbilling->ProviderCompanyCode
                                                                                           product             = ls_companyproductbilling->product
                                                                                           pandlid             = ls_companyproductbilling->pandlid
                                                                                           profitcenter        = ls_companyproductbilling->profitcenter
                                                                                           costcentersubarea   = ls_companyproductbilling->costcentersubarea
             BINARY SEARCH.

        IF ls_companyproductbilling_aux IS NOT INITIAL AND (    ( ls_companyproductbilling_aux-validto   BETWEEN ls_companyproductbilling->validfrom AND ls_companyproductbilling->validto )
                                                             OR ( ls_companyproductbilling_aux-validfrom BETWEEN ls_companyproductbilling->validfrom AND ls_companyproductbilling->validto ) ).
          APPEND VALUE #( %tky = ls_compprodbill->%tky ) TO failed-zi_intercocompanyrelprodbill.
          APPEND VALUE #( %key = ls_compprodbill->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '041'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
        ENDIF.

      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD precheck_delete.
    READ ENTITIES OF zi_intercocompanyrelprodbill
       ENTITY zi_intercocompanyrelprodbill ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_companyrelprodbill).

    LOOP AT lt_companyrelprodbill INTO DATA(ls_companyrelprodbill).
      IF ls_companyrelprodbill-isdeleted = abap_false.
        APPEND VALUE #( %key = ls_companyrelprodbill-%key ) TO failed-zi_intercocompanyrelprodbill.
        APPEND VALUE #( %key = ls_companyrelprodbill-%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '020' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD setdeletebbill.
    READ ENTITIES OF zi_intercocompanyrelprodbill
        ENTITY zi_intercocompanyrelprodbill ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_companyrelprodbill).

    READ TABLE lt_companyrelprodbill REFERENCE INTO DATA(ls_companyrelprodbill) INDEX 1.

    IF ls_companyrelprodbill->isdeleted = ''.
      MODIFY ENTITIES OF zi_intercocompanyrelprodbill IN LOCAL MODE
        ENTITY zi_intercocompanyrelprodbill
        UPDATE FIELDS ( isdeleted )
        WITH VALUE #( FOR ls_key IN keys
                     ( %tky         = ls_key-%tky
                       isdeleted     = 'X'
                      )
                   )
        FAILED failed
        REPORTED reported.

      IF failed IS NOT INITIAL.

      ENDIF.
    ENDIF.
  ENDMETHOD.

  "  METHOD SetCostCenterAllocation.
  "    READ ENTITIES OF ZI_IntercoCompanyRelProdBill
  "        ENTITY ZI_IntercoCompanyRelProdBill ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_CompanyRelProdBill).
  "
  "    READ TABLE lt_CompanyRelProdBill ASSIGNING FIELD-SYMBOL(<fs_CompanyRelProdBill>) INDEX 1.
  "
  "    IF <fs_CompanyRelProdBill>-CostCenterAllocation is not INITIAL.
  "      SHIFT <fs_CompanyRelProdBill>-CostCenterAllocation LEFT DELETING LEADING '0'.
  "
  "      MODIFY ENTITIES OF ZI_IntercoCompanyRelProdBill IN LOCAL MODE
  "       ENTITY ZI_IntercoCompanyRelProdBill
  "        UPDATE FIELDS ( CostCenterAllocation )
  "        WITH CORRESPONDING #( lt_CompanyRelProdBill )
  "        REPORTED  DATA(lt_reported).
  "
  "        reported-zi_intercocompanyrelprodbill =  CORRESPONDING #( lt_reported-zi_intercocompanyrelprodbill ).
  "    ENDIF.
  "  ENDMETHOD.

  METHOD getcostcenterarea.
    READ ENTITIES OF zi_intercocompanyrelprodbill
        ENTITY zi_intercocompanyrelprodbill ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_companyrelprodbill).

    READ TABLE lt_companyrelprodbill ASSIGNING FIELD-SYMBOL(<fs_companyrelprodbill>) INDEX 1.

    IF <fs_companyrelprodbill>-costcentersubarea IS NOT INITIAL.

      SELECT SINGLE * FROM zi_intercocostcentersubarea
          WHERE costcentersubarea = @<fs_companyrelprodbill>-costcentersubarea
          INTO @DATA(ls_costcentersubarea).

      IF ls_costcentersubarea IS INITIAL.
        <fs_companyrelprodbill>-costcenterarea = ls_costcentersubarea-costcenterarea.

        MODIFY ENTITIES OF zi_intercocompanyrelprodbill IN LOCAL MODE
           ENTITY zi_intercocompanyrelprodbill
                UPDATE FIELDS ( costcenterarea )
                WITH CORRESPONDING #( lt_companyrelprodbill )
                REPORTED  DATA(lt_reported).

        reported-zi_intercocompanyrelprodbill =  CORRESPONDING #( lt_reported-zi_intercocompanyrelprodbill ).
      ENDIF.



    ENDIF.
  ENDMETHOD.

  METHOD uploadProdBill.
    DATA lt_relprodbill  TYPE TABLE FOR CREATE ZI_IntercoCompanyRelProdBill.

    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).

    IF <fs_key> IS NOT ASSIGNED.
      RETURN.
    ENDIF.
    AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
    ID 'ACTVT' FIELD '02'
    ID 'ZFI_IC_LVV' DUMMY.
    IF sy-subrc NE 0.
      APPEND VALUE #( %cid = <fs_key>-%cid ) TO failed-zi_intercocompanyrelprodbill.
      APPEND VALUE #( %cid = <fs_key>-%cid %msg = new_message( id = 'ZHOM_MONITOR_NFE' number = '800' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelprodbill.
      RETURN.
    ENDIF.
    DATA(lcl_interco_upload) = NEW zcl_interco_master_upload( ).
    DATA(lt_data) = lcl_interco_upload->upload_relprodbill( is_params = CONV #( <fs_key>-%param ) ).

    IF lt_data[] IS INITIAL.
      RETURN.
    ENDIF.

*    INSERT lcl_interco_upload INTO TABLE ltd_list_bo.
*
*    DATA lv_debug TYPE abap_boolean.
*
*    CHECK ltd_list_bo IS NOT INITIAL.
*
*    DATA(l_ref) = NEW cl_abap_parallel( p_num_tasks = 1 ).
*    l_ref->run_inst( EXPORTING p_in_tab  = ltd_list_bo
*                               p_debug   = lv_debug
*                     IMPORTING
*                               p_out_tab = DATA(L_out_tab) ).
*
*    READ TABLE l_out_tab ASSIGNING FIELD-SYMBOL(<fs_outtab>) INDEX 1.
*    if sy-subrc eq 0.
*
*    endif.
    GET TIME STAMP FIELD DATA(lv_tmtmpl).
    lt_relprodbill = VALUE #( FOR ls_data IN lt_data INDEX INTO lv_index
                              ( %cid                = lv_index
                                Product             = ls_data-product
                                ProviderCompanyCode = ls_data-providercompanycode
                                ProfitCenter        = ls_data-profitCenter
                                ValidFrom           = ls_data-validFrom
                                ValidTo             = ls_data-validto
                                IsNotBilable        = ls_data-isnotbilable
                                CreatedBy           = sy-uname
                                CreatedAt           = lv_tmtmpl
                                zindex              = lv_index ) ).

    TRY.
        MODIFY ENTITIES OF zi_intercocompanyrelprodbill IN LOCAL MODE
               ENTITY zi_intercocompanyrelprodbill
               CREATE FIELDS ( Product ProviderCompanyCode ProfitCenter ValidFrom ValidTo IsNotBilable zindex CreatedBy CreatedAt )
               WITH lt_relprodbill[].
*               MAPPED mapped
*               FAILED failed
*               REPORTED reported.

      CATCH cx_root INTO DATA(lo_ex). " TODO: variable is assigned but never used (ABAP cleaner)

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
