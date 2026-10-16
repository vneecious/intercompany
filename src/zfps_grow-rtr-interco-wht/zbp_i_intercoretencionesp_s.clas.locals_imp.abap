CLASS LHC_RAP_TDAT_CTS DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS:
      GET
        RETURNING
          VALUE(RESULT) TYPE REF TO IF_MBC_CP_RAP_TDAT_CTS.

ENDCLASS.

CLASS LHC_RAP_TDAT_CTS IMPLEMENTATION.
  METHOD GET.
    result = mbc_cp_api=>rap_tdat_cts( tdat_name = 'ZINTERCORETENCIONESP'
                                       table_entity_relations = VALUE #(
                                         ( entity = 'IntercoRetencionesP' table = 'ZINTER_WHT_ZUONR' )
                                       ) ) ##NO_TEXT.
  ENDMETHOD.
ENDCLASS.
CLASS LHC_ZI_INTERCORETENCIONESP_S DEFINITION FINAL INHERITING FROM CL_ABAP_BEHAVIOR_HANDLER.
  PRIVATE SECTION.
    METHODS:
      GET_INSTANCE_FEATURES FOR INSTANCE FEATURES
        IMPORTING
          KEYS REQUEST requested_features FOR IntercoRetencionAll
        RESULT result,
      SELECTCUSTOMIZINGTRANSPTREQ FOR MODIFY
        IMPORTING
          KEYS FOR ACTION IntercoRetencionAll~SelectCustomizingTransptReq
        RESULT result,
      GET_GLOBAL_AUTHORIZATIONS FOR GLOBAL AUTHORIZATION
        IMPORTING
           REQUEST requested_authorizations FOR IntercoRetencionAll
        RESULT result.
ENDCLASS.

CLASS LHC_ZI_INTERCORETENCIONESP_S IMPLEMENTATION.
  METHOD GET_INSTANCE_FEATURES.
    DATA: selecttransport_flag TYPE abp_behv_flag VALUE if_abap_behv=>fc-o-enabled,
          edit_flag            TYPE abp_behv_flag VALUE if_abap_behv=>fc-o-enabled.

    IF lhc_rap_tdat_cts=>get( )->is_editable( ) = abap_false.
      edit_flag = if_abap_behv=>fc-o-disabled.
    ENDIF.
    IF lhc_rap_tdat_cts=>get( )->is_transport_allowed( ) = abap_false.
      selecttransport_flag = if_abap_behv=>fc-o-disabled.
    ENDIF.
    READ ENTITIES OF ZI_IntercoRetencionesP_S IN LOCAL MODE
    ENTITY IntercoRetencionAll
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(all).
    IF all[ 1 ]-%IS_DRAFT = if_abap_behv=>mk-off.
      selecttransport_flag = if_abap_behv=>fc-o-disabled.
    ENDIF.
    result = VALUE #( (
               %TKY = all[ 1 ]-%TKY
               %ACTION-edit = edit_flag
               %ASSOC-_IntercoRetencionesP = edit_flag
               %ACTION-SelectCustomizingTransptReq = selecttransport_flag ) ).
  ENDMETHOD.
  METHOD SELECTCUSTOMIZINGTRANSPTREQ.
    MODIFY ENTITIES OF ZI_IntercoRetencionesP_S IN LOCAL MODE
      ENTITY IntercoRetencionAll
        UPDATE FIELDS ( TransportRequestID HideTransport )
        WITH VALUE #( FOR key IN keys
                        ( %TKY               = key-%TKY
                          TransportRequestID = key-%PARAM-transportrequestid
                          HideTransport      = abap_false ) ).

    READ ENTITIES OF ZI_IntercoRetencionesP_S IN LOCAL MODE
      ENTITY IntercoRetencionAll
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(entities).
    result = VALUE #( FOR entity IN entities
                        ( %TKY   = entity-%TKY
                          %PARAM = entity ) ).
  ENDMETHOD.
  METHOD GET_GLOBAL_AUTHORIZATIONS.
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM' ID 'TABLE' FIELD 'ZI_INTERCORETENCIONESP' ID 'ACTVT' FIELD '02'.
    DATA(is_authorized) = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                  ELSE if_abap_behv=>auth-unauthorized ).
    result-%UPDATE      = is_authorized.
    result-%ACTION-Edit = is_authorized.
    result-%ACTION-SelectCustomizingTransptReq = is_authorized.
  ENDMETHOD.
