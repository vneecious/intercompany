*"* use this source file for your ABAP unit test classes
CLASS ltd_orphan_verify DEFINITION FOR TESTING FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_orphan_verify.

    DATA mv_bkpf_exists   TYPE abap_bool.
    DATA mv_storno_exists TYPE abap_bool.

ENDCLASS.

CLASS ltd_orphan_verify IMPLEMENTATION.

  METHOD zif_reing_ca_orphan_verify~exists_bkpf_for_line.
    rv_exists = mv_bkpf_exists.
  ENDMETHOD.

  METHOD zif_reing_ca_orphan_verify~exists_storno_for_line.
    rv_exists = mv_storno_exists.
  ENDMETHOD.

ENDCLASS.


" Forward declaration required: ltcl_orphan_rec is only defined further
" below, but the FRIENDS statement referencing it must appear first.
CLASS ltcl_orphan_rec DEFINITION DEFERRED.

" Grants ltcl_orphan_rec friend access to ZCL_REING_CA_ORPHAN_REC's private
" members (needed for check_job_active( ) in false_positive_job_active,
" scenario 3) -- without this statement the class is NOT a friend just by
" being a local test class; ABAP requires this explicit declaration.
CLASS zcl_reing_ca_orphan_rec DEFINITION LOCAL FRIENDS ltcl_orphan_rec.

CLASS ltcl_orphan_rec DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.

  PRIVATE SECTION.
    TYPES lty_line_a_tab TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    TYPES lty_log_a_tab  TYPE STANDARD TABLE OF zreing_ca_log_a  WITH EMPTY KEY.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    DATA mo_verify_dbl TYPE REF TO ltd_orphan_verify.
    DATA mo_cut        TYPE REF TO zcl_reing_ca_orphan_rec.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS calc_proc_orphan_deleted FOR TESTING RAISING cx_static_check.
    METHODS sim_proc_orphan_rollback FOR TESTING RAISING cx_static_check.
    METHODS false_positive_job_active FOR TESTING RAISING cx_static_check.
    METHODS post_proc_anul_proc_stub FOR TESTING RAISING cx_static_check.
    METHODS cycle_no_orphans_no_error FOR TESTING RAISING cx_static_check.
    METHODS multi_orphans_same_run FOR TESTING RAISING cx_static_check.
    METHODS concurrency_no_side_effects FOR TESTING RAISING cx_static_check.

    METHODS old_heartbeat
      IMPORTING iv_seconds_ago    TYPE i DEFAULT 300
      RETURNING VALUE(rv_result) TYPE zreing_ca_line_a-proc_heartbeat_at.

ENDCLASS.


