*&---------------------------------------------------------------------*
*& Report ZCL_INTERCO_MD001_DATA_LOAD
* Initial data load to Relación Sociedades Intercompany por Conceptos
*&---------------------------------------------------------------------*
*& Autor: Gabriel Ribeiro dos Santos - Globant - 12-12-2023
*&---------------------------------------------------------------------*
REPORT zinterco_md001_data_load.

SELECTION-SCREEN: BEGIN OF BLOCK bloq1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_clean AS CHECKBOX DEFAULT '',
              p_file  TYPE rlgrap-filename.

SELECTION-SCREEN: END OF BLOCK bloq1.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  PERFORM open_folder.

START-OF-SELECTION.
  DATA: lt_excel_data LIKE alsmex_tabline OCCURS 0,
        lt_md001      TYPE STANDARD TABLE OF zint_a_md001,
        ls_md001      TYPE zint_a_md001.

  CLEAR: lt_md001, lt_md001[].

  IF p_clean EQ 'X'.
    zcl_interco_md001_data_load=>clean_table( ).
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

    APPEND INITIAL LINE TO lt_md001 ASSIGNING FIELD-SYMBOL(<lfs_md001>).

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
              uuid = <lfs_md001>-id.

          <lfs_md001>-providercompanycode = lv_value.
        WHEN 2.
          <lfs_md001>-recipientcompanycode = lv_value.
        WHEN 3.
          <lfs_md001>-product = lv_value.
        WHEN 4.
          <lfs_md001>-profitcenter = lv_value.
        WHEN 5.
          <lfs_md001>-flow = lv_value.
      ENDCASE.

      lv_column = lv_column + 1.

    ENDWHILE.

    IF lv_row = 1.
      CLEAR lt_cab[].
    ENDIF.

    lv_column = 1.
    lv_row = lv_row + 1.

  ENDWHILE.

  IF lt_md001 IS NOT INITIAL.
    DELETE lt_md001 WHERE providercompanycode IS INITIAL.
    DATA(lv_len) = zcl_interco_md001_data_load=>load_data( lt_md001 ). "#EC MSG_FIND
    MESSAGE |Total de registros cargados en la tabla ZINT_A_MD001: { lv_len }.| TYPE 'I'.
  ENDIF.

                                                           "#EC CI_FORM
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
