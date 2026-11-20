CLASS lsc_classificationrule DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_classificationrule IMPLEMENTATION.

  METHOD save_modified.

    IF create-classificationrule IS INITIAL AND
       update-classificationrule IS INITIAL AND
       delete-classificationrule IS INITIAL.
      RETURN.
    ENDIF.

    zcl_interco=>log->save(
      iv_tablename = 'ZINT_A_MD_CR'
      it_creates   = create-classificationrule
      it_updates   = update-classificationrule
      it_deletes   = delete-classificationrule
    ).

*
*    data _creates type table of zint_a_md_cr.
*    data _updates type table of zint_a_md_cr.
*    data _deletes type table of zint_a_md_cr.
*    data news type table of zint_a_md_cr.
*    data change_indicator type if_chdo_object_tools_rel=>ty_cdchngindh.
*
*    _creates = corresponding #( create-classificationrule mapping from entity ).
*    _updates = corresponding #( update-classificationrule mapping from entity ).
*    _deletes = corresponding #( delete-classificationrule mapping from entity ).
*
*    append lines of _creates to news.
*    append lines of _updates to news.
*
*    data range_ids type range of zint_a_md_cr-id.
*
*    select 'I', 'EQ', updates~id
*        from @_updates as updates
*        appending table @range_ids.
*    select 'I', 'EQ', deletes~id
*        from @_deletes as deletes
*        appending table @range_ids.
*
*    select from zint_a_md_cr
*        fields
*            client,
*            id,
*            rule_id,
*            rule_name,
*            valid_from,
*            valid_to,
*            company_code,
*            p_and_l_id,
*            p_and_l_level,
*            profit_center,
*            cc_std_hier_area,
*            cc_allocation,
*            cc_consolidation,
*            product,
*            is_not_billable,
*            is_deleted,
*            created_at,
*            created_by,
*            last_changed_at,
*            local_last_changed_at,
*            last_changed_by
*            where id in @range_ids
*            into table @data(olds).
*
*    loop at news into data(new).
*      new-client = cond #( when new-client is initial then sy-mandt else new-client ).
*
*      try.
*          data(old) = olds[ id = new-id ].
*        catch cx_sy_itab_line_not_found.
*          clear old.
*      endtry.
*
*      change_indicator = cond #( when line_exists( _creates[ id = new-id ] ) then 'I'
*                                 when line_exists( _updates[ id = new-id ] ) then 'U'
*                                 when line_exists( _deletes[ id = new-id ] ) then 'D'
*                                 else space ).
*
*      try.
*          zcl_zint_a_md_cr_chdo=>write(
*            exporting
*              objectid         = 'ZINT_A_MD_CR'
*              utime            = cl_abap_context_info=>get_system_time( )
*              udate            = cl_abap_context_info=>get_system_date( )
*              username         = sy-uname
*              o_zint_a_md_cr   = old
*              n_zint_a_md_cr   = new
*              upd_zint_a_md_cr = change_indicator
*            importing
*              changenumber     = data(changenumber)
*          ).
*        catch cx_chdo_write_error.
*          "  too late to do something.
*      endtry.
*
*    endloop.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_numberrange_rule_id DEFINITION.
  PUBLIC SECTION.

    DATA ty_keys TYPE TABLE FOR DETERMINATION zr_intercoclassificationrule\\classificationrule~setruleid.
    TYPES ty_key LIKE LINE OF ty_keys.
    INTERFACES if_abap_parallel.

    METHODS:
      constructor
        IMPORTING key TYPE ty_key.

    DATA rule_id TYPE zint_rule_id.
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
            iv_object   = zif_co_interco_class_rule=>range_number
            iv_interval = '01'
            iv_quantity = 1
          IMPORTING
            ev_number   = DATA(rule_id)
        ).

        me->rule_id = CONV #( rule_id ).
      CATCH cx_number_ranges.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.



CLASS lhc_classificationrule DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR ClassificationRule
        RESULT result,

      SetRuleId FOR DETERMINE ON SAVE
        IMPORTING keys FOR ClassificationRule~SetRuleId,

      get_instance_features FOR INSTANCE FEATURES
        IMPORTING keys REQUEST requested_features FOR ClassificationRule RESULT result.

    METHODS DefaultForCreate FOR READ
      IMPORTING keys FOR FUNCTION ClassificationRule~DefaultForCreate RESULT result.

    METHODS CopyClassificationRule FOR MODIFY
      IMPORTING keys FOR ACTION ClassificationRule~CopyClassificationRule.

    METHODS Delimit FOR MODIFY
      IMPORTING keys FOR ACTION ClassificationRule~Delimit RESULT result.

    " This methods is relevant only for the Copy action.
    METHODS ValidateDateOverlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR ClassificationRule~ValidateDateOverlap.

    METHODS ValidateValidTo FOR VALIDATE ON SAVE
      IMPORTING keys FOR ClassificationRule~ValidateValidTo.

    METHODS ValidateRequired FOR VALIDATE ON SAVE
      IMPORTING keys FOR ClassificationRule~ValidateRequired.

    METHODS ClearProduct FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ClassificationRule~ClearProduct.
    METHODS ValidateBillRelation FOR VALIDATE ON SAVE
      IMPORTING keys FOR ClassificationRule~ValidateBillRelation.
    METHODS ValidateDuplicated FOR VALIDATE ON SAVE
      IMPORTING keys FOR ClassificationRule~ValidateDuplicated.
    METHODS Delete FOR MODIFY
      IMPORTING keys FOR ACTION ClassificationRule~Delete RESULT result.

    METHODS Restore FOR MODIFY
      IMPORTING keys FOR ACTION ClassificationRule~Restore RESULT result.
    METHODS SetPandLevel FOR DETERMINE ON SAVE
      IMPORTING keys FOR ClassificationRule~SetPandLevel.

    "! Validate fields that are linked to search helps
    METHODS ValidateAllFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR ClassificationRule~ValidateAllFields.

