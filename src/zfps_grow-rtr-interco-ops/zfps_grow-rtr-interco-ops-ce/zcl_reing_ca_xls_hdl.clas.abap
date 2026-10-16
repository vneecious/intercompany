"----------------------------------------------------------------------
" Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
" Change ID      : V001 (CC)
" Date           : 15.07.2026
" Description    : F6-07 Export Excel - genera el binario .xlsx real a partir
"                  de filas ya armadas (header + datos) via la API XCO XLSX
"                  (Clean-Core-safe). CL_FDT_XL_SPREADSHEET quedo descartada
"                  (metodo CREATE_DOCUMENT privado, clase NOT_RELEASED) -- ver
"                  precedente ya en produccion: ZCL_REING_ME_XLS_HDL
"                  (App ME, FX-XLS) usa el mismo API.
" Transport      : DS4K9B5XZC
" Reference      : 5000049390
"----------------------------------------------------------------------
CLASS zcl_reing_ca_xls_hdl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    " V001 (CC) - #119 (Delta v2): preserve text IDs and write amounts as numbers.
    TYPES tt_numeric_cols TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.
    TYPES ty_row  TYPE string_table.
    TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    " Escribe una hoja unica a partir de filas ya armadas.
    " La primera fila de it_rows es el header, el resto son datos.
    " El numero de columnas es variable (columnas TAX dinamicas, ver ET pto 12.3).
    METHODS export_rows
      IMPORTING
        it_rows                TYPE ty_rows
        it_numeric_cols        TYPE tt_numeric_cols OPTIONAL
      RETURNING
        VALUE(rv_file_content)  TYPE xstring
      RAISING zcx_reing_ca_calc_error.

  PRIVATE SECTION.
    " V001 (CC) - #119 (Delta v2): exact numeric transfer and bounded OOXML repair.
    TYPES ty_xlsx_number TYPE p LENGTH 16 DECIMALS 14.
    TYPES ty_xlsx_large_number TYPE p LENGTH 16 DECIMALS 5.
    TYPES: BEGIN OF ty_xml_path,
             name TYPE string,
             nsuri TYPE string,
           END OF ty_xml_path,
           tt_xml_path TYPE STANDARD TABLE OF ty_xml_path WITH EMPTY KEY.
    CONSTANTS c_sheet_ns TYPE string VALUE 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'.
    CONSTANTS c_sheet_name TYPE string VALUE 'Resumen por Receptora'.
    CONSTANTS c_workbook_part TYPE string VALUE 'xl/workbook.xml'.
    CONSTANTS c_styles_part TYPE string VALUE 'xl/styles.xml'.
    METHODS get_zip_part
      IMPORTING io_zip TYPE REF TO cl_abap_zip iv_name TYPE string
      RETURNING VALUE(rv_content) TYPE xstring
      RAISING zcx_reing_ca_calc_error.
    METHODS normalize_file
      IMPORTING iv_content TYPE xstring
      RETURNING VALUE(rv_content) TYPE xstring
      RAISING zcx_reing_ca_calc_error.
    METHODS normalize_xml
      IMPORTING iv_xml TYPE xstring iv_part TYPE c
      RETURNING VALUE(rv_xml) TYPE xstring
      RAISING zcx_reing_ca_calc_error.
    METHODS fix_xf_attributes
      IMPORTING io_open TYPE REF TO if_sxml_open_element iv_parent TYPE string
      RAISING zcx_reing_ca_calc_error cx_sxml_name_error.
    " Convierte un indice de columna (1-based) a letra(s) de Excel (A, B, ..., Z, AA, AB, ...).
    METHODS col_letter
      IMPORTING
        iv_col                  TYPE i
      RETURNING
        VALUE(rv_letter)        TYPE string.

ENDCLASS.


