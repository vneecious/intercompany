"----------------------------------------------------------------------
" Created by     : Carlos (CC)
" Requirement N° : ME-13 (Delta v2 PRGI)
" Date           : 29.07.2026
" Description    : Metric-centric XLSX upload preparation service
" Transport      : DS4K9B5VNA
" Reference      : 5000047741
"----------------------------------------------------------------------
" V001 (CC) — ME-13 (Delta v2)
CLASS zcl_reing_me_upload_hdl DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_severity TYPE c LENGTH 1.
    TYPES ty_upload_value TYPE p LENGTH 8 DECIMALS 6.

    TYPES: BEGIN OF ty_message,
             row_number TYPE i,
             severity   TYPE ty_severity,
             text       TYPE string,
           END OF ty_message.
    TYPES ty_t_message TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

    TYPES: BEGIN OF ty_item_payload,
             source_row    TYPE i,
             bukrs         TYPE zreing_me_i_a-bukrs,
             prctr         TYPE zreing_me_i_a-prctr,
             campana       TYPE zreing_me_i_a-campana,
             role_category TYPE zreing_me_i_a-role_category,
             allocation    TYPE zreing_me_i_a-allocation,
             me_value      TYPE ty_upload_value,
           END OF ty_item_payload.
    TYPES ty_t_item_payload TYPE STANDARD TABLE OF ty_item_payload WITH EMPTY KEY.

    TYPES: BEGIN OF ty_header_payload,
             source_row    TYPE i,
             ct_id         TYPE zreing_me_h_a-ct_id,
             matnr         TYPE zreing_me_h_a-matnr,
             metric_code   TYPE zreing_me_h_a-metric_code,
             met_version   TYPE zreing_me_h_a-met_version,
             period_year   TYPE zreing_me_h_a-period_year,
             period_month  TYPE zreing_me_h_a-period_month,
             item          TYPE ty_item_payload,
           END OF ty_header_payload.
    TYPES ty_t_header_payload TYPE STANDARD TABLE OF ty_header_payload WITH EMPTY KEY.
    TYPES ty_t_accepted_source_row TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.

    TYPES: BEGIN OF ty_import_result,
             is_success           TYPE abap_bool,
             messages             TYPE ty_t_message,
             payload              TYPE ty_t_header_payload,
             accepted_source_rows TYPE ty_t_accepted_source_row,
           END OF ty_import_result.

    METHODS import_file
      IMPORTING
        iv_period_year  TYPE zreing_me_h_a-period_year
        iv_period_month TYPE zreing_me_h_a-period_month
        iv_file_content TYPE xstring
      RETURNING
        VALUE(rs_result) TYPE ty_import_result.

  PRIVATE SECTION.
    CONSTANTS gc_title_metric  TYPE string VALUE 'Metrica'.
    CONSTANTS gc_title_bukrs   TYPE string VALUE 'Sociedad'.
    CONSTANTS gc_title_campana TYPE string VALUE 'Campana'.
    " Mod 25.09.2026 EXT_AGFAGINA - DF-553: el template ahora dice "Allocation".
    " Se sigue aceptando "Asignacion" para no rechazar los templates ya
    " descargados antes del cambio.
    CONSTANTS gc_title_alloc     TYPE string VALUE 'Allocation'.
    CONSTANTS gc_title_alloc_old TYPE string VALUE 'Asignacion'.
    CONSTANTS gc_title_prctr   TYPE string VALUE 'CeBe'.
    CONSTANTS gc_title_rolecat TYPE string VALUE 'Categoria Gasto'.
    CONSTANTS gc_title_value   TYPE string VALUE 'Valor'.

    TYPES: BEGIN OF ty_xlsx_row,
             col_a TYPE string,
             col_b TYPE string,
             col_c TYPE string,
             col_d TYPE string,
             col_e TYPE string,
             col_f TYPE string,
             col_g TYPE string,
           END OF ty_xlsx_row.
    TYPES ty_t_xlsx_row TYPE STANDARD TABLE OF ty_xlsx_row WITH EMPTY KEY.

    TYPES: BEGIN OF ty_raw_row,
             row_number    TYPE i,
             metric_code   TYPE zreing_me_h_a-metric_code,
             bukrs         TYPE zreing_me_i_a-bukrs,
             campana       TYPE zreing_me_i_a-campana,
             allocation    TYPE zreing_me_i_a-allocation,
             prctr         TYPE zreing_me_i_a-prctr,
             role_category TYPE zreing_me_i_a-role_category,
             me_value      TYPE ty_upload_value,
             is_valid      TYPE abap_bool,
           END OF ty_raw_row.
    TYPES ty_t_raw_row TYPE STANDARD TABLE OF ty_raw_row WITH EMPTY KEY.

    TYPES: BEGIN OF ty_company_code,
             bukrs TYPE zreing_me_i_a-bukrs,
           END OF ty_company_code.
    TYPES ty_t_company_code TYPE SORTED TABLE OF ty_company_code WITH UNIQUE KEY bukrs.

    TYPES: BEGIN OF ty_file_key,
             metric_code   TYPE zreing_me_h_a-metric_code,
             bukrs         TYPE zreing_me_i_a-bukrs,
             campana       TYPE zreing_me_i_a-campana,
             allocation    TYPE zreing_me_i_a-allocation,
             prctr         TYPE zreing_me_i_a-prctr,
             role_category TYPE zreing_me_i_a-role_category,
           END OF ty_file_key.
    TYPES ty_t_file_key TYPE SORTED TABLE OF ty_file_key
                        WITH UNIQUE KEY metric_code bukrs campana allocation prctr role_category.

    TYPES: BEGIN OF ty_ct_target,
             ct_id         TYPE zreing_me_h_a-ct_id,
             matnr         TYPE zreing_me_h_a-matnr,
             metric_code   TYPE zreing_me_h_a-metric_code,
             met_version   TYPE zreing_me_h_a-met_version,
             bukrs         TYPE zreing_me_i_a-bukrs,
             prctr         TYPE zreing_me_i_a-prctr,
             campana       TYPE zreing_me_i_a-campana,
             role_category TYPE zreing_me_i_a-role_category,
             allocation    TYPE zreing_me_i_a-allocation,
           END OF ty_ct_target.
    TYPES ty_t_ct_target TYPE SORTED TABLE OF ty_ct_target
                         WITH NON-UNIQUE KEY metric_code bukrs campana allocation prctr role_category.

    TYPES: BEGIN OF ty_target_item,
             ct_id         TYPE zreing_me_h_a-ct_id,
             matnr         TYPE zreing_me_h_a-matnr,
             period_year   TYPE zreing_me_h_a-period_year,
             period_month  TYPE zreing_me_h_a-period_month,
             bukrs         TYPE zreing_me_i_a-bukrs,
             prctr         TYPE zreing_me_i_a-prctr,
             campana       TYPE zreing_me_i_a-campana,
             role_category TYPE zreing_me_i_a-role_category,
             allocation    TYPE zreing_me_i_a-allocation,
             source_row    TYPE i,
             me_value      TYPE ty_upload_value,
             payload       TYPE ty_header_payload,
           END OF ty_target_item.
    TYPES ty_t_target_item TYPE SORTED TABLE OF ty_target_item
                           WITH UNIQUE KEY ct_id matnr period_year period_month
                                           bukrs prctr campana role_category allocation.

    CLASS-METHODS add_message
      IMPORTING
        iv_row      TYPE i
        iv_severity TYPE ty_severity
        iv_text     TYPE string
      CHANGING
        ct_messages TYPE ty_t_message.

    CLASS-METHODS resolve_target_conflicts
      IMPORTING it_candidates TYPE ty_t_header_payload
      CHANGING  ct_messages   TYPE ty_t_message
                ct_payload    TYPE ty_t_header_payload
                ct_accepted   TYPE ty_t_accepted_source_row.
