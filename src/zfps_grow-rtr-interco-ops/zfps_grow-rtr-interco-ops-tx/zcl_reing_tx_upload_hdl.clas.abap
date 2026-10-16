CLASS zcl_reing_tx_upload_hdl DEFINITION
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
        country     TYPE zreing_tx_rule_a-country,
        tax_type    TYPE zreing_tx_rule_a-tax_type,
        matnr       TYPE zreing_tx_rule_a-matnr,
        lifnr       TYPE zreing_tx_rule_a-lifnr,
        rate        TYPE zreing_tx_rule_a-rate,
        gross_up    TYPE zreing_tx_rule_a-gross_up,
        valid_from  TYPE zreing_tx_rule_a-valid_from,
        valid_to    TYPE zreing_tx_rule_a-valid_to,
        tx_status   TYPE zreing_tx_rule_a-tx_status,
        description TYPE zreing_tx_rule_a-description,
        " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
        " ET-REING-BR-001 v5 SS4.2 -- los 3 campos de matching nuevos del motor
        " de especificidad viajan desde el Excel hasta el CREATE de la entidad.
        " Sin ellos aca, read_rows los parsearia y uploadRules los descartaria
        " en silencio: la carga masiva seguiria creando reglas sin prestadora.
        country_prest TYPE zreing_tx_rule_a-country_prest,
        bukrs_prest   TYPE zreing_tx_rule_a-bukrs_prest,
        bukrs_recv    TYPE zreing_tx_rule_a-bukrs_recv,
        " End Insert V009 (15.09.2026 | EXT_GONZALCA)
      END OF ty_create_line,
      tt_create_line TYPE STANDARD TABLE OF ty_create_line WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_result_line,
        row_number TYPE i,
        country    TYPE zreing_tx_rule_a-country,
        tax_type   TYPE zreing_tx_rule_a-tax_type,
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

    " DF-TX - Genera el template .xlsx vacio (solo fila de titulos) con el layout
    " EXACTO que espera read_rows. Evita que el usuario lo arme a mano: un
    " archivo con menos columnas hace fallar la lectura de titulos.
    " Mod V009 (15.09.2026): el layout pasa de A..L a A..O (ver export_template).
    METHODS export_template
      RETURNING VALUE(rv_xstring) TYPE xstring.

    METHODS import_file
      IMPORTING iv_file_content  TYPE xstring
      RETURNING VALUE(rs_result) TYPE ty_import_result.

  PRIVATE SECTION.

    " Titulos del template — alineados con el Excel de bajada de la app TX.
    " Columnas A (Regla ID), I (Especificidad) y L (Estado) se ignoran:
    " se generan automaticamente / se asignan por defecto.
    CONSTANTS:
      gc_title_country  TYPE string VALUE 'Pais',
      gc_title_desc     TYPE string VALUE 'Descripcion',
      gc_title_lifnr    TYPE string VALUE 'Proveedor (LIFNR)',
      gc_title_matnr    TYPE string VALUE 'Material (MATNR)',
      gc_title_taxtype  TYPE string VALUE 'Tipo Impuesto',
      gc_title_rate     TYPE string VALUE 'Tasa (%)',
      gc_title_grossup  TYPE string VALUE 'Gross Up',
      gc_title_from     TYPE string VALUE 'Vigente Desde',
      gc_title_to       TYPE string VALUE 'Vigente Hasta',
      " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
      " Titulos de las 3 columnas nuevas (M, N, O). Los textos coinciden
      " EXACTAMENTE con los labels de ZC_ReingTXRule, porque el usuario baja
      " el Excel de la app y vuelve a subirlo: si difieren, el mapeo por
      " titulo de read_rows no las encuentra y quedan vacias sin avisar.
      gc_title_cty_prest TYPE string VALUE 'Pais Prestadora',
      gc_title_buk_prest TYPE string VALUE 'Soc. Prestadora',
      gc_title_buk_recv  TYPE string VALUE 'Soc. Receptora'.
      " End Insert V009 (15.09.2026 | EXT_GONZALCA)

    TYPES:
      BEGIN OF ty_raw_row,
        country  TYPE string,
        desc     TYPE string,
        lifnr    TYPE string,
        matnr    TYPE string,
        tax_type TYPE string,
        rate     TYPE string,
        gross_up TYPE string,
        from     TYPE string,
        to       TYPE string,
        " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
        cty_prest TYPE string,
        buk_prest TYPE string,
        buk_recv  TYPE string,
        " End Insert V009 (15.09.2026 | EXT_GONZALCA)
      END OF ty_raw_row,
      tt_raw_row TYPE STANDARD TABLE OF ty_raw_row WITH EMPTY KEY.

    METHODS read_rows
      IMPORTING iv_file_content TYPE xstring
      EXPORTING et_rows         TYPE tt_raw_row
                ev_ok           TYPE abap_boolean
                ev_reason       TYPE string.

    " Convierte fecha de texto (dd/mm/aaaa, aaaa-mm-dd o aaaammdd) a DATS.
    METHODS parse_date
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_date) TYPE d.

    " Convierte tasa de texto (admite coma o punto decimal) a DEC.
    METHODS parse_rate
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_rate) TYPE zreing_tx_rule_a-rate.

