CLASS lsc_exemption DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_exemption IMPLEMENTATION.

  METHOD save_modified.

*    IF create-exemption IS INITIAL AND
*       update-exemption IS INITIAL AND
*       delete-exemption IS INITIAL.
*      RETURN.
*    ENDIF.
*
*    zcl_interco=>log->save(
*      iv_tablename = 'ZINT_A_MD_CR'
*      it_creates   = create-exemption
*      it_updates   = update-exemption
*      it_deletes   = delete-exemption
*    ).

  ENDMETHOD.

ENDCLASS.

CLASS lcl_numberrange_rule_id DEFINITION.
  PUBLIC SECTION.

    DATA ty_keys TYPE TABLE FOR DETERMINATION zi_intercoexemptiontp\\exemption~setexternalid.
    TYPES ty_key LIKE LINE OF ty_keys.
    INTERFACES if_abap_parallel.

    METHODS:
      constructor
        IMPORTING key TYPE ty_key.

    DATA external_id TYPE zint_exemption_id.
    DATA key TYPE ty_key.
ENDCLASS.

CLASS lcl_numberrange_rule_id IMPLEMENTATION.

  METHOD constructor.
    me->key = key.
  ENDMETHOD.

  METHOD if_abap_parallel~do.
    TRY.
        DATA(number_range) = CAST if_numberrange_buffer( cl_numberrange_buffer=>get_instance( ) ).
        number_range->number_get_no_buffer(
          EXPORTING
            iv_object   = zif_co_interco_exemption=>range_number
            iv_interval = '01'
            iv_quantity = 1
          IMPORTING
            ev_number   = DATA(external_id)
        ).

        me->external_id = CONV #( external_id ).
      CATCH cx_number_ranges.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_exemption DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR exemption RESULT result.

    METHODS delimit FOR MODIFY
      IMPORTING keys FOR ACTION exemption~delimit RESULT result.

    METHODS defaultforcreate FOR READ
      IMPORTING keys FOR FUNCTION exemption~defaultforcreate RESULT result.

    METHODS copyexemption FOR MODIFY
      IMPORTING keys FOR ACTION exemption~copyexemption.

    METHODS validatevalidto FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatevalidto.

    METHODS validatedateoverlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatedateoverlap.

    METHODS setexternalid FOR DETERMINE ON SAVE
      IMPORTING keys FOR exemption~setexternalid.
    "
    METHODS validaterequired FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validaterequired.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR exemption RESULT result.
    METHODS delete FOR MODIFY
      IMPORTING keys FOR ACTION exemption~delete RESULT result.

    METHODS restore FOR MODIFY
      IMPORTING keys FOR ACTION exemption~restore RESULT result.


ENDCLASS.

