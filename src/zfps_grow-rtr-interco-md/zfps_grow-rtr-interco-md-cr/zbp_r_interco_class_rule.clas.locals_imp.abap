class lsc_classificationrule definition inheriting from cl_abap_behavior_saver.

  protected section.

    methods save_modified redefinition.

endclass.

class lsc_classificationrule implementation.

  method save_modified.

    if create-classificationrule is initial and
       update-classificationrule is initial and
       delete-classificationrule is initial.
      return.
    endif.

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

  endmethod.

endclass.

class lcl_numberrange_rule_id definition.
  public section.

    data ty_keys type table for determination zr_intercoclassificationrule\\classificationrule~setruleid.
    types ty_key like line of ty_keys.
    interfaces if_abap_parallel.

    methods:
      constructor
        importing key type ty_key.

    data rule_id type zint_rule_id.
    data key type ty_key.
endclass.

class lcl_numberrange_rule_id implementation.

  method constructor.
    me->key = key.
  endmethod.

  method if_abap_parallel~do.
    try.
        data(number_range) = cast if_numberrange_buffer( cl_numberrange_buffer=>get_instance( ) ).
        number_range->number_get_no_buffer(
          exporting
            iv_object   = zif_co_interco_class_rule=>range_number
            iv_interval = '01'
            iv_quantity = 1
          importing
            ev_number   = data(rule_id)
        ).

        me->rule_id = conv #( rule_id ).
      catch cx_number_ranges.
    endtry.
  endmethod.
endclass.



class lhc_classificationrule definition inheriting from cl_abap_behavior_handler.
  private section.
    methods:
      get_global_authorizations for global authorization
        importing
        request requested_authorizations for ClassificationRule
        result result,

      SetRuleId for determine on save
        importing keys for ClassificationRule~SetRuleId,

      get_instance_features for instance features
        importing keys request requested_features for ClassificationRule result result.

    methods DefaultForCreate for read
      importing keys for function ClassificationRule~DefaultForCreate result result.

    methods CopyClassificationRule for modify
      importing keys for action ClassificationRule~CopyClassificationRule.

    methods Delimit for modify
      importing keys for action ClassificationRule~Delimit result result.

    " This methods is relevant only for the Copy action.
    methods ValidateDateOverlap for validate on save
      importing keys for ClassificationRule~ValidateDateOverlap.

    methods ValidateValidTo for validate on save
      importing keys for ClassificationRule~ValidateValidTo.

    methods ValidateRequired for validate on save
      importing keys for ClassificationRule~ValidateRequired.

    methods ClearProduct for determine on modify
      importing keys for ClassificationRule~ClearProduct.
    methods ValidateBillRelation for validate on save
      importing keys for ClassificationRule~ValidateBillRelation.
    methods ValidateDuplicated for validate on save
      importing keys for ClassificationRule~ValidateDuplicated.
    methods Delete for modify
      importing keys for action ClassificationRule~Delete result result.

    methods Restore for modify
      importing keys for action ClassificationRule~Restore result result.
    methods SetPandLevel for determine on save
      importing keys for ClassificationRule~SetPandLevel.

    "! Validate fields that are linked to search helps
    methods ValidateAllFields for validate on save
      importing keys for ClassificationRule~ValidateAllFields.

endclass.

