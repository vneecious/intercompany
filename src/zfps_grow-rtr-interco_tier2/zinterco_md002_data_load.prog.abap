*&---------------------------------------------------------------------*
*& Report ZCL_INTERCO_md002_DATA_LOAD
* Initial data load to Conceptos Facturables por Empresa Prestadora
*&---------------------------------------------------------------------*
*& Autor: Gabriel Ribeiro dos Santos - Globant - 07-11-2024
*&---------------------------------------------------------------------*
REPORT zinterco_md002_data_load.

SELECTION-SCREEN: BEGIN OF BLOCK bloq1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_clean AS CHECKBOX DEFAULT '',
              p_file  TYPE rlgrap-filename.

SELECTION-SCREEN: END OF BLOCK bloq1.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM open_folder.

START-OF-SELECTION.
  DATA: lt_excel_data LIKE z001_str_alsmex_tabline OCCURS 0,
        lt_md002      TYPE STANDARD TABLE OF zint_a_md002,
        ls_md002      TYPE zint_a_md002.

  CLEAR: lt_md002, lt_md002[].

  IF p_clean EQ 'X'.
    zcl_interco_md002_data_load=>clean_table( ).
  ENDIF.

  DATA vl_file TYPE string.
  DATA : lv_filename      TYPE string,
         lt_records       TYPE solix_tab,
         lv_headerxstring TYPE xstring,
         lv_filelength    TYPE i.

  TYPES: BEGIN OF ty_s_row,
           a TYPE string,
           b TYPE string,
           c TYPE string,
           d TYPE string,
           e TYPE string,
           f TYPE string,
           g TYPE string,
         END OF ty_s_row.

  DATA(lo_reader)  = NEW zcl_excel_reader_2007( ).
  DATA: lv_row    TYPE int4 VALUE 1,
        lv_column TYPE zexcel_cell_column VALUE 1,
        lv_value  TYPE zexcel_cell_value,
        lt_cab    TYPE STANDARD TABLE OF ty_s_row.

  vl_file = p_file.

  TRY.
      DATA(lo_excel) = lo_reader->zif_excel_reader~load_file( vl_file ).
    CATCH zcx_z001_root.
  ENDTRY.

  TRY.
      DATA(lo_worksheet) = lo_excel->get_worksheet_by_index( 1 ).
    CATCH zcx_z001_root.
  ENDTRY.

  TRY.
      DATA(lv_highest_column) = lo_worksheet->get_highest_column( ).
    CATCH zcx_z001_root.
  ENDTRY.

  TRY.
      DATA(lv_highest_row) = lo_worksheet->get_highest_row( ).
    CATCH zcx_z001_root.
  ENDTRY.

*...Se recorre cada uno de los campos que compone el archivo de EXCEL
  WHILE lv_row <= lv_highest_row.
    IF lv_row EQ 1.
      lv_row = lv_row + 1.
      CONTINUE.
    ENDIF.

    APPEND INITIAL LINE TO lt_md002 ASSIGNING FIELD-SYMBOL(<lfs_md002>).

    WHILE lv_column <= lv_highest_column.
      DATA(lv_col_str) = zcl_excel_common=>convert_column2alpha( lv_column ).

      lo_worksheet->get_cell(
        EXPORTING
          ip_column = lv_col_str
          ip_row    = lv_row
        IMPORTING
          ep_value  = lv_value ).

*.......Armar Linea
      CASE lv_column.
        WHEN 1.
          CALL FUNCTION 'SYSTEM_UUID_CREATE'
            IMPORTING
              uuid = <lfs_md002>-id.

          <lfs_md002>-product = lv_value.
        WHEN 2.
          <lfs_md002>-providercompanycode = lv_value.
        WHEN 3.
          <lfs_md002>-pandlid = lv_value.
        WHEN 4.
          <lfs_md002>-profitcenter = lv_value.
        WHEN 5.
          <lfs_md002>-costcentersubarea = lv_value.
        WHEN 6.
          IF  lv_value IS NOT INITIAL.
            <lfs_md002>-costcenterallocation = lv_value(2).
          ENDIF.
        WHEN 7.
          <lfs_md002>-isnotbilable = lv_value.
      ENDCASE.

      lv_column = lv_column + 1.

    ENDWHILE.

    IF lv_row = 1.
      CLEAR lt_cab[].
    ENDIF.

    lv_column = 1.
    lv_row = lv_row + 1.

  ENDWHILE.

  IF lt_md002 IS NOT INITIAL.
    DELETE lt_md002 WHERE product IS INITIAL.
    DATA(lv_len) = zcl_interco_md002_data_load=>load_data( lt_md002 ).
    MESSAGE |Total de registros cargados en la tabla ZINT_A_MD002: { lv_len }.| TYPE 'I'.
  ENDIF.


FORM open_folder .
  DATA: li_file  TYPE TABLE OF sdokpath,
        lwa_file TYPE sdokpath.
  CLEAR: p_file, lwa_file.
  REFRESH li_file[].
  CALL FUNCTION 'TMP_GUI_FILE_OPEN_DIALOG'
    TABLES
      file_table = li_file
    EXCEPTIONS
      cntl_error = 1
      OTHERS     = 2.
  IF sy-subrc IS INITIAL.
    READ TABLE li_file INTO lwa_file INDEX 1.
    IF sy-subrc IS INITIAL.
      p_file = lwa_file-pathname.
    ENDIF.
  ENDIF.
ENDFORM.                    "open_folder
