CLASS lhc_zi_reingctcontract DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR zi_reingctcontract RESULT result.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR zi_reingctcontract RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR zi_reingctcontract RESULT result.
    METHODS ActivateContract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract~ActivateContract RESULT result.
    METHODS ArchiveContract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract~ArchiveContract RESULT result.
    METHODS InactivateContract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract~InactivateContract RESULT result.
    METHODS ReactivateContract FOR MODIFY
      IMPORTING keys FOR ACTION zi_reingctcontract~ReactivateContract RESULT result.
    METHODS CalcTotalAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctcontract~CalcTotalAmount.
    METHODS SetCtStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctcontract~SetCtStatus.
    METHODS ValidateActivation FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcontract~ValidateActivation.
    METHODS ValidateContractHeader FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcontract~ValidateContractHeader.
ENDCLASS.

CLASS lhc_zi_reingctmaterial DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS ValidateMatnr FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctmaterial~ValidateMatnr.
ENDCLASS.

CLASS lhc_zi_reingctoptype DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS AutoCreateLinkedOpType FOR DETERMINE ON MODIFY
      IMPORTING keys FOR zi_reingctoptype~AutoCreateLinkedOpType.
    METHODS ValidateOpTypeFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctoptype~ValidateOpTypeFields.
ENDCLASS.

CLASS lhc_zi_reingctcron DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS ValidateCronSum FOR VALIDATE ON SAVE
      IMPORTING keys FOR zi_reingctcron~ValidateCronSum.
ENDCLASS.

