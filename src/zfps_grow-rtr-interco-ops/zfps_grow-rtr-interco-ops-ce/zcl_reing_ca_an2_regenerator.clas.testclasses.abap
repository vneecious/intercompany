" V001 (CC) - AN2 APJ: harmless pure/lock-seam tests, not yet executed.

CLASS ltcl_an2_bridge DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA ms_ant TYPE zreing_ca_line_a.
    DATA mt_options TYPE zcl_reing_ca_an2_regenerator=>tt_option.
    METHODS setup.
    METHODS exact_child FOR TESTING.
    METHODS ambiguous_legacy FOR TESTING.
    METHODS wrong_parent FOR TESTING.
    METHODS mismatched_instance FOR TESTING.
    METHODS duplicate_origin FOR TESTING.
    METHODS context_closed FOR TESTING.
    METHODS partial_lock_failure FOR TESTING.
    METHODS incomplete_pipeline FOR TESTING.
    METHODS foreign_lpc FOR TESTING.
    METHODS duplicate_step FOR TESTING.
    METHODS rejected_header_not_owned FOR TESTING.
    METHODS wildcard_origin_rejected FOR TESTING.
    METHODS unopened_context_rejected FOR TESTING.
ENDCLASS.

CLASS ltcl_an2_bridge IMPLEMENTATION.
  METHOD setup.
    ms_ant = VALUE #( calc_run_id = 'RUN-202604' line_num = '0000150'
      ct_uuid = CONV #( '11' ) mat_uuid = CONV #( '22' ) op_uuid = CONV #( '33' )
      op_type = 'ANT' op_instance_num = '003' bukrs_recv = 'EBA' ).
    mt_options = VALUE #(
      ( ct_uuid = ms_ant-ct_uuid mat_uuid = ms_ant-mat_uuid op_uuid = ms_ant-op_uuid
        op_type = 'ANT' op_instance_num = '003' )
      ( ct_uuid = ms_ant-ct_uuid mat_uuid = ms_ant-mat_uuid op_uuid = CONV #( '44' )
        op_type = 'AN2' op_instance_num = '003' parent_instance_id = ms_ant-op_uuid ) ).
  ENDMETHOD.
  METHOD exact_child.
    DATA(ls_option) = zcl_reing_ca_an2_regenerator=>pick_an2_option( is_ant = ms_ant it_options = mt_options ).
    cl_abap_unit_assert=>assert_equals( act = ls_option-op_uuid exp = mt_options[ 2 ]-op_uuid ).
    cl_abap_unit_assert=>assert_equals( act = ls_option-op_instance_num exp = '003' ).
  ENDMETHOD.
  METHOD ambiguous_legacy.
    CLEAR mt_options[ 2 ]-parent_instance_id.
    APPEND VALUE #( BASE mt_options[ 2 ] op_uuid = CONV #( '55' ) ) TO mt_options.
    cl_abap_unit_assert=>assert_initial(
      zcl_reing_ca_an2_regenerator=>pick_an2_option( is_ant = ms_ant it_options = mt_options ) ).
  ENDMETHOD.
  METHOD wrong_parent.
    mt_options[ 2 ]-parent_instance_id = CONV #( '99' ).
    cl_abap_unit_assert=>assert_initial(
      zcl_reing_ca_an2_regenerator=>pick_an2_option( is_ant = ms_ant it_options = mt_options ) ).
  ENDMETHOD.
  METHOD mismatched_instance.
    ms_ant-op_instance_num = '002'.
    cl_abap_unit_assert=>assert_initial(
      zcl_reing_ca_an2_regenerator=>pick_an2_option( is_ant = ms_ant it_options = mt_options ) ).
  ENDMETHOD.
  METHOD duplicate_origin.
    DATA(lo_context) = zcl_reing_ca_an2_regenerator=>open_context( VALUE #(
      ( origin_run_id = 'RUN-202604' origin_line_num = '0000150' )
      ( origin_run_id = 'RUN-202604' origin_line_num = '0000150' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( lo_context->get_error( ) ).
    cl_abap_unit_assert=>assert_initial( lo_context->mt_owned_runs ).
  ENDMETHOD.
  METHOD context_closed.
    TEST-INJECTION an2_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_enqueue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_dequeue.
    END-TEST-INJECTION.
    DATA(lt_origins) = VALUE zcl_reing_ca_an2_regenerator=>tt_origin(
      ( origin_run_id = 'RUN-202604' origin_line_num = '0000150' ) ).
    DATA(lo_context) = zcl_reing_ca_an2_regenerator=>open_context( lt_origins ).
    cl_abap_unit_assert=>assert_initial( lo_context->get_error( ) ).
    cl_abap_unit_assert=>assert_not_initial( lo_context->mt_owned_runs ).
    DATA(lv_message) = lo_context->close_context( ).
    cl_abap_unit_assert=>assert_initial( lv_message ).
    cl_abap_unit_assert=>assert_initial( lo_context->mt_owned_runs ).
    DATA(ls_result) = lo_context->regenerate_many( lt_origins ).
    cl_abap_unit_assert=>assert_true( ls_result-failed ).
    cl_abap_unit_assert=>assert_initial( ls_result-rows ).
  ENDMETHOD.
  METHOD partial_lock_failure.
    TEST-INJECTION an2_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_enqueue.
      IF lines( ro_context->mt_owned_runs ) = 1.
        RAISE EXCEPTION TYPE cx_abap_foreign_lock.
      ENDIF.
    END-TEST-INJECTION.
    TEST-INJECTION an2_dequeue.
    END-TEST-INJECTION.
    DATA(lo_context) = zcl_reing_ca_an2_regenerator=>open_context( VALUE #(
      ( origin_run_id = 'RUN-202601' origin_line_num = '0000001' )
      ( origin_run_id = 'RUN-202602' origin_line_num = '0000002' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( lo_context->get_error( ) ).
    cl_abap_unit_assert=>assert_initial( lo_context->mt_owned_runs ).
    cl_abap_unit_assert=>assert_false( lo_context->mv_active ).
  ENDMETHOD.
  METHOD incomplete_pipeline.
    DATA(lt_seeds) = VALUE zif_reing_ca_types=>ty_line_t(
      ( calc_run_id = 'RUN-202610' line_num = '0000150' )
      ( calc_run_id = 'RUN-202610' line_num = '0000167' ) ).
    DATA(ls_result) = VALUE zif_reing_ca_types=>ty_pipeline_result(
      lines = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' line_status = 'CALC' ) ) ).
    cl_abap_unit_assert=>assert_not_initial(
      zcl_reing_ca_an2_regenerator=>audit_result( it_seeds = lt_seeds is_result = ls_result ) ).
  ENDMETHOD.
  METHOD foreign_lpc.
    DATA(lt_seeds) = VALUE zif_reing_ca_types=>ty_line_t(
      ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' ) ).
    DATA(ls_result) = VALUE zif_reing_ca_types=>ty_pipeline_result(
      lines = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' line_status = 'CALC' ) )
      line_pc = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000167' pc_seq = '001' ) ) ).
    cl_abap_unit_assert=>assert_not_initial(
      zcl_reing_ca_an2_regenerator=>audit_result( it_seeds = lt_seeds is_result = ls_result ) ).
  ENDMETHOD.
  METHOD duplicate_step.
    DATA(lt_seeds) = VALUE zif_reing_ca_types=>ty_line_t(
      ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' ) ).
    DATA(ls_result) = VALUE zif_reing_ca_types=>ty_pipeline_result(
      lines = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' op_type = 'AN2' line_status = 'CALC' ) )
      steps = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' step_num = '01' seq = '01' )
                      ( calc_run_id = 'RUN-202610' line_num = '0000150' step_num = '01' seq = '01' ) ) ).
    cl_abap_unit_assert=>assert_not_initial(
      zcl_reing_ca_an2_regenerator=>audit_result( it_seeds = lt_seeds is_result = ls_result ) ).
  ENDMETHOD.
  METHOD rejected_header_not_owned.
    DATA(lo_env) = cl_osql_test_environment=>create( VALUE #( ( 'ZREING_CA_RUN_A' ) ) ).
    TRY.
        TEST-INJECTION an2_insert_run.
          lv_inserted = abap_false.
        END-TEST-INJECTION.
        DATA(lv_created) = zcl_reing_ca_an2_regenerator=>ensure_batch_run(
          iv_calc_run_id = 'RUN-202610' iv_year = '2026' iv_period = '10' ).
        cl_abap_unit_assert=>assert_false( lv_created ).
      CLEANUP.
        lo_env->destroy( ).
    ENDTRY.
    lo_env->destroy( ).
  ENDMETHOD.
  METHOD wildcard_origin_rejected.
    DATA(lo_context) = zcl_reing_ca_an2_regenerator=>open_context( VALUE #(
      ( origin_run_id = 'RUN-*' origin_line_num = '0000150' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( lo_context->get_error( ) ).
    cl_abap_unit_assert=>assert_initial( lo_context->mt_owned_runs ).
  ENDMETHOD.
  METHOD unopened_context_rejected.
    DATA(lo_context) = NEW zcl_reing_ca_an2_regenerator( ).
    cl_abap_unit_assert=>assert_not_initial( lo_context->get_error( ) ).
    DATA(ls_result) = lo_context->regenerate_many( VALUE #(
      ( origin_run_id = 'RUN-202604' origin_line_num = '0000150' ) ) ).
    cl_abap_unit_assert=>assert_true( ls_result-failed ).
    cl_abap_unit_assert=>assert_initial( ls_result-rows ).
    cl_abap_unit_assert=>assert_initial( lo_context->mt_owned_runs ).
    cl_abap_unit_assert=>assert_false( lo_context->mv_used ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_an2_sql DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA ms_ant TYPE zreing_ca_line_a.
    DATA mt_options TYPE STANDARD TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.
    METHODS setup.
    METHODS batch_snapshot_options FOR TESTING.
ENDCLASS.

CLASS ltcl_an2_sql IMPLEMENTATION.
  METHOD setup.
    ms_ant = VALUE #( calc_run_id = 'RUN-202604' line_num = '0000150'
      ct_uuid = CONV #( '11' ) mat_uuid = CONV #( '22' ) op_uuid = CONV #( '33' )
      op_type = 'ANT' op_instance_num = '003' bukrs_recv = 'EBA' ).
    mt_options = VALUE #(
      ( ct_uuid = ms_ant-ct_uuid mat_uuid = ms_ant-mat_uuid op_uuid = ms_ant-op_uuid
        op_type = 'ANT' op_instance_num = '003' )
      ( ct_uuid = ms_ant-ct_uuid mat_uuid = ms_ant-mat_uuid op_uuid = CONV #( '44' )
        op_type = 'AN2' op_instance_num = '003' parent_instance_id = ms_ant-op_uuid ) ).
  ENDMETHOD.
  METHOD batch_snapshot_options.
    " V001 (CC) - AN2 APJ: exercise the production lookup using isolated SQL doubles.
    TEST-INJECTION an2_lock_factory.
    END-TEST-INJECTION.
    TEST-INJECTION an2_enqueue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_dequeue.
    END-TEST-INJECTION.
    TEST-INJECTION an2_insert_run.
      cl_abap_unit_assert=>fail( msg = 'Unexpected batch RUN creation' ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_seed_insert.
      cl_abap_unit_assert=>fail( msg = 'Unexpected AN2 seed creation' ).
    END-TEST-INJECTION.
    TEST-INJECTION an2_batch_pipeline.
      cl_abap_unit_assert=>fail( msg = 'Unexpected AN2 pipeline execution' ).
    END-TEST-INJECTION.
    DATA(lo_env) = cl_osql_test_environment=>create(
      VALUE #( ( 'ZREING_CA_LINE_A' ) ( 'ZREING_CT2_OPT_A' ) ( 'ZREING_CA_RUN_A' )
               ( 'ZREING_CA_LPC_A' ) ( 'ZREING_CA_STEP_A' ) ) ).
    DATA(lt_origins) = VALUE zcl_reing_ca_an2_regenerator=>tt_origin(
      ( origin_run_id = ms_ant-calc_run_id origin_line_num = '0000150' )
      ( origin_run_id = ms_ant-calc_run_id origin_line_num = '0000151' )
      ( origin_run_id = ms_ant-calc_run_id origin_line_num = '0000152' ) ).
    DATA(lo_context) = zcl_reing_ca_an2_regenerator=>open_context( lt_origins ).
    TRY.
        cl_abap_unit_assert=>assert_initial( lo_context->get_error( ) ).
        DATA lt_lines TYPE zif_reing_ca_types=>ty_line_t.
        APPEND VALUE #( BASE ms_ant mandt = sy-mandt line_num = '0000150' line_status = 'CONT' ) TO lt_lines.
        APPEND VALUE #( BASE ms_ant mandt = sy-mandt line_num = '0000151' line_status = 'CONT' ) TO lt_lines.
        APPEND VALUE #( BASE ms_ant mandt = sy-mandt calc_run_id = 'RUN-202605' line_num = '0000201'
          op_type = 'AN2' op_uuid = mt_options[ 2 ]-op_uuid parent_op_type = 'ANT'
          origin_run_id = ms_ant-calc_run_id origin_line_num = '0000150' line_status = 'CALC' ) TO lt_lines.
        APPEND VALUE #( BASE ms_ant mandt = sy-mandt calc_run_id = 'RUN-202609' line_num = '0000202'
          op_type = 'AN2' op_uuid = mt_options[ 2 ]-op_uuid parent_op_type = 'ANT'
          origin_run_id = ms_ant-calc_run_id origin_line_num = '0000151' line_status = 'CALC' ) TO lt_lines.
        DATA lt_ct TYPE STANDARD TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.
        lt_ct = CORRESPONDING #( mt_options ).
        LOOP AT lt_ct ASSIGNING FIELD-SYMBOL(<ls_ct>).
          <ls_ct>-mandt = sy-mandt.
        ENDLOOP.
        lo_env->insert_test_data( lt_lines ).
        lo_env->insert_test_data( lt_ct ).
        DATA(ls_result) = lo_context->regenerate_many( lt_origins ).
        cl_abap_unit_assert=>assert_false( ls_result-failed ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-rows ) exp = 3 ).
        READ TABLE ls_result-rows INTO DATA(ls_first)
          WITH KEY origin-origin_run_id = ms_ant-calc_run_id origin-origin_line_num = '0000150'.
        cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 0 ).
        cl_abap_unit_assert=>assert_equals( act = ls_first-outcome exp = 'EXISTS_CALC' ).
        cl_abap_unit_assert=>assert_equals( act = ls_first-result-calc_run_id exp = 'RUN-202605' ).
        READ TABLE ls_result-rows INTO DATA(ls_second)
          WITH KEY origin-origin_run_id = ms_ant-calc_run_id origin-origin_line_num = '0000151'.
        cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 0 ).
        cl_abap_unit_assert=>assert_equals( act = ls_second-outcome exp = 'EXISTS_CALC' ).
        cl_abap_unit_assert=>assert_equals( act = ls_second-result-calc_run_id exp = 'RUN-202609' ).
        READ TABLE ls_result-rows INTO DATA(ls_missing)
          WITH KEY origin-origin_run_id = ms_ant-calc_run_id origin-origin_line_num = '0000152'.
        cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 0 ).
        cl_abap_unit_assert=>assert_equals( act = ls_missing-outcome exp = 'INVALID' ).
      CLEANUP.
        DATA(lv_cleanup_release) = lo_context->close_context( ).
        lo_env->destroy( ).
    ENDTRY.
    DATA(lv_release) = lo_context->close_context( ).
    lo_env->destroy( ).
    cl_abap_unit_assert=>assert_initial( lv_release ).
  ENDMETHOD.
ENDCLASS.
