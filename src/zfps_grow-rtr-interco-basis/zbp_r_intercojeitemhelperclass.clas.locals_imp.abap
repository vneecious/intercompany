CLASS lsc_zr_intercojeitemhelperclas DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zr_intercojeitemhelperclas IMPLEMENTATION.

  METHOD save_modified.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: paso 6a, coordinación de eventos
    " ANTES: se conserva completo el cuerpo anterior como referencia.
    " Se evita duplicar la solicitud al resetear los padres E/L junto con
    " su coordinadora vacía; el comportamiento anterior fuera de ese caso queda igual.
    "
    "     LOOP AT create-header REFERENCE INTO DATA(header).
    "
    "       IF header->isruleprocessed = abap_true AND header->isexemptionprocessed = abap_true.
    "         CONTINUE.
    "       ENDIF.
    "
    "       RAISE ENTITY EVENT zr_intercojeitemhelperclass~applyrulesrequested
    "           FROM VALUE #( ( %key = header->%key ) ).
    "     ENDLOOP.
    "
    "     LOOP AT update-header REFERENCE INTO header.
    "
    "       IF header->isruleprocessed = abap_true AND header->isexemptionprocessed = abap_true.
    "         CONTINUE.
    "       ENDIF.
    "
    "       RAISE ENTITY EVENT zr_intercojeitemhelperclass~applyrulesrequested
    "           FROM VALUE #( ( %key = header->%key ) ).
    "     ENDLOOP.
    "

    " AHORA: identificar la solicitud coordinada sin modificar tablas ni CDS.
    DATA pending_coordinators
      TYPE HASHED TABLE OF zr_intercojeitemhelperclass
      WITH UNIQUE KEY companycode fiscalyear fiscalperiod ledger paymenttype.

    " Registrar solo coordinadoras pendientes incluidas en este guardado.
    " Una coordinadora ya procesada no debe bloquear eventos anteriores E/L.
    LOOP AT create-header REFERENCE INTO DATA(coordinator_create).
      IF coordinator_create->paymenttype IS INITIAL
         AND ( coordinator_create->isruleprocessed <> abap_true
            OR coordinator_create->isexemptionprocessed <> abap_true ).
        INSERT CORRESPONDING #( coordinator_create->* )
          INTO TABLE pending_coordinators.
      ENDIF.
    ENDLOOP.

    LOOP AT update-header REFERENCE INTO DATA(coordinator_update).
      IF coordinator_update->paymenttype IS INITIAL
         AND ( coordinator_update->isruleprocessed <> abap_true
            OR coordinator_update->isexemptionprocessed <> abap_true ).
        INSERT CORRESPONDING #( coordinator_update->* )
          INTO TABLE pending_coordinators.
      ENDIF.
    ENDLOOP.

    LOOP AT create-header REFERENCE INTO DATA(header).

      " Evitar otra ejecución para los padres E/L del mismo ámbito.
      " Sin coordinadora pendiente en este guardado, conservar el flujo anterior.
      IF ( header->paymenttype = 'E' OR header->paymenttype = 'L' )
         AND line_exists( pending_coordinators[
           companycode  = header->companycode
           fiscalyear   = header->fiscalyear
           fiscalperiod = header->fiscalperiod
           ledger       = header->ledger
           paymenttype  = space ] ).
        CONTINUE.
      ENDIF.

      IF header->isruleprocessed = abap_true AND header->isexemptionprocessed = abap_true.
        CONTINUE.
      ENDIF.

      RAISE ENTITY EVENT zr_intercojeitemhelperclass~applyrulesrequested
          FROM VALUE #( ( %key = header->%key ) ).
    ENDLOOP.

    LOOP AT update-header REFERENCE INTO header.

      " Evitar otra ejecución para los padres E/L del mismo ámbito.
      " Sin coordinadora pendiente en este guardado, conservar el flujo anterior.
      IF ( header->paymenttype = 'E' OR header->paymenttype = 'L' )
         AND line_exists( pending_coordinators[
           companycode  = header->companycode
           fiscalyear   = header->fiscalyear
           fiscalperiod = header->fiscalperiod
           ledger       = header->ledger
           paymenttype  = space ] ).
        CONTINUE.
      ENDIF.

      IF header->isruleprocessed = abap_true AND header->isexemptionprocessed = abap_true.
        CONTINUE.
      ENDIF.

      RAISE ENTITY EVENT zr_intercojeitemhelperclass~applyrulesrequested
          FROM VALUE #( ( %key = header->%key ) ).
    ENDLOOP.

    " Fin EXT_OSCUGALD 06.10.2026 - C12

  ENDMETHOD.

ENDCLASS.

CLASS lhc_zr_intercojeitemhelperclas DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR header RESULT result.
    METHODS applyrules FOR MODIFY
      IMPORTING keys FOR ACTION header~applyrules.

ENDCLASS.

