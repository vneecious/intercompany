*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : Orphan Recovery (F5) - Motor de Calculo CA          *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Single class implementing, at the same time, the timeout rollback
* state machine (F5-01) and the Application Job Step role (F5-02) --
* same 1:1 pattern as the active precedent ZCL_REING_CA_CALC_JOB
* (F3.2): IF_APJ_RT_EXEC_OBJECT / IF_APJ_DT_EXEC_OBJECT /
* IF_OO_ADT_CLASSRUN, plus a business method (run_recovery_cycle)
* separate from the interface method that only parses parameters and
* delegates (F5-DD-1).
*
* Sub-minute recurrence is solved via self-rescheduling: at the end of
* every cycle (whether orphans were found or not) the class reschedules
* itself with CL_APJ_RT_API=>SCHEDULE_JOB, now + ZREING_CA_RECOVERY_
* INTERVAL seconds (F5-DD-4). check_job_active resolves without a new
* DDIC field via CL_APJ_RT_API=>GET_JOB_DETAILS( iv_jobname = ... ),
* which auto-resolves the latest JOBCOUNT for that JOBNAME when
* IV_JOBCOUNT is omitted (F5-DD-2).
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_orphan_rec DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES:
      if_oo_adt_classrun,
      if_apj_dt_exec_object,
      if_apj_rt_exec_object.

    METHODS constructor
      IMPORTING
        io_verify TYPE REF TO zif_reing_ca_orphan_verify OPTIONAL.
    " OPTIONAL to allow injecting a stub/double in unit tests (F5-04);
    " in production, if omitted, ZCL_REING_CA_ORPHAN_STUB is instantiated.

    "! Business entry point. Public and separate from
    "! if_apj_rt_exec_object~execute (F5-DD-1, same pattern as F3.2).
    METHODS run_recovery_cycle
      RAISING
        cx_apj_rt_content.

  PRIVATE SECTION.
    DATA mo_verify TYPE REF TO zif_reing_ca_orphan_verify.
    DATA mt_log    TYPE string_table.

    " Outcome of decide_recovery( ) for one candidate line -- pure data,
    " no DB access (ATC fix, see class header note).
    TYPES: BEGIN OF ty_recovery_decision,
             skip       TYPE abap_bool,
             delete     TYPE abap_bool,
             new_status TYPE zreing_ca_line_status,
             message    TYPE zreing_ca_log_a-message,
           END OF ty_recovery_decision.

    " Named table types (ATC fix helpers) -- method parameter interfaces
    " require a formal/named type, an anonymous inline
    " "TYPE STANDARD TABLE OF x WITH EMPTY KEY" is not accepted there.
    TYPES ty_jobname_tab TYPE STANDARD TABLE OF zreing_ca_line_a-proc_job_id WITH EMPTY KEY.
    TYPES ty_line_a_tab  TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    TYPES ty_log_a_tab   TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.

    METHODS add_log
      IMPORTING iv_message TYPE string.


    METHODS read_timeout_seconds
      RETURNING VALUE(rv_seconds) TYPE i.

    METHODS read_interval_seconds
      RETURNING VALUE(rv_seconds) TYPE i.



    METHODS reschedule_self.

    METHODS decide_recovery
      IMPORTING is_line            TYPE zreing_ca_line_a
      RETURNING VALUE(rs_decision) TYPE ty_recovery_decision.
METHODS resolve_active_jobs
      RETURNING VALUE(rt_active_jobnames) TYPE ty_jobname_tab.
METHODS persist_recovery
      IMPORTING it_to_delete   TYPE ty_line_a_tab
                it_to_update   TYPE ty_line_a_tab
                it_log_pending TYPE ty_log_a_tab.

ENDCLASS.


CLASS zcl_reing_ca_orphan_rec IMPLEMENTATION.

  METHOD constructor.
    mo_verify = COND #( WHEN io_verify IS BOUND THEN io_verify
                         ELSE NEW zcl_reing_ca_orphan_stub( ) ).
  ENDMETHOD.