CLASS lhc_zi_reingctcontract IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #(
      %create = if_abap_behv=>auth-allowed
      %update = if_abap_behv=>auth-allowed
      %delete = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_authorizations.
    result = VALUE #(
      FOR key IN keys
      ( %tky                       = key-%tky
        %update                    = if_abap_behv=>auth-allowed
        %delete                    = if_abap_behv=>auth-allowed
        %action-ActivateContract   = if_abap_behv=>auth-allowed
        %action-InactivateContract = if_abap_behv=>auth-allowed
        %action-ReactivateContract = if_abap_behv=>auth-allowed
        %action-ArchiveContract    = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    result = VALUE #(
      FOR ls IN lt_ct
      LET lv_st = ls-%data-CtStatus IN (
        %tky                       = ls-%tky
        %action-ActivateContract   = COND #( WHEN lv_st = 'BO' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-InactivateContract = COND #( WHEN lv_st = 'AC' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-ReactivateContract = COND #( WHEN lv_st = 'IN' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-ArchiveContract    = COND #( WHEN lv_st = 'IN' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      ) ).
  ENDMETHOD.

  METHOD SetCtStatus.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      CHECK ls_ct-%data-CtStatus IS INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctcontract
          UPDATE FIELDS ( CtStatus )
          WITH VALUE #( ( %tky     = ls_ct-%tky
                          CtStatus = 'BO' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
  ENDMETHOD.

  METHOD CalcTotalAmount.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    DATA lt_ct_ids TYPE SORTED TABLE OF zreing_ct_a-ct_id WITH UNIQUE KEY table_line.
    LOOP AT lt_ct INTO DATA(ls_ct_f).
      CHECK ls_ct_f-%data-CtId IS NOT INITIAL.
      INSERT ls_ct_f-%data-CtId INTO TABLE lt_ct_ids.
    ENDLOOP.
    CHECK lt_ct_ids IS NOT INITIAL.
    DATA lt_mats TYPE TABLE OF zreing_ct_mat_a WITH EMPTY KEY.
    SELECT ct_id, amount FROM zreing_ct_mat_a
      FOR ALL ENTRIES IN @lt_ct_ids
      WHERE ct_id = @lt_ct_ids-table_line
      INTO CORRESPONDING FIELDS OF TABLE @lt_mats.
    DATA lt_totals TYPE HASHED TABLE OF zreing_ct_mat_a WITH UNIQUE KEY ct_id.
    LOOP AT lt_mats INTO DATA(ls_mat).
      READ TABLE lt_totals INTO DATA(ls_tot) WITH TABLE KEY ct_id = ls_mat-ct_id.
      IF sy-subrc = 0.
        ls_tot-amount = ls_tot-amount + ls_mat-amount.
        MODIFY TABLE lt_totals FROM ls_tot.
      ELSE.
        INSERT VALUE zreing_ct_mat_a( ct_id = ls_mat-ct_id amount = ls_mat-amount ) INTO TABLE lt_totals.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_ct INTO DATA(ls_ct).
      CHECK ls_ct-%data-CtId IS NOT INITIAL.
      READ TABLE lt_totals INTO DATA(ls_total) WITH TABLE KEY ct_id = ls_ct-%data-CtId.
      DATA(lv_total) = COND zreing_ct_a-total_amount( WHEN sy-subrc = 0 THEN ls_total-amount ELSE 0 ).
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctcontract
          UPDATE FIELDS ( TotalAmount )
          WITH VALUE #( ( %tky = ls_ct-%tky TotalAmount = lv_total ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateContractHeader.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( Lifnr Bukrs ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-Lifnr IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El proveedor es obligatorio' ) )
          TO reported-Contract.
      ENDIF.
      IF ls_ct-%data-Bukrs IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La sociedad de origen es obligatoria' ) )
          TO reported-Contract.
      ENDIF.
      IF ls_ct-%data-ValidFrom IS NOT INITIAL
         AND ls_ct-%data-ValidTo IS NOT INITIAL
         AND ls_ct-%data-ValidFrom >= ls_ct-%data-ValidTo.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Fecha fin debe ser posterior a fecha inicio (BR-CT-06)' ) )
          TO reported-Contract.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateActivation.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtId CtStatus ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    DATA lt_bo LIKE lt_ct.
    LOOP AT lt_ct INTO DATA(ls_ct_f).
      CHECK ls_ct_f-%data-CtStatus = 'BO'.
      APPEND ls_ct_f TO lt_bo.
    ENDLOOP.
    CHECK lt_bo IS NOT INITIAL.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract BY \_Materials
        ALL FIELDS
        WITH CORRESPONDING #( lt_bo )
      RESULT DATA(lt_all_mats).
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctmaterial BY \_Receivers
        ALL FIELDS
        WITH CORRESPONDING #( lt_all_mats )
      RESULT DATA(lt_all_recs).
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctmaterial BY \_GLLines
        ALL FIELDS
        WITH CORRESPONDING #( lt_all_mats )
      RESULT DATA(lt_all_gls).
    DATA lt_has_mat TYPE SORTED TABLE OF zreing_ct_a-ct_id WITH UNIQUE KEY table_line.
    DATA lt_has_rec TYPE SORTED TABLE OF zreing_ct_a-ct_id WITH UNIQUE KEY table_line.
    DATA lt_has_gl  TYPE SORTED TABLE OF zreing_ct_a-ct_id WITH UNIQUE KEY table_line.
    LOOP AT lt_all_mats INTO DATA(ls_mat).
      TRY. INSERT ls_mat-%data-CtId INTO TABLE lt_has_mat. CATCH cx_sy_itab_duplicate_key. ENDTRY.
    ENDLOOP.
    LOOP AT lt_all_recs INTO DATA(ls_rec).
      TRY. INSERT ls_rec-%data-CtId INTO TABLE lt_has_rec. CATCH cx_sy_itab_duplicate_key. ENDTRY.
    ENDLOOP.
    LOOP AT lt_all_gls INTO DATA(ls_gl).
      TRY. INSERT ls_gl-%data-CtId INTO TABLE lt_has_gl. CATCH cx_sy_itab_duplicate_key. ENDTRY.
    ENDLOOP.
    LOOP AT lt_bo INTO DATA(ls_ct).
      DATA(lv_id) = ls_ct-%data-CtId.
      READ TABLE lt_has_mat WITH TABLE KEY table_line = lv_id TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Debe tener al menos 1 material (BR-CT-05)' ) )
          TO reported-Contract.
      ENDIF.
      IF ls_ct-%data-ValidFrom IS INITIAL OR ls_ct-%data-ValidTo IS INITIAL.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Vigencia incompleta (BR-CT-05)' ) )
          TO reported-Contract.
      ENDIF.
      READ TABLE lt_has_rec WITH TABLE KEY table_line = lv_id TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Debe tener al menos 1 receptora (BR-CT-05)' ) )
          TO reported-Contract.
      ENDIF.
      READ TABLE lt_has_gl WITH TABLE KEY table_line = lv_id TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Debe tener al menos 1 linea GL (BR-CT-05)' ) )
          TO reported-Contract.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD ActivateContract.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-CtStatus <> 'BO'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo Borrador puede activarse' ) )
          TO reported-Contract.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctcontract
          UPDATE FIELDS ( CtStatus )
          WITH VALUE #( ( %tky = ls_ct-%tky CtStatus = 'AC' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD InactivateContract.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-CtStatus <> 'AC'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo Activo puede inactivarse' ) )
          TO reported-Contract.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctcontract
          UPDATE FIELDS ( CtStatus )
          WITH VALUE #( ( %tky = ls_ct-%tky CtStatus = 'IN' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD ReactivateContract.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-CtStatus <> 'IN'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo Inactivo puede reactivarse' ) )
          TO reported-Contract.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctcontract
          UPDATE FIELDS ( CtStatus )
          WITH VALUE #( ( %tky = ls_ct-%tky CtStatus = 'AC' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

  METHOD ArchiveContract.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract
        FIELDS ( CtStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ct).
    LOOP AT lt_ct INTO DATA(ls_ct).
      IF ls_ct-%data-CtStatus <> 'IN'.
        APPEND VALUE #( %tky = ls_ct-%tky ) TO failed-Contract.
        APPEND VALUE #( %tky = ls_ct-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Solo Inactivo puede archivarse' ) )
          TO reported-Contract.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctcontract
          UPDATE FIELDS ( CtStatus )
          WITH VALUE #( ( %tky = ls_ct-%tky CtStatus = 'AR' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcontract ALL FIELDS
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res).
    result = VALUE #( FOR ls IN lt_res ( %tky = ls-%tky %param = CORRESPONDING #( ls-%data ) ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctmaterial IMPLEMENTATION.

  METHOD ValidateMatnr.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctmaterial
        FIELDS ( Matnr )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_mats).
    LOOP AT lt_mats INTO DATA(ls_mat).
      IF ls_mat-%data-Matnr IS INITIAL.
        APPEND VALUE #( %tky = ls_mat-%tky ) TO failed-Material.
        APPEND VALUE #( %tky = ls_mat-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'El código de material es obligatorio' ) )
          TO reported-Material.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctoptype IMPLEMENTATION.

  METHOD AutoCreateLinkedOpType.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctoptype
        FIELDS ( CtId Matnr OpType DeferFrom DeferTo ExchType ExchRate Waers DistType Installments )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opts).
    LOOP AT lt_opts INTO DATA(ls_opt).
      DATA(lv_linked) = SWITCH zreing_ct_opt_a-op_type(
        ls_opt-%data-OpType WHEN 'A' THEN 'D' WHEN 'F' THEN 'NC' ELSE '' ).
      CHECK lv_linked IS NOT INITIAL.
      READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctoptype FIELDS ( OpType )
        WITH VALUE #( ( %key-CtId   = ls_opt-%data-CtId
                        %key-Matnr  = ls_opt-%data-Matnr
                        %key-OpType = lv_linked ) )
        RESULT DATA(lt_exists) FAILED DATA(lt_fail_check).
      CHECK lt_exists IS INITIAL AND lt_fail_check IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingctcontract IN LOCAL MODE
        ENTITY zi_reingctoptype
          UPDATE FIELDS ( DeferFrom DeferTo ExchType ExchRate Waers DistType Installments OpStatus )
          WITH VALUE #( ( %key-CtId    = ls_opt-%data-CtId
                          %key-Matnr   = ls_opt-%data-Matnr
                          %key-OpType  = lv_linked
                          DeferFrom    = ls_opt-%data-DeferFrom
                          DeferTo      = ls_opt-%data-DeferTo
                          ExchType     = ls_opt-%data-ExchType
                          ExchRate     = ls_opt-%data-ExchRate
                          Waers        = ls_opt-%data-Waers
                          DistType     = ls_opt-%data-DistType
                          Installments = ls_opt-%data-Installments
                          OpStatus     = 'AC' ) )
        REPORTED DATA(lt_rep).
    ENDLOOP.
  ENDMETHOD.

  METHOD ValidateOpTypeFields.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctoptype
        FIELDS ( OpType DeferFrom DeferTo DistType Installments ExchType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_opts).
    LOOP AT lt_opts INTO DATA(ls_opt).
      CHECK ls_opt-%data-OpType = 'A'.
      IF ls_opt-%data-DeferFrom IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-OpType.
        APPEND VALUE #( %tky = ls_opt-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Fecha Inicio Devengamiento es obligatoria (BR-CT-12)' ) )
          TO reported-OpType.
      ENDIF.
      IF ls_opt-%data-DeferTo IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-OpType.
        APPEND VALUE #( %tky = ls_opt-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Fecha Fin Devengamiento es obligatoria (BR-CT-12)' ) )
          TO reported-OpType.
      ENDIF.
      IF ls_opt-%data-DistType IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-OpType.
        APPEND VALUE #( %tky = ls_opt-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Tipo de Distribucion es obligatorio (BR-CT-12)' ) )
          TO reported-OpType.
      ENDIF.
      IF ls_opt-%data-DistType = 'L' AND ls_opt-%data-Installments IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-OpType.
        APPEND VALUE #( %tky = ls_opt-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'N. Cuotas es obligatorio para distribucion Lineal (BR-CT-12)' ) )
          TO reported-OpType.
      ENDIF.
      IF ls_opt-%data-ExchType IS INITIAL.
        APPEND VALUE #( %tky = ls_opt-%tky ) TO failed-OpType.
        APPEND VALUE #( %tky = ls_opt-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'Tipo de Cambio es obligatorio (BR-CT-12)' ) )
          TO reported-OpType.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zi_reingctcron IMPLEMENTATION.

  METHOD ValidateCronSum.
    READ ENTITIES OF zi_reingctcontract IN LOCAL MODE
      ENTITY zi_reingctcron
        FIELDS ( CtId Matnr OpType Percentage )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_cron).
    TYPES: BEGIN OF ty_cron_sum,
             ct_id   TYPE zreing_ct_cron_a-ct_id,
             matnr   TYPE zreing_ct_cron_a-matnr,
             op_type TYPE zreing_ct_cron_a-op_type,
             total   TYPE zreing_ct_cron_a-percentage,
           END OF ty_cron_sum.
    DATA lt_sums TYPE HASHED TABLE OF ty_cron_sum WITH UNIQUE KEY ct_id matnr op_type.
    DATA ls_sum  TYPE ty_cron_sum.
    LOOP AT lt_cron INTO DATA(ls_c).
      READ TABLE lt_sums INTO ls_sum
        WITH TABLE KEY ct_id = ls_c-%data-CtId matnr = ls_c-%data-Matnr op_type = ls_c-%data-OpType.
      IF sy-subrc = 0.
        ls_sum-total = ls_sum-total + ls_c-%data-Percentage.
        MODIFY TABLE lt_sums FROM ls_sum.
      ELSE.
        INSERT VALUE ty_cron_sum(
          ct_id   = ls_c-%data-CtId
          matnr   = ls_c-%data-Matnr
          op_type = ls_c-%data-OpType
          total   = ls_c-%data-Percentage ) INTO TABLE lt_sums.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_cron INTO DATA(ls_cron).
      READ TABLE lt_sums INTO ls_sum
        WITH TABLE KEY ct_id = ls_cron-%data-CtId matnr = ls_cron-%data-Matnr op_type = ls_cron-%data-OpType.
      IF sy-subrc = 0 AND ls_sum-total <> 100.
        APPEND VALUE #( %tky = ls_cron-%tky ) TO failed-Cron.
        APPEND VALUE #( %tky = ls_cron-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = 'La suma de porcentajes debe ser exactamente 100% (BR-CT-15)' ) )
          TO reported-Cron.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