CLASS lhc_zr_intercojeitemhelperclas IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD applyrules.
    DATA creates TYPE TABLE OF zr_intercojeitemhelperclass.
    DATA updates TYPE TABLE OF zr_intercojeitemhelperclass.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: normalizar clave de ejecución
    " E/L es resultado de la regla ganadora, no un filtro de la pantalla.
    " Se conserva PaymentType en la clave, con valor vacío.
    DATA normalized_keys TYPE TABLE FOR READ IMPORT zr_intercojeitemhelperclass.
    normalized_keys = CORRESPONDING #( keys ).

    LOOP AT normalized_keys REFERENCE INTO DATA(normalized_key).
      CLEAR normalized_key->paymenttype.
    ENDLOOP.

    " Evitar cabeceras duplicadas si llegan E y L para el mismo ámbito.
    SORT normalized_keys BY companycode fiscalyear fiscalperiod ledger paymenttype.
    DELETE ADJACENT DUPLICATES FROM normalized_keys
      COMPARING companycode fiscalyear fiscalperiod ledger paymenttype.
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: buscar cabecera unificada
    READ ENTITIES OF zr_intercojeitemhelperclass IN LOCAL MODE
        ENTITY header
            FIELDS ( isruleprocessed isexemptionprocessed )
            " WITH CORRESPONDING #( keys )
            WITH normalized_keys
            RESULT DATA(classification_headers).
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: usar claves normalizadas
    " LOOP AT keys REFERENCE INTO DATA(key).
    LOOP AT normalized_keys REFERENCE INTO DATA(key).
      " Fin EXT_OSCUGALD 06.10.2026 - C12
      IF NOT line_exists( classification_headers[ %key = key->%key ] ).
        APPEND INITIAL LINE TO creates REFERENCE INTO DATA(create).
        create->* = CORRESPONDING #( key->* ).
        CONTINUE.
      ENDIF.

      DATA(classification_header) = REF #( classification_headers[ %key = key->%key ] ).
      IF classification_header->isexemptionprocessed = abap_true AND
         classification_header->isruleprocessed = abap_true.
        APPEND INITIAL LINE TO updates REFERENCE INTO DATA(update).
        update->* = CORRESPONDING #( classification_header->* ).
      ENDIF.
    ENDLOOP.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: paso 6b, sincronizar estados E/L
    " Ampliación aditiva: no se reemplaza código anterior.
    " Capturar solo los ámbitos donde se programó una nueva corrida.
    " Si la coordinadora ya está pendiente, no reiniciar sus padres otra vez.
    DATA scheduled_scopes TYPE TABLE OF zr_intercojeitemhelperclass.
    scheduled_scopes = creates.
    APPEND LINES OF updates TO scheduled_scopes.

    IF scheduled_scopes IS NOT INITIAL.

      DATA result_parent_keys
        TYPE TABLE FOR READ IMPORT zr_intercojeitemhelperclass.

      " Buscar ambos padres del mismo ámbito; no crear los que no existan.
      result_parent_keys = VALUE #(
        FOR scheduled_scope IN scheduled_scopes
        ( companycode  = scheduled_scope-companycode
          fiscalyear   = scheduled_scope-fiscalyear
          fiscalperiod = scheduled_scope-fiscalperiod
          ledger       = scheduled_scope-ledger
          paymenttype  = 'E' )
        ( companycode  = scheduled_scope-companycode
          fiscalyear   = scheduled_scope-fiscalyear
          fiscalperiod = scheduled_scope-fiscalperiod
          ledger       = scheduled_scope-ledger
          paymenttype  = 'L' ) ).

      READ ENTITIES OF zr_intercojeitemhelperclass IN LOCAL MODE
        ENTITY header
          FIELDS ( isruleprocessed isexemptionprocessed )
          WITH result_parent_keys
          RESULT DATA(result_parent_headers).

      " El UPDATE existente selecciona ambos flags y envía solo las claves:
      " sus valores iniciales dejan coordinadora y padres en pendiente.
      " CreatedAt, CreatedBy y resultados CI/CE no se modifican aquí.
      LOOP AT result_parent_headers INTO DATA(result_parent_header).
        APPEND CORRESPONDING #( result_parent_header ) TO updates.
      ENDLOOP.

    ENDIF.
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zr_intercojeitemhelperclass IN LOCAL MODE
          ENTITY header
              UPDATE FIELDS ( isexemptionprocessed isruleprocessed )
                WITH VALUE #( FOR u IN updates
                              ( %key = VALUE #(
                                                companycode  = u-companycode
                                                fiscalperiod = u-fiscalperiod
                                                fiscalyear   = u-fiscalyear
                                                ledger       = u-ledger
                                                paymenttype  = u-paymenttype ) )
                            ).
    ENDIF.

    IF creates IS NOT INITIAL.
      MODIFY ENTITIES OF zr_intercojeitemhelperclass IN LOCAL MODE
         ENTITY header
             CREATE AUTO FILL CID FIELDS ( companycode fiscalperiod fiscalyear ledger paymenttype )
             WITH VALUE #( FOR c IN creates (
                           companycode  = c-companycode
                           fiscalyear   = c-fiscalyear
                           fiscalperiod = c-fiscalperiod
                           ledger       = c-ledger
                           paymenttype  = c-paymenttype ) )
             FAILED failed
             REPORTED reported
             MAPPED mapped.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