CLASS ltcl_orphan_rec IMPLEMENTATION.

  METHOD class_setup.
    " TVARVC removed from the dependency list (ERR-006): production code
    " no longer selects TVARVC directly (F5-H5 -- now reads via the
    " ZI_TVARVCPARAMS CDS view instead), and cl_osql_test_environment
    " does not permit creating a test double for TVARVC at all
    " ("Creation of test doubles is not permitted for TVARVC") -- same
    " family of Clean Core restriction, this time on the test-doubling
    " mechanism itself. read_timeout_seconds/read_interval_seconds still
    " fall back to their documented defaults (120s/60s) deterministically
    " in this test run, since ZI_TVARVCPARAMS is queried for real (no
    " matching ZREING_CA_* row expected in this system's TVARVC for the
    " test to accidentally pick up) -- not doubled, but safe and
    " read-only.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZREING_CA_LINE_A' ) ( 'ZREING_CA_LOG_A' )
        ( 'ZREING_CA_STEP_A' ) ( 'ZREING_CA_LPC_A' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    go_env->clear_doubles( ).
    mo_verify_dbl = NEW ltd_orphan_verify( ).
    mo_cut = NEW zcl_reing_ca_orphan_rec( io_verify = mo_verify_dbl ).
    " No TVARVC test data inserted on purpose -- read_timeout_seconds/
    " read_interval_seconds must fall back to the documented defaults
    " (120s/60s, F0-11) when the doubled table is empty; this is
    " deterministic and does not depend on knowing the exact literal
    " value behind ZIF_REING_CA_C=>tvarvc_id at Developer time.
  ENDMETHOD.

  METHOD teardown.
    go_env->clear_doubles( ).
  ENDMETHOD.

  METHOD old_heartbeat.
    " Comfortably older than the 120s default timeout fallback.
    " Materialize the "short" timestamp first -- nesting
    " UTCLONG2TSTMP_SHORT( ) directly as SUBTRACTSECS' actual parameter
    " raises CX_PARAMETER_INVALID_TYPE at runtime (confirmed empirically
    " with an isolated $TMP test; see run_recovery_cycle's note in
    " /source/main).
    DATA(lv_now_short) = cl_abap_tstmp=>utclong2tstmp_short( utclong_current( ) ).
    rv_result = cl_abap_tstmp=>subtractsecs(
      tstmp = lv_now_short
      secs  = iv_seconds_ago ).
  ENDMETHOD.

METHOD calc_proc_orphan_deleted.
    " Escenario 1: CALC_PROC huerfana -> se elimina LINE_A/STEP_A/LPC_A,
    " LOG_A se graba ANTES del DELETE en cascada.
    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUN0001' line_num = 1 line_status = 'CALC_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space ) ) ).

    mo_cut->run_recovery_cycle( ).

    SELECT SINGLE COUNT(*) FROM zreing_ca_line_a
      WHERE calc_run_id = 'RUN0001' AND line_num = 1
      INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 0
      msg = 'CALC_PROC orphan must be physically deleted' ).

    " Not SELECT SINGLE (ATC: possibly not unique -- LOG_A can hold more
    " than one row per calc_run_id/line_num as log_num accumulates);
    " take the most recent entry explicitly instead.
    SELECT action FROM zreing_ca_log_a
      WHERE calc_run_id = 'RUN0001' AND line_num = 1
      ORDER BY log_num DESCENDING
      INTO TABLE @DATA(lt_action)
      UP TO 1 ROWS.
    DATA(lv_action) = VALUE #( lt_action[ 1 ]-action OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = lv_action exp = 'ORPHAN_REC'
      msg = 'LOG_A must be written before the cascading delete, with action ORPHAN_REC' ).
  ENDMETHOD.

  METHOD sim_proc_orphan_rollback.
    " Escenario 2: SIM_PROC huerfana -> rollback a CALC.
    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUN0002' line_num = 1 line_status = 'SIM_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space ) ) ).

    mo_cut->run_recovery_cycle( ).

    SELECT SINGLE line_status FROM zreing_ca_line_a
      WHERE calc_run_id = 'RUN0002' AND line_num = 1
      INTO @DATA(lv_status).
    cl_abap_unit_assert=>assert_equals( act = lv_status exp = 'CALC'
      msg = 'SIM_PROC orphan must roll back to CALC' ).
  ENDMETHOD.

METHOD false_positive_job_active.
    " Escenario 3: falso positivo de timeout. Cobertura parcial (ver
    " nota de cabecera del include): tras el ATC fix (2026-07-15,
    " ZMELI_CLEAN_CORE_V3), RESOLVE_ACTIVE_JOBS trae en bulk (sin loop)
    " los jobs REALMENTE activos del JCE ZREING_CA_CALC_JOBT; un job_id
    " que no existe en ese catalogo nunca aparece en el resultado, por lo
    " que la linea se recupera con normalidad (ver otros escenarios, que
    " usan PROC_JOB_ID = space y sí se recuperan). Esta prueba verifica
    " directamente que RESOLVE_ACTIVE_JOBS no marca como activo un job
    " inexistente. No prueba el camino "job realmente activo" (requeriria
    " un job en ejecucion real al momento del test, no reproducible de
    " forma determinista en ABAP Unit) -- documentado como gap de
    " cobertura para el Reviewer, no omitido en silencio.
    DATA(lt_active) = mo_cut->resolve_active_jobs( ).
    cl_abap_unit_assert=>assert_false(
      act = xsdbool( line_exists( lt_active[ table_line = 'ZZ_NOT_A_REAL_JOB0001' ] ) )
      msg = 'A job that does not exist must never be treated as active' ).
  ENDMETHOD.

