CLASS lhc_glaccountdetermination DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR GLAccountDetermination
        RESULT result,
      ValidateDuplicated FOR VALIDATE ON SAVE
        IMPORTING keys FOR GLAccountDetermination~ValidateDuplicated,
      " DF-461 - DS4K9B6E12 - 07.10.2026: validacion del intervalo de vigencia
      ValidateValidTo FOR VALIDATE ON SAVE
        IMPORTING keys FOR GLAccountDetermination~ValidateValidTo.
ENDCLASS.

CLASS lhc_glaccountdetermination IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD ValidateDuplicated.
    " ============================================================================
    " INICIO CORRECCION - DF-461 - DS4K9B6E12 - 07.10.2026
    " Descripcion: la validacion de duplicados no consideraba la vigencia del
    " registro (ValidFrom/ValidTo). Bloqueaba cualquier segundo registro con la
    " misma combinacion aunque los periodos no se solaparan, y no ignoraba los
    " registros con borrado logico. Ahora un registro es duplicado solo si:
    "   - coincide la combinacion de campos de negocio,
    "   - su periodo de vigencia se solapa con el de otro registro,
    "   - el otro registro no esta marcado como borrado (IsDeleted).
    " Se reemplaza el ASSIGN sobre tabla SORTED NON-UNIQUE (tomaba solo la
    " primera coincidencia) por un REDUCE ... WHERE sobre todas las coincidencias.
    " La version original queda comentada al final de la clase.
    " ============================================================================
    READ ENTITIES OF zr_intercoglacctdetermination IN LOCAL MODE
      ENTITY GLAccountDetermination
      FIELDS ( ValidFrom ValidTo DocType ProviderCompanyCode RecipientCompanyCode
               Product Depto PAndLID TariffType OperationType IsDeleted )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_current_data).

    IF lt_current_data IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT lt_current_data ASSIGNING FIELD-SYMBOL(<fs_norm>).
      <fs_norm>-Product = condense( <fs_norm>-Product ).
    ENDLOOP.

    " Registros activos de la misma combinacion cuyo periodo se solapa
    SELECT id, valid_from, valid_to, doc_type, provider_company_code,
           recipient_company_code, product, depto, p_and_l_id,
           tariff_type, operation_type
      FROM zint_a_md_glacct
      FOR ALL ENTRIES IN @lt_current_data
      WHERE doc_type               = @lt_current_data-DocType
        AND provider_company_code  = @lt_current_data-ProviderCompanyCode
        AND recipient_company_code = @lt_current_data-RecipientCompanyCode
        AND product                = @lt_current_data-Product
        AND depto                  = @lt_current_data-Depto
        AND p_and_l_id             = @lt_current_data-PAndLID
        AND tariff_type            = @lt_current_data-TariffType
        AND operation_type         = @lt_current_data-OperationType
        AND valid_from            <= @lt_current_data-ValidTo
        AND valid_to              >= @lt_current_data-ValidFrom
        AND is_deleted             = @abap_false
      INTO TABLE @DATA(lt_db_overlaps).

    LOOP AT lt_current_data REFERENCE INTO DATA(ls_current).

      APPEND VALUE #( %tky = ls_current->%tky %state_area = 'VALIDATE_DUPLICATED' ) TO reported-glaccountdetermination.

      " Un registro marcado como borrado no compite por la vigencia
      IF ls_current->IsDeleted = abap_true.
        CONTINUE.
      ENDIF.

      " Cantidad de registros de otra ID con la misma combinacion y periodo solapado
      DATA(lv_overlaps) = REDUCE i( INIT n = 0
                                    FOR ls_db IN lt_db_overlaps
                                    WHERE ( doc_type               = ls_current->DocType
                                        AND provider_company_code  = ls_current->ProviderCompanyCode
                                        AND recipient_company_code = ls_current->RecipientCompanyCode
                                        AND product                = ls_current->Product
                                        AND depto                  = ls_current->Depto
                                        AND p_and_l_id             = ls_current->PAndLID
                                        AND tariff_type            = ls_current->TariffType
                                        AND operation_type         = ls_current->OperationType
                                        AND valid_from            <= ls_current->ValidTo
                                        AND valid_to              >= ls_current->ValidFrom
                                        AND id                    <> ls_current->ID )
                                    NEXT n = n + 1 ).

      IF lv_overlaps > 0.
        APPEND VALUE #( %tky = ls_current->%tky ) TO failed-glaccountdetermination.

        APPEND VALUE #( %tky               = ls_current->%tky
                        %state_area        = 'VALIDATE_DUPLICATED'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                                               textid   = zcl_fi_intrc_messages=>date_overlaps
                                               severity = if_abap_behv_message=>severity-error )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on
        ) TO reported-glaccountdetermination.
      ENDIF.
    ENDLOOP.
    " ============================================================================
    " FIN CORRECCION - DF-461 - DS4K9B6E12 - 07.10.2026
    " ============================================================================
  ENDMETHOD.

  METHOD ValidateValidTo.
    " ============================================================================
    " INICIO CORRECCION - DF-461 - DS4K9B6E12 - 07.10.2026
    " Descripcion: valida el intervalo de vigencia del registro.
    "   - ValidFrom y ValidTo son obligatorios (ZFI_INTERCO 203)
    "   - ValidFrom no puede ser mayor que ValidTo (ZFI_INTERCO 202)
    " ============================================================================
    READ ENTITIES OF zr_intercoglacctdetermination IN LOCAL MODE
      ENTITY GLAccountDetermination
      FIELDS ( ValidFrom ValidTo )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_current_data).

    LOOP AT lt_current_data REFERENCE INTO DATA(ls_current).

      APPEND VALUE #( %tky = ls_current->%tky %state_area = 'VALIDATE_DATE_INTERVAL' ) TO reported-glaccountdetermination.

      IF ls_current->ValidFrom IS INITIAL OR ls_current->ValidTo IS INITIAL.

        APPEND VALUE #( %tky = ls_current->%tky ) TO failed-glaccountdetermination.

        APPEND VALUE #( %tky               = ls_current->%tky
                        %state_area        = 'VALIDATE_DATE_INTERVAL'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                                               textid   = zcl_fi_intrc_messages=>field_required
                                               severity = if_abap_behv_message=>severity-error )
                        %element-ValidFrom = COND #( WHEN ls_current->ValidFrom IS INITIAL THEN if_abap_behv=>mk-on )
                        %element-ValidTo   = COND #( WHEN ls_current->ValidTo   IS INITIAL THEN if_abap_behv=>mk-on )
        ) TO reported-glaccountdetermination.

      ELSEIF ls_current->ValidFrom > ls_current->ValidTo.

        APPEND VALUE #( %tky = ls_current->%tky ) TO failed-glaccountdetermination.

        APPEND VALUE #( %tky               = ls_current->%tky
                        %state_area        = 'VALIDATE_DATE_INTERVAL'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                                               textid   = zcl_fi_intrc_messages=>date_interval
                                               severity = if_abap_behv_message=>severity-error )
                        %element-ValidFrom = if_abap_behv=>mk-on
                        %element-ValidTo   = if_abap_behv=>mk-on
        ) TO reported-glaccountdetermination.
      ENDIF.
    ENDLOOP.
    " ============================================================================
    " FIN CORRECCION - DF-461 - DS4K9B6E12 - 07.10.2026
    " ============================================================================
  ENDMETHOD.

