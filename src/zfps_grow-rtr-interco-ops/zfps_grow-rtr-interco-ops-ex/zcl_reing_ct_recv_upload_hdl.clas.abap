CLASS zcl_reing_ct_recv_upload_hdl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF gc_line_status,
        ok      TYPE c LENGTH 1 VALUE 'S',
        error   TYPE c LENGTH 1 VALUE 'E',
        warning TYPE c LENGTH 1 VALUE 'W',
      END OF gc_line_status.

    TYPES:
      BEGIN OF ty_create_line,
        rec_bukrs     TYPE zreing_ct2_rec_a-rec_bukrs,
        prctr         TYPE zreing_ct2_rec_a-prctr,
        country       TYPE zreing_ct2_rec_a-country,
        campana       TYPE zreing_ct2_rec_a-campana,
        role_category TYPE zreing_ct2_rec_a-role_category,
        allocation    TYPE zreing_ct2_rec_a-allocation,
      END OF ty_create_line,
      tt_create_line TYPE STANDARD TABLE OF ty_create_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_result_line,
        row_number TYPE i,
        rec_bukrs  TYPE zreing_ct2_rec_a-rec_bukrs,
        status     TYPE c LENGTH 1,
        message    TYPE string,
      END OF ty_result_line,
      tt_result_line TYPE STANDARD TABLE OF ty_result_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_import_result,
        aborted      TYPE abap_boolean,
        abort_reason TYPE string,
        results      TYPE tt_result_line,
        create_lines TYPE tt_create_line,
      END OF ty_import_result.

    METHODS import_file
      IMPORTING
        iv_ct_uuid      TYPE sysuuid_x16
        iv_mat_uuid     TYPE sysuuid_x16
        iv_file_content TYPE xstring
      RETURNING
        VALUE(rs_result) TYPE ty_import_result.

  PRIVATE SECTION.

    CONSTANTS:
      gc_title_bukrs   TYPE string VALUE 'Sociedad Receptora',
      gc_title_prctr   TYPE string VALUE 'Centro de Beneficio',
      gc_title_country TYPE string VALUE 'Pais',
      gc_title_campana TYPE string VALUE 'Campana',
      gc_title_rolecat TYPE string VALUE 'Categoria Gasto',
      " Mod 30.09.2026 EXT_AGFAGINA - DF-559: el titulo correcto es "Allocation".
      " Se sigue aceptando "Asignacion" para no rechazar templates ya descargados.
      " El template lo genera el front; este handler solo lo lee.
      gc_title_alloc     TYPE string VALUE 'Allocation',
      gc_title_alloc_old TYPE string VALUE 'Asignacion'.

    TYPES:
      BEGIN OF ty_raw_row,
        rec_bukrs     TYPE string,
        prctr         TYPE string,
        country       TYPE string,
        campana       TYPE string,
        role_category TYPE string,
        allocation    TYPE string,
      END OF ty_raw_row,
      tt_raw_row TYPE STANDARD TABLE OF ty_raw_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_company,
        companycode TYPE i_companycode-companycode,
        country     TYPE i_companycode-country,
      END OF ty_company.

    " Tipo auxiliar: mismo tipo que I_CompanyCode-CompanyCode
    TYPES ty_companycode TYPE i_companycode-companycode.

    " Tabla auxiliar para existing sin tipo BUKRS en key
    TYPES:
      BEGIN OF ty_existing,
        rec_bukrs     TYPE string,
        prctr         TYPE string,
        campana       TYPE string,
        role_category TYPE string,
        allocation    TYPE string,
      END OF ty_existing.

    METHODS read_rows
      IMPORTING iv_file_content TYPE xstring
      EXPORTING et_rows         TYPE tt_raw_row
                ev_ok           TYPE abap_boolean
                ev_reason       TYPE string.

ENDCLASS.

