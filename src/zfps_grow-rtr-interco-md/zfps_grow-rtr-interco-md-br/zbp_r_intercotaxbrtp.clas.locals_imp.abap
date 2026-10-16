class lhc_TaxBrazil definition inheriting from cl_abap_behavior_handler.
  private section.

    methods get_instance_features for instance features
      importing keys request requested_features for TaxBrazil result result.

    methods get_global_authorizations for global authorization
      importing request requested_authorizations for TaxBrazil result result.

    methods ValidateRequired for validate on save
      importing keys for TaxBrazil~ValidateRequired.
    methods Delete for modify
      importing keys for action TaxBrazil~Delete result result.

    methods Restore for modify
      importing keys for action TaxBrazil~Restore result result.
    methods ValidateDateOverlap for validate on save
      importing keys for TaxBrazil~ValidateDateOverlap.

    methods ValidateValidTo for validate on save
      importing keys for TaxBrazil~ValidateValidTo.
    methods DefaultForCreate for read
      importing keys for function TaxBrazil~DefaultForCreate result result.

endclass.

class lhc_TaxBrazil implementation.

  method get_instance_features.
    read entities of ZR_IntercoTaxBRTP in local mode
    entity TaxBrazil
        fields ( ValidFrom ValidTo IsDeleted )
            with corresponding #( keys )
            result data(current_rules).


    loop at current_rules reference into data(current_rule).
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
                            %tky            = current_rule->%tky
                            %key            = current_rule->%key
                            %pky            = current_rule->%pky
                            %action-Delete  = can_mark_as_deleted
                            %action-Restore = can_restore
                            %action-Edit    = can_edit
                            %update         = can_edit ) to result.
    endloop.
  endmethod.

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
    result-%action-Edit = can_create.

    if can_create = if_abap_behv=>auth-unauthorized and (
       requested_authorizations-%create = if_abap_behv=>mk-on or
       requested_authorizations-%action-Edit = if_abap_behv=>mk-on ).
      display_error = abap_true.
    endif.

    " Check UPDATE
    result-%action-Delete = can_update.
    result-%action-Edit = can_update.
    result-%update = can_update.

    if can_update =  if_abap_behv=>auth-unauthorized and (
       requested_authorizations-%update = if_abap_behv=>mk-on or
       requested_authorizations-%action-Edit = if_abap_behv=>mk-on or
       requested_authorizations-%action-Delete = if_abap_behv=>mk-on ).
      display_error = abap_true.
    endif.

    if display_error = abap_true.
      append value #( %msg    = zcl_fi_intrc_messages=>new_message(
                      textid   = zcl_fi_intrc_messages=>no_authority
                      severity = if_abap_behv_message=>severity-error )
                      %global = if_abap_behv=>mk-on ) to reported-taxbrazil.
    endif.
  endmethod.


  method ValidateRequired.

    data permission_request type structure for permissions request ZR_IntercoTaxBRTP.

    " Implementation of a generic method for validating mandatory fields,
    " covering both those statically defined in the behavior definition
    " and those dynamically defined via `features: instance` in the `get_instance_features` method.
    data(components) = cast cl_abap_structdescr( cl_abap_structdescr=>describe_by_name( 'ZR_IntercoTaxBRTP' ) )->get_components( ).

    loop at components reference into data(component).
      permission_request-%field-(component->name) = if_abap_behv=>mk-on.
    endloop.

    data instance_permissions type table for instance features result ZR_IntercoTaxBRTP\\TaxBrazil.
    get permissions of ZR_IntercoTaxBRTP
      entity TaxBrazil
      from corresponding #( keys )
    request permission_request
    result data(permissions).

    read entities of ZR_IntercoTaxBRTP in local mode
      entity TaxBrazil
      all fields
      with corresponding #( keys )
      result data(current_rules).

    loop at current_rules reference into data(rule).

      append value #( %tky        = rule->%tky
                      %state_area = 'VALIDATE_REQUIRED'
      ) to reported-TaxBrazil.

      "  Validate mandatory fields
      do lines( components ) times.
        component = ref #( components[ sy-index ] ).
        if ( permissions-global-%field-(component->name) = if_abap_behv=>mk-on or
             permissions-instances[ key entity %key = rule->%key ]-%field-(component->name) = if_abap_behv=>mk-on )
           and rule->(component->name) is initial.

          "  Mark validation failure
          append value #( %tky = rule->%tky ) to failed-TaxBrazil.

          "  Register validation error message
          append initial line to reported-TaxBrazil assigning field-symbol(<reported_entity>).
          <reported_entity> = value #( %tky        = rule->%tky
                                       %state_area = 'VALIDATE_REQUIRED'
                                       %msg        = zcl_fi_intrc_messages=>new_message(
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
      ) to reported-TaxBrazil.

    endloop.

  endmethod.


  method Delete.
    read entities of ZR_IntercoTaxBRTP in local mode
         entity TaxBrazil
         all fields with corresponding #( keys )
             result data(current_taxes).

    modify entities of ZR_IntercoTaxBRTP in local mode
           entity TaxBrazil
              update fields ( IsDeleted )
                 with value #( for key in keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 IsDeleted = abap_true ) ).

    " Read changed data for action result
    read entities of ZR_IntercoTaxBRTP in local mode
      entity TaxBrazil
         all fields with
         corresponding #( keys )
       result data(taxes).

    result = value #( for tax in taxes ( %tky   = tax-%tky
                                         %param = tax ) ).
  endmethod.

  method Restore.
    read entities of ZR_IntercoTaxBRTP in local mode
           entity TaxBrazil
           all fields with corresponding #( keys )
               result data(current_taxes).

    modify entities of ZR_IntercoTaxBRTP in local mode
           entity TaxBrazil
              update fields ( IsDeleted )
                 with value #( for key in keys ( %is_draft = 00
                                                 %tky      = key-%tky
                                                 IsDeleted = abap_false ) ).

    " Read changed data for action result
    read entities of ZR_IntercoTaxBRTP in local mode
      entity TaxBrazil
         all fields with
         corresponding #( keys )
       result data(taxes).

    result = value #( for tax in taxes ( %tky   = tax-%tky
                                         %param = tax ) ).
  endmethod.

  method ValidateDateOverlap.
    return.
    read entities of zr_intercotaxbrtp in local mode
           entity TaxBrazil
            all fields with corresponding #( keys )
         result data(current_taxes).

    if current_taxes is not initial.
      select ProviderCompanyCode, RecipientCompanyCode, Product, ValidFrom, ValidTo
      from zr_intercotaxbrtp
      with privileged access
      for all entries in @current_taxes
      where ProviderCompanyCode = @current_taxes-ProviderCompanyCode
        and RecipientCompanyCode = @current_taxes-RecipientCompanyCode
        and Product = @current_taxes-Product
        and IsDeleted = @abap_false
          into table @data(db_taxes).
    endif.

    data(combined_taxes) = db_taxes.
    loop at current_taxes into data(current_tax).
      modify combined_taxes from corresponding #( current_tax )
        transporting ValidTo
            where ProviderCompanyCode = current_tax-ProviderCompanyCode
              and RecipientCompanyCode = current_tax-RecipientCompanyCode
              and Product = current_tax-Product
              and ValidFrom = current_tax-ValidFrom.
    endloop.

    loop at current_taxes into current_tax.
      append value #( %tky        = current_tax-%tky
                      %state_area = 'VALIDATE_DATE_OVERLAP'
      ) to reported-taxbrazil.

      data invalid_rules like combined_taxes.
      invalid_rules = value #( for existing_exemption in combined_taxes
                               where ( providercompanycode  = current_tax-providercompanycode and
                                       recipientcompanycode = current_tax-recipientcompanycode and
                                       product              = current_tax-product and
                                       validfrom            = current_tax-validfrom and
                               validto >= current_tax-validfrom and
                               validfrom <= current_tax-validto )
                               (                            existing_exemption ) ).

      if invalid_rules is not initial.
        failed-taxbrazil = value #( for failed_exemption in invalid_rules ( %tky = current_tax-%tky ) ).
        append value #( %tky               = current_tax-%tky
                        %state_area        = 'VALIDATE_DATE_OVERLAP'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>date_overlaps
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
                        %element-validto   = if_abap_behv=>mk-on
        ) to reported-taxbrazil.

      endif.
    endloop.
  endmethod.

  method ValidateValidTo.
    read entities of zr_intercotaxbrtp in local mode
       entity TaxBrazil
        all fields with corresponding #( keys )
     result data(current_taxes).

    loop at current_taxes reference into data(tax).

      data(key) = keys[ %tky = tax->%tky ].

      append value #( %tky        = key-%tky
                      %state_area = 'VALIDATE_DATE_INTERVAL'
      ) to reported-taxbrazil.

      if tax->validfrom > tax->validto.
        append value #( %tky = key-%tky ) to failed-taxbrazil.
        append value #( %tky               = key-%tky
                        %state_area        = 'VALIDATE_DATE_INTERVAL'
                        %msg               = zcl_fi_intrc_messages=>new_message(
                        textid   = zcl_fi_intrc_messages=>date_interval
                        severity = if_abap_behv_message=>severity-error )
                        %element-validfrom = if_abap_behv=>mk-on
        ) to reported-taxbrazil.
      endif.

    endloop.

  endmethod.

  method DefaultForCreate.
    data(today) = cl_abap_context_info=>get_system_date( ).
    result = value #( for key in keys (
                      %cid                   = key-%cid
                      %param-%is_draft       = if_abap_Behv=>mk-on
                      %param-%data-ValidFrom = |{ today(6) }01|
                      %param-%data-ValidTo   = |99991231| ) ).
  endmethod.

endclass.

class lsc_ZR_INTERCOTAXBRTP definition inheriting from cl_abap_behavior_saver.
  protected section.

    methods save_modified redefinition.

    methods cleanup_finalize redefinition.

endclass.

class lsc_ZR_INTERCOTAXBRTP implementation.

  method save_modified.
    if create-taxbrazil is initial and
     update-taxbrazil is initial and
     delete-taxbrazil is initial.
      return.
    endif.

*    zcl_interco=>log->save(
*      iv_tablename = 'ZINT_A_MD_TAXBR'
*      it_creates   = create-taxbrazil
*      it_updates   = update-taxbrazil
*      it_deletes   = delete-taxbrazil
*    ).
  endmethod.

  method cleanup_finalize.
  endmethod.

endclass.
