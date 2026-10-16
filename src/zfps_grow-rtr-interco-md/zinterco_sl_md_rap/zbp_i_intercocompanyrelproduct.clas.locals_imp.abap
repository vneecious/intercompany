CLASS lsc_zi_intercocompanyrelprodu DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zi_intercocompanyrelprodu IMPLEMENTATION.
  METHOD save_modified.
    DATA lt_md001 TYPE STANDARD TABLE OF zint_a_md001.

    DATA(lref_cdo) = NEW zcl_interco_cdo( ).
    IF create-zi_intercocompanyrelproduct IS NOT INITIAL.
      lt_md001 = CORRESPONDING #( create-zi_intercocompanyrelproduct ).
      SORT lt_md001 BY id.

      SELECT mandt, id, validfrom, validto, providercompanycode, recipientcompanycode, product, profitcenter, rate,
             flow, ispromo, isblocked, isdeleted, zindex, authorizationgroup, createdat, createdby, lastchangedat
        FROM zint_a_md001
        FOR ALL ENTRIES IN @lt_md001
        WHERE id = @lt_md001-id
        INTO TABLE @DATA(lt_md001_orig).
      IF sy-subrc = 0.
        SORT lt_md001_orig BY id.
      ENDIF.
      LOOP AT lt_md001 ASSIGNING FIELD-SYMBOL(<fs_md001>).
        READ TABLE lt_md001_orig INTO DATA(ls_data_old) WITH KEY id = <fs_md001>-id BINARY SEARCH.

        lref_cdo->write_md001_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-create
                                              is_data     = <fs_md001>
                                              is_data_old = ls_data_old
                                             " TODO: variable is assigned but never used (ABAP cleaner)
                                    IMPORTING ev_error    = DATA(lv_error) ).
      ENDLOOP.
      lref_cdo->save_md001( iv_chin = lref_cdo->cs_chdo-create
                            it_data = lt_md001 ).
    ENDIF.
    IF update-zi_intercocompanyrelproduct IS NOT INITIAL.
      lt_md001 = CORRESPONDING #( update-zi_intercocompanyrelproduct ).
      SORT lt_md001 BY id.

      SELECT mandt, id, validfrom, validto, providercompanycode, recipientcompanycode, product, profitcenter, rate,
             flow, ispromo, isblocked, isdeleted, zindex, authorizationgroup, createdat, createdby, lastchangedat
        FROM zint_a_md001
        FOR ALL ENTRIES IN @lt_md001
        WHERE id = @lt_md001-id
        INTO TABLE @lt_md001_orig.
      IF sy-subrc = 0.
        SORT lt_md001_orig BY id.
      ENDIF.

      LOOP AT lt_md001 ASSIGNING <fs_md001>.
        READ TABLE lt_md001_orig INTO ls_data_old WITH KEY id = <fs_md001>-id BINARY SEARCH.

        lref_cdo->write_md001_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-update
                                              is_data     = <fs_md001>
                                              is_data_old = ls_data_old
                                    IMPORTING ev_error    = lv_error ).
      ENDLOOP.
      lref_cdo->save_md001( iv_chin = lref_cdo->cs_chdo-update
                            it_data = lt_md001 ).
    ENDIF.
    IF delete-zi_intercocompanyrelproduct IS NOT INITIAL.
      lt_md001 = CORRESPONDING #( delete-zi_intercocompanyrelproduct ).
      LOOP AT lt_md001 ASSIGNING <fs_md001>.
        READ TABLE lt_md001_orig INTO ls_data_old WITH KEY id = <fs_md001>-id BINARY SEARCH.
        lref_cdo->write_md001_chdo( EXPORTING iv_chin     = lref_cdo->cs_chdo-delete
                                              is_data     = <fs_md001>
                                              is_data_old = ls_data_old
                                    IMPORTING ev_error    = lv_error ).
      ENDLOOP.
      lref_cdo->save_md001( iv_chin = lref_cdo->cs_chdo-delete
                            it_data = lt_md001 ).
    ENDIF.
  ENDMETHOD.



ENDCLASS.

CLASS lhc_zi_intercocompanyrelproduc DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_intercocompanyrelproduct RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_intercocompanyrelproduct RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_intercocompanyrelproduct RESULT result.

    "    METHODS precheck FOR PRECHECK
    "     IMPORTING entities_create FOR CREATE CompanyRelationshipProduct
    "                entities_update FOR UPDATE CompanyRelationshipProduct.

    " METHODS get_instance_features FOR FEATURES
    "  IMPORTING keys   REQUEST requested_features FOR ZI_IntercoCompanyRelProduct
    " RESULT    result.

    METHODS validatedata FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_intercocompanyrelproduct~validatedata.

    METHODS precheck_delete FOR PRECHECK
      IMPORTING keys FOR DELETE zi_intercocompanyrelproduct.

    METHODS block FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelproduct~block.
    METHODS release FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelproduct~release.
    METHODS setdelete FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelproduct~setdelete.
    METHODS deletedraft FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelproduct~deletedraft.
    METHODS uploadCompProducts FOR MODIFY
      IMPORTING keys FOR ACTION zi_intercocompanyrelproduct~uploadCompProducts.
    METHODS DeterValidFrom FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ZI_IntercoCompanyRelProduct~DeterValidFrom.
    METHODS DeterValidTo FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ZI_IntercoCompanyRelProduct~DeterValidTo.

    METHODS get_last_day_of_month
      IMPORTING VALUE(day_in)            TYPE sy-datum
      EXPORTING VALUE(last_day_of_month) TYPE sy-datum.

