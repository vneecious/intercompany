CLASS zcl_reing_ct_gl_upload_hdl DEFINITION
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
        gl_role    TYPE zreing_ct2_gl_a-gl_role,
        saknr      TYPE zreing_ct2_gl_a-saknr,
        reclassify TYPE zreing_ct2_gl_a-reclassify,
      END OF ty_create_line,
      tt_create_line TYPE STANDARD TABLE OF ty_create_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_result_line,
        row_number TYPE i,
        gl_role    TYPE zreing_ct2_gl_a-gl_role,
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
        iv_ct_uuid       TYPE sysuuid_x16
        iv_mat_uuid      TYPE sysuuid_x16
        iv_file_content  TYPE xstring
      RETURNING
        VALUE(rs_result) TYPE ty_import_result.

  PRIVATE SECTION.

    CONSTANTS:
      gc_title_role     TYPE string VALUE 'Rol_Contable',
      gc_title_account  TYPE string VALUE 'Cuenta_GL',
      gc_title_reclas   TYPE string VALUE 'Reclasificable',
      gc_title_roledest TYPE string VALUE 'Rol_Destino'.

    CONSTANTS gc_max_role_len TYPE i VALUE 4.

    TYPES:
      BEGIN OF ty_raw_row,
        gl_role   TYPE string,
        saknr     TYPE string,
        reclas    TYPE string,
        roledest  TYPE string,
      END OF ty_raw_row,
      tt_raw_row TYPE STANDARD TABLE OF ty_raw_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_role,
        gl_role     TYPE zreing_gl_roles-gl_role,
        reclassify  TYPE zreing_gl_roles-reclassify,
        role_reclas TYPE zreing_gl_roles-role_reclas,
      END OF ty_role.

    METHODS read_rows
      IMPORTING iv_file_content TYPE xstring
      EXPORTING et_rows         TYPE tt_raw_row
                ev_ok           TYPE abap_boolean
                ev_reason       TYPE string.

ENDCLASS.