ENDCLASS.

CLASS zcl_reing_me_upload_hdl IMPLEMENTATION.
  METHOD add_message.
    APPEND VALUE #( row_number = iv_row severity = iv_severity text = iv_text ) TO ct_messages.
  ENDMETHOD.

  METHOD resolve_target_conflicts.
    DATA lt_targets TYPE ty_t_target_item.

    CLEAR: ct_payload, ct_accepted.
    LOOP AT it_candidates INTO DATA(ls_candidate).
      READ TABLE lt_targets INTO DATA(ls_existing)
        WITH TABLE KEY ct_id         = ls_candidate-ct_id
                       matnr         = ls_candidate-matnr
                       period_year   = ls_candidate-period_year
                       period_month  = ls_candidate-period_month
                       bukrs         = ls_candidate-item-bukrs
                       prctr         = ls_candidate-item-prctr
                       campana       = ls_candidate-item-campana
                       role_category = ls_candidate-item-role_category
                       allocation    = ls_candidate-item-allocation.
      IF sy-subrc <> 0.
        INSERT VALUE #( ct_id         = ls_candidate-ct_id
                        matnr         = ls_candidate-matnr
                        period_year   = ls_candidate-period_year
                        period_month  = ls_candidate-period_month
                        bukrs         = ls_candidate-item-bukrs
                        prctr         = ls_candidate-item-prctr
                        campana       = ls_candidate-item-campana
                        role_category = ls_candidate-item-role_category
                        allocation    = ls_candidate-item-allocation
                        source_row    = ls_candidate-source_row
                        me_value      = ls_candidate-item-me_value
                        payload       = ls_candidate ) INTO TABLE lt_targets.
        INSERT ls_candidate-source_row INTO TABLE ct_accepted.
      ELSEIF ls_existing-me_value = ls_candidate-item-me_value.
        INSERT ls_candidate-source_row INTO TABLE ct_accepted.
      ELSE.
        add_message( EXPORTING iv_row = ls_existing-source_row iv_severity = 'E'
                      iv_text = 'Conflicting values resolve to the same contract item destination'
                     CHANGING ct_messages = ct_messages ).
        add_message( EXPORTING iv_row = ls_candidate-source_row iv_severity = 'E'
                      iv_text = 'Conflicting values resolve to the same contract item destination'
                     CHANGING ct_messages = ct_messages ).
      ENDIF.
    ENDLOOP.

    READ TABLE ct_messages WITH KEY severity = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      CLEAR: ct_payload, ct_accepted.
      RETURN.
    ENDIF.
    ct_payload = VALUE #( FOR ls_target IN lt_targets ( ls_target-payload ) ).
  ENDMETHOD.