CLASS lhc_exemption IMPLEMENTATION.

  METHOD get_instance_features.
    LOOP AT keys REFERENCE INTO DATA(key).

      DATA(disable_on_draft) = COND #(
              WHEN key->%is_draft = if_abap_behv=>mk-on
                  THEN if_abap_behv=>fc-o-disabled
                  ELSE if_abap_behv=>fc-o-enabled ).

      result = VALUE #(  BASE result ( %tky = key->%tky %action-delimit = disable_on_draft ) ).

    ENDLOOP.
  ENDMETHOD.

  METHOD delimit.

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
        ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(read_result_exemptions).

    MODIFY ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
           ENTITY exemption
              UPDATE FIELDS ( validfrom validto ) " The necessity of providing valid from is due to the date validations that required both fields.
                 WITH VALUE #( FOR key IN keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 validfrom = read_result_exemptions[ %tky = key-%tky ]-validfrom
                                                 validto   = key-%param-validto ) ).

    " Read changed data for action result
    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
      ENTITY exemption
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(exemptions).

    result = VALUE #( FOR exemption IN exemptions ( %tky   = exemption-%tky
                                                    %param = exemption ) ).

  ENDMETHOD.

  METHOD copyexemption.

    DATA:
      exemptions           TYPE TABLE FOR CREATE zi_intercoexemptiontp\\exemption,
      delimited_exemptions TYPE TABLE FOR ACTION IMPORT zi_intercoexemptiontp\\exemption~delimit,
      create_rules         TYPE TABLE FOR CREATE zi_intercoexemptiontp\\exemption\_exemptionrules.

    READ TABLE keys WITH KEY %cid = '' INTO DATA(key_with_inital_cid).
    ASSERT key_with_inital_cid IS INITIAL.

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
      ENTITY exemption
       ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(read_exemptions)
    FAILED failed.

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
      ENTITY exemption BY \_exemptionrules
       ALL FIELDS WITH CORRESPONDING #( read_exemptions )
     RESULT DATA(read_rules).


    LOOP AT read_exemptions ASSIGNING FIELD-SYMBOL(<read_exemption>).
      DATA(key) = keys[ %tky = <read_exemption>-%tky ].

      IF <read_exemption>-companycode = key-%param-companycode AND
         <read_exemption>-product = key-%param-product AND
         <read_exemption>-validto >= key-%param-validfrom.

        APPEND VALUE #( %tky           = key-%tky
                        %key           = key-%key
                        %param-validto = key-%param-validfrom - 1 )
                        TO delimited_exemptions.
      ENDIF.


      APPEND VALUE #( %cid  = key-%cid
                      %data = CORRESPONDING #( <read_exemption> EXCEPT id
                      ) ) TO exemptions ASSIGNING FIELD-SYMBOL(<create_exemption>).


      <create_exemption>-companycode = key-%param-companycode.
      <create_exemption>-product     = key-%param-product.
      <create_exemption>-validfrom   = key-%param-validfrom.
      <create_exemption>-validto     = '99991231'.

      APPEND VALUE #( %cid_ref = key-%cid
      ) TO create_rules ASSIGNING FIELD-SYMBOL(<create_rule>).


      <create_rule>-%target = VALUE #( FOR read_rule IN read_rules
                                       INDEX INTO idx USING KEY entity
                                       WHERE ( id    = <read_exemption>-id )
                                             ( %cid  = key-%cid && idx
                                               %data = CORRESPONDING #( read_rule EXCEPT id ruleid ) ) ).


    ENDLOOP.


    MODIFY ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
       ENTITY exemption
         EXECUTE delimit FROM delimited_exemptions
         CREATE
            FIELDS ( companycode product validfrom validto )
                WITH exemptions
         CREATE BY \_exemptionrules
            FIELDS ( accountingdocumenttype glaccount costcenter profitcenter )
                WITH create_rules
       MAPPED mapped
       FAILED failed
       REPORTED reported.


  ENDMETHOD.

  METHOD defaultforcreate.
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    result = VALUE #( FOR key IN keys (
                      %cid                   = key-%cid
                      %param-%is_draft       = if_abap_behv=>mk-on
                      %param-%data-validfrom = |{ today(6) }01|
                      %param-%data-validto   = |{ today(4) }1231| ) ).
  ENDMETHOD.
*
  METHOD validatedateoverlap.
    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
           ENTITY exemption
            ALL FIELDS WITH CORRESPONDING #( keys )
         RESULT DATA(current_exemptions).

    IF current_exemptions IS NOT INITIAL.
      SELECT id, externalid, validto, validfrom FROM zi_intercoexemptiontp
      FOR ALL ENTRIES IN @current_exemptions
      WHERE externalid = @current_exemptions-externalid
