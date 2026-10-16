" V001 (CC) - VAL-TX-01 (Brazil): isolated handler tests.
CLASS ltcl_tx_xlsx DEFINITION FINAL FOR TESTING
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
    DATA mo_cut TYPE REF TO zcl_reing_tx_upload_hdl.
    CLASS-METHODS class_setup.
    METHODS setup.
    METHODS assert_line IMPORTING is_result TYPE zcl_reing_tx_upload_hdl=>ty_import_result
      is_expected TYPE zcl_reing_tx_upload_hdl=>ty_create_line.
    METHODS expected_line RETURNING VALUE(rs_line) TYPE zcl_reing_tx_upload_hdl=>ty_create_line.
    METHODS legacy_12cols FOR TESTING.
    METHODS new_15cols FOR TESTING.
    METHODS new_cols_empty FOR TESTING.
    METHODS country_empty FOR TESTING.
    METHODS required_header FOR TESTING.
    METHODS zero_rate FOR TESTING.
    METHODS title_mapping FOR TESTING.
ENDCLASS.
CLASS ltcl_tx_xlsx IMPLEMENTATION.
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
          i_dependency_list = VALUE #( ( 'ZREING_TX_TYPE_C' ) ( 'I_COUNTRY' ) ) ).
        seed( ).
        cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'ZREING_TX_TYPE_C' ) ).
        cl_abap_unit_assert=>assert_bound( mo_env->get_double( 'I_COUNTRY' ) ).
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
  ENDMETHOD.
  METHOD setup.
    TRY.
        seed( ).
      CATCH cx_root INTO DATA(lx_setup).
        release_env( CHANGING co_env = mo_env ).
        cl_abap_unit_assert=>fail( msg = lx_setup->get_text( ) ).
        RETURN.
    ENDTRY.
    mo_cut = NEW #( ).
  ENDMETHOD.
  METHOD expected_line.
    rs_line = VALUE #( country = 'UY' description = 'VAL-TX synthetic'
      tax_type = 'WHT' rate = '10.00' valid_from = '20260101' valid_to = '20261231'
      tx_status = 'AC' country_prest = 'BR' bukrs_prest = 'B901' bukrs_recv = 'B902' ).
  ENDMETHOD.
  METHOD assert_line.
    cl_abap_unit_assert=>assert_false( is_result-aborted ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-results ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-results[ 1 ]-status exp = 'S' ).
    cl_abap_unit_assert=>assert_equals( act = is_result-results[ 1 ]-row_number exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-create_lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-create_lines[ 1 ] exp = is_expected ).
  ENDMETHOD.
  METHOD legacy_12cols.
    DATA(ls_expected) = expected_line( ).
    CLEAR: ls_expected-country_prest, ls_expected-bukrs_prest, ls_expected-bukrs_recv.
    assert_line( is_result = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( headers( ) ) ( valid_row( ) ) ) iv_legacy = abap_true ) )
      is_expected = ls_expected ).
  ENDMETHOD.
  METHOD new_15cols.
    DATA(lv_template) = mo_cut->export_template( ).
    cl_abap_unit_assert=>assert_not_initial( lv_template ).
    DATA(lo_sheet) = xco_cp_xlsx=>document->for_file_content( lv_template
      )->read_access( )->get_workbook( )->worksheet->at_position( 1 ).
    DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'O' )
      )->to_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) )->get_pattern( ).
    DATA lt_headers TYPE tt_row15.
    lo_sheet->select( lo_pattern )->row_stream( )->operation->write_to( REF #( lt_headers )
      )->if_xco_xlsx_ra_operation~execute( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_headers ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_headers[ 1 ] exp = headers( ) ).
    assert_line( is_result = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( headers( ) ) ( valid_row( ) ) ) iv_template = lv_template ) )
      is_expected = expected_line( ) ).
  ENDMETHOD.
  METHOD new_cols_empty.
    DATA(ls_row) = valid_row( ).
    CLEAR: ls_row-c13, ls_row-c14, ls_row-c15.
    DATA(ls_expected) = expected_line( ).
    CLEAR: ls_expected-country_prest, ls_expected-bukrs_prest, ls_expected-bukrs_recv.
    assert_line( is_result = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( headers( ) ) ( ls_row ) ) ) ) is_expected = ls_expected ).
  ENDMETHOD.
  METHOD country_empty.
    DATA(ls_row) = valid_row( ).
    CLEAR: ls_row-c2, ls_row-c14, ls_row-c15.
    DATA(ls_expected) = expected_line( ).
    CLEAR: ls_expected-country, ls_expected-bukrs_prest, ls_expected-bukrs_recv.
    assert_line( is_result = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( headers( ) ) ( ls_row ) ) ) ) is_expected = ls_expected ).
  ENDMETHOD.
  METHOD required_header.
    DATA(ls_header) = headers( ).
    CLEAR ls_header-c4.
    DATA(ls_result) = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( ls_header ) ( valid_row( ) ) ) ) ).
    cl_abap_unit_assert=>assert_true( ls_result-aborted ).
    cl_abap_unit_assert=>assert_initial( ls_result-create_lines ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-abort_reason exp = '*Tipo Impuesto*' ).
  ENDMETHOD.
  METHOD zero_rate.
    DATA(ls_row) = valid_row( ).
    ls_row-c5 = '0.00'.
    DATA(ls_expected) = expected_line( ).
    ls_expected-rate = 0.
    assert_line( is_result = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( headers( ) ) ( ls_row ) ) ) ) is_expected = ls_expected ).
  ENDMETHOD.
  METHOD title_mapping.
    DATA(ls_header) = headers( ).
    ls_header-c13 = 'Soc. Receptora'.
    ls_header-c14 = 'Pais Prestadora'.
    ls_header-c15 = 'Soc. Prestadora'.
    DATA(ls_row) = valid_row( ).
    ls_row-c13 = 'B902'.
    ls_row-c14 = 'BR'.
    ls_row-c15 = 'B901'.
    assert_line( is_result = mo_cut->import_file( workbook(
      it_rows = VALUE #( ( ls_header ) ( ls_row ) ) ) ) is_expected = expected_line( ) ).
  ENDMETHOD.
ENDCLASS.