METHOD if_oo_adt_classrun~main.
    " Direct debug/test from ADT without the APJ framework. Always print
    " at least a start/end marker (user request, F5) so a console run
    " confirms the class actually executed, even on a fully "quiet"
    " successful cycle (no orphans, reschedule OK) where add_log()
    " previously had nothing to append.
    out->write( |[Orphan Recovery] cycle started -- { utclong_current( ) }| ). "#EC NOTEXT

    TRY.
        run_recovery_cycle( ).
      CATCH cx_apj_rt_content INTO DATA(lx).
        out->write( |[Orphan Recovery] uncaught error: { lx->get_text( ) }| ). "#EC NOTEXT
    ENDTRY.

    LOOP AT mt_log INTO DATA(lv_line).
      out->write( lv_line ).
    ENDLOOP.

    out->write( |[Orphan Recovery] cycle finished -- { lines( mt_log ) } log entr{ COND #( WHEN lines( mt_log ) = 1 THEN `y` ELSE `ies` ) }.| ). "#EC NOTEXT
  ENDMETHOD.

  METHOD if_apj_dt_exec_object~get_parameters.
    " No design parameters -- the job does not receive a CALC_RUN_ID, it
    " sweeps ALL *_PROC lines of the table on every cycle (BR-1).
    CLEAR et_parameter_def.
  ENDMETHOD.

  METHOD if_apj_rt_exec_object~execute.
    " APJ entry point -- no parameters to parse, delegates directly.
    TRY.
        run_recovery_cycle( ).
      CATCH cx_apj_rt_content INTO DATA(lx_error).
        RAISE EXCEPTION lx_error.
    ENDTRY.
  ENDMETHOD.

METHOD run_recovery_cycle.
    " BR-1: orphan detection -- LINE_STATUS LIKE '%_PROC' with heartbeat
    " expired according to ZREING_CA_ORPHAN_TIMEOUT.
    "
    " All fields of ZREING_CA_LINE_A are enumerated explicitly (instead of
    " SELECT *, ONB-001) because is_line/ls_candidate must carry the
    " complete structure: both mo_verify->exists_bkpf_for_line/
    " exists_storno_for_line (ZIF_REING_CA_ORPHAN_VERIFY contract, F5-03)
    " and decide_recovery() need the full row, so no field can be dropped
    " -- this only removes the ATC "Avoid use of SELECT *" finding, it
    " does not narrow the field list.
    " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-09 --
    " quitado HAS_PC_BREAKDOWN de la lista explicita (columna retirada de
    " ZREING_CA_LINE_A por CA-02). LT_CANDIDATES pasa a tipo explicito
    " TY_LINE_A_TAB (estructura completa ZREING_CA_LINE_A) en vez de la
    " inferencia inline @DATA(...) -- sin esto, el tipo ad-hoc generado
    " por la lista de campos explicita quedaba incompatible con la firma
    " de DECIDE_RECOVERY (que espera ZREING_CA_LINE_A completa).
    DATA(lv_timeout_s) = read_timeout_seconds( ).
    " ADD/SUBTRACTSECS require a materialized "short" TIMESTAMP variable
    " for the TSTMP parameter -- nesting UTCLONG2TSTMP_SHORT's call
    " directly as the actual parameter raises CX_PARAMETER_INVALID_TYPE
    " at runtime (confirmed empirically with an isolated $TMP test): the
    " intermediate functional-call result does not carry the same
    " runtime type info as a materialized variable. Always assign to
    " lv_now_short first.
    DATA(lv_now_short) = cl_abap_tstmp=>utclong2tstmp_short( utclong_current( ) ).
    DATA(lv_cutoff) = cl_abap_tstmp=>subtractsecs(
      tstmp = lv_now_short
      secs  = lv_timeout_s ).

    DATA lt_candidates TYPE ty_line_a_tab.
    SELECT mandt, calc_run_id, line_num,
           ct_uuid, ct_id, lifnr, bp_name, bukrs_prest, mat_uuid, matnr,
           op_type, op_uuid, op_instance_num, parent_op_type, origin_run_id, origin_line_num,
           parent_net_amt, parent_currency, defer_pct, defer_cuota_num, defer_cuota_total,
           defer_from, defer_to, bukrs_recv, country, base_amt, share_pct, share_pais_pct,
           share_comb_pct, calc_amt, bruto_amt, gross_up_amt, tax_amt, net_amt, ct_currency,
           net_local_amt, local_currency, exch_rate, exch_rate_type,
           line_status, sim_message, proc_started_at, proc_heartbeat_at, proc_job_id,
           insumo_check_at, fi_awkey, local_last_changed_at
      FROM zreing_ca_line_a
      WHERE line_status LIKE '%\_PROC' ESCAPE '\'
        AND proc_heartbeat_at < @lv_cutoff
      INTO CORRESPONDING FIELDS OF TABLE @lt_candidates.
    " End Change ID V002 (03.08.2026 | EXT_GONZALCA)

    IF lt_candidates IS INITIAL.
      " BR-5: cycle without orphans -- ends without error. Logged
      " explicitly (user request, F5) so a console run has visible
      " confirmation instead of silent success.
      add_log( |No orphan lines found this cycle (timeout { lv_timeout_s }s).| ). "#EC NOTEXT
      reschedule_self( ).
      RETURN.
    ENDIF.

    " ATC fix (NonLocal DB in loop): resolve which candidates' jobs are
    " still active with ONE bulk call, before entering the per-candidate
    " loop -- instead of calling CL_APJ_RT_API once per candidate inside
    " the loop below.
    DATA(lt_active_jobnames) = resolve_active_jobs( ).

    " ATC fix (NonLocal DB in loop via the former recover_line/insert_log):
    " this loop only decides the outcome per candidate in memory
    " (BR-2/BR-3/BR-4); every DELETE/UPDATE/INSERT happens once, in
    " persist_recovery, AFTER the loop -- same pattern already applied to
    " ZCL_REING_CA_CALC_JOB=>run_pipeline/persist_line.
    DATA lt_to_delete   TYPE ty_line_a_tab.
    DATA lt_to_update   TYPE ty_line_a_tab.
    DATA lt_log_pending TYPE ty_log_a_tab.

    LOOP AT lt_candidates INTO DATA(ls_candidate).
      " BR-2: timeout false positive -- if the job is still active, skip
      " it (the line is left untouched).
      IF line_exists( lt_active_jobnames[ table_line = ls_candidate-proc_job_id ] ).
        add_log( |Line { ls_candidate-calc_run_id }/{ ls_candidate-line_num }: | && "#EC NOTEXT
                 |job { ls_candidate-proc_job_id } still active, skipped (false positive).| ). "#EC NOTEXT
        CONTINUE.
      ENDIF.

      DATA(ls_decision) = decide_recovery( ls_candidate ).
      IF ls_decision-skip = abap_true.
        " *_PROC status not contemplated -- should not happen (BR-1 only
        " selects the 4 known process states); logged and skipped for
        " safety, without touching the line.
        add_log( |Line { ls_candidate-calc_run_id }/{ ls_candidate-line_num }: | && "#EC NOTEXT
                 |status { ls_candidate-line_status } not mapped in Orphan Recovery, skipped.| ). "#EC NOTEXT
        CONTINUE.
      ENDIF.

      IF ls_decision-delete = abap_true.
        APPEND ls_candidate TO lt_to_delete.
        add_log( |Line { ls_candidate-calc_run_id }/{ ls_candidate-line_num }: deleted (orphan CALC_PROC).| ). "#EC NOTEXT
      ELSE.
        DATA(ls_updated) = ls_candidate.
        ls_updated-line_status       = ls_decision-new_status.
        ls_updated-proc_started_at   = space.
        ls_updated-proc_heartbeat_at = space.
        ls_updated-proc_job_id       = space.
        APPEND ls_updated TO lt_to_update.
        add_log( |Line { ls_candidate-calc_run_id }/{ ls_candidate-line_num }: | && "#EC NOTEXT
                 |{ ls_candidate-line_status } -> { ls_decision-new_status } (Orphan Recovery).| ). "#EC NOTEXT
      ENDIF.

      APPEND VALUE zreing_ca_log_a(
        calc_run_id = ls_candidate-calc_run_id
        line_num    = ls_candidate-line_num
        action      = 'ORPHAN_REC'   " Real domain value (F5-H1) -- NOT 'ORPHAN_RECOVERY'.
        status_from = ls_candidate-line_status
        status_to   = COND #( WHEN ls_decision-delete = abap_true THEN '' ELSE ls_decision-new_status )
        created_by  = sy-uname
        created_at  = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
        message     = ls_decision-message ) TO lt_log_pending.
    ENDLOOP.

    persist_recovery(
      it_to_delete   = lt_to_delete
      it_to_update   = lt_to_update
      it_log_pending = lt_log_pending ).

    reschedule_self( ).
  ENDMETHOD.




  METHOD read_timeout_seconds.
    " Direct SELECT FROM tvarvc, and the classic wrapper ZCL_T_TVARVC,
    " are both blocked by Clean Core on this system (confirmed at
    " activation, and again confirmed with a CDS view entity attempt --
    " the restriction applies to the TVARVC object itself, not just to
    " who consumes it). ZI_TvarvcParams (package
    " ZFPS_GROW-RTR-INTERCO_TIER2, classic/non-cloud-restricted) is a
    " released CDS wrapper exposing TVARVC -- consuming a CDS view is a
    " different access layer with its own release contract, unlike a
    " raw table/class reference (F5-H5, amended).
    SELECT SINGLE low FROM zi_tvarvc "zi_tvarvcparams
      WHERE name = @zif_reing_ca_c=>tvarvc_id-orphan_timeout AND type = 'P'
      INTO @DATA(lv_low).
    rv_seconds = COND #( WHEN sy-subrc = 0 AND lv_low IS NOT INITIAL
                          THEN lv_low ELSE 120 ). " default F0-11
  ENDMETHOD.

  METHOD read_interval_seconds.
    SELECT SINGLE low FROM zi_tvarvc "zi_tvarvcparams
      WHERE name = @zif_reing_ca_c=>tvarvc_id-recovery_interval AND type = 'P'
      INTO @DATA(lv_low).
    rv_seconds = COND #( WHEN sy-subrc = 0 AND lv_low IS NOT INITIAL
                          THEN lv_low ELSE 60 ). " default F0-11
  ENDMETHOD.

