*" V001 (CC) - ME-19 (Delta v2)
*"! @testing BDEF:ZI_REINGMEHEADER
*CLASS ltc_reingme_item_validation DEFINITION FINAL FOR TESTING
*  DURATION SHORT
*  RISK LEVEL HARMLESS.
*
*  PRIVATE SECTION.
*    TYPES ty_t_ct TYPE STANDARD TABLE OF zreing_ct2_a WITH EMPTY KEY.
*    TYPES ty_t_ct_mat TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
*    TYPES ty_t_ct_rec TYPE STANDARD TABLE OF zreing_ct2_rec_a WITH EMPTY KEY.
*    TYPES ty_t_ct_met TYPE STANDARD TABLE OF zreing_ct2_met_a WITH EMPTY KEY.
*    TYPES ty_t_company_code TYPE STANDARD TABLE OF i_companycode WITH EMPTY KEY.
*
*    CLASS-DATA mo_header TYPE REF TO lhc_zi_reingmeheader.
*    CLASS-DATA mo_item TYPE REF TO lhc_zi_reingmeitem.
*    CLASS-DATA mo_cds_env TYPE REF TO if_cds_test_environment.
*    CLASS-DATA mo_sql_env TYPE REF TO if_osql_test_environment.
*
*    CLASS-METHODS class_setup.
*    CLASS-METHODS class_teardown.
*    METHODS setup.
*    METHODS share_excludes_unmatched FOR TESTING.
*    METHODS sets_prev_values FOR TESTING.
*    METHODS rejects_invalid_dimensions FOR TESTING.
*    METHODS rejects_duplicate_business_key FOR TESTING.
*    METHODS accepts_distinct_dimensions FOR TESTING.
*    METHODS upload_replaces_items FOR TESTING.
*ENDCLASS.
*
*CLASS ltc_reingme_item_validation IMPLEMENTATION.
*METHOD class_setup.
*  CREATE OBJECT mo_header FOR TESTING.
*  CREATE OBJECT mo_item FOR TESTING.
*  mo_cds_env = cl_cds_test_environment=>create_for_multiple_cds(
*    VALUE #(
*      ( i_for_entity = 'ZI_REINGMEHEADER' )
*      ( i_for_entity = 'ZI_REINGMEITEM' ) ) ).
*  mo_sql_env = cl_osql_test_environment=>create(
*    VALUE #(
*      ( 'ZREING_CT2_A' )
*      ( 'ZREING_CT2_MAT_A' )
*      ( 'ZREING_CT2_REC_A' )
*      ( 'ZREING_CT2_MET_A' )
*      ( 'ZREING_ME_H_A' )
*      ( 'ZREING_ME_I_A' ) ) ).
*ENDMETHOD.
*
*  METHOD class_teardown.
*    mo_sql_env->destroy( ).
*    mo_cds_env->destroy( ).
*  ENDMETHOD.
*
*  METHOD setup.
*    mo_cds_env->clear_doubles( ).
*    mo_sql_env->clear_doubles( ).
*  ENDMETHOD.
*
*  METHOD share_excludes_unmatched.
*    DATA lt_headers TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
*    DATA lt_items TYPE STANDARD TABLE OF zreing_me_i_a WITH EMPTY KEY.
*    DATA result TYPE TABLE FOR ACTION RESULT zi_reingmeheader~calcularshare.
*    DATA failed TYPE RESPONSE FOR FAILED EARLY zi_reingmeheader.
*    DATA reported TYPE RESPONSE FOR REPORTED EARLY zi_reingmeheader.
*
*    lt_headers = VALUE #(
*      ( me_h_id = CONV sysuuid_x16( '91111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' me_status = 'RASO' ) ).
*    lt_items = VALUE #(
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( 'A1111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '100.000000' )
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( 'B1111111111111111111111111111111' )
*        bukrs = '2000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '50.000000' ) ).
*    mo_cds_env->insert_test_data( lt_headers ).
*    mo_cds_env->insert_test_data( lt_items ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct( (
*      ct_uuid = CONV sysuuid_x16( 'C1111111111111111111111111111111' )
*      ct_id = 'UTME19' ct_status = 'AC' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_mat( (
*      ct_uuid = CONV sysuuid_x16( 'C1111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( 'D1111111111111111111111111111111' )
*      matnr = 'UTME19' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_rec( (
*      ct_uuid = CONV sysuuid_x16( 'C1111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( 'D1111111111111111111111111111111' )
*      rec_uuid = CONV sysuuid_x16( 'E1111111111111111111111111111111' )
*      rec_bukrs = '1000' prctr = '0000000001' campana = '001'
*      role_category = 'C' allocation = '0' rec_status = 'AC' ) ) ).
*
*    mo_header->calcularshare(
*      EXPORTING keys = CORRESPONDING #( lt_headers )
*      CHANGING result = result failed = failed reported = reported ).
*
*    cl_abap_unit_assert=>assert_initial( act = failed ).
*    READ ENTITIES OF zi_reingmeheader
*      ENTITY zi_reingmeheader BY \_item
*        FIELDS ( sharepct )
*        WITH CORRESPONDING #( lt_headers )
*      RESULT DATA(lt_actual_items).
*    cl_abap_unit_assert=>assert_equals(
*      exp = '100.000000' act = lt_actual_items[ 1 ]-%data-sharepct ).
*    cl_abap_unit_assert=>assert_equals(
*      exp = '0.000000' act = lt_actual_items[ 2 ]-%data-sharepct ).
*  ENDMETHOD.
*
*  METHOD sets_prev_values.
*    DATA lt_headers TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
*    DATA lt_items TYPE STANDARD TABLE OF zreing_me_i_a WITH EMPTY KEY.
*    DATA result TYPE TABLE FOR ACTION RESULT zi_reingmeheader~calcularshare.
*    DATA failed TYPE RESPONSE FOR FAILED EARLY zi_reingmeheader.
*    DATA reported TYPE RESPONSE FOR REPORTED EARLY zi_reingmeheader.
*
*    lt_headers = VALUE #(
*      ( me_h_id = CONV sysuuid_x16( 'F1111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' period_year = '2026'
*        period_month = '03' me_status = 'RASO' )
*      ( me_h_id = CONV sysuuid_x16( '01111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' period_year = '2026'
*        period_month = '02' me_status = 'LIBD' load_version = '1' )
*      ( me_h_id = CONV sysuuid_x16( '12111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' period_year = '2026'
*        period_month = '01' me_status = 'LIBD' load_version = '1' ) ).
*    lt_items = VALUE #(
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '13111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '100.000000' )
*      ( me_h_id = lt_headers[ 2 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '14111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '80.000000' )
*      ( me_h_id = lt_headers[ 3 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '15111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '70.000000' ) ).
*    mo_cds_env->insert_test_data( lt_headers ).
*    mo_cds_env->insert_test_data( lt_items ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct( (
*      ct_uuid = CONV sysuuid_x16( '16111111111111111111111111111111' )
*      ct_id = 'UTME19' ct_status = 'AC' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_mat( (
*      ct_uuid = CONV sysuuid_x16( '16111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( '17111111111111111111111111111111' )
*      matnr = 'UTME19' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_rec( (
*      ct_uuid = CONV sysuuid_x16( '16111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( '17111111111111111111111111111111' )
*      rec_uuid = CONV sysuuid_x16( '18111111111111111111111111111111' )
*      rec_bukrs = '1000' prctr = '0000000001' campana = '001'
*      role_category = 'C' allocation = '0' rec_status = 'AC' ) ) ).
*
*    mo_header->calcularshare(
*      EXPORTING keys = VALUE #( ( mehid = lt_headers[ 1 ]-me_h_id ) )
*      CHANGING result = result failed = failed reported = reported ).
*
*    cl_abap_unit_assert=>assert_initial( act = failed ).
*    READ ENTITIES OF zi_reingmeheader
*      ENTITY zi_reingmeheader BY \_item
*        FIELDS ( prevvalue prev2value )
*        WITH VALUE #( ( mehid = lt_headers[ 1 ]-me_h_id ) )
*      RESULT DATA(lt_actual_items).
*    cl_abap_unit_assert=>assert_equals(
*      exp = '80.000000' act = lt_actual_items[ 1 ]-%data-prevvalue ).
*    cl_abap_unit_assert=>assert_equals(
*      exp = '70.000000' act = lt_actual_items[ 1 ]-%data-prev2value ).
*  ENDMETHOD.
*
*  METHOD rejects_invalid_dimensions.
*    DATA lt_headers TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
*    DATA lt_items TYPE STANDARD TABLE OF zreing_me_i_a WITH EMPTY KEY.
*    DATA failed TYPE RESPONSE FOR FAILED LATE zi_reingmeheader.
*    DATA reported TYPE RESPONSE FOR REPORTED LATE zi_reingmeheader.
*
*    lt_headers = VALUE #(
*      ( me_h_id = CONV sysuuid_x16( '11111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' me_status = 'RASO' ) ).
*    lt_items = VALUE #(
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '21111111111111111111111111111111' )
*        bukrs = '1000' prctr = '' campana = '001'
*        role_category = 'X' allocation = '9' me_value = '10.000000' ) ).
*    mo_cds_env->insert_test_data( lt_headers ).
*    mo_cds_env->insert_test_data( lt_items ).
*
*    mo_item->validateitem(
*      EXPORTING keys = CORRESPONDING #( lt_items )
*      CHANGING failed = failed reported = reported ).
*
*    cl_abap_unit_assert=>assert_equals(
*      exp = 1 act = lines( failed-zi_reingmeitem ) ).
*    cl_abap_unit_assert=>assert_equals(
*      exp = 3 act = lines( reported-zi_reingmeitem ) ).
*  ENDMETHOD.
*
*  METHOD rejects_duplicate_business_key.
*    DATA lt_headers TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
*    DATA lt_items TYPE STANDARD TABLE OF zreing_me_i_a WITH EMPTY KEY.
*    DATA failed TYPE RESPONSE FOR FAILED LATE zi_reingmeheader.
*    DATA reported TYPE RESPONSE FOR REPORTED LATE zi_reingmeheader.
*
*    lt_headers = VALUE #(
*      ( me_h_id = CONV sysuuid_x16( '31111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' me_status = 'RASO' ) ).
*    lt_items = VALUE #(
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '41111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '10.000000' )
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '51111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '20.000000' ) ).
*    mo_cds_env->insert_test_data( lt_headers ).
*    mo_cds_env->insert_test_data( lt_items ).
*
*    mo_item->validateitem(
*      EXPORTING keys = CORRESPONDING #( lt_items )
*      CHANGING failed = failed reported = reported ).
*
*    cl_abap_unit_assert=>assert_equals(
*      exp = 1 act = lines( failed-zi_reingmeitem ) ).
*    cl_abap_unit_assert=>assert_equals(
*      exp = 1 act = lines( reported-zi_reingmeitem ) ).
*  ENDMETHOD.
*
*  METHOD accepts_distinct_dimensions.
*    DATA lt_headers TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
*    DATA lt_items TYPE STANDARD TABLE OF zreing_me_i_a WITH EMPTY KEY.
*    DATA failed TYPE RESPONSE FOR FAILED LATE zi_reingmeheader.
*    DATA reported TYPE RESPONSE FOR REPORTED LATE zi_reingmeheader.
*
*    lt_headers = VALUE #(
*      ( me_h_id = CONV sysuuid_x16( '61111111111111111111111111111111' )
*        ct_id = 'UTME19' matnr = 'UTME19' me_status = 'RASO' ) ).
*    lt_items = VALUE #(
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '71111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'C' allocation = '0' me_value = '10.000000' )
*      ( me_h_id = lt_headers[ 1 ]-me_h_id
*        me_i_id = CONV sysuuid_x16( '81111111111111111111111111111111' )
*        bukrs = '1000' prctr = '0000000001' campana = '001'
*        role_category = 'E' allocation = '0' me_value = '20.000000' ) ).
*    mo_cds_env->insert_test_data( lt_headers ).
*    mo_cds_env->insert_test_data( lt_items ).
*
*    mo_item->validateitem(
*      EXPORTING keys = CORRESPONDING #( lt_items )
*      CHANGING failed = failed reported = reported ).
*
*    cl_abap_unit_assert=>assert_initial( act = failed ).
*    cl_abap_unit_assert=>assert_initial( act = reported ).
*  ENDMETHOD.
*  METHOD upload_replaces_items.
*    DATA lt_headers TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
*    DATA lt_old_items TYPE STANDARD TABLE OF zreing_me_i_a WITH EMPTY KEY.
*    DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
*    DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).
*    DATA(lo_cursor) = lo_sheet->cursor(
*      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
*      io_row = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).
*
*    lo_cursor->get_cell( )->value->write_from( 'Metrica' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Sociedad' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Campana' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Asignacion' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'CeBe' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Categoria Gasto' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Valor' ).
*    lo_cursor = lo_sheet->cursor(
*      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
*      io_row = xco_cp_xlsx=>coordinate->for_numeric_value( 2 ) ).
*    lo_cursor->get_cell( )->value->write_from( 'UTMET19' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( '1000' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( '001' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( '0' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( '1' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( 'C' ).
*    lo_cursor->move_right( )->get_cell( )->value->write_from( '100' ).
*
*    lt_headers = VALUE #( (
*      me_h_id = CONV sysuuid_x16( 'A9111111111111111111111111111111' )
*      ct_id = 'UTUP19' matnr = 'UTUP19' period_year = '2026'
*      period_month = '07' load_version = '1' me_status = 'RASO'
*      metric_code = 'UTMET19' met_version = '1' ) ).
*    lt_old_items = VALUE #( (
*      me_h_id = lt_headers[ 1 ]-me_h_id
*      me_i_id = CONV sysuuid_x16( 'B9111111111111111111111111111111' )
*      bukrs = '2000' prctr = '0000000001' campana = '001'
*      role_category = 'C' allocation = '0' me_value = '10.000000' ) ).
*    mo_cds_env->insert_test_data( lt_headers ).
*    mo_cds_env->insert_test_data( lt_old_items ).
*    mo_sql_env->insert_test_data( lt_headers ).
*    mo_sql_env->insert_test_data( lt_old_items ).
*    mo_cds_env->insert_test_data( VALUE ty_t_company_code( ( companycode = '1000' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct( (
*      ct_uuid = CONV sysuuid_x16( 'C9111111111111111111111111111111' )
*      ct_id = 'UTUP19' valid_from = '20260101' valid_to = '20261231' ct_status = 'AC' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_mat( (
*      ct_uuid = CONV sysuuid_x16( 'C9111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( 'D9111111111111111111111111111111' )
*      matnr = 'UTUP19' mat_status = 'AC' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_met( (
*      ct_uuid = CONV sysuuid_x16( 'C9111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( 'D9111111111111111111111111111111' )
*      met_uuid = CONV sysuuid_x16( 'E9111111111111111111111111111111' )
*      metric_code = 'UTMET19' version_num = '1' valid_from = '20260101'
*      valid_to = '20261231' met_status = 'AC' ) ) ).
*    mo_sql_env->insert_test_data( VALUE ty_t_ct_rec( (
*      ct_uuid = CONV sysuuid_x16( 'C9111111111111111111111111111111' )
*      mat_uuid = CONV sysuuid_x16( 'D9111111111111111111111111111111' )
*      rec_uuid = CONV sysuuid_x16( 'F9111111111111111111111111111111' )
*      rec_bukrs = '1000' prctr = '0000000001' campana = '001'
*      role_category = 'C' allocation = '0' rec_status = 'AC'
*      valid_from = '20260101' valid_to = '20261231' ) ) ).
*
*    DATA(lv_base64) = cl_web_http_utility=>encode_x_base64(
*      unencoded = lo_write->get_file_content( ) ).
*    MODIFY ENTITIES OF zi_reingmeheader IN LOCAL MODE
*      ENTITY zi_reingmeheader EXECUTE upload
*      FROM VALUE #( ( %cid = 'UP19' %param-PeriodYear = '2026'
*                      %param-PeriodMonth = '07' %param-FileContent = lv_base64
*                      %param-FileName = 'upload.xlsx' ) )
*      RESULT DATA(result) FAILED DATA(failed) REPORTED DATA(reported).
*
*    cl_abap_unit_assert=>assert_initial( act = failed ).
*    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( result ) ).
*    cl_abap_unit_assert=>assert_equals( exp = 'S' act = result[ 1 ]-%param-Severity ).
*    READ ENTITIES OF zi_reingmeheader IN LOCAL MODE
*      ENTITY zi_reingmeheader BY \_item
*        FIELDS ( mevalue sharepct )
*        WITH VALUE #( ( mehid = lt_headers[ 1 ]-me_h_id ) )
*      RESULT DATA(actual_items).
*    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( actual_items ) ).
*    cl_abap_unit_assert=>assert_equals( exp = '100.000000'
*      act = actual_items[ 1 ]-%data-mevalue ).
*    cl_abap_unit_assert=>assert_equals( exp = '100.000000'
*      act = actual_items[ 1 ]-%data-sharepct ).
*  ENDMETHOD.
*ENDCLASS.
