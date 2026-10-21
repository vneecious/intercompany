CLASS lsc_zr_intercojeitemhelperclas DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zr_intercojeitemhelperclas IMPLEMENTATION.

  METHOD save_modified.

    LOOP AT create-header REFERENCE INTO DATA(header).

      IF header->isruleprocessed = abap_true AND header->isexemptionprocessed = abap_true.
        CONTINUE.
      ENDIF.

      RAISE ENTITY EVENT zr_intercojeitemhelperclass~applyrulesrequested
          FROM VALUE #( ( %key = header->%key ) ).
    ENDLOOP.

    LOOP AT update-header REFERENCE INTO header.

      IF header->isruleprocessed = abap_true AND header->isexemptionprocessed = abap_true.
        CONTINUE.
      ENDIF.

      RAISE ENTITY EVENT zr_intercojeitemhelperclass~applyrulesrequested
          FROM VALUE #( ( %key = header->%key ) ).
    ENDLOOP.

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

    READ ENTITIES OF zr_intercojeitemhelperclass IN LOCAL MODE
        ENTITY header
            FIELDS ( isruleprocessed isexemptionprocessed )
            WITH CORRESPONDING #( keys )
            RESULT DATA(classification_headers).

    LOOP AT keys REFERENCE INTO DATA(key).
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