METHOD reschedule_self.
    " Self-rescheduling: schedules the NEXT one-off execution of this
    " same Job Step, now + ZREING_CA_RECOVERY_INTERVAL seconds. Does not
    " use IS_SCHEDULING_INFO (the framework's native D/W/M periodicity,
    " insufficient for second-level granularity -- confirmed by the
    " Architect against the real TY_SCHEDULING_INFO). TY_START_INFO-
    " timestamp DOES have second-level granularity (TIMESTAMP type).
    DATA(lv_interval_s) = read_interval_seconds( ).
    " See run_recovery_cycle note: ADD requires a materialized "short"
    " TIMESTAMP variable, not a nested UTCLONG2TSTMP_SHORT( ) call.
    DATA(lv_now_short) = cl_abap_tstmp=>utclong2tstmp_short( utclong_current( ) ).
    DATA(lv_next) = cl_abap_tstmp=>add(
      tstmp = lv_now_short
      secs  = lv_interval_s ).

    TRY.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name = zif_reing_ca_c=>apj_job_template-orphan_recovery  " SAJT, manual step (F5-H2)
            iv_job_text          = 'CA Orphan Recovery' "#EC NOTEXT
            is_start_info        = VALUE #( start_immediately = abap_false
                                             timestamp         = lv_next )
          IMPORTING
            ev_jobname           = DATA(lv_jobname)
            ev_jobcount          = DATA(lv_jobcount) ).
        " Logged explicitly (user request, F5) so a successful, orphan-free
        " cycle still leaves visible confirmation that the next run was
        " scheduled, instead of a silent (but successful) no-op.
        add_log( |Rescheduled next Orphan Recovery cycle: job { lv_jobname }/{ lv_jobcount }, | && "#EC NOTEXT
                 |next run in { lv_interval_s }s.| ). "#EC NOTEXT
      CATCH cx_apj_rt INTO DATA(lx_apj).
        " The exception must not escape uncaught (same criterion as
        " F3.2-DD-2 with schedule_calc_job) -- degrade to a log entry. If
        " the SAJT does not exist yet (F5-H2 pending), this cycle simply
        " does not get rescheduled; the user must re-trigger manually
        " until the manual step is done.
        add_log( |Failed to reschedule Orphan Recovery: { lx_apj->get_text( ) }| ). "#EC NOTEXT
    ENDTRY.
  ENDMETHOD.