ENDCLASS.


CLASS zcl_reing_tx_upload_hdl IMPLEMENTATION.

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

    "--- Pre-cargar catalogo de tipos impositivos (un solo SELECT) ---
    DATA lt_taxtype_keys TYPE SORTED TABLE OF zreing_tx_type_c-tax_type
                         WITH UNIQUE KEY table_line.
    LOOP AT lt_rows INTO DATA(ls_tk) WHERE tax_type IS NOT INITIAL.
      INSERT CONV zreing_tx_type_c-tax_type( to_upper( condense( ls_tk-tax_type ) ) )
        INTO TABLE lt_taxtype_keys.
    ENDLOOP.

    DATA lt_taxtype TYPE SORTED TABLE OF zreing_tx_type_c-tax_type
                    WITH UNIQUE KEY table_line.
    IF lt_taxtype_keys IS NOT INITIAL.
      SELECT tax_type FROM zreing_tx_type_c
        FOR ALL ENTRIES IN @lt_taxtype_keys
        WHERE tax_type = @lt_taxtype_keys-table_line
          AND active   = 'X'
        INTO TABLE @lt_taxtype.
    ENDIF.

    "--- Pre-cargar paises validos (un solo SELECT) ---
    DATA lt_country_keys TYPE SORTED TABLE OF land1 WITH UNIQUE KEY table_line.
    LOOP AT lt_rows INTO DATA(ls_ck) WHERE country IS NOT INITIAL.
      INSERT CONV land1( to_upper( condense( ls_ck-country ) ) )
        INTO TABLE lt_country_keys.
    ENDLOOP.

    TYPES: BEGIN OF ty_country,
             country TYPE land1,
           END OF ty_country.
    DATA lt_country TYPE SORTED TABLE OF ty_country WITH UNIQUE KEY country.
    IF lt_country_keys IS NOT INITIAL.
      SELECT Country AS country FROM I_Country WITH PRIVILEGED ACCESS
        FOR ALL ENTRIES IN @lt_country_keys
        WHERE Country = @lt_country_keys-table_line
        INTO TABLE @lt_country.
    ENDIF.

    "--- Validacion por linea (N2) ---
    DATA lv_rownum TYPE i VALUE 1.
    LOOP AT lt_rows INTO DATA(ls_row).
      lv_rownum = lv_rownum + 1.

      DATA(lv_country)  = to_upper( condense( ls_row-country ) ).
      DATA(lv_taxtype)  = to_upper( condense( ls_row-tax_type ) ).
      DATA(lv_grossup)  = to_upper( condense( ls_row-gross_up ) ).
      DATA(lv_desc)     = condense( ls_row-desc ).
      DATA(lv_lifnr)    = condense( ls_row-lifnr ).
      DATA(lv_matnr)    = condense( ls_row-matnr ).
      " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
      " ET-REING-BR-001 v5 SS4.2. Solo se normalizan a mayusculas: la EXISTENCIA
      " de pais y sociedades la valida ZCL_REING_TX_RULE_BP~validate_country,
      " que ya cubre los 3 campos desde V009 y corre igual sobre las reglas que
      " este metodo crea en draft. Repetir el chequeo aca duplicaria la regla en
      " dos lugares que habria que mantener sincronizados.
      " BUKRS no lleva conversion ALPHA (es CHAR 4, no un numerico con padding
      " como LIFNR/MATNR).
      DATA(lv_cty_prest) = to_upper( condense( ls_row-cty_prest ) ).
      DATA(lv_buk_prest) = to_upper( condense( ls_row-buk_prest ) ).
      DATA(lv_buk_recv)  = to_upper( condense( ls_row-buk_recv ) ).
      " End Insert V009 (15.09.2026 | EXT_GONZALCA)

      DATA(ls_res) = VALUE ty_result_line(
        row_number = lv_rownum
        country    = CONV #( lv_country )
        tax_type   = CONV #( lv_taxtype ) ).

      " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
      " El pais dejo de ser obligatorio: vacio = wildcard del motor de
      " especificidad (SS4.5), decidido en la consulta A-12(2). Este era el
      " SEPTIMO lugar donde el caracter obligatorio estaba cableado -- ademas
      " de validate_country y del "field ( mandatory : create )" del BDEF, ya
      " relajados en A4, y de lt_required en read_rows. Si quedaba, la carga
      " masiva rechazaba filas que la app acepta por pantalla.
      " Si viene informado, se sigue exigiendo que exista.
      " Lineas originales conservadas como referencia:
      "    IF lv_country IS INITIAL.
      "      ls_res-status  = gc_line_status-error.
      "      ls_res-message = 'Pais obligatorio.'.
      "      APPEND ls_res TO rs_result-results.
      "      CONTINUE.
      "    ENDIF.
      IF lv_country IS NOT INITIAL.
        READ TABLE lt_country TRANSPORTING NO FIELDS WITH KEY country = lv_country.
        IF sy-subrc <> 0.
          ls_res-status  = gc_line_status-error.
          ls_res-message = |Pais '{ lv_country }' inexistente.|.
          APPEND ls_res TO rs_result-results.
          CONTINUE.
        ENDIF.
      ENDIF.
      " End Change ID V009 (15.09.2026 | EXT_GONZALCA)

      " Descripcion obligatoria
      IF lv_desc IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Descripcion obligatoria.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Tipo impuesto obligatorio + existente/activo en catalogo
      IF lv_taxtype IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Tipo Impuesto obligatorio.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      READ TABLE lt_taxtype TRANSPORTING NO FIELDS WITH KEY table_line = lv_taxtype.
      IF sy-subrc <> 0.
        ls_res-status  = gc_line_status-error.
        ls_res-message = |Tipo Impuesto '{ lv_taxtype }' inexistente o inactivo en el catalogo.|.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Tasa obligatoria + numerica
      IF ls_row-rate IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Tasa obligatoria.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      DATA(lv_rate) = parse_rate( ls_row-rate ).

      " Fechas de vigencia obligatorias
      DATA(lv_from) = parse_date( ls_row-from ).
      DATA(lv_to)   = parse_date( ls_row-to ).
      IF lv_from IS INITIAL OR lv_to IS INITIAL.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Vigencia Desde/Hasta obligatoria o con formato invalido.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.
      IF lv_from >= lv_to.
        ls_res-status  = gc_line_status-error.
        ls_res-message = 'Vigencia Hasta debe ser posterior a Vigente Desde.'.
        APPEND ls_res TO rs_result-results.
        CONTINUE.
      ENDIF.

      " Gross Up: normalizar a 'X' o vacio
      DATA lv_grossup_flag TYPE zreing_tx_rule_a-gross_up.
      CLEAR lv_grossup_flag.
      IF lv_grossup = 'X' OR lv_grossup = 'S' OR lv_grossup = 'SI'
         OR lv_grossup = 'TRUE' OR lv_grossup = '1'.
        lv_grossup_flag = 'X'.
      ENDIF.

      " OK
      ls_res-status  = gc_line_status-ok.
      ls_res-message = |Fila { lv_rownum }: OK.|.
      APPEND ls_res TO rs_result-results.

      APPEND VALUE ty_create_line(
        country     = CONV #( lv_country )
        tax_type    = CONV #( lv_taxtype )
        matnr       = COND #( WHEN lv_matnr IS NOT INITIAL
                              THEN CONV #( |{ lv_matnr ALPHA = IN }| )
                              ELSE space )
        lifnr       = COND #( WHEN lv_lifnr IS NOT INITIAL
                              THEN CONV #( |{ lv_lifnr ALPHA = IN }| )
                              ELSE space )
        rate        = lv_rate
        gross_up    = lv_grossup_flag
        valid_from  = lv_from
        valid_to    = lv_to
        tx_status   = 'AC'
        description = CONV #( lv_desc )
        " V009: los 3 campos del motor de especificidad. Vacio = wildcard.
        country_prest = CONV #( lv_cty_prest )
        bukrs_prest   = CONV #( lv_buk_prest )
        bukrs_recv    = CONV #( lv_buk_recv )
      ) TO rs_result-create_lines.

    ENDLOOP.

  ENDMETHOD.


  METHOD parse_rate.
    DATA lv_txt TYPE string.
    lv_txt = condense( iv_text ).
    " Admitir coma decimal -> punto
    REPLACE ALL OCCURRENCES OF ',' IN lv_txt WITH '.'.
    TRY.
        rv_rate = CONV zreing_tx_rule_a-rate( lv_txt ).
      CATCH cx_sy_conversion_no_number.
        CLEAR rv_rate.
    ENDTRY.
  ENDMETHOD.


  METHOD parse_date.
    DATA lv_txt TYPE string.
    lv_txt = condense( iv_text ).
    CLEAR rv_date.
    IF lv_txt IS INITIAL.
      RETURN.
    ENDIF.

    " Caso 1: ya viene como aaaammdd (8 digitos)
    IF strlen( lv_txt ) = 8 AND lv_txt CO '0123456789'.
      rv_date = lv_txt.
      RETURN.
    ENDIF.

    " Caso 2: aaaa-mm-dd  (incluye timestamps tipo 'aaaa-mm-dd 00:00:00')
    IF lv_txt CS '-'.
      DATA lv_datepart TYPE string.
      SPLIT lv_txt AT space INTO lv_datepart DATA(lv_rest).
      SPLIT lv_datepart AT '-' INTO DATA(lv_a) DATA(lv_b) DATA(lv_c).
      IF strlen( lv_a ) = 4.
        rv_date = |{ lv_a }{ lv_b WIDTH = 2 ALIGN = RIGHT PAD = '0' }{ lv_c WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
        RETURN.
      ENDIF.
    ENDIF.

    " Caso 3: dd/mm/aaaa
    IF lv_txt CS '/'.
      SPLIT lv_txt AT '/' INTO DATA(lv_d) DATA(lv_m) DATA(lv_y).
      IF strlen( lv_y ) = 4.
        rv_date = |{ lv_y }{ lv_m WIDTH = 2 ALIGN = RIGHT PAD = '0' }{ lv_d WIDTH = 2 ALIGN = RIGHT PAD = '0' }|.
        RETURN.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD export_template.
    " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
    " ET-REING-BR-001 v5 SS4.2 -- el template pasa de A..L a A..O con las 3
    " columnas del motor de especificidad: Pais Prestadora, Soc. Prestadora y
    " Soc. Receptora.
    "
    " VAN AL FINAL Y NO INTERCALADAS, por decision del arquitecto en la
    " consulta A-12(4): "Extender el layout con 3 columnas nuevas al final.
    " Columnas existentes inalteradas. Columnas nuevas opcionales (vacio =
    " wildcard)". Respetar las 12 posiciones viejas es lo que permite que un
    " archivo armado con el template anterior siga cargando (ver read_rows).
    "
    " Fila de titulos con el layout EXACTO que lee read_rows (A..O).
    " Las columnas A (Regla ID), I (Especificidad) y L (Estado) se generan
    " a proposito: el importador las ignora, pero deben EXISTIR para que el
    " rango sea legible (un archivo con menos columnas hace fallar la
    " lectura de titulos).
    " Lineas originales conservadas como referencia:
    "    TYPES: BEGIN OF ty_tpl_row,
    "             c1  TYPE string, ... c12 TYPE string,
    "           END OF ty_tpl_row.
    TYPES: BEGIN OF ty_tpl_row,
             c1  TYPE string, c2  TYPE string, c3  TYPE string,
             c4  TYPE string, c5  TYPE string, c6  TYPE string,
             c7  TYPE string, c8  TYPE string, c9  TYPE string,
             c10 TYPE string, c11 TYPE string, c12 TYPE string,
             c13 TYPE string, c14 TYPE string, c15 TYPE string,
           END OF ty_tpl_row.

    DATA lt_tpl TYPE STANDARD TABLE OF ty_tpl_row WITH EMPTY KEY.
    APPEND VALUE #( c1  = 'Regla (ID)'
                    c2  = gc_title_country
                    c3  = gc_title_desc
                    c4  = gc_title_taxtype
                    c5  = gc_title_rate
                    c6  = gc_title_from
                    c7  = gc_title_to
                    c8  = gc_title_lifnr
                    c9  = 'Especificidad'
                    c10 = gc_title_matnr
                    c11 = gc_title_grossup
                    c12 = 'Estado'
                    c13 = gc_title_cty_prest
                    c14 = gc_title_buk_prest
                    c15 = gc_title_buk_recv ) TO lt_tpl.

    TRY.
        DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
        DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).

        DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
          )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
          )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
          )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( 'O' )
          )->get_pattern( ).

        lo_sheet->select( lo_pattern
          )->row_stream( )->operation->write_from( REF #( lt_tpl )
          )->if_xco_xlsx_wa_operation~execute( ).

        rv_xstring = lo_write->get_file_content( ).
      CATCH cx_root.
        CLEAR rv_xstring.
    ENDTRY.
    " End Change ID V009 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.


  METHOD read_rows.
    " Begin Change ID V009 (15.09.2026 | EXT_GONZALCA)
    " ET-REING-BR-001 v5 SS4.2 -- el rango leido pasa de A..L a A..O para
    " incorporar Pais Prestadora / Soc. Prestadora / Soc. Receptora (M, N, O).
    "
    " COMPATIBILIDAD CON ARCHIVOS DE 12 COLUMNAS -- el punto delicado.
    " La carga masiva es el mecanismo de cutover (consulta A-12(4)), asi que un
    " Excel armado con el template anterior TIENE que seguir cargando. Dos
    " mecanismos lo garantizan:
    "
    "  1) El mapeo es POR TITULO, no por posicion: lt_colmap asocia cada titulo
    "     de la fila 1 con su indice de columna, y las celdas se leen despues
    "     con ASSIGN COMPONENT sobre ese indice. En un archivo viejo los 3
    "     titulos nuevos simplemente no estan, su lv_c_* queda en 0 y los 3
    "     campos salen vacios = wildcard. Nada que migrar.
    "  2) El rango se pide primero hasta 'O' y, si XCO no lo acepta, se
    "     reintenta hasta 'L'. No esta verificado en runtime que XCO tolere un
    "     rango mas ancho que las columnas realmente presentes en la hoja (con
    "     un archivo de 12 columnas, pedir A..O podria levantar excepcion y
    "     hacer fallar la lectura de titulos, que es justo el error que este
    "     metodo ya reporta como 'No se pudo leer la fila de titulos').
    "     El reintento vuelve el comportamiento independiente de ese detalle:
    "     si el rango ancho funciona se usa, y si no se cae al viejo sin que el
    "     usuario vea diferencia. La columna efectiva queda en LV_LAST_COL y se
    "     REUTILIZA para las filas de datos, para que titulos y datos se lean
    "     siempre con el mismo ancho.
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

    " V009: 15 componentes. Un archivo de 12 columnas deja c13..c15 iniciales.
    " Lineas originales conservadas como referencia:
    "    TYPES: BEGIN OF ty_row12,
    "             c1 TYPE string, ... c12 TYPE string,
    "           END OF ty_row12.
    TYPES: BEGIN OF ty_row15,
             c1  TYPE string, c2  TYPE string, c3  TYPE string,
             c4  TYPE string, c5  TYPE string, c6  TYPE string,
             c7  TYPE string, c8  TYPE string, c9  TYPE string,
             c10 TYPE string, c11 TYPE string, c12 TYPE string,
             c13 TYPE string, c14 TYPE string, c15 TYPE string,
           END OF ty_row15.
    DATA lt_hdr TYPE STANDARD TABLE OF ty_row15 WITH EMPTY KEY.

    " Titulos en la fila 1, datos desde la fila 2.
    " V009: DO 2 TIMES en lugar de dos bloques TRY duplicados -- y DO, no LOOP,
    " porque un loop aca quedaria anidado y es hallazgo P2 del ATC.
    DATA lv_last_col  TYPE string VALUE 'O'.
    DATA lv_hdr_ok    TYPE abap_bool VALUE abap_false.
    DO 2 TIMES.
      DATA(lo_hdr_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
        )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
        )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
        )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( lv_last_col )
        )->to_row(      xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
        )->get_pattern( ).

      TRY.
          CLEAR lt_hdr.
          lo_sheet->select( lo_hdr_pattern
            )->row_stream( )->operation->write_to( REF #( lt_hdr )
            )->if_xco_xlsx_ra_operation~execute( ).
          lv_hdr_ok = abap_true.
        CATCH cx_root.
          " 1er intento (A..O): el archivo puede ser del template viejo de 12
          " columnas -> se reintenta con A..L. 2do intento: error real.
          lv_last_col = 'L'.
      ENDTRY.
      IF lv_hdr_ok = abap_true.
        EXIT.
      ENDIF.
    ENDDO.

    IF lv_hdr_ok = abap_false.
      ev_ok     = abap_false.
      ev_reason = 'No se pudo leer la fila de titulos.'.
      RETURN.
    ENDIF.

    DATA(ls_hdr) = VALUE ty_row15( lt_hdr[ 1 ] OPTIONAL ).

    TYPES: BEGIN OF ty_colmap,
             title TYPE string,
             col   TYPE i,
           END OF ty_colmap.
    DATA lt_colmap TYPE SORTED TABLE OF ty_colmap WITH UNIQUE KEY title.
    DATA lt_hdr_seq TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    lt_hdr_seq = VALUE #(
      ( condense( ls_hdr-c1 ) ) ( condense( ls_hdr-c2 ) )
      ( condense( ls_hdr-c3 ) ) ( condense( ls_hdr-c4 ) )
      ( condense( ls_hdr-c5 ) ) ( condense( ls_hdr-c6 ) )
      ( condense( ls_hdr-c7 ) ) ( condense( ls_hdr-c8 ) )
      ( condense( ls_hdr-c9 ) ) ( condense( ls_hdr-c10 ) )
      ( condense( ls_hdr-c11 ) ) ( condense( ls_hdr-c12 ) )
      " V009: titulos de las 3 columnas nuevas. En un archivo viejo vienen
      " vacios y el IF de abajo no los inserta en el colmap.
      ( condense( ls_hdr-c13 ) ) ( condense( ls_hdr-c14 ) )
      ( condense( ls_hdr-c15 ) ) ).

    LOOP AT lt_hdr_seq ASSIGNING FIELD-SYMBOL(<lv_title>).
      DATA(lv_idx) = sy-tabix.
      IF <lv_title> IS NOT INITIAL.
        INSERT VALUE ty_colmap( title = <lv_title> col = lv_idx )
          INTO TABLE lt_colmap.
      ENDIF.
    ENDLOOP.

    " N1: columnas obligatorias estructurales
    " V009: GC_TITLE_COUNTRY sale de la lista. El pais dejo de ser obligatorio
    " al pasar a wildcard del motor de especificidad (SS4.5) y la validacion
    " del behavior ya lo acepta vacio (validate_country, consulta A-12(2)):
    " si se quedaba aca, la carga masiva seguiria exigiendo una columna que la
    " app ya no exige, y una regla "solo prestadora" no se podria cargar.
    " Las 3 columnas nuevas NO se agregan: son opcionales por definicion.
    " Lineas originales conservadas como referencia:
    "    lt_required = VALUE #( ( gc_title_country ) ( gc_title_desc ) ... ).
    DATA lt_required TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    lt_required = VALUE #(
      ( gc_title_desc )
      ( gc_title_taxtype )
      ( gc_title_rate )
      ( gc_title_from )
      ( gc_title_to ) ).
    LOOP AT lt_required ASSIGNING FIELD-SYMBOL(<lv_req>).
      READ TABLE lt_colmap TRANSPORTING NO FIELDS WITH KEY title = <lv_req>.
      IF sy-subrc <> 0.
        ev_ok     = abap_false.
        ev_reason = |Columna obligatoria faltante: { <lv_req> }. Verifique el template.|.
        CLEAR et_rows.
        RETURN.
      ENDIF.
    ENDLOOP.

    " Leer filas de datos desde la fila 2 -- con el MISMO ancho que resulto
    " legible para los titulos (V009).
    DATA(lo_data_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
      )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      )->from_row(    xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
      )->to_column(   xco_cp_xlsx=>coordinate->for_alphabetic_value( lv_last_col )
      )->get_pattern( ).

    DATA lt_data TYPE STANDARD TABLE OF ty_row15 WITH EMPTY KEY.
    TRY.
        lo_sheet->select( lo_data_pattern
          )->row_stream( )->operation->write_to( REF #( lt_data )
          )->if_xco_xlsx_ra_operation~execute( ).
      CATCH cx_root.
        ev_ok     = abap_false.
        ev_reason = 'No se pudieron leer las filas de datos.'.
        RETURN.
    ENDTRY.

    DATA(lv_c_country) = VALUE i( lt_colmap[ title = gc_title_country ]-col OPTIONAL ).
    DATA(lv_c_desc)    = VALUE i( lt_colmap[ title = gc_title_desc    ]-col OPTIONAL ).
    DATA(lv_c_lifnr)   = VALUE i( lt_colmap[ title = gc_title_lifnr   ]-col OPTIONAL ).
    DATA(lv_c_matnr)   = VALUE i( lt_colmap[ title = gc_title_matnr   ]-col OPTIONAL ).
    DATA(lv_c_taxtype) = VALUE i( lt_colmap[ title = gc_title_taxtype ]-col OPTIONAL ).
    DATA(lv_c_rate)    = VALUE i( lt_colmap[ title = gc_title_rate    ]-col OPTIONAL ).
    DATA(lv_c_grossup) = VALUE i( lt_colmap[ title = gc_title_grossup ]-col OPTIONAL ).
    DATA(lv_c_from)    = VALUE i( lt_colmap[ title = gc_title_from    ]-col OPTIONAL ).
    DATA(lv_c_to)      = VALUE i( lt_colmap[ title = gc_title_to      ]-col OPTIONAL ).
    " V009: 0 cuando la columna no esta en el archivo -> campo vacio = wildcard.
    DATA(lv_c_cty_prest) = VALUE i( lt_colmap[ title = gc_title_cty_prest ]-col OPTIONAL ).
    DATA(lv_c_buk_prest) = VALUE i( lt_colmap[ title = gc_title_buk_prest ]-col OPTIONAL ).
    DATA(lv_c_buk_recv)  = VALUE i( lt_colmap[ title = gc_title_buk_recv  ]-col OPTIONAL ).

    FIELD-SYMBOLS <lv_cell> TYPE string.
    LOOP AT lt_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      IF <ls_data>-c1 IS INITIAL AND <ls_data>-c2 IS INITIAL
         AND <ls_data>-c3 IS INITIAL AND <ls_data>-c4 IS INITIAL
         AND <ls_data>-c5 IS INITIAL AND <ls_data>-c6 IS INITIAL
         AND <ls_data>-c7 IS INITIAL AND <ls_data>-c8 IS INITIAL
         AND <ls_data>-c9 IS INITIAL AND <ls_data>-c10 IS INITIAL
         AND <ls_data>-c11 IS INITIAL AND <ls_data>-c12 IS INITIAL
         AND <ls_data>-c13 IS INITIAL AND <ls_data>-c14 IS INITIAL
         AND <ls_data>-c15 IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_out) = VALUE ty_raw_row( ).

      IF lv_c_country > 0.
        ASSIGN COMPONENT lv_c_country OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-country = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_desc > 0.
        ASSIGN COMPONENT lv_c_desc OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-desc = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_lifnr > 0.
        ASSIGN COMPONENT lv_c_lifnr OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-lifnr = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_matnr > 0.
        ASSIGN COMPONENT lv_c_matnr OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-matnr = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_taxtype > 0.
        ASSIGN COMPONENT lv_c_taxtype OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-tax_type = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_rate > 0.
        ASSIGN COMPONENT lv_c_rate OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-rate = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_grossup > 0.
        ASSIGN COMPONENT lv_c_grossup OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-gross_up = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_from > 0.
        ASSIGN COMPONENT lv_c_from OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-from = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_to > 0.
        ASSIGN COMPONENT lv_c_to OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-to = condense( <lv_cell> ). ENDIF.
      ENDIF.
      " Begin Insert V009 (15.09.2026 | EXT_GONZALCA)
      IF lv_c_cty_prest > 0.
        ASSIGN COMPONENT lv_c_cty_prest OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-cty_prest = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_buk_prest > 0.
        ASSIGN COMPONENT lv_c_buk_prest OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-buk_prest = condense( <lv_cell> ). ENDIF.
      ENDIF.
      IF lv_c_buk_recv > 0.
        ASSIGN COMPONENT lv_c_buk_recv OF STRUCTURE <ls_data> TO <lv_cell>.
        IF sy-subrc = 0. ls_out-buk_recv = condense( <lv_cell> ). ENDIF.
      ENDIF.
      " End Insert V009 (15.09.2026 | EXT_GONZALCA)

      APPEND ls_out TO et_rows.
    ENDLOOP.
    " End Change ID V009 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

ENDCLASS.

