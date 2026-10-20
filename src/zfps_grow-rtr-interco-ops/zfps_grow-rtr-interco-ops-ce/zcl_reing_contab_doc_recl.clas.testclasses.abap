CLASS ltcl_cebe_grouping DEFINITION DEFERRED.
CLASS zcl_reing_contab_doc_recl DEFINITION LOCAL FRIENDS ltcl_cebe_grouping.
" V001 (CC) - CB-03: SQL doubles and an injected poster isolate every test.
CLASS lcl_cb03_recl_probe DEFINITION INHERITING FROM zcl_reing_contab_doc_recl.
  PUBLIC SECTION.
    METHODS enable_nominal.
    METHODS build RETURNING VALUE(rt_items) TYPE zif_reing_contab_types=>ty_doc_item_t.
    METHODS native_line RETURNING VALUE(rs_line) TYPE zreing_ca_line_a.
    METHODS prior_docs RETURNING VALUE(rt_docs) TYPE zif_reing_contab_types=>ty_step_result_t.
    METHODS pending_error RETURNING VALUE(rv_error) TYPE string.

    " V001 (CC) - #125: supply configured role order without changing the CUT.
    METHODS build_with_roles
      IMPORTING it_roles TYPE zif_reing_contab_types=>ty_role_resolved_t
      RETURNING VALUE(rt_items) TYPE zif_reing_contab_types=>ty_doc_item_t.
ENDCLASS.
CLASS lcl_cb03_recl_probe IMPLEMENTATION.
  METHOD enable_nominal.
    " The DOC pool owns its switch seam. This fixture starts after that boundary.
    " No guard error is cleared and no product flag is changed.
    mv_use_trans = abap_true.
    mv_trans_decimals = 2.
    ms_trans_projection-line = ms_line_a.
    ms_trans_projection-calc_trans_amt = 500.
    ms_trans_projection-bruto_trans_amt = 1000.
  ENDMETHOD.
  METHOD build.
    rt_items = build_items( find_roles_for_step( ) ).
  ENDMETHOD.
  METHOD native_line.
    rs_line = ms_line_a.
  ENDMETHOD.
  METHOD prior_docs.
    rt_docs = mt_prior_docs.
  ENDMETHOD.
  METHOD pending_error.
    rv_error = mv_trans_error.
  ENDMETHOD.

  METHOD build_with_roles.
    rt_items = build_items( it_roles ).
  ENDMETHOD.
ENDCLASS.

CLASS lcl_cb03_poster DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_reing_contab_fi_poster.
    DATA post_calls TYPE i.
    DATA reverse_calls TYPE i.
    DATA failed TYPE abap_bool.
    DATA header TYPE zif_reing_contab_types=>ty_header.
    DATA items TYPE zif_reing_contab_types=>ty_doc_item_t.
    DATA mode TYPE zreing_ca_contab_mode.