ENDCLASS.

CLASS lhc_classificationrule IMPLEMENTATION.

  METHOD get_global_authorizations.
    DATA display_error TYPE abap_boolean.

    DATA(can_delete) = zcl_interco=>authority->for( zcl_interco_authority=>c_delete ).
    DATA(can_create) = zcl_interco=>authority->for( zcl_interco_authority=>c_create ).
    DATA(can_update) = zcl_interco=>authority->for( zcl_interco_authority=>c_update ).

    " Check DELETE
    result-%delete = can_delete.
    result-%action-Restore = can_delete.
    IF can_delete = if_abap_behv=>auth-unauthorized AND (
          requested_authorizations-%delete = if_abap_behv=>mk-on OR
          requested_authorizations-%action-Restore = if_abap_behv=>mk-on ).
      display_error = abap_true.
    ENDIF.

    " Check CREATE
    result-%create = can_create.
    result-%action-CopyClassificationRule = can_create.
    result-%action-Edit = can_create.

    IF can_create = if_abap_behv=>auth-unauthorized AND (
       requested_authorizations-%create = if_abap_behv=>mk-on OR
       requested_authorizations-%action-CopyClassificationRule = if_abap_behv=>mk-on OR
       requested_authorizations-%action-Edit = if_abap_behv=>mk-on ).
      display_error = abap_true.
    ENDIF.

    " Check UPDATE
    result-%action-Delete = can_update.
    result-%action-Delimit = can_update.
    result-%action-Edit = can_update.
    result-%update = can_update.

    IF can_update =  if_abap_behv=>auth-unauthorized AND (
       requested_authorizations-%update = if_abap_behv=>mk-on OR
       requested_authorizations-%action-Edit = if_abap_behv=>mk-on OR
       requested_authorizations-%action-Delimit = if_abap_behv=>mk-on OR
       requested_authorizations-%action-Delete = if_abap_behv=>mk-on ).
      display_error = abap_true.
    ENDIF.

    IF display_error = abap_true.
      APPEND VALUE #( %msg    = zcl_fi_intrc_messages=>new_message(
                      textid   = zcl_fi_intrc_messages=>no_authority
                      severity = if_abap_behv_message=>severity-error )
                      %global = if_abap_behv=>mk-on ) TO reported-classificationrule.
    ENDIF.

  ENDMETHOD.

  METHOD SetRuleId.

    " RuleID is used as an 'external ID' and not the primary key in this context.
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

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
            FIELDS ( RuleId )
            WITH CORRESPONDING #( keys )
            RESULT DATA(rules).

    DELETE rules WHERE ruleid IS NOT INITIAL.

    parallel_processing->run_inst(
      EXPORTING
        p_in_tab  = VALUE #( FOR r IN rules ( NEW lcl_numberrange_rule_id( key = CORRESPONDING #( r ) ) ) )
      IMPORTING
        p_out_tab = DATA(parallel_results)
    ).

    LOOP AT parallel_results INTO DATA(parallel_result).
      DATA(numberrange_rule_id) =  CAST lcl_numberrange_rule_id( parallel_result-inst ).
      DATA(rule) = REF #( rules[ KEY entity %key = numberrange_rule_id->key-%key ] ).
      rule->RuleID = numberrange_rule_id->rule_id.
    ENDLOOP.

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
            UPDATE FIELDS ( RuleID ) WITH CORRESPONDING #( rules )
                REPORTED DATA(reported_modify)
                FAILED DATA(failed_modify)
                MAPPED DATA(mapped_modify).

    reported = CORRESPONDING #( DEEP reported_modify ).

  ENDMETHOD.


  METHOD SetPandLevel.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY classificationrule
            FIELDS ( pandlid )
            WITH CORRESPONDING #( keys )
            RESULT DATA(rules).

    IF rules IS NOT INITIAL.
      SELECT id, customerlevel FROM ZI_IntercoPandLHierFlattenedSH
      WITH PRIVILEGED ACCESS
          FOR ALL ENTRIES IN @rules
          WHERE id = @rules-PAndLID
          INTO TABLE @DATA(pandl_levels).
    ENDIF.

    LOOP AT rules REFERENCE INTO DATA(rule).

      TRY.
          rule->PAndLLevel = pandl_levels[ id = rule->PAndLID ]-CustomerLevel.
        CATCH cx_sy_itab_line_not_found.
          CONTINUE.
      ENDTRY.

    ENDLOOP.

    MODIFY ENTITIES OF ZR_IntercoClassificationRule IN LOCAL MODE
        ENTITY classificationrule
            UPDATE FIELDS ( PAndLLevel ) WITH CORRESPONDING #( rules )
            REPORTED DATA(reported_modify)
            FAILED DATA(failed_modify)
            MAPPED DATA(mapped_modify).

    reported = CORRESPONDING #( DEEP reported_modify ).


  ENDMETHOD.

  METHOD get_instance_features.
    CONSTANTS: BEGIN OF c_product_flow,
                 outflow TYPE zi_intercocompanyrelproduct-Flow VALUE 'O',
                 inflow  TYPE zi_intercocompanyrelproduct-Flow VALUE 'I',
               END OF c_product_flow.


    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
          " Ini Facturación Local EXT_VINBARRI 20.11.2026 - CcStdHierArea opcional para PaymentType L
          " FIELDS ( ValidFrom ValidTo CompanyCode IsNotBillable Product IsDeleted IsNotDeleted )
          FIELDS ( ValidFrom ValidTo CompanyCode IsNotBillable Product IsDeleted IsNotDeleted PaymentType )
          " Fin EXT_VINBARRI 20.11.2026
              WITH CORRESPONDING #( keys )
              RESULT DATA(current_rules).

    IF current_rules IS NOT INITIAL.
      SELECT providercompanycode AS companycode, product, flow FROM ZI_IntercoCompanyRelProduct
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @current_rules
          WHERE Product = @current_rules-Product
            AND ValidFrom <= @current_rules-validto
            AND ValidTo >= @current_rules-validfrom
            AND IsDeleted IS INITIAL
            INTO TABLE @DATA(products_flows).
    ENDIF.

    LOOP AT current_rules REFERENCE INTO DATA(current_rule).

      TRY.
          DATA(product_flow) = products_flows[ companycode = current_rule->CompanyCode product = current_rule->product ].
        CATCH cx_sy_itab_line_not_found.
          TRY.
              product_flow = products_flows[ product = current_rule->product ].
            CATCH cx_sy_itab_line_not_found.
          ENDTRY.
      ENDTRY.

      "  Fields:
      DATA(required_when_outflow) = COND #( WHEN product_flow-Flow = c_product_flow-outflow THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-unrestricted ).
      DATA(required_when_inflow) = COND #( WHEN product_flow-Flow = c_product_flow-inflow THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-unrestricted ).
      " Ini Facturación Local EXT_VINBARRI 20.11.2026 - CcStdHierArea opcional para PaymentType L
      DATA(required_area_when_outflow) = COND #( WHEN current_rule->PaymentType = 'L' THEN if_abap_behv=>fc-f-unrestricted
                                                 ELSE required_when_outflow ).
      " Fin EXT_VINBARRI 20.11.2026
      DATA(required_when_billable) = COND #( WHEN current_rule->IsNotBillable = abap_false THEN if_abap_behv=>fc-f-mandatory ELSE if_abap_behv=>fc-f-unrestricted ).

      DATA(enable_when_billable) = COND #(
              WHEN current_rule->IsNotBillable = abap_true
                THEN if_abap_behv=>fc-f-read_only
                ELSE if_abap_behv=>fc-f-mandatory ).

      "  Actions:
      DATA(can_delimit) = COND #(
              WHEN current_rule->%is_draft = if_abap_behv=>mk-on
                  THEN if_abap_behv=>fc-o-disabled
                  ELSE if_abap_behv=>fc-o-enabled ).

      DATA(can_restore) = COND #(
        WHEN current_rule->%is_draft = if_abap_behv=>mk-on THEN if_abap_behv=>fc-o-disabled
        WHEN current_rule->IsDeleted = abap_true THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ).

      DATA(can_mark_as_deleted) = COND #(
        WHEN current_rule->%is_draft = if_abap_behv=>mk-on THEN if_abap_behv=>fc-o-disabled
        WHEN current_rule->IsDeleted = abap_true THEN if_abap_behv=>fc-o-disabled
        ELSE if_abap_behv=>fc-o-enabled ).

      " Operations:
      DATA(can_edit) = COND #(
          WHEN current_rule->IsDeleted = abap_true
              THEN if_abap_behv=>fc-o-disabled
              ELSE if_abap_behv=>fc-o-enabled
      ).

      APPEND VALUE #(
                        %tky                 = current_rule->%tky
                        %key                 = current_rule->%key
                        %pky                 = current_rule->%pky
                        %action-delimit      = can_delimit
                        %action-Delete       = can_mark_as_deleted
                        %action-Restore      = can_restore
                        %action-Edit         = can_edit
                        %update              = can_edit
                        %field-PAndLID       = required_when_billable
                        %field-Product       = enable_when_billable
                        %field-ProfitCenter  = required_when_inflow
                        " Ini Facturación Local EXT_VINBARRI 20.11.2026 - CcStdHierArea opcional para PaymentType L
                        " %field-CcStdHierArea = required_when_outflow
                        %field-CcStdHierArea = required_area_when_outflow
                        " Fin EXT_VINBARRI 20.11.2026
                        %field-CcAllocation  = required_when_outflow ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD DefaultForCreate.

    DATA(today) = cl_abap_context_info=>get_system_date( ).
    result = VALUE #( FOR key IN keys (
                      %cid                       = key-%cid
                      %param-%is_draft           = if_abap_Behv=>mk-on
                      %param-%data-ValidFrom     = |{ today(6) }01|
                      %param-%data-ValidTo       = |{ today(4) }1231|
                      %param-%data-IsNotBillable = abap_false ) ).
  ENDMETHOD.

  METHOD CopyClassificationRule.

    DATA:
      new_rules      TYPE TABLE FOR CREATE zr_intercoclassificationrule\\ClassificationRule,
      delimited_keys TYPE TABLE FOR ACTION IMPORT zr_intercoclassificationrule\\ClassificationRule~Delimit.

    READ TABLE keys WITH KEY %cid = '' INTO DATA(key_with_inital_cid).
    ASSERT key_with_inital_cid IS INITIAL.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
       ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(current_rules)
    FAILED failed.

    LOOP AT current_rules ASSIGNING FIELD-SYMBOL(<current_rule>).
      DATA(key) = keys[ %tky = <current_rule>-%tky ].

      " A copy operation can result in either:
      " 1. A New Rule based on an existing one (RuleID filled), or
      " 2. A new version of an existing rule (RuleID empty).
      "
      " For the second scenario, we need to delimit the copied record to ensure the new version
      " becomes the valid one.
      IF key-%param-RuleID IS NOT INITIAL AND
         <current_rule>-validto >= key-%param-validfrom.
        APPEND INITIAL LINE TO delimited_keys  ASSIGNING FIELD-SYMBOL(<delimited_key>).
        <delimited_key> = CORRESPONDING #( key ).
        <delimited_key>-%param-ValidTo = key-%param-ValidFrom - 1.
      ENDIF.

      APPEND VALUE #( %cid      = key-%cid
                      %is_draft = COND #( WHEN key-%param-RuleId IS NOT INITIAL THEN if_abap_behv=>mk-off ELSE if_abap_behv=>mk-on )
                      %data     = CORRESPONDING #( <current_rule> EXCEPT id ) )
                        TO new_rules ASSIGNING FIELD-SYMBOL(<new_rule>).

      DATA(today) = cl_abap_context_info=>get_system_date( ).

      <new_rule>-RuleId = key-%param-RuleID.
      <new_rule>-validfrom   = key-%param-validfrom.
      <new_rule>-validto     = |{ today(4) }1231|.

    ENDLOOP.

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
       ENTITY ClassificationRule
         EXECUTE delimit FROM delimited_keys
            MAPPED DATA(mapped_delimit)
            FAILED DATA(failed_delimit)
            REPORTED DATA(reporte_delimit).

    IF failed-classificationrule IS NOT INITIAL.
      mapped = CORRESPONDING #( mapped_delimit ).
      failed = CORRESPONDING #( failed_delimit ).
      reported = CORRESPONDING #( reporte_delimit ).
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
    ENTITY ClassificationRule
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 17.11.2026 - C13F-R1: conserva PaymentType al copiar la regla
    " Original conservado:
    " CREATE FIELDS ( RuleID RuleName CompanyCode Ledger ProfitCenter CcStdHierArea CcAllocation CcConsolidation PAndLID Product IsNotBillable ValidFrom ValidTo )
    CREATE FIELDS ( RuleID RuleName CompanyCode Ledger ProfitCenter CcStdHierArea CcAllocation CcConsolidation PAndLID Product IsNotBillable ValidFrom ValidTo PaymentType )
    " Fin EXT_OSCUGALD 17.11.2026 - C13F-R1
           WITH new_rules
  MAPPED mapped
  FAILED failed
  REPORTED reported.

  ENDMETHOD.

  METHOD Delimit.
    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
        ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(current_rules).

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
           ENTITY ClassificationRule
              UPDATE FIELDS ( validfrom validto ) " The necessity of providing valid from is due to the date validations that required both fields.
                 WITH VALUE #( FOR key IN keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 validfrom = current_rules[ KEY entity id = key-id ]-validfrom
                                                 validto   = key-%param-validto ) ).

    " Read changed data for action result
    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(rules).

    result = VALUE #( FOR rule IN rules ( %tky   = rule-%tky
                                          %param = rule ) ).
  ENDMETHOD.

  METHOD ValidateDateOverlap.
    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
       ENTITY ClassificationRule
        ALL FIELDS WITH CORRESPONDING #( keys )
     RESULT DATA(current_rules).

    IF current_rules IS NOT INITIAL.
      SELECT Id, RuleId, ValidTo, ValidFrom
      FROM zr_intercoclassificationrule
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @current_rules
      WHERE RuleID = @current_rules-RuleID
        AND IsDeleted = @abap_false
          INTO TABLE @DATA(db_rules).
    ENDIF.

    " Update db_exemptions with the coming changes to ensure validation considers updated dates.
    DATA(combined_rules) = db_rules.
    LOOP AT current_rules INTO DATA(current_rule).
      MODIFY combined_rules FROM CORRESPONDING #( current_rule )
        TRANSPORTING ValidFrom ValidTo WHERE RuleId = current_rule-RuleId.
    ENDLOOP.

    LOOP AT current_rules INTO DATA(exemption).
      APPEND VALUE #( %tky        = exemption-%tky
                      %state_area = 'VALIDATE_DATE_OVERLAP'
      ) TO reported-classificationrule.

      DATA invalid_rules LIKE combined_rules.
      invalid_rules = VALUE #( FOR existing_exemption IN combined_rules
                               WHERE ( ruleid = exemption-ruleid AND
                               id <> exemption-id AND
                               validto >= exemption-validfrom AND
                               validfrom <= exemption-validto )
                               (              existing_exemption ) ).

      IF invalid_rules IS NOT INITIAL.
        failed-classificationrule = VALUE #( FOR failed_exemption IN invalid_rules ( %tky = exemption-%tky ) ).
        APPEND VALUE #( %tky               = exemption-%tky
                        %state_area        = 'VALIDATE_DATE_OVERLAP'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>date_overlaps
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
                        %element-validto   = if_abap_behv=>mk-on
        ) TO reported-classificationrule.

      ENDIF.
    ENDLOOP.


  ENDMETHOD.

  METHOD ValidateValidTo.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
         ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(current_rules).

    LOOP AT current_rules REFERENCE INTO DATA(rule).

      DATA(key) = keys[ %tky = rule->%tky ].

      APPEND VALUE #( %tky        = key-%tky
                      %state_area = 'VALIDATE_DATE_INTERVAL'
      ) TO reported-classificationrule.

      IF rule->ExcelLineNumber > 0.
        DATA(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      ENDIF.


      IF rule->validfrom > rule->validto.
        APPEND VALUE #( %tky = key-%tky ) TO failed-classificationrule.
        APPEND VALUE #( %tky               = key-%tky
                        %state_area        = 'VALIDATE_DATE_INTERVAL'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        textid   = zcl_fi_intrc_messages=>date_interval
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD ValidateRequired.

    DATA permission_request TYPE STRUCTURE FOR PERMISSIONS REQUEST zr_intercoclassificationrule.

    " Implementation of a generic method for validating mandatory fields,
    " covering both those statically defined in the behavior definition
    " and those dynamically defined via `features: instance` in the `get_instance_features` method.
    DATA(components) = CAST cl_abap_structdescr( cl_abap_structdescr=>describe_by_name( 'ZR_IntercoClassificationRule' ) )->get_components( ).

    LOOP AT components REFERENCE INTO DATA(component).
      permission_request-%field-(component->name) = if_abap_behv=>mk-on.
    ENDLOOP.

    DATA instance_permissions TYPE TABLE FOR INSTANCE FEATURES RESULT zr_intercoclassificationrule\\classificationrule .
    GET PERMISSIONS OF zr_intercoclassificationrule
      ENTITY ClassificationRule
      FROM CORRESPONDING #( keys )
    REQUEST permission_request
    RESULT DATA(permissions).

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
      ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(current_rules).

    LOOP AT current_rules REFERENCE INTO DATA(rule).

      APPEND VALUE #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_REQUIRED'
      ) TO reported-classificationrule.

      IF rule->ExcelLineNumber > 0.
        DATA(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      ENDIF.


      "  Validate mandatory fields
      DO lines( components ) TIMES.
        component = REF #( components[ sy-index ] ).
        IF ( permissions-global-%field-(component->name) = if_abap_behv=>mk-on OR
             permissions-instances[ KEY entity %key = rule->%key ]-%field-(component->name) = if_abap_behv=>mk-on )
           AND rule->(component->name) IS INITIAL.

          "  Mark validation failure
          APPEND VALUE #( %tky = rule->%tky ) TO failed-classificationrule.

          "  Register validation error message
          APPEND INITIAL LINE TO reported-classificationrule ASSIGNING FIELD-SYMBOL(<reported_entity>).
          <reported_entity> = VALUE #( %tky        = rule->%tky
                                       %state_area = 'VALIDATE_REQUIRED'
                                       %msg        = zcl_fi_intrc_messages=>new_message(
                                       v1       = line_number
                                       v2       = |'{ <reported_entity>-%element-(component->name) }'(|
                                       textid   = zcl_fi_intrc_messages=>field_required
                                       severity = if_abap_behv_message=>severity-error ) ).

          "  Indicate the specific field that failed validation
          <reported_entity>-%element-(component->name) = if_abap_behv=>mk-on.
        ENDIF.
      ENDDO.

      "  Ensure that at least one of the Input fields is filled
      APPEND VALUE #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_INPUT'
      ) TO reported-classificationrule.

      IF rule->CcAllocation IS INITIAL AND
        rule->CcConsolidation IS INITIAL AND
        rule->CcStdHierArea IS INITIAL AND
        rule->CompanyCode IS INITIAL AND
        rule->PAndLID IS INITIAL AND
        rule->ProfitCenter IS INITIAL.
        APPEND VALUE #( %tky = rule->%tky ) TO failed-classificationrule.
        APPEND VALUE #( %tky        = rule->%tky
                        %state_area = 'VALIDATE_INPUT'
                        %msg        = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        textid   = zcl_fi_intrc_messages=>at_least_one_required
                        severity = if_abap_behv_message=>severity-error )
        ) TO reported-classificationrule ASSIGNING FIELD-SYMBOL(<reported>).

        <reported>-%element-CCAllocation    = if_abap_behv=>mk-on.
        APPEND <reported> TO reported-classificationrule ASSIGNING <reported>.
        <reported>-%element-CcConsolidation = if_abap_behv=>mk-on.
        APPEND <reported> TO reported-classificationrule ASSIGNING <reported>.
        <reported>-%element-CcStdHierArea   = if_abap_behv=>mk-on.
        APPEND <reported> TO reported-classificationrule ASSIGNING <reported>.
        <reported>-%element-CompanyCode     = if_abap_behv=>mk-on.
        APPEND <reported> TO reported-classificationrule ASSIGNING <reported>.
        <reported>-%element-PAndLId         = if_abap_behv=>mk-on.
        APPEND <reported> TO reported-classificationrule ASSIGNING <reported>.
        <reported>-%element-ProfitCenter    = if_abap_behv=>mk-on.

      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD ClearProduct.
    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
    ENTITY ClassificationRule
    FIELDS ( Product IsNotBillable )
        WITH CORRESPONDING #( keys )
        RESULT DATA(current_rules).

    DELETE current_rules WHERE IsNotBillable = abap_false.

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
        UPDATE FIELDS ( Product )
        WITH CORRESPONDING #( current_rules EXCEPT Product )
        REPORTED DATA(modifiy_reported).

    reported = CORRESPONDING #( DEEP modifiy_reported ).

  ENDMETHOD.


  METHOD ValidateBillRelation.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
       ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(current_rules).

    IF current_rules IS NOT INITIAL.
      SELECT DISTINCT providercompanycode AS companycode, product FROM ZI_IntercoCompanyRelProduct
      WITH PRIVILEGED ACCESS
    FOR ALL ENTRIES IN @current_rules
        WHERE Product = @current_rules-Product
          AND ValidFrom <= @current_rules-validto
          AND ValidTo >= @current_rules-validfrom
          AND IsDeleted IS INITIAL
          INTO TABLE @DATA(products_flows).
    ENDIF.

    LOOP AT current_rules REFERENCE INTO DATA(rule).

      DATA(key) = keys[ %tky = rule->%tky ].

      APPEND VALUE #( %tky        = key-%tky
                      %state_area = 'VALIDATE_BILLABLE_RELATION'
      ) TO reported-classificationrule.

      " Validate only Billable rules
      IF rule->IsNotBillable = abap_true.
        CONTINUE.
      ENDIF.

      IF rule->ExcelLineNumber > 0.
        DATA(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      ENDIF.

      IF ( rule->CompanyCode IS INITIAL AND NOT line_exists( products_flows[ Product = rule->Product ] ) ) OR
         ( rule->CompanyCode IS NOT INITIAL AND NOT line_exists( products_flows[ CompanyCode = rule->CompanyCode Product = rule->Product ] ) ).

        APPEND VALUE #( %tky = key-%tky ) TO failed-classificationrule.

        DATA(out_product) = |{ rule->Product ALPHA = OUT }|.
        DATA(out_companycode) = COND #( WHEN rule->CompanyCode IS INITIAL THEN `*` ELSE |{ rule->CompanyCode ALPHA = OUT }| ).

        APPEND VALUE #( %tky             = rule->%tky
                        %state_area      = 'VALIDATE_BILLABLE_RELATION'
                        %msg             = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        v2       = out_product
                        v3       = out_companycode
                        textid   = zcl_fi_intrc_messages=>relation_not_exists
                        severity = if_abap_behv_message=>severity-error )
                        %element-product = if_abap_behv=>mk-on
        ) TO reported-classificationrule ASSIGNING FIELD-SYMBOL(<reported>).

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD ValidateDuplicated.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
     ENTITY ClassificationRule
      ALL FIELDS WITH CORRESPONDING #( keys )
   RESULT DATA(current_rules).

    DATA all_rules LIKE current_rules.
    DATA duplicate_rules LIKE current_rules.

    IF current_rules IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM zr_intercoclassificationrule WITH PRIVILEGED ACCESS
    FIELDS
      id,
      RuleID,
      RuleName,
      ValidFrom,
      ValidTo,
      CompanyCode,
      Ledger,
      PAndLID,
      PandLLevel,
      ProfitCenter,
      CcStdHierArea,
      CcAllocation,
      CcConsolidation,
      Product,
      IsNotBillable
    FOR ALL ENTRIES IN @current_rules
      WHERE ValidFrom <= @current_rules-validto
        AND ValidTo >= @current_rules-validfrom
        AND CompanyCode = @current_rules-CompanyCode
        AND Ledger = @current_rules-Ledger
        AND PAndLID = @current_rules-PAndLID
        AND CcAllocation = @current_rules-CcAllocation
        AND CcConsolidation = @current_rules-CcConsolidation
        AND ProfitCenter = @current_rules-ProfitCenter
        AND IsDeleted IS INITIAL
        INTO CORRESPONDING FIELDS OF TABLE @all_rules.

    APPEND LINES OF current_rules TO all_rules.

