" V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
CLASS ltcl_tx_scope DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_row15,
             c1 TYPE string,
             c2 TYPE string,
             c3 TYPE string,
             c4 TYPE string,
             c5 TYPE string,
             c6 TYPE string,
             c7 TYPE string,
             c8 TYPE string,
             c9 TYPE string,
             c10 TYPE string,
             c11 TYPE string,
             c12 TYPE string,
             c13 TYPE string,
             c14 TYPE string,
             c15 TYPE string,
           END OF ty_row15,
           tt_row15 TYPE STANDARD TABLE OF ty_row15 WITH EMPTY KEY.
    TYPES: BEGIN OF ty_row12,
             c1 TYPE string,
             c2 TYPE string,
             c3 TYPE string,
             c4 TYPE string,
             c5 TYPE string,
             c6 TYPE string,
             c7 TYPE string,
             c8 TYPE string,
             c9 TYPE string,
             c10 TYPE string,
             c11 TYPE string,
             c12 TYPE string,
           END OF ty_row12,
           tt_row12 TYPE STANDARD TABLE OF ty_row12 WITH EMPTY KEY.
    CLASS-DATA mo_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_teardown.
    METHODS teardown.
    CLASS-METHODS seed.
    CLASS-METHODS headers RETURNING VALUE(rs_row) TYPE ty_row15.
    CLASS-METHODS valid_row RETURNING VALUE(rs_row) TYPE ty_row15.
    CLASS-METHODS workbook
      IMPORTING it_rows TYPE tt_row15 iv_legacy TYPE abap_bool DEFAULT abap_false
                iv_template TYPE xstring OPTIONAL
      RETURNING VALUE(rv_file) TYPE xstring.
    CLASS-METHODS release_env CHANGING co_env TYPE REF TO if_osql_test_environment.
    TYPES ty_failed TYPE RESPONSE FOR FAILED LATE zi_reingtxrule.
    TYPES ty_reported TYPE RESPONSE FOR REPORTED LATE zi_reingtxrule.
    TYPES ty_upload_reported TYPE RESPONSE FOR REPORTED zi_reingtxrule.
    TYPES ty_rule TYPE STRUCTURE FOR READ RESULT zi_reingtxrule.
    DATA mo_cut TYPE REF TO lhc_TxRule.
    CLASS-METHODS class_setup.
    CLASS-METHODS isolated_handler RETURNING VALUE(ro_cut) TYPE REF TO lhc_TxRule.
    CLASS-METHODS bootstrap.
    METHODS setup.
    METHODS read_rule RETURNING VALUE(rs_rule) TYPE ty_rule.
    METHODS persist_rule IMPORTING iv_id TYPE zreing_tx_rule_a-tx_rule_id DEFAULT 'VALFX003'.
    METHODS call_scope EXPORTING es_failed TYPE ty_failed
      es_reported TYPE ty_reported.
    METHODS call_overlap EXPORTING es_failed TYPE ty_failed
      es_reported TYPE ty_reported.
    METHODS call_upload IMPORTING it_rows TYPE tt_row15
      EXPORTING es_reported TYPE ty_upload_reported.
    METHODS upload_three_fields FOR TESTING.
    METHODS upload_error_no_create FOR TESTING.
    METHODS scope_invalid FOR TESTING.
    METHODS check_scope_invalid IMPORTING iv_variant TYPE i.
    METHODS check_different_scope IMPORTING iv_variant TYPE i.
    METHODS scope_optional FOR TESTING.
    METHODS same_scope_overlap FOR TESTING.
    METHODS new_scope_differs FOR TESTING.
    METHODS batch_scope_isolated FOR TESTING.
    METHODS self_rule_ignored FOR TESTING.
