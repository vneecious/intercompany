CLASS zcl_reing_ca_trans_backfill DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
  PRIVATE SECTION.
    " V001 (CC) - CA-09 (EBA): maintenance-window MUR migration only.
    CONSTANTS gc_schema TYPE c LENGTH 16 VALUE 'CA09_L56_V001'.
    CONSTANTS gc_max TYPE i VALUE 5000.
    CONSTANTS gc_read_max TYPE i VALUE 5001.
    TYPES ty_hash TYPE x LENGTH 32.
    TYPES ty_mode TYPE c LENGTH 7.
    TYPES ty_decision TYPE c LENGTH 8.
    TYPES ty_selname TYPE c LENGTH 8.
    TYPES: BEGIN OF ty_input,
             mode TYPE ty_mode,
             run_id TYPE zreing_calc_run_id,
             batch_id TYPE sysuuid_x16,
             plan TYPE ty_hash,
             pause TYPE abap_bool,
           END OF ty_input.
    TYPES ty_lines TYPE SORTED TABLE OF zreing_ca_line_a
      WITH UNIQUE KEY calc_run_id line_num.
    TYPES ty_items TYPE SORTED TABLE OF zreing_ca_bf_i_a
      WITH UNIQUE KEY batch_id run_id line_num.
    TYPES: BEGIN OF ty_target,
             currency TYPE zreing_trans_waers,
             amount TYPE zreing_ca_net_trans_amt,
             rate TYPE zreing_ca_exch_rate_1,
             rate_type TYPE zreing_ca_exr1_type,
           END OF ty_target.
    TYPES: BEGIN OF ty_plan_row,
             run_id TYPE zreing_calc_run_id,
             line_num TYPE zreing_line_num,
             decision TYPE ty_decision,
             current_hash TYPE ty_hash,
             target TYPE ty_target,
           END OF ty_plan_row.
    TYPES ty_plan_rows TYPE STANDARD TABLE OF ty_plan_row WITH EMPTY KEY.
    TYPES: BEGIN OF ty_change,
             before TYPE zreing_ca_line_a,
             after TYPE zreing_ca_line_a,
           END OF ty_change.
    TYPES ty_changes TYPE STANDARD TABLE OF ty_change WITH EMPTY KEY.
    TYPES: BEGIN OF ty_counts,
             candidates TYPE i,
             matched TYPE i,
             excluded TYPE i,
             conflicts TYPE i,
             other_provider TYPE i,
           END OF ty_counts.
    TYPES: BEGIN OF ty_set,
             mandt TYPE abap_bool,
             calc_run_id TYPE abap_bool,
             line_num TYPE abap_bool,
             ct_uuid TYPE abap_bool,
             ct_id TYPE abap_bool,
             lifnr TYPE abap_bool,
             bp_name TYPE abap_bool,
             bukrs_prest TYPE abap_bool,
             mat_uuid TYPE abap_bool,
             matnr TYPE abap_bool,
             op_type TYPE abap_bool,
             op_uuid TYPE abap_bool,
             cm_h_id TYPE abap_bool,
             cm_load_seq TYPE abap_bool,
             op_instance_num TYPE abap_bool,
             parent_op_type TYPE abap_bool,
             origin_run_id TYPE abap_bool,
             origin_line_num TYPE abap_bool,
             parent_net_amt TYPE abap_bool,
             parent_currency TYPE abap_bool,
             defer_pct TYPE abap_bool,
             defer_cuota_num TYPE abap_bool,
             defer_cuota_total TYPE abap_bool,
             defer_from TYPE abap_bool,
             defer_to TYPE abap_bool,
             bukrs_recv TYPE abap_bool,
             country TYPE abap_bool,
             base_amt TYPE abap_bool,
             share_pct TYPE abap_bool,
             share_pais_pct TYPE abap_bool,
             share_comb_pct TYPE abap_bool,
             calc_amt TYPE abap_bool,
             bruto_amt TYPE abap_bool,
             gross_up_amt TYPE abap_bool,
             tax_amt TYPE abap_bool,
             net_amt TYPE abap_bool,
             ct_currency TYPE abap_bool,
             net_local_amt TYPE abap_bool,
             local_currency TYPE abap_bool,
             exch_rate TYPE abap_bool,
             exch_rate_type TYPE abap_bool,
             trans_currency TYPE abap_bool,
             net_trans_amt TYPE abap_bool,
             exch_rate_1 TYPE abap_bool,
             exch_rate_1_type TYPE abap_bool,
             is_delta TYPE abap_bool,
             delta_seq TYPE abap_bool,
             delta_base_amt TYPE abap_bool,
             line_status TYPE abap_bool,
             sim_message TYPE abap_bool,
             proc_started_at TYPE abap_bool,
             proc_heartbeat_at TYPE abap_bool,
             proc_job_id TYPE abap_bool,
             insumo_check_at TYPE abap_bool,
             fi_awkey TYPE abap_bool,
             local_last_changed_at TYPE abap_bool,
           END OF ty_set.
    TYPES BEGIN OF ty_update.
    INCLUDE TYPE zreing_ca_line_a.
    TYPES set_fields TYPE ty_set.
    TYPES END OF ty_update.
    TYPES ty_updates TYPE STANDARD TABLE OF ty_update WITH EMPTY KEY.
    DATA ms_input TYPE ty_input.
    DATA ms_run TYPE zreing_ca_run_a.
    DATA ms_header TYPE zreing_ca_bf_h_a.
    DATA mt_items TYPE ty_items.
    DATA mt_lines TYPE ty_lines.
    DATA mt_changes TYPE ty_changes.
    DATA mt_plan_rows TYPE ty_plan_rows.
    DATA ms_counts TYPE ty_counts.
    DATA mv_plan TYPE ty_hash.
    DATA mv_proc_count TYPE i.
    DATA mv_job_key TYPE c LENGTH 64.
    DATA mv_time TYPE timestampl.
    DATA mv_locked_run TYPE zreing_calc_run_id.
    DATA mo_lock TYPE REF TO if_abap_lock_object.
    DATA mt_log TYPE string_table.
    DATA mv_committed TYPE abap_bool.
    DATA mv_context_owned TYPE abap_bool.
    DATA mv_isolated_test TYPE abap_bool.
    METHODS fail IMPORTING iv_text TYPE string RAISING cx_apj_rt_content.
    METHODS parse IMPORTING it_parameters TYPE if_apj_rt_exec_object=>tt_templ_val
      RAISING cx_apj_rt_content.
    METHODS validate_input RAISING cx_apj_rt_content.
    METHODS check_context RAISING cx_apj_rt_content.
    METHODS lock_run RAISING cx_apj_rt_content.
    METHODS release_run RETURNING VALUE(rv_error) TYPE string.
    METHODS load_snapshot RAISING cx_apj_rt_content.
    METHODS load_batch RAISING cx_apj_rt_content.
    METHODS classify IMPORTING is_line TYPE zreing_ca_line_a
      RETURNING VALUE(rv_decision) TYPE ty_decision.
    METHODS desired IMPORTING is_line TYPE zreing_ca_line_a
      RETURNING VALUE(rs_target) TYPE ty_target.
    METHODS fingerprint IMPORTING is_line TYPE zreing_ca_line_a
      RETURNING VALUE(rv_hash) TYPE ty_hash RAISING cx_apj_rt_content.
    METHODS digest IMPORTING iv_bytes TYPE xstring
      RETURNING VALUE(rv_hash) TYPE ty_hash RAISING cx_apj_rt_content.
    METHODS build_apply RAISING cx_apj_rt_content.
    METHODS report_matched_batches RAISING cx_apj_rt_content.
    METHODS build_reverse RAISING cx_apj_rt_content.
    METHODS calculate_plan RAISING cx_apj_rt_content.
    METHODS batch_noop RETURNING VALUE(rv_noop) TYPE abap_bool
      RAISING cx_apj_rt_content.
    METHODS stamp_changes RAISING cx_apj_rt_content.
    METHODS make_apply_items RAISING cx_apj_rt_content.
    METHODS update_lines RAISING cx_apj_rt_content.
    METHODS verify_lines RAISING cx_apj_rt_content.
    METHODS persist_journal RAISING cx_apj_rt_content.
    METHODS save_log IMPORTING iv_error TYPE abap_bool DEFAULT abap_false
      RAISING cx_apj_rt_content.
    METHODS execute_job RAISING cx_apj_rt_content.