CLASS zcl_reing_ct_gl_upload_hdl IMPLEMENTATION.

  METHOD import_file.

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

    " RV-09: tope de 500 lineas por carga (antes lo validaba el front; ahora en backend)
    IF lines( lt_rows ) > 500.
      rs_result-aborted      = abap_true.
      rs_result-abort_reason =
        |El archivo tiene { lines( lt_rows ) } filas y supera el maximo de 500 lineas permitidas por carga.|.
      RETURN.
    ENDIF.

    " Pre-cargar catalogo de roles (un solo SELECT)
    DATA lt_role_keys TYPE SORTED TABLE OF zreing_gl_roles-gl_role
                      WITH UNIQUE KEY table_line.
    LOOP AT lt_rows INTO DATA(ls_row_key) WHERE gl_role IS NOT INITIAL.
      INSERT CONV zreing_gl_roles-gl_role( to_upper( condense( ls_row_key-gl_role ) ) )
        INTO TABLE lt_role_keys.
      IF ls_row_key-roledest IS NOT INITIAL.
        INSERT CONV zreing_gl_roles-gl_role( to_upper( condense( ls_row_key-roledest ) ) )
          INTO TABLE lt_role_keys.
      ENDIF.
    ENDLOOP.

    DATA lt_catalog TYPE SORTED TABLE OF ty_role WITH UNIQUE KEY gl_role.
    IF lt_role_keys IS NOT INITIAL.
      SELECT gl_role, reclassify, role_reclas
        FROM zreing_gl_roles
        FOR ALL ENTRIES IN @lt_role_keys
        WHERE gl_role = @lt_role_keys-table_line
        INTO CORRESPONDING FIELDS OF TABLE @lt_catalog.
    ENDIF.

    " Pre-cargar cuentas GL informadas (un solo SELECT)
    DATA lt_acct_keys TYPE SORTED TABLE OF i_glaccountincompanycode-glaccount
                      WITH UNIQUE KEY table_line.
    DATA lv_acct_key TYPE i_glaccountincompanycode-glaccount.
    LOOP AT lt_rows INTO DATA(ls_acct_key) WHERE saknr IS NOT INITIAL.
      lv_acct_key = condense( ls_acct_key-saknr ).
      " saknr puede venir como '245166.0' (celda tipo numero en Excel): tomar solo parte entera
      IF lv_acct_key CA '.'.
        SPLIT lv_acct_key AT '.' INTO lv_acct_key DATA(lv_dec_pre).
      ENDIF.
      lv_acct_key = |{ lv_acct_key ALPHA = IN }|.
      INSERT lv_acct_key INTO TABLE lt_acct_keys.
    ENDLOOP.

    TYPES: BEGIN OF ty_acct,
             glaccount TYPE i_glaccountincompanycode-glaccount,
           END OF ty_acct.
    DATA lt_accounts TYPE SORTED TABLE OF ty_acct WITH UNIQUE KEY glaccount.
    IF lt_acct_keys IS NOT INITIAL.
      DATA lr_accounts TYPE RANGE OF i_glaccountincompanycode-glaccount.
      lr_accounts = VALUE #( FOR key IN lt_acct_keys
                             ( sign = 'I' option = 'EQ' low = key ) ).
      SELECT DISTINCT glaccount FROM i_glaccountinchartofaccounts
        WHERE glaccount IN @lr_accounts
        INTO CORRESPONDING FIELDS OF TABLE @lt_accounts.
    ENDIF.

    DATA lv_rownum TYPE i VALUE 1.
    LOOP AT lt_rows INTO DATA(ls_row).
      lv_rownum = lv_rownum + 1.

      DATA(lv_role)     = to_upper( condense( ls_row-gl_role ) ).
      DATA(lv_roledest) = to_upper( condense( ls_row-roledest ) ).
      DATA(lv_reclas)   = to_upper( condense( ls_row-reclas ) ).
      DATA(lv_saknr)    = condense( ls_row-saknr ).

      DATA(ls_res) = VALUE ty_result_line(
        row_number = lv_rownum
        gl_role    = CONV #( lv_role ) ).

      IF lv_role IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Rol Contable obligatorio.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      IF strlen( lv_role ) > gc_max_role_len.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Rol Contable '{ lv_role }' excede { gc_max_role_len } caracteres.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      READ TABLE lt_catalog ASSIGNING FIELD-SYMBOL(<ls_cat>)
        WITH KEY gl_role = lv_role.
      IF sy-subrc <> 0.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |'{ lv_role }' no es un rol contable valido.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      IF lv_reclas IS NOT INITIAL AND lv_reclas <> 'S' AND lv_reclas <> 'N' AND lv_reclas <> 'X'.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Reclasificable '{ lv_reclas }' invalido: se aceptan S, N o X.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      DATA(lv_is_reclas) = xsdbool( lv_reclas = 'X' OR lv_reclas = 'S' ).

      IF lv_is_reclas = abap_true AND lv_roledest IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Rol Destino obligatorio cuando Reclasificable = X.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      IF lv_is_reclas = abap_true.
        IF strlen( lv_roledest ) > gc_max_role_len.
          ls_res-status  = gc_line_status-error.
          ls_res-message = |Rol Destino '{ lv_roledest }' excede { gc_max_role_len } caracteres.|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
        IF <ls_cat>-role_reclas IS INITIAL.
          ls_res-status  = gc_line_status-error.
          ls_res-message = |El rol '{ lv_role }' no tiene rol destino configurado en el catalogo.|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
        IF to_upper( CONV string( <ls_cat>-role_reclas ) ) <> lv_roledest.
          ls_res-status  = gc_line_status-error.
          ls_res-message =
            |Rol Destino '{ lv_roledest }' no coincide con el configurado en el catalogo | &&
            |('{ <ls_cat>-role_reclas }') para el rol '{ lv_role }'.|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
      ENDIF.

      DATA lv_saknr_alpha TYPE i_glaccountincompanycode-glaccount.
      CLEAR lv_saknr_alpha.
      IF lv_saknr IS NOT INITIAL.
        " saknr puede venir como '245166.0' (celda tipo numero en Excel): tomar solo parte entera
        IF lv_saknr CA '.'.
          SPLIT lv_saknr AT '.' INTO lv_saknr DATA(lv_dec_row).
        ENDIF.
        lv_saknr_alpha = lv_saknr.
        lv_saknr_alpha = |{ lv_saknr_alpha ALPHA = IN }|.
        READ TABLE lt_accounts TRANSPORTING NO FIELDS
          WITH KEY glaccount = lv_saknr_alpha.
        IF sy-subrc <> 0.
          ls_res-status  = gc_line_status-error.
          ls_res-message = |Cuenta GL '{ lv_saknr }' no existe en el plan de cuentas.|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
      ENDIF.

      ls_res-status  = gc_line_status-ok.
      ls_res-message = |Fila { lv_rownum }: OK.|.
      APPEND ls_res TO rs_result-results.

      APPEND VALUE ty_create_line(
        gl_role    = CONV #( lv_role )
        saknr      = COND #( WHEN lv_saknr IS NOT INITIAL
                             THEN CONV #( lv_saknr_alpha )
                             ELSE space )
        reclassify = COND #( WHEN lv_is_reclas = abap_true THEN 'X' ELSE space )
      ) TO rs_result-create_lines.

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
      )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( 'E' )
      )->to_row(      xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
      )->get_pattern( ).

    TYPES: BEGIN OF ty_row5,
             c1 TYPE string, c2 TYPE string, c3 TYPE string,
             c4 TYPE string, c5 TYPE string,
           END OF ty_row5.
    DATA lt_hdr TYPE STANDARD TABLE OF ty_row5 WITH EMPTY KEY.

    TRY.
        lo_sheet->select( lo_hdr_pattern
          )->row_stream( )->operation->write_to( REF #( lt_hdr )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudo leer la fila de titulos.'.
        RETURN.
    ENDTRY.

    DATA(ls_hdr) = VALUE ty_row5( lt_hdr[ 1 ] OPTIONAL ).

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
      ( condense( ls_hdr-c5 ) ) ).

    LOOP AT lt_hdr_seq ASSIGNING FIELD-SYMBOL(<lv_title>).
      DATA(lv_idx) = sy-tabix.
      IF <lv_title> IS NOT INITIAL.
        INSERT VALUE ty_colmap( title = <lv_title> col = lv_idx )
          INTO TABLE lt_colmap.
      ENDIF.
    ENDLOOP.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_role.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_role }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = gc_title_reclas.
    IF sy-subrc <> 0.
      ev_ok     = abap_false.
      ev_reason = |Columna '{ gc_title_reclas }' no encontrada. Verifique el template.|.
      RETURN.
    ENDIF.

    DATA(lo_data_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
      )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( 'E' )
      )->get_pattern( ).

    DATA lt_data TYPE STANDARD TABLE OF ty_row5 WITH EMPTY KEY.
    TRY.
        lo_sheet->select( lo_data_pattern
          )->row_stream( )->operation->write_to( REF #( lt_data )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudieron leer las filas de datos.'.
        RETURN.
    ENDTRY.

    DATA(lv_col_role)     = VALUE i( lt_colmap[ title = gc_title_role     ]-col OPTIONAL ).
    DATA(lv_col_account)  = VALUE i( lt_colmap[ title = gc_title_account  ]-col OPTIONAL ).
    DATA(lv_col_reclas)   = VALUE i( lt_colmap[ title = gc_title_reclas   ]-col OPTIONAL ).
    DATA(lv_col_roledest) = VALUE i( lt_colmap[ title = gc_title_roledest ]-col OPTIONAL ).

    FIELD-SYMBOLS <lv_cell> TYPE string.
    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      IF <ls_data>-c1 IS INITIAL AND <ls_data>-c2 IS INITIAL
         AND <ls_data>-c3 IS INITIAL AND <ls_data>-c4 IS INITIAL
         AND <ls_data>-c5 IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_out) = VALUE ty_raw_row( ).

      IF lv_col_role > 0.
        ASSIGN COMPONENT lv_col_role OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-gl_role = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_account > 0.
        ASSIGN COMPONENT lv_col_account OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-saknr = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_reclas > 0.
        ASSIGN COMPONENT lv_col_reclas OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-reclas = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_col_roledest > 0.
        ASSIGN COMPONENT lv_col_roledest OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-roledest = condense( <lv_cell> ). ENDIF.
      ENDIF.

      APPEND ls_out TO et_rows.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