ENDCLASS.
CLASS lcl_cb03_poster IMPLEMENTATION.
  METHOD zif_reing_contab_fi_poster~post_document.
    post_calls += 1.
    header = is_header.
    items = it_items.
    mode = iv_mode.
    rs_result = VALUE #( belnr = '9000000011' gjahr = '2026'
                        has_error = failed ).
    IF failed = abap_true.
      rs_result-error_msg = 'Injected poster failure'.
    ENDIF.
  ENDMETHOD.
  METHOD zif_reing_contab_fi_poster~reverse_document.
    reverse_calls += 1.
    cl_abap_unit_assert=>fail( 'No reversal belongs to this test suite' ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_cb03_recl DEFINITION FINAL FOR TESTING
  DURATION MEDIUM RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES tt_master TYPE STANDARD TABLE OF zreing_gl_roles WITH EMPTY KEY.
    TYPES tt_roles TYPE STANDARD TABLE OF zreing_doctype_r WITH EMPTY KEY.
    TYPES tt_accounts TYPE STANDARD TABLE OF zreing_ct2_gl_a WITH EMPTY KEY.
    TYPES tt_flow TYPE STANDARD TABLE OF zreing_docflow_c WITH EMPTY KEY.
    TYPES tt_run TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    TYPES tt_ops TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    TYPES tt_company TYPE STANDARD TABLE OF zi_companycodeaddlinformation WITH EMPTY KEY.
    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.
    CONSTANTS co_ct TYPE zreing_ca_line_a-ct_uuid
      VALUE '000000000000000000000000000000C3'.
    CONSTANTS co_mat TYPE zreing_ca_line_a-mat_uuid
      VALUE '000000000000000000000000000000D3'.
    CONSTANTS co_gl_recl TYPE zreing_ct2_gl_a-gl_uuid
      VALUE '0000000000000000000000000000C301'.
    CONSTANTS co_gl_rree TYPE zreing_ct2_gl_a-gl_uuid
      VALUE '0000000000000000000000000000C302'.
    CONSTANTS co_gl_rrec TYPE zreing_ct2_gl_a-gl_uuid
      VALUE '0000000000000000000000000000C303'.
    CONSTANTS co_target_msg TYPE symsgno VALUE '424'.
    CONSTANTS co_counter_msg TYPE symsgno VALUE '425'.
    CONSTANTS co_equal_msg TYPE symsgno VALUE '426'.
    DATA masters TYPE tt_master.
    DATA roles TYPE tt_roles.
    DATA accounts TYPE tt_accounts.
    DATA flow TYPE tt_flow.
    DATA docs TYPE zif_reing_contab_types=>ty_step_result_t.
    DATA line TYPE zreing_ca_line_a.
    DATA step TYPE zreing_docflow_c.
    DATA cut TYPE REF TO lcl_cb03_recl_probe.
    DATA poster TYPE REF TO lcl_cb03_poster.
    CLASS-METHODS class_setup RAISING cx_static_check.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS load_sql.
    METHODS configure
      IMPORTING iv_act TYPE abap_bool DEFAULT abap_false
                iv_nominal TYPE abap_bool DEFAULT abap_false
                iv_rule TYPE zreing_docflow_c-bukrs_rule DEFAULT 'O'.
    METHODS apply_context.
    METHODS run RETURNING VALUE(rs_result) TYPE zif_reing_contab_types=>ty_step_result.
    METHODS assert_pair
      IMPORTING is_result TYPE zif_reing_contab_types=>ty_step_result
                iv_currency TYPE waers DEFAULT 'USD'
                iv_act TYPE abap_bool DEFAULT abap_false
                iv_kostl TYPE kostl DEFAULT '4591333999'.
    METHODS assert_not_applicable.
    METHODS assert_config_error
      IMPORTING iv_message TYPE symsgno iv_source TYPE zreing_role_code DEFAULT 'RWHE'
                iv_target TYPE zreing_role_code DEFAULT 'RECL'
                iv_category TYPE zreing_role_cat DEFAULT 'E'.
    METHODS rejected_both IMPORTING iv_kind TYPE i.
    METHODS rejected_one
      IMPORTING iv_kind TYPE i iv_nominal TYPE abap_bool.
    METHODS assert_partial IMPORTING iv_nominal TYPE abap_bool.
    METHODS zzz_legacy_nominal FOR TESTING RAISING cx_static_check.
    METHODS actzzz_legacy_sides FOR TESTING RAISING cx_static_check.
    METHODS zzz_trans_nominal FOR TESTING RAISING cx_static_check.
    METHODS actzzz_trans_sides FOR TESTING RAISING cx_static_check.
    METHODS multi_category_pairs FOR TESTING RAISING cx_static_check.
    METHODS previous_amount_not_fx FOR TESTING RAISING cx_static_check.
    METHODS previous_dimensions FOR TESTING RAISING cx_static_check.
    METHODS immediately_previous_step FOR TESTING RAISING cx_static_check.
    METHODS absent_previous_flow FOR TESTING RAISING cx_static_check.
    METHODS absent_previous_result FOR TESTING RAISING cx_static_check.
    METHODS failed_previous_result FOR TESTING RAISING cx_static_check.
    METHODS empty_previous_items FOR TESTING RAISING cx_static_check.
    METHODS zero_marked_items FOR TESTING RAISING cx_static_check.
    METHODS unmarked_nonzero FOR TESTING RAISING cx_static_check.
    METHODS selected_items_only FOR TESTING RAISING cx_static_check.
    METHODS replace_prior_context FOR TESTING RAISING cx_static_check.
    METHODS header_provider_costcenter FOR TESTING RAISING cx_static_check.
    METHODS header_receiver_costcenter FOR TESTING RAISING cx_static_check.
    METHODS header_override_costcenter FOR TESTING RAISING cx_static_check.
    METHODS missing_target_rejected FOR TESTING RAISING cx_static_check.
    METHODS missing_counter_rejected FOR TESTING RAISING cx_static_check.
    METHODS same_role_rejected FOR TESTING RAISING cx_static_check.
    METHODS partial_items_not_posted FOR TESTING RAISING cx_static_check.
    METHODS missing_account_rejected FOR TESTING RAISING cx_static_check.
    METHODS same_sides_unbalanced FOR TESTING RAISING cx_static_check.
    METHODS poster_error_payload FOR TESTING RAISING cx_static_check.
    METHODS post_mode_uses_fake FOR TESTING RAISING cx_static_check.
    METHODS error_context_reset FOR TESTING RAISING cx_static_check.
    " V001 (CC) - bug107 CONTAB: reclassification never inherits the previous CeCo.
    METHODS contract_pair_legacy FOR TESTING RAISING cx_static_check.
    METHODS contract_pair_nominal FOR TESTING RAISING cx_static_check.
    METHODS contract_recl_missing FOR TESTING RAISING cx_static_check.
    METHODS contract_recl_context IMPORTING iv_kostl TYPE kostl OPTIONAL.

    " V001 (CC) - #121: source KOSTL prefix overrides campaign metadata.
    METHODS map_recl_context IMPORTING iv_rule TYPE zreing_bukrs_rule DEFAULT 'O'
      iv_prctr TYPE prctr DEFAULT '999'
      it_map TYPE zif_reing_contab_types=>tt_campana_map OPTIONAL.
    METHODS map_recl_error IMPORTING iv_message TYPE symsgno.
    METHODS map_pair_legacy FOR TESTING RAISING cx_static_check.
    METHODS map_pair_nominal FOR TESTING RAISING cx_static_check.
    METHODS map_bad_company FOR TESTING RAISING cx_static_check.
    METHODS map_source_prefix_missing FOR TESTING RAISING cx_static_check.
    METHODS map_empty_destination FOR TESTING RAISING cx_static_check.
    METHODS map_zero_skips FOR TESTING RAISING cx_static_check.
    METHODS map_context_reset FOR TESTING RAISING cx_static_check.

    " V001 (CC) - #125: configured counterparts, ambiguity and legacy guards.
    CONSTANTS co_gl_counter TYPE zreing_ct2_gl_a-gl_uuid
      VALUE '0000000000000000000000000000C304'.
    METHODS given_counter
      IMPORTING iv_counter TYPE zreing_role_code DEFAULT 'RWHE'
                iv_category TYPE zreing_role_cat DEFAULT 'E'
                iv_tax TYPE zreing_gl_roles-tax_type DEFAULT 'WHT'
                iv_nominal TYPE abap_bool DEFAULT abap_false
                iv_act TYPE abap_bool DEFAULT abap_false.
    METHODS reload_counter
      IMPORTING iv_nominal TYPE abap_bool DEFAULT abap_false
                iv_contract TYPE kostl OPTIONAL
                it_map TYPE zif_reing_contab_types=>tt_campana_map OPTIONAL.
    METHODS assert_counter_pair
      IMPORTING is_result TYPE zif_reing_contab_types=>ty_step_result
                iv_counter TYPE zreing_role_code DEFAULT 'RWHE'
                iv_amount TYPE zreing_ca_line_a-net_amt DEFAULT '75.25'
                iv_currency TYPE waers DEFAULT 'USD'
                iv_act TYPE abap_bool DEFAULT abap_false
                iv_kostl TYPE kostl DEFAULT '4591333999'
                iv_campana TYPE zreing_campana DEFAULT '459'.
    METHODS assert_counter_error
      IMPORTING iv_number TYPE symsgno
                iv_source TYPE zreing_role_code DEFAULT 'RWHE'
                iv_category TYPE zreing_role_cat DEFAULT 'E'
                iv_count TYPE i DEFAULT 2.
    METHODS check_shared_flow
      IMPORTING iv_op TYPE zreing_op_type iv_act TYPE abap_bool DEFAULT abap_false.
    METHODS check_case_amount IMPORTING iv_amount TYPE zreing_ca_line_a-net_amt.
    METHODS cfg_wht_legacy FOR TESTING RAISING cx_static_check.
    METHODS cfg_wht_nominal FOR TESTING RAISING cx_static_check.
    METHODS cfg_wht_actzzz FOR TESTING RAISING cx_static_check.
    METHODS cfg_wht_actzzz_nominal FOR TESTING RAISING cx_static_check.
    METHODS cfg_cogs_counter FOR TESTING RAISING cx_static_check.
    METHODS renamed_tax_counter FOR TESTING RAISING cx_static_check.
    METHODS renamed_plain_counter FOR TESTING RAISING cx_static_check.
    METHODS blank_category_counter FOR TESTING RAISING cx_static_check.
    METHODS target_same_category FOR TESTING RAISING cx_static_check.
    METHODS ambiguity_legacy FOR TESTING RAISING cx_static_check.
    METHODS ambiguity_nominal FOR TESTING RAISING cx_static_check.
    METHODS ambiguity_role_order FOR TESTING RAISING cx_static_check.
    METHODS ambiguity_partial_document FOR TESTING RAISING cx_static_check.
    METHODS ambiguity_source_order FOR TESTING RAISING cx_static_check.
    METHODS target_ar_rejected FOR TESTING RAISING cx_static_check.
    METHODS target_ap_rejected FOR TESTING RAISING cx_static_check.
    METHODS target_no_master FOR TESTING RAISING cx_static_check.
    METHODS non_gl_counter_rejected FOR TESTING RAISING cx_static_check.
    METHODS other_category_rejected FOR TESTING RAISING cx_static_check.
    METHODS zero_invalid_target_skipped FOR TESTING RAISING cx_static_check.
    METHODS context_after_ambiguity FOR TESTING RAISING cx_static_check.
    METHODS contract_cost_tax_counter FOR TESTING RAISING cx_static_check.
    METHODS mapped_cost_tax_counter FOR TESTING RAISING cx_static_check.
    METHODS shared_reclass_flows FOR TESTING RAISING cx_static_check.
    METHODS current_case_accounts FOR TESTING RAISING cx_static_check.
    METHODS two_tax_categories FOR TESTING RAISING cx_static_check.
    " V001 (CC) - #121: contractual CeBe and scoped consolidation.
    METHODS cebe_case
      IMPORTING it_sources TYPE zif_reing_contab_types=>ty_doc_item_t
                iv_prctr TYPE prctr DEFAULT '999'
                iv_nominal TYPE abap_bool DEFAULT abap_false.
    METHODS assert_cebe_pair
      IMPORTING iv_total TYPE zreing_ca_line_a-net_amt
                iv_pc TYPE prctr DEFAULT '0000000999'
                iv_kostl TYPE kostl DEFAULT '9540147999'
                iv_currency TYPE waers DEFAULT 'USD'.
    METHODS cebe_mco FOR TESTING RAISING cx_static_check.
    METHODS cebe_dru FOR TESTING RAISING cx_static_check.
    METHODS cebe_mpo FOR TESTING RAISING cx_static_check.
    METHODS cebe_alt_contract FOR TESTING RAISING cx_static_check.
    METHODS cebe_nominal_group FOR TESTING RAISING cx_static_check.
    METHODS cebe_empty_reject FOR TESTING RAISING cx_static_check.
    METHODS cebe_empty_zero_skips FOR TESTING RAISING cx_static_check.
    METHODS cebe_empty_unmarked_skips FOR TESTING RAISING cx_static_check.
    METHODS cebe_reset_after_success FOR TESTING RAISING cx_static_check.
    METHODS cebe_invalid_company FOR TESTING RAISING cx_static_check.
    METHODS cebe_actzzz_unchanged FOR TESTING RAISING cx_static_check.
    METHODS cebe_late_map_error FOR TESTING RAISING cx_static_check.
    METHODS cebe_grouped_sources_over_999 FOR TESTING RAISING cx_static_check.
    METHODS check_cebe_operation IMPORTING iv_op TYPE zreing_op_type.
    METHODS cebe_shared_zzz_operations FOR TESTING RAISING cx_static_check.

    " V001 (CC) - #122: explicit ET oracles, no live FI calls.
    METHODS text_et_zzz_roles FOR TESTING RAISING cx_static_check.
    METHODS text_et_actzzz_roles FOR TESTING RAISING cx_static_check.
    METHODS text_et_nominal_counter FOR TESTING RAISING cx_static_check.
    METHODS text_et_after_grouping FOR TESTING RAISING cx_static_check.
    " V001 (CC) - #122: unified external-contract text.
    METHODS text_external_context_reset FOR TESTING RAISING cx_static_check.
    METHODS text_external_override_company FOR TESTING RAISING cx_static_check.
ENDCLASS.
CLASS ltcl_cb03_recl IMPLEMENTATION.
  METHOD class_setup.
    sql_env = cl_osql_test_environment=>create( VALUE #(
      ( 'ZREING_CA_RUN_A' ) ( 'ZREING_OP_TYPE_C' ) ( 'ZREING_DOCTYPE_R' )
      ( 'ZREING_GL_ROLES' ) ( 'ZREING_CT2_GL_A' ) ( 'ZREING_DOCFLOW_C' )
      ( 'ZI_COMPANYCODEADDLINFORMATION' ) ( 'ZC_INTERCORELATIONSHIP' )
      ( 'ZI_REINGCBCUSTOMERRECON' ) ( 'ZI_REINGCBSUPPLIERRECON' )
      ( 'ZI_REINGCBPRODUCTTEXT' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    sql_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    sql_env->clear_doubles( ).
  ENDMETHOD.
  METHOD teardown.
    sql_env->clear_doubles( ).
  ENDMETHOD.
  METHOD configure.
    masters = VALUE #(
      ( gl_role = 'RWHE' role_category = 'E' tax_type = 'WHT'
        posting_context = 'GL' reclassify = abap_true role_reclas = 'RECL' )
      ( gl_role = 'RWHC' role_category = 'C' tax_type = 'WHT'
        posting_context = 'GL' reclassify = abap_true role_reclas = 'RECL' )
      ( gl_role = 'RWHP' role_category = 'E' tax_type = 'WHT' posting_context = 'GL' )
      ( gl_role = 'RECL' posting_context = 'GL' )
      ( gl_role = 'RREE' role_category = 'E' posting_context = 'GL' )
      ( gl_role = 'RREC' role_category = 'C' posting_context = 'GL' ) ).
    roles = VALUE #(
      ( doc_type_code = 'ZZZ' role_code = 'RECL' posting_side = 'S' )
      ( doc_type_code = 'ZZZ' role_code = 'RREE' posting_side = 'H' )
      ( doc_type_code = 'ZZZ' role_code = 'RREC' posting_side = 'H' )
      ( doc_type_code = 'ACTZZZ' role_code = 'RECL' posting_side = 'H' )
      ( doc_type_code = 'ACTZZZ' role_code = 'RREE' posting_side = 'S' )
      ( doc_type_code = 'ACTZZZ' role_code = 'RREC' posting_side = 'S' ) ).
    accounts = VALUE #( ( ct_uuid = co_ct mat_uuid = co_mat gl_uuid = co_gl_recl gl_role = 'RECL' saknr = '0000410000' )
      ( ct_uuid = co_ct mat_uuid = co_mat gl_uuid = co_gl_rree gl_role = 'RREE' saknr = '0000510000' )
      ( ct_uuid = co_ct mat_uuid = co_mat gl_uuid = co_gl_rrec gl_role = 'RREC' saknr = '0000610000' ) ).
    flow = VALUE #( ( op_type = 'F' seq = '005' doc_type_code = 'AR' )
      ( op_type = 'F' seq = '010' doc_type_code = 'AP' )
      ( op_type = 'F' seq = '030' doc_type_code = 'ZZZ' )
      ( op_type = 'A' seq = '010' doc_type_code = 'ACT' )
      ( op_type = 'A' seq = '030' doc_type_code = 'ACTZZZ' ) ).
    line = VALUE #( calc_run_id = 'CB03TEST' line_num = '0000001'
      ct_uuid = co_ct mat_uuid = co_mat ct_id = 'CB03FIXTURE' matnr = 'FIXTURE'
      bukrs_prest = 'EBA' bukrs_recv = 'RCV' op_type = COND #( WHEN iv_act = abap_true THEN 'A' ELSE 'F' )
      calc_amt = 100 bruto_amt = 200 ct_currency = 'USD'
      trans_currency = 'BRL' exch_rate_1 = 5 net_trans_amt = 500 ).
    step = VALUE #( op_type = line-op_type seq = '030' blart = 'SA'
      bukrs_rule = iv_rule bukrs_override = 'OVR'
      doc_type_code = COND #( WHEN iv_act = abap_true THEN 'ACTZZZ' ELSE 'ZZZ' ) ).
    docs = VALUE #( ( doc_type_code = COND #( WHEN iv_act = abap_true THEN 'ACT' ELSE 'AP' )
      items = VALUE #( ( role_code = 'RWHE' amount = '-75.25'
        waers = COND #( WHEN iv_nominal = abap_true THEN 'BRL' ELSE 'USD' )
        hkont = '0000990000' kostl = '4591999999' campana = '459'
        allocation = '1' prctr = '0000000999' zuonr = 'PREVIOUS-E' ) ) ) ).
    cut = NEW #( ).
    poster = NEW #( ).
    load_sql( ).
    apply_context( ).
    IF iv_nominal = abap_true. cut->enable_nominal( ). ENDIF.
  ENDMETHOD.
  METHOD load_sql.
    sql_env->clear_doubles( ).
    sql_env->insert_test_data( masters ).
    sql_env->insert_test_data( roles ).
    sql_env->insert_test_data( accounts ).
    sql_env->insert_test_data( flow ).
    DATA(runs) = VALUE tt_run( ( calc_run_id = 'CB03TEST' fiscal_year = '2026' fiscal_period = '01' ) ).
    sql_env->insert_test_data( runs ).
    DATA(ops) = VALUE tt_ops( ( op_type = 'F' ) ( op_type = 'A' ) ).
    sql_env->insert_test_data( ops ).
    DATA(companies) = VALUE tt_company(
      ( companycode = 'EBA' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'EBA' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '111' )
      ( companycode = 'RCV' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'RCV' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '222' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '333' ) ).
    sql_env->insert_test_data( companies ).
  ENDMETHOD.
  METHOD apply_context.
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( )
      it_step_a = VALUE #( ) is_flow_step = step iv_contract_ext = 'Simetrik' ).
    cut->zif_reing_contab~set_prior_documents( docs ).
    cut->zif_reing_contab~set_fi_poster( poster ).
  ENDMETHOD.
  METHOD run.
    cl_abap_unit_assert=>assert_true( cut->zif_reing_contab~is_applicable( ) ).
    rs_result = cut->zif_reing_contab~execute( 'C' ).
  ENDMETHOD.
  METHOD assert_pair.
    cl_abap_unit_assert=>assert_false( is_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-items exp = poster->items ).
    cl_abap_unit_assert=>assert_equals( act = is_result-waers exp = iv_currency ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-total_amount
      exp = CONV zreing_ca_calc_amt( '75.25' ) ).
    DATA(target) = is_result-items[ role_code = 'RECL' ].
    DATA(counter) = is_result-items[ role_code = 'RREE' ].
    cl_abap_unit_assert=>assert_equals( act = target-amount
      exp = COND zreing_ca_calc_amt( WHEN iv_act = abap_true THEN '-75.25' ELSE '75.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = counter-amount exp = target-amount * -1 ).
    cl_abap_unit_assert=>assert_equals( act = target-posting_side
      exp = COND shkzg( WHEN iv_act = abap_true THEN 'H' ELSE 'S' ) ).
    cl_abap_unit_assert=>assert_equals( act = counter-posting_side
      exp = COND shkzg( WHEN iv_act = abap_true THEN 'S' ELSE 'H' ) ).
    cl_abap_unit_assert=>assert_equals( act = target-hkont exp = '0000410000' ).
    cl_abap_unit_assert=>assert_equals( act = counter-hkont exp = '0000510000' ).
    cl_abap_unit_assert=>assert_equals( act = target-item_num exp = '001' ).
    cl_abap_unit_assert=>assert_equals( act = counter-item_num exp = '002' ).
    LOOP AT is_result-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-waers exp = iv_currency ).
      cl_abap_unit_assert=>assert_equals( act = item-kostl exp = iv_kostl ).
      cl_abap_unit_assert=>assert_equals( act = item-prctr exp = '0000000999' ).
      cl_abap_unit_assert=>assert_equals( act = item-campana exp = '459' ).
      cl_abap_unit_assert=>assert_equals( act = item-allocation exp = '1' ).
      cl_abap_unit_assert=>assert_equals( act = item-zuonr exp = 'PREVIOUS-E' ).
      cl_abap_unit_assert=>assert_equals( act = item-posting_context exp = 'GL' ).
    ENDLOOP.
  ENDMETHOD.
  METHOD assert_not_applicable.
    cl_abap_unit_assert=>assert_false( cut->zif_reing_contab~is_applicable( ) ).
    " The public processor contract stops here; Engine traces are not claimed.
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD assert_config_error.
    DATA(result) = run( ).
    DATA expected TYPE string.
    MESSAGE ID zif_reing_ca_c=>message_class
      TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_message
      WITH step-doc_type_code iv_source iv_target iv_category INTO expected.
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD rejected_both.
    rejected_one( iv_kind = iv_kind iv_nominal = abap_false ).
    rejected_one( iv_kind = iv_kind iv_nominal = abap_true ).
  ENDMETHOD.
  METHOD rejected_one.
    configure( iv_nominal = iv_nominal ).
    CASE iv_kind.
      WHEN 1.
        DELETE roles WHERE doc_type_code = 'ZZZ' AND role_code = 'RECL'.
      WHEN 2.
        DELETE roles WHERE doc_type_code = 'ZZZ' AND role_code = 'RREE'.
      WHEN 3.
        masters[ gl_role = 'RWHE' ]-role_reclas = 'RREE'.
    ENDCASE.
    load_sql( ).
    apply_context( ).
    IF iv_nominal = abap_true. cut->enable_nominal( ). ENDIF.
    assert_config_error(
      iv_message = COND #( WHEN iv_kind = 1 THEN co_target_msg
                           WHEN iv_kind = 2 THEN co_counter_msg ELSE co_equal_msg )
      iv_target = COND #( WHEN iv_kind = 3 THEN 'RREE' ELSE 'RECL' ) ).
  ENDMETHOD.
  METHOD assert_partial.
    configure( iv_nominal = iv_nominal ).
    masters[ gl_role = 'RWHC' ]-role_reclas = 'NONE'.
    DATA(extra_items) = docs[ 1 ]-items.
    APPEND VALUE #( role_code = 'RWHC' amount = 1
      waers = COND #( WHEN iv_nominal = abap_true THEN 'BRL' ELSE 'USD' ) ) TO extra_items.
    docs[ 1 ]-items = extra_items.
    load_sql( ).
    apply_context( ).
    IF iv_nominal = abap_true. cut->enable_nominal( ). ENDIF.
    assert_config_error( iv_message = co_target_msg iv_source = 'RWHC'
      iv_target = 'NONE' iv_category = 'C' ).
    DATA(items) = cut->build( ).
    cl_abap_unit_assert=>assert_equals( act = lines( items ) exp = 2 ).
  ENDMETHOD.
  METHOD zzz_legacy_nominal.
    configure( ).
    assert_pair( run( ) ).
    cl_abap_unit_assert=>assert_equals( act = poster->header-waers exp = 'USD' ).
  ENDMETHOD.
  METHOD actzzz_legacy_sides.
    configure( iv_act = abap_true ).
    assert_pair( is_result = run( ) iv_act = abap_true ).
  ENDMETHOD.
  METHOD zzz_trans_nominal.
    configure( iv_nominal = abap_true ).
    assert_pair( is_result = run( ) iv_currency = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = poster->header-waers exp = 'BRL' ).
  ENDMETHOD.
  METHOD actzzz_trans_sides.
    configure( iv_act = abap_true iv_nominal = abap_true ).
    assert_pair( is_result = run( ) iv_currency = 'BRL' iv_act = abap_true ).
  ENDMETHOD.
  METHOD multi_category_pairs.
    configure( iv_nominal = abap_true ).
    docs[ 1 ]-items = VALUE #(
      ( role_code = 'RWHC' amount = '20.11' waers = 'BRL' prctr = '0000000111'
        campana = '123' allocation = '0' zuonr = 'PREVIOUS-C' )
      ( role_code = 'RWHE' amount = '-55.14' waers = 'BRL' prctr = '0000000222'
        campana = '459' allocation = '1' zuonr = 'PREVIOUS-E' ) ).
    cut->zif_reing_contab~set_prior_documents( docs ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = result-total_amount exp = CONV zreing_ca_calc_amt( '75.25' ) ).
    DATA(c_items) = VALUE zif_reing_contab_types=>ty_doc_item_t(
      FOR item IN result-items WHERE ( prctr = '0000000111' ) ( item ) ).
    DATA(e_items) = VALUE zif_reing_contab_types=>ty_doc_item_t(
      FOR item IN result-items WHERE ( prctr = '0000000222' ) ( item ) ).
    cl_abap_unit_assert=>assert_equals( act = c_items[ role_code = 'RECL' ]-amount
      exp = CONV zreing_ca_calc_amt( '20.11' ) ).
    cl_abap_unit_assert=>assert_equals( act = c_items[ role_code = 'RREC' ]-amount
      exp = CONV zreing_ca_calc_amt( '-20.11' ) ).
    cl_abap_unit_assert=>assert_equals( act = e_items[ role_code = 'RECL' ]-amount
      exp = CONV zreing_ca_calc_amt( '55.14' ) ).
    cl_abap_unit_assert=>assert_equals( act = e_items[ role_code = 'RREE' ]-amount
      exp = CONV zreing_ca_calc_amt( '-55.14' ) ).
    LOOP AT result-items INTO DATA(actual).
      cl_abap_unit_assert=>assert_equals( act = actual-waers exp = 'BRL' ).
      IF actual-prctr = '0000000111'.
        cl_abap_unit_assert=>assert_equals( act = actual-kostl exp = '1230333111' ).
        cl_abap_unit_assert=>assert_equals( act = actual-zuonr exp = 'PREVIOUS-C' ).
        cl_abap_unit_assert=>assert_equals( act = actual-campana exp = '123' ).
        cl_abap_unit_assert=>assert_equals( act = actual-allocation exp = '0' ).
      ELSE.
        cl_abap_unit_assert=>assert_equals( act = actual-kostl exp = '4591333222' ).
        cl_abap_unit_assert=>assert_equals( act = actual-zuonr exp = 'PREVIOUS-E' ).
        cl_abap_unit_assert=>assert_equals( act = actual-campana exp = '459' ).
        cl_abap_unit_assert=>assert_equals( act = actual-allocation exp = '1' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD previous_amount_not_fx.
    configure( iv_nominal = abap_true ).
    DATA(before_line) = cut->native_line( ).
    DATA(before_docs) = cut->prior_docs( ).
    assert_pair( is_result = run( ) iv_currency = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = cut->native_line( ) exp = before_line ).
    cl_abap_unit_assert=>assert_equals( act = cut->prior_docs( ) exp = before_docs ).
    cl_abap_unit_assert=>assert_equals( act = before_line-exch_rate_1 exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = before_line-calc_amt exp = 100 ).
  ENDMETHOD.
  METHOD previous_dimensions.
    configure( ).
    DATA(before) = cut->prior_docs( ).
    assert_pair( run( ) ).
    cl_abap_unit_assert=>assert_equals( act = cut->prior_docs( ) exp = before ).
  ENDMETHOD.
  METHOD immediately_previous_step.
    configure( ).
    APPEND VALUE #( op_type = 'F' seq = '020' doc_type_code = 'ACT' ) TO flow.
    APPEND VALUE #( op_type = 'F' seq = '040' doc_type_code = 'INT' ) TO flow.
    APPEND VALUE #( op_type = 'P' seq = '025' doc_type_code = 'API' ) TO flow.
    docs = VALUE #( ( doc_type_code = 'AP' items = VALUE #(
      ( role_code = 'RWHE' amount = 999 waers = 'USD' ) ) )
      ( doc_type_code = 'ACT' items = VALUE #(
      ( role_code = 'RWHE' amount = '75.25' waers = 'USD' campana = '459'
        allocation = '1' prctr = '0000000999' zuonr = 'PREVIOUS-E' ) ) ) ).
    load_sql( ).
    apply_context( ).
    assert_pair( run( ) ).
  ENDMETHOD.
  METHOD absent_previous_flow.
    configure( ).
    DELETE flow WHERE op_type = 'F' AND seq < '030'.
    load_sql( ).
    apply_context( ).
    assert_not_applicable( ).
  ENDMETHOD.
  METHOD absent_previous_result.
    configure( ).
    CLEAR docs.
    cut->zif_reing_contab~set_prior_documents( docs ).
    assert_not_applicable( ).
  ENDMETHOD.
  METHOD failed_previous_result.
    configure( ).
    docs[ 1 ]-has_error = abap_true.
    cut->zif_reing_contab~set_prior_documents( docs ).
    assert_not_applicable( ).
  ENDMETHOD.
  METHOD empty_previous_items.
    configure( ).
    CLEAR docs[ 1 ]-items.
    cut->zif_reing_contab~set_prior_documents( docs ).
    assert_not_applicable( ).
  ENDMETHOD.
  METHOD zero_marked_items.
    configure( ).
    docs[ 1 ]-items[ 1 ]-amount = 0.
    cut->zif_reing_contab~set_prior_documents( docs ).
    assert_not_applicable( ).
    cl_abap_unit_assert=>assert_initial( cut->build( ) ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
  ENDMETHOD.
  METHOD unmarked_nonzero.
    configure( ).
    docs[ 1 ]-items[ 1 ]-role_code = 'RWHP'.
    cut->zif_reing_contab~set_prior_documents( docs ).
    assert_not_applicable( ).
  ENDMETHOD.
  METHOD selected_items_only.
    configure( ).
    masters[ gl_role = 'RWHC' ]-role_reclas = 'NONE'.
    DELETE roles WHERE role_code = 'RREC'.
    DATA(selected) = docs[ 1 ]-items[ 1 ].
    docs[ 1 ]-items = VALUE #( ( role_code = 'RWHC' amount = 0 waers = 'USD' )
      ( role_code = 'RWHP' amount = 999 waers = 'USD' ) ( selected ) ).
    load_sql( ).
    apply_context( ).
    assert_pair( run( ) ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
  ENDMETHOD.
  METHOD replace_prior_context.
    configure( ).
    cl_abap_unit_assert=>assert_true( cut->zif_reing_contab~is_applicable( ) ).
    cut->zif_reing_contab~set_prior_documents( VALUE #( ( doc_type_code = 'AR' ) ) ).
    assert_not_applicable( ).
    cut->zif_reing_contab~set_prior_documents( VALUE #( ) ).
    assert_not_applicable( ).
  ENDMETHOD.
  METHOD header_provider_costcenter.
    configure( iv_rule = 'P' ).
    assert_pair( is_result = run( ) iv_kostl = '4591111999' ).
    cl_abap_unit_assert=>assert_equals( act = poster->header-bukrs exp = 'EBA' ).
  ENDMETHOD.
  METHOD header_receiver_costcenter.
    configure( iv_rule = 'R' ).
    assert_pair( is_result = run( ) iv_kostl = '4591222999' ).
    cl_abap_unit_assert=>assert_equals( act = poster->header-bukrs exp = 'RCV' ).
  ENDMETHOD.
  METHOD header_override_costcenter.
    configure( iv_rule = 'O' ).
    assert_pair( is_result = run( ) iv_kostl = '4591333999' ).
    cl_abap_unit_assert=>assert_equals( act = poster->header-bukrs exp = 'OVR' ).
  ENDMETHOD.
  METHOD missing_target_rejected.
    rejected_both( 1 ).
  ENDMETHOD.
  METHOD missing_counter_rejected.
    rejected_both( 2 ).
  ENDMETHOD.
  METHOD same_role_rejected.
    rejected_both( 3 ).
  ENDMETHOD.
  METHOD partial_items_not_posted.
    assert_partial( abap_false ).
    assert_partial( abap_true ).
  ENDMETHOD.
  METHOD missing_account_rejected.
    configure( ).
    DELETE accounts WHERE gl_role = 'RECL'.
    load_sql( ).
    apply_context( ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_not_initial( result-error_msg ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD same_sides_unbalanced.
    configure( ).
    roles[ doc_type_code = 'ZZZ' role_code = 'RREE' ]-posting_side = 'S'.
    load_sql( ).
    apply_context( ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RECL' ]-amount
      exp = CONV zreing_ca_calc_amt( '75.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RREE' ]-amount
      exp = CONV zreing_ca_calc_amt( '75.25' ) ).
  ENDMETHOD.
  METHOD poster_error_payload.
    configure( ).
    poster->failed = abap_true.
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = 'Injected poster failure' ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 1 ).
    DATA(decoded) = VALUE zif_reing_contab_types=>ty_step_result( ).
    /ui2/cl_json=>deserialize( EXPORTING json = result-payload CHANGING data = decoded ).
    cl_abap_unit_assert=>assert_equals( act = decoded-items exp = result-items ).
    cl_abap_unit_assert=>assert_equals( act = decoded-doc_type_code exp = 'ZZZ' ).
  ENDMETHOD.
  METHOD post_mode_uses_fake.
    configure( iv_nominal = abap_true ).
    cl_abap_unit_assert=>assert_true( cut->zif_reing_contab~is_applicable( ) ).
    DATA(result) = cut->zif_reing_contab~execute( 'P' ).
    assert_pair( is_result = result iv_currency = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = poster->mode exp = 'P' ).
    cl_abap_unit_assert=>assert_equals( act = result-belnr exp = '9000000011' ).
    cl_abap_unit_assert=>assert_equals( act = result-gjahr exp = '2026' ).
    cl_abap_unit_assert=>assert_equals( act = poster->reverse_calls exp = 0 ).
  ENDMETHOD.
  METHOD error_context_reset.
    configure( ).
    DATA(good_roles) = roles.
    DELETE roles WHERE doc_type_code = 'ZZZ' AND role_code = 'RECL'.
    load_sql( ).
    apply_context( ).
    assert_config_error( co_target_msg ).
    roles = good_roles.
    load_sql( ).
    apply_context( ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
    assert_pair( run( ) ).
  ENDMETHOD.
  METHOD contract_recl_context.
    step-kostl_rule = 'C'.
    step-bukrs_rule = 'P'.
    cut->zif_reing_contab~set_context(
      is_line_a = line it_line_pc = VALUE #( ) it_step_a = VALUE #( )
      is_flow_step = step iv_contract_kostl = iv_kostl ).
    cut->zif_reing_contab~set_prior_documents( docs ).
    cut->zif_reing_contab~set_fi_poster( poster ).
  ENDMETHOD.
  METHOD contract_pair_legacy.
    configure( ).
    contract_recl_context( 'CTCECO1234' ).
    assert_pair( is_result = run( ) iv_kostl = 'CTCECO1234' ).
  ENDMETHOD.
  METHOD contract_pair_nominal.
    configure( iv_nominal = abap_true ).
    contract_recl_context( 'CTCECO1234' ).
    cut->enable_nominal( ).
    assert_pair( is_result = run( ) iv_kostl = 'CTCECO1234' iv_currency = 'BRL' ).
  ENDMETHOD.
  METHOD contract_recl_missing.
    configure( ).
    contract_recl_context( ).
    DATA(result) = run( ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '006'
      WITH line-ct_id line-matnr step-doc_type_code INTO DATA(expected).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.

  METHOD map_recl_context.
    step-kostl_rule = 'Z'.
    step-bukrs_rule = iv_rule.
    " Campaign metadata remains 459; the actual source center starts with 777.
    docs[ 1 ]-items[ 1 ]-kostl = '7771222999'.
    DATA maps TYPE zif_reing_contab_types=>tt_campana_map.
    IF it_map IS SUPPLIED.
      maps = it_map.
    ELSE.
      maps = VALUE #( ( campana_de = '777' matnr = line-matnr campana_para = '888' )
        ( campana_de = '459' matnr = line-matnr campana_para = '999' ) ).
    ENDIF.
    cut->zif_reing_contab~set_context(
      is_line_a = line it_line_pc = VALUE #( ) it_step_a = VALUE #( )
      is_flow_step = step it_campana_map = maps iv_contract_prctr = iv_prctr ).
    cut->zif_reing_contab~set_prior_documents( docs ).
    cut->zif_reing_contab~set_fi_poster( poster ).
  ENDMETHOD.
  METHOD map_pair_legacy.
    configure( ).
    map_recl_context( ).
    assert_pair( is_result = run( ) iv_kostl = '8881333999' ).
  ENDMETHOD.
  METHOD map_pair_nominal.
    configure( iv_nominal = abap_true ).
    map_recl_context( ).
    cut->enable_nominal( ).
    assert_pair( is_result = run( ) iv_kostl = '8881333999' iv_currency = 'BRL' ).
  ENDMETHOD.
  METHOD map_recl_error.
    DATA(result) = run( ).
    DATA expected TYPE string.
    IF iv_message = '007'.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER iv_message WITH step-doc_type_code INTO expected.
    ELSE.
      MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER iv_message WITH step-doc_type_code '777' line-matnr INTO expected.
    ENDIF.
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD map_bad_company.
    configure( ).
    map_recl_context( iv_rule = 'P' ).
    map_recl_error( '007' ).
    map_recl_context( iv_rule = 'R' ).
    map_recl_error( '007' ).
    map_recl_context( iv_rule = space ).
    map_recl_error( '007' ).
  ENDMETHOD.
  METHOD map_source_prefix_missing.
    configure( ).
    map_recl_context( it_map = VALUE #( ( campana_de = '459' matnr = line-matnr campana_para = '999' ) ) ).
    map_recl_error( '008' ).
  ENDMETHOD.
  METHOD map_empty_destination.
    configure( ).
    map_recl_context( it_map = VALUE #( ( campana_de = '777' matnr = line-matnr ) ) ).
    map_recl_error( '009' ).
  ENDMETHOD.
  METHOD map_zero_skips.
    configure( ).
    map_recl_context( iv_rule = 'P' it_map = VALUE #( ) ).
    CLEAR docs[ 1 ]-items[ 1 ]-amount.
    cut->zif_reing_contab~set_prior_documents( docs ).
    assert_not_applicable( ).
    DATA(items) = cut->build( ).
    cl_abap_unit_assert=>assert_initial( items ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
  ENDMETHOD.
  METHOD map_context_reset.
    configure( ).
    map_recl_context( ).
    assert_pair( is_result = run( ) iv_kostl = '8881333999' ).
    poster->post_calls = 0.
    map_recl_context( it_map = VALUE #( ) ).
    map_recl_error( '008' ).
  ENDMETHOD.

  METHOD given_counter.
    configure( iv_nominal = iv_nominal iv_act = iv_act ).
    DATA(source_role) = CONV zreing_role_code(
      COND #( WHEN iv_category = 'C' THEN 'RWHC' ELSE 'RWHE' ) ).
    masters[ gl_role = source_role ]-role_category = iv_category.
    docs[ 1 ]-items[ 1 ]-role_code = source_role.
    IF line_exists( masters[ gl_role = iv_counter ] ).
      masters[ gl_role = iv_counter ]-role_category = iv_category.
      masters[ gl_role = iv_counter ]-tax_type = iv_tax.
      masters[ gl_role = iv_counter ]-posting_context = 'GL'.
    ELSE.
      APPEND VALUE #( gl_role = iv_counter role_category = iv_category
        tax_type = iv_tax posting_context = 'GL' ) TO masters.
    ENDIF.
    DELETE roles WHERE doc_type_code = step-doc_type_code.
    APPEND VALUE #( doc_type_code = step-doc_type_code role_code = 'RECL'
      posting_side = COND #( WHEN iv_act = abap_true THEN 'H' ELSE 'S' ) ) TO roles.
    APPEND VALUE #( doc_type_code = step-doc_type_code role_code = iv_counter
      posting_side = COND #( WHEN iv_act = abap_true THEN 'S' ELSE 'H' ) ) TO roles.
    DELETE accounts WHERE gl_role = iv_counter.
    APPEND VALUE #( ct_uuid = co_ct mat_uuid = co_mat gl_uuid = co_gl_counter
      gl_role = iv_counter saknr = '0000510000' ) TO accounts.
    reload_counter( iv_nominal = iv_nominal ).
  ENDMETHOD.
  METHOD reload_counter.
    load_sql( ).
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( )
      it_step_a = VALUE #( ) is_flow_step = step iv_contract_kostl = iv_contract
      it_campana_map = it_map iv_contract_prctr = '999' iv_contract_ext = 'Simetrik' ).
    cut->zif_reing_contab~set_prior_documents( docs ).
    cut->zif_reing_contab~set_fi_poster( poster ).
    IF iv_nominal = abap_true. cut->enable_nominal( ). ENDIF.
  ENDMETHOD.
  METHOD assert_counter_pair.
    cl_abap_unit_assert=>assert_false( is_result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-items exp = poster->items ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-waers exp = iv_currency ).
    cl_abap_unit_assert=>assert_equals( act = is_result-total_amount exp = abs( iv_amount ) ).
    DATA(target) = is_result-items[ role_code = 'RECL' ].
    DATA(counter) = is_result-items[ role_code = iv_counter ].
    cl_abap_unit_assert=>assert_equals( act = target-amount
      exp = COND zreing_ca_calc_amt( WHEN iv_act = abap_true THEN iv_amount * -1 ELSE iv_amount ) ).
    cl_abap_unit_assert=>assert_equals( act = counter-amount exp = target-amount * -1 ).
    cl_abap_unit_assert=>assert_equals( act = target-posting_side
      exp = COND shkzg( WHEN iv_act = abap_true THEN 'H' ELSE 'S' ) ).
    cl_abap_unit_assert=>assert_equals( act = counter-posting_side
      exp = COND shkzg( WHEN iv_act = abap_true THEN 'S' ELSE 'H' ) ).
    cl_abap_unit_assert=>assert_equals( act = target-hkont exp = accounts[ gl_role = 'RECL' ]-saknr ).
    cl_abap_unit_assert=>assert_equals( act = counter-hkont exp = accounts[ gl_role = iv_counter ]-saknr ).
    cl_abap_unit_assert=>assert_equals( act = target-item_num exp = '001' ).
    cl_abap_unit_assert=>assert_equals( act = counter-item_num exp = '002' ).
    LOOP AT is_result-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-posting_context exp = 'GL' ).
      cl_abap_unit_assert=>assert_equals( act = item-waers exp = iv_currency ).
      cl_abap_unit_assert=>assert_equals( act = item-kostl exp = iv_kostl ).
      cl_abap_unit_assert=>assert_equals( act = item-prctr exp = '0000000999' ).
      cl_abap_unit_assert=>assert_equals( act = item-campana exp = iv_campana ).
      cl_abap_unit_assert=>assert_equals( act = item-allocation exp = '1' ).
      cl_abap_unit_assert=>assert_equals( act = item-zuonr exp = 'PREVIOUS-E' ).
    ENDLOOP.
  ENDMETHOD.
  METHOD assert_counter_error.
    DATA(result) = run( ).
    DATA expected TYPE string.
    CASE iv_number.
      WHEN '010'.
        MESSAGE ID zif_reing_ca_c=>message_class
          TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_number
          WITH step-doc_type_code iv_source iv_count iv_category INTO expected.
      WHEN '011'.
        MESSAGE ID zif_reing_ca_c=>message_class
          TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_number
          WITH step-doc_type_code iv_source 'RECL' INTO expected.
      WHEN OTHERS.
        MESSAGE ID zif_reing_ca_c=>message_class
          TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER iv_number
          WITH step-doc_type_code iv_source 'RECL' iv_category INTO expected.
    ENDCASE.
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD check_shared_flow.
    given_counter( iv_act = iv_act ).
    line-op_type = iv_op. step-op_type = iv_op.
    flow = VALUE #( ( op_type = iv_op seq = '010' doc_type_code = docs[ 1 ]-doc_type_code )
      ( op_type = iv_op seq = '030' doc_type_code = step-doc_type_code ) ).
    reload_counter( ).
    assert_counter_pair( is_result = run( ) iv_act = iv_act ).
  ENDMETHOD.
  METHOD check_case_amount.
    " The reported amounts/accounts use a synthetic, isolated run/company context.
    given_counter( ).
    line-ct_id = 'IC-0020'. line-bukrs_prest = 'MUR'. line-bukrs_recv = 'MPB'.
    accounts[ gl_role = 'RECL' ]-saknr = '6202010003'.
    accounts[ gl_role = 'RWHE' ]-saknr = '6401020007'.
    docs[ 1 ]-items[ 1 ]-amount = iv_amount.
    reload_counter( ).
    assert_counter_pair( is_result = run( ) iv_amount = iv_amount ).
  ENDMETHOD.

  METHOD cfg_wht_legacy.
    given_counter( ).
    assert_counter_pair( run( ) ).
  ENDMETHOD.

  METHOD cfg_wht_nominal.
    given_counter( iv_nominal = abap_true ).
    assert_counter_pair( is_result = run( ) iv_currency = 'BRL' ).
  ENDMETHOD.

  METHOD cfg_wht_actzzz.
    given_counter( iv_act = abap_true ).
    assert_counter_pair( is_result = run( ) iv_act = abap_true ).
  ENDMETHOD.

  METHOD cfg_wht_actzzz_nominal.
    given_counter( iv_act = abap_true iv_nominal = abap_true ).
    assert_counter_pair( is_result = run( ) iv_act = abap_true iv_currency = 'BRL' ).
  ENDMETHOD.

  METHOD cfg_cogs_counter.
    given_counter( iv_counter = 'RWHC' iv_category = 'C' ).
    assert_counter_pair( is_result = run( ) iv_counter = 'RWHC' ).
  ENDMETHOD.

  METHOD renamed_tax_counter.
    given_counter( iv_counter = 'XALT' iv_tax = 'CIDE' ).
    assert_counter_pair( is_result = run( ) iv_counter = 'XALT' ).
  ENDMETHOD.

  METHOD renamed_plain_counter.
    given_counter( iv_counter = 'XALT' iv_tax = space ).
    assert_counter_pair( is_result = run( ) iv_counter = 'XALT' ).
  ENDMETHOD.

  METHOD blank_category_counter.
    given_counter( iv_counter = 'XALT' iv_category = space ).
    assert_counter_pair( is_result = run( ) iv_counter = 'XALT' ).
  ENDMETHOD.

  METHOD target_same_category.
    given_counter( ).
    masters[ gl_role = 'RECL' ]-role_category = 'E'.
    reload_counter( ).
    assert_counter_pair( run( ) ).
  ENDMETHOD.

  METHOD ambiguity_legacy.
    given_counter( ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RREE' posting_side = 'H' ) TO roles.
    reload_counter( ).
    assert_counter_error( '010' ).
  ENDMETHOD.

  METHOD ambiguity_nominal.
    given_counter( iv_nominal = abap_true ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RREE' posting_side = 'H' ) TO roles.
    reload_counter( iv_nominal = abap_true ).
    assert_counter_error( '010' ).
  ENDMETHOD.

  METHOD ambiguity_role_order.
    given_counter( ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RREE' posting_side = 'H' ) TO roles.
    reload_counter( ).
    DATA(configured) = VALUE zif_reing_contab_types=>ty_role_resolved_t(
      ( role_code = 'RECL' posting_context = 'GL' posting_side = 'S' )
      ( role_code = 'RWHE' posting_context = 'GL' role_category = 'E' tax_type = 'WHT' posting_side = 'H' )
      ( role_code = 'RREE' posting_context = 'GL' role_category = 'E' posting_side = 'H' ) ).
    DATA(first_items) = cut->build_with_roles( configured ).
    DATA(first_error) = cut->pending_error( ).
    MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
      NUMBER '010' WITH 'ZZZ' 'RWHE' '2' 'E' INTO DATA(expected).
    cl_abap_unit_assert=>assert_equals( act = first_error exp = expected ).
    cl_abap_unit_assert=>assert_initial( first_items ).
    SORT configured BY role_code DESCENDING.
    reload_counter( ).
    DATA(second_items) = cut->build_with_roles( configured ).
    cl_abap_unit_assert=>assert_initial( second_items ).
    cl_abap_unit_assert=>assert_equals( act = cut->pending_error( ) exp = first_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.

  METHOD ambiguity_partial_document.
    given_counter( ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RWHC' posting_side = 'H' ) TO roles.
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RREC' posting_side = 'H' ) TO roles.
    DATA(previous) = docs[ 1 ]-items.
    APPEND VALUE #( role_code = 'RWHC' amount = '20.11' waers = 'USD'
      prctr = '0000000111' campana = '123' allocation = '0' ) TO previous.
    docs[ 1 ]-items = previous.
    reload_counter( ).
    assert_counter_error( iv_number = '010' iv_source = 'RWHC' iv_category = 'C' ).
    DATA(diagnostic_items) = cut->build( ).
    cl_abap_unit_assert=>assert_equals( act = lines( diagnostic_items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = diagnostic_items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( '75.25' ) ).
  ENDMETHOD.

  METHOD ambiguity_source_order.
    given_counter( ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RWHC' posting_side = 'H' ) TO roles.
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RREC' posting_side = 'H' ) TO roles.
    DATA(previous) = docs[ 1 ]-items.
    APPEND VALUE #( role_code = 'RWHC' amount = '20.11' waers = 'USD' ) TO previous.
    SORT previous BY role_code.
    docs[ 1 ]-items = previous.
    reload_counter( ).
    assert_counter_error( iv_number = '010' iv_source = 'RWHC' iv_category = 'C' ).
  ENDMETHOD.

  METHOD target_ar_rejected.
    given_counter( ).
    masters[ gl_role = 'RECL' ]-posting_context = 'AR'.
    reload_counter( ).
    assert_counter_error( '011' ).
  ENDMETHOD.

  METHOD target_ap_rejected.
    given_counter( iv_nominal = abap_true ).
    masters[ gl_role = 'RECL' ]-posting_context = 'AP'.
    reload_counter( iv_nominal = abap_true ).
    assert_counter_error( '011' ).
  ENDMETHOD.

  METHOD target_no_master.
    given_counter( ).
    DELETE masters WHERE gl_role = 'RECL'.
    reload_counter( ).
    assert_counter_error( '011' ).
  ENDMETHOD.

  METHOD non_gl_counter_rejected.
    given_counter( iv_counter = 'XALT' ).
    masters[ gl_role = 'XALT' ]-posting_context = 'AR'.
    reload_counter( ).
    assert_counter_error( '425' ).
  ENDMETHOD.

  METHOD other_category_rejected.
    given_counter( iv_counter = 'XALT' ).
    masters[ gl_role = 'XALT' ]-role_category = 'C'.
    reload_counter( ).
    assert_counter_error( '425' ).
  ENDMETHOD.

  METHOD zero_invalid_target_skipped.
    given_counter( ).
    CLEAR docs[ 1 ]-items[ 1 ]-amount.
    masters[ gl_role = 'RECL' ]-posting_context = 'AR'.
    reload_counter( ).
    assert_not_applicable( ).
    DATA(items) = cut->build( ).
    cl_abap_unit_assert=>assert_initial( items ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
  ENDMETHOD.

  METHOD context_after_ambiguity.
    given_counter( ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RREE' posting_side = 'H' ) TO roles.
    reload_counter( ).
    assert_counter_error( '010' ).
    DELETE roles WHERE doc_type_code = 'ZZZ' AND role_code = 'RREE'.
    reload_counter( ).
    assert_counter_pair( run( ) ).
  ENDMETHOD.

  METHOD contract_cost_tax_counter.
    given_counter( ).
    step-kostl_rule = 'C'. step-bukrs_rule = 'P'.
    reload_counter( iv_contract = 'CTCECO1234' ).
    assert_counter_pair( is_result = run( ) iv_kostl = 'CTCECO1234' ).
  ENDMETHOD.

  METHOD mapped_cost_tax_counter.
    given_counter( iv_nominal = abap_true ).
    step-kostl_rule = 'Z'.
    docs[ 1 ]-items[ 1 ]-kostl = '7771222999'.
    reload_counter( iv_nominal = abap_true
      it_map = VALUE #( ( campana_de = '777' matnr = line-matnr campana_para = '888' )
        ( campana_de = '459' matnr = line-matnr campana_para = '999' ) ) ).
    assert_counter_pair( is_result = run( ) iv_kostl = '8881333999' iv_currency = 'BRL' ).
  ENDMETHOD.

  METHOD shared_reclass_flows.
    check_shared_flow( iv_op = 'F' ).
    check_shared_flow( iv_op = 'P' ).
    check_shared_flow( iv_op = 'D' ).
    check_shared_flow( iv_op = 'AN2' ).
    check_shared_flow( iv_op = 'A' iv_act = abap_true ).
    check_shared_flow( iv_op = 'NC' iv_act = abap_true ).
  ENDMETHOD.

  METHOD current_case_accounts.
    check_case_amount( '51282.85' ).
    check_case_amount( '413.84' ).
    check_case_amount( '249.20' ).
  ENDMETHOD.

  METHOD two_tax_categories.
    given_counter( ).
    APPEND VALUE #( doc_type_code = 'ZZZ' role_code = 'RWHC' posting_side = 'H' ) TO roles.
    APPEND VALUE #( ct_uuid = co_ct mat_uuid = co_mat
      gl_uuid = '0000000000000000000000000000C305' gl_role = 'RWHC' saknr = '0000610000' ) TO accounts.
    docs[ 1 ]-items = VALUE #( ( role_code = 'RWHE' amount = '55.14' waers = 'USD'
      prctr = '0000000999' campana = '459' allocation = '1' )
      ( role_code = 'RWHC' amount = '20.11' waers = 'USD'
        prctr = '0000000111' campana = '123' allocation = '0' ) ).
    reload_counter( ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = result-total_amount exp = CONV zreing_ca_calc_amt( '75.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RWHE' ]-amount
      exp = CONV zreing_ca_calc_amt( '-55.14' ) ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RWHC' ]-amount
      exp = CONV zreing_ca_calc_amt( '-20.11' ) ).
  ENDMETHOD.
  METHOD cebe_case.
    configure( iv_nominal = iv_nominal ).
    DATA(template) = docs[ 1 ]-items[ 1 ].
    DATA case_items TYPE zif_reing_contab_types=>ty_doc_item_t.
    LOOP AT it_sources INTO DATA(source).
      DATA(item) = template.
      item-amount = source-amount. item-prctr = source-prctr.
      item-kostl = |4590122{ source-prctr+7(3) }|.
      item-allocation = '0'.
      APPEND item TO case_items.
    ENDLOOP.
    docs[ 1 ]-items = case_items.
    step-kostl_rule = 'Z'.
    DATA(companies) = VALUE tt_company(
      ( companycode = 'OVR' companycodeparametertype = 'ZIC003' companycodeparametervalue = 'X' )
      ( companycode = 'OVR' companycodeparametertype = 'ZIDMEL' companycodeparametervalue = '147' ) ).
    sql_env->get_double( 'ZI_COMPANYCODEADDLINFORMATION' )->clear( ).
    sql_env->insert_test_data( companies ).
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( ) it_step_a = VALUE #( )
      is_flow_step = step iv_contract_prctr = iv_prctr iv_contract_ext = 'Simetrik'
      it_campana_map = VALUE #( ( campana_de = '459' matnr = line-matnr campana_para = '954' ) ) ).
    cut->zif_reing_contab~set_prior_documents( docs ).
    cut->zif_reing_contab~set_fi_poster( poster ).
    IF iv_nominal = abap_true. cut->enable_nominal( ). ENDIF.
  ENDMETHOD.
  METHOD assert_cebe_pair.
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = result-items exp = poster->items ).
    DATA sum TYPE zreing_ca_line_a-net_amt.
    LOOP AT result-items INTO DATA(item).
      cl_abap_unit_assert=>assert_equals( act = item-item_num exp = sy-tabix ).
      cl_abap_unit_assert=>assert_equals( act = item-prctr exp = iv_pc ).
      cl_abap_unit_assert=>assert_equals( act = item-kostl exp = iv_kostl ).
      cl_abap_unit_assert=>assert_equals( act = item-campana exp = '459' ).
      cl_abap_unit_assert=>assert_equals( act = item-allocation exp = '0' ).
      cl_abap_unit_assert=>assert_equals( act = item-waers exp = iv_currency ).
      cl_abap_unit_assert=>assert_equals( act = abs( item-amount ) exp = iv_total ).
      sum += item-amount.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = sum exp = 0 ).
  ENDMETHOD.
  METHOD cebe_mco.
    cebe_case( VALUE #( ( amount = '-18930.79' prctr = '0000000199' )
      ( amount = '-1752.85' prctr = '0000000400' ) ( amount = '-14369.87' prctr = '0000000630' ) ) ).
    assert_cebe_pair( iv_total = '35053.51' ).
  ENDMETHOD.
  METHOD cebe_dru.
    cebe_case( VALUE #( ( amount = '-8805.22' prctr = '0000000199' )
      ( amount = '-943.42' prctr = '0000000200' ) ( amount = '-943.42' prctr = '0000000400' )
      ( amount = '-2830.37' prctr = '0000000630' ) ) ).
    assert_cebe_pair( iv_total = '13522.43' ).
  ENDMETHOD.
  METHOD cebe_mpo.
    cebe_case( VALUE #( ( amount = '-2306.15' prctr = '0000000200' ) ) ).
    assert_cebe_pair( iv_total = '2306.15' ).
  ENDMETHOD.
  METHOD cebe_alt_contract.
    cebe_case( it_sources = VALUE #( ( amount = '-10.25' prctr = '0000000200' ) ) iv_prctr = '250' ).
    assert_cebe_pair( iv_total = '10.25' iv_pc = '0000000250' iv_kostl = '9540147250' ).
  ENDMETHOD.
  METHOD cebe_nominal_group.
    cebe_case( it_sources = VALUE #( ( amount = '-10.11' prctr = '0000000200' )
      ( amount = '-20.22' prctr = '0000000300' ) ) iv_nominal = abap_true ).
    assert_cebe_pair( iv_total = '30.33' iv_currency = 'BRL' ).
  ENDMETHOD.
  METHOD cebe_empty_reject.
    cebe_case( it_sources = VALUE #( ( amount = '-1' prctr = '0000000200' ) ) iv_prctr = space ).
    DATA(result) = run( ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '012'
      WITH line-ct_id line-matnr step-doc_type_code INTO DATA(expected).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-error_msg exp = expected ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD cebe_empty_zero_skips.
    cebe_case( it_sources = VALUE #( ( amount = 0 prctr = '0000000200' ) ) iv_prctr = space ).
    DATA(items) = cut->build( ).
    cl_abap_unit_assert=>assert_initial( items ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
  ENDMETHOD.
  METHOD cebe_empty_unmarked_skips.
    cebe_case( it_sources = VALUE #( ( amount = 1 prctr = '0000000200' ) ) iv_prctr = space ).
    docs[ 1 ]-items[ 1 ]-role_code = 'RWHP'.
    cut->zif_reing_contab~set_prior_documents( docs ).
    DATA(items) = cut->build( ).
    cl_abap_unit_assert=>assert_initial( items ).
    cl_abap_unit_assert=>assert_initial( cut->pending_error( ) ).
  ENDMETHOD.
  METHOD cebe_reset_after_success.
    cebe_case( VALUE #( ( amount = '-1' prctr = '0000000200' ) ) ).
    assert_cebe_pair( iv_total = 1 ).
    poster->post_calls = 0.
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( )
      it_step_a = VALUE #( ) is_flow_step = step ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
    cl_abap_unit_assert=>assert_not_initial( cut->prior_docs( ) ).
  ENDMETHOD.
  METHOD cebe_invalid_company.
    configure( ).
    map_recl_context( iv_rule = 'R' iv_prctr = space ).
    map_recl_error( '007' ).
  ENDMETHOD.
  METHOD cebe_actzzz_unchanged.
    configure( iv_act = abap_true ).
    map_recl_context( iv_prctr = '250' ).
    assert_pair( is_result = run( ) iv_act = abap_true iv_kostl = '8881333999' ).
  ENDMETHOD.
  METHOD cebe_late_map_error.
    cebe_case( VALUE #( ( amount = '-1' prctr = '0000000200' )
      ( amount = '-2' prctr = '0000000300' ) ) ).
    docs[ 1 ]-items[ 2 ]-kostl = '7770122300'.
    cut->zif_reing_contab~set_prior_documents( docs ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_true( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = poster->post_calls exp = 0 ).
  ENDMETHOD.
  METHOD cebe_grouped_sources_over_999.
    DATA sources TYPE zif_reing_contab_types=>ty_doc_item_t.
    DO 501 TIMES.
      APPEND VALUE #( amount = '-0.01' prctr = '0000000200' ) TO sources.
    ENDDO.
    cebe_case( sources ).
    assert_cebe_pair( iv_total = '5.01' ).
  ENDMETHOD.
  METHOD check_cebe_operation.
    cebe_case( VALUE #( ( amount = '-1' prctr = '0000000200' )
      ( amount = '-2' prctr = '0000000300' ) ) ).
    line-op_type = iv_op. step-op_type = iv_op.
    DATA(current_flow) = VALUE tt_flow( FOR f IN flow WHERE ( op_type = 'F' ) ( f ) ).
    LOOP AT current_flow ASSIGNING FIELD-SYMBOL(<flow>).
      <flow>-op_type = iv_op.
    ENDLOOP.
    sql_env->get_double( 'ZREING_DOCFLOW_C' )->clear( ).
    sql_env->insert_test_data( current_flow ).
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( ) it_step_a = VALUE #( )
      is_flow_step = step iv_contract_prctr = '999'
      it_campana_map = VALUE #( ( campana_de = '459' matnr = line-matnr campana_para = '954' ) ) ).
    assert_cebe_pair( iv_total = 3 ).
  ENDMETHOD.
  METHOD cebe_shared_zzz_operations.
    check_cebe_operation( 'F' ).
    check_cebe_operation( 'P' ).
    check_cebe_operation( 'D' ).
    check_cebe_operation( 'AN2' ).
  ENDMETHOD.

  METHOD text_et_zzz_roles.
    configure( ).
    DATA(result) = run( ).
    assert_pair( is_result = result iv_kostl = '4591333999' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RECL' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RREE' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
  ENDMETHOD.
  METHOD text_et_actzzz_roles.
    configure( iv_act = abap_true ).
    DATA(result) = run( ).
    assert_pair( is_result = result iv_act = abap_true iv_kostl = '4591333999' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RECL' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RREE' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
  ENDMETHOD.
  METHOD text_et_nominal_counter.
    given_counter( iv_nominal = abap_true ).
    DATA(result) = run( ).
    assert_counter_pair( is_result = result iv_currency = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RWHE' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RECL' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
  ENDMETHOD.
  METHOD text_et_after_grouping.
    cebe_case( VALUE #( ( amount = '-10.11' prctr = '0000000200' )
      ( amount = '-20.22' prctr = '0000000300' ) ) ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = lines( result-items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RECL' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ role_code = 'RREE' ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ 1 ]-prctr exp = '0000000999' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ 1 ]-kostl exp = '9540147999' ).
    cl_abap_unit_assert=>assert_equals( act = result-total_amount exp = CONV zreing_ca_calc_amt( '30.33' ) ).
  ENDMETHOD.
  METHOD text_external_context_reset.
    configure( ).
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( )
      it_step_a = VALUE #( ) is_flow_step = step iv_contract_ext = 'Contract-B' ).
    DATA(first) = run( ).
    cl_abap_unit_assert=>assert_false( first-has_error ).
    cl_abap_unit_assert=>assert_equals( act = first-items[ 1 ]-item_text
      exp = 'Reintegros | EBA X RCV | Contract-B' ).
    cl_abap_unit_assert=>assert_equals( act = first-items[ 2 ]-item_text
      exp = 'Reintegros | EBA X RCV | Contract-B' ).
    cut->zif_reing_contab~set_context( is_line_a = line it_line_pc = VALUE #( )
      it_step_a = VALUE #( ) is_flow_step = step ).
    DATA(second) = run( ).
    cl_abap_unit_assert=>assert_false( second-has_error ).
    cl_abap_unit_assert=>assert_equals( act = second-items[ 1 ]-item_text
      exp = 'Reintegros | EBA X RCV' ).
    cl_abap_unit_assert=>assert_equals( act = second-items[ 2 ]-item_text
      exp = 'Reintegros | EBA X RCV' ).
  ENDMETHOD.

  METHOD text_external_override_company.
    configure( iv_rule = 'O' ).
    DATA(result) = run( ).
    cl_abap_unit_assert=>assert_false( result-has_error ).
    cl_abap_unit_assert=>assert_equals( act = result-bukrs exp = 'OVR' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ 1 ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
    cl_abap_unit_assert=>assert_equals( act = result-items[ 2 ]-item_text
      exp = 'Reintegros | EBA X RCV | Simetrik' ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_cebe_grouping DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_reing_contab_doc_recl.
    DATA template TYPE zif_reing_contab_types=>ty_doc_item.
    METHODS setup.
    METHODS dimensions_separate FOR TESTING.
    METHODS opposite_sides_separate FOR TESTING.
    METHODS first_order_exact_sum FOR TESTING.
    METHODS grouped_amount_overflow FOR TESTING.
    METHODS grouped_item_limit FOR TESTING.
    METHODS many_sources_one_group FOR TESTING.
ENDCLASS.
CLASS ltcl_cebe_grouping IMPLEMENTATION.
  METHOD setup.
    cut = NEW lcl_cb03_recl_probe( ).
    template = VALUE #( role_code = 'RECL' posting_context = 'GL' hkont = '0000410000'
      posting_side = 'S' amount = '1.11' waers = 'USD' kostl = '9540147999'
      prctr = '0000000999' campana = '459' allocation = '0' zuonr = 'SOURCE' ).
  ENDMETHOD.
  METHOD dimensions_separate.
    DATA names TYPE string_table.
    names = VALUE #( ( `ROLE_CODE` ) ( `POSTING_CONTEXT` ) ( `HKONT` ) ( `PARTNER` )
      ( `POSTING_SIDE` ) ( `WAERS` ) ( `KOSTL` ) ( `PRCTR` ) ( `CAMPANA` )
      ( `ALLOCATION` ) ( `ZUONR` ) ).
    LOOP AT names INTO DATA(name).
      DATA(other) = template.
      ASSIGN COMPONENT name OF STRUCTURE other TO FIELD-SYMBOL(<field>).
      cl_abap_unit_assert=>assert_subrc( ).
      <field> = 'X'.
      DATA(items) = cut->consolidate_mapped_items( VALUE #( ( template ) ( other ) ) ).
      cl_abap_unit_assert=>assert_equals( act = lines( items ) exp = 2 msg = name ).
    ENDLOOP.
  ENDMETHOD.
  METHOD opposite_sides_separate.
    DATA(other) = template. other-posting_side = 'H'. other-amount = '-1.11'.
    DATA(items) = cut->consolidate_mapped_items( VALUE #( ( template ) ( other ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-amount + items[ 2 ]-amount exp = 0 ).
  ENDMETHOD.
  METHOD first_order_exact_sum.
    DATA(second) = template. second-zuonr = 'SECOND'.
    DATA(third) = template. third-amount = '2.22'.
    DATA(items) = cut->consolidate_mapped_items( VALUE #( ( template ) ( second ) ( third ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( items ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( '3.33' ) ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-zuonr exp = 'SOURCE' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 2 ]-zuonr exp = 'SECOND' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-item_num exp = '001' ).
    cl_abap_unit_assert=>assert_equals( act = items[ 2 ]-item_num exp = '002' ).
  ENDMETHOD.
  METHOD grouped_amount_overflow.
    template-amount = '9999999999999.99'.
    DATA(items) = cut->consolidate_mapped_items( VALUE #( ( template ) ( template ) ) ).
    cl_abap_unit_assert=>assert_initial( items ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '013' WITH space INTO DATA(expected).
    cl_abap_unit_assert=>assert_equals( act = CAST lcl_cb03_recl_probe( cut )->pending_error( ) exp = expected ).
  ENDMETHOD.
  METHOD grouped_item_limit.
    DATA source TYPE zif_reing_contab_types=>ty_doc_item_t.
    DO 1000 TIMES.
      template-zuonr = |{ sy-index }|.
      APPEND template TO source.
    ENDDO.
    DATA(items) = cut->consolidate_mapped_items( source ).
    cl_abap_unit_assert=>assert_initial( items ).
    MESSAGE ID 'ZREING_CA' TYPE zif_reing_ca_c=>fx_projection-message_type NUMBER '014' WITH space INTO DATA(expected).
    cl_abap_unit_assert=>assert_equals( act = CAST lcl_cb03_recl_probe( cut )->pending_error( ) exp = expected ).
  ENDMETHOD.
  METHOD many_sources_one_group.
    DATA source TYPE zif_reing_contab_types=>ty_doc_item_t.
    DO 1100 TIMES. APPEND template TO source. ENDDO.
    DATA(items) = cut->consolidate_mapped_items( source ).
    cl_abap_unit_assert=>assert_equals( act = lines( items ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = items[ 1 ]-amount exp = CONV zreing_ca_calc_amt( 1221 ) ).
    cl_abap_unit_assert=>assert_initial( CAST lcl_cb03_recl_probe( cut )->pending_error( ) ).
  ENDMETHOD.
ENDCLASS.