METHOD add_log.
    APPEND iv_message TO mt_log.
  ENDMETHOD.

METHOD decide_recovery.
    " BR-3/BR-4: rollback according to LINE_STATUS. Pure decision, no DB
    " access (ATC fix) -- persist_recovery executes the DML in bulk.
    CASE is_line-line_status.
      WHEN 'CALC_PROC'.
        " Nothing permanent was created -- delete LINE_A + STEP_A/LPC_A.
        rs_decision-delete  = abap_true.
        rs_decision-message = 'Orphan CALC_PROC: line deleted (timeout rollback)'. "#EC NOTEXT

      WHEN 'SIM_PROC'.
        " Simulation does not generate persistent artifacts -- rollback to CALC.
        rs_decision-new_status = 'CALC'.
        rs_decision-message    = 'Timeout rollback (Orphan Recovery).'. "#EC NOTEXT

      WHEN 'POST_PROC'.
        " Extension point (stub in this phase, F5-03 will complete it).
        rs_decision-new_status = COND #(
          WHEN mo_verify->exists_bkpf_for_line( is_line ) = abap_true THEN 'CONT' ELSE 'LIBD' ).
        rs_decision-message = 'Result via stub ZCL_REING_CA_ORPHAN_STUB -- real verification pending F5-03.'. "#EC NOTEXT

      WHEN 'ANUL_PROC'.
        rs_decision-new_status = COND #(
          WHEN mo_verify->exists_storno_for_line( is_line ) = abap_true THEN 'LIBD' ELSE 'CONT' ).
        rs_decision-message = 'Result via stub ZCL_REING_CA_ORPHAN_STUB -- real verification pending F5-03.'. "#EC NOTEXT

      WHEN OTHERS.
        rs_decision-skip = abap_true.
    ENDCASE.
  ENDMETHOD.
