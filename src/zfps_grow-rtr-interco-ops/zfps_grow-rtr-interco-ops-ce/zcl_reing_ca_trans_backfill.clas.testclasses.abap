" V001 (CC) - CA-09 (EBA): isolated fixtures; never execute business jobs.
CLASS ltc_backfill DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PUBLIC SECTION.
    CLASS-DATA mv_lock_calls TYPE i.
    CLASS-DATA mv_unlock_calls TYPE i.
    CLASS-DATA mv_commit_calls TYPE i.
    CLASS-DATA mv_rollback_calls TYPE i.
    CLASS-DATA mv_log_calls TYPE i.
    CLASS-DATA mv_fixture_clock TYPE timestampl.
  PRIVATE SECTION.
    CLASS-DATA mo_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zcl_reing_ca_trans_backfill.
    DATA ms_line TYPE zreing_ca_line_a.
    CONSTANTS gc_batch TYPE sysuuid_x16 VALUE '00112233445566778899AABBCCDDEEFF'.
    TYPES ty_fixture_lines TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    METHODS setup.
    METHODS teardown.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS seed IMPORTING it_lines TYPE ty_fixture_lines.
    METHODS prepare_apply RAISING cx_apj_rt_content.
    METHODS prepare_reverse RAISING cx_apj_rt_content.
    METHODS call_mode IMPORTING iv_mode TYPE csequence iv_plan TYPE csequence OPTIONAL
      RAISING cx_apj_rt_content.
    METHODS assert_no_business_journal.
    METHODS parameters_rejected FOR TESTING RAISING cx_apj_rt_content.
    METHODS modes_and_zero_uuid FOR TESTING RAISING cx_apj_rt_content.
    METHODS scalar_lengths FOR TESTING RAISING cx_apj_rt_content.
    METHODS signed_net_copy FOR TESTING RAISING cx_apj_rt_content.
    METHODS eligibility_matrix FOR TESTING.
    METHODS full_line_hash FOR TESTING RAISING cx_apj_rt_content.
    METHODS apply_preview_stable FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_preview_stable FOR TESTING RAISING cx_apj_rt_content.
    METHODS simulate_no_dml FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_sim_no_dml FOR TESTING RAISING cx_apj_rt_content.
    METHODS bounded_snapshot FOR TESTING RAISING cx_apj_rt_content.
    METHODS processing_other_provider FOR TESTING RAISING cx_apj_rt_content.
    METHODS preview_drift FOR TESTING RAISING cx_apj_rt_content.
    METHODS conflicts_no_partial FOR TESTING RAISING cx_apj_rt_content.
    METHODS apply_selective_and_journal FOR TESTING RAISING cx_apj_rt_content.
    METHODS repeat_apply_no_dml FOR TESTING RAISING cx_apj_rt_content.
    METHODS batch_wrong_run FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_restore_etag FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_before_corruption FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_after_corruption FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_drift_missing FOR TESTING RAISING cx_apj_rt_content.
    METHODS reverse_bad_schema_count FOR TESTING RAISING cx_apj_rt_content.
    METHODS repeat_reverse_no_dml FOR TESTING RAISING cx_apj_rt_content.
    METHODS lock_conflict FOR TESTING RAISING cx_apj_rt_content.
    METHODS rollback_before_commit FOR TESTING RAISING cx_apj_rt_content.
    METHODS failure_after_commit FOR TESTING RAISING cx_apj_rt_content.
    METHODS clock_must_advance FOR TESTING RAISING cx_apj_rt_content.
    METHODS eba_on_blocked FOR TESTING RAISING cx_apj_rt_content.
    METHODS isolation_without_injection FOR TESTING RAISING cx_apj_rt_content.
    METHODS journal_failure_rollback FOR TESTING RAISING cx_apj_rt_content.
    METHODS log_failure_rollback FOR TESTING RAISING cx_apj_rt_content.
    METHODS reread_failure_rollback FOR TESTING RAISING cx_apj_rt_content.
    METHODS matched_noop FOR TESTING RAISING cx_apj_rt_content.
    METHODS orphan_batch_rejected FOR TESTING RAISING cx_apj_rt_content.
    METHODS bad_request_no_ambient_effect FOR TESTING RAISING cx_apj_rt_content.
    METHODS untrusted_context_no_effect FOR TESTING RAISING cx_apj_rt_content.
