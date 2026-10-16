CLASS ltcl_export_rows DEFINITION DEFERRED.
CLASS zcl_reing_ca_xls_hdl DEFINITION LOCAL FRIENDS ltcl_export_rows.
CLASS ltcl_export_rows DEFINITION FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT
  FINAL.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_xml_cell, cell_type TYPE string, cell_value TYPE string, has_value TYPE abap_bool, END OF ty_xml_cell.
    METHODS numbers_preserved FOR TESTING RAISING cx_static_check.
    METHODS high_precision FOR TESTING RAISING cx_static_check.
    METHODS rounding_rejected FOR TESTING RAISING cx_static_check.
    METHODS overflow_rejected FOR TESTING RAISING cx_static_check.
    METHODS invalid_number_rejected FOR TESTING RAISING cx_static_check.
    METHODS no_mask_stays_text FOR TESTING RAISING cx_static_check.
    METHODS sheet_name_final FOR TESTING RAISING cx_static_check.
    METHODS styles_final FOR TESTING RAISING cx_static_check.
    METHODS empty_sheet_name FOR TESTING RAISING cx_static_check.
    METHODS idempotent_normalization FOR TESTING RAISING cx_static_check.
    METHODS other_parts_unchanged FOR TESTING RAISING cx_static_check.
    METHODS numeric_after_z FOR TESTING RAISING cx_static_check.
    METHODS invalid_zip_rejected FOR TESTING RAISING cx_static_check.
    METHODS missing_part_rejected FOR TESTING RAISING cx_static_check.
    METHODS multiple_sheets_rejected FOR TESTING RAISING cx_static_check.
    METHODS style_conflict_rejected FOR TESTING RAISING cx_static_check.
    METHODS namespaces_preserved FOR TESTING RAISING cx_static_check.
    METHODS malformed_xml_rejected FOR TESTING RAISING cx_static_check.
    METHODS valid_styles_preserved FOR TESTING RAISING cx_static_check.
    METHODS large_total_preserved FOR TESTING RAISING cx_static_check.
    METHODS raw_precision_rejected FOR TESTING RAISING cx_static_check.
    METHODS xml_declaration_supported FOR TESTING RAISING cx_static_check.
    METHODS zip_part IMPORTING iv_file TYPE xstring iv_name TYPE string RETURNING VALUE(rv_xml) TYPE xstring.
    METHODS xml_bytes IMPORTING iv_text TYPE string RETURNING VALUE(rv_xml) TYPE xstring.
    METHODS xml_cell IMPORTING iv_file TYPE xstring iv_address TYPE string
      RETURNING VALUE(rs_cell) TYPE ty_xml_cell RAISING cx_static_check.
    METHODS single_row       FOR TESTING RAISING cx_static_check.
    METHODS multiple_rows    FOR TESTING RAISING cx_static_check.
    METHODS column_beyond_z  FOR TESTING RAISING cx_static_check.
    METHODS empty_table      FOR TESTING RAISING cx_static_check.

    " Lee una unica celda decodificando el rango A1..<iv_col_idx><iv_row> en
    " una estructura construida dinamicamente (RTTI) con iv_col_idx campos
    " string -- el ancho del rango debe calzar EXACTO con el numero de
    " componentes del destino (un mismatch dispara GETWA_NOT_ASSIGNED en
    " CL_XCO_XLSX_RA_RS_OP_WRITE_TO al hacer ASSIGN COMPONENT).
    METHODS read_cell
      IMPORTING
        iv_file_content TYPE xstring
        iv_col_idx      TYPE i
        iv_row          TYPE i
      RETURNING
        VALUE(rv_value) TYPE string.

ENDCLASS.