*        and IsDeleted = @abap_false
          INTO TABLE @DATA(db_rules).
    ENDIF.

    " Update db_exemptions with the coming changes to ensure validation considers updated dates.
    DATA(combined_rules) = db_rules.
    LOOP AT current_exemptions INTO DATA(current_rule).
      MODIFY combined_rules FROM CORRESPONDING #( current_rule )
        TRANSPORTING validfrom validto WHERE externalid = current_rule-externalid.
    ENDLOOP.

    LOOP AT current_exemptions INTO DATA(exemption).
      APPEND VALUE #( %tky        = exemption-%tky
                      %state_area = 'VALIDATE_DATE_OVERLAP'
      ) TO reported-exemption.


      DATA invalid_rules LIKE combined_rules.
      invalid_rules = VALUE #( FOR existing_exemption IN combined_rules
                               WHERE ( externalid = exemption-externalid AND
                               id <> exemption-id AND
                               validto >= exemption-validfrom AND
                               validfrom <= exemption-validto )
                               (                  existing_exemption ) ).


      IF invalid_rules IS NOT INITIAL.
        failed-exemption = VALUE #( FOR failed_exemption IN invalid_rules ( %tky = exemption-%tky ) ).
        APPEND VALUE #( %tky               = exemption-%tky
                        %state_area        = 'VALIDATE_DATE_OVERLAP'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>date_overlaps
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
        ) TO reported-exemption.

      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD validatevalidto.

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
          ENTITY exemption
           ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(current_exemptions).

    LOOP AT current_exemptions REFERENCE INTO DATA(rule).

      DATA(key) = keys[ %tky = rule->%tky ].

      APPEND VALUE #( %tky        = key-%tky
                      %state_area = 'VALIDATE_DATE_INTERVAL'
      ) TO reported-exemption.


      IF rule->validfrom > rule->validto.
        APPEND VALUE #( %tky = key-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky               = key-%tky
                        %state_area        = 'VALIDATE_DATE_INTERVAL'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>date_interval
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
        ) TO reported-exemption.
      ENDIF.

    ENDLOOP.


  ENDMETHOD.

  METHOD setexternalid.

    " This is an 'external ID' and not the primary key in this context.
    " However, we do not want users to manually assign this value. Instead, it is generated using a number range (ZINTRULEID).
    " Since RAP does not support 'late numbering' for non-key fields, we rely on determinations to handle this logic.
    "
    " The challenge arises because determinations run within the behavior handler, which has restrictions.
    " Specifically, using CL_NUMBERRANGE_BUFFER directly within this context results in a "Behavior Illegal Statement" error.
    " To work around this limitation, we opted to generate the RuleID using parallel processing.
    "
    " The parallel processing triggers the number range generation outside the restricted behavior handler context,
    " allowing us to retrieve the new RuleIDs and update them accordingly.
    DATA(parallel_processing) = NEW cl_abap_parallel(  ).

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
        ENTITY exemption
            FIELDS ( externalid )
            WITH CORRESPONDING #( keys )
            RESULT DATA(rules).

    DELETE rules WHERE externalid IS NOT INITIAL.

    parallel_processing->run_inst(
      EXPORTING
        p_in_tab  = VALUE #( FOR r IN rules ( NEW lcl_numberrange_rule_id( key = CORRESPONDING #( r ) ) ) )
      IMPORTING
        p_out_tab = DATA(parallel_results)
    ).

    LOOP AT parallel_results INTO DATA(parallel_result).
      DATA(numberrange_external_id) =  CAST lcl_numberrange_rule_id( parallel_result-inst ).
      DATA(rule) = REF #( rules[ KEY entity %key = numberrange_external_id->key-%key ] ).
      rule->externalid = numberrange_external_id->external_id.
    ENDLOOP.

    MODIFY ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
        ENTITY exemption
            UPDATE FIELDS ( externalid ) WITH CORRESPONDING #( rules )
                REPORTED DATA(reported_modify)
                FAILED DATA(failed_modify)
                MAPPED DATA(mapped_modify).

    reported = CORRESPONDING #( DEEP reported_modify ).
  ENDMETHOD.

  METHOD validaterequired.

    DATA permission_request TYPE STRUCTURE FOR PERMISSIONS REQUEST zi_intercoexemptiontp.

    " Implementation of a generic method for validating mandatory fields,
    " covering both those statically defined in the behavior definition
    " and those dynamically defined via `features: instance` in the `get_instance_features` method.
    DATA(components) = CAST cl_abap_structdescr( cl_abap_structdescr=>describe_by_name( 'ZI_IntercoExemptionTP' ) )->get_components( ).

    LOOP AT components REFERENCE INTO DATA(component).
      permission_request-%field-(component->name) = if_abap_behv=>mk-on.
    ENDLOOP.

    DATA instance_permissions TYPE TABLE FOR INSTANCE FEATURES RESULT zi_intercoexemptiontp\\exemption .
    GET PERMISSIONS OF zi_intercoexemptiontp
      ENTITY exemption
      FROM CORRESPONDING #( keys )
    REQUEST permission_request
    RESULT DATA(permissions).

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
      ENTITY exemption
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(current_rules).

    LOOP AT current_rules REFERENCE INTO DATA(rule).

      APPEND VALUE #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_REQUIRED'
      ) TO reported-exemption.

      "  Validate mandatory fields
      DO lines( components ) TIMES.
        component = REF #( components[ sy-index ] ).
        IF ( permissions-global-%field-(component->name) = if_abap_behv=>mk-on OR
             permissions-instances[ KEY entity %key = rule->%key ]-%field-(component->name) = if_abap_behv=>mk-on )
           AND rule->(component->name) IS INITIAL.

          "  Mark validation failure
          APPEND VALUE #( %tky = rule->%tky ) TO failed-exemption.

          "  Register validation error message
          APPEND INITIAL LINE TO reported-exemption ASSIGNING FIELD-SYMBOL(<reported_entity>).
          <reported_entity> = VALUE #( %tky        = rule->%tky
                                       %state_area = 'VALIDATE_REQUIRED'
                                       %msg        = zcl_fi_intrc_messages=>new_message(
                                       textid   = zcl_fi_intrc_messages=>field_required
                                       severity = if_abap_behv_message=>severity-error ) ).

          "  Indicate the specific field that failed validation
          <reported_entity>-%element-(component->name) = if_abap_behv=>mk-on.
        ENDIF.
      ENDDO.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_global_authorizations.

    DATA display_error TYPE abap_boolean.

    DATA(can_delete) = zcl_interco=>authority->for( zcl_interco_authority=>c_delete ).
    DATA(can_create) = zcl_interco=>authority->for( zcl_interco_authority=>c_create ).
    DATA(can_update) = zcl_interco=>authority->for( zcl_interco_authority=>c_update ).

    " Check DELETE
    result-%delete = can_delete.
    result-%action-restore = can_delete.
    IF can_delete = if_abap_behv=>auth-unauthorized AND (
          requested_authorizations-%delete = if_abap_behv=>mk-on OR
          requested_authorizations-%action-restore = if_abap_behv=>mk-on ).
      display_error = abap_true.
    ENDIF.

    " Check CREATE
    result-%create = can_create.
    result-%action-copyexemption = can_create.
    result-%action-edit = can_create.

    IF can_create = if_abap_behv=>auth-unauthorized AND (
       requested_authorizations-%create = if_abap_behv=>mk-on OR
       requested_authorizations-%action-copyexemption = if_abap_behv=>mk-on OR
       requested_authorizations-%action-edit = if_abap_behv=>mk-on ).
      display_error = abap_true.
    ENDIF.

    " Check UPDATE
    result-%action-delete = can_update.
    result-%action-delimit = can_update.
    result-%action-edit = can_update.
    result-%update = can_update.

    IF can_update =  if_abap_behv=>auth-unauthorized AND (
       requested_authorizations-%update = if_abap_behv=>mk-on OR
       requested_authorizations-%action-edit = if_abap_behv=>mk-on OR
       requested_authorizations-%action-delimit = if_abap_behv=>mk-on OR
       requested_authorizations-%action-delete = if_abap_behv=>mk-on ).
      display_error = abap_true.
    ENDIF.

    IF display_error = abap_true.
      APPEND VALUE #( %msg    = zcl_fi_intrc_messages=>new_message(
                      textid   = zcl_fi_intrc_messages=>no_authority
                      severity = if_abap_behv_message=>severity-error )
                      %global = if_abap_behv=>mk-on ) TO reported-exemption.
    ENDIF.

  ENDMETHOD.

  METHOD delete.

    READ ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
      ENTITY exemption FIELDS ( isdeleted )
        WITH CORRESPONDING #( keys )
          RESULT DATA(current_exemptions).

    LOOP AT current_exemptions REFERENCE INTO DATA(exemption).
      exemption->isdeleted = abap_true.
    ENDLOOP.

    MODIFY ENTITIES OF zi_intercoexemptiontp IN LOCAL MODE
    ENTITY exemption
    UPDATE FIELDS ( isdeleted )
    WITH CORRESPONDING #( current_exemptions ).

    result = CORRESPONDING #( current_exemptions ).

  ENDMETHOD.

  METHOD restore.
  ENDMETHOD.

ENDCLASS.