class lhc_classificationrule implementation.

  method get_global_authorizations.
    data display_error type abap_boolean.

    data(can_delete) = zcl_interco=>authority->for( zcl_interco_authority=>c_delete ).
    data(can_create) = zcl_interco=>authority->for( zcl_interco_authority=>c_create ).
    data(can_update) = zcl_interco=>authority->for( zcl_interco_authority=>c_update ).

    " Check DELETE
    result-%delete = can_delete.
    result-%action-Restore = can_delete.
    if can_delete = if_abap_behv=>auth-unauthorized and (
          requested_authorizations-%delete = if_abap_behv=>mk-on or
          requested_authorizations-%action-Restore = if_abap_behv=>mk-on ).
      display_error = abap_true.
    endif.

    " Check CREATE
    result-%create = can_create.
    result-%action-CopyClassificationRule = can_create.
    result-%action-Edit = can_create.

    if can_create = if_abap_behv=>auth-unauthorized and (
       requested_authorizations-%create = if_abap_behv=>mk-on or
       requested_authorizations-%action-CopyClassificationRule = if_abap_behv=>mk-on or
       requested_authorizations-%action-Edit = if_abap_behv=>mk-on ).
      display_error = abap_true.
    endif.

    " Check UPDATE
    result-%action-Delete = can_update.
    result-%action-Delimit = can_update.
    result-%action-Edit = can_update.
    result-%update = can_update.

    if can_update =  if_abap_behv=>auth-unauthorized and (
       requested_authorizations-%update = if_abap_behv=>mk-on or
       requested_authorizations-%action-Edit = if_abap_behv=>mk-on or
       requested_authorizations-%action-Delimit = if_abap_behv=>mk-on or
       requested_authorizations-%action-Delete = if_abap_behv=>mk-on ).
      display_error = abap_true.
    endif.

    if display_error = abap_true.
      append value #( %msg    = zcl_fi_intrc_messages=>new_message(
                      textid   = zcl_fi_intrc_messages=>no_authority
                      severity = if_abap_behv_message=>severity-error )
                      %global = if_abap_behv=>mk-on ) to reported-classificationrule.
    endif.

  endmethod.

  method SetRuleId.

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
    data(parallel_processing) = new cl_abap_parallel(  ).

    read entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
            fields ( RuleId )
            with corresponding #( keys )
            result data(rules).

    delete rules where ruleid is not initial.

    parallel_processing->run_inst(
      exporting
        p_in_tab  = value #( for r in rules ( new lcl_numberrange_rule_id( key = corresponding #( r ) ) ) )
      importing
        p_out_tab = data(parallel_results)
    ).

    loop at parallel_results into data(parallel_result).
      data(numberrange_rule_id) =  cast lcl_numberrange_rule_id( parallel_result-inst ).
      data(rule) = ref #( rules[ key entity %key = numberrange_rule_id->key-%key ] ).
      rule->RuleID = numberrange_rule_id->rule_id.
    endloop.

    modify entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
            update fields ( RuleID ) with corresponding #( rules )
                reported data(reported_modify)
                failed data(failed_modify)
                mapped data(mapped_modify).

    reported = corresponding #( deep reported_modify ).

  endmethod.


  method SetPandLevel.

    read entities of zr_intercoclassificationrule in local mode
        entity classificationrule
            fields ( pandlid )
            with corresponding #( keys )
            result data(rules).

    if rules is not initial.
      select id, customerlevel from ZI_IntercoPandLHierFlattenedSH
      with privileged access
          for all entries in @rules
          where id = @rules-PAndLID
          into table @data(pandl_levels).
    endif.

    loop at rules reference into data(rule).

      try.
          rule->PAndLLevel = pandl_levels[ id = rule->PAndLID ]-CustomerLevel.
        catch cx_sy_itab_line_not_found.
          continue.
      endtry.

    endloop.

    modify entities of ZR_IntercoClassificationRule in local mode
        entity classificationrule
            update fields ( PAndLLevel ) with corresponding #( rules )
            reported data(reported_modify)
            failed data(failed_modify)
            mapped data(mapped_modify).

    reported = corresponding #( deep reported_modify ).


  endmethod.

  method get_instance_features.
    constants: begin of c_product_flow,
                 outflow type zi_intercocompanyrelproduct-Flow value 'O',
                 inflow  type zi_intercocompanyrelproduct-Flow value 'I',
               end of c_product_flow.


    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
          fields ( ValidFrom ValidTo CompanyCode IsNotBillable Product IsDeleted IsNotDeleted )
              with corresponding #( keys )
              result data(current_rules).

    if current_rules is not initial.
      select providercompanycode as companycode, product, flow from ZI_IntercoCompanyRelProduct
      with privileged access
      for all entries in @current_rules
          where Product = @current_rules-Product
            and ValidFrom <= @current_rules-validto
            and ValidTo >= @current_rules-validfrom
            and IsDeleted is initial
            into table @data(products_flows).
    endif.

    loop at current_rules reference into data(current_rule).

      try.
          data(product_flow) = products_flows[ companycode = current_rule->CompanyCode product = current_rule->product ].
        catch cx_sy_itab_line_not_found.
          try.
              product_flow = products_flows[ product = current_rule->product ].
            catch cx_sy_itab_line_not_found.
          endtry.
      endtry.

      "  Fields:
      data(required_when_outflow) = cond #( when product_flow-Flow = c_product_flow-outflow then if_abap_behv=>fc-f-mandatory else if_abap_behv=>fc-f-unrestricted ).
      data(required_when_inflow) = cond #( when product_flow-Flow = c_product_flow-inflow then if_abap_behv=>fc-f-mandatory else if_abap_behv=>fc-f-unrestricted ).
      data(required_when_billable) = cond #( when current_rule->IsNotBillable = abap_false then if_abap_behv=>fc-f-mandatory else if_abap_behv=>fc-f-unrestricted ).

      data(enable_when_billable) = cond #(
              when current_rule->IsNotBillable = abap_true
                then if_abap_behv=>fc-f-read_only
                else if_abap_behv=>fc-f-mandatory ).

      "  Actions:
      data(can_delimit) = cond #(
              when current_rule->%is_draft = if_abap_behv=>mk-on
                  then if_abap_behv=>fc-o-disabled
                  else if_abap_behv=>fc-o-enabled ).

      data(can_restore) = cond #(
        when current_rule->%is_draft = if_abap_behv=>mk-on then if_abap_behv=>fc-o-disabled
        when current_rule->IsDeleted = abap_true then if_abap_behv=>fc-o-enabled
        else if_abap_behv=>fc-o-disabled ).

      data(can_mark_as_deleted) = cond #(
        when current_rule->%is_draft = if_abap_behv=>mk-on then if_abap_behv=>fc-o-disabled
        when current_rule->IsDeleted = abap_true then if_abap_behv=>fc-o-disabled
        else if_abap_behv=>fc-o-enabled ).

      " Operations:
      data(can_edit) = cond #(
          when current_rule->IsDeleted = abap_true
              then if_abap_behv=>fc-o-disabled
              else if_abap_behv=>fc-o-enabled
      ).

      append value #(
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
                        %field-CcStdHierArea = required_when_outflow
                        %field-CcAllocation  = required_when_outflow ) to result.
    endloop.
  endmethod.

  method DefaultForCreate.

    data(today) = cl_abap_context_info=>get_system_date( ).
    result = value #( for key in keys (
                      %cid                       = key-%cid
                      %param-%is_draft           = if_abap_Behv=>mk-on
                      %param-%data-ValidFrom     = |{ today(6) }01|
                      %param-%data-ValidTo       = |{ today(4) }1231|
                      %param-%data-IsNotBillable = abap_false ) ).
  endmethod.

  method CopyClassificationRule.

    data:
      new_rules      type table for create zr_intercoclassificationrule\\ClassificationRule,
      delimited_keys type table for action import zr_intercoclassificationrule\\ClassificationRule~Delimit.

    read table keys with key %cid = '' into data(key_with_inital_cid).
    assert key_with_inital_cid is initial.

    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
       all fields with corresponding #( keys )
    result data(current_rules)
    failed failed.

    loop at current_rules assigning field-symbol(<current_rule>).
      data(key) = keys[ %tky = <current_rule>-%tky ].

      " A copy operation can result in either:
      " 1. A New Rule based on an existing one (RuleID filled), or
      " 2. A new version of an existing rule (RuleID empty).
      "
      " For the second scenario, we need to delimit the copied record to ensure the new version
      " becomes the valid one.
      if key-%param-RuleID is not initial and
         <current_rule>-validto >= key-%param-validfrom.
        append initial line to delimited_keys  assigning field-symbol(<delimited_key>).
        <delimited_key> = corresponding #( key ).
        <delimited_key>-%param-ValidTo = key-%param-ValidFrom - 1.
      endif.

      append value #( %cid      = key-%cid
                      %is_draft = cond #( when key-%param-RuleId is not initial then if_abap_behv=>mk-off else if_abap_behv=>mk-on )
                      %data     = corresponding #( <current_rule> except id ) )
                        to new_rules assigning field-symbol(<new_rule>).

      data(today) = cl_abap_context_info=>get_system_date( ).

      <new_rule>-RuleId = key-%param-RuleID.
      <new_rule>-validfrom   = key-%param-validfrom.
      <new_rule>-validto     = |{ today(4) }1231|.

    endloop.

    modify entities of zr_intercoclassificationrule in local mode
       entity ClassificationRule
         execute delimit from delimited_keys
            mapped data(mapped_delimit)
            failed data(failed_delimit)
            reported data(reporte_delimit).

    if failed-classificationrule is not initial.
      mapped = corresponding #( mapped_delimit ).
      failed = corresponding #( failed_delimit ).
      reported = corresponding #( reporte_delimit ).
      return.
    endif.

    modify entities of zr_intercoclassificationrule in local mode
    entity ClassificationRule
    create fields ( RuleID RuleName CompanyCode Ledger ProfitCenter CcStdHierArea CcAllocation CcConsolidation PAndLID Product IsNotBillable ValidFrom ValidTo )
           with new_rules
  mapped mapped
  failed failed
  reported reported.

  endmethod.

  method Delimit.
    read entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
        all fields with corresponding #( keys )
            result data(current_rules).

    modify entities of zr_intercoclassificationrule in local mode
           entity ClassificationRule
              update fields ( validfrom validto ) " The necessity of providing valid from is due to the date validations that required both fields.
                 with value #( for key in keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 validfrom = current_rules[ key entity id = key-id ]-validfrom
                                                 validto   = key-%param-validto ) ).

    " Read changed data for action result
    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
         all fields with
         corresponding #( keys )
       result data(rules).

    result = value #( for rule in rules ( %tky   = rule-%tky
                                          %param = rule ) ).
  endmethod.

  method ValidateDateOverlap.
    read entities of zr_intercoclassificationrule in local mode
       entity ClassificationRule
        all fields with corresponding #( keys )
     result data(current_rules).

    if current_rules is not initial.
      select Id, RuleId, ValidTo, ValidFrom
      from zr_intercoclassificationrule
      with privileged access
      for all entries in @current_rules
      where RuleID = @current_rules-RuleID
        and IsDeleted = @abap_false
          into table @data(db_rules).
    endif.

    " Update db_exemptions with the coming changes to ensure validation considers updated dates.
    data(combined_rules) = db_rules.
    loop at current_rules into data(current_rule).
      modify combined_rules from corresponding #( current_rule )
        transporting ValidFrom ValidTo where RuleId = current_rule-RuleId.
    endloop.

    loop at current_rules into data(exemption).
      append value #( %tky        = exemption-%tky
                      %state_area = 'VALIDATE_DATE_OVERLAP'
      ) to reported-classificationrule.

      data invalid_rules like combined_rules.
      invalid_rules = value #( for existing_exemption in combined_rules
                               where ( ruleid = exemption-ruleid and
                               id <> exemption-id and
                               validto >= exemption-validfrom and
                               validfrom <= exemption-validto )
                               (              existing_exemption ) ).

      if invalid_rules is not initial.
        failed-classificationrule = value #( for failed_exemption in invalid_rules ( %tky = exemption-%tky ) ).
        append value #( %tky               = exemption-%tky
                        %state_area        = 'VALIDATE_DATE_OVERLAP'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>date_overlaps
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
                        %element-validto   = if_abap_behv=>mk-on
        ) to reported-classificationrule.

      endif.
    endloop.


  endmethod.

  method ValidateValidTo.

    read entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
         all fields with corresponding #( keys )
      result data(current_rules).

    loop at current_rules reference into data(rule).

      data(key) = keys[ %tky = rule->%tky ].

      append value #( %tky        = key-%tky
                      %state_area = 'VALIDATE_DATE_INTERVAL'
      ) to reported-classificationrule.

      if rule->ExcelLineNumber > 0.
        data(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      endif.


      if rule->validfrom > rule->validto.
        append value #( %tky = key-%tky ) to failed-classificationrule.
        append value #( %tky               = key-%tky
                        %state_area        = 'VALIDATE_DATE_INTERVAL'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        textid   = zcl_fi_intrc_messages=>date_interval
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

    endloop.

  endmethod.


  method ValidateRequired.

    data permission_request type structure for permissions request zr_intercoclassificationrule.

    " Implementation of a generic method for validating mandatory fields,
    " covering both those statically defined in the behavior definition
    " and those dynamically defined via `features: instance` in the `get_instance_features` method.
    data(components) = cast cl_abap_structdescr( cl_abap_structdescr=>describe_by_name( 'ZR_IntercoClassificationRule' ) )->get_components( ).

    loop at components reference into data(component).
      permission_request-%field-(component->name) = if_abap_behv=>mk-on.
    endloop.

    data instance_permissions type table for instance features result zr_intercoclassificationrule\\classificationrule .
    get permissions of zr_intercoclassificationrule
      entity ClassificationRule
      from corresponding #( keys )
    request permission_request
    result data(permissions).

    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
      all fields
      with corresponding #( keys )
      result data(current_rules).

    loop at current_rules reference into data(rule).

      append value #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_REQUIRED'
      ) to reported-classificationrule.

      if rule->ExcelLineNumber > 0.
        data(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      endif.


      "  Validate mandatory fields
      do lines( components ) times.
        component = ref #( components[ sy-index ] ).
        if ( permissions-global-%field-(component->name) = if_abap_behv=>mk-on or
             permissions-instances[ key entity %key = rule->%key ]-%field-(component->name) = if_abap_behv=>mk-on )
           and rule->(component->name) is initial.

          "  Mark validation failure
          append value #( %tky = rule->%tky ) to failed-classificationrule.

          "  Register validation error message
          append initial line to reported-classificationrule assigning field-symbol(<reported_entity>).
          <reported_entity> = value #( %tky        = rule->%tky
                                       %state_area = 'VALIDATE_REQUIRED'
                                       %msg        = zcl_fi_intrc_messages=>new_message(
                                       v1       = line_number
                                       v2       = |'{ <reported_entity>-%element-(component->name) }'(|
                                       textid   = zcl_fi_intrc_messages=>field_required
                                       severity = if_abap_behv_message=>severity-error ) ).

          "  Indicate the specific field that failed validation
          <reported_entity>-%element-(component->name) = if_abap_behv=>mk-on.
        endif.
      enddo.

      "  Ensure that at least one of the Input fields is filled
      append value #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_INPUT'
      ) to reported-classificationrule.

      if rule->CcAllocation is initial and
        rule->CcConsolidation is initial and
        rule->CcStdHierArea is initial and
        rule->CompanyCode is initial and
        rule->PAndLID is initial and
        rule->ProfitCenter is initial.
        append value #( %tky = rule->%tky ) to failed-classificationrule.
        append value #( %tky        = rule->%tky
                        %state_area = 'VALIDATE_INPUT'
                        %msg        = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        textid   = zcl_fi_intrc_messages=>at_least_one_required
                        severity = if_abap_behv_message=>severity-error )
        ) to reported-classificationrule assigning field-symbol(<reported>).

        <reported>-%element-CCAllocation    = if_abap_behv=>mk-on.
        append <reported> to reported-classificationrule assigning <reported>.
        <reported>-%element-CcConsolidation = if_abap_behv=>mk-on.
        append <reported> to reported-classificationrule assigning <reported>.
        <reported>-%element-CcStdHierArea   = if_abap_behv=>mk-on.
        append <reported> to reported-classificationrule assigning <reported>.
        <reported>-%element-CompanyCode     = if_abap_behv=>mk-on.
        append <reported> to reported-classificationrule assigning <reported>.
        <reported>-%element-PAndLId         = if_abap_behv=>mk-on.
        append <reported> to reported-classificationrule assigning <reported>.
        <reported>-%element-ProfitCenter    = if_abap_behv=>mk-on.

      endif.
    endloop.

  endmethod.

  method ClearProduct.
    read entities of zr_intercoclassificationrule in local mode
    entity ClassificationRule
    fields ( Product IsNotBillable )
        with corresponding #( keys )
        result data(current_rules).

    delete current_rules where IsNotBillable = abap_false.

    modify entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
        update fields ( Product )
        with corresponding #( current_rules except Product )
        reported data(modifiy_reported).

    reported = corresponding #( deep modifiy_reported ).

  endmethod.


  method ValidateBillRelation.

    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
       all fields with corresponding #( keys )
    result data(current_rules).

    if current_rules is not initial.
      select distinct providercompanycode as companycode, product from ZI_IntercoCompanyRelProduct
      with privileged access
    for all entries in @current_rules
        where Product = @current_rules-Product
          and ValidFrom <= @current_rules-validto
          and ValidTo >= @current_rules-validfrom
          and IsDeleted is initial
          into table @data(products_flows).
    endif.

    loop at current_rules reference into data(rule).

      data(key) = keys[ %tky = rule->%tky ].

      append value #( %tky        = key-%tky
                      %state_area = 'VALIDATE_BILLABLE_RELATION'
      ) to reported-classificationrule.

      " Validate only Billable rules
      if rule->IsNotBillable = abap_true.
        continue.
      endif.

      if rule->ExcelLineNumber > 0.
        data(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      endif.

      if ( rule->CompanyCode is initial and not line_exists( products_flows[ Product = rule->Product ] ) ) or
         ( rule->CompanyCode is not initial and not line_exists( products_flows[ CompanyCode = rule->CompanyCode Product = rule->Product ] ) ).

        append value #( %tky = key-%tky ) to failed-classificationrule.

        data(out_product) = |{ rule->Product alpha = out }|.
        data(out_companycode) = cond #( when rule->CompanyCode is initial then `*` else |{ rule->CompanyCode alpha = out }| ).

        append value #( %tky             = rule->%tky
                        %state_area      = 'VALIDATE_BILLABLE_RELATION'
                        %msg             = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        v2       = out_product
                        v3       = out_companycode
                        textid   = zcl_fi_intrc_messages=>relation_not_exists
                        severity = if_abap_behv_message=>severity-error )
                        %element-product = if_abap_behv=>mk-on
        ) to reported-classificationrule assigning field-symbol(<reported>).

      endif.

    endloop.

  endmethod.

  method ValidateDuplicated.

    read entities of zr_intercoclassificationrule in local mode
     entity ClassificationRule
      all fields with corresponding #( keys )
   result data(current_rules).

    data all_rules like current_rules.
    data duplicate_rules like current_rules.

    if current_rules is initial.
      return.
    endif.

    select from zr_intercoclassificationrule with privileged access
    fields
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
    for all entries in @current_rules
      where ValidFrom <= @current_rules-validto
        and ValidTo >= @current_rules-validfrom
        and CompanyCode = @current_rules-CompanyCode
        and Ledger = @current_rules-Ledger
        and PAndLID = @current_rules-PAndLID
        and CcAllocation = @current_rules-CcAllocation
        and CcConsolidation = @current_rules-CcConsolidation
        and ProfitCenter = @current_rules-ProfitCenter
        and IsDeleted is initial
        into corresponding fields of table @all_rules.

    append lines of current_rules to all_rules.

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

    data range_all_pandl type range of ZI_IntercoPandLHierFlattenedSH-id.
    select distinct 'I' as sign, 'EQ' as option, id as low, @space as high
        from ZI_IntercoPandLHierFlattenedSH
        with privileged access
        where 1 = 1
            into table @range_all_pandl.

    data range_all_companycodes type range of zr_intercoclassificationrule-companycode.
    select distinct 'I' as sign, 'EQ' as option, providercompanycode as low, @space as high
        from ZI_IntercoCompanyRelProduct
        with privileged access
        where 1 = 1
            into table @range_all_companycodes.

    data range_all_profitcenters type range of  zr_intercoclassificationrule-profitcenter.
    select distinct 'I' as sign, 'EQ' as option, profitcenter as low, @space as high
        from I_ProfitCenter
        with privileged access
            where ControllingArea = 'ML00'
                into table @range_all_profitcenters.

    data range_all_cc_allocations type range of  zr_intercoclassificationrule-ccallocation.
    select distinct 'I' as sign, 'EQ' as option, HierarchyNodeVal as low, @space as high
        from I_CostCenterHierarchyNode
        with privileged access
            where ControllingArea = 'ML00'
              and CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
              and NodeType = 'N'
                into table @range_all_cc_allocations.

    data range_all_cc_consolidations type range of  zr_intercoclassificationrule-CcConsolidation.
    select distinct 'I' as sign, 'EQ' as option, HierarchyNodeVal as low, @space as high
        from I_CostCenterHierarchyNode
        with privileged access
            where ControllingArea = 'ML00'
              and CostCenterHierarchy = 'H101/ML00/CONS_CC'
              and NodeType = 'N'
                into table @range_all_cc_consolidations.

    data range_companycodes like range_all_companycodes.
    data range_profitcenters like range_all_profitcenters.
    data range_cc_allocations like  range_all_cc_allocations.
    data range_cc_consolidations like range_all_cc_consolidations.
    data range_pandl like range_all_pandl.

    loop at current_rules reference into data(rule).

      range_companycodes = range_all_companycodes.
      delete range_companycodes where low <> rule->companycode.

      range_profitcenters = range_all_profitcenters.
      delete range_profitcenters where low <> rule->profitcenter.

      range_cc_allocations = range_all_cc_allocations.
      delete range_cc_allocations where low <> rule->CcAllocation.

      range_cc_consolidations = range_all_cc_consolidations.
      delete range_cc_consolidations where low <> rule->ccconsolidation.

      range_pandl = range_all_pandl.
      delete range_pandl where low <> rule->PAndLID.