ENDCLASS.
CLASS ltcl_tx_scope IMPLEMENTATION.
  METHOD teardown.
    IF mo_env IS BOUND.
      mo_env->clear_doubles( ).
    ENDIF.
    CLEAR mo_cut.
  ENDMETHOD.
  METHOD release_env.
    IF co_env IS BOUND.
      co_env->destroy( ).
      CLEAR co_env.
    ENDIF.
  ENDMETHOD.
  METHOD class_teardown.
    release_env( CHANGING co_env = mo_env ).
  ENDMETHOD.
  METHOD headers.
    rs_row = VALUE #( c1 = 'Regla (ID)' c2 = 'Pais' c3 = 'Descripcion'
      c4 = 'Tipo Impuesto' c5 = 'Tasa (%)' c6 = 'Vigente Desde'
      c7 = 'Vigente Hasta' c8 = 'Proveedor (LIFNR)' c9 = 'Especificidad'
      c10 = 'Material (MATNR)' c11 = 'Gross Up' c12 = 'Estado'
      c13 = 'Pais Prestadora' c14 = 'Soc. Prestadora' c15 = 'Soc. Receptora' ).
  ENDMETHOD.
  METHOD valid_row.
    rs_row = VALUE #( c1 = 'IGNORED_ID' c2 = 'UY' c3 = 'VAL-TX synthetic'
      c4 = 'WHT' c5 = '10.00' c6 = '2026-01-01' c7 = '2026-12-31'
      c9 = 'IGNORED_SPEC' c12 = 'IGNORED_STATE'
      c13 = 'BR' c14 = 'B901' c15 = 'B902' ).
  ENDMETHOD.
  METHOD workbook.
    TRY.
        DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
        DATA(lt_rows) = it_rows.
        IF iv_template IS NOT INITIAL.
          DATA(lo_read_sheet) = xco_cp_xlsx=>document->for_file_content( iv_template
            )->read_access( )->get_workbook( )->worksheet->at_position( 1 ).
          DATA(lo_header_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
            )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
            )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
            )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'O' )
            )->to_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) )->get_pattern( ).
          DATA lt_template_header TYPE tt_row15.
          lo_read_sheet->select( lo_header_pattern )->row_stream( )->operation->write_to(
            REF #( lt_template_header ) )->if_xco_xlsx_ra_operation~execute( ).
          cl_abap_unit_assert=>assert_equals( act = lines( lt_template_header ) exp = 1 ).
          lt_rows[ 1 ] = lt_template_header[ 1 ].
        ENDIF.
        DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).
        DATA(lv_last) = COND string( WHEN iv_legacy = abap_true THEN 'L' ELSE 'O' ).
        DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
          )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
          )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
          )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( lv_last )
          )->get_pattern( ).
        IF iv_legacy = abap_true.
          DATA(lt_old) = CORRESPONDING tt_row12( lt_rows ).
          lo_sheet->select( lo_pattern )->row_stream( )->operation->write_from( REF #( lt_old )
            )->if_xco_xlsx_wa_operation~execute( ).
        ELSE.
          lo_sheet->select( lo_pattern )->row_stream( )->operation->write_from( REF #( lt_rows )
            )->if_xco_xlsx_wa_operation~execute( ).
        ENDIF.
        rv_file = lo_write->get_file_content( ).
      CATCH cx_root INTO DATA(lx_fixture).
        release_env( CHANGING co_env = mo_env ).
        cl_abap_unit_assert=>fail( msg = lx_fixture->get_text( ) ).
        RETURN.
    ENDTRY.
    cl_abap_unit_assert=>assert_not_initial( rv_file ).
  ENDMETHOD.
  METHOD class_setup.
    TRY.
        mo_env = cl_osql_test_environment=>create(
          i_dependency_list = VALUE #( ( 'ZREING_TX_TYPE_C' ) ( 'I_COUNTRY' ) ( 'I_COMPANYCODE' ) ( 'ZREING_TX_RULE_A' ) ) ).
        seed( ).
        cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_TX_TYPE_C' ) ).
        cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'I_COUNTRY' ) ).
        cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'I_COMPANYCODE' ) ).
        cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_TX_RULE_A' ) ).
        bootstrap( ).
      CATCH cx_root INTO DATA(lx_setup).
        release_env( CHANGING co_env = mo_env ).
        cl_abap_unit_assert=>fail( msg = lx_setup->get_text( ) ).
        RETURN.
    ENDTRY.
  ENDMETHOD.
  METHOD seed.
    cl_abap_unit_assert=>assert_bound( mo_env ).
    mo_env->clear_doubles( ).
    DATA lt_tax TYPE STANDARD TABLE OF zreing_tx_type_c WITH EMPTY KEY.
    lt_tax = VALUE #( ( mandt = sy-mandt tax_type = 'WHT' active = abap_true ) ).
    mo_env->insert_test_data( lt_tax ).
    DATA lt_country TYPE STANDARD TABLE OF i_country WITH EMPTY KEY.
    lt_country = VALUE #( ( Country = 'BR' ) ( Country = 'UY' ) ).
    mo_env->insert_test_data( lt_country ).
    DATA lt_company TYPE STANDARD TABLE OF i_companycode WITH EMPTY KEY.
    lt_company = VALUE #( ( CompanyCode = 'B901' ) ( CompanyCode = 'B902' )
                         ( CompanyCode = 'B903' ) ).
    mo_env->insert_test_data( lt_company ).
  ENDMETHOD.
  METHOD isolated_handler.
    CREATE OBJECT ro_cut FOR TESTING.
    ro_cut->mv_isolated_test = abap_true.
  ENDMETHOD.
  METHOD bootstrap.
    " No injection is installed until SETUP: each original EML body must return.
    DATA(lo_cut) = isolated_handler( ).
    cl_abap_unit_assert=>assert_true( lo_cut->mv_isolated_test ).
    DATA ls_failed TYPE RESPONSE FOR FAILED LATE zi_reingtxrule.
    DATA ls_reported TYPE RESPONSE FOR REPORTED LATE zi_reingtxrule.
    DATA ls_upload_reported TYPE RESPONSE FOR REPORTED zi_reingtxrule.
    lo_cut->validate_country( EXPORTING keys = VALUE #( ( TxRuleId = 'VALFX001'
      %is_draft = if_abap_behv=>mk-on ) ) CHANGING failed = ls_failed reported = ls_reported ).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
    lo_cut->validate_overlap( EXPORTING keys = VALUE #( ( TxRuleId = 'VALFX001'
      %is_draft = if_abap_behv=>mk-on ) ) CHANGING failed = ls_failed reported = ls_reported ).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
    DATA(lv_file) = workbook( it_rows = VALUE #( ( headers( ) ) ( valid_row( ) ) ) ).
    DATA(ls_parsed) = NEW zcl_reing_tx_upload_hdl( )->import_file( lv_file ).
    cl_abap_unit_assert=>assert_false( ls_parsed-aborted ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_parsed-create_lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_parsed-results ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_parsed-results[ 1 ]-status exp = 'S' ).
    DATA(lv_b64) = xco_cp=>xstring( lv_file )->as_string( xco_cp_binary=>text_encoding->base64 )->value.
    lo_cut->UploadRules( EXPORTING keys = VALUE #( ( %param-FileContent = lv_b64 ) )
      CHANGING reported = ls_upload_reported ).
    cl_abap_unit_assert=>assert_initial( ls_upload_reported ).
    DATA(ls_bad_header) = headers( ).
    CLEAR ls_bad_header-c4.
    lv_file = workbook( it_rows = VALUE #( ( ls_bad_header ) ( valid_row( ) ) ) ).
    lv_b64 = xco_cp=>xstring( lv_file )->as_string( xco_cp_binary=>text_encoding->base64 )->value.
    lo_cut->UploadRules( EXPORTING keys = VALUE #( ( %param-FileContent = lv_b64 ) )
      CHANGING reported = ls_upload_reported ).
    cl_abap_unit_assert=>assert_not_initial( ls_upload_reported-txrule ).
    cl_abap_unit_assert=>assert_equals( act = ls_upload_reported-txrule[ 1 ]-%msg->m_severity
      exp = if_abap_behv_message=>severity-error ).
    DATA lo_unbound TYPE REF TO if_osql_test_environment.
    release_env( CHANGING co_env = lo_unbound ).
    cl_abap_unit_assert=>assert_not_bound( lo_unbound ).
  ENDMETHOD.
  METHOD setup.
    CLEAR: lcl_tx_fixture=>mt_rules, lcl_tx_fixture=>mt_created, lcl_tx_fixture=>mv_scope_reads, lcl_tx_fixture=>mv_overlap_reads, lcl_tx_fixture=>mv_creates.
    TRY.
        seed( ).
      CATCH cx_root INTO DATA(lx_setup).
        release_env( CHANGING co_env = mo_env ).
        cl_abap_unit_assert=>fail( msg = lx_setup->get_text( ) ).
        RETURN.
    ENDTRY.
    mo_cut = isolated_handler( ).
    TEST-INJECTION tx_scope_read.
      lt_rules = lcl_tx_fixture=>mt_rules.
      lcl_tx_fixture=>mv_scope_reads += 1.
    END-TEST-INJECTION.
    TEST-INJECTION tx_overlap_read.
      lt_rules = lcl_tx_fixture=>mt_rules.
      lcl_tx_fixture=>mv_overlap_reads += 1.
    END-TEST-INJECTION.
    TEST-INJECTION tx_upload_create.
      lcl_tx_fixture=>mt_created = lt_create.
      lcl_tx_fixture=>mv_creates += 1.
      CLEAR: lt_rep, lt_fail, lt_map.
    END-TEST-INJECTION.
  ENDMETHOD.
  METHOD read_rule.
    rs_rule = VALUE #( TxRuleId = 'VALFX001' %is_draft = if_abap_behv=>mk-on
      Country = 'UY' CountryPrest = 'BR' BukrsPrest = 'B901' BukrsRecv = 'B902'
      TaxType = 'WHT' Rate = '10.00' ValidFrom = '20260101' ValidTo = '20261231' TxStatus = 'AC' ).
  ENDMETHOD.
  METHOD persist_rule.
    DATA lt_active TYPE STANDARD TABLE OF zreing_tx_rule_a WITH EMPTY KEY.
    lt_active = VALUE #( ( client = sy-mandt tx_rule_id = iv_id country = 'UY'
      country_prest = 'BR' bukrs_prest = 'B901' bukrs_recv = 'B902' tax_type = 'WHT'
      rate = '10.00' valid_from = '20260101' valid_to = '20261231' tx_status = 'AC' ) ).
    mo_env->insert_test_data( lt_active ).
  ENDMETHOD.
  METHOD call_scope.
    CLEAR: es_failed, es_reported, lcl_tx_fixture=>mv_scope_reads.
    cl_abap_unit_assert=>assert_true( mo_cut->mv_isolated_test ).
    mo_cut->validate_country( EXPORTING keys = CORRESPONDING #( lcl_tx_fixture=>mt_rules )
      CHANGING failed = es_failed reported = es_reported ).
    cl_abap_unit_assert=>assert_equals( act = lcl_tx_fixture=>mv_scope_reads exp = 1 ).
  ENDMETHOD.
  METHOD call_overlap.
    CLEAR: es_failed, es_reported, lcl_tx_fixture=>mv_overlap_reads.
    cl_abap_unit_assert=>assert_true( mo_cut->mv_isolated_test ).
    mo_cut->validate_overlap( EXPORTING keys = CORRESPONDING #( lcl_tx_fixture=>mt_rules )
      CHANGING failed = es_failed reported = es_reported ).
    cl_abap_unit_assert=>assert_equals( act = lcl_tx_fixture=>mv_overlap_reads exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mo_cut->mt_active_overlap ).
  ENDMETHOD.
  METHOD call_upload.
    CLEAR es_reported.
    cl_abap_unit_assert=>assert_true( mo_cut->mv_isolated_test ).
    DATA(lv_file) = workbook( it_rows = it_rows ).
    DATA(lv_b64) = xco_cp=>xstring( lv_file )->as_string( xco_cp_binary=>text_encoding->base64 )->value.
    mo_cut->UploadRules( EXPORTING keys = VALUE #( ( %param-FileContent = lv_b64 ) )
      CHANGING reported = es_reported ).
  ENDMETHOD.
  METHOD upload_three_fields.
    call_upload( EXPORTING it_rows = VALUE #( ( headers( ) ) ( valid_row( ) ) )
      IMPORTING es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
    cl_abap_unit_assert=>assert_equals( act = lcl_tx_fixture=>mv_creates exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lcl_tx_fixture=>mt_created ) exp = 1 ).
    DATA(ls_created) = lcl_tx_fixture=>mt_created[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_created-%is_draft exp = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-%cid exp = 'TX_UPLOAD_1' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-CountryPrest exp = 'BR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-BukrsPrest exp = 'B901' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-BukrsRecv exp = 'B902' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-%control-CountryPrest exp = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-%control-BukrsPrest exp = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-%control-BukrsRecv exp = if_abap_behv=>mk-on ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-Country exp = 'UY' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-TaxType exp = 'WHT' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-Rate exp = CONV zreing_tx_rate( '10.00' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-ValidFrom exp = CONV d( '20260101' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-ValidTo exp = CONV d( '20261231' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-TxStatus exp = 'AC' ).
    cl_abap_unit_assert=>assert_equals( act = ls_created-Description exp = 'VAL-TX synthetic' ).
    cl_abap_unit_assert=>assert_initial( ls_created-Matnr ).
    cl_abap_unit_assert=>assert_initial( ls_created-Lifnr ).
    cl_abap_unit_assert=>assert_initial( ls_created-GrossUp ).
  ENDMETHOD.
  METHOD upload_error_no_create.
    DATA(ls_bad) = valid_row( ).
    CLEAR ls_bad-c3.
    call_upload( EXPORTING it_rows = VALUE #( ( headers( ) ) ( valid_row( ) ) ( ls_bad ) )
      IMPORTING es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_equals( act = lcl_tx_fixture=>mv_creates exp = 0 ).
    cl_abap_unit_assert=>assert_initial( lcl_tx_fixture=>mt_created ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_reported-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%msg->m_severity
      exp = if_abap_behv_message=>severity-error ).
  ENDMETHOD.
  METHOD scope_invalid.
    check_scope_invalid( 1 ).
    check_scope_invalid( 2 ).
    check_scope_invalid( 3 ).
    check_scope_invalid( 4 ).
  ENDMETHOD.
  METHOD check_scope_invalid.
    DATA(ls_rule) = read_rule( ).
    DATA ls_elements LIKE LINE OF lcl_tx_fixture=>mt_created.
    CASE iv_variant.
      WHEN 1. ls_rule-Country = 'ZZ'. ls_elements-%control-Country = if_abap_behv=>mk-on.
      WHEN 2. ls_rule-CountryPrest = 'ZZ'. ls_elements-%control-CountryPrest = if_abap_behv=>mk-on.
      WHEN 3. ls_rule-BukrsPrest = 'B999'. ls_elements-%control-BukrsPrest = if_abap_behv=>mk-on.
      WHEN 4. ls_rule-BukrsRecv = 'B999'. ls_elements-%control-BukrsRecv = if_abap_behv=>mk-on.
    ENDCASE.
    lcl_tx_fixture=>mt_rules = VALUE #( ( ls_rule ) ).
    call_scope( IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_failed-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_reported-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_failed-txrule[ 1 ]-%tky exp = ls_rule-%tky ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%tky exp = ls_rule-%tky ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%msg->m_severity
      exp = if_abap_behv_message=>severity-error ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%element
      exp = ls_elements-%control ).
    CLEAR ls_elements.
  ENDMETHOD.
  METHOD scope_optional.
    DATA(ls_rule) = read_rule( ).
    CLEAR: ls_rule-Country, ls_rule-CountryPrest, ls_rule-BukrsPrest, ls_rule-BukrsRecv.
    lcl_tx_fixture=>mt_rules = VALUE #( ( ls_rule ) ).
    call_scope( IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
    ls_rule-CountryPrest = 'BR'.
    lcl_tx_fixture=>mt_rules = VALUE #( ( ls_rule ) ).
    call_scope( IMPORTING es_failed = ls_failed es_reported = ls_reported ).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
  ENDMETHOD.
  METHOD same_scope_overlap.
    persist_rule( ).
    lcl_tx_fixture=>mt_rules = VALUE #( ( read_rule( ) ) ).
    call_overlap( IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_failed-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_reported-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_failed-txrule[ 1 ]-%tky exp = lcl_tx_fixture=>mt_rules[ 1 ]-%tky ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%msg->m_severity
      exp = if_abap_behv_message=>severity-error ).
  ENDMETHOD.
  METHOD new_scope_differs.
    persist_rule( ).
    check_different_scope( 1 ).
    check_different_scope( 2 ).
    check_different_scope( 3 ).
  ENDMETHOD.
  METHOD check_different_scope.
    DATA(ls_rule) = read_rule( ).
    CASE iv_variant.
      WHEN 1. ls_rule-CountryPrest = 'UY'.
      WHEN 2. ls_rule-BukrsPrest = 'B903'.
      WHEN 3. ls_rule-BukrsRecv = 'B903'.
    ENDCASE.
    lcl_tx_fixture=>mt_rules = VALUE #( ( ls_rule ) ).
    call_overlap( IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
  ENDMETHOD.
  METHOD batch_scope_isolated.
    persist_rule( ).
    DATA(ls_first) = read_rule( ).
    DATA(ls_second) = read_rule( ).
    ls_second-TxRuleId = 'VALFX002'.
    ls_second-BukrsRecv = 'B903'.
    lcl_tx_fixture=>mt_rules = VALUE #( ( ls_first ) ( ls_second ) ).
    call_overlap( IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_failed-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_failed-txrule[ 1 ]-%tky exp = ls_first-%tky ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_reported-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%tky exp = ls_first-%tky ).
    lcl_tx_fixture=>mt_rules = VALUE #( ( ls_second ) ( ls_first ) ).
    call_overlap( IMPORTING es_failed = ls_failed es_reported = ls_reported ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_failed-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_failed-txrule[ 1 ]-%tky exp = ls_first-%tky ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_reported-txrule ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_reported-txrule[ 1 ]-%tky exp = ls_first-%tky ).
  ENDMETHOD.
  METHOD self_rule_ignored.
    persist_rule( iv_id = 'VALFX001' ).
    lcl_tx_fixture=>mt_rules = VALUE #( ( read_rule( ) ) ).
    call_overlap( IMPORTING es_failed = DATA(ls_failed) es_reported = DATA(ls_reported) ).
    cl_abap_unit_assert=>assert_initial( ls_failed ).
    cl_abap_unit_assert=>assert_initial( ls_reported ).
  ENDMETHOD.
ENDCLASS.