*    select distinct idl5, idl4, idl3, idl2, idl1, idl0
*    from z_pnl_mt005
*    with privileged access
*        for all entries in @current_rules
*        where idl5 = @current_rules-PAndLID or
*              idl4 = @current_rules-PandLID or
*              idl3 = @current_rules-PandLID or
*              idl2 = @current_rules-PandLID or
*              idl1 = @current_rules-PandLID or
*              idl0 = @current_rules-PandLID
*              into table @data(spread_pandls).

*    try.
*        types: tt_range_pandl type range of zr_intercoclassificationrule-PAndLID.
*        data(spread_pandl) = ref #( spread_pandls[ 1 ] ).
*        data(range_pandls) = value tt_range_pandl(
*                                ( sign = 'I' option = 'EQ' low = spread_pandl->IdL5 )
*                                ( sign = 'I' option = 'EQ' low = spread_pandl->IdL4 )
*                                ( sign = 'I' option = 'EQ' low = spread_pandl->IdL3 )
*                                ( sign = 'I' option = 'EQ' low = spread_pandl->IdL2 )
*                                ( sign = 'I' option = 'EQ' low = spread_pandl->IdL1 )
*                                ( sign = 'I' option = 'EQ' low = spread_pandl->IdL0 ) ).
*      catch cx_sy_itab_line_not_found.
*    endtry.

    DATA range_all_pandl TYPE RANGE OF ZI_IntercoPandLHierFlattenedSH-id.
    SELECT DISTINCT 'I' AS sign, 'EQ' AS option, id AS low, @space AS high
        FROM ZI_IntercoPandLHierFlattenedSH
        WITH PRIVILEGED ACCESS
        WHERE 1 = 1
            INTO TABLE @range_all_pandl.

    DATA range_all_companycodes TYPE RANGE OF zr_intercoclassificationrule-companycode.
    SELECT DISTINCT 'I' AS sign, 'EQ' AS option, providercompanycode AS low, @space AS high
        FROM ZI_IntercoCompanyRelProduct
        WITH PRIVILEGED ACCESS
        WHERE 1 = 1
            INTO TABLE @range_all_companycodes.

    DATA range_all_profitcenters TYPE RANGE OF  zr_intercoclassificationrule-profitcenter.
    SELECT DISTINCT 'I' AS sign, 'EQ' AS option, profitcenter AS low, @space AS high
        FROM I_ProfitCenter
        WITH PRIVILEGED ACCESS
            WHERE ControllingArea = 'ML00'
                INTO TABLE @range_all_profitcenters.

    DATA range_all_cc_allocations TYPE RANGE OF  zr_intercoclassificationrule-ccallocation.
    SELECT DISTINCT 'I' AS sign, 'EQ' AS option, HierarchyNodeVal AS low, @space AS high
        FROM I_CostCenterHierarchyNode
        WITH PRIVILEGED ACCESS
            WHERE ControllingArea = 'ML00'
              AND CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
              AND NodeType = 'N'
                INTO TABLE @range_all_cc_allocations.

    DATA range_all_cc_consolidations TYPE RANGE OF  zr_intercoclassificationrule-CcConsolidation.
    SELECT DISTINCT 'I' AS sign, 'EQ' AS option, HierarchyNodeVal AS low, @space AS high
        FROM I_CostCenterHierarchyNode
        WITH PRIVILEGED ACCESS
            WHERE ControllingArea = 'ML00'
              AND CostCenterHierarchy = 'H101/ML00/CONS_CC'
              AND NodeType = 'N'
                INTO TABLE @range_all_cc_consolidations.

    DATA range_companycodes LIKE range_all_companycodes.
    DATA range_profitcenters LIKE range_all_profitcenters.
    DATA range_cc_allocations LIKE  range_all_cc_allocations.
    DATA range_cc_consolidations LIKE range_all_cc_consolidations.
    DATA range_pandl LIKE range_all_pandl.

    LOOP AT current_rules REFERENCE INTO DATA(rule).

      range_companycodes = range_all_companycodes.
      DELETE range_companycodes WHERE low <> rule->companycode.

      range_profitcenters = range_all_profitcenters.
      DELETE range_profitcenters WHERE low <> rule->profitcenter.

      range_cc_allocations = range_all_cc_allocations.
      DELETE range_cc_allocations WHERE low <> rule->CcAllocation.

      range_cc_consolidations = range_all_cc_consolidations.
      DELETE range_cc_consolidations WHERE low <> rule->ccconsolidation.

      range_pandl = range_all_pandl.
      DELETE range_pandl WHERE low <> rule->PAndLID.

