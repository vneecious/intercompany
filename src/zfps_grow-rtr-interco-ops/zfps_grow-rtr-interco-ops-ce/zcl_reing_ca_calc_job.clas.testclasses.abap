" V001 (CC) - Private RUN lock lifecycle and commit order, no live locks/commits/FI.
CLASS ltcl_an2_calc DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS conflict_no_snapshot FOR TESTING.
    METHODS commit_after_totals FOR TESTING RAISING cx_static_check.
    METHODS rollback_keeps_lock FOR TESTING.
    METHODS owned_lock_rejects_reentry FOR TESTING RAISING cx_static_check.
    METHODS counts_failure_terminalized FOR TESTING.
    METHODS empty_snapshot_releases FOR TESTING RAISING cx_static_check.
ENDCLASS.
CLASS ltcl_an2_calc IMPLEMENTATION.
  METHOD conflict_no_snapshot.
    TEST-INJECTION an2_calc_run.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_totals.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_commit.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_technical_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_terminate.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_cleanup_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_dequeue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_enqueue.
      RAISE EXCEPTION TYPE cx_abap_foreign_lock.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_snapshot.
      cl_abap_unit_assert=>fail( 'Snapshot reached after lock conflict' ).
    END-TEST-INJECTION.
    DATA(lo_job) = NEW zcl_reing_ca_calc_job( ).
    TRY.
        lo_job->execute( 'RUN-202610' ).
        cl_abap_unit_assert=>fail( 'Lock conflict must be visible' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( lo_job->mv_locked_run ).
  ENDMETHOD.
  METHOD commit_after_totals.
    TEST-INJECTION an2_calc_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_technical_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_terminate.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_cleanup_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_enqueue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_snapshot.
      lt_lines = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' ) ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_run.
      APPEND 'PIPELINE' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_totals.
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
      APPEND 'COUNTS' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_commit.
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mt_log[ table_line = 'COUNTS' ] ) ) ).
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
      APPEND 'COMMIT' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_dequeue.
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mt_log[ table_line = 'COMMIT' ] ) ) ).
    END-TEST-INJECTION.
    DATA(lo_job) = NEW zcl_reing_ca_calc_job( ).
    lo_job->execute( 'RUN-202610' ).
    cl_abap_unit_assert=>assert_initial( lo_job->mv_locked_run ).
  ENDMETHOD.
  METHOD rollback_keeps_lock.
    TEST-INJECTION an2_calc_totals.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_commit.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_technical_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_terminate.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_enqueue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_snapshot.
      lt_lines = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' ) ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_run.
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_rollback.
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
      APPEND 'ROLLBACK' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_cleanup_rollback.
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_dequeue.
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mt_log[ table_line = 'ROLLBACK' ] ) ) ).
    END-TEST-INJECTION.
    DATA(lo_job) = NEW zcl_reing_ca_calc_job( ).
    TRY.
        lo_job->execute( 'RUN-202610' ).
        cl_abap_unit_assert=>fail( 'Pipeline failure must be visible' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( lo_job->mv_locked_run ).
  ENDMETHOD.
  METHOD owned_lock_rejects_reentry.
    TEST-INJECTION an2_calc_snapshot.
      CLEAR lt_lines.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_run.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_totals.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_commit.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_technical_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_terminate.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_cleanup_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_enqueue.
      cl_abap_unit_assert=>assert_initial( mv_locked_run ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_dequeue.
    END-TEST-INJECTION.
    DATA(lo_job) = NEW zcl_reing_ca_calc_job( ).
    lo_job->lock_run( 'RUN-202610' ).
    TRY.
        lo_job->lock_run( 'RUN-202610' ).
        cl_abap_unit_assert=>fail( 'Repeated acquisition must be rejected' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = lo_job->mv_locked_run exp = 'RUN-202610' ).
    DATA(lv_release) = lo_job->release_run( ).
    cl_abap_unit_assert=>assert_initial( lv_release ).
  ENDMETHOD.
  METHOD counts_failure_terminalized.
    TEST-INJECTION an2_calc_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_enqueue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_run.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_commit.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_snapshot.
      lt_lines = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' ) ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_totals.
      RAISE EXCEPTION TYPE cx_sy_conversion_overflow.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_technical_rollback.
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
      APPEND 'TECH_ROLLBACK' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_terminate.
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mt_log[ table_line = 'TECH_ROLLBACK' ] ) ) ).
      " Replace the entire terminalization, including all of its SQL and commit.
      APPEND 'TERMINAL_SIMULATED' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_cleanup_rollback.
      cl_abap_unit_assert=>assert_not_initial( mv_locked_run ).
      APPEND 'CLEANUP_ROLLBACK' TO mt_log.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_dequeue.
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mt_log[ table_line = 'TERMINAL_SIMULATED' ] ) ) ).
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mt_log[ table_line = 'CLEANUP_ROLLBACK' ] ) ) ).
      APPEND 'RELEASE' TO mt_log.
    END-TEST-INJECTION.
    DATA(lo_job) = NEW zcl_reing_ca_calc_job( ).
    TRY.
        lo_job->execute( 'RUN-202610' ).
        cl_abap_unit_assert=>fail( 'Counts failure must be visible' ).
      CATCH cx_apj_rt_content.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( lo_job->mv_locked_run ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lo_job->mt_log[ table_line = 'RELEASE' ] ) ) ).
  ENDMETHOD.
  METHOD empty_snapshot_releases.
    TEST-INJECTION an2_calc_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_enqueue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_technical_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_terminate.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_cleanup_rollback.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_snapshot.
      CLEAR lt_lines.
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_run.
      cl_abap_unit_assert=>fail( 'Pipeline reached after empty snapshot' ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_totals.
      cl_abap_unit_assert=>fail( 'Counts reached after empty snapshot' ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_commit.
      cl_abap_unit_assert=>fail( 'Commit reached after empty snapshot' ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_calc_dequeue.
      APPEND 'EMPTY_RELEASE' TO mt_log.
    END-TEST-INJECTION.
    DATA(lo_job) = NEW zcl_reing_ca_calc_job( ).
    lo_job->execute( 'RUN-202610' ).
    cl_abap_unit_assert=>assert_initial( lo_job->mv_locked_run ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lo_job->mt_log[ table_line = 'EMPTY_RELEASE' ] ) ) ).
  ENDMETHOD.
ENDCLASS.