ENDCLASS.

CLASS zcl_reing_ca_trans_backfill IMPLEMENTATION.
  METHOD if_apj_dt_exec_object~get_parameters.
    et_parameter_def = VALUE #(
      ( selname = 'P_MODE' kind = if_apj_dt_exec_object=>parameter datatype = 'CHAR'
        length = 7 param_text = 'SIM / APPLY / R_SIM / REVERSE' changeable_ind = abap_true )
      ( selname = 'P_RUNID' kind = if_apj_dt_exec_object=>parameter datatype = 'CHAR'
        length = 20 param_text = 'Identificador físico de ejecución' mandatory_ind = abap_true changeable_ind = abap_true )
      ( selname = 'P_BATCH' kind = if_apj_dt_exec_object=>parameter datatype = 'CHAR'
        length = 32 param_text = 'UUID del lote del operador (32 hex)' changeable_ind = abap_true )
      ( selname = 'P_PLAN' kind = if_apj_dt_exec_object=>parameter datatype = 'CHAR'
        length = 64 param_text = 'SHA-256 de simulación aprobada' changeable_ind = abap_true )
      ( selname = 'P_PAUSE' kind = if_apj_dt_exec_object=>parameter datatype = 'CHAR'
        length = 1 param_text = 'Procesos de escritura detenidos' checkbox_ind = abap_true changeable_ind = abap_true ) ).
    et_parameter_val = VALUE #( ( selname = 'P_MODE' kind = 'P' sign = 'I' option = 'EQ' low = 'SIM' ) ).
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    CLEAR: ms_input, ms_run, ms_header, mt_items, mt_lines, mt_changes,
      mt_plan_rows, ms_counts, mv_plan, mv_proc_count, mv_job_key, mv_time, mt_log, mv_committed, mv_context_owned.
    IF mv_locked_run IS NOT INITIAL.
      fail( 'This instance still owns a RUN lock; resolve it before retrying' ).
    ENDIF.
    TRY.
        parse( it_parameters ).
        execute_job( ).
      CATCH cx_root INTO DATA(lx_error).
        IF mv_context_owned = abap_true AND mv_committed = abap_false.
          TEST-SEAM ca09_rollback.
            IF mv_isolated_test = abap_false.
              ROLLBACK WORK.
            ENDIF.
          END-TEST-SEAM.
        ENDIF.
        APPEND |Failure: { lx_error->get_text( ) }; data committed={ mv_committed }| TO mt_log.
        DATA(lv_unlock) = release_run( ).
        IF lv_unlock IS NOT INITIAL.
          APPEND |Owned RUN lock cleanup failed: { lv_unlock }| TO mt_log.
        ENDIF.
        IF mv_context_owned = abap_true.
          TRY.
              save_log( iv_error = abap_true ).
            CATCH cx_root.
              " Diagnostic log failure must not hide the original error.
          ENDTRY.
        ENDIF.
        RAISE EXCEPTION TYPE cx_apj_rt_content EXPORTING previous = lx_error.
    ENDTRY.
  ENDMETHOD.

  METHOD fail.
    APPEND iv_text TO mt_log.
    RAISE EXCEPTION TYPE cx_apj_rt_content.
  ENDMETHOD.

  METHOD parse.
    DATA lt_seen TYPE SORTED TABLE OF ty_selname WITH UNIQUE KEY table_line.
    ms_input-mode = 'SIM'.
    LOOP AT it_parameters INTO DATA(ls_param).
      IF ls_param-kind <> 'P' OR ls_param-sign <> 'I' OR ls_param-option <> 'EQ'
          OR ls_param-high IS NOT INITIAL.
        fail( |Only exact scalar parameters are accepted: { ls_param-selname }| ).
      ENDIF.
      INSERT ls_param-selname INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        fail( |Duplicate parameter: { ls_param-selname }| ).
      ENDIF.
      DATA(lv_value) = CONV string( ls_param-low ).
      CASE ls_param-selname.
        WHEN 'P_MODE'.
          IF strlen( lv_value ) > 7.
            fail( 'P_MODE is too long' ).
          ENDIF.
          ms_input-mode = lv_value.
        WHEN 'P_RUNID'.
          IF strlen( lv_value ) > 20.
            fail( 'P_RUNID is too long' ).
          ENDIF.
          ms_input-run_id = lv_value.
        WHEN 'P_BATCH'.
          IF lv_value IS NOT INITIAL.
            IF strlen( lv_value ) <> 32 OR lv_value CN '0123456789ABCDEF'.
              fail( 'P_BATCH requires exactly 32 uppercase hexadecimal characters' ).
            ENDIF.
            ms_input-batch_id = lv_value.
            IF ms_input-batch_id IS INITIAL.
              fail( 'P_BATCH must not be a zero UUID' ).
            ENDIF.
          ENDIF.
        WHEN 'P_PLAN'.
          IF lv_value IS NOT INITIAL.
            IF strlen( lv_value ) <> 64 OR lv_value CN '0123456789ABCDEF'.
              fail( 'P_PLAN requires exactly 64 uppercase hexadecimal characters' ).
            ENDIF.
            ms_input-plan = lv_value.
            IF ms_input-plan IS INITIAL.
              fail( 'P_PLAN must not be an all-zero digest' ).
            ENDIF.
          ENDIF.
        WHEN 'P_PAUSE'.
          IF lv_value <> '' AND lv_value <> 'X'.
            fail( 'P_PAUSE accepts only blank or X' ).
          ENDIF.
          ms_input-pause = lv_value.
        WHEN OTHERS.
          fail( |Unknown parameter: { ls_param-selname }| ).
      ENDCASE.
    ENDLOOP.
    validate_input( ).
  ENDMETHOD.

  METHOD validate_input.
    IF ms_input-mode <> 'SIM' AND ms_input-mode <> 'APPLY'
        AND ms_input-mode <> 'R_SIM' AND ms_input-mode <> 'REVERSE'.
      fail( 'Unsupported mode' ).
    ENDIF.
    IF ms_input-run_id IS INITIAL OR ms_input-run_id CA '*+%'.
      fail( 'An exact, noninitial physical RUN is required' ).
    ENDIF.
    IF ms_input-mode <> 'SIM' AND ms_input-batch_id IS INITIAL.
      fail( 'This mode requires a nonzero batch UUID' ).
    ENDIF.
    IF ms_input-mode = 'APPLY' OR ms_input-mode = 'REVERSE'.
      IF ms_input-pause <> abap_true OR ms_input-plan IS INITIAL.
        fail( 'Write modes require an approved SHA-256 preview and acknowledgement of stopped writers' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD check_context.
    TEST-SEAM ca09_context.
      IF mv_isolated_test = abap_true.
        fail( 'Isolated tests must replace the APJ context seam' ).
      ENDIF.
      TRY.
          cl_apj_rt_api=>get_job_runtime_info(
            IMPORTING ev_catalog_name = DATA(lv_catalog) ev_template_name = DATA(lv_template)
              ev_jobname = DATA(lv_job) ev_jobcount = DATA(lv_count) ev_stepcount = DATA(lv_step) ).
          IF lv_catalog <> 'ZREING_CA_BF_C' OR lv_template <> 'ZREING_CA_BF_T'
              OR lv_job IS INITIAL OR lv_count IS INITIAL OR lv_step <= 0.
            fail( 'Solo se admite el catálogo y la plantilla del job de migración MUR' ).
          ENDIF.
          mv_job_key = |{ lv_job }/{ lv_count }/{ lv_step }|.
        CATCH cx_apj_rt INTO DATA(lx_apj).
          fail( |Cannot establish administrative APJ context: { lx_apj->get_text( ) }| ).
      ENDTRY.
    END-TEST-SEAM.
    " Ownership is established only after the dedicated APJ context has been verified.
    mv_context_owned = abap_true.
    IF ms_input-mode = 'APPLY' OR ms_input-mode = 'REVERSE'.
      DATA(lv_off) = zif_reing_ca_c=>br_isolation-eba_off.
      TEST-SEAM ca09_switch.
        " Test injection may change only this local switch value.
      END-TEST-SEAM.
      IF lv_off <> abap_true.
        fail( 'Los modos de escritura requieren EBA desactivado' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD lock_run.
    TRY.
        TEST-SEAM ca09_lock.
          IF mv_isolated_test = abap_true.
            fail( 'Isolated tests must replace the RUN lock seam' ).
          ENDIF.
          mo_lock = cl_abap_lock_object_factory=>get_instance( 'EZREINGCARUN' ).
          mo_lock->enqueue(
            it_table_mode = VALUE #( ( table_name = 'ZREING_CA_RUN_A'
              mode = if_abap_lock_object=>cs_mode-exclusive_lock ) )
            it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( ms_input-run_id ) ) )
            _scope = if_abap_lock_object=>cs_scope-no_update_program _wait = if_abap_lock_object=>cs_wait-no ).
        END-TEST-SEAM.
        mv_locked_run = ms_input-run_id.
      CATCH cx_root INTO DATA(lx_lock).
        fail( |RUN lock not acquired: { lx_lock->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD release_run.
    CHECK mv_locked_run IS NOT INITIAL.
    TRY.
        TEST-SEAM ca09_unlock.
          IF mv_isolated_test = abap_true.
            fail( 'Isolated tests must replace the RUN unlock seam' ).
          ENDIF.
          mo_lock->dequeue(
            it_table_mode = VALUE #( ( table_name = 'ZREING_CA_RUN_A'
              mode = if_abap_lock_object=>cs_mode-exclusive_lock ) )
            it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( mv_locked_run ) ) )
            _scope = if_abap_lock_object=>cs_scope-no_update_program _synchronous = if_abap_lock_object=>cs_synchronous-yes ).
        END-TEST-SEAM.
        CLEAR: mv_locked_run, mo_lock.
      CATCH cx_root INTO DATA(lx_unlock).
        rv_error = lx_unlock->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD load_snapshot.
    SELECT SINGLE FROM zreing_ca_run_a FIELDS mandt, calc_run_id, fiscal_period, fiscal_year, total_lines,
      total_groups, created_by, created_at, local_last_changed_at
      WHERE calc_run_id = @ms_input-run_id INTO @ms_run.
    IF sy-subrc <> 0.
      fail( 'Physical RUN header does not exist' ).
    ENDIF.
    SELECT FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
      lifnr, bp_name, bukrs_prest, mat_uuid, matnr,
      op_type, op_uuid, cm_h_id, cm_load_seq, op_instance_num,
      parent_op_type, origin_run_id, origin_line_num, parent_net_amt, parent_currency,
      defer_pct, defer_cuota_num, defer_cuota_total, defer_from, defer_to,
      bukrs_recv, country, base_amt, share_pct, share_pais_pct,
      share_comb_pct, calc_amt, bruto_amt, gross_up_amt, tax_amt,
      net_amt, ct_currency, net_local_amt, local_currency, exch_rate,
      exch_rate_type, trans_currency, net_trans_amt, exch_rate_1, exch_rate_1_type,
      is_delta, delta_seq, delta_base_amt, line_status, sim_message,
      proc_started_at, proc_heartbeat_at, proc_job_id, insumo_check_at, fi_awkey,
      local_last_changed_at
      WHERE calc_run_id = @ms_input-run_id AND bukrs_prest = 'MUR'
      ORDER BY PRIMARY KEY INTO TABLE @mt_lines UP TO @gc_read_max ROWS.
    IF lines( mt_lines ) > gc_max.
      fail( 'RUN exceeds 5000 MUR rows; chunking is not supported' ).
    ENDIF.
    SELECT FROM zreing_ca_line_a FIELDS COUNT( * )
      WHERE calc_run_id = @ms_input-run_id AND bukrs_prest <> 'MUR'
      INTO @ms_counts-other_provider.
    SELECT FROM zreing_ca_line_a FIELDS COUNT( * )
      WHERE calc_run_id = @ms_input-run_id
        AND ( line_status = 'CALC_PROC' OR line_status = 'SIM_PROC'
          OR line_status = 'POST_PROC' OR line_status = 'ANUL_PROC' )
      INTO @mv_proc_count.
    IF mv_proc_count > 0 AND ( ms_input-mode = 'APPLY' OR ms_input-mode = 'REVERSE' ).
      fail( 'A processing line exists in this RUN; write rejected, including non-MUR lines' ).
    ENDIF.
    load_batch( ).
  ENDMETHOD.

  METHOD load_batch.
    CLEAR: ms_header, mt_items.
    CHECK ms_input-batch_id IS NOT INITIAL.
    SELECT SINGLE FROM zreing_ca_bf_h_a FIELDS mandt, batch_id, run_id, schema_id, state,
      plan_hash, row_count, applied_by, applied_at, reversed_by,
      reversed_at, job_key
      WHERE batch_id = @ms_input-batch_id INTO @ms_header.
    IF ms_header-batch_id IS INITIAL.
      SELECT FROM zreing_ca_bf_i_a FIELDS COUNT( * )
        WHERE batch_id = @ms_input-batch_id INTO @DATA(lv_orphan_count).
      IF lv_orphan_count <> 0.
        fail( 'Journal rows exist without their batch header; reject orphaned batch' ).
      ENDIF.
      IF ms_input-mode = 'R_SIM' OR ms_input-mode = 'REVERSE'.
        fail( 'Requested reversal batch does not exist' ).
      ENDIF.
      RETURN.
    ENDIF.
    IF ms_header-run_id <> ms_input-run_id OR ms_header-schema_id <> gc_schema
        OR ( ms_header-state <> 'A' AND ms_header-state <> 'R' )
        OR ms_header-row_count < 1 OR ms_header-row_count > gc_max.
      fail( 'Journal header RUN/schema/state/cardinality is invalid' ).
    ENDIF.
    SELECT FROM zreing_ca_bf_i_a FIELDS mandt, batch_id, run_id, line_num, before_trans_currency,
      before_net_trans_amt, before_exch_rate_1, before_exch_rate_1_type, before_changed_at, after_trans_currency,
      after_net_trans_amt, after_exch_rate_1, after_exch_rate_1_type, after_changed_at, before_hash,
      after_hash, reverse_hash, reversed_at WHERE batch_id = @ms_input-batch_id
      ORDER BY PRIMARY KEY INTO TABLE @mt_items UP TO @gc_read_max ROWS.
    IF lines( mt_items ) <> ms_header-row_count.
      fail( 'Journal row count does not match its header' ).
    ENDIF.
    LOOP AT mt_items INTO DATA(ls_item).
      IF ls_item-run_id <> ms_input-run_id OR ls_item-mandt <> ms_header-mandt.
        fail( 'Journal row belongs to a different RUN/client' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD desired.
    rs_target = VALUE #( currency = is_line-ct_currency amount = is_line-net_amt rate = '1.00000' ).
  ENDMETHOD.

  METHOD classify.
    IF is_line-bukrs_prest <> 'MUR'
        OR ( is_line-line_status <> 'CALC' AND is_line-line_status <> 'LIBD'
          AND is_line-line_status <> 'CONT' AND is_line-line_status <> 'ANULD' ).
      rv_decision = 'EXCLUDED'.
    ELSEIF is_line-ct_currency IS INITIAL.
      rv_decision = 'CONFLICT'.
    ELSEIF is_line-trans_currency IS INITIAL AND is_line-net_trans_amt = 0
        AND is_line-exch_rate_1 = 0 AND is_line-exch_rate_1_type IS INITIAL.
      rv_decision = 'CAND'.
    ELSEIF is_line-trans_currency = is_line-ct_currency AND is_line-net_trans_amt = is_line-net_amt
        AND is_line-exch_rate_1 = '1.00000' AND is_line-exch_rate_1_type IS INITIAL.
      rv_decision = 'MATCHED'.
    ELSE.
      rv_decision = 'CONFLICT'.
    ENDIF.
  ENDMETHOD.

  METHOD digest.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_raw(
          EXPORTING if_algorithm = 'SHA-256' if_data = iv_bytes IMPORTING ef_hashxstring = DATA(lv_hash) ).
        IF xstrlen( lv_hash ) <> 32.
          fail( 'SHA-256 digest length is invalid' ).
        ENDIF.
        rv_hash = lv_hash.
      CATCH cx_abap_message_digest INTO DATA(lx_digest).
        fail( |Cannot calculate SHA-256: { lx_digest->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD fingerprint.
    DATA lv_xml TYPE xstring.
    CALL TRANSFORMATION id SOURCE line = is_line RESULT XML lv_xml.
    rv_hash = digest( lv_xml ).
  ENDMETHOD.

  METHOD build_apply.
    CLEAR: mt_changes, mt_plan_rows, ms_counts-candidates, ms_counts-matched,
      ms_counts-excluded, ms_counts-conflicts.
    LOOP AT mt_lines INTO DATA(ls_line).
      DATA(lv_decision) = classify( ls_line ).
      DATA(ls_target) = desired( ls_line ).
      APPEND VALUE #( run_id = ls_line-calc_run_id line_num = ls_line-line_num
        decision = lv_decision current_hash = fingerprint( ls_line ) target = ls_target ) TO mt_plan_rows.
      CASE lv_decision.
        WHEN 'CAND'.
          DATA(ls_after) = ls_line.
          ls_after-trans_currency = ls_target-currency.
          ls_after-net_trans_amt = ls_target-amount.
          ls_after-exch_rate_1 = ls_target-rate.
          ls_after-exch_rate_1_type = ls_target-rate_type.
          APPEND VALUE #( before = ls_line after = ls_after ) TO mt_changes.
          ms_counts-candidates += 1.
        WHEN 'MATCHED'.
          ms_counts-matched += 1.
        WHEN 'EXCLUDED'.
          ms_counts-excluded += 1.
        WHEN OTHERS.
          ms_counts-conflicts += 1.
          APPEND |CONFLICT RUN={ ls_line-calc_run_id } LINE={ ls_line-line_num }| TO mt_log.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_reverse.
    CLEAR: mt_changes, mt_plan_rows.
    IF ms_header-state <> 'A' OR lines( mt_items ) <> ms_header-row_count
        OR ms_header-row_count < 1 OR ms_header-row_count > gc_max OR ms_header-schema_id <> gc_schema
        OR ms_header-run_id <> ms_input-run_id OR ms_header-batch_id <> ms_input-batch_id.
      fail( 'Reversal requires an intact applied batch header' ).
    ENDIF.
    LOOP AT mt_items INTO DATA(ls_item).
      READ TABLE mt_lines INTO DATA(ls_current) WITH TABLE KEY calc_run_id = ls_item-run_id line_num = ls_item-line_num.
      IF sy-subrc <> 0 OR ls_item-run_id <> ms_input-run_id OR ls_item-mandt <> ms_header-mandt
          OR ls_item-batch_id <> ms_header-batch_id.
        fail( |Reversal journal/LINE identity mismatch: LINE={ ls_item-line_num }| ).
      ENDIF.
      IF fingerprint( ls_current ) <> ls_item-after_hash
          OR ls_current-trans_currency <> ls_item-after_trans_currency
          OR ls_current-net_trans_amt <> ls_item-after_net_trans_amt
          OR ls_current-exch_rate_1 <> ls_item-after_exch_rate_1
          OR ls_current-exch_rate_1_type <> ls_item-after_exch_rate_1_type
          OR ls_current-local_last_changed_at <> ls_item-after_changed_at.
        fail( |After image changed or journal inconsistent: LINE={ ls_item-line_num }| ).
      ENDIF.
      DATA(ls_before) = ls_current.
      ls_before-trans_currency = ls_item-before_trans_currency.
      ls_before-net_trans_amt = ls_item-before_net_trans_amt.
      ls_before-exch_rate_1 = ls_item-before_exch_rate_1.
      ls_before-exch_rate_1_type = ls_item-before_exch_rate_1_type.
      ls_before-local_last_changed_at = ls_item-before_changed_at.
      IF fingerprint( ls_before ) <> ls_item-before_hash OR classify( ls_before ) <> 'CAND'
          OR ls_item-after_changed_at <= ls_item-before_changed_at.
        fail( |Before image invalid: LINE={ ls_item-line_num }| ).
      ENDIF.
      DATA(ls_expected_target) = desired( ls_before ).
      IF ls_current-trans_currency <> ls_expected_target-currency
          OR ls_current-net_trans_amt <> ls_expected_target-amount
          OR ls_current-exch_rate_1 <> ls_expected_target-rate
          OR ls_current-exch_rate_1_type <> ls_expected_target-rate_type.
        fail( |Journal AFTER violates the original MUR copy rule: LINE={ ls_item-line_num }| ).
      ENDIF.
      APPEND VALUE #( before = ls_current after = ls_before ) TO mt_changes.
      APPEND VALUE #( run_id = ls_current-calc_run_id line_num = ls_current-line_num decision = 'REVERSE'
        current_hash = fingerprint( ls_current ) target = VALUE #( currency = ls_before-trans_currency
          amount = ls_before-net_trans_amt rate = ls_before-exch_rate_1 rate_type = ls_before-exch_rate_1_type ) ) TO mt_plan_rows.
    ENDLOOP.
    ms_counts-candidates = lines( mt_changes ).
  ENDMETHOD.

  METHOD report_matched_batches.
    CHECK ms_counts-matched > 0.
    TYPES ty_line_range TYPE RANGE OF zreing_line_num.
    DATA lt_keys TYPE ty_line_range.
    LOOP AT mt_plan_rows INTO DATA(ls_plan) WHERE decision = 'MATCHED'.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_plan-line_num ) TO lt_keys.
    ENDLOOP.
    SELECT FROM zreing_ca_bf_i_a AS item
      INNER JOIN zreing_ca_bf_h_a AS header ON header~batch_id = item~batch_id
      FIELDS item~batch_id, item~line_num
      WHERE header~run_id = @ms_input-run_id AND header~state = 'A'
        AND item~run_id = @ms_input-run_id AND item~line_num IN @lt_keys
      ORDER BY item~line_num, item~batch_id INTO TABLE @DATA(lt_batches) UP TO @gc_read_max ROWS.
    IF lines( lt_batches ) > gc_max.
      fail( 'Applied journal ownership inventory exceeds the bounded limit' ).
    ENDIF.
    LOOP AT lt_batches INTO DATA(ls_batch).
      APPEND |MATCHED LINE={ ls_batch-line_num } applied journal batch={ ls_batch-batch_id }| TO mt_log.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculate_plan.
    DATA lv_xml TYPE xstring.
    DATA lv_operation TYPE c LENGTH 16.
    IF ms_input-mode = 'SIM' OR ms_input-mode = 'APPLY'.
      lv_operation = 'APPLY_PREVIEW'.
      CALL TRANSFORMATION id SOURCE operation = lv_operation schema = gc_schema
        max_rows = gc_max run = ms_run processing = mv_proc_count other_provider = ms_counts-other_provider
        rows = mt_plan_rows RESULT XML lv_xml.
    ELSE.
      lv_operation = 'REVERSE_PREVIEW'.
      CALL TRANSFORMATION id SOURCE operation = lv_operation schema = gc_schema
        max_rows = gc_max run = ms_run processing = mv_proc_count other_provider = ms_counts-other_provider
        header = ms_header items = mt_items rows = mt_plan_rows RESULT XML lv_xml.
    ENDIF.
    mv_plan = digest( lv_xml ).
    APPEND |P_PLAN={ mv_plan } RUN={ ms_run-calc_run_id } PERIOD={ ms_run-fiscal_period } YEAR={ ms_run-fiscal_year }| TO mt_log.
    APPEND |Candidate={ ms_counts-candidates } matched={ ms_counts-matched } excluded={ ms_counts-excluded }| TO mt_log.
    APPEND |Conflict={ ms_counts-conflicts } other-provider={ ms_counts-other_provider } processing={ mv_proc_count }| TO mt_log.
  ENDMETHOD.

  METHOD batch_noop.
    CHECK ms_header-batch_id IS NOT INITIAL.
    IF ms_input-mode = 'APPLY'.
      IF ms_header-state = 'R'.
        fail( 'A reversed UUID cannot be reused for APPLY' ).
      ENDIF.
      APPEND |ALREADY_APPLIED batch={ ms_header-batch_id }; no repair will be attempted| TO mt_log.
      LOOP AT mt_items INTO DATA(ls_item).
        READ TABLE mt_lines INTO DATA(ls_line) WITH TABLE KEY calc_run_id = ls_item-run_id line_num = ls_item-line_num.
        IF sy-subrc <> 0.
          APPEND |DRIFT missing LINE={ ls_item-line_num }| TO mt_log.
        ELSEIF fingerprint( ls_line ) <> ls_item-after_hash.
          APPEND |DRIFT changed LINE={ ls_item-line_num }| TO mt_log.
        ENDIF.
      ENDLOOP.
      rv_noop = abap_true.
    ELSEIF ( ms_input-mode = 'REVERSE' OR ms_input-mode = 'R_SIM' ) AND ms_header-state = 'R'.
      APPEND |ALREADY_REVERSED batch={ ms_header-batch_id }| TO mt_log.
      rv_noop = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD stamp_changes.
    TEST-SEAM ca09_clock.
      GET TIME STAMP FIELD mv_time.
    END-TEST-SEAM.
    LOOP AT mt_changes ASSIGNING FIELD-SYMBOL(<change>).
      IF mv_time <= <change>-before-local_last_changed_at OR mv_time <= <change>-after-local_last_changed_at.
        fail( 'New timestamp cannot advance all affected ETags' ).
      ENDIF.
      <change>-after-local_last_changed_at = mv_time.
    ENDLOOP.
  ENDMETHOD.

  METHOD make_apply_items.
    CLEAR mt_items.
    LOOP AT mt_changes INTO DATA(ls_change).
      INSERT VALUE #( mandt = ls_change-before-mandt batch_id = ms_input-batch_id run_id = ms_input-run_id
        line_num = ls_change-before-line_num
        before_trans_currency = ls_change-before-trans_currency before_net_trans_amt = ls_change-before-net_trans_amt
        before_exch_rate_1 = ls_change-before-exch_rate_1 before_exch_rate_1_type = ls_change-before-exch_rate_1_type
        before_changed_at = ls_change-before-local_last_changed_at before_hash = fingerprint( ls_change-before )
        after_trans_currency = ls_change-after-trans_currency after_net_trans_amt = ls_change-after-net_trans_amt
        after_exch_rate_1 = ls_change-after-exch_rate_1 after_exch_rate_1_type = ls_change-after-exch_rate_1_type
        after_changed_at = ls_change-after-local_last_changed_at after_hash = fingerprint( ls_change-after ) ) INTO TABLE mt_items.
      IF sy-subrc <> 0.
        fail( 'Duplicate planned journal key' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD update_lines.
    DATA lt_update TYPE ty_updates.
    LOOP AT mt_changes INTO DATA(ls_change).
      DATA(ls_update) = CORRESPONDING ty_update( ls_change-after ).
      ls_update-set_fields = VALUE #( trans_currency = abap_true net_trans_amt = abap_true
        exch_rate_1 = abap_true exch_rate_1_type = abap_true local_last_changed_at = abap_true ).
      APPEND ls_update TO lt_update.
    ENDLOOP.
    DATA lv_rc TYPE sy-subrc.
    DATA lv_count TYPE sy-dbcnt.
    TEST-SEAM ca09_update.
      UPDATE zreing_ca_line_a FROM TABLE @lt_update INDICATORS SET STRUCTURE set_fields.
      lv_rc = sy-subrc.
      lv_count = sy-dbcnt.
    END-TEST-SEAM.
    IF lv_rc <> 0 OR lv_count <> lines( mt_changes ).
      fail( 'Selective UPDATE row count differs from the plan' ).
    ENDIF.
    verify_lines( ).
  ENDMETHOD.

  METHOD verify_lines.
    DATA lt_actual TYPE ty_lines.
    SELECT FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
      lifnr, bp_name, bukrs_prest, mat_uuid, matnr,
      op_type, op_uuid, cm_h_id, cm_load_seq, op_instance_num,
      parent_op_type, origin_run_id, origin_line_num, parent_net_amt, parent_currency,
      defer_pct, defer_cuota_num, defer_cuota_total, defer_from, defer_to,
      bukrs_recv, country, base_amt, share_pct, share_pais_pct,
      share_comb_pct, calc_amt, bruto_amt, gross_up_amt, tax_amt,
      net_amt, ct_currency, net_local_amt, local_currency, exch_rate,
      exch_rate_type, trans_currency, net_trans_amt, exch_rate_1, exch_rate_1_type,
      is_delta, delta_seq, delta_base_amt, line_status, sim_message,
      proc_started_at, proc_heartbeat_at, proc_job_id, insumo_check_at, fi_awkey,
      local_last_changed_at
      WHERE calc_run_id = @ms_input-run_id AND bukrs_prest = 'MUR'
      ORDER BY PRIMARY KEY INTO TABLE @lt_actual UP TO @gc_read_max ROWS.
    IF lines( lt_actual ) > gc_max.
      fail( 'RUN grew beyond the bounded snapshot during UPDATE' ).
    ENDIF.
    LOOP AT mt_changes INTO DATA(ls_change).
      READ TABLE lt_actual INTO DATA(ls_actual)
        WITH TABLE KEY calc_run_id = ls_change-after-calc_run_id line_num = ls_change-after-line_num.
      IF sy-subrc <> 0.
        fail( 'Updated physical LINE is missing' ).
      ENDIF.
      IF ls_actual <> ls_change-after.
        fail( |Post-update full LINE verification failed: LINE={ ls_actual-line_num }| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD persist_journal.
    DATA lv_rc TYPE sy-subrc.
    DATA lv_count TYPE sy-dbcnt.
    IF ms_input-mode = 'APPLY'.
      make_apply_items( ).
      ms_header = VALUE #( mandt = ms_run-mandt batch_id = ms_input-batch_id run_id = ms_input-run_id
        schema_id = gc_schema state = 'A' plan_hash = mv_plan row_count = lines( mt_items )
        applied_by = sy-uname applied_at = mv_time job_key = mv_job_key ).
      TEST-SEAM ca09_insert_items.
        INSERT zreing_ca_bf_i_a FROM TABLE @mt_items.
        lv_rc = sy-subrc.
        lv_count = sy-dbcnt.
      END-TEST-SEAM.
      IF lv_rc <> 0 OR lv_count <> lines( mt_items ).
        fail( 'Journal INSERT cardinality failed' ).
      ENDIF.
      TEST-SEAM ca09_insert_header.
        INSERT zreing_ca_bf_h_a FROM @ms_header.
        lv_rc = sy-subrc.
        lv_count = sy-dbcnt.
      END-TEST-SEAM.
      IF lv_rc <> 0 OR lv_count <> 1.
        fail( 'Journal header INSERT failed; rollback required' ).
      ENDIF.
    ELSE.
      LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<item>).
        READ TABLE mt_changes INTO DATA(ls_change)
          WITH KEY before-calc_run_id = <item>-run_id before-line_num = <item>-line_num.
        IF sy-subrc <> 0.
          fail( 'Reverse journal has no planned LINE' ).
        ENDIF.
        <item>-reverse_hash = fingerprint( ls_change-after ).
        <item>-reversed_at = mv_time.
      ENDLOOP.
      TEST-SEAM ca09_reverse_items.
        UPDATE zreing_ca_bf_i_a FROM TABLE @mt_items.
        lv_rc = sy-subrc.
        lv_count = sy-dbcnt.
      END-TEST-SEAM.
      IF lv_rc <> 0 OR lv_count <> lines( mt_items ).
        fail( 'Reverse journal UPDATE cardinality failed' ).
      ENDIF.
      ms_header-state = 'R'.
      ms_header-reversed_by = sy-uname.
      ms_header-reversed_at = mv_time.
      TEST-SEAM ca09_reverse_header.
        UPDATE zreing_ca_bf_h_a FROM @ms_header.
        lv_rc = sy-subrc.
        lv_count = sy-dbcnt.
      END-TEST-SEAM.
      IF lv_rc <> 0 OR lv_count <> 1.
        fail( 'Reverse header UPDATE failed' ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD save_log.
    TEST-SEAM ca09_log.
      IF mv_isolated_test = abap_true.
        fail( 'Isolated tests must replace the BALI persistence seam' ).
      ENDIF.
      TRY.
          DATA(lo_log) = cl_bali_log=>create_with_header( cl_bali_header_setter=>create(
            object = 'ZREING_CA_BF' subobject = 'MAIN' external_id = CONV #( ms_input-run_id ) ) ).
          lo_log->add_item( cl_bali_free_text_setter=>create(
            text = CONV #( |System={ sy-sysid } Client={ sy-mandt } Actor={ sy-uname } Mode={ ms_input-mode }| ) ) ).
          lo_log->add_item( cl_bali_free_text_setter=>create(
            text = CONV #( |RUN={ ms_input-run_id } Batch={ ms_input-batch_id } Schema={ gc_schema } Job={ mv_job_key }| ) ) ).
          LOOP AT mt_log INTO DATA(lv_text).
            " BALI free-text items are bounded; split instead of truncating preview hashes/errors.
            WHILE strlen( lv_text ) > 0.
              DATA(lv_length) = nmin( val1 = 200 val2 = strlen( lv_text ) ).
              lo_log->add_item( cl_bali_free_text_setter=>create( text = CONV #( lv_text(lv_length) ) ) ).
              lv_text = substring( val = lv_text off = lv_length ).
            ENDWHILE.
          ENDLOOP.
          IF iv_error = abap_true.
            cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection( log = lo_log assign_to_current_appl_job = abap_true ).
          ELSE.
            cl_bali_log_db=>get_instance( )->save_log( log = lo_log assign_to_current_appl_job = abap_true ).
          ENDIF.
        CATCH cx_bali_runtime INTO DATA(lx_log).
          fail( |Cannot persist application log: { lx_log->get_text( ) }| ).
      ENDTRY.
    END-TEST-SEAM.
  ENDMETHOD.

  METHOD execute_job.
    check_context( ).
    DATA(lv_write) = xsdbool( ms_input-mode = 'APPLY' OR ms_input-mode = 'REVERSE' ).
    IF lv_write = abap_true.
      lock_run( ).
    ENDIF.
    load_snapshot( ).
    IF batch_noop( ) = abap_false.
      IF ms_input-mode = 'SIM' OR ms_input-mode = 'APPLY'.
        build_apply( ).
        report_matched_batches( ).
      ELSE.
        build_reverse( ).
      ENDIF.
      calculate_plan( ).
      IF lv_write = abap_true.
        IF mv_plan <> ms_input-plan.
          fail( 'Approved preview no longer matches this RUN/journal; simulate again' ).
        ENDIF.
        IF ms_counts-conflicts > 0.
          fail( 'The plan contains conflicts; entire write rejected' ).
        ENDIF.
        IF mt_changes IS NOT INITIAL.
          stamp_changes( ).
          update_lines( ).
          persist_journal( ).
          APPEND |{ ms_input-mode } rows={ lines( mt_changes ) } batch={ ms_input-batch_id }| TO mt_log.
        ELSE.
          APPEND 'NOOP: no eligible rows; no fictitious journal batch created' TO mt_log.
        ENDIF.
      ELSE.
        APPEND 'PREVIEW ONLY: no business/journal DML and no RUN lock' TO mt_log.
      ENDIF.
    ENDIF.
    save_log( ).
    TEST-SEAM ca09_commit.
      IF mv_isolated_test = abap_true.
        fail( 'Isolated tests must replace the commit seam' ).
      ENDIF.
      COMMIT WORK.
    END-TEST-SEAM.
    mv_committed = abap_true.
    DATA(lv_unlock) = release_run( ).
    IF lv_unlock IS NOT INITIAL.
      fail( |Data already committed; owned RUN lock cleanup failed: { lv_unlock }| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