ENDCLASS.
CLASS LSC_ZI_INTERCORETENCIONESP_S DEFINITION FINAL INHERITING FROM CL_ABAP_BEHAVIOR_SAVER.
  PROTECTED SECTION.
    METHODS:
      SAVE_MODIFIED REDEFINITION,
      CLEANUP_FINALIZE REDEFINITION.
ENDCLASS.

CLASS LSC_ZI_INTERCORETENCIONESP_S IMPLEMENTATION.
  METHOD SAVE_MODIFIED.
    READ TABLE update-IntercoRetencionAll INDEX 1 INTO DATA(all).
    IF all-TransportRequestID IS NOT INITIAL.
      lhc_rap_tdat_cts=>get( )->record_changes(
                                  transport_request = all-TransportRequestID
                                  create            = REF #( create )
                                  update            = REF #( update )
                                  delete            = REF #( delete ) )->update_last_changed_date_time( view_entity_name   = 'ZI_INTERCORETENCIONESP'
                                                                                                        maintenance_object = 'ZINTERCORETENCIONESP' ).
    ENDIF.
  ENDMETHOD.
  METHOD CLEANUP_FINALIZE ##NEEDED.
  ENDMETHOD.
ENDCLASS.
CLASS LHC_ZI_INTERCORETENCIONESP DEFINITION FINAL INHERITING FROM CL_ABAP_BEHAVIOR_HANDLER.
  PRIVATE SECTION.
    METHODS:
      VALIDATETRANSPORTREQUEST FOR VALIDATE ON SAVE
        IMPORTING
          KEYS FOR IntercoRetencionesP~ValidateTransportRequest,
      VALIDATEDATACONSISTENCY FOR VALIDATE ON SAVE
        IMPORTING
          KEYS FOR IntercoRetencionesP~ValidateDataConsistency,
      GET_GLOBAL_FEATURES FOR GLOBAL FEATURES
        IMPORTING
          REQUEST REQUESTED_FEATURES FOR IntercoRetencionesP
        RESULT result,
      COPYINTERCORETENCIONESP FOR MODIFY
        IMPORTING
          KEYS FOR ACTION IntercoRetencionesP~CopyIntercoRetencionesP,
      GET_GLOBAL_AUTHORIZATIONS FOR GLOBAL AUTHORIZATION
        IMPORTING
           REQUEST requested_authorizations FOR IntercoRetencionesP
        RESULT result,
      GET_INSTANCE_FEATURES FOR INSTANCE FEATURES
        IMPORTING
          KEYS REQUEST requested_features FOR IntercoRetencionesP
        RESULT result.
ENDCLASS.

