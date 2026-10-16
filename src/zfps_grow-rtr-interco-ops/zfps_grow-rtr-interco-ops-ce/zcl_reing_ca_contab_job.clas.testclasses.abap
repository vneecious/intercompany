" V001 (CC) - AN2 APJ: pure FI gate/log contracts and OSQL log double; no FI/commit.

CLASS ltcl_an2_job DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_job TYPE REF TO zcl_reing_ca_contab_job.
    DATA mt_origins TYPE zcl_reing_ca_an2_regenerator=>tt_origin.
    DATA mt_lines TYPE zif_reing_ca_types=>ty_line_t.
    DATA mt_docs TYPE zcl_reing_contab_engine=>tt_reversal_docs.
    DATA mt_journal TYPE zcl_reing_contab_engine=>tt_journal.
    METHODS setup.
    METHODS fi_complete FOR TESTING.
    METHODS no_fi_skip FOR TESTING.
    METHODS missing_fi_deferred FOR TESTING.
    METHODS wrong_year_deferred FOR TESTING.
    METHODS planned_not_reversed FOR TESTING.
    METHODS partial_docs_deferred FOR TESTING.
    METHODS original_status_guard FOR TESTING.
    METHODS source_log_unchanged FOR TESTING.
    METHODS rollback_clears_seed FOR TESTING.
    METHODS logs_multi_run FOR TESTING RAISING cx_static_check.
    METHODS multi_origin_missing FOR TESTING.
    METHODS multi_origin_reversed FOR TESTING.
ENDCLASS.