*Ini mod - ext_jugesto - DS4K9B4I10 - 09.09.2025
      duplicate_rules = value #( for duplicate_rule in all_rules
                                 where ( CompanyCode = rule->companycode
                                         and Ledger = rule->Ledger
                                         and CcAllocation = rule->CcAllocation
                                         and CcConsolidation = rule->ccconsolidation
                                         and CcStdHierArea = rule->CcStdHierArea
                                         and PAndLID = rule->PAndLID
                                         and ProfitCenter = rule->profitcenter
                                         and IsNotBillable = rule->IsNotBillable
                                         and id <> rule->id )
                               (                           duplicate_rule ) ).
*Fin mod - ext_jugesto - DS4K9B4I10 - 09.09.2025

      data(key) = keys[ %tky = rule->%tky ].

      append value #( %tky        = key-%tky
                      %state_area = 'VALIDATE_DUPLICATED'
      ) to reported-classificationrule.
      if lines( duplicate_rules ) > 0.
        if rule->ExcelLineNumber > 0.
          data(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
        endif.

        append value #( %tky = key-%tky ) to failed-classificationrule.
        append value #( %tky        = rule->%tky
                        %state_area = 'VALIDATE_DUPLICATED'
                        %msg        = zcl_fi_intrc_messages=>new_message(
                        v1       = line_number
                        textid   = zcl_fi_intrc_messages=>duplicated_rule
                        severity = if_abap_behv_message=>severity-error )
        ) to reported-classificationrule.

      endif.

    endloop.

  endmethod.

  method Delete.

    read entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
        all fields with corresponding #( keys )
            result data(current_rules).

    modify entities of zr_intercoclassificationrule in local mode
           entity ClassificationRule
              update fields ( IsDeleted )
                 with value #( for key in keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 IsDeleted = abap_true ) ).

    " Read changed data for action result
    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
         all fields with
         corresponding #( keys )
       result data(rules).

    loop at rules reference into data(rule).
      rule->RuleCriticality = cond #( when rule->IsDeleted = abap_true then '1' else '0' ).
    endloop.

    result = value #( for r in rules ( %tky   = r-%tky
                                       %param = r ) ).

  endmethod.

  method Restore.

    read entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
        all fields with corresponding #( keys )
            result data(current_rules).

    modify entities of zr_intercoclassificationrule in local mode
           entity ClassificationRule
              update fields ( IsDeleted )
                 with value #( for key in keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 IsDeleted = abap_false ) ).

    " Read changed data for action result
    read entities of zr_intercoclassificationrule in local mode
      entity ClassificationRule
         all fields with
         corresponding #( keys )
       result data(rules).

    result = value #( for rule in rules ( %tky   = rule-%tky
                                          %param = rule ) ).


  endmethod.

  method ValidateAllFields.

    read entities of zr_intercoclassificationrule in local mode
        entity ClassificationRule
            all fields with
                corresponding #( keys )
                result data(rules).

    if rules is initial.
      return.
    endif.

    "$. Region get_data - Search for the given values in their corresponding VH tables.
    select distinct companycode from ZI_IntercoCompanyCodeVH
        with privileged access
        for all entries in @rules
        where companycode = @rules-CompanyCode
            into table @data(company_codes).

    select distinct id as PAndLID from ZI_IntercoPandLHierFlattenedSH
        with privileged access
        for all entries in @rules
          where id = @rules-PAndLID
            into table @data(pandl_ids).

    select distinct profitcenter from i_profitcenter
        with privileged access
        for all entries in @rules
            where controllingarea = 'ML00'
              and profitcenter = @rules-ProfitCenter
              and ValidityEndDate >= @rules-validfrom
              and ValidityStartDate <= @rules-ValidTo
                into table @data(profit_centers).

    select distinct Product from ZI_IntercoProduct_SH
        with privileged access
        for all entries in @rules
            where Product = @rules-Product
                into table @data(products).

    types: begin of ty_converted_columns,
             CcStdHierArea   type i_costcenterhierarchynode-hierarchynodeval,
             CcAllocation    type i_costcenterhierarchynode-hierarchynodeval,
             CcConsolidation type i_costcenterhierarchynode-hierarchynodeval,
           end of ty_converted_columns,
           tt_converted_columns type table of ty_converted_columns with default key.

    data(converted_columns) = value tt_converted_columns(
                                        for r in rules ( ccstdhierarea   = r-CcStdHierArea
                                                         ccallocation    = r-CcAllocation
                                                         ccconsolidation = r-CcConsolidation ) ).

    select distinct CostCenterSubArea as CcStdHierArea from ZI_IntercoCostCenterSubArea_SH
      with privileged access
      for all entries in @converted_columns
          where CostCenterSubArea =  @converted_columns-ccstdhierarea
          into table @data(cc_stdhierareas).

    select distinct Allocation as CcAllocation from ZI_IntercoCostCenterAlloc_SH
        with privileged access
        for all entries in @converted_columns
            where Allocation = @converted_columns-CcAllocation
              into table @data(cc_allocations).

    select distinct Consolidation as CcConsolidation from ZI_IntercoCostCenterConsVH
        with privileged access
        for all entries in @converted_columns
            where Consolidation = @converted_columns-CcConsolidation
                into table @data(cc_consolidations).
    "$. EndRegion get_data.


    " Perform Validations
    loop at rules reference into data(rule).

      append value #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_ALL'
      ) to reported-classificationrule.

      if rule->ExcelLineNumber > 0.
        data(line_number) = |({ 'Row'(001) } { rule->ExcelLinenumber })|.
      endif.


      " Company Code
      if rule->companycode is not initial and not line_exists( company_codes[ CompanyCode = rule->CompanyCode ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky                 = rule->%tky
                        %state_area          = 'VALIDATE_ALL'
                        %msg                 = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->companycode
                        v3       = 'Company Code'(002)
                        )
                        %element-companycode = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

      " P&L ID
      if rule->pandlid is not initial and not line_exists( pandl_ids[ pandlid = rule->PAndLID ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky             = rule->%tky
                        %state_area      = 'VALIDATE_ALL'
                        %msg             = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->pandlid
                        v3       = 'P&L ID'(003)
                        )
                        %element-pandlid = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

      " Profit Center
      if rule->profitcenter is not initial and not line_exists( profit_centers[ profitcenter = rule->profitcenter ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky                  = rule->%tky
                        %state_area           = 'VALIDATE_ALL'
                        %msg                  = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->profitcenter
                        v3       = 'Profit Center'(004)
                        )
                        %element-profitcenter = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

      " Product
      if rule->product is not initial and not line_exists( products[ product = rule->product ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky             = rule->%tky
                        %state_area      = 'VALIDATE_ALL'
                        %msg             = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->product
                        v3       = 'Product'(005)
                        )
                        %element-product = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

      " CcStdHierArea
      if rule->CcStdHierArea is not initial and not line_exists( cc_stdhierareas[ ccstdhierarea = rule->CcStdHierArea ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky                   = rule->%tky
                        %state_area            = 'VALIDATE_ALL'
                        %msg                   = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->ccstdhierarea
                        v3       = 'CC. Std. Hierarchy Area'(006)
                        )
                        %element-ccstdhierarea = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

      " CcAllocation
      if rule->CcAllocation is not initial and not line_exists( cc_allocations[ CcAllocation = rule->CcAllocation ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky                  = rule->%tky
                        %state_area           = 'VALIDATE_ALL'
                        %msg                  = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->ccallocation
                        v3       = 'CC. Allocation'(007)
                        )
                        %element-ccallocation = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

      " CcConsolidation
      if rule->ccconsolidation is not initial and not line_exists( cc_consolidations[ ccconsolidation = rule->ccconsolidation ] ).
        failed-classificationrule = value #( ( %tky = rule->%tky ) ).
        append value #( %tky                     = rule->%tky
                        %state_area              = 'VALIDATE_ALL'
                        %msg                     = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>invalid_field_value
                        severity = if_abap_behv_message=>severity-error
                        v1       = line_number
                        v2       = rule->ccconsolidation
                        v3       = 'CC. Consolidation'(008)
                        )
                        %element-ccconsolidation = if_abap_behv=>mk-on
        ) to reported-classificationrule.
      endif.

    endloop.



  endmethod.

endclass.