*Ini mod - ext_jugesto - DS4K9B4I10 - 09.09.2025
      duplicate_rules = VALUE #( FOR duplicate_rule IN all_rules
                                 WHERE ( CompanyCode = rule->companycode
                                         AND Ledger = rule->Ledger
                                         AND CcAllocation = rule->CcAllocation
                                         AND CcConsolidation = rule->ccconsolidation
                                         AND CcStdHierArea = rule->CcStdHierArea
                                         AND PAndLID = rule->PAndLID
                                         AND ProfitCenter = rule->profitcenter
                                         AND IsNotBillable = rule->IsNotBillable
                                         AND id <> rule->id )
                               (                           duplicate_rule ) ).
*Fin mod - ext_jugesto - DS4K9B4I10 - 09.09.2025

      DATA(key) = keys[ %tky = rule->%tky ].

      APPEND VALUE #( %tky        = key-%tky
                      %state_area = 'VALIDATE_DUPLICATED'
      ) TO reported-classificationrule.
      IF lines( duplicate_rules ) > 0.
        IF rule->ExcelLineNumber > 0.
          DATA(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
        ENDIF.

        APPEND VALUE #( %tky = key-%tky ) TO failed-classificationrule.
        APPEND VALUE #( %tky        = rule->%tky
                        %state_area = 'VALIDATE_DUPLICATED'
                        %msg        = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        textid   = zcl_fi_intrc_messages=>duplicated_rule
                        severity = if_abap_behv_message=>severity-error )
        ) TO reported-classificationrule.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD Delete.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
        ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(current_rules).

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
           ENTITY ClassificationRule
              UPDATE FIELDS ( IsDeleted )
                 WITH VALUE #( FOR key IN keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 IsDeleted = abap_true ) ).

    " Read changed data for action result
    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(rules).

    LOOP AT rules REFERENCE INTO DATA(rule).
      rule->RuleCriticality = COND #( WHEN rule->IsDeleted = abap_true THEN '1' ELSE '0' ).
    ENDLOOP.

    result = VALUE #( FOR r IN rules ( %tky   = r-%tky
                                       %param = r ) ).

  ENDMETHOD.

  METHOD Restore.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
        ALL FIELDS WITH CORRESPONDING #( keys )
            RESULT DATA(current_rules).

    MODIFY ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
           ENTITY ClassificationRule
              UPDATE FIELDS ( IsDeleted )
                 WITH VALUE #( FOR key IN keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 IsDeleted = abap_false ) ).

    " Read changed data for action result
    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
      ENTITY ClassificationRule
         ALL FIELDS WITH
         CORRESPONDING #( keys )
       RESULT DATA(rules).

    result = VALUE #( FOR rule IN rules ( %tky   = rule-%tky
                                          %param = rule ) ).


  ENDMETHOD.

  METHOD ValidateAllFields.

    READ ENTITIES OF zr_intercoclassificationrule IN LOCAL MODE
        ENTITY ClassificationRule
            ALL FIELDS WITH
                CORRESPONDING #( keys )
                RESULT DATA(rules).

    IF rules IS INITIAL.
      RETURN.
    ENDIF.

    "$. Region get_data - Search for the given values in their corresponding VH tables.
    SELECT DISTINCT companycode FROM ZI_IntercoCompanyCodeVH
        WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @rules
        WHERE companycode = @rules-CompanyCode
            INTO TABLE @DATA(company_codes).

    SELECT DISTINCT id AS PAndLID FROM ZI_IntercoPandLHierFlattenedSH
        WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @rules
          WHERE id = @rules-PAndLID
            INTO TABLE @DATA(pandl_ids).

    SELECT DISTINCT profitcenter FROM i_profitcenter
        WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @rules
            WHERE controllingarea = 'ML00'
              AND profitcenter = @rules-ProfitCenter
              AND ValidityEndDate >= @rules-validfrom
              AND ValidityStartDate <= @rules-ValidTo
                INTO TABLE @DATA(profit_centers).

    SELECT DISTINCT Product FROM ZI_IntercoProduct_SH
        WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @rules
            WHERE Product = @rules-Product
                INTO TABLE @DATA(products).

    TYPES: BEGIN OF ty_converted_columns,
             CcStdHierArea   TYPE i_costcenterhierarchynode-hierarchynodeval,
             CcAllocation    TYPE i_costcenterhierarchynode-hierarchynodeval,
             CcConsolidation TYPE i_costcenterhierarchynode-hierarchynodeval,
           END OF ty_converted_columns,
           tt_converted_columns TYPE TABLE OF ty_converted_columns WITH DEFAULT KEY.

    DATA(converted_columns) = VALUE tt_converted_columns(
                                        FOR r IN rules ( ccstdhierarea   = r-CcStdHierArea
                                                         ccallocation    = r-CcAllocation
                                                         ccconsolidation = r-CcConsolidation ) ).

    SELECT DISTINCT CostCenterSubArea AS CcStdHierArea FROM ZI_IntercoCostCenterSubArea_SH
      WITH PRIVILEGED ACCESS
      FOR ALL ENTRIES IN @converted_columns
          WHERE CostCenterSubArea =  @converted_columns-ccstdhierarea
          INTO TABLE @DATA(cc_stdhierareas).

    SELECT DISTINCT Allocation AS CcAllocation FROM ZI_IntercoCostCenterAlloc_SH
        WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @converted_columns
            WHERE Allocation = @converted_columns-CcAllocation
              INTO TABLE @DATA(cc_allocations).

    SELECT DISTINCT Consolidation AS CcConsolidation FROM ZI_IntercoCostCenterConsVH
        WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @converted_columns
            WHERE Consolidation = @converted_columns-CcConsolidation
                INTO TABLE @DATA(cc_consolidations).
    "$. EndRegion get_data.


    " Perform Validations
    LOOP AT rules REFERENCE INTO DATA(rule).

      APPEND VALUE #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_ALL'
      ) TO reported-classificationrule.

      IF rule->ExcelLineNumber > 0.
        DATA(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      ENDIF.


      " Company Code
      IF rule->companycode IS NOT INITIAL AND NOT line_exists( company_codes[ CompanyCode = rule->CompanyCode ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky                 = rule->%tky
                        %state_area          = 'VALIDATE_ALL'
                        %msg                 = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->companycode
                        v3       = 'Company Code'(002)
                        )
                        %element-companycode = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " P&L ID
      IF rule->pandlid IS NOT INITIAL AND NOT line_exists( pandl_ids[ pandlid = rule->PAndLID ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky             = rule->%tky
                        %state_area      = 'VALIDATE_ALL'
                        %msg             = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->pandlid
                        v3       = 'P&L ID'(003)
                        )
                        %element-pandlid = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " Profit Center
      IF rule->profitcenter IS NOT INITIAL AND NOT line_exists( profit_centers[ profitcenter = rule->profitcenter ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky                  = rule->%tky
                        %state_area           = 'VALIDATE_ALL'
                        %msg                  = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->profitcenter
                        v3       = 'Profit Center'(004)
                        )
                        %element-profitcenter = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " Product
      IF rule->product IS NOT INITIAL AND NOT line_exists( products[ product = rule->product ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky             = rule->%tky
                        %state_area      = 'VALIDATE_ALL'
                        %msg             = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->product
                        v3       = 'Product'(005)
                        )
                        %element-product = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " CcStdHierArea
      IF rule->CcStdHierArea IS NOT INITIAL AND NOT line_exists( cc_stdhierareas[ ccstdhierarea = rule->CcStdHierArea ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky                   = rule->%tky
                        %state_area            = 'VALIDATE_ALL'
                        %msg                   = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->ccstdhierarea
                        v3       = 'CC. Std. Hierarchy Area'(006)
                        )
                        %element-ccstdhierarea = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " CcAllocation
      IF rule->CcAllocation IS NOT INITIAL AND NOT line_exists( cc_allocations[ CcAllocation = rule->CcAllocation ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky                  = rule->%tky
                        %state_area           = 'VALIDATE_ALL'
                        %msg                  = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->ccallocation
                        v3       = 'CC. Allocation'(007)
                        )
                        %element-ccallocation = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " CcConsolidation
      IF rule->ccconsolidation IS NOT INITIAL AND NOT line_exists( cc_consolidations[ ccconsolidation = rule->ccconsolidation ] ).
        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).
        APPEND VALUE #( %tky                     = rule->%tky
                        %state_area              = 'VALIDATE_ALL'
                        %msg                     = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->ccconsolidation
                        v3       = 'CC. Consolidation'(008)
                        )
                        %element-ccconsolidation = if_abap_behv=>mk-on
        ) TO reported-classificationrule.
      ENDIF.

      " PaymentType: vacío, E o L
      IF rule->PaymentType IS NOT INITIAL
         AND rule->PaymentType <> 'E'
         AND rule->PaymentType <> 'L'.

        failed-classificationrule = VALUE #( ( %tky = rule->%tky ) ).

        APPEND VALUE #( %tky                 = rule->%tky
                        %state_area          = 'VALIDATE_ALL'
                        %msg                 = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->PaymentType
                        v3       = 'Payment Type'
                        )
                        %element-PaymentType = if_abap_behv=>mk-on
        ) TO reported-classificationrule.

      ENDIF.

    ENDLOOP.



  ENDMETHOD.

ENDCLASS.