CLASS zcl_reing_ct_recv_upload_hdl IMPLEMENTATION.

  METHOD import_file.

    " --- Leer filas del Excel ---
    DATA lt_rows TYPE tt_raw_row.
    read_rows(
      EXPORTING iv_file_content = iv_file_content
      IMPORTING et_rows         = lt_rows
                ev_ok           = DATA(lv_ok)
                ev_reason       = DATA(lv_reason) ).

    IF lv_ok = abap_false.
      rs_result-aborted      = abap_true.
      rs_result-abort_reason = lv_reason.
      RETURN.
    ENDIF.

    " --- Pre-cargar receptoras existentes (tupla completa, como string) ---
    DATA lt_existing TYPE HASHED TABLE OF ty_existing
      WITH UNIQUE KEY rec_bukrs prctr campana role_category allocation.
    SELECT rec_bukrs, prctr, campana, role_category, allocation
      FROM zreing_ct2_rec_a
      WHERE ct_uuid  = @iv_ct_uuid
        AND mat_uuid = @iv_mat_uuid
      INTO TABLE @DATA(lt_exist_raw).
    LOOP AT lt_exist_raw INTO DATA(ls_ex).
      INSERT VALUE ty_existing(
        rec_bukrs     = CONV string( ls_ex-rec_bukrs )
        prctr         = CONV string( ls_ex-prctr )
        campana       = CONV string( ls_ex-campana )
        role_category = CONV string( ls_ex-role_category )
        allocation    = CONV string( ls_ex-allocation ) )
        INTO TABLE lt_existing.
    ENDLOOP.

    " --- Pre-cargar CompanyCode para validacion y derivacion de pais ---
    DATA lt_bukrs_keys TYPE SORTED TABLE OF ty_companycode
                       WITH UNIQUE KEY table_line.
    LOOP AT lt_rows INTO DATA(ls_row_key) WHERE rec_bukrs IS NOT INITIAL.
      INSERT CONV ty_companycode( ls_row_key-rec_bukrs )
        INTO TABLE lt_bukrs_keys.
    ENDLOOP.

    DATA lt_company TYPE SORTED TABLE OF ty_company WITH UNIQUE KEY companycode.
    IF lt_bukrs_keys IS NOT INITIAL.
      SELECT companycode, country FROM i_companycode
        FOR ALL ENTRIES IN @lt_bukrs_keys
        WHERE companycode = @lt_bukrs_keys-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_company.
    ENDIF.

    " --- Procesar filas ---
    DATA lv_rownum TYPE i VALUE 1.
    LOOP AT lt_rows INTO DATA(ls_row).
      lv_rownum = lv_rownum + 1.

      DATA(ls_res) = VALUE ty_result_line(
        row_number = lv_rownum
        rec_bukrs  = CONV #( ls_row-rec_bukrs ) ).

      " Sociedad obligatoria
      IF ls_row-rec_bukrs IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Sociedad Receptora obligatoria.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Centro de Beneficio obligatorio (BR-CT-SOC-01)
      IF ls_row-prctr IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Centro de Beneficio obligatorio.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Campana obligatoria y de 3 caracteres (BR-CT-SOC-02)
      IF ls_row-campana IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Campana obligatoria.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      IF strlen( ls_row-campana ) <> 3.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Campana debe tener 3 caracteres.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Categoria de gasto valida (BR-CT-SOC-03): C o E
      IF ls_row-role_category <> 'C' AND ls_row-role_category <> 'E'.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Categoria de gasto invalida (debe ser C o E).|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Asignacion valida (BR-CT-SOC-04): 0, 1 o 3
      IF ls_row-allocation <> '0' AND ls_row-allocation <> '1'
         AND ls_row-allocation <> '3'.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Allocation invalida (debe ser 0, 1 o 3).|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Sociedad debe existir en I_CompanyCode
      READ TABLE lt_company ASSIGNING FIELD-SYMBOL(<ls_co>)
        WITH KEY companycode = CONV ty_companycode( ls_row-rec_bukrs ).
      IF sy-subrc <> 0.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Fila { lv_rownum }: Sociedad '{ ls_row-rec_bukrs }' no existe en el sistema.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Aviso: la combinacion ya existe para el material (tupla completa)
      READ TABLE lt_existing TRANSPORTING NO FIELDS
        WITH TABLE KEY
          rec_bukrs     = ls_row-rec_bukrs
          prctr         = ls_row-prctr
          campana       = ls_row-campana
          role_category = ls_row-role_category
          allocation    = ls_row-allocation.
      IF sy-subrc = 0.
        ls_res-status  = gc_line_status-warning.
        ls_res-message = |Fila { lv_rownum }: la combinacion ya existe para este material. Se omite.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " OK — derivar pais desde I_CompanyCode si no vino en Excel
      DATA lv_country TYPE zreing_ct2_rec_a-country.
      lv_country = COND #(
        WHEN ls_row-country IS NOT INITIAL
        THEN CONV #( ls_row-country )
        ELSE <ls_co>-country ).

      ls_res-status  = gc_line_status-ok.
      ls_res-message = |Fila { lv_rownum }: OK.|.
      APPEND ls_res TO rs_result-results.

      APPEND VALUE ty_create_line(
        rec_bukrs     = CONV #( ls_row-rec_bukrs )
        prctr         = CONV #( ls_row-prctr )
        country       = lv_country
        campana       = CONV #( ls_row-campana )
        role_category = CONV #( ls_row-role_category )
        allocation    = CONV #( ls_row-allocation ) ) TO rs_result-create_lines.

    ENDLOOP.

  ENDMETHOD.


  METHOD read_rows.
    ev_ok = abap_true.

    TRY.
        DATA(lo_read) = xco_cp_xlsx=>document->for_file_content( iv_file_content
                          )->read_access( ).
        DATA(lo_sheet) = lo_read->get_workbook( )->worksheet->at_position( 1 ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudo abrir el archivo Excel.'.
        RETURN.
    ENDTRY.

    DATA(lo_hdr_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )
      )->to_row(      xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->get_pattern( ).

    TYPES: BEGIN OF ty_row6,
             c1 TYPE string, c2 TYPE string, c3 TYPE string,
             c4 TYPE string, c5 TYPE string, c6 TYPE string,
           END OF ty_row6.
    DATA lt_hdr TYPE STANDARD TABLE OF ty_row6 WITH EMPTY KEY.

    TRY.
        lo_sheet->select( lo_hdr_pattern
          )->row_stream( )->operation->write_to( REF #( lt_hdr )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudo leer la fila de titulos.'.
        RETURN.
    ENDTRY.

    DATA(ls_hdr) = VALUE ty_row6( lt_hdr[ 1 ] OPTIONAL ).

    TYPES: BEGIN OF ty_colmap,
             title TYPE string,
             col   TYPE i,
           END OF ty_colmap.
    DATA lt_colmap TYPE SORTED TABLE OF ty_colmap WITH UNIQUE KEY title.
    DATA lt_hdr_seq TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    lt_hdr_seq = VALUE #(
      ( condense( ls_hdr-c1 ) )
      ( condense( ls_hdr-c2 ) )
      ( condense( ls_hdr-c3 ) )
      ( condense( ls_hdr-c4 ) )
      ( condense( ls_hdr-c5 ) )
      ( condense( ls_hdr-c6 ) ) ).

    LOOP AT lt_hdr_seq ASSIGNING FIELD-SYMBOL(<lv_title>).
      DATA(lv_idx) = sy-tabix.
      IF <lv_title> IS NOT INITIAL.
        INSERT VALUE ty_colmap( title = <lv_title> col = lv_idx )
          INTO TABLE lt_colmap.
      ENDIF.
    ENDLOOP.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_bukrs.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_bukrs }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_prctr.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_prctr }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_campana.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_campana }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_rolecat.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_rolecat }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_alloc.
    IF sy-subrc <> 0.
      " Mod 30.09.2026 EXT_AGFAGINA - DF-559: template anterior al cambio.
      READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_alloc_old.
    ENDIF.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_alloc }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    DATA(lo_data_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
      )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( 'F' )
      )->get_pattern( ).

    DATA lt_data TYPE STANDARD TABLE OF ty_row6 WITH EMPTY KEY.
    TRY.
        lo_sheet->select( lo_data_pattern
          )->row_stream( )->operation->write_to( REF #( lt_data )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudieron leer las filas de datos.'.
        RETURN.
    ENDTRY.

    DATA(lv_col_bukrs)   = VALUE i( lt_colmap[ title = gc_title_bukrs   ]-col OPTIONAL ).
    DATA(lv_col_prctr)   = VALUE i( lt_colmap[ title = gc_title_prctr   ]-col OPTIONAL ).
    DATA(lv_col_country) = VALUE i( lt_colmap[ title = gc_title_country ]-col OPTIONAL ).
    DATA(lv_col_campana) = VALUE i( lt_colmap[ title = gc_title_campana ]-col OPTIONAL ).
    DATA(lv_col_rolecat) = VALUE i( lt_colmap[ title = gc_title_rolecat ]-col OPTIONAL ).
    DATA(lv_col_alloc)   = VALUE i( lt_colmap[ title = gc_title_alloc   ]-col OPTIONAL ).
    " Mod 30.09.2026 EXT_AGFAGINA - DF-559: template anterior al cambio.
    IF lv_col_alloc = 0.
      lv_col_alloc = VALUE i( lt_colmap[ title = gc_title_alloc_old ]-col OPTIONAL ).
    ENDIF.

    FIELD-SYMBOLS <lv_cell> TYPE string.
    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      IF <ls_data>-c1 IS INITIAL AND <ls_data>-c2 IS INITIAL
         AND <ls_data>-c3 IS INITIAL AND <ls_data>-c4 IS INITIAL
         AND <ls_data>-c5 IS INITIAL AND <ls_data>-c6 IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_out) = VALUE ty_raw_row( ).

      IF lv_col_bukrs > 0.
        ASSIGN COMPONENT lv_col_bukrs OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-rec_bukrs = to_upper( condense( <lv_cell> ) ). ENDIF.
      ENDIF.
      IF lv_col_prctr > 0.
        ASSIGN COMPONENT lv_col_prctr OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-prctr = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_country > 0.
        ASSIGN COMPONENT lv_col_country OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-country = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_campana > 0.
        ASSIGN COMPONENT lv_col_campana OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-campana = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_rolecat > 0.
        ASSIGN COMPONENT lv_col_rolecat OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-role_category = to_upper( condense( <lv_cell> ) ). ENDIF.
      ENDIF.
      IF lv_col_alloc > 0.
        ASSIGN COMPONENT lv_col_alloc OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-allocation = condense( <lv_cell> ). ENDIF.
      ENDIF.

      APPEND ls_out TO et_rows.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