METHOD resolve_active_jobs.
    " ATC fix (NonLocal DB in loop): ONE non-looped bulk call instead of
    " CL_APJ_RT_API=>GET_JOB_DETAILS called once per candidate inside the
    " recovery LOOP. 'ZREING_CA_CALC_JOBT' is currently the only Job
    " Catalog Entry that can leave a line in a *_PROC status with a
    " PROC_JOB_ID (F3.2 Calculate); extend this list if a second JCE is
    " introduced later for Simulate/Post/Anular.
    TRY.
        DATA(lt_jobs) = cl_apj_rt_api=>find_jobs_with_jce( iv_catalog_name = 'ZREING_CA_CALC_JOBT' ).
      CATCH cx_apj_rt.
        " SAJC/SAJT not created yet, or no read authorization -- treat as
        " "no active jobs known" (safe default: candidates proceed to
        " recovery instead of being falsely skipped as still-active).
        RETURN.
    ENDTRY.

    " Active APJ_STATUS values: R (running), S (scheduled), P (released),
    " Y (ready). Everything else (A/C/F/X/U/K/D/W) is considered inactive
    " -- same criterion as before the ATC fix.
    LOOP AT lt_jobs INTO DATA(ls_job) WHERE status CA 'RSPY'.
      APPEND ls_job-jobname TO rt_active_jobnames.
    ENDLOOP.
  ENDMETHOD.