CLASS ltcl_an2_job IMPLEMENTATION.
  METHOD setup.
    mo_job = NEW #( ).
    mt_origins = VALUE #( ( origin_run_id = 'RUN-202604' origin_line_num = '0000150' ) ).
    mt_lines = VALUE #( ( calc_run_id = 'RUN-202604' line_num = '0000150' op_type = 'ANT' line_status = 'CONT' ) ).
    mt_docs = VALUE #( ( calc_run_id = 'RUN-202604' line_num = '0000150' bukrs = 'EBA'
      doc_type_code = 'AN1' belnr = '1234567890' gjahr = '2026' status = 'OK' ) ).
    mt_journal = VALUE #( ( companycode = 'EBA' accountingdocument = '1234567890' fiscalyear = '2026' ) ).
  ENDMETHOD.
  METHOD fi_complete.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'ELIGIBLE' ).
  ENDMETHOD.
  METHOD no_fi_skip.
    CLEAR mt_docs.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'SKIP_NO_FI' ).
  ENDMETHOD.
  METHOD missing_fi_deferred.
    CLEAR mt_journal.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'DEFER_FI' ).
  ENDMETHOD.
  METHOD wrong_year_deferred.
    mt_journal[ 1 ]-fiscalyear = '2027'.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'DEFER_FI' ).
  ENDMETHOD.
  METHOD planned_not_reversed.
    mt_journal[ 1 ]-reversedocument = '9999999999'.
    mt_journal[ 1 ]-reversedocumentfiscalyear = '2027'.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'ELIGIBLE' ).
  ENDMETHOD.
  METHOD partial_docs_deferred.
    APPEND VALUE #( BASE mt_docs[ 1 ] bukrs = 'DAB' doc_type_code = 'AN2' ) TO mt_docs.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'DEFER_FI' ).
  ENDMETHOD.
  METHOD original_status_guard.
    mt_lines[ 1 ]-line_status = 'ANUL_PROC'.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'INVALID' ).
  ENDMETHOD.
  METHOD multi_origin_missing.
    " First origin has two visible documents; the next has one missing document.
    APPEND VALUE #( origin_run_id = 'RUN-202605' origin_line_num = '0000150' ) TO mt_origins.
    APPEND VALUE #( BASE mt_lines[ 1 ] calc_run_id = 'RUN-202605' ) TO mt_lines.
    APPEND VALUE #( BASE mt_docs[ 1 ] doc_type_code = 'AN2' bukrs = 'DAB'
      belnr = '2234567890' ) TO mt_docs.
    APPEND VALUE #( BASE mt_docs[ 1 ] calc_run_id = 'RUN-202605'
      belnr = '3234567890' ) TO mt_docs.
    APPEND VALUE #( companycode = 'DAB' accountingdocument = '2234567890'
      fiscalyear = '2026' ) TO mt_journal.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-origin exp = mt_origins[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'ELIGIBLE' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-origin exp = mt_origins[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-outcome exp = 'DEFER_FI' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-result-message
      exp = 'Original FI document is not visible or is reversed' ).
  ENDMETHOD.
  METHOD multi_origin_reversed.
    " First origin has one document; the next has two, with its first already reversed.
    APPEND VALUE #( origin_run_id = 'RUN-202605' origin_line_num = '0000150' ) TO mt_origins.
    APPEND VALUE #( BASE mt_lines[ 1 ] calc_run_id = 'RUN-202605' ) TO mt_lines.
    APPEND VALUE #( BASE mt_docs[ 1 ] calc_run_id = 'RUN-202605'
      belnr = '3234567890' ) TO mt_docs.
    APPEND VALUE #( BASE mt_docs[ 1 ] calc_run_id = 'RUN-202605' doc_type_code = 'AN2'
      bukrs = 'DAB' belnr = '4234567890' ) TO mt_docs.
    APPEND VALUE #( companycode = 'EBA' accountingdocument = '3234567890'
      fiscalyear = '2026' isreversed = abap_true ) TO mt_journal.
    APPEND VALUE #( companycode = 'DAB' accountingdocument = '4234567890'
      fiscalyear = '2026' ) TO mt_journal.
    DATA(lt_rows) = mo_job->classify_ant_fi( it_origins = mt_origins it_lines = mt_lines
      it_docs = mt_docs it_journal = mt_journal ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-origin exp = mt_origins[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'ELIGIBLE' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-origin exp = mt_origins[ 2 ] ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-outcome exp = 'DEFER_FI' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-result-message
      exp = 'Original FI document is not visible or is reversed' ).
  ENDMETHOD.
  METHOD source_log_unchanged.
    DATA(lt_rows) = VALUE zcl_reing_ca_an2_regenerator=>tt_batch_row(
      ( origin = mt_origins[ 1 ] outcome = 'READY_CALC'
        result = VALUE #( calc_run_id = 'RUN-202610' line_num = '0000167' success = abap_true ) ) ).
    DATA(lt_logs) = mo_job->build_an2_logs( it_rows = lt_rows it_lines = mt_lines ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_logs ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_logs[ 1 ]-action exp = 'POST' ).
    cl_abap_unit_assert=>assert_equals( act = lt_logs[ 1 ]-status_from exp = 'CONT' ).
    cl_abap_unit_assert=>assert_equals( act = lt_logs[ 1 ]-status_to exp = 'CONT' ).
    cl_abap_unit_assert=>assert_equals( act = lt_logs[ 2 ]-calc_run_id exp = 'RUN-202610' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-line_status exp = 'CONT' ).
  ENDMETHOD.
  METHOD rollback_clears_seed.
    DATA(lt_rows) = VALUE zcl_reing_ca_an2_regenerator=>tt_batch_row(
      ( origin = mt_origins[ 1 ] outcome = 'READY_CALC'
        result = VALUE #( calc_run_id = 'RUN-202610' line_num = '0000167' success = abap_true ) ) ).
    mo_job->normalize_failed_batch( EXPORTING it_eligible = mt_origins iv_message = 'Pipeline incomplete'
      CHANGING ct_rows = lt_rows ).
    cl_abap_unit_assert=>assert_false( lt_rows[ 1 ]-result-success ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-result-calc_run_id ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-result-line_num ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-outcome exp = 'TECH_FAILED' ).
  ENDMETHOD.
  METHOD logs_multi_run.
    DATA(lo_env) = cl_osql_test_environment=>create( VALUE #( ( 'ZREING_CA_LOG_A' ) ) ).
    TRY.
        DATA(lt_before) = VALUE zif_reing_ca_types=>ty_log_t(
          ( mandt = sy-mandt calc_run_id = 'RUN-202604' line_num = '0000150' log_num = '0012' )
          ( mandt = sy-mandt calc_run_id = 'RUN-202610' line_num = '0000150' log_num = '0003' ) ).
        lo_env->insert_test_data( lt_before ).
        mo_job->write_an2_logs( VALUE #(
          ( calc_run_id = 'RUN-202604' line_num = '0000150' )
          ( calc_run_id = 'RUN-202610' line_num = '0000150' )
          ( calc_run_id = 'RUN-202604' line_num = '0000150' ) ) ).
        SELECT calc_run_id, line_num, log_num FROM zreing_ca_log_a
          WHERE ( calc_run_id = 'RUN-202604' OR calc_run_id = 'RUN-202610' )
            AND line_num = '0000150' INTO TABLE @DATA(lt_after).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_after ) exp = 5 ).
        cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_after[
          calc_run_id = 'RUN-202604' line_num = '0000150' log_num = '0014' ] ) ) ).
        cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_after[
          calc_run_id = 'RUN-202610' line_num = '0000150' log_num = '0004' ] ) ) ).
      CLEANUP.
        lo_env->destroy( ).
    ENDTRY.
    lo_env->destroy( ).
  ENDMETHOD.
ENDCLASS.