ENDCLASS.

CLASS lhc_zi_intercocompanyrelproduc IMPLEMENTATION.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
           ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys )
           RESULT DATA(lt_companyproduct).

    LOOP AT lt_companyproduct ASSIGNING FIELD-SYMBOL(<fs_rate>).
      APPEND VALUE #( %is_draft         = keys[ id = <fs_rate>-id ]-%is_draft
                      id                = <fs_rate>-id
                      %update           = COND #( WHEN <fs_rate>-isdeleted = abap_true
                                                   OR <fs_rate>-IsBlocked = abap_true
                      THEN if_abap_behv=>auth-unauthorized
                      ELSE if_abap_behv=>auth-Allowed )
                      %delete           = COND #( WHEN <fs_rate>-isdeleted = abap_true
                      THEN if_abap_behv=>auth-Allowed
                      ELSE if_abap_behv=>auth-unauthorized )
                      %action-Block     = if_abap_behv=>auth-Allowed
                      %action-release   = COND #( WHEN <fs_rate>-isdeleted = abap_true
                      THEN if_abap_behv=>auth-unauthorized
                      ELSE if_abap_behv=>auth-Allowed )
                      %action-SetDelete = COND #( WHEN <fs_rate>-isdeleted = abap_true
                      THEN if_abap_behv=>auth-unauthorized
                      ELSE if_abap_behv=>auth-Allowed )
      ) TO result.
    ENDLOOP.

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
    IF requested_authorizations-%action-SetDelete = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '02'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%action-SetDelete = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                         ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-Block = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '02'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%action-Block = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                     ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
    IF requested_authorizations-%action-Release = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZFI_IC_LVL'
      ID 'ACTVT' FIELD '02'
      ID 'ZFI_IC_LVV' DUMMY.
      result-%action-Release = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                       ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.

    GET TIME STAMP FIELD DATA(lv_time_stamp).
    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
       ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys )
       RESULT DATA(lt_companyproduct).

    LOOP AT lt_companyproduct ASSIGNING FIELD-SYMBOL(<fs_rate>).

      APPEND VALUE #(
           %tky    = <fs_rate>-%tky
           %delete = COND #( WHEN <fs_rate>-isdeleted = 'X' THEN if_abap_behv=>fc-o-enabled
           ELSE if_abap_behv=>fc-o-disabled )
                    ) TO result.

      "Cambio FPSRUNFI-5784 | Siempre permitir edición, solo marcar como mandatory si están vacíos**
      APPEND VALUE #( %tky                        = <fs_rate>-%tky
                      %field-ProviderCompanyCode  = COND #( WHEN <fs_rate>-ProviderCompanyCode IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                      %field-RecipientCompanyCode = COND #( WHEN <fs_rate>-RecipientCompanyCode IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                      %field-Product              = COND #( WHEN <fs_rate>-Product IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                      %field-ProfitCenter         = COND #( WHEN <fs_rate>-ProfitCenter IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                      %field-Flow                 = COND #( WHEN <fs_rate>-Flow IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                      %field-ValidFrom            = COND #( WHEN <fs_rate>-ValidFrom IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                      %field-ValidTo              = COND #( WHEN <fs_rate>-ValidTo IS INITIAL
                                                           THEN if_abap_behv=>fc-f-mandatory
                                                           ELSE if_abap_behv=>fc-f-unrestricted )
                    ) TO result.
    ENDLOOP.
  ENDMETHOD.

  "  METHOD precheck.
  "    DATA(entities_check) = entities_create.
  "    entities_check = VALUE #( BASE entities_check FOR entity_update IN entities_update ( CORRESPONDING #( entity_update ) ) ).
  "
  "    LOOP AT entities_check INTO DATA(ls_CompanyRelepProduct).
  "      IF ls_CompanyRelepProduct-%is_draft EQ '01' OR ls_CompanyRelepProduct-IsBlocked = 'X' OR ls_CompanyRelepProduct-IsDeleted = 'X'.
  "        EXIT.
  "      ENDIF.
  "
  "    ENDLOOP.
  "  ENDMETHOD.

  "METHOD get_instance_features.
  "  result = VALUE #( FOR key IN keys
  "                      ( %tky = key-%tky
  "                        %field-IsDeleted        = if_abap_behv=>fc-f-read_only
  "                        %field-IsBlocked        = if_abap_behv=>fc-f-read_only
  "                      ) ).
  "ENDMETHOD.

  METHOD precheck_delete.
    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
       ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys )
       RESULT DATA(lt_companyproduct).

    LOOP AT lt_companyproduct INTO DATA(ls_companyproduct).
      IF ls_companyproduct-isdeleted = abap_false.
        APPEND VALUE #( %key = ls_companyproduct-%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_companyproduct-%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '020' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatedata.
    DATA lt_companyproduct TYPE TABLE OF zi_intercocompanyrelproduct.
    DATA lv_index          TYPE symsg-msgv1.

    CLEAR: failed-zi_intercocompanyrelproduct,
           reported-zi_intercocompanyrelproduct.

    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
         ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_compprod).

    LOOP AT lt_compprod INTO DATA(ls_comp_check).
      IF ls_comp_check-ProviderCompanyCode IS NOT INITIAL AND
         ls_comp_check-RecipientCompanyCode IS NOT INITIAL AND
         ls_comp_check-Product IS NOT INITIAL AND
         ls_comp_check-ProfitCenter IS NOT INITIAL AND
         ls_comp_check-Flow IS NOT INITIAL AND
         ls_comp_check-ValidFrom IS NOT INITIAL AND
         ls_comp_check-ValidTo IS NOT INITIAL.

        IF ls_comp_check-Flow = 'O' OR ls_comp_check-Flow = 'I'.
          CONTINUE.
        ENDIF.
      ENDIF.
    ENDLOOP.

    READ TABLE lt_compprod  REFERENCE INTO DATA(ls_compprod) INDEX 1.

    lt_companyproduct = CORRESPONDING #( lt_compprod ).

    READ TABLE lt_companyproduct REFERENCE INTO DATA(ls_companyrelepproduct) INDEX 1.

    IF ls_companyrelepproduct IS INITIAL.
      RETURN.
    ENDIF.

    IF ls_companyrelepproduct->zindex IS INITIAL.

      IF ls_companyrelepproduct->providercompanycode IS INITIAL.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '001'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        " APPEND VALUE #( %key = ls_compprod->%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'ProviderCompanyCode Required' ) ) TO reported-ZI_IntercoCompanyRelProduct.
      ELSE.

        SELECT SINGLE zi_intercorelationship~providercompanycode
          FROM zi_intercorelationship
          WHERE zi_intercorelationship~providercompanycode = @ls_companyrelepproduct->providercompanycode
          INTO @DATA(ls_company).
        IF ls_company IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '002'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.
      ENDIF.

      IF ls_companyrelepproduct->recipientcompanycode IS INITIAL.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '003'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ELSE.
        SELECT SINGLE zi_intercorelationship~recipientcompanycode
          FROM zi_intercorelationship
          WHERE zi_intercorelationship~recipientcompanycode = @ls_companyrelepproduct->recipientcompanycode
          INTO @DATA(ls_company2).
        IF ls_company2 IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '004'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.
      ENDIF.

      IF     ls_companyrelepproduct->providercompanycode  IS NOT INITIAL
         AND ls_companyrelepproduct->recipientcompanycode IS NOT INITIAL
         AND ls_companyrelepproduct->providercompanycode  <> ls_companyrelepproduct->recipientcompanycode.

        SELECT SINGLE * FROM zi_intercorelationship
          WHERE providercompanycode  = @ls_companyrelepproduct->providercompanycode
            AND recipientcompanycode = @ls_companyrelepproduct->recipientcompanycode
          INTO @DATA(ls_intercorelationship).
        IF ls_intercorelationship IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '005'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.
      ENDIF.

      IF ls_companyrelepproduct->product IS INITIAL.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '006'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ELSE.

        SELECT SINGLE product FROM zi_intercoproduct
          WHERE product = @ls_companyrelepproduct->product
          INTO @DATA(lv_product).
        IF lv_product IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '007'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.
      ENDIF.

      "###### Inicio DF-190 - Submiter: Florencia Majul
      " Por Favor ajustar la validacion de datos en la applicacion Relaciones de Sociedades por Conceptos (IC02D)
      " de maneira tal de permitir registros sin CEBE para materiales de Cost Sharing Brasil
      SELECT SINGLE metric FROM zi_intercoproduct
        WHERE product = @ls_companyrelepproduct->product
        INTO @DATA(lv_productgroup).

      IF lv_productgroup <> 'IC' AND lv_productgroup <> 'CS'.
        "###### Fim DF-190.

        IF ls_companyrelepproduct->profitcenter IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-ZI_IntercoCompanyRelProduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '008'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-ZI_IntercoCompanyRelProduct.
        ELSE.
          SELECT SINGLE ProfitCenter FROM zi_intercoprofitcenter
            WHERE ProfitCenter = @ls_companyrelepproduct->profitcenter
            INTO @DATA(lv_profitcenter).
          IF lv_profitcenter IS INITIAL.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '009'
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.
      ENDIF.

      IF ls_companyrelepproduct->flow IS INITIAL.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '010'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ELSE.
        "  SELECT SINGLE flow FROM ZI_IntercoFlow_SH
        "      WHERE Flow = @ls_companyrelepproduct->Flow
        "      INTO @DATA(lv_flow).
        "  IF lv_flow IS INITIAL.
        IF ls_companyrelepproduct->flow <> 'O' AND ls_companyrelepproduct->flow <> 'I'.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '011'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.
      ENDIF.

      IF ls_companyrelepproduct->validfrom IS INITIAL.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '012'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ENDIF.

      IF ls_companyrelepproduct->validto IS INITIAL.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '013'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ENDIF.

      IF     ls_companyrelepproduct->validfrom IS NOT INITIAL
         AND ls_companyrelepproduct->validto   IS NOT INITIAL
         AND ls_companyrelepproduct->validfrom >= ls_companyrelepproduct->validto.
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.

        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '014'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ENDIF.

      IF     ls_companyrelepproduct->rate IS NOT INITIAL
         AND ( ls_companyrelepproduct->rate < 0 OR ls_companyrelepproduct->rate > 100 ).
        APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
        APPEND VALUE #( %key = ls_compprod->%key
                        %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                            number   = '015'
                                            severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      ENDIF.

      " IF ls_CompanyRelepProduct->IsBlocked = abap_true.
      "  APPEND VALUE #( %key =  ls_compprod->%key ) TO failed-ZI_IntercoCompanyRelProduct.
      "  APPEND VALUE #( %key =  ls_compprod->%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Cannot create/update the record Blocked' ) ) TO reported-ZI_IntercoCompanyRelProduct.
      " ENDIF.

      " IF ls_CompanyRelepProduct->IsDeleted = abap_true.
      "  APPEND VALUE #( %key =  ls_compprod->%key ) TO failed-ZI_IntercoCompanyRelProduct.
      "  APPEND VALUE #( %key =  ls_compprod->%key %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error text = 'Cannot create/update the record Deleted' ) ) TO reported-ZI_IntercoCompanyRelProduct.
      " ENDIF.

      IF ls_companyrelepproduct->id IS NOT INITIAL.
        " Validação se já existe um registro Igual
        " Se valida dentro de todo el periodo
        " TODO: variable is assigned but only used in commented-out code (ABAP cleaner)
        DATA(lv_validfrom) = ls_companyrelepproduct->validfrom.
        lv_validfrom = |{ lv_validfrom(6) }{ '01' }|.
        " TODO: variable is assigned but only used in commented-out code (ABAP cleaner)
        DATA(lv_validto) = ls_companyrelepproduct->validto.