METHOD persist_recovery.
    " ATC fix (NonLocal DB in loop via the former insert_log/recover_line):
    " every DELETE/UPDATE/INSERT executes once here, never inside a loop
    " that iterates candidates. LOG_A is written BEFORE the cascading
    " DELETE of LINE_A (F3.3-DD-2/DD-3 pattern), same order as before the
    " ATC fix.
    IF it_log_pending IS NOT INITIAL.
      DATA(lt_log_pending) = it_log_pending.

      " GROUP BY cannot be combined with FOR ALL ENTRIES in Open SQL --
      " fetch the raw rows instead and compute MAX(log_num) per key in
      " ABAP (confirmed at activation: "GROUP is not allowed here").
      DATA lt_existing_logs TYPE ty_log_a_tab.
      SELECT calc_run_id, line_num, log_num
        FROM zreing_ca_log_a
        FOR ALL ENTRIES IN @lt_log_pending
        WHERE calc_run_id = @lt_log_pending-calc_run_id
          AND line_num    = @lt_log_pending-line_num
        INTO CORRESPONDING FIELDS OF TABLE @lt_existing_logs.

      " Single-pass MAX(log_num) per key (calc_run_id, line_num), no
      " nested LOOP (ATC: "Loops anidados") and no classic AT NEW/ENDAT
      " (deprecated in this ABAP language version): sort descending by
      " log_num, then INSERT into a SORTED table with a UNIQUE key --
      " the first insert per key wins (the highest log_num), later
      " duplicates for the same key are simply rejected by the table.
      SORT lt_existing_logs BY calc_run_id line_num log_num DESCENDING.

      TYPES: BEGIN OF ty_max_log_num,
               calc_run_id TYPE zreing_ca_line_a-calc_run_id,
               line_num    TYPE zreing_ca_line_a-line_num,
               log_num     TYPE zreing_ca_log_a-log_num,
             END OF ty_max_log_num.
      DATA lt_max_log_num TYPE SORTED TABLE OF ty_max_log_num
        WITH UNIQUE KEY calc_run_id line_num.

      LOOP AT lt_existing_logs INTO DATA(ls_existing).
        INSERT VALUE ty_max_log_num(
          calc_run_id = ls_existing-calc_run_id
          line_num    = ls_existing-line_num
          log_num     = ls_existing-log_num ) INTO TABLE lt_max_log_num.
      ENDLOOP.

      LOOP AT lt_log_pending ASSIGNING FIELD-SYMBOL(<ls_log>).
        READ TABLE lt_max_log_num INTO DATA(ls_max)
          WITH TABLE KEY calc_run_id = <ls_log>-calc_run_id line_num = <ls_log>-line_num.
        <ls_log>-log_num = COND #( WHEN sy-subrc = 0 THEN ls_max-log_num + 1 ELSE 1 ).
      ENDLOOP.

      INSERT zreing_ca_log_a FROM TABLE @lt_log_pending.
    ENDIF.

    IF it_to_delete IS NOT INITIAL.
      " DELETE does not support FOR ALL ENTRIES (Open SQL restriction --
      " confirmed at activation: "FOR is invalid here"). Use the mass
      " "DELETE <dbtab> FROM TABLE @itab" form instead, which deletes by
      " primary key and needs a table typed as that db table's row
      " (non-key fields are ignored).
      DATA lt_step_keys TYPE STANDARD TABLE OF zreing_ca_step_a WITH EMPTY KEY.
      DATA lt_lpc_keys  TYPE STANDARD TABLE OF zreing_ca_lpc_a  WITH EMPTY KEY.
      LOOP AT it_to_delete INTO DATA(ls_delete_key).
        APPEND VALUE #( calc_run_id = ls_delete_key-calc_run_id
                         line_num    = ls_delete_key-line_num ) TO lt_step_keys.
        APPEND VALUE #( calc_run_id = ls_delete_key-calc_run_id
                         line_num    = ls_delete_key-line_num ) TO lt_lpc_keys.
      ENDLOOP.

      DELETE zreing_ca_step_a FROM TABLE @lt_step_keys.
      DELETE zreing_ca_lpc_a  FROM TABLE @lt_lpc_keys.
      DELETE zreing_ca_line_a FROM TABLE @it_to_delete.
    ENDIF.

    IF it_to_update IS NOT INITIAL.
      UPDATE zreing_ca_line_a FROM TABLE @it_to_update.
    ENDIF.

    COMMIT WORK.
  ENDMETHOD.
ENDCLASS.