CLASS ltcl_export_rows IMPLEMENTATION.

  METHOD single_row.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA lt_rows TYPE zcl_reing_ca_xls_hdl=>ty_rows.

    APPEND VALUE zcl_reing_ca_xls_hdl=>ty_row(
      ( `Contrato` ) ( `Ext` ) ( `Prestadora` ) ) TO lt_rows.

    DATA(lv_xstring) = lo_cut->export_rows( lt_rows ).
    cl_abap_unit_assert=>assert_not_initial( lv_xstring ).

    cl_abap_unit_assert=>assert_equals(
      act = read_cell( iv_file_content = lv_xstring iv_col_idx = 1 iv_row = 1 )
      exp = 'Contrato' ).
    cl_abap_unit_assert=>assert_equals(
      act = read_cell( iv_file_content = lv_xstring iv_col_idx = 3 iv_row = 1 )
      exp = 'Prestadora' ).
  ENDMETHOD.

  METHOD multiple_rows.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA lt_rows TYPE zcl_reing_ca_xls_hdl=>ty_rows.

    APPEND VALUE zcl_reing_ca_xls_hdl=>ty_row( ( `Contrato` ) ( `Material` ) ) TO lt_rows.
    APPEND VALUE zcl_reing_ca_xls_hdl=>ty_row( ( `CT-001` )   ( `MAT-01` ) )   TO lt_rows.
    APPEND VALUE zcl_reing_ca_xls_hdl=>ty_row( ( `CT-002` )   ( `MAT-02` ) )   TO lt_rows.

    DATA(lv_xstring) = lo_cut->export_rows( lt_rows ).

    cl_abap_unit_assert=>assert_equals(
      act = read_cell( iv_file_content = lv_xstring iv_col_idx = 1 iv_row = 3 )
      exp = 'CT-002' ).
    cl_abap_unit_assert=>assert_equals(
      act = read_cell( iv_file_content = lv_xstring iv_col_idx = 2 iv_row = 2 )
      exp = 'MAT-01' ).
  ENDMETHOD.

  METHOD column_beyond_z.
    " Fuerza el rollover de col_letter (columna 27 = "AA") -- cubre la rama
    " de dos letras de la conversion base-26 privada del handler, ejercitada
    " a traves del metodo publico export_rows.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA lt_rows TYPE zcl_reing_ca_xls_hdl=>ty_rows.
    DATA lt_vals TYPE string_table.
    DATA(lv_n_cols) = 27.

    DO lv_n_cols TIMES.
      APPEND |Col{ sy-index }| TO lt_vals.
    ENDDO.
    APPEND lt_vals TO lt_rows.

    DATA(lv_xstring) = lo_cut->export_rows( lt_rows ).

    cl_abap_unit_assert=>assert_equals(
      act = read_cell( iv_file_content = lv_xstring iv_col_idx = lv_n_cols iv_row = 1 )
      exp = |Col{ lv_n_cols }| ).
  ENDMETHOD.

  METHOD empty_table.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA lt_rows TYPE zcl_reing_ca_xls_hdl=>ty_rows.

    DATA(lv_xstring) = lo_cut->export_rows( lt_rows ).
    cl_abap_unit_assert=>assert_not_initial( lv_xstring ).
  ENDMETHOD.

  METHOD read_cell.
    DATA(lo_read)  = xco_cp_xlsx=>document->for_file_content( iv_file_content )->read_access( ).
    DATA(lo_sheet) = lo_read->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( iv_row )
      )->to_column(   xco_cp_xlsx=>coordinate->for_numeric_value( iv_col_idx )
      )->to_row(      xco_cp_xlsx=>coordinate->for_numeric_value( iv_row )
      )->get_pattern( ).

    DATA(lt_components) = VALUE cl_abap_structdescr=>component_table( ).
    DO iv_col_idx TIMES.
      APPEND VALUE #( name = |F{ sy-index }| type = cl_abap_elemdescr=>get_string( ) ) TO lt_components.
    ENDDO.
    DATA(lo_struct)     = cl_abap_structdescr=>create( lt_components ).
    DATA(lo_tabledescr) = cl_abap_tabledescr=>create( p_line_type = lo_struct ).

    DATA lr_table TYPE REF TO data.
    CREATE DATA lr_table TYPE HANDLE lo_tabledescr.
    FIELD-SYMBOLS <lt_out> TYPE STANDARD TABLE.
    ASSIGN lr_table->* TO <lt_out>.

    lo_sheet->select( lo_pattern
      )->row_stream( )->operation->write_to( lr_table
      )->if_xco_xlsx_ra_operation~execute( ).

    IF lines( <lt_out> ) > 0.
      ASSIGN <lt_out>[ 1 ] TO FIELD-SYMBOL(<ls_row>).
      ASSIGN COMPONENT iv_col_idx OF STRUCTURE <ls_row> TO FIELD-SYMBOL(<lv_val>).
      IF <lv_val> IS ASSIGNED.
        rv_value = <lv_val>.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD numbers_preserved.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA(lt_rows) = VALUE zcl_reing_ca_xls_hdl=>ty_rows(
      ( VALUE #( ( `ID` ) ( `Monto` ) ( `Tasa` ) ) )
      ( VALUE #( ( `001` ) ( `1234.56` ) ( `17.381900` ) ) )
      ( VALUE #( ( `000` ) ( `-0.25` ) ( `0` ) ) )
      ( VALUE #( ( `099` ) ( `0` ) ( `` ) ) ) ).
    DATA(lv_file) = lo_cut->export_rows( it_rows = lt_rows it_numeric_cols = VALUE #( ( 2 ) ( 3 ) ) ).
    DATA(ls_amount) = xml_cell( iv_file = lv_file iv_address = 'B2' ).
    cl_abap_unit_assert=>assert_equals( act = ls_amount-cell_type exp = 'n' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_amount-cell_value ) exp = CONV decfloat34( '1234.56' ) ).
    DATA(ls_rate) = xml_cell( iv_file = lv_file iv_address = 'C2' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_rate-cell_value ) exp = CONV decfloat34( '17.3819' ) ).
    DATA(ls_negative) = xml_cell( iv_file = lv_file iv_address = 'B3' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_negative-cell_value ) exp = CONV decfloat34( '-0.25' ) ).
    DATA(ls_zero) = xml_cell( iv_file = lv_file iv_address = 'B4' ).
    cl_abap_unit_assert=>assert_equals( act = ls_zero-has_value exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_zero-cell_value ) exp = CONV decfloat34( 0 ) ).
    DATA(ls_missing) = xml_cell( iv_file = lv_file iv_address = 'C4' ).
    " A shared-string index is not the decoded empty value.
    cl_abap_unit_assert=>assert_equals( act = ls_missing-cell_type exp = 's' ).
    cl_abap_unit_assert=>assert_equals(
      act = read_cell( iv_file_content = lv_file iv_col_idx = 3 iv_row = 4 ) exp = '' ).
    DATA(ls_id) = xml_cell( iv_file = lv_file iv_address = 'A2' ).
    cl_abap_unit_assert=>assert_equals( act = ls_id-cell_type exp = 's' ).
    cl_abap_unit_assert=>assert_equals( act = read_cell( iv_file_content = lv_file iv_col_idx = 1 iv_row = 2 ) exp = '001' ).
    DATA(ls_header) = xml_cell( iv_file = lv_file iv_address = 'B1' ).
    cl_abap_unit_assert=>assert_equals( act = ls_header-cell_type exp = 's' ).
  ENDMETHOD.

  METHOD high_precision.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA(lv_value) = `99999999999999999.12345678901234`.
    DATA(lv_file) = lo_cut->export_rows(
      it_rows = VALUE #( ( VALUE #( ( `Monto` ) ) ) ( VALUE #( ( lv_value ) ) ) ) it_numeric_cols = VALUE #( ( 1 ) ) ).
    DATA(ls_cell) = xml_cell( iv_file = lv_file iv_address = 'A2' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cell-cell_type exp = 'n' ).
    " Verify the serialized decimal value, not Excel's floating-point display precision.
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_cell-cell_value ) exp = CONV decfloat34( lv_value ) ).
  ENDMETHOD.

  METHOD rounding_rejected.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    TRY.
        lo_cut->export_rows( it_rows = VALUE #( ( VALUE #( ( `Tasa` ) ) ) ( VALUE #( ( `0.123456789012345` ) ) ) )
          it_numeric_cols = VALUE #( ( 1 ) ) ).
        cl_abap_unit_assert=>fail( 'A decimal value must not be silently rounded' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( xsdbool( lx_error->mv_message CS 'Número XLSX no representable' ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD overflow_rejected.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    TRY.
        lo_cut->export_rows( it_rows = VALUE #( ( VALUE #( ( `Monto` ) ) ) ( VALUE #( ( `100000000000000000000000000` ) ) ) )
          it_numeric_cols = VALUE #( ( 1 ) ) ).
        cl_abap_unit_assert=>fail( 'A decimal value must not overflow' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( lx_error->previous ).
    ENDTRY.
  ENDMETHOD.

  METHOD invalid_number_rejected.
    TRY.
        NEW zcl_reing_ca_xls_hdl( )->export_rows(
          it_rows = VALUE #( ( VALUE #( ( `Monto` ) ) ) ( VALUE #( ( `invalid` ) ) ) ) it_numeric_cols = VALUE #( ( 1 ) ) ).
        cl_abap_unit_assert=>fail( 'Invalid numeric text must fail' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( xsdbool( lx_error->mv_message CS 'fila 2, columna 1' ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD no_mask_stays_text.
    DATA(lv_file) = NEW zcl_reing_ca_xls_hdl( )->export_rows(
      VALUE #( ( VALUE #( ( `Monto` ) ) ) ( VALUE #( ( `123.40` ) ) ) ) ).
    DATA(ls_cell) = xml_cell( iv_file = lv_file iv_address = 'A2' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cell-cell_type exp = 's' ).
    cl_abap_unit_assert=>assert_equals( act = read_cell( iv_file_content = lv_file iv_col_idx = 1 iv_row = 2 ) exp = '123.40' ).
  ENDMETHOD.

  METHOD sheet_name_final.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA(lv_file) = lo_cut->export_rows( VALUE #( ( VALUE #( ( `Header` ) ) ) ) ).
    DATA(lv_xml) = zip_part( iv_file = lv_file iv_name = 'xl/workbook.xml' ).
    DATA(lo_reader) = cl_sxml_string_reader=>create( lv_xml ).
    DATA lv_count TYPE i.
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
            IF lo_reader->node_type = if_sxml_node=>co_nt_final. EXIT. ENDIF.
            CONTINUE.
          ENDIF.
      IF lo_node->type <> if_sxml_node=>co_nt_element_open. CONTINUE. ENDIF.
      DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
      IF lo_open->qname-name = 'sheet'.
        lv_count += 1.
        cl_abap_unit_assert=>assert_equals( act = lo_open->get_attribute_value( name = 'name' )->get_value( )
          exp = 'Resumen por Receptora' ).
      ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 ).
  ENDMETHOD.

  METHOD styles_final.
    DATA(lv_file) = NEW zcl_reing_ca_xls_hdl( )->export_rows(
      it_rows = VALUE #( ( VALUE #( ( `Monto` ) ) ) ( VALUE #( ( `1.25` ) ) ) ) it_numeric_cols = VALUE #( ( 1 ) ) ).
    DATA(lo_reader) = cl_sxml_string_reader=>create( zip_part( iv_file = lv_file iv_name = 'xl/styles.xml' ) ).
    DATA lv_count TYPE i.
    DATA lv_style_count TYPE i.
    DATA lt_path TYPE string_table.
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
            IF lo_reader->node_type = if_sxml_node=>co_nt_final. EXIT. ENDIF.
            CONTINUE.
          ENDIF.
      IF lo_node->type = if_sxml_node=>co_nt_element_close.
        DELETE lt_path INDEX lines( lt_path ).
        CONTINUE.
      ENDIF.
      IF lo_node->type <> if_sxml_node=>co_nt_element_open. CONTINUE. ENDIF.
      DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
      IF lo_open->qname-name = 'cellStyleXfs'.
        lv_style_count = lo_open->get_attribute_value( name = 'count' )->get_value( ).
      ENDIF.
      IF lo_open->qname-name = 'xf'.
        lv_count += 1.
        cl_abap_unit_assert=>assert_initial( lo_open->get_attribute_value( name = 'xf_id' ) ).
        IF lt_path[ lines( lt_path ) ] = 'cellStyleXfs'.
          cl_abap_unit_assert=>assert_initial( lo_open->get_attribute_value( name = 'xfId' ) ).
        ELSEIF lt_path[ lines( lt_path ) ] = 'cellXfs'.
          DATA(lo_index) = lo_open->get_attribute_value( name = 'xfId' ).
          IF lo_index IS BOUND.
            DATA lv_index TYPE i.
            lv_index = lo_index->get_value( ).
            cl_abap_unit_assert=>assert_true( xsdbool( lv_index >= 0 AND lv_index < lv_style_count ) ).
          ENDIF.
        ENDIF.
      ENDIF.
      APPEND lo_open->qname-name TO lt_path.
    ENDDO.
    cl_abap_unit_assert=>assert_true( xsdbool( lv_count > 0 AND lv_style_count > 0 ) ).
  ENDMETHOD.

  METHOD empty_sheet_name.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA(lv_file) = lo_cut->export_rows( VALUE #( ) ).
    DATA(lv_xml) = zip_part( iv_file = lv_file iv_name = 'xl/workbook.xml' ).
    DATA(lv_text) = cl_abap_conv_codepage=>create_in( )->convert( lv_xml ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_text CS 'Resumen por Receptora' ) ).
  ENDMETHOD.

  METHOD idempotent_normalization.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA(lv_file) = lo_cut->export_rows( VALUE #( ( VALUE #( ( `Header` ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lo_cut->normalize_file( lv_file ) exp = lv_file ).
  ENDMETHOD.

  METHOD other_parts_unchanged.
    DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).
    lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      io_row = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) )->get_cell( )->value->write_from( `001` ).
    DATA(lv_before) = lo_write->get_file_content( ).
    DATA(lv_after) = NEW zcl_reing_ca_xls_hdl( )->normalize_file( lv_before ).
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load( EXPORTING zip = lv_before EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( ).
    DO lines( lo_zip->files ) TIMES.
      READ TABLE lo_zip->files INTO DATA(ls_file) INDEX sy-index.
      IF ls_file-name = 'xl/workbook.xml' OR ls_file-name = 'xl/styles.xml'. CONTINUE. ENDIF.
      cl_abap_unit_assert=>assert_equals( act = zip_part( iv_file = lv_after iv_name = ls_file-name )
        exp = zip_part( iv_file = lv_before iv_name = ls_file-name ) ).
    ENDDO.
  ENDMETHOD.

  METHOD numeric_after_z.
    DATA lt_header TYPE string_table.
    DATA lt_values TYPE string_table.
    DO 27 TIMES.
      APPEND |Col{ sy-index }| TO lt_header.
      APPEND `001` TO lt_values.
    ENDDO.
    lt_values[ 27 ] = `17.25`.
    DATA(lv_file) = NEW zcl_reing_ca_xls_hdl( )->export_rows(
      it_rows = VALUE #( ( lt_header ) ( lt_values ) ) it_numeric_cols = VALUE #( ( 27 ) ) ).
    DATA(ls_cell) = xml_cell( iv_file = lv_file iv_address = 'AA2' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cell-cell_type exp = 'n' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_cell-cell_value ) exp = CONV decfloat34( '17.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = read_cell( iv_file_content = lv_file iv_col_idx = 27 iv_row = 1 ) exp = 'Col27' ).
  ENDMETHOD.

  METHOD invalid_zip_rejected.
    CONSTANTS lc_invalid TYPE xstring VALUE '00'.
    TRY.
        NEW zcl_reing_ca_xls_hdl( )->normalize_file( lc_invalid ).
        cl_abap_unit_assert=>fail( 'Invalid ZIP must fail' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD missing_part_rejected.
    DATA(lo_cut) = NEW zcl_reing_ca_xls_hdl( ).
    DATA(lv_file) = lo_cut->export_rows( VALUE #( ) ).
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load( EXPORTING zip = lv_file EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( ).
    lo_zip->delete( EXPORTING name = 'xl/styles.xml' EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( ).
    TRY.
        lo_cut->normalize_file( lo_zip->save( ) ).
        cl_abap_unit_assert=>fail( 'Missing XML part must fail' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( xsdbool( lx_error->mv_message CS 'xl/styles.xml' ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD multiple_sheets_rejected.
    DATA(lv_xml) = xml_bytes( `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
      && `<sheets><sheet name="A"/><sheet name="B"/></sheets></workbook>` ).
    TRY.
        NEW zcl_reing_ca_xls_hdl( )->normalize_xml( iv_xml = lv_xml iv_part = 'W' ).
        cl_abap_unit_assert=>fail( 'Multiple worksheets must fail' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD style_conflict_rejected.
    DATA(lv_xml) = xml_bytes( `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
      && `<cellXfs count="1"><xf xf_id="0" xfId="1"/></cellXfs></styleSheet>` ).
    TRY.
        NEW zcl_reing_ca_xls_hdl( )->normalize_xml( iv_xml = lv_xml iv_part = 'S' ).
        cl_abap_unit_assert=>fail( 'Conflicting format indices must fail' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( xsdbool( lx_error->mv_message CS 'contradictorios' ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD namespaces_preserved.
    DATA(lv_xml) = xml_bytes( `<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"`
      && ` xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"`
      && ` xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:keep="urn:keep" mc:Ignorable="keep">`
      && `<sheets><sheet name="Sheet1" sheetId="7" r:id="rId9"/></sheets></workbook>` ).
    DATA(lv_fixed) = NEW zcl_reing_ca_xls_hdl( )->normalize_xml( iv_xml = lv_xml iv_part = 'W' ).
    DATA(lo_reader) = cl_sxml_string_reader=>create( lv_fixed ).
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
            IF lo_reader->node_type = if_sxml_node=>co_nt_final. EXIT. ENDIF.
            CONTINUE.
          ENDIF.
      IF lo_node->type <> if_sxml_node=>co_nt_element_open. CONTINUE. ENDIF.
      DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
      IF lo_open->qname-name = 'workbook'.
        cl_abap_unit_assert=>assert_equals( act = lo_reader->get_nsuri_by_prefix( 'keep' ) exp = 'urn:keep' ).
        cl_abap_unit_assert=>assert_equals( act = lo_open->get_attribute_value( name = 'Ignorable'
          nsuri = 'http://schemas.openxmlformats.org/markup-compatibility/2006' )->get_value( ) exp = 'keep' ).
      ELSEIF lo_open->qname-name = 'sheet'.
        cl_abap_unit_assert=>assert_equals( act = lo_open->get_attribute_value( name = 'sheetId' )->get_value( ) exp = '7' ).
        cl_abap_unit_assert=>assert_equals( act = lo_open->get_attribute_value( name = 'id'
          nsuri = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' )->get_value( ) exp = 'rId9' ).
      ENDIF.
    ENDDO.
  ENDMETHOD.

  METHOD malformed_xml_rejected.
    TRY.
        NEW zcl_reing_ca_xls_hdl( )->normalize_xml( iv_xml = xml_bytes( `<workbook><sheets>` ) iv_part = 'W' ).
        cl_abap_unit_assert=>fail( 'Malformed XML must fail' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD valid_styles_preserved.
    DATA(lv_xml) = xml_bytes( `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
      && `<cellStyleXfs count="1"><xf numFmtId="0"/></cellStyleXfs>`
      && `<cellXfs count="1"><xf numFmtId="4" xfId="0"/></cellXfs>`
      && `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>` ).
    DATA(lv_fixed) = NEW zcl_reing_ca_xls_hdl( )->normalize_xml( iv_xml = lv_xml iv_part = 'S' ).
    DATA(lo_reader) = cl_sxml_string_reader=>create( lv_fixed ).
    DATA lv_seen TYPE i.
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
            IF lo_reader->node_type = if_sxml_node=>co_nt_final. EXIT. ENDIF.
            CONTINUE.
          ENDIF.
      IF lo_node->type <> if_sxml_node=>co_nt_element_open. CONTINUE. ENDIF.
      DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
      IF lo_open->qname-name = 'xf'.
        DATA(lo_index) = lo_open->get_attribute_value( name = 'xfId' ).
        IF lo_index IS BOUND.
          lv_seen += 1.
          cl_abap_unit_assert=>assert_equals( act = lo_index->get_value( ) exp = '0' ).
          cl_abap_unit_assert=>assert_equals( act = lo_open->get_attribute_value( name = 'numFmtId' )->get_value( ) exp = '4' ).
        ENDIF.
      ELSEIF lo_open->qname-name = 'cellStyle'.
        lv_seen += 1.
        cl_abap_unit_assert=>assert_equals( act = lo_open->get_attribute_value( name = 'xfId' )->get_value( ) exp = '0' ).
      ENDIF.
    ENDDO.
    cl_abap_unit_assert=>assert_equals( act = lv_seen exp = 2 ).
  ENDMETHOD.

  METHOD zip_part.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load( EXPORTING zip = iv_file EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( ).
    lo_zip->get( EXPORTING name = iv_name IMPORTING content = rv_xml EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( ).
  ENDMETHOD.

  METHOD xml_bytes.
    rv_xml = cl_abap_conv_codepage=>create_out( )->convert( iv_text ).
  ENDMETHOD.

  METHOD xml_cell.
    DATA(lo_reader) = cl_sxml_string_reader=>create( zip_part( iv_file = iv_file iv_name = 'xl/worksheets/sheet1.xml' ) ).
    DATA lv_selected TYPE abap_bool.
    DATA lv_value TYPE abap_bool.
    DO.
      DATA(lo_node) = lo_reader->read_next_node( ).
      IF lo_node IS INITIAL.
            IF lo_reader->node_type = if_sxml_node=>co_nt_final. EXIT. ENDIF.
            CONTINUE.
          ENDIF.
      CASE lo_node->type.
        WHEN if_sxml_node=>co_nt_element_open.
          DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
          IF lo_open->qname-name = 'c'.
            lv_selected = xsdbool( lo_open->get_attribute_value( name = 'r' )->get_value( ) = iv_address ).
            IF lv_selected = abap_true.
              DATA(lo_type) = lo_open->get_attribute_value( name = 't' ).
              rs_cell-cell_type = COND #( WHEN lo_type IS BOUND THEN lo_type->get_value( ) ELSE 'n' ).
            ENDIF.
          ELSEIF lo_open->qname-name = 'v' AND lv_selected = abap_true.
            lv_value = abap_true.
            rs_cell-has_value = abap_true.
          ENDIF.
        WHEN if_sxml_node=>co_nt_value.
          IF lv_selected = abap_true AND lv_value = abap_true.
            DATA(lo_value) = CAST if_sxml_value_node( lo_node ).
            rs_cell-cell_value &&= lo_value->get_value( ).
          ENDIF.
        WHEN if_sxml_node=>co_nt_element_close.
          DATA(lo_close) = CAST if_sxml_close_element( lo_node ).
          IF lo_close->qname-name = 'v'. CLEAR lv_value.
          ELSEIF lo_close->qname-name = 'c'.
            IF lv_selected = abap_true. EXIT. ENDIF.
            CLEAR lv_selected.
          ENDIF.
      ENDCASE.
    ENDDO.
  ENDMETHOD.

  METHOD large_total_preserved.
    DATA(lv_value) = `12345678901234567890.12`.
    DATA(lv_file) = NEW zcl_reing_ca_xls_hdl( )->export_rows(
      it_rows = VALUE #( ( VALUE #( ( `Total` ) ) ) ( VALUE #( ( lv_value ) ) ) )
      it_numeric_cols = VALUE #( ( 1 ) ) ).
    DATA(ls_cell) = xml_cell( iv_file = lv_file iv_address = `A2` ).
    cl_abap_unit_assert=>assert_equals( act = ls_cell-cell_type exp = `n` ).
    cl_abap_unit_assert=>assert_true( ls_cell-has_value ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( ls_cell-cell_value ) exp = CONV decfloat34( lv_value ) ).
  ENDMETHOD.

  METHOD raw_precision_rejected.
    TRY.
        NEW zcl_reing_ca_xls_hdl( )->export_rows(
          it_rows = VALUE #( ( VALUE #( ( `Monto` ) ) )
            ( VALUE #( ( `1.0000000000000000000000000000000001` ) ) ) )
          it_numeric_cols = VALUE #( ( 1 ) ) ).
        cl_abap_unit_assert=>fail( 'Raw input must not round before packed conversion' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( lx_error->previous ).
    ENDTRY.
  ENDMETHOD.

  METHOD xml_declaration_supported.
    DATA(lv_xml) = xml_bytes( `<?xml version="1.0" encoding="utf-8"?>`
      && `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">`
      && `<cellStyleXfs count="1"><xf xf_id="0"/></cellStyleXfs>`
      && `<cellXfs count="1"><xf xf_id="0"/></cellXfs></styleSheet>` ).
    DATA(lv_fixed) = NEW zcl_reing_ca_xls_hdl( )->normalize_xml( iv_xml = lv_xml iv_part = 'S' ).
    DATA(lv_text) = cl_abap_conv_codepage=>create_in( )->convert( lv_fixed ).
    cl_abap_unit_assert=>assert_true( xsdbool( lv_text CS 'xfId="0"' ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( lv_text CS 'xf_id' ) ).
  ENDMETHOD.

ENDCLASS.