*{ Insert Mod 001 RAR - Validar duplicidd
*        READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
*             ENTITY zi_intercocompanyrelproduct ALL FIELDS
*             WITH VALUE #( (
*                             "%control-Id <> ls_companyrelepproduct->id
*                             %control-providercompanycode   = ls_companyrelepproduct->providercompanycode
*                             %control-recipientcompanycode  = ls_companyrelepproduct->recipientcompanycode
*                             %control-product               = ls_companyrelepproduct->product
*                             %control-profitcenter          = ls_companyrelepproduct->profitcenter
*                             %control-flow                  = ls_companyrelepproduct->Flow
*                             "%control-validfrom            <= ls_companyrelepproduct->ValidFrom
*                             "%control-validto              >= ls_companyrelepproduct->ValidTo
*                             %control-isdeleted             = abap_false
*            ) )
*          RESULT DATA(lt_companyproduct_aux).

*        SELECT SINGLE * FROM zi_intercocompanyrelproduct zint_a_md003
        SELECT SINGLE * FROM zint_a_md001
          WHERE id                   <> @ls_companyrelepproduct->id
            AND providercompanycode   = @ls_companyrelepproduct->providercompanycode
            AND recipientcompanycode  = @ls_companyrelepproduct->recipientcompanycode
            AND product               = @ls_companyrelepproduct->product
            AND profitcenter          = @ls_companyrelepproduct->profitcenter
            AND flow                  = @ls_companyrelepproduct->Flow
            AND validfrom            <= @ls_companyrelepproduct->ValidFrom
            AND validto              >= @ls_companyrelepproduct->ValidTo
            AND isdeleted             = @abap_false
          INTO @DATA(ls_companyproduct_aux).