CLASS zcl_reing_ca_xls_hdl IMPLEMENTATION.

  METHOD export_rows.
    DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).
    " V001 (CC) - #119 (Delta v2): ET12.1 worksheet name.
    lo_sheet->set_name( 'Resumen por Receptora' ).

    DATA lv_row_idx TYPE i.
    DATA lv_col_idx TYPE i.
    DATA lv_n_cols  TYPE i.
    DATA lv_val     TYPE string.

    " ATC fix (nested LOOP/ENDLOOP no permitido -- mismo patron ya usado en
    " ZBP_ReingCARun/ZCL_REING_CA_PIPELINE): el loop interno por columna se
    " reemplaza por DO ... TIMES + READ TABLE INDEX.
    LOOP AT it_rows INTO DATA(lt_cols).
      lv_row_idx = lv_row_idx + 1.
      lv_n_cols  = lines( lt_cols ).

      DO lv_n_cols TIMES.
        lv_col_idx = sy-index.
        READ TABLE lt_cols INTO lv_val INDEX lv_col_idx.

        DATA(lo_cursor) = lo_sheet->cursor(
          io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( col_letter( lv_col_idx ) )
          io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( lv_row_idx ) ).
        IF lv_row_idx > 1 AND lv_val IS NOT INITIAL
           AND line_exists( it_numeric_cols[ table_line = lv_col_idx ] ).
          DATA lv_number TYPE ty_xlsx_number.
          DATA lv_large_number TYPE ty_xlsx_large_number.
          DATA lr_number TYPE REF TO data.
          TRY.
              DATA(lv_decimal) = EXACT decfloat34( lv_val ).
              TRY.
                  lv_number = EXACT #( lv_decimal ).
                  lr_number = REF #( lv_number ).
                CATCH cx_sy_conversion_overflow.
                  " Aggregated currency amounts may exceed 17 integer digits.
                  lv_large_number = EXACT #( lv_decimal ).
                  lr_number = REF #( lv_large_number ).
              ENDTRY.
            CATCH cx_root INTO DATA(lx_number).
              RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                EXPORTING iv_message = |Número XLSX no representable en fila { lv_row_idx }, columna { lv_col_idx }: { lv_val }|
                          previous = lx_number.
          ENDTRY.
          lo_cursor->get_cell( )->value->write_from( lr_number->* ).
        ELSE.
          lo_cursor->get_cell( )->value->write_from( lv_val ).
        ENDIF.
      ENDDO.
    ENDLOOP.

    rv_file_content = normalize_file( lo_write->get_file_content( ) ).
  ENDMETHOD.


  METHOD col_letter.
    CONSTANTS lc_alphabet TYPE c LENGTH 26 VALUE 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
    DATA lv_n   TYPE i.
    DATA lv_rem TYPE i.

    lv_n = iv_col.
    CLEAR rv_letter.

    WHILE lv_n > 0.
      lv_rem = ( lv_n - 1 ) MOD 26.
      rv_letter = |{ lc_alphabet+lv_rem(1) }{ rv_letter }|.
      lv_n = ( lv_n - 1 ) DIV 26.
    ENDWHILE.
  ENDMETHOD.

  METHOD get_zip_part.
    io_zip->get( EXPORTING name = iv_name IMPORTING content = rv_content
      EXCEPTIONS zip_index_error = 1 zip_decompression_error = 2 OTHERS = 3 ).
    IF sy-subrc <> 0 OR rv_content IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = |No se puede leer la parte XLSX { iv_name }|.
    ENDIF.
  ENDMETHOD.

  METHOD normalize_file.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load( EXPORTING zip = iv_content EXCEPTIONS zip_parse_error = 1 OTHERS = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'El archivo generado no es un ZIP XLSX válido'.
    ENDIF.
    DATA(lv_workbook) = get_zip_part( io_zip = lo_zip iv_name = c_workbook_part ).
    DATA(lv_styles) = get_zip_part( io_zip = lo_zip iv_name = c_styles_part ).
    DATA(lv_workbook_fixed) = normalize_xml( iv_xml = lv_workbook iv_part = 'W' ).
    DATA(lv_styles_fixed) = normalize_xml( iv_xml = lv_styles iv_part = 'S' ).
    " Keep the original archive when both parts already have canonical output.
    IF lv_workbook = lv_workbook_fixed AND lv_styles = lv_styles_fixed.
      rv_content = iv_content.
      RETURN.
    ENDIF.
    IF lv_workbook <> lv_workbook_fixed.
      lo_zip->delete( EXPORTING name = c_workbook_part EXCEPTIONS zip_index_error = 1 OTHERS = 2 ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'No se puede reemplazar workbook.xml'.
      ENDIF.
      lo_zip->add( name = c_workbook_part content = lv_workbook_fixed ).
    ENDIF.
    IF lv_styles <> lv_styles_fixed.
      lo_zip->delete( EXPORTING name = c_styles_part EXCEPTIONS zip_index_error = 1 OTHERS = 2 ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'No se puede reemplazar styles.xml'.
      ENDIF.
      lo_zip->add( name = c_styles_part content = lv_styles_fixed ).
    ENDIF.
    rv_content = lo_zip->save( ).
  ENDMETHOD.

  METHOD normalize_xml.
    " V001 (CC) - #119 (Delta v2): normalize only the writer's own OOXML parts.
    IF iv_part <> 'W' AND iv_part <> 'S'.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Parte XLSX no admitida para normalización'.
    ENDIF.
    TRY.
        DATA(lo_reader) = cl_sxml_string_reader=>create( iv_xml ).
        lo_reader->set_option( option = if_sxml_reader=>co_opt_keep_whitespace ).
        DATA(lo_writer_buffer) = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_xml10 ).
        DATA lo_writer TYPE REF TO if_sxml_writer.
        lo_writer = lo_writer_buffer.
        DATA lt_path TYPE tt_xml_path.
        DATA lv_roots TYPE i.
        DATA lv_sheets TYPE i.
        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).
          IF lo_node IS INITIAL.
            IF lo_reader->node_type = if_sxml_node=>co_nt_final. EXIT. ENDIF.
            CONTINUE.
          ENDIF.
          CASE lo_node->type.
            WHEN if_sxml_node=>co_nt_element_open.
              DATA(lo_open) = CAST if_sxml_open_element( lo_node ).
              DATA(lv_depth) = lines( lt_path ).
              IF lv_depth = 0.
                lv_roots += 1.
                IF lo_open->qname-namespace <> c_sheet_ns
                   OR ( iv_part = 'W' AND lo_open->qname-name <> 'workbook' )
                   OR ( iv_part = 'S' AND lo_open->qname-name <> 'styleSheet' ).
                  RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                    EXPORTING iv_message = 'Raíz o namespace inesperado en XLSX'.
                ENDIF.
              ENDIF.
              IF lv_depth = 2 AND lo_open->qname-namespace = c_sheet_ns
                 AND lt_path[ 2 ]-nsuri = c_sheet_ns.
                IF iv_part = 'W' AND lt_path[ 2 ]-name = 'sheets' AND lo_open->qname-name = 'sheet'.
                  lv_sheets += 1.
                  lo_open->set_attribute( name = 'name' value = c_sheet_name ).
                ELSEIF iv_part = 'S' AND lo_open->qname-name = 'xf'
                   AND ( lt_path[ 2 ]-name = 'cellXfs' OR lt_path[ 2 ]-name = 'cellStyleXfs' ).
                  fix_xf_attributes( io_open = lo_open iv_parent = lt_path[ 2 ]-name ).
                ENDIF.
              ENDIF.
              APPEND VALUE #( name = lo_open->qname-name nsuri = lo_open->qname-namespace ) TO lt_path.
              lo_writer->write_node( lo_node ).
              " Preserve bindings used by QName-valued attributes such as mc:Ignorable.
              DATA lt_bindings TYPE STANDARD TABLE OF if_sxml_named=>nsbinding WITH EMPTY KEY.
              lt_bindings = CORRESPONDING #( lo_reader->get_nsbindings( ) ).
              DO lines( lt_bindings ) TIMES.
                READ TABLE lt_bindings INTO DATA(ls_binding) INDEX sy-index.
                IF ls_binding-prefix <> 'xml'
                   AND lo_writer->get_nsuri_by_prefix( ls_binding-prefix ) <> ls_binding-nsuri.
                  lo_writer->write_namespace_declaration( nsuri = ls_binding-nsuri prefix = ls_binding-prefix ).
                ENDIF.
              ENDDO.
            WHEN if_sxml_node=>co_nt_element_close.
              IF lt_path IS INITIAL.
                RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                  EXPORTING iv_message = 'Cierre XML inesperado en XLSX'.
              ENDIF.
              lo_writer->write_node( lo_node ).
              DELETE lt_path INDEX lines( lt_path ).
            WHEN if_sxml_node=>co_nt_initial OR if_sxml_node=>co_nt_final.
              CONTINUE.
            WHEN OTHERS.
              lo_writer->write_node( lo_node ).
          ENDCASE.
        ENDDO.
        IF lv_roots <> 1 OR lt_path IS NOT INITIAL OR ( iv_part = 'W' AND lv_sheets <> 1 ).
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'El XLSX debe tener XML completo y una única hoja'.
        ENDIF.
        rv_xml = lo_writer_buffer->get_output( ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_domain).
        RAISE EXCEPTION lx_domain.
      CATCH cx_root INTO DATA(lx_xml).
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |No se puede normalizar el XML XLSX: { lx_xml->get_text( ) }| previous = lx_xml.
    ENDTRY.
  ENDMETHOD.

  METHOD fix_xf_attributes.
    DATA(lo_legacy) = io_open->get_attribute_value( name = 'xf_id' ).
    IF lo_legacy IS INITIAL. RETURN. ENDIF.
    DATA(lo_canonical) = io_open->get_attribute_value( name = 'xfId' ).
    IF iv_parent = 'cellXfs' AND lo_canonical IS BOUND.
      IF CONV i( lo_legacy->get_value( ) ) <> CONV i( lo_canonical->get_value( ) ).
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Índices xf_id y xfId contradictorios en XLSX'.
      ENDIF.
    ENDIF.
    DATA(lt_attributes) = io_open->get_attributes( ).
    DATA lt_kept TYPE if_sxml_attribute=>attributes.
    DO lines( lt_attributes ) TIMES.
      READ TABLE lt_attributes INTO DATA(lo_attribute) INDEX sy-index.
      IF lo_attribute->qname-name = 'xf_id' AND lo_attribute->qname-namespace IS INITIAL. CONTINUE. ENDIF.
      APPEND lo_attribute TO lt_kept.
    ENDDO.
    io_open->set_attributes( lt_kept ).
    IF iv_parent = 'cellXfs' AND lo_canonical IS INITIAL.
      io_open->set_attribute( name = 'xfId' value = lo_legacy->get_value( ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