CLASS LHC_ZI_INTERCORETENCIONESP IMPLEMENTATION.
  METHOD VALIDATETRANSPORTREQUEST.
    DATA change TYPE REQUEST FOR CHANGE ZI_IntercoRetencionesP_S.
    SELECT SINGLE TransportRequestID
      FROM ZINTER_WHT_Z_D_S
      WHERE SingletonID = 1
      INTO @DATA(TransportRequestID).
    lhc_rap_tdat_cts=>get( )->validate_changes(
                                transport_request = TransportRequestID
                                table             = 'ZINTER_WHT_ZUONR'
                                keys              = REF #( keys )
                                reported          = REF #( reported )
                                failed            = REF #( failed )
                                change            = REF #( change-IntercoRetencionesP ) ).
  ENDMETHOD.
  METHOD VALIDATEDATACONSISTENCY.
    READ ENTITIES OF ZI_IntercoRetencionesP_S IN LOCAL MODE
      ENTITY IntercoRetencionesP
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(IntercoRetencionesP).
    DATA(table) = xco_cp_abap_repository=>object->tabl->database_table->for( 'ZINTER_WHT_ZUONR' ).
    DATA: BEGIN OF element_check,
            element  TYPE string,
            check    TYPE ref to if_xco_dp_check,
          END OF element_check,
          element_checks LIKE TABLE OF element_check WITH EMPTY KEY.
    LOOP AT IntercoRetencionesP ASSIGNING FIELD-SYMBOL(<IntercoRetencionesP>).
      element_checks = VALUE #(
        ( element = 'Land1' check = table->field( 'LAND1' )->get_value_check( ia_value = <IntercoRetencionesP>-Land1
              it_additional_fields = VALUE #( ) ) )
        ( element = 'Bukrs' check = table->field( 'BUKRS' )->get_value_check( ia_value = <IntercoRetencionesP>-Bukrs
              it_additional_fields = VALUE #( ) ) )
        ( element = 'Lifnr' check = table->field( 'LIFNR' )->get_value_check( ia_value = <IntercoRetencionesP>-Lifnr
              it_additional_fields = VALUE #(
                ( table_name = 'ZINTER_WHT_ZUONR' field_name = 'BUKRS' value = REF #( <IntercoRetencionesP>-Bukrs ) ) ) ) )
      ).
      LOOP AT element_checks INTO element_check.
        INSERT VALUE #( %TKY        = <IntercoRetencionesP>-%TKY
                        %STATE_AREA = |IntercoRetencionesP_{ element_check-element }| ) INTO TABLE reported-IntercoRetencionesP.
        element_check-check->execute( ).
        CHECK element_check-check->passed = xco_cp=>boolean->false.
        INSERT VALUE #( %TKY        = <IntercoRetencionesP>-%TKY ) INTO TABLE failed-IntercoRetencionesP.
        LOOP AT element_check-check->messages ASSIGNING FIELD-SYMBOL(<msg>).
          INSERT VALUE #( %TKY = <IntercoRetencionesP>-%TKY
                          %STATE_AREA = 'IntercoRetencionesP_Input_Check'
                          %PATH-IntercoRetencionAll-SingletonID = 1
                          %PATH-IntercoRetencionAll-%IS_DRAFT = <IntercoRetencionesP>-%IS_DRAFT
                          %msg = new_message(
                                   id       = <msg>->value-msgid
                                   number   = <msg>->value-msgno
                                   severity = if_abap_behv_message=>severity-error
                                   v1       = <msg>->value-msgv1
                                   v2       = <msg>->value-msgv2
                                   v3       = <msg>->value-msgv3
                                   v4       = <msg>->value-msgv4 ) ) INTO TABLE reported-IntercoRetencionesP ASSIGNING FIELD-SYMBOL(<rep>).
          ASSIGN COMPONENT element_check-element OF STRUCTURE <rep>-%ELEMENT TO FIELD-SYMBOL(<comp>).
          <comp> = if_abap_behv=>mk-on.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.
  METHOD GET_GLOBAL_FEATURES.
    DATA edit_flag TYPE abp_behv_flag VALUE if_abap_behv=>fc-o-enabled.
    IF lhc_rap_tdat_cts=>get( )->is_editable( ) = abap_false.
      edit_flag = if_abap_behv=>fc-o-disabled.
    ENDIF.
    result-%UPDATE = edit_flag.
    result-%DELETE = edit_flag.
  ENDMETHOD.
  METHOD COPYINTERCORETENCIONESP.
    DATA new_IntercoRetencionesP TYPE TABLE FOR CREATE ZI_IntercoRetencionesP_S\_IntercoRetencionesP.

    IF lines( keys ) > 1.
      INSERT mbc_cp_api=>message( )->get_select_only_one_entry( ) INTO TABLE reported-%other.
      failed-IntercoRetencionesP = VALUE #( FOR fkey IN keys ( %TKY = fkey-%TKY ) ).
      RETURN.
    ENDIF.

    READ ENTITIES OF ZI_IntercoRetencionesP_S IN LOCAL MODE
      ENTITY IntercoRetencionesP
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(ref_IntercoRetencionesP)
      FAILED DATA(read_failed).

    LOOP AT ref_IntercoRetencionesP ASSIGNING FIELD-SYMBOL(<ref_IntercoRetencionesP>).
      DATA(key) = keys[ KEY draft %TKY = <ref_IntercoRetencionesP>-%TKY ].
      DATA(key_cid) = key-%CID.
      APPEND VALUE #(
        %TKY-SingletonID = 1
        %IS_DRAFT = <ref_IntercoRetencionesP>-%IS_DRAFT
        %TARGET = VALUE #( (
          %CID = key_cid
          %IS_DRAFT = <ref_IntercoRetencionesP>-%IS_DRAFT
          %DATA = CORRESPONDING #( <ref_IntercoRetencionesP> EXCEPT

            Bukrs
            Concepto
            Land1
            Lifnr
            SingletonID
        ) ) )
      ) TO new_IntercoRetencionesP ASSIGNING FIELD-SYMBOL(<new_IntercoRetencionesP>).
      <new_IntercoRetencionesP>-%TARGET[ 1 ]-Land1 = key-%PARAM-Land1.
      <new_IntercoRetencionesP>-%TARGET[ 1 ]-Bukrs = key-%PARAM-Bukrs.
      <new_IntercoRetencionesP>-%TARGET[ 1 ]-Lifnr = key-%PARAM-Lifnr.
      <new_IntercoRetencionesP>-%TARGET[ 1 ]-Concepto = key-%PARAM-Concepto.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_IntercoRetencionesP_S IN LOCAL MODE
      ENTITY IntercoRetencionAll CREATE BY \_IntercoRetencionesP
      FIELDS (
               Land1
               Bukrs
               Lifnr
               Concepto
               Witht
               WtWithcd
             ) WITH new_IntercoRetencionesP
      MAPPED DATA(mapped_create)
      FAILED failed
      REPORTED reported.

    mapped-IntercoRetencionesP = mapped_create-IntercoRetencionesP.
    INSERT LINES OF read_failed-IntercoRetencionesP INTO TABLE failed-IntercoRetencionesP.

    IF failed-IntercoRetencionesP IS INITIAL.
      reported-IntercoRetencionesP = VALUE #( FOR created IN mapped-IntercoRetencionesP (
                                                 %CID = created-%CID
                                                 %ACTION-CopyIntercoRetencionesP = if_abap_behv=>mk-on
                                                 %MSG = mbc_cp_api=>message( )->get_item_copied( )
                                                 %PATH-IntercoRetencionAll-%IS_DRAFT = created-%IS_DRAFT
                                                 %PATH-IntercoRetencionAll-SingletonID = 1 ) ).
    ENDIF.
  ENDMETHOD.
  METHOD GET_GLOBAL_AUTHORIZATIONS.
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM' ID 'TABLE' FIELD 'ZI_INTERCORETENCIONESP' ID 'ACTVT' FIELD '02'.
    DATA(is_authorized) = COND #( WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
                                  ELSE if_abap_behv=>auth-unauthorized ).
    result-%ACTION-CopyIntercoRetencionesP = is_authorized.
  ENDMETHOD.
  METHOD GET_INSTANCE_FEATURES.
    result = VALUE #( FOR row IN keys ( %TKY = row-%TKY
                                        %ACTION-CopyIntercoRetencionesP = COND #( WHEN row-%IS_DRAFT = if_abap_behv=>mk-off THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
   ) ).
  ENDMETHOD.
ENDCLASS.