*        IF lt_companyproduct_aux IS NOT INITIAL.
*          DATA lt_compprod_aux TYPE TABLE OF zi_intercocompanyrelproduct.
*          lt_compprod_aux = CORRESPONDING #( lt_companyproduct_aux ).
*
*          LOOP AT lt_compprod_aux REFERENCE INTO DATA(ls_companyproduct_aux).

        IF ls_companyproduct_aux IS NOT INITIAL.
*            IF ls_companyproduct_aux IS NOT INITIAL AND
*               ls_companyproduct_aux->Id  <> ls_companyrelepproduct->id AND
*               ls_companyproduct_aux->validfrom <= ls_companyrelepproduct->ValidFrom AND
*               ls_companyproduct_aux->validto >= ls_companyrelepproduct->ValidTo.

          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '016'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.
*          ENDLOOP.
*        ENDIF.
*} End Mod 001
      ENDIF.
    ELSE.

      DATA(lt_data_aux) = lt_companyproduct[].
      SORT lt_Data_aux BY ProviderCompanyCode.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING ProviderCompanyCode.

      IF lt_data_aux[] IS NOT INITIAL.

        SELECT zi_intercorelationship~providercompanycode
          FROM zi_intercorelationship
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE zi_intercorelationship~providercompanycode = @lt_data_aux-providercompanycode
          INTO TABLE @DATA(lt_company).
        IF sy-subrc = 0.
          SORT lt_company BY ProviderCompanyCode.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_companyproduct[].
      SORT lt_Data_aux BY RecipientCompanyCode.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING RecipientCompanyCode.

      IF lt_data_aux[] IS NOT INITIAL.

        SELECT zi_intercorelationship~RecipientCompanyCode
          FROM zi_intercorelationship
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE zi_intercorelationship~RecipientCompanyCode = @lt_data_aux-RecipientCompanyCode
          INTO TABLE @DATA(lt_company2).
        IF sy-subrc = 0.
          SORT lt_company BY ProviderCompanyCode.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_companyproduct[].
      SORT lt_Data_aux BY providercompanycode
                          RecipientCompanyCode.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING providercompanycode RecipientCompanyCode.

      IF lt_data_aux[] IS NOT INITIAL.
        SELECT providercompanycode, recipientcompanycode
          FROM zi_intercorelationship
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE providercompanycode  = @lt_data_aux-providercompanycode
            AND recipientcompanycode = @lt_data_aux-recipientcompanycode
          INTO TABLE @DATA(lt_intercorelationship).
        IF sy-subrc = 0.
          SORT lt_intercorelationship BY ProviderCompanyCode
                                         recipientcompanycode.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_companyproduct[].
      SORT lt_Data_aux BY Product.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING Product.

      IF lt_data_aux[] IS NOT INITIAL.

        SELECT product FROM zi_intercoproduct
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE product = @lt_data_aux-product
          INTO TABLE @DATA(lt_product).
        IF sy-subrc = 0.
          SORT lt_product BY Product.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_companyproduct[].
      SORT lt_Data_aux BY ProfitCenter.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING ProfitCenter.

      IF lt_data_aux[] IS NOT INITIAL.
        SELECT ProfitCenter FROM zi_intercoprofitcenter
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE ProfitCenter = @lt_data_aux-profitcenter
          INTO TABLE @DATA(lt_profitcenter).
        IF sy-subrc = 0.
          SORT lt_profitcenter BY ProfitCenter.
        ENDIF.
      ENDIF.

      lt_data_aux = lt_companyproduct[].
      SORT lt_Data_aux BY id
                          providercompanycode
                          RecipientCompanyCode
                          Product
                          ProfitCenter
                          flow.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING id providercompanycode RecipientCompanyCode Product ProfitCenter flow.

      IF lt_data_aux[] IS NOT INITIAL.

        DATA lt_companyprod TYPE STANDARD TABLE OF zi_intercocompanyrelproduct.

        SELECT *
          FROM zi_intercocompanyrelproduct
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE providercompanycode  = @lt_data_aux-providercompanycode
            AND recipientcompanycode = @lt_data_aux-recipientcompanycode
            AND product              = @lt_data_aux-product
            AND profitcenter         = @lt_data_aux-profitcenter
            AND flow                 = @lt_data_aux-flow
            AND isdeleted            = @abap_false
          INTO TABLE @lt_companyprod.