METHOD post_proc_anul_proc_stub.
    " Escenario 4: POST_PROC/ANUL_PROC con heartbeat vencido -> se invoca
    " el punto de extension sin romper el flujo; el resultado queda
    " documentado como proveniente del stub.
    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUN0004' line_num = 1 line_status = 'POST_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space )
      ( calc_run_id = 'RUN0004' line_num = 2 line_status = 'ANUL_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space ) ) ).

    mo_verify_dbl->mv_bkpf_exists   = abap_false.
    mo_verify_dbl->mv_storno_exists = abap_false.

    mo_cut->run_recovery_cycle( ).

    SELECT SINGLE line_status FROM zreing_ca_line_a
      WHERE calc_run_id = 'RUN0004' AND line_num = 1
      INTO @DATA(lv_post_status).
    cl_abap_unit_assert=>assert_equals( act = lv_post_status exp = 'LIBD'
      msg = 'POST_PROC without BKPF (stub) must roll to LIBD' ).

    SELECT SINGLE line_status FROM zreing_ca_line_a
      WHERE calc_run_id = 'RUN0004' AND line_num = 2
      INTO @DATA(lv_anul_status).
    cl_abap_unit_assert=>assert_equals( act = lv_anul_status exp = 'CONT'
      msg = 'ANUL_PROC without storno (stub) must roll to CONT' ).

    " Not SELECT SINGLE (ATC: possibly not unique -- LOG_A can hold more
    " than one row per calc_run_id/line_num as log_num accumulates);
    " take the most recent entry explicitly instead.
    SELECT message FROM zreing_ca_log_a
      WHERE calc_run_id = 'RUN0004' AND line_num = 1
      ORDER BY log_num DESCENDING
      INTO TABLE @DATA(lt_message)
      UP TO 1 ROWS.
    DATA(lv_message) = VALUE #( lt_message[ 1 ]-message OPTIONAL ).
    FIND 'stub' IN lv_message IGNORING CASE MATCH OFFSET DATA(lv_offset).
    cl_abap_unit_assert=>assert_subrc( exp = 0
      msg = 'LOG_A message must explicitly mention that the result came from the stub' ).
  ENDMETHOD.

  METHOD cycle_no_orphans_no_error.
    " Escenario 5: sin huerfanas -> termina sin error y sin ruido de log.
    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUN0005' line_num = 1 line_status = 'CALC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space ) ) ).

    mo_cut->run_recovery_cycle( ).

    SELECT SINGLE COUNT(*) FROM zreing_ca_log_a
      WHERE calc_run_id = 'RUN0005'
      INTO @DATA(lv_log_count).
    cl_abap_unit_assert=>assert_equals( act = lv_log_count exp = 0
      msg = 'A cycle with no *_PROC candidates must not write any LOG_A entry' ).
  ENDMETHOD.

  METHOD multi_orphans_same_run.
    " Escenario 6: multiples huerfanas del mismo CALC_RUN_ID -> todas se
    " procesan, sin duplicar LOG_A.
    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUN0006' line_num = 1 line_status = 'SIM_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space )
      ( calc_run_id = 'RUN0006' line_num = 2 line_status = 'SIM_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space ) ) ).

    mo_cut->run_recovery_cycle( ).

    SELECT COUNT(*) FROM zreing_ca_line_a
      WHERE calc_run_id = 'RUN0006' AND line_status = 'CALC'
      INTO @DATA(lv_rolled_back).
    cl_abap_unit_assert=>assert_equals( act = lv_rolled_back exp = 2
      msg = 'Both orphaned lines of the same run must be rolled back' ).

    SELECT COUNT(*) FROM zreing_ca_log_a
      WHERE calc_run_id = 'RUN0006'
      INTO @DATA(lv_log_count).
    cl_abap_unit_assert=>assert_equals( act = lv_log_count exp = 2
      msg = 'Exactly one LOG_A entry per recovered line, no duplicates' ).
  ENDMETHOD.

  METHOD concurrency_no_side_effects.
    " Escenario 7: proxy de concurrencia con accion RAP normal -- una
    " linea "viva" (line_status <> *_PROC) del mismo run no debe verse
    " afectada por un ciclo de recuperacion sobre otra linea huerfana.
    " No sustituye una prueba de integracion real de lock RAP (fuera de
    " alcance de ABAP Unit) -- documentado explicitamente, no asumido
    " como cobertura completa del escenario.
    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUN0007' line_num = 1 line_status = 'SIM_PROC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space )
      ( calc_run_id = 'RUN0007' line_num = 2 line_status = 'CALC'
        proc_heartbeat_at = old_heartbeat( ) proc_job_id = space ) ) ).

    mo_cut->run_recovery_cycle( ).

    SELECT SINGLE line_status FROM zreing_ca_line_a
      WHERE calc_run_id = 'RUN0007' AND line_num = 2
      INTO @DATA(lv_sibling_status).
    cl_abap_unit_assert=>assert_equals( act = lv_sibling_status exp = 'CALC'
      msg = 'A sibling line not in *_PROC must be left untouched by the recovery cycle' ).
  ENDMETHOD.

ENDCLASS.