ENDCLASS.

CLASS ltc_backfill IMPLEMENTATION.
  METHOD class_setup.
    mo_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #(
      ( 'ZREING_CA_LINE_A' ) ( 'ZREING_CA_RUN_A' ) ( 'ZREING_CA_BF_H_A' ) ( 'ZREING_CA_BF_I_A' ) ) ).
    cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_CA_LINE_A' ) ).
    cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_CA_RUN_A' ) ).
    cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_CA_BF_H_A' ) ).
    cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_CA_BF_I_A' ) ).
  ENDMETHOD.
  METHOD class_teardown.
    IF mo_env IS BOUND.
      mo_env->destroy( ).
    ENDIF.
  ENDMETHOD.
  METHOD setup.
    mo_cut = NEW #( ).
    mo_cut->mv_isolated_test = abap_true.
    cl_abap_unit_assert=>assert_bound( mo_env ).
    mo_env->clear_doubles( ).
    CLEAR: mv_lock_calls, mv_unlock_calls, mv_commit_calls, mv_rollback_calls, mv_log_calls.
    mv_fixture_clock = '20261005120001.0000000'.
    ms_line = VALUE #( mandt = sy-mandt calc_run_id = 'TEST-CA09' line_num = 1
      bukrs_prest = 'MUR' bukrs_recv = 'B901' line_status = 'CONT' ct_currency = 'USD'
      net_amt = '1234.56' calc_amt = '1240.56' tax_amt = '6.00' fi_awkey = 'TEST-FI-KEY'
      op_type = 'P' op_instance_num = 2 local_last_changed_at = '20261005120000.0000000' ).
    seed( VALUE #( ( ms_line ) ) ).
    mo_cut->ms_input = VALUE #( mode = 'SIM' run_id = ms_line-calc_run_id ).
  ENDMETHOD.
  METHOD teardown.
    IF mo_env IS BOUND.
      mo_env->clear_doubles( ).
    ENDIF.
    CLEAR mo_cut.
  ENDMETHOD.
  METHOD seed.
    DATA lt_run TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    lt_run = VALUE #( ( mandt = sy-mandt calc_run_id = 'TEST-CA09' fiscal_period = '010'
      fiscal_year = '2026' total_lines = lines( it_lines ) total_groups = 1 ) ).
    mo_env->clear_doubles( ).
    mo_env->insert_test_data( lt_run ).
    mo_env->insert_test_data( it_lines ).
  ENDMETHOD.
  METHOD prepare_apply.
    mo_cut->ms_input = VALUE #( mode = 'SIM' run_id = ms_line-calc_run_id ).
    mo_cut->load_snapshot( ).
    mo_cut->build_apply( ).
    mo_cut->calculate_plan( ).
    mo_cut->ms_input = VALUE #( mode = 'APPLY' run_id = ms_line-calc_run_id
      batch_id = gc_batch pause = abap_true plan = mo_cut->mv_plan ).
  ENDMETHOD.
  METHOD prepare_reverse.
    prepare_apply( ).
    mo_cut->execute_job( ).
    mo_cut->ms_input-mode = 'R_SIM'.
    mo_cut->load_snapshot( ).
    mo_cut->build_reverse( ).
    mo_cut->calculate_plan( ).
    mo_cut->ms_input-mode = 'REVERSE'.
    mo_cut->ms_input-plan = mo_cut->mv_plan.
    mv_fixture_clock = '20261005120002.0000000'.
    CLEAR: mv_lock_calls, mv_unlock_calls, mv_commit_calls, mv_rollback_calls, mv_log_calls.
  ENDMETHOD.
  METHOD call_mode.
    DATA lt_params TYPE if_apj_rt_exec_object=>tt_templ_val.
    lt_params = VALUE #( ( selname = 'P_MODE' kind = 'P' sign = 'I' option = 'EQ' low = CONV #( iv_mode ) )
      ( selname = 'P_RUNID' kind = 'P' sign = 'I' option = 'EQ' low = 'TEST-CA09' ) ).
    IF iv_mode <> 'SIM'.
      APPEND VALUE #( selname = 'P_BATCH' kind = 'P' sign = 'I' option = 'EQ' low = CONV #( gc_batch ) ) TO lt_params.
    ENDIF.
    IF iv_mode = 'APPLY' OR iv_mode = 'REVERSE'.
      APPEND VALUE #( selname = 'P_PAUSE' kind = 'P' sign = 'I' option = 'EQ' low = 'X' ) TO lt_params.
      APPEND VALUE #( selname = 'P_PLAN' kind = 'P' sign = 'I' option = 'EQ' low = CONV #( iv_plan ) ) TO lt_params.
    ENDIF.
    mo_cut->if_apj_rt_exec_object~execute( lt_params ).
  ENDMETHOD.
  METHOD assert_no_business_journal.
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_line).
    cl_abap_unit_assert=>assert_equals( act = ls_line exp = ms_line ).
    SELECT FROM zreing_ca_bf_h_a FIELDS COUNT( * ) WHERE run_id = 'TEST-CA09' INTO @DATA(lv_headers).
    SELECT FROM zreing_ca_bf_i_a FIELDS COUNT( * ) WHERE run_id = 'TEST-CA09' INTO @DATA(lv_items).
    cl_abap_unit_assert=>assert_initial( lv_headers ).
    cl_abap_unit_assert=>assert_initial( lv_items ).
  ENDMETHOD.

  METHOD parameters_rejected.
    DATA lt_bad TYPE if_apj_rt_exec_object=>tt_templ_val.
    lt_bad = VALUE #( ( selname = 'P_RUNID' kind = 'P' sign = 'I' option = 'EQ' low = 'TEST-CA09' )
      ( selname = 'P_RUNID' kind = 'P' sign = 'I' option = 'EQ' low = 'TEST-CA09' ) ).
    TRY.
        mo_cut->parse( lt_bad ).
        cl_abap_unit_assert=>fail( 'Duplicate accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    lt_bad = VALUE #( ( selname = 'UNKNOWN' kind = 'P' sign = 'I' option = 'EQ' low = 'X' ) ).
    TRY.
        mo_cut->parse( lt_bad ).
        cl_abap_unit_assert=>fail( 'Unknown parameter accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    lt_bad = VALUE #( ( selname = 'P_RUNID' kind = 'S' sign = 'I' option = 'BT' low = 'A' high = 'Z' ) ).
    TRY.
        mo_cut->parse( lt_bad ).
        cl_abap_unit_assert=>fail( 'Range accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mv_lock_calls ).
    assert_no_business_journal( ).
  ENDMETHOD.
  METHOD modes_and_zero_uuid.
    DATA lt_params TYPE if_apj_rt_exec_object=>tt_templ_val.
    lt_params = VALUE #( ( selname = 'P_RUNID' kind = 'P' sign = 'I' option = 'EQ' low = 'TEST-CA09' )
      ( selname = 'P_MODE' kind = 'P' sign = 'I' option = 'EQ' low = 'BAD' ) ).
    TRY.
        mo_cut->parse( lt_params ).
        cl_abap_unit_assert=>fail( 'Invalid mode accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    lt_params = VALUE #( ( selname = 'P_RUNID' kind = 'P' sign = 'I' option = 'EQ' low = 'TEST-CA09' )
      ( selname = 'P_BATCH' kind = 'P' sign = 'I' option = 'EQ' low = '00000000000000000000000000000000' ) ).
    TRY.
        mo_cut->parse( lt_params ).
        cl_abap_unit_assert=>fail( 'Zero UUID accepted in SIM' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    CLEAR mo_cut->ms_input.
    mo_cut->parse( VALUE #( ( selname = 'P_RUNID' kind = 'P' sign = 'I' option = 'EQ' low = 'TEST-CA09' )
      ( selname = 'P_BATCH' kind = 'P' sign = 'I' option = 'EQ' low = '00112233445566778899AABBCCDDEEFF' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->ms_input-batch_id exp = gc_batch ).
  ENDMETHOD.
  METHOD scalar_lengths.
    TYPES ty_names TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA(lt_names) = VALUE ty_names( ( `P_RUNID` ) ( `P_MODE` ) ( `P_BATCH` ) ( `P_PLAN` ) ).
    LOOP AT lt_names INTO DATA(lv_name).
      CLEAR mo_cut->ms_input.
      TRY.
          mo_cut->parse( VALUE #( ( selname = CONV #( lv_name ) kind = 'P' sign = 'I' option = 'EQ'
            low = 'ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ' ) ) ).
          cl_abap_unit_assert=>fail( |Invalid/truncated value accepted: { lv_name }| ).
        CATCH cx_apj_rt_content.
      ENDTRY.
    ENDLOOP.
    TRY.
        mo_cut->parse( VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'Empty RUN accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD signed_net_copy.
    DATA lt_lines TYPE ty_fixture_lines.
    DATA ls_line TYPE zreing_ca_line_a.
    DO 3 TIMES.
      ls_line = ms_line.
      ls_line-line_num = sy-index.
      CASE sy-index.
        WHEN 1. ls_line-net_amt = '1234.56'.
        WHEN 2. ls_line-net_amt = '-1234.56'.
        WHEN 3. ls_line-net_amt = 0.
      ENDCASE.
      APPEND ls_line TO lt_lines.
    ENDDO.
    seed( lt_lines ).
    prepare_apply( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->mt_changes ) exp = 3 ).
    LOOP AT mo_cut->mt_changes INTO DATA(ls_change).
      cl_abap_unit_assert=>assert_equals( act = ls_change-after-net_trans_amt exp = ls_change-before-net_amt ).
      cl_abap_unit_assert=>assert_equals( act = ls_change-after-trans_currency exp = ls_change-before-ct_currency ).
      cl_abap_unit_assert=>assert_equals( act = ls_change-after-exch_rate_1 exp = CONV zreing_ca_exch_rate_1( '1.00000' ) ).
      cl_abap_unit_assert=>assert_initial( ls_change-after-exch_rate_1_type ).
    ENDLOOP.
  ENDMETHOD.
  METHOD eligibility_matrix.
    DATA(ls_line) = ms_line.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'CAND' ).
    TYPES ty_states TYPE STANDARD TABLE OF zreing_ca_line_status WITH EMPTY KEY.
    DATA(lt_states) = VALUE ty_states( ( 'CALC' ) ( 'LIBD' ) ( 'CONT' ) ( 'ANULD' ) ).
    LOOP AT lt_states INTO DATA(lv_state).
      ls_line-line_status = lv_state.
      cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'CAND' ).
    ENDLOOP.
    ls_line-ct_currency = ''.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'CONFLICT' ).
    ls_line = ms_line.
    ls_line-bukrs_prest = 'EBA'.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'EXCLUDED' ).
    ls_line = ms_line.
    ls_line-line_status = 'PEND'.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'EXCLUDED' ).
    ls_line = ms_line.
    ls_line-net_trans_amt = 1.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'CONFLICT' ).
    ls_line-net_trans_amt = ms_line-net_amt.
    ls_line-trans_currency = 'USD'.
    ls_line-exch_rate_1 = '1.00000'.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'MATCHED' ).
    ls_line-exch_rate_1_type = 'M'.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->classify( ls_line ) exp = 'CONFLICT' ).
  ENDMETHOD.
  METHOD full_line_hash.
    DATA(lv_before) = mo_cut->fingerprint( ms_line ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->fingerprint( ms_line ) exp = lv_before ).
    DATA(ls_drift) = ms_line.
    ls_drift-fi_awkey = 'OTHER-FI'.
    cl_abap_unit_assert=>assert_differs( act = mo_cut->fingerprint( ls_drift ) exp = lv_before ).
    ls_drift = ms_line.
    ls_drift-op_instance_num += 1.
    cl_abap_unit_assert=>assert_differs( act = mo_cut->fingerprint( ls_drift ) exp = lv_before ).
    ls_drift = ms_line.
    ls_drift-line_status = 'ANULD'.
    cl_abap_unit_assert=>assert_differs( act = mo_cut->fingerprint( ls_drift ) exp = lv_before ).
  ENDMETHOD.
  METHOD apply_preview_stable.
    prepare_apply( ).
    DATA(lv_sim) = mo_cut->mv_plan.
    mo_cut->mv_job_key = 'OTHER-JOB'.
    mo_cut->mv_time = '20271005120000.0000000'.
    mo_cut->calculate_plan( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_plan exp = lv_sim ).
    mo_cut->ms_input-mode = 'SIM'.
    CLEAR mo_cut->ms_input-batch_id.
    mo_cut->calculate_plan( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_plan exp = lv_sim ).
  ENDMETHOD.
  METHOD reverse_preview_stable.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    DATA(lv_preview) = mo_cut->mv_plan.
    mo_cut->mv_time = '20271005120000.0000000'.
    mo_cut->calculate_plan( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_plan exp = lv_preview ).
    mo_cut->ms_input-mode = 'R_SIM'.
    mo_cut->calculate_plan( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->mv_plan exp = lv_preview ).
  ENDMETHOD.
  METHOD simulate_no_dml.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    call_mode( 'SIM' ).
    assert_no_business_journal( ).
    cl_abap_unit_assert=>assert_initial( mv_lock_calls ).
    cl_abap_unit_assert=>assert_initial( mv_unlock_calls ).
    cl_abap_unit_assert=>assert_equals( act = mv_log_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_commit_calls exp = 1 ).
  ENDMETHOD.
  METHOD reverse_sim_no_dml.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_before).
    call_mode( 'R_SIM' ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_after).
    cl_abap_unit_assert=>assert_equals( act = ls_after exp = ls_before ).
    SELECT SINGLE FROM zreing_ca_bf_h_a FIELDS state WHERE batch_id = @gc_batch INTO @DATA(lv_state).
    cl_abap_unit_assert=>assert_equals( act = lv_state exp = 'A' ).
    cl_abap_unit_assert=>assert_initial( mv_lock_calls ).
  ENDMETHOD.
  METHOD bounded_snapshot.
    DATA lt_rows TYPE ty_fixture_lines.
    DO 5000 TIMES.
      DATA(ls_row) = ms_line.
      ls_row-line_num = sy-index.
      APPEND ls_row TO lt_rows.
    ENDDO.
    seed( lt_rows ).
    mo_cut->load_snapshot( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->mt_lines ) exp = 5000 ).
    ls_row-line_num = 5001.
    APPEND ls_row TO lt_rows.
    seed( lt_rows ).
    TRY.
        mo_cut->load_snapshot( ).
        cl_abap_unit_assert=>fail( '5001 rows silently truncated' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD processing_other_provider.
    DATA(ls_other) = ms_line.
    ls_other-line_num = 2.
    ls_other-bukrs_prest = 'EBA'.
    ls_other-line_status = 'POST_PROC'.
    seed( VALUE #( ( ms_line ) ( ls_other ) ) ).
    prepare_apply( ).
    TRY.
        mo_cut->load_snapshot( ).
        cl_abap_unit_assert=>fail( 'Non-MUR processing line allowed APPLY' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    assert_no_business_journal( ).
  ENDMETHOD.
  METHOD preview_drift.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    UPDATE zreing_ca_line_a SET fi_awkey = 'DRIFT' WHERE calc_run_id = 'TEST-CA09' AND line_num = 1.
    TRY.
        mo_cut->execute_job( ).
        cl_abap_unit_assert=>fail( 'Stale preview accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    SELECT SINGLE FROM zreing_ca_line_a FIELDS trans_currency WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(lv_currency).
    cl_abap_unit_assert=>assert_initial( lv_currency ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
  ENDMETHOD.
  METHOD conflicts_no_partial.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    DATA(ls_bad) = ms_line.
    ls_bad-line_num = 2.
    ls_bad-exch_rate_1 = 2.
    seed( VALUE #( ( ms_line ) ( ls_bad ) ) ).
    prepare_apply( ).
    TRY.
        mo_cut->execute_job( ).
        cl_abap_unit_assert=>fail( 'Conflict permitted partial update' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    assert_no_business_journal( ).
  ENDMETHOD.
  METHOD apply_selective_and_journal.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    mo_cut->execute_job( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_actual).
    DATA(ls_expected) = ms_line.
    ls_expected-trans_currency = 'USD'.
    ls_expected-net_trans_amt = ms_line-net_amt.
    ls_expected-exch_rate_1 = '1.00000'.
    ls_expected-local_last_changed_at = mv_fixture_clock.
    cl_abap_unit_assert=>assert_equals( act = ls_actual exp = ls_expected ).
    SELECT SINGLE FROM zreing_ca_bf_h_a FIELDS mandt, batch_id, run_id, schema_id, state,
      plan_hash, row_count, applied_by, applied_at, reversed_by,
      reversed_at, job_key WHERE batch_id = @gc_batch INTO @DATA(ls_header).
    SELECT SINGLE FROM zreing_ca_bf_i_a FIELDS mandt, batch_id, run_id, line_num, before_trans_currency,
      before_net_trans_amt, before_exch_rate_1, before_exch_rate_1_type, before_changed_at, after_trans_currency,
      after_net_trans_amt, after_exch_rate_1, after_exch_rate_1_type, after_changed_at, before_hash,
      after_hash, reverse_hash, reversed_at WHERE batch_id = @gc_batch AND run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_item).
    cl_abap_unit_assert=>assert_equals( act = ls_header-state exp = 'A' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-row_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-before_hash exp = mo_cut->fingerprint( ms_line ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-after_hash exp = mo_cut->fingerprint( ls_actual ) ).
    cl_abap_unit_assert=>assert_equals( act = mv_commit_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_unlock_calls exp = 1 ).
  ENDMETHOD.
  METHOD repeat_apply_no_dml.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    mo_cut->execute_job( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_before).
    mv_fixture_clock = '20261005120003.0000000'.
    mo_cut->execute_job( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_after).
    cl_abap_unit_assert=>assert_equals( act = ls_after exp = ls_before ).
    SELECT FROM zreing_ca_bf_i_a FIELDS COUNT( * ) WHERE run_id = 'TEST-CA09' INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 ).
  ENDMETHOD.
  METHOD batch_wrong_run.
    prepare_apply( ).
    DATA lt_headers TYPE STANDARD TABLE OF zreing_ca_bf_h_a WITH EMPTY KEY.
    lt_headers = VALUE #( ( mandt = sy-mandt batch_id = gc_batch run_id = 'OTHER-RUN'
      schema_id = 'CA09_L56_V001' state = 'A' row_count = 1 ) ).
    mo_env->insert_test_data( lt_headers ).
    TRY.
        mo_cut->load_batch( ).
        cl_abap_unit_assert=>fail( 'UUID reused for another RUN' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD reverse_restore_etag.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    mo_cut->execute_job( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_actual).
    DATA(ls_expected) = ms_line.
    ls_expected-local_last_changed_at = mv_fixture_clock.
    cl_abap_unit_assert=>assert_equals( act = ls_actual exp = ls_expected ).
    SELECT SINGLE FROM zreing_ca_bf_h_a FIELDS state WHERE batch_id = @gc_batch INTO @DATA(lv_state).
    cl_abap_unit_assert=>assert_equals( act = lv_state exp = 'R' ).
    SELECT SINGLE FROM zreing_ca_bf_i_a FIELDS reverse_hash WHERE batch_id = @gc_batch AND run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(lv_hash).
    cl_abap_unit_assert=>assert_equals( act = lv_hash exp = mo_cut->fingerprint( ls_actual ) ).
  ENDMETHOD.
  METHOD reverse_before_corruption.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    UPDATE zreing_ca_bf_i_a SET before_net_trans_amt = 99 WHERE batch_id = @gc_batch AND run_id = 'TEST-CA09' AND line_num = 1.
    mo_cut->load_batch( ).
    TRY.
        mo_cut->build_reverse( ).
        cl_abap_unit_assert=>fail( 'Corrupted BEFORE restored despite intact LINE/AFTER_HASH' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
  ENDMETHOD.
  METHOD reverse_after_corruption.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    UPDATE zreing_ca_bf_i_a SET after_trans_currency = 'BRL' WHERE batch_id = @gc_batch AND run_id = 'TEST-CA09' AND line_num = 1.
    mo_cut->load_batch( ).
    TRY.
        mo_cut->build_reverse( ).
        cl_abap_unit_assert=>fail( 'Corrupted AFTER tuple accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD reverse_drift_missing.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    UPDATE zreing_ca_line_a SET fi_awkey = 'DRIFT' WHERE calc_run_id = 'TEST-CA09' AND line_num = 1.
    mo_cut->load_snapshot( ).
    TRY.
        mo_cut->build_reverse( ).
        cl_abap_unit_assert=>fail( 'Non-target drift accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    DELETE FROM zreing_ca_line_a WHERE calc_run_id = 'TEST-CA09' AND line_num = 1.
    mo_cut->load_snapshot( ).
    TRY.
        mo_cut->build_reverse( ).
        cl_abap_unit_assert=>fail( 'Missing LINE accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD reverse_bad_schema_count.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    UPDATE zreing_ca_bf_h_a SET schema_id = 'OTHER' WHERE batch_id = @gc_batch.
    TRY.
        mo_cut->load_batch( ).
        cl_abap_unit_assert=>fail( 'Unknown recipe accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    UPDATE zreing_ca_bf_h_a SET schema_id = 'CA09_L56_V001', row_count = 2 WHERE batch_id = @gc_batch.
    TRY.
        mo_cut->load_batch( ).
        cl_abap_unit_assert=>fail( 'Journal cardinality mismatch accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD repeat_reverse_no_dml.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    prepare_reverse( ).
    mo_cut->execute_job( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_before).
    mo_cut->execute_job( ).
    SELECT SINGLE FROM zreing_ca_line_a FIELDS mandt, calc_run_id, line_num, ct_uuid, ct_id,
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
      local_last_changed_at WHERE calc_run_id = 'TEST-CA09' AND line_num = 1 INTO @DATA(ls_after).
    cl_abap_unit_assert=>assert_equals( act = ls_after exp = ls_before ).
    mo_cut->ms_input-mode = 'APPLY'.
    TRY.
        mo_cut->execute_job( ).
        cl_abap_unit_assert=>fail( 'Reversed UUID reused' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD lock_conflict.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock.
      ltc_backfill=>mv_lock_calls += 1.
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    END-TEST-INJECTION.
    prepare_apply( ).
    TRY.
        mo_cut->execute_job( ).
        cl_abap_unit_assert=>fail( 'Lock conflict accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mo_cut->mv_locked_run ).
    cl_abap_unit_assert=>assert_initial( mv_unlock_calls ).
    assert_no_business_journal( ).
  ENDMETHOD.
  METHOD rollback_before_commit.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_update. lv_rc = 4. lv_count = 0. END-TEST-INJECTION.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    DATA(lv_plan) = CONV string( mo_cut->mv_plan ).
    TRY.
        call_mode( iv_mode = 'APPLY' iv_plan = lv_plan ).
        cl_abap_unit_assert=>fail( 'UPDATE failure accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mv_rollback_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_unlock_calls exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
    assert_no_business_journal( ).
  ENDMETHOD.
  METHOD failure_after_commit.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock.
      ltc_backfill=>mv_unlock_calls += 1.
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    DATA(lv_plan) = CONV string( mo_cut->mv_plan ).
    TRY.
        call_mode( iv_mode = 'APPLY' iv_plan = lv_plan ).
        cl_abap_unit_assert=>fail( 'Cleanup failure hidden' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mv_commit_calls exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mv_rollback_calls ).
    cl_abap_unit_assert=>assert_true( mo_cut->mv_committed ).
    SELECT SINGLE FROM zreing_ca_bf_h_a FIELDS state WHERE batch_id = @gc_batch INTO @DATA(lv_state).
    cl_abap_unit_assert=>assert_equals( act = lv_state exp = 'A' ).
  ENDMETHOD.
  METHOD clock_must_advance.
    TEST-INJECTION ca09_clock. mv_time = '20261005120000.0000000'. END-TEST-INJECTION.
    prepare_apply( ).
    TRY.
        mo_cut->stamp_changes( ).
        cl_abap_unit_assert=>fail( 'Old ETag reused' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.
  METHOD eba_on_blocked.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_switch. lv_off = abap_false. END-TEST-INJECTION.
    prepare_apply( ).
    TRY.
        mo_cut->execute_job( ).
        cl_abap_unit_assert=>fail( 'EBA ON permitted APPLY' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mv_lock_calls ).
    assert_no_business_journal( ).
  ENDMETHOD.
  METHOD isolation_without_injection.
    " No injections: every non-SQL boundary must fail before touching the real system.
    TRY.
        mo_cut->check_context( ).
        cl_abap_unit_assert=>fail( 'Uninjected APJ context reached' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    TRY.
        mo_cut->lock_run( ).
        cl_abap_unit_assert=>fail( 'Uninjected real lock reached' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    TRY.
        mo_cut->save_log( ).
        cl_abap_unit_assert=>fail( 'Uninjected real log persistence reached' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    assert_no_business_journal( ).
  ENDMETHOD.

  METHOD journal_failure_rollback.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_insert_header. lv_rc = 4. lv_count = 0. END-TEST-INJECTION.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    DATA(lv_plan) = CONV string( mo_cut->mv_plan ).
    TRY.
        call_mode( iv_mode = 'APPLY' iv_plan = lv_plan ).
        cl_abap_unit_assert=>fail( 'Header INSERT failure accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    " Doubles stage rows; this verifies rollback orchestration, not database transaction semantics.
    cl_abap_unit_assert=>assert_equals( act = mv_rollback_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_unlock_calls exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
  ENDMETHOD.

  METHOD log_failure_rollback.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_log.
      ltc_backfill=>mv_log_calls += 1.
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    END-TEST-INJECTION.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    DATA(lv_plan) = CONV string( mo_cut->mv_plan ).
    TRY.
        call_mode( iv_mode = 'APPLY' iv_plan = lv_plan ).
        cl_abap_unit_assert=>fail( 'Failed BALI persistence committed data' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mv_rollback_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mv_log_calls exp = 2 ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
  ENDMETHOD.

  METHOD reread_failure_rollback.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_clock. mv_time = ltc_backfill=>mv_fixture_clock. END-TEST-INJECTION.
    TEST-INJECTION ca09_update. lv_rc = 0. lv_count = lines( mt_changes ). END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    prepare_apply( ).
    DATA(lv_plan) = CONV string( mo_cut->mv_plan ).
    TRY.
        call_mode( iv_mode = 'APPLY' iv_plan = lv_plan ).
        cl_abap_unit_assert=>fail( 'UPDATE count accepted despite unchanged reread image' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mv_rollback_calls exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
    assert_no_business_journal( ).
  ENDMETHOD.

  METHOD matched_noop.
    TEST-INJECTION ca09_context. mv_job_key = 'TEST-JOB'. END-TEST-INJECTION.
    TEST-INJECTION ca09_lock. ltc_backfill=>mv_lock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_unlock. ltc_backfill=>mv_unlock_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_commit. ltc_backfill=>mv_commit_calls += 1. END-TEST-INJECTION.
    ms_line-trans_currency = ms_line-ct_currency.
    ms_line-net_trans_amt = ms_line-net_amt.
    ms_line-exch_rate_1 = '1.00000'.
    seed( VALUE #( ( ms_line ) ) ).
    prepare_apply( ).
    mo_cut->execute_job( ).
    assert_no_business_journal( ).
    cl_abap_unit_assert=>assert_equals( act = mo_cut->ms_counts-matched exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mt_changes ).
  ENDMETHOD.

  METHOD orphan_batch_rejected.
    DATA lt_items TYPE STANDARD TABLE OF zreing_ca_bf_i_a WITH EMPTY KEY.
    lt_items = VALUE #( ( mandt = sy-mandt batch_id = gc_batch run_id = 'TEST-CA09' line_num = 1 ) ).
    mo_env->insert_test_data( lt_items ).
    mo_cut->ms_input-batch_id = gc_batch.
    TRY.
        mo_cut->load_batch( ).
        cl_abap_unit_assert=>fail( 'Orphan journal accepted as new batch' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
  ENDMETHOD.

  METHOD bad_request_no_ambient_effect.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TRY.
        call_mode( 'BAD' ).
        cl_abap_unit_assert=>fail( 'Invalid input accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mv_rollback_calls ).
    cl_abap_unit_assert=>assert_initial( mv_log_calls ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
    cl_abap_unit_assert=>assert_initial( mv_lock_calls ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_context_owned ).
    assert_no_business_journal( ).
  ENDMETHOD.

  METHOD untrusted_context_no_effect.
    " Missing context injection fails closed before all effects; no ambient rollback/logging.
    TEST-INJECTION ca09_rollback. ltc_backfill=>mv_rollback_calls += 1. END-TEST-INJECTION.
    TEST-INJECTION ca09_log. ltc_backfill=>mv_log_calls += 1. END-TEST-INJECTION.
    TRY.
        call_mode( 'SIM' ).
        cl_abap_unit_assert=>fail( 'Untrusted context accepted' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( mv_rollback_calls ).
    cl_abap_unit_assert=>assert_initial( mv_log_calls ).
    cl_abap_unit_assert=>assert_initial( mv_commit_calls ).
    cl_abap_unit_assert=>assert_false( mo_cut->mv_context_owned ).
    assert_no_business_journal( ).
  ENDMETHOD.
ENDCLASS.