***        READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
***             ENTITY zi_intercocompanyrelproduct ALL FIELDS
***             WITH VALUE #( FOR <ls_data_aux> IN lt_data_aux (
***                           %control-providercompanycode  = <ls_data_aux>-providercompanycode
***                           %control-recipientcompanycode = <ls_data_aux>-recipientcompanycode
***                           %control-product              = <ls_data_aux>-product
***                           %control-profitcenter         = <ls_data_aux>-profitcenter
***                           %control-flow                 = <ls_data_aux>-Flow
***                           %control-isdeleted            = abap_false
***                           ) )
***          RESULT DATA(lt_companyprod).
        "        SELECT Id,
        "               ProviderCompanyCode,
        "               ProviderCompanyCodeName,
        "               RecipientCompanyCode,
        "               RecipientCompanyCodeName,
        "               Product,
        "               ProductName,
        "               Metric,
        "               ProfitCenter,
        "               ProfitCenterName,
        "               ValidFrom,
        "               ValidTo,
        "               rate,
        "               flow
        "          FROM zi_intercocompanyrelproduct
        "          FOR ALL ENTRIES IN @lt_data_aux
        "          WHERE id                   <> @lt_data_aux-id
        "            AND providercompanycode   = @lt_data_aux-providercompanycode
        "            AND recipientcompanycode  = @lt_data_aux-recipientcompanycode
        "            AND product               = @lt_data_aux-product
        "            AND profitcenter          = @lt_data_aux-profitcenter
        "            AND flow                  = @lt_data_aux-Flow
        "            AND isdeleted             = @abap_false
        "          INTO TABLE @DATA(lt_companyprod).
        IF sy-subrc = 0.

          SORT lt_companyprod BY providercompanycode
                                 RecipientCompanyCode
                                 Product
                                 ProfitCenter
                                 flow.
        ENDIF.
      ENDIF.

      "###### Inicio DF-190 - Submiter: Florencia Majul
      " Por Favor ajustar la validacion de datos en la applicacion Relaciones de Sociedades por Conceptos (IC02D)
      " de maneira tal de permitir registros sin CEBE para materiales de Cost Sharing Brasil
      lt_data_aux = lt_companyproduct[].
      SORT lt_Data_aux BY product.
      DELETE ADJACENT DUPLICATES FROM lt_Data_aux COMPARING Product.

      IF lt_data_aux[] IS NOT INITIAL.

        SELECT product,
               metric  AS group
          FROM zi_intercoproduct
          FOR ALL ENTRIES IN @lt_data_aux
          WHERE product = @lt_data_aux-product
          INTO TABLE @DATA(lt_productgroup).
        IF sy-subrc = 0.
          SORT lt_productgroup BY product.
        ENDIF.
      ENDIF.
      "###### Fim DF-190.

      LOOP AT lt_companyproduct REFERENCE INTO ls_companyrelepproduct.
        lv_index = ls_companyrelepproduct->zindex.
        CONDENSE lv_index NO-GAPS.

        IF ls_companyrelepproduct->providercompanycode IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '042'
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ELSE.
          READ TABLE lt_company TRANSPORTING NO FIELDS WITH KEY providercompanycode = ls_companyrelepproduct->providercompanycode BINARY SEARCH.
          IF sy-subrc <> 0.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '033'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.

        IF ls_companyrelepproduct->recipientcompanycode IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '043'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ELSE.

          READ TABLE lt_company2 TRANSPORTING NO FIELDS WITH KEY RecipientCompanyCode = ls_companyrelepproduct->RecipientCompanyCode BINARY SEARCH.
          IF sy-subrc <> 0.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '044'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.

        IF     ls_companyrelepproduct->providercompanycode  IS NOT INITIAL
           AND ls_companyrelepproduct->recipientcompanycode IS NOT INITIAL
           AND ls_companyrelepproduct->providercompanycode  <> ls_companyrelepproduct->recipientcompanycode.

          READ TABLE lt_intercorelationship TRANSPORTING NO FIELDS WITH KEY ProviderCompanyCode  = ls_companyrelepproduct->ProviderCompanyCode
                                                                            RecipientCompanyCode = ls_companyrelepproduct->RecipientCompanyCode BINARY SEARCH.
          IF sy-subrc <> 0.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '045'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.

        IF ls_companyrelepproduct->product IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '031'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ELSE.

          READ TABLE lt_product TRANSPORTING NO FIELDS WITH KEY Product = ls_companyrelepproduct->Product BINARY SEARCH.
          IF sy-subrc <> 0.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '032'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.

        "###### Inicio DF-190 - Submiter: Florencia Majul
        READ TABLE lt_productgroup INTO DATA(ls_productgroup) WITH KEY product = ls_companyrelepproduct->Product BINARY SEARCH.
        IF ls_productgroup-group <> 'IC' AND ls_productgroup-group <> 'CS'.
          "###### Fim DF-190.

          IF ls_companyrelepproduct->profitcenter IS INITIAL.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-ZI_IntercoCompanyRelProduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '046'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-ZI_IntercoCompanyRelProduct.
          ELSE.

            READ TABLE lt_profitcenter TRANSPORTING NO FIELDS WITH KEY ProfitCenter = ls_companyrelepproduct->ProfitCenter BINARY SEARCH.
            IF sy-subrc <> 0.
              APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
              APPEND VALUE #( %key = ls_compprod->%key
                              %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                  number   = '036'
                                                  v1       = lv_index
                                                  severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
            ENDIF.
          ENDIF.

        ENDIF.

        IF ls_companyrelepproduct->flow IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '047'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ELSE.
          IF ls_companyrelepproduct->flow <> 'O' AND ls_companyrelepproduct->flow <> 'I'.
            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '048'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.

        IF ls_companyrelepproduct->validfrom IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '028'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.

        IF ls_companyrelepproduct->validto IS INITIAL.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '029'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.

        IF     ls_companyrelepproduct->validfrom IS NOT INITIAL
           AND ls_companyrelepproduct->validto   IS NOT INITIAL
           AND ls_companyrelepproduct->validfrom >= ls_companyrelepproduct->validto.
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.

          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '030'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.

        IF     ls_companyrelepproduct->rate IS NOT INITIAL
           AND ( ls_companyrelepproduct->rate < 0 OR ls_companyrelepproduct->rate > 100 ).
          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '049'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.

        SELECT zindex FROM @lt_companyproduct AS ltprod
          WHERE ltprod~id                   <> @ls_companyrelepproduct->id
            AND ltprod~providercompanycode   = @ls_companyrelepproduct->providercompanycode
            AND ltprod~recipientcompanycode  = @ls_companyrelepproduct->recipientcompanycode
            AND ltprod~product               = @ls_companyrelepproduct->product
            AND ltprod~profitcenter          = @ls_companyrelepproduct->profitcenter
            AND ltprod~flow                  = @ls_companyrelepproduct->Flow
            AND ltprod~Validfrom            <= @ls_companyrelepproduct->Validfrom
            AND ltprod~Validto              >= @ls_companyrelepproduct->Validto
          INTO TABLE @DATA(lt_duplicated).
        IF lt_duplicated[] IS NOT INITIAL.
          CLEAR lt_duplicated[].

          APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
          APPEND VALUE #( %key = ls_compprod->%key
                          %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                              number   = '050'
                                              v1       = lv_index
                                              severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
        ENDIF.

        IF ls_companyrelepproduct->id IS NOT INITIAL.
          " Validação se já existe um registro Igual
          " Se valida dentro de todo el periodo