METHOD import_file.
    DATA lt_header_rows TYPE ty_t_xlsx_row.
    DATA lt_excel_rows TYPE ty_t_xlsx_row.
    DATA lt_rows TYPE ty_t_raw_row.
    DATA lt_file_keys TYPE ty_t_file_key.
    DATA lt_company_codes TYPE ty_t_company_code.
    DATA lt_targets TYPE ty_t_ct_target.

    rs_result-is_success = abap_false.
    IF iv_file_content IS INITIAL.
      add_message( EXPORTING iv_row = 0 iv_severity = 'E' iv_text = 'The XLSX file is empty'
                   CHANGING ct_messages = rs_result-messages ).
      RETURN.
    ENDIF.

    DATA(lv_year) = CONV i( iv_period_year ).
    DATA(lv_month) = CONV i( iv_period_month ).
    IF lv_year < 1 OR lv_month < 1 OR lv_month > 12.
      add_message( EXPORTING iv_row = 0 iv_severity = 'E' iv_text = 'The upload period is invalid'
                   CHANGING ct_messages = rs_result-messages ).
      RETURN.
    ENDIF.

    " Begin Mod (28.08.2026 | EXT_AGFAGINA) — fix del formateo del periodo.
    " lv_year/lv_month son tipo i y el WIDTH/PAD del string template los alineaba
    " a la IZQUIERDA: el mes 6 se formateaba como '60' y no como '06' (idem el
    " mes+1), dando lv_first_day = 20266001 y lv_last_day = 00000000. Con esas
    " fechas el SELECT de contratos no devolvia NINGUNA fila y todas las lineas
    " del archivo se rechazaban con "No active overlapping contract target".
    " Afectaba a los periodos de enero a septiembre; con 10/11/12 el WIDTH
    " llenaba exacto y el defecto no se manifestaba.
    " Se usan los parametros NUMC tal cual (mismo patron que ZCL_REING_ME_XLS_HDL,
    " que por eso generaba bien la plantilla) y el mes siguiente se arma con un
    " NUMC(6) intermedio, sin depender de la alineacion del string template.
    DATA(lv_first_day) = CONV d( |{ iv_period_year }{ iv_period_month }01| ).
    DATA lv_next_ym TYPE n LENGTH 6.
    IF lv_month = 12.
      lv_next_ym = ( ( lv_year + 1 ) * 100 ) + 1.
    ELSE.
      lv_next_ym = ( lv_year * 100 ) + lv_month + 1.
    ENDIF.
    DATA(lv_next_first_day) = CONV d( |{ lv_next_ym }01| ).
    " End Mod (28.08.2026 | EXT_AGFAGINA)
    " Begin Mod V002 (CC) — fix SAPSQL_DATA_LOSS: DATA() inline inference on date arithmetic (Delta v2)
    DATA(lv_last_day) = CONV d( lv_next_first_day - 1 ).
    " End Mod V002 (CC) — fix SAPSQL_DATA_LOSS: DATA() inline inference on date arithmetic (Delta v2)

    TRY.
        DATA(lo_document) = xco_cp_xlsx=>document->for_file_content( iv_file_content ).
        DATA(lo_read_access) = lo_document->read_access( ).
        DATA(lo_worksheet) = lo_read_access->get_workbook( )->worksheet->at_position( 1 ).
        DATA(lo_header_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
          )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
          )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'G' )
          )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
          )->to_row( xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
          )->get_pattern( ).
        lo_worksheet->select( lo_header_pattern )->row_stream( )->operation->write_to(
          REF #( lt_header_rows ) )->if_xco_xlsx_ra_operation~execute( ).

        DATA(lo_data_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
          )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
          )->to_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'G' )
          )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
          )->get_pattern( ).
        lo_worksheet->select( lo_data_pattern )->row_stream( )->operation->write_to(
          REF #( lt_excel_rows )
          )->if_xco_xlsx_ra_operation~execute( ).
    " Begin Mod V002 (CC) — return an understandable message for unhandled parsing errors, e.g. XLSX files without shared strings (Delta v2)
      CATCH cx_sy_ref_is_initial.
        add_message( EXPORTING iv_row = 0 iv_severity = 'E'
                      iv_text = 'The XLSX file could not be read - please verify it is a valid file saved from Excel, LibreOffice, or Google Sheets'
                     CHANGING ct_messages = rs_result-messages ).
        RETURN.
    " End Mod V002 (CC) — return an understandable message for unhandled parsing errors, e.g. XLSX files without shared strings (Delta v2)
      CATCH cx_root INTO DATA(lx_xlsx).
        add_message( EXPORTING iv_row = 0 iv_severity = 'E' iv_text = lx_xlsx->get_text( )
                     CHANGING ct_messages = rs_result-messages ).
        RETURN.
    ENDTRY.

    READ TABLE lt_header_rows INDEX 1 INTO DATA(ls_header).
    IF sy-subrc <> 0.
      add_message( EXPORTING iv_row = 0 iv_severity = 'E' iv_text = 'The XLSX file has no header row'
                   CHANGING ct_messages = rs_result-messages ).
      RETURN.
    ENDIF.

    IF ls_header-col_a <> gc_title_metric OR ls_header-col_b <> gc_title_bukrs
       OR ls_header-col_c <> gc_title_campana
       OR ( ls_header-col_d <> gc_title_alloc AND ls_header-col_d <> gc_title_alloc_old )
       OR ls_header-col_e <> gc_title_prctr OR ls_header-col_f <> gc_title_rolecat
       OR ls_header-col_g <> gc_title_value.
      add_message( EXPORTING iv_row = 1 iv_severity = 'E'
                    iv_text = 'The seven mandatory headers must match the template literally'
                   CHANGING ct_messages = rs_result-messages ).
      RETURN.
    ENDIF.

    LOOP AT lt_excel_rows INTO DATA(ls_excel).
      DATA(lv_row_number) = sy-tabix + 1.
      IF ls_excel-col_a IS INITIAL AND ls_excel-col_b IS INITIAL AND ls_excel-col_c IS INITIAL
         AND ls_excel-col_d IS INITIAL AND ls_excel-col_e IS INITIAL AND ls_excel-col_f IS INITIAL
         AND ls_excel-col_g IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(ls_row) = VALUE ty_raw_row( row_number = lv_row_number is_valid = abap_true ).
      IF ls_excel-col_a IS INITIAL OR ls_excel-col_b IS INITIAL OR ls_excel-col_c IS INITIAL
         OR ls_excel-col_d IS INITIAL OR ls_excel-col_e IS INITIAL OR ls_excel-col_f IS INITIAL.
        ls_row-is_valid = abap_false.
        add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                      iv_text = 'Metrica, Sociedad, Campana, Allocation, CeBe y Categoria Gasto son obligatorias'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.
      " Fix (28.08.2026 | EXT_AGFAGINA) - Valor se valida aparte: antes entraba en
      " el chequeo de "las siete columnas" y una fila sin valor generaba DOS
      " mensajes confusos ("faltan columnas" + "decimal invalido") cuando en
      " realidad solo falta un dato.
      IF ls_excel-col_g IS INITIAL.
        ls_row-is_valid = abap_false.
        add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                      iv_text = 'Valor es obligatorio'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.

      FIND PCRE '^[0-9]+$' IN ls_excel-col_e MATCH COUNT DATA(lv_prctr_match).
      IF lv_prctr_match = 0 OR strlen( ls_excel-col_e ) > 10.
        ls_row-is_valid = abap_false.
        add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                      iv_text = 'CeBe must be a non-negative numeric identifier'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.
      IF ls_excel-col_c IS INITIAL OR strlen( ls_excel-col_c ) > 3.
        ls_row-is_valid = abap_false.
        add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                      iv_text = 'Campana is mandatory and can contain at most three characters'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.
      IF ls_excel-col_d <> '0' AND ls_excel-col_d <> '1' AND ls_excel-col_d <> '3'.
        ls_row-is_valid = abap_false.
        add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                      iv_text = 'Allocation debe ser 0, 1 o 3'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.
      IF ls_excel-col_f <> 'C' AND ls_excel-col_f <> 'E'.
        ls_row-is_valid = abap_false.
        add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                      iv_text = 'Categoria Gasto must be C or E'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.

      " Begin Mod 08.09.2026 EXT_AGFAGINA - se reemplaza la validacion por patron.
      " La regla anterior era: FIND PCRE '^[0-9]+([.,][0-9]{1,6})?$'
      " Solo aceptaba digitos con hasta 6 decimales, y rechazaba lo que Excel
      " realmente escribe en el XML. Caso real (CargasMetricas_2025-12, TS4):
      "   fila 3  -> 9.8542000000000005E-2   (= 0,098542)
      "   fila 6  -> 1.3139E-2               (= 0,013139)
      "   fila 13 -> 6.5694000000000002E-2   (= 0,065694)
      " Dos motivos de rechazo simultaneos:
      "   1) notacion cientifica: Excel guarda asi TODO valor menor a 1, y la
      "      regla no admite 'E' ni el signo del exponente.
      "   2) precision binaria: 9.8542000000000005E-2 tiene 17 digitos, no 6.
      "      No es un error del usuario, es como se representa un decimal en
      "      punto flotante.
      " Consecuencia: ningun valor decimal menor a 1 podia cargarse nunca, que
      " es justo el caso de uso de las metricas de share.
      " Ahora se intenta la conversion directamente: el tipo destino es
      " DEC(15,6) y redondea la precision extra al asignar, que es exactamente
      " lo que el usuario quiso escribir. Se conserva el rechazo de negativos y
      " el control de desborde.
      DATA(lv_value_text) = condense( ls_excel-col_g ).
      IF lv_value_text IS NOT INITIAL.
        " Separador decimal: se tolera coma (configuracion regional del usuario).
        " No se tocan los puntos: en el XML de un xlsx el separador de miles no
        " existe, los numeros vienen crudos.
        REPLACE ALL OCCURRENCES OF ',' IN lv_value_text WITH '.'.
        TRY.
            " Paso por float para tolerar notacion cientifica; el destino
            " DEC(15,6) hace el redondeo final.
            DATA lv_value_f TYPE f.
            lv_value_f      = lv_value_text.
            ls_row-me_value = lv_value_f.

            IF ls_row-me_value < 0.
              ls_row-is_valid = abap_false.
              add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                            iv_text = 'Valor no puede ser negativo'
                           CHANGING ct_messages = rs_result-messages ).
            ENDIF.
          CATCH cx_sy_conversion_no_number.
            ls_row-is_valid = abap_false.
            add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                          iv_text = |Valor no numerico: '{ lv_value_text }'|
                         CHANGING ct_messages = rs_result-messages ).
          CATCH cx_sy_conversion_overflow.
            ls_row-is_valid = abap_false.
            add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                          iv_text = 'Valor excede el maximo admitido DEC(15,6)'
                         CHANGING ct_messages = rs_result-messages ).
        ENDTRY.
      ENDIF.
      " End Mod 08.09.2026 EXT_AGFAGINA

      IF ls_excel-col_c IS NOT INITIAL AND strlen( ls_excel-col_c ) <= 3.
        ls_row-campana = ls_excel-col_c.
      ENDIF.
      IF ls_excel-col_d = '0' OR ls_excel-col_d = '1' OR ls_excel-col_d = '3'.
        ls_row-allocation = ls_excel-col_d.
      ENDIF.
      IF lv_prctr_match > 0 AND strlen( ls_excel-col_e ) <= 10.
        " Fix (28.08.2026 | EXT_AGFAGINA) - ZREING_CT2_REC_A guarda el PRCTR en
        " formato EXTERNO, sin ceros a la izquierda ('199', no '0000000199').
        " El ALPHA = IN previo convertia el valor del Excel a formato interno y
        " el READ TABLE contra lt_targets nunca matcheaba: toda fila del propio
        " template respondia "No active overlapping contract target was found".
        " Se normaliza a formato externo para coincidir con la BD y para tolerar
        " que el usuario escriba el CeBe con o sin ceros a la izquierda.
        ls_row-prctr = condense( |{ ls_excel-col_e ALPHA = OUT }| ).
      ENDIF.
      IF ls_excel-col_f = 'C' OR ls_excel-col_f = 'E'.
        ls_row-role_category = ls_excel-col_f.
      ENDIF.
      " Mod 25.09.2026 EXT_AGFAGINA - DF-553/554: la columna A puede venir con
      " codigo y nombre ("M-0016 - S&T"). Se toma el primer bloque antes del
      " espacio, que es el codigo. Un archivo con solo el codigo resuelve igual.
      " No se busca por nombre a proposito: los nombres no son unicos.
      SPLIT condense( ls_excel-col_a ) AT space INTO DATA(lv_metric_tok) DATA(lv_metric_rest).
      ls_row-metric_code = to_upper( lv_metric_tok ).
      ls_row-bukrs = |{ ls_excel-col_b ALPHA = IN }|.

      IF ls_row-is_valid = abap_true.
        TRY.
            INSERT VALUE ty_file_key(
              metric_code = ls_row-metric_code bukrs = ls_row-bukrs campana = ls_row-campana
              allocation = ls_row-allocation prctr = ls_row-prctr role_category = ls_row-role_category )
              INTO TABLE lt_file_keys.
          CATCH cx_sy_itab_duplicate_key.
            ls_row-is_valid = abap_false.
            add_message( EXPORTING iv_row = lv_row_number iv_severity = 'E'
                          iv_text = 'The row duplicates a metric and receiver tuple in the file'
                         CHANGING ct_messages = rs_result-messages ).
        ENDTRY.
      ENDIF.
      APPEND ls_row TO lt_rows.
    ENDLOOP.

    IF lt_rows IS INITIAL.
      add_message( EXPORTING iv_row = 0 iv_severity = 'E' iv_text = 'The XLSX file has no data rows'
                   CHANGING ct_messages = rs_result-messages ).
      RETURN.
    ENDIF.

    SELECT FROM i_companycode
      FIELDS companycode AS bukrs
      FOR ALL ENTRIES IN @lt_rows
      WHERE companycode = @lt_rows-bukrs
      INTO TABLE @lt_company_codes.

    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE is_valid = abap_true.
      READ TABLE lt_company_codes WITH TABLE KEY bukrs = <ls_row>-bukrs TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        <ls_row>-is_valid = abap_false.
        add_message( EXPORTING iv_row = <ls_row>-row_number iv_severity = 'E'
                      iv_text = 'Sociedad does not exist'
                     CHANGING ct_messages = rs_result-messages ).
      ENDIF.
    ENDLOOP.

    SELECT con~ct_id, mat~matnr, met~metric_code, met~version_num AS met_version,
           rec~rec_bukrs AS bukrs, rec~prctr, rec~campana,
           rec~role_category, rec~allocation
      FROM zreing_ct2_a AS con
      INNER JOIN zreing_ct2_mat_a AS mat ON mat~ct_uuid = con~ct_uuid
      INNER JOIN zreing_ct2_met_a AS met ON met~ct_uuid = mat~ct_uuid
                                         AND met~mat_uuid = mat~mat_uuid
      INNER JOIN zreing_ct2_rec_a AS rec ON rec~ct_uuid = mat~ct_uuid
                                         AND rec~mat_uuid = mat~mat_uuid
      FOR ALL ENTRIES IN @lt_rows
      WHERE con~ct_status = 'AC'
        AND con~valid_from <= @lv_last_day
        AND con~valid_to >= @lv_first_day
        AND met~met_status = 'AC'
        AND met~metric_code = @lt_rows-metric_code
        AND rec~rec_status = 'AC'
        AND rec~rec_bukrs = @lt_rows-bukrs
        AND rec~prctr = @lt_rows-prctr
        AND rec~campana = @lt_rows-campana
        AND rec~role_category = @lt_rows-role_category
        AND rec~allocation = @lt_rows-allocation
      INTO TABLE @lt_targets.

    " Begin Mod (28.08.2026 | EXT_AGFAGINA) — diagnostico de causa unica.
    " Si el SELECT no devolvio NINGUN contrato, ninguna fila puede matchear: la
    " causa es global (periodo sin contratos vigentes o metrica inexistente/inactiva)
    " y no de cada linea. Antes se emitia un mensaje identico por cada fila del
    " archivo, lo que ocultaba la causa real detras de N errores repetidos.
    IF lt_targets IS INITIAL.
      add_message( EXPORTING iv_row = 0 iv_severity = 'E'
                    iv_text = |No hay contratos activos vigentes para el periodo | &&
                              |{ iv_period_month }/{ iv_period_year } con la metrica indicada. | &&
                              |Verifique la vigencia del contrato y el estado de la metrica.|
                   CHANGING ct_messages = rs_result-messages ).
      RETURN.
    ENDIF.
    " End Mod (28.08.2026 | EXT_AGFAGINA)

    LOOP AT lt_rows INTO DATA(ls_valid_row) WHERE is_valid = abap_true.
      READ TABLE lt_targets TRANSPORTING NO FIELDS
        WITH KEY metric_code = ls_valid_row-metric_code bukrs = ls_valid_row-bukrs
                 campana = ls_valid_row-campana allocation = ls_valid_row-allocation
                 prctr = ls_valid_row-prctr role_category = ls_valid_row-role_category.
      IF sy-subrc <> 0.
        " Begin Mod (28.08.2026 | EXT_AGFAGINA) — el mensaje identifica la combinacion
        " rechazada. Llegado aqui SI hay contratos vigentes para el periodo (ver el
        " chequeo global previo), por lo que el problema es de esta linea puntual y el
        " usuario necesita saber que combinacion revisar en el contrato.
        add_message( EXPORTING iv_row = ls_valid_row-row_number iv_severity = 'E'
                      iv_text = |La combinacion no corresponde a una receptora activa del contrato: | &&
                                |metrica { ls_valid_row-metric_code }, sociedad { ls_valid_row-bukrs }, | &&
                                |campana { ls_valid_row-campana }, allocation { ls_valid_row-allocation }, | &&
                                |CeBe { ls_valid_row-prctr }, categoria { ls_valid_row-role_category }|
                     CHANGING ct_messages = rs_result-messages ).
        " End Mod (28.08.2026 | EXT_AGFAGINA)
        CONTINUE.
      ENDIF.

      " Begin Mod V001 (CC) — ATC P2 performance (Delta v2)
      DATA(lt_row_targets) = FILTER #( lt_targets
        WHERE metric_code = ls_valid_row-metric_code
          AND bukrs = ls_valid_row-bukrs
          AND campana = ls_valid_row-campana
          AND allocation = ls_valid_row-allocation
          AND prctr = ls_valid_row-prctr
          AND role_category = ls_valid_row-role_category ).
      APPEND LINES OF VALUE ty_t_header_payload(
        FOR ls_target IN lt_row_targets
        ( source_row   = ls_valid_row-row_number ct_id = ls_target-ct_id matnr = ls_target-matnr
          metric_code  = ls_target-metric_code met_version = ls_target-met_version
          period_year  = iv_period_year period_month = iv_period_month
          item = VALUE #( source_row = ls_valid_row-row_number bukrs = ls_valid_row-bukrs
                          prctr = ls_valid_row-prctr campana = ls_valid_row-campana
                          role_category = ls_valid_row-role_category allocation = ls_valid_row-allocation
                          me_value = ls_valid_row-me_value ) ) ) TO rs_result-payload.
      " End Mod V001 (CC) — ATC P2 performance (Delta v2)
    ENDLOOP.

    DATA(lt_candidates) = rs_result-payload.
    resolve_target_conflicts( EXPORTING it_candidates = lt_candidates
                              CHANGING  ct_messages   = rs_result-messages
                                        ct_payload    = rs_result-payload
                                        ct_accepted   = rs_result-accepted_source_rows ).

    READ TABLE rs_result-messages WITH KEY severity = 'E' TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      CLEAR rs_result-payload.
      RETURN.
    ENDIF.
    rs_result-is_success = abap_true.
  ENDMETHOD.
ENDCLASS.