* ============================================================================
* DF-461 - DS4K9B6E12 - 07.10.2026
* Version original de ValidateDuplicated (comentada, no se elimina):
* ============================================================================
*  METHOD ValidateDuplicated.
*    " 1. Tipado explícito para cumplir con Clean Core y mejorar rendimiento
*    TYPES: BEGIN OF ty_db_key,
*             doc_type               TYPE zint_txbr_doctype,
*             provider_company_code  TYPE bukrs,
*             recipient_company_code TYPE bukrs,
*             product                TYPE matnr,
*             depto                  TYPE zint_depto,
*             p_and_l_id             TYPE zint_dte_pandlid,
*             tariff_type            TYPE zint_tariff_type,
*             operation_type         TYPE zint_operation_type,
*             id                     TYPE sysuuid_x16,
*           END OF ty_db_key.
*
*    " Tabla organizada para búsquedas rápidas (evita SORT y LOOP WHERE ineficiente)
*    DATA lt_db_duplicates TYPE SORTED TABLE OF ty_db_key
*      WITH NON-UNIQUE KEY doc_type provider_company_code recipient_company_code product depto p_and_l_id tariff_type operation_type.
*
*    " 2. Leer Draft
*    READ ENTITIES OF zr_intercoglacctdetermination IN LOCAL MODE
*      ENTITY GLAccountDetermination
*      ALL FIELDS WITH CORRESPONDING #( keys )
*      RESULT DATA(lt_current_data).
*
*    IF lt_current_data IS INITIAL. RETURN. ENDIF.
*
*    LOOP AT lt_current_data ASSIGNING FIELD-SYMBOL(<fs_norm>).
*      <fs_norm>-GlAccount1 = |{ <fs_norm>-GlAccount1 ALPHA = IN }|.
*      <fs_norm>-GlAccount2 = |{ <fs_norm>-GlAccount2 ALPHA = IN }|.
*      <fs_norm>-Product = condense( <fs_norm>-Product ).
*    ENDLOOP.
*    " 3. Buscar en DB (SELECT directo a la Sorted Table)
*    SELECT id, doc_type, provider_company_code, recipient_company_code,
*           product, depto, p_and_l_id, tariff_type, operation_type
*      FROM zint_a_md_glacct
*      FOR ALL ENTRIES IN @lt_current_data
*      WHERE doc_type               = @lt_current_data-DocType
*        AND provider_company_code  = @lt_current_data-ProviderCompanyCode
*        AND recipient_company_code = @lt_current_data-RecipientCompanyCode
*        AND product                = @lt_current_data-Product
*        AND depto                  = @lt_current_data-Depto
*        AND p_and_l_id             = @lt_current_data-PAndLID
*        AND tariff_type            = @lt_current_data-TariffType
*        AND operation_type         = @lt_current_data-OperationType
*      INTO CORRESPONDING FIELDS OF TABLE @lt_db_duplicates.
*
*    " 4. Procesamiento de validación
*    LOOP AT lt_current_data REFERENCE INTO DATA(ls_current).
*
*      APPEND VALUE #( %tky = ls_current->%tky %state_area = 'VALIDATE_DUPLICATED' ) TO reported-glaccountdetermination.
*
*      " Búsqueda binaria implícita por clave
*      " Usamos la referencia para validar el ID después de encontrar la línea
*      ASSIGN lt_db_duplicates[
*                        doc_type               = ls_current->DocType
*                        provider_company_code  = ls_current->ProviderCompanyCode
*                        recipient_company_code = ls_current->RecipientCompanyCode
*                        product                = ls_current->Product
*                        depto                  = ls_current->Depto
*                        p_and_l_id             = ls_current->PAndLID
*                        tariff_type            = ls_current->TariffType
*                        operation_type         = ls_current->OperationType
*                    ] TO FIELD-SYMBOL(<ls_db_match>).
*
*      " Si existe y el ID es diferente, entonces es un duplicado real
*      IF sy-subrc = 0 AND <ls_db_match>-id <> ls_current->id.
*
*        APPEND VALUE #( %tky = ls_current->%tky ) TO failed-glaccountdetermination.
*
*        APPEND VALUE #( %tky        = ls_current->%tky
*                        %state_area = 'VALIDATE_DUPLICATED'
*                        %msg        = new_message(
*                                        id       = 'ZFI_INTERCO'
*                                        number   = '212'
*                                        severity = if_abap_behv_message=>severity-error )
*                        %element-DocType              = if_abap_behv=>mk-on
*                        %element-ProviderCompanyCode  = if_abap_behv=>mk-on
*                        %element-RecipientCompanyCode = if_abap_behv=>mk-on
*                        %element-Product              = if_abap_behv=>mk-on
*                        %element-Depto                = if_abap_behv=>mk-on
*        ) TO reported-glaccountdetermination.
*      ENDIF.
*    ENDLOOP.
*  ENDMETHOD.

ENDCLASS.