*          lv_validfrom = ls_companyrelepproduct->validfrom.
*          lv_validfrom = |{ lv_validfrom(6) }{ '01' }|.
*          lv_validto = ls_companyrelepproduct->validto.
*          TRY.
*              zcl_amdp_interco_relationships=>get_last_day( EXPORTING iv_date = lv_validto
*                                                            IMPORTING ev_date = lv_validto ).
*            CATCH cx_amdp_execution_failed INTO DATA(lo_excepcion).
*              lv_validto = ls_companyrelepproduct->validto.
*          ENDTRY.

          SELECT SINGLE id FROM @lt_companyprod AS ltcomprod
            WHERE ltcomprod~id                   <> @ls_companyrelepproduct->id
              AND ltcomprod~providercompanycode   = @ls_companyrelepproduct->providercompanycode
              AND ltcomprod~recipientcompanycode  = @ls_companyrelepproduct->recipientcompanycode
              AND ltcomprod~product               = @ls_companyrelepproduct->product
              AND ltcomprod~profitcenter          = @ls_companyrelepproduct->profitcenter
              AND ltcomprod~flow                  = @ls_companyrelepproduct->Flow
              AND ltcomprod~Validfrom            <= @ls_companyrelepproduct->Validfrom
              AND ltcomprod~Validto              >= @ls_companyrelepproduct->Validto
            INTO @DATA(ls_exist).
          IF ls_exist IS NOT INITIAL.
            CLEAR ls_exist.

            APPEND VALUE #( %key = ls_compprod->%key ) TO failed-zi_intercocompanyrelproduct.
            APPEND VALUE #( %key = ls_compprod->%key
                            %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                                number   = '041'
                                                v1       = lv_index
                                                severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD block.
    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
         ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_companyrelationshipproduct).

    READ TABLE lt_companyrelationshipproduct REFERENCE INTO DATA(ls_companyrelationshipproduct) INDEX 1.

    IF ls_companyrelationshipproduct->isblocked = 'X'.
      APPEND VALUE #( %key = ls_companyrelationshipproduct->%key ) TO failed-zi_intercocompanyrelproduct.
      APPEND VALUE #( %key = ls_companyrelationshipproduct->%key
                      %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                          number   = '017'
                                          severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
    ELSEIF ls_companyrelationshipproduct->isdeleted = 'X'.
      APPEND VALUE #( %key = ls_companyrelationshipproduct->%key ) TO failed-zi_intercocompanyrelproduct.
      APPEND VALUE #( %key = ls_companyrelationshipproduct->%key
                      %msg = new_message( id       = 'ZINT_MSG_INTERCO_MD'
                                          number   = '018'
                                          severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
    ELSE.
      MODIFY ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
             ENTITY zi_intercocompanyrelproduct
             UPDATE
             FIELDS ( isblocked )
             WITH VALUE #( FOR ls_key IN keys
                           ( %tky      = ls_key-%tky
                             isblocked = 'X' ) )
             FAILED failed
             REPORTED reported.
    ENDIF.
  ENDMETHOD.

  METHOD release.
    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
        ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_companyrelationshipproduct).

    READ TABLE lt_companyrelationshipproduct REFERENCE INTO DATA(ls_companyrelationshipproduct) INDEX 1.

    IF ls_companyrelationshipproduct->isblocked = ''.
      APPEND VALUE #( %key = ls_companyrelationshipproduct->%key ) TO failed-zi_intercocompanyrelproduct.
      APPEND VALUE #( %key = ls_companyrelationshipproduct->%key %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '019' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
    ELSE.
      MODIFY ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
        ENTITY zi_intercocompanyrelproduct
        UPDATE
        FIELDS ( isblocked )
        WITH VALUE #( FOR ls_key IN keys
                      ( %tky      = ls_key-%tky
                        isblocked = ''
                      )
      )
        FAILED failed
        REPORTED reported.
    ENDIF.
  ENDMETHOD.

  METHOD setdelete.
    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
        ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_companyrelationshipproduct).

    READ TABLE lt_companyrelationshipproduct ASSIGNING FIELD-SYMBOL(<fs_comprelproduct>) INDEX 1.

    IF <fs_comprelproduct>-isdeleted = ''.

      <fs_comprelproduct>-isdeleted = 'X'.

      MODIFY ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
          ENTITY zi_intercocompanyrelproduct
          UPDATE FIELDS ( isdeleted )
          WITH CORRESPONDING #( lt_companyrelationshipproduct )
          FAILED failed
          REPORTED reported.

      "MODIFY ENTITIES OF ZI_IntercoCompanyRelProduct
      "    ENTITY ZI_IntercoCompanyRelProduct
      "    UPDATE
      "    FIELDS ( IsDeleted )
      "    WITH VALUE #( FOR ls_key IN keys
      "                 ( %tky         = ls_key-%tky
      "                   IsDeleted     = 'X'
      "                  )
      "               )
      "    FAILED failed
      "    REPORTED reported.

      IF failed IS NOT INITIAL.

      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD deleteDraft.

    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
       ENTITY zi_intercocompanyrelproduct ALL FIELDS WITH CORRESPONDING #( keys )
       RESULT DATA(lt_companyproduct).

    TRY.
        zcl_amdp_interco_relationships=>get_drafts_interco( EXPORTING iv_type   = '1'
                                                            IMPORTING et_drafts = DATA(lt_drafts) ).
      CATCH cx_amdp_execution_failed.
        RETURN.
    ENDTRY.

    IF lt_drafts[] IS NOT INITIAL.
*      MODIFY ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
*       ENTITY zi_intercocompanyrelproduct
*          EXECUTE Discard FROM
*         VALUE #( FOR ls_key IN lt_drafts
*                   ( Id        = ls_key-id
*                    )
*                 )
*            REPORTED DATA(discard_reported)
*            FAILED DATA(discard_failed)
*            MAPPED DATA(discard_mapped).
    ENDIF.

  ENDMETHOD.

  METHOD uploadCompProducts.
    DATA lt_companyproduct TYPE TABLE FOR CREATE zi_intercocompanyrelproduct.

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
      APPEND VALUE #( %cid = <fs_key>-%cid ) TO failed-zi_intercocompanyrelproduct.
      APPEND VALUE #( %cid = <fs_key>-%cid %msg = new_message( id = 'ZHOM_MONITOR_NFE' number = '800' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.
      RETURN.
    ENDIF.

    DATA(lcl_interco_upload) = NEW zcl_interco_master_upload( ).
    DATA(lt_data) = lcl_interco_upload->upload_companyproduct( is_params = CONV #( <fs_key>-%param ) ).

    IF lt_data[] IS INITIAL.
      APPEND VALUE #( %cid = <fs_key>-%cid ) TO failed-zi_intercocompanyrelproduct.
      APPEND VALUE #( %cid = <fs_key>-%cid %msg = new_message( id = 'ZINT_MSG_INTERCO_MD' number = '051' severity = if_abap_behv_message=>severity-error ) ) TO reported-zi_intercocompanyrelproduct.

    ELSE.
      " sumo uno al indice, porque el archivo tiene el encabezado
      GET TIME STAMP FIELD DATA(lv_tmtmpl).
      lt_companyproduct = VALUE #( FOR ls_data IN lt_data INDEX INTO lv_index
                                   ( %cid                 = lv_index + 1
                                     Product              = ls_data-material
                                     ProviderCompanyCode  = ls_data-providerCompany
                                     RecipientCompanyCode = ls_data-recipientcompany
                                     ProfitCenter         = |{ ls_data-profitCenter ALPHA = IN }|
                                     ValidFrom            = ls_data-validFrom
                                     ValidTo              = ls_data-validTo
                                     Flow                 = ls_data-flow
                                     rate                 = ls_data-rate
*                                     IsPromo              = ls_data-ispromo
                                     IsPromo              = abap_false
                                     CreatedBy            = sy-uname
                                     CreatedAt            = lv_tmtmpl
                                     zindex               = lv_index + 1 ) ).
      LOOP AT lt_companyproduct ASSIGNING FIELD-SYMBOL(<fs_row>).
        IF <fs_row>-ValidFrom IS NOT INITIAL.
          <fs_row>-ValidFrom+6(2) = '01'.
        ENDIF.
        IF <fs_row>-ValidTo <> '99991231'.
          get_last_day_of_month( EXPORTING day_in            = <fs_row>-ValidTo
                                 IMPORTING last_day_of_month = <fs_row>-ValidTo ).
        ENDIF.
      ENDLOOP.

      TRY.
          MODIFY ENTITIES OF ZI_IntercoCompanyRelProduct IN LOCAL MODE
                 ENTITY ZI_IntercoCompanyRelProduct
                 CREATE FIELDS ( Product ProviderCompanyCode RecipientCompanyCode ProfitCenter ValidFrom ValidTo rate flow ispromo zindex CreatedBy CreatedAt )
                 WITH lt_companyproduct[]
                 MAPPED mapped
                 FAILED failed
                 REPORTED reported.

        CATCH cx_root INTO DATA(lo_ex). " TODO: variable is assigned but never used (ABAP cleaner)

      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD get_last_day_of_month.
    CONSTANTS december TYPE c LENGTH 2 VALUE '12'.
    CONSTANTS first    TYPE c LENGTH 2 VALUE '01'.

    DATA: BEGIN OF date,
            j TYPE c LENGTH 4,
            m TYPE c LENGTH 2,
            t TYPE c LENGTH 2,
          END OF date.

    DATA lv_month TYPE n LENGTH 2.

    date = day_in.

    " For December of any year: last day is always the 31st
    IF date-m = december.
      date-t = '31'.
      last_day_of_month = date.
    ELSE.
      " For other months: go to day 1 of next month and subtract 1
      lv_month = date-m + 1.
      date-m = lv_month.
      date-t = first.
      last_day_of_month = date.
      last_day_of_month -= 1.
    ENDIF.
  ENDMETHOD.

  METHOD DeterValidFrom.
    IF keys IS INITIAL.
      RETURN.
    ENDIF.
    ASSIGN keys[ 1 ] TO FIELD-SYMBOL(<fs_key>).

    IF <fs_key> IS NOT ASSIGNED.
      RETURN.
    ENDIF.

    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
         ENTITY ZI_IntercoCompanyRelProduct
         FIELDS ( ValidFrom ValidTo )
         WITH CORRESPONDING #( keys )
         RESULT DATA(lt_companyProducts).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ASSIGN lt_companyproducts[ 1 ] TO FIELD-SYMBOL(<fs_prod>).
    IF sy-subrc = 0.
      IF <fs_prod>-ValidFrom+6(2) <> '01' OR <fs_prod>-ValidTo IS INITIAL.
        <fs_prod>-ValidFrom+6(2) = '01'.
        IF <fs_prod>-ValidTo <> '99991231'.
          get_last_day_of_month( EXPORTING day_in            = <fs_prod>-ValidFrom
                                 IMPORTING last_day_of_month = <fs_prod>-ValidTo ).

        ENDIF.

        UNASSIGN <fs_prod>.

        MODIFY ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
               ENTITY ZI_IntercoCompanyRelProduct
               UPDATE FIELDS ( ValidFrom ValidTo )
               WITH CORRESPONDING #( lt_companyProducts ).
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

    READ ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
         ENTITY ZI_IntercoCompanyRelProduct
         FIELDS ( ValidTo )
         WITH CORRESPONDING #( keys )
         RESULT DATA(lt_companyProducts).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    ASSIGN lt_companyproducts[ 1 ] TO FIELD-SYMBOL(<fs_prod>).
    IF sy-subrc = 0.
      IF <fs_prod>-ValidTo <> '99991231'.
        DATA(lv_validTo) = zcl_interco_utils=>rp_last_day_of_months( day_in = <fs_prod>-ValidTo ).
*        get_last_day_of_month( EXPORTING day_in            = <fs_prod>-ValidTo
*                               IMPORTING last_day_of_month = DATA(lv_validTo) ).
        IF lv_validTo <> <fs_prod>-ValidTo.
          <fs_prod>-ValidTo = lv_validTo.
          MODIFY ENTITIES OF zi_intercocompanyrelproduct IN LOCAL MODE
                 ENTITY ZI_IntercoCompanyRelProduct
                 UPDATE FIELDS ( ValidTo )
                 WITH CORRESPONDING #( lt_companyProducts ).
        ENDIF.
      ENDIF.

    ENDIF.
  ENDMETHOD.

ENDCLASS.
