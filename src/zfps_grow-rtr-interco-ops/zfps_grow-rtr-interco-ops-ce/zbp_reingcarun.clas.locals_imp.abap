" V001 (CC) - #119 (Delta v2): typed, validated filter tree for the list.
CLASS lcl_ca_export_filter DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_version TYPE n LENGTH 2.
    TYPES tt_year TYPE RANGE OF zc_reingcalineall-PeriodYear.
    TYPES tt_month TYPE RANGE OF zc_reingcalineall-PeriodMonth.
    TYPES tt_run TYPE RANGE OF zc_reingcalineall-CalcRunId.
    DATA mt_year TYPE tt_year READ-ONLY.
    DATA mt_month TYPE tt_month READ-ONLY.
    DATA mt_run TYPE tt_run READ-ONLY.
    TYPES: BEGIN OF ty_node,
             node_id TYPE i,
             parent_id TYPE i,
             node_kind TYPE c LENGTH 3,
             field_name TYPE c LENGTH 30,
             operator TYPE c LENGTH 12,
             low TYPE string,
             high TYPE string,
           END OF ty_node,
           tt_node TYPE STANDARD TABLE OF ty_node WITH EMPTY KEY.
    METHODS prepare
      IMPORTING iv_version TYPE ty_version it_nodes TYPE tt_node
      RAISING zcx_reing_ca_calc_error.
    METHODS matches
      IMPORTING is_line TYPE zc_reingcalineall
      RETURNING VALUE(rv_match) TYPE abap_bool.
  PRIVATE SECTION.
    TYPES: BEGIN OF ty_condition,
             node TYPE ty_node,
             low TYPE REF TO data,
             high TYPE REF TO data,
           END OF ty_condition,
           tt_condition TYPE SORTED TABLE OF ty_condition WITH UNIQUE KEY node-node_id.
    DATA mt_nodes TYPE tt_node.
    DATA mt_conditions TYPE tt_condition.
    DATA mv_root TYPE i.
    METHODS typed_value
      IMPORTING iv_text TYPE string iv_field TYPE any
      RETURNING VALUE(rr_value) TYPE REF TO data
      RAISING zcx_reing_ca_calc_error.
    METHODS eval
      IMPORTING iv_node TYPE i is_line TYPE zc_reingcalineall
      RETURNING VALUE(rv_match) TYPE abap_bool.
ENDCLASS.

CLASS lcl_ca_export_filter IMPLEMENTATION.
  METHOD prepare.
    CLEAR: mt_nodes, mt_conditions, mv_root, mt_year, mt_month, mt_run.
    IF iv_version <> '01' OR lines( it_nodes ) > 512.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Versión o cantidad de filtros no admitida'.
    ENDIF.
    " An empty tree explicitly means the applied list has no filters.
    mt_nodes = it_nodes.
    IF mt_nodes IS INITIAL.
      RETURN.
    ENDIF.
    TYPES tt_ids TYPE HASHED TABLE OF i WITH UNIQUE KEY table_line.
    DATA lt_ids TYPE tt_ids.
    DATA ls_sample TYPE zc_reingcalineall.
    DATA lv_roots TYPE i.
    DATA(lc_fields) =
      '|CTUUID|MATUUID|OPTYPE|OPUUID|BUKRSRECV|PERIODYEAR|PERIODMONTH|ROWTYPE|DELTASEQ|CMHID|' &&
      'CALCRUNID|LINENUM|CMLOADSEQ|CTID|LIFNR|BPNAME|BUKRSPREST|OPINSTANCENUM|MATNR|MATDESC|' &&
      'COUNTRY|SHAREPCT|SHAREPAISPCT|SHARECOMBPCT|OPTYPEDESC|GROUPKEY|HEADERTITLE|' &&
      'ISDELTA|DELTACRITICALITY|DELTABASEAMT|BASEAMT|CALCAMT|BRUTOAMT|GROSSUPAMT|TAXAMT|' &&
      'NETAMT|NETLOCALAMT|CTCURRENCY|LOCALCURRENCY|TRANSCURRENCY|NETTRANSAMT|EXCHRATE1|' &&
      'EXCHRATE1TYPE|EXCHRATE|EXCHRATETYPE|LINESTATUS|STATUSCRITICALITY|CRITCRITICALFIX|' &&
      'CRITPOSITIVEFIX|SIMMESSAGE|ISORPHAN|INSUMOCHECKAT|PARENTNETAMT|PARENTCURRENCY|' &&
      'DEFERPCT|DEFERCUOTANUM|DEFERCUOTATOTAL|DEFERFROM|DEFERTO|ORIGINRUNID|ORIGINLINENUM|HASPARENT|'.
    LOOP AT mt_nodes ASSIGNING FIELD-SYMBOL(<node>).
      IF <node>-node_id <= 0 OR <node>-parent_id < 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Identificador de nodo inválido'.
      ENDIF.
      INSERT <node>-node_id INTO TABLE lt_ids.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Identificadores de filtros repetidos'.
      ENDIF.
      IF <node>-parent_id = 0.
        lv_roots += 1.
        mv_root = <node>-node_id.
      ENDIF.
      IF <node>-node_kind <> 'AND' AND <node>-node_kind <> 'OR'
         AND <node>-node_kind <> 'NOT' AND <node>-node_kind <> 'CMP'.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Tipo de nodo de filtro no admitido'.
      ENDIF.
      IF <node>-node_kind <> 'CMP'.
        IF <node>-field_name IS NOT INITIAL OR <node>-operator IS NOT INITIAL
           OR <node>-low IS NOT INITIAL OR <node>-high IS NOT INITIAL.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'Un grupo lógico no admite propiedad ni valores'.
        ENDIF.
        CONTINUE.
      ENDIF.
      DATA(lv_field) = to_upper( <node>-field_name ).
      IF find( val = lc_fields sub = |\|{ lv_field }\|| ) < 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |Propiedad no admitida: { <node>-field_name }|.
      ENDIF.
      ASSIGN COMPONENT lv_field OF STRUCTURE ls_sample TO FIELD-SYMBOL(<field>).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |Propiedad no disponible: { <node>-field_name }|.
      ENDIF.
      CASE <node>-operator.
        WHEN 'EQ' OR 'NE' OR 'GT' OR 'GE' OR 'LT' OR 'LE' OR 'BT' OR 'NB'.
        WHEN 'CONTAINS' OR 'STARTSWITH' OR 'ENDSWITH'.
          DATA(lo_type) = cl_abap_typedescr=>describe_by_data( <field> ).
          IF lo_type->type_kind <> cl_abap_typedescr=>typekind_char
             AND lo_type->type_kind <> cl_abap_typedescr=>typekind_string.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING iv_message = 'Operador de texto sobre propiedad no textual'.
          ENDIF.
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = |Operador de filtro no admitido: { <node>-operator }|.
      ENDCASE.
      DATA(ls_condition) = VALUE ty_condition( node = <node> ).
      ls_condition-node-field_name = lv_field.
      " Substring literals can be longer than the field; they then match nothing.
      IF <node>-operator = 'CONTAINS' OR <node>-operator = 'STARTSWITH' OR <node>-operator = 'ENDSWITH'.
        CREATE DATA ls_condition-low TYPE string.
        ASSIGN ls_condition-low->* TO FIELD-SYMBOL(<text>).
        <text> = <node>-low.
      ELSE.
        ls_condition-low = typed_value( iv_text = <node>-low iv_field = <field> ).
      ENDIF.
      IF <node>-operator = 'BT' OR <node>-operator = 'NB'.
        ls_condition-high = typed_value( iv_text = <node>-high iv_field = <field> ).
        ASSIGN ls_condition-low->* TO FIELD-SYMBOL(<low>).
        ASSIGN ls_condition-high->* TO FIELD-SYMBOL(<high>).
        IF <low> > <high>.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'Límite inferior mayor que superior'.
        ENDIF.
      ELSEIF <node>-high IS NOT INITIAL.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Este operador no admite un segundo valor'.
      ENDIF.
      INSERT ls_condition INTO TABLE mt_conditions.
    ENDLOOP.
    IF lv_roots <> 1.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'Los filtros requieren una única raíz'.
    ENDIF.
    LOOP AT mt_nodes INTO DATA(ls_node).
      DATA(lv_children) = REDUCE i( INIT n = 0 FOR child IN mt_nodes
        WHERE ( parent_id = ls_node-node_id ) NEXT n = n + 1 ).
      IF ( ls_node-node_kind = 'CMP' AND lv_children <> 0 )
         OR ( ls_node-node_kind = 'NOT' AND lv_children <> 1 )
         OR ( ( ls_node-node_kind = 'AND' OR ls_node-node_kind = 'OR' ) AND lv_children = 0 ).
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'Cantidad de hijos inválida en filtro'.
      ENDIF.
      DATA(lv_ancestor) = ls_node-node_id.
      DATA lv_depth TYPE i.
      CLEAR lv_depth.
      WHILE lv_ancestor <> mv_root.
        lv_depth += 1.
        IF lv_depth > 64.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'Ciclo o profundidad excesiva de filtros'.
        ENDIF.
        READ TABLE mt_nodes INTO DATA(ls_parent) WITH KEY node_id = lv_ancestor.
        IF sy-subrc <> 0 OR ls_parent-parent_id = 0.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'Filtro desconectado o padre inexistente'.
        ENDIF.
        lv_ancestor = ls_parent-parent_id.
      ENDWHILE.
    ENDLOOP.
    " Only mandatory EQ conjuncts can safely restrict the SQL preselection.
    DO lines( mt_conditions ) TIMES.
      READ TABLE mt_conditions INTO DATA(ls_prefilter) INDEX sy-index.
      IF ls_prefilter-node-operator <> 'EQ'. CONTINUE. ENDIF.
      lv_ancestor = ls_prefilter-node-parent_id.
      DATA(lv_mandatory) = abap_true.
      WHILE lv_ancestor <> 0.
        ls_parent = mt_nodes[ node_id = lv_ancestor ].
        IF ls_parent-node_kind <> 'AND'. lv_mandatory = abap_false. ENDIF.
        lv_ancestor = ls_parent-parent_id.
      ENDWHILE.
      IF lv_mandatory = abap_false. CONTINUE. ENDIF.
      ASSIGN ls_prefilter-low->* TO FIELD-SYMBOL(<prefilter>).
      CASE ls_prefilter-node-field_name.
        WHEN 'PERIODYEAR'.
          IF mt_year IS INITIAL. mt_year = VALUE #( ( sign = 'I' option = 'EQ' low = <prefilter> ) ). ENDIF.
        WHEN 'PERIODMONTH'.
          IF mt_month IS INITIAL. mt_month = VALUE #( ( sign = 'I' option = 'EQ' low = <prefilter> ) ). ENDIF.
        WHEN 'CALCRUNID'.
          IF mt_run IS INITIAL. mt_run = VALUE #( ( sign = 'I' option = 'EQ' low = <prefilter> ) ). ENDIF.
      ENDCASE.
    ENDDO.
  ENDMETHOD.

  METHOD typed_value.
    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( iv_field ).
    DATA(lo_element) = CAST cl_abap_elemdescr( lo_type ).
    CREATE DATA rr_value TYPE HANDLE lo_element.
    ASSIGN rr_value->* TO FIELD-SYMBOL(<value>).
    DATA(lv_text) = iv_text.
    TRY.
        CASE lo_type->type_kind.
          WHEN cl_abap_typedescr=>typekind_char OR cl_abap_typedescr=>typekind_num.
            DATA lv_chars TYPE i.
            lv_chars = lo_element->length / cl_abap_char_utilities=>charsize.
            IF strlen( lv_text ) > lv_chars
               OR ( lo_type->type_kind = cl_abap_typedescr=>typekind_num
                    AND ( lv_text IS INITIAL OR lv_text CN '0123456789' ) ).
              RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                EXPORTING iv_message = 'Valor de texto o NUMC inválido'.
            ENDIF.
            <value> = lv_text.
          WHEN cl_abap_typedescr=>typekind_hex.
            REPLACE ALL OCCURRENCES OF '-' IN lv_text WITH ''.
            lv_text = to_upper( lv_text ).
            IF strlen( lv_text ) <> lo_element->length * 2 OR lv_text CN '0123456789ABCDEF'.
              RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                EXPORTING iv_message = 'UUID de filtro inválido'.
            ENDIF.
            <value> = lv_text.
          WHEN cl_abap_typedescr=>typekind_date.
            REPLACE ALL OCCURRENCES OF '-' IN lv_text WITH ''.
            IF strlen( lv_text ) <> 8 OR lv_text CN '0123456789'.
              RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                EXPORTING iv_message = 'Fecha de filtro inválida; usar AAAAMMDD'.
            ENDIF.
            DATA(lv_year) = CONV i( lv_text(4) ).
            DATA(lv_month) = CONV i( lv_text+4(2) ).
            DATA(lv_day) = CONV i( lv_text+6(2) ).
            DATA(lv_days) = COND i( WHEN lv_month = 2 THEN 28
              WHEN lv_month = 4 OR lv_month = 6 OR lv_month = 9 OR lv_month = 11 THEN 30 ELSE 31 ).
            IF lv_month = 2 AND ( lv_year MOD 400 = 0 OR ( lv_year MOD 4 = 0 AND lv_year MOD 100 <> 0 ) ).
              lv_days = 29.
            ENDIF.
            IF lv_year < 1 OR lv_month < 1 OR lv_month > 12 OR lv_day < 1 OR lv_day > lv_days.
              RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                EXPORTING iv_message = 'Fecha de calendario inválida'.
            ENDIF.
            <value> = lv_text.
          WHEN OTHERS.
            DATA(lv_number) = EXACT decfloat34( lv_text ).
            <value> = lv_number.
            IF CONV decfloat34( <value> ) <> lv_number.
              RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
                EXPORTING iv_message = 'Valor de filtro fuera de precisión o escala'.
            ENDIF.
        ENDCASE.
      CATCH cx_sy_conversion_error INTO DATA(lx_conversion).
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |Valor de filtro inválido: { lx_conversion->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD matches.
    rv_match = COND #( WHEN mt_nodes IS INITIAL THEN abap_true
                      ELSE eval( iv_node = mv_root is_line = is_line ) ).
  ENDMETHOD.

  METHOD eval.
    DATA(ls_node) = mt_nodes[ node_id = iv_node ].
    IF ls_node-node_kind = 'CMP'.
      DATA(ls_condition) = mt_conditions[ node-node_id = iv_node ].
      ASSIGN COMPONENT ls_condition-node-field_name OF STRUCTURE is_line TO FIELD-SYMBOL(<field>).
      ASSIGN ls_condition-low->* TO FIELD-SYMBOL(<low>).
      CASE ls_node-operator.
        WHEN 'EQ'. rv_match = xsdbool( <field> = <low> ).
        WHEN 'NE'. rv_match = xsdbool( <field> <> <low> ).
        WHEN 'GT'. rv_match = xsdbool( <field> > <low> ).
        WHEN 'GE'. rv_match = xsdbool( <field> >= <low> ).
        WHEN 'LT'. rv_match = xsdbool( <field> < <low> ).
        WHEN 'LE'. rv_match = xsdbool( <field> <= <low> ).
        WHEN 'BT' OR 'NB'.
          ASSIGN ls_condition-high->* TO FIELD-SYMBOL(<high>).
          rv_match = xsdbool( <field> >= <low> AND <field> <= <high> ).
          IF ls_node-operator = 'NB'. rv_match = xsdbool( rv_match = abap_false ). ENDIF.
        WHEN OTHERS.
          DATA(lv_text) = CONV string( <field> ).
          DATA(lv_low) = CONV string( <low> ).
          IF lv_low IS INITIAL.
            rv_match = abap_true.
            RETURN.
          ENDIF.
          DATA(lv_position) = find( val = lv_text sub = lv_low ).
          CASE ls_node-operator.
            WHEN 'CONTAINS'. rv_match = xsdbool( lv_low IS INITIAL OR lv_position >= 0 ).
            WHEN 'STARTSWITH'. rv_match = xsdbool( lv_low IS INITIAL OR lv_position = 0 ).
            WHEN 'ENDSWITH'.
              DATA(lv_offset) = strlen( lv_text ) - strlen( lv_low ).
              IF lv_offset >= 0.
                rv_match = xsdbool( substring( val = lv_text off = lv_offset ) = lv_low ).
              ENDIF.
          ENDCASE.
      ENDCASE.
      RETURN.
    ENDIF.
    rv_match = xsdbool( ls_node-node_kind = 'AND' ).
    LOOP AT mt_nodes INTO DATA(ls_child) WHERE parent_id = iv_node.
      DATA(lv_child) = eval( iv_node = ls_child-node_id is_line = is_line ).
      CASE ls_node-node_kind.
        WHEN 'AND'. rv_match = xsdbool( rv_match = abap_true AND lv_child = abap_true ).
        WHEN 'OR'. rv_match = xsdbool( rv_match = abap_true OR lv_child = abap_true ).
        WHEN 'NOT'. rv_match = xsdbool( lv_child = abap_false ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - #119 (Delta v2): pure shared assembler and bulk reads.
CLASS lcl_ca_export_xlsx DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_id,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num TYPE zreing_ca_line_a-line_num,
           END OF ty_id,
           tt_id TYPE SORTED TABLE OF ty_id WITH UNIQUE KEY calc_run_id line_num,
           tt_contract TYPE STANDARD TABLE OF zreing_ct2_a WITH EMPTY KEY,
           tt_currency TYPE STANDARD TABLE OF i_currency WITH EMPTY KEY,
           BEGIN OF ty_excel_row,
             cols TYPE string_table,
           END OF ty_excel_row,
           tt_excel_row TYPE STANDARD TABLE OF ty_excel_row WITH EMPTY KEY,
           tt_output_cols TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.
    CLASS-METHODS fetch
      IMPORTING it_ids TYPE tt_id
      EXPORTING et_lines TYPE zif_reing_ca_types=>ty_line_t
                et_pcs TYPE zif_reing_ca_types=>ty_line_pc_t
                et_steps TYPE zif_reing_ca_types=>ty_step_t
                et_contracts TYPE tt_contract et_currencies TYPE tt_currency.
    CLASS-METHODS build
      IMPORTING it_lines TYPE zif_reing_ca_types=>ty_line_t
                it_pcs TYPE zif_reing_ca_types=>ty_line_pc_t
                it_steps TYPE zif_reing_ca_types=>ty_step_t
                it_contracts TYPE tt_contract it_currencies TYPE tt_currency
      RETURNING VALUE(rt_rows) TYPE zcl_reing_ca_xls_hdl=>ty_rows
      RAISING zcx_reing_ca_calc_error.
    CLASS-METHODS numeric_cols
      IMPORTING it_header TYPE string_table
      RETURNING VALUE(rt_cols) TYPE tt_output_cols.
  PRIVATE SECTION.
    " V001 (CC) - Presentation offsets remain private to this worksheet.
    CONSTANTS:
      BEGIN OF trans_col,
        currency TYPE i VALUE 27,
        net TYPE i VALUE 28,
        bruto TYPE i VALUE 29,
      END OF trans_col.
    TYPES tt_fx_index TYPE SORTED TABLE OF zreing_ca_step_a
      WITH NON-UNIQUE KEY calc_run_id line_num step_num seq.
    CLASS-METHODS line_fx_steps
      IMPORTING iv_run TYPE zreing_ca_line_a-calc_run_id
                iv_line TYPE zreing_ca_line_a-line_num it_index TYPE tt_fx_index
      RETURNING VALUE(rt_steps) TYPE zif_reing_ca_types=>ty_step_t.
    CLASS-METHODS validate_trans_line
      IMPORTING is_line TYPE zreing_ca_line_a it_pcs TYPE zif_reing_ca_types=>ty_line_pc_t
                it_steps TYPE zif_reing_ca_types=>ty_step_t
                it_currencies TYPE zif_reing_ca_types=>tt_currency_precision
                iv_local_available TYPE abap_bool
      RAISING zcx_reing_ca_calc_error.

    TYPES: BEGIN OF ty_tax,
             calc_run_id TYPE zreing_ca_step_a-calc_run_id,
             line_num TYPE zreing_ca_step_a-line_num,
             tax_type TYPE zreing_ca_step_a-tax_type,
             output_amt TYPE decfloat34,
           END OF ty_tax,
           tt_tax TYPE HASHED TABLE OF ty_tax WITH UNIQUE KEY calc_run_id line_num tax_type,
           BEGIN OF ty_total,
             currency TYPE waers,
             kind TYPE c LENGTH 1,
             calc TYPE decfloat34,
             bruto TYPE decfloat34,
             tax TYPE decfloat34,
             net TYPE decfloat34,
           END OF ty_total,
           tt_total TYPE SORTED TABLE OF ty_total WITH UNIQUE KEY currency kind,
           BEGIN OF ty_tax_total,
             currency TYPE waers,
             tax_type TYPE zreing_ca_step_a-tax_type,
             amount TYPE decfloat34,
           END OF ty_tax_total,
           tt_tax_total TYPE SORTED TABLE OF ty_tax_total WITH UNIQUE KEY currency tax_type.
    CLASS-METHODS add_total
      IMPORTING iv_currency TYPE waers iv_kind TYPE c
                iv_calc TYPE decfloat34 DEFAULT 0 iv_bruto TYPE decfloat34 DEFAULT 0
                iv_tax TYPE decfloat34 DEFAULT 0 iv_net TYPE decfloat34
      CHANGING ct_totals TYPE tt_total.
ENDCLASS.

CLASS lcl_ca_export_xlsx IMPLEMENTATION.
  METHOD validate_trans_line.
    " Validate stored facts without rewriting/reconverting the exported cells.
    DATA(ls_expected) = zcl_reing_ca_trans_amounts=>project_line(
      is_line = is_line it_line_pc = it_pcs it_steps = it_steps
      it_currencies = it_currencies iv_eba_off = abap_false ).
    IF ls_expected-use_trans = abap_false OR ls_expected-local_available <> iv_local_available.
      MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
        NUMBER zif_reing_ca_c=>fx_projection_message-memory WITH is_line-line_num INTO DATA(lv_error).
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_error.
    ENDIF.
    TYPES tt_stored_pcs TYPE HASHED TABLE OF zreing_ca_lpc_a
      WITH UNIQUE KEY calc_run_id line_num pc_seq.
    DATA(lt_stored) = CORRESPONDING tt_stored_pcs( it_pcs ).
    LOOP AT ls_expected-line_pc INTO DATA(ls_expected_pc).
      DATA(ls_stored_pc) = lt_stored[ calc_run_id = ls_expected_pc-calc_run_id
        line_num = ls_expected_pc-line_num pc_seq = ls_expected_pc-pc_seq ].
      IF ls_expected_pc-bruto_trans_amt <> ls_stored_pc-bruto_trans_amt
         OR ls_expected_pc-net_trans_amt <> ls_stored_pc-net_trans_amt
         OR ls_expected_pc-net_local_amt <> ls_stored_pc-net_local_amt.
        MESSAGE ID zif_reing_ca_c=>message_class TYPE zif_reing_ca_c=>fx_projection-message_type
          NUMBER zif_reing_ca_c=>fx_projection_message-breakdown WITH is_line-line_num INTO lv_error.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = lv_error.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD line_fx_steps.
    LOOP AT it_index INTO DATA(ls_fx)
      WHERE calc_run_id = iv_run AND line_num = iv_line
        AND step_num = zif_reing_ca_c=>fx_step-number
        AND ( seq = zif_reing_ca_c=>fx_step-primary_seq OR seq = zif_reing_ca_c=>fx_step-local_seq ).
      APPEND ls_fx TO rt_steps.
    ENDLOOP.
  ENDMETHOD.

  METHOD fetch.
    CLEAR: et_lines, et_pcs, et_steps, et_contracts, et_currencies.
    IF it_ids IS INITIAL. RETURN. ENDIF.
    SELECT * FROM zreing_ca_line_a FOR ALL ENTRIES IN @it_ids
      WHERE calc_run_id = @it_ids-calc_run_id AND line_num = @it_ids-line_num
        AND line_status <> 'PEND' INTO TABLE @et_lines.
    IF et_lines IS INITIAL. RETURN. ENDIF.
    SORT et_lines BY calc_run_id line_num.
    SELECT * FROM zreing_ca_lpc_a FOR ALL ENTRIES IN @et_lines
      WHERE calc_run_id = @et_lines-calc_run_id AND line_num = @et_lines-line_num INTO TABLE @et_pcs.
    SORT et_pcs BY calc_run_id line_num pc_seq.
    SELECT * FROM zreing_ca_step_a FOR ALL ENTRIES IN @et_lines
      WHERE calc_run_id = @et_lines-calc_run_id AND line_num = @et_lines-line_num
        AND ( step_category = 'TAX'
          OR ( step_num = @zif_reing_ca_c=>fx_step-number
            AND ( seq = @zif_reing_ca_c=>fx_step-primary_seq OR seq = @zif_reing_ca_c=>fx_step-local_seq ) ) )
      INTO TABLE @et_steps.
    SELECT * FROM zreing_ct2_a FOR ALL ENTRIES IN @et_lines
      WHERE ct_uuid = @et_lines-ct_uuid INTO TABLE @et_contracts.
    SELECT currency, decimals FROM i_currency FOR ALL ENTRIES IN @et_lines
      WHERE currency = @et_lines-ct_currency OR currency = @et_lines-local_currency
        OR currency = @et_lines-trans_currency
      INTO CORRESPONDING FIELDS OF TABLE @et_currencies.
  ENDMETHOD.

  METHOD build.
    IF it_lines IS INITIAL. RETURN. ENDIF.
    IF lines( it_pcs ) > 100000.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'La descarga excede 100000 aperturas; reduzca los filtros'.
    ENDIF.
    TYPES: BEGIN OF ty_type,
             tax_type TYPE zreing_ca_step_a-tax_type,
           END OF ty_type,
           tt_type TYPE SORTED TABLE OF ty_type WITH UNIQUE KEY tax_type.
    DATA lt_tax_types TYPE tt_type.
    DATA lt_step_taxes TYPE tt_tax.
    DATA lt_totals TYPE tt_total.
    DATA lt_tax_totals TYPE tt_tax_total.
    DATA lt_selected_ids TYPE tt_id.
    " V001 (CC) - One sorted bulk index; lookup is bounded to the current Run/Line.
    DATA(lt_fx_index) = CORRESPONDING tt_fx_index( it_steps ).
    DATA(lt_projection_currencies) = CORRESPONDING zif_reing_ca_types=>tt_currency_precision( it_currencies ).
    lt_selected_ids = CORRESPONDING #( it_lines ).
    " Preserve the approved #83 policy: use the persisted TAX steps, including GU.
    LOOP AT it_steps INTO DATA(ls_step) WHERE step_category = 'TAX'.
      IF NOT line_exists( lt_selected_ids[ calc_run_id = ls_step-calc_run_id line_num = ls_step-line_num ] ).
        CONTINUE.
      ENDIF.
      IF ls_step-tax_type IS INITIAL.
        IF ls_step-output_amt <> 0.
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING iv_message = 'Un paso de impuesto con importe no tiene tipo'.
        ENDIF.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( tax_type = ls_step-tax_type ) INTO TABLE lt_tax_types.
      COLLECT VALUE ty_tax( calc_run_id = ls_step-calc_run_id line_num = ls_step-line_num
        tax_type = ls_step-tax_type output_amt = CONV decfloat34( ls_step-output_amt ) ) INTO lt_step_taxes.
    ENDLOOP.
    DATA lt_rows TYPE tt_excel_row.

    TYPES: BEGIN OF ty_tax_acum,
             tax_type TYPE zreing_ca_step_a-tax_type,
             amount   TYPE decfloat34,
           END OF ty_tax_acum.
    DATA lt_tax_acum TYPE HASHED TABLE OF ty_tax_acum
      WITH UNIQUE KEY tax_type.

    DATA(ls_header) = VALUE ty_excel_row( ).
    APPEND: 'Contrato'    TO ls_header-cols,
            'Ext'         TO ls_header-cols,
            'Prestadora'  TO ls_header-cols,
            'Material'    TO ls_header-cols,
            'Op.Type'     TO ls_header-cols,
            'Inst'        TO ls_header-cols,
            'Receptora'   TO ls_header-cols,
            'Pais'        TO ls_header-cols,
            'CeBe'        TO ls_header-cols,
            'Campana'     TO ls_header-cols,
            'Categoria'   TO ls_header-cols,
            'Asignacion'  TO ls_header-cols,
            'Share%'      TO ls_header-cols,
            'Share Pais'  TO ls_header-cols,
            'Share Comb.' TO ls_header-cols,
            'GU'          TO ls_header-cols,
            'CalcAmt'     TO ls_header-cols,
            'Bruto (GU)'  TO ls_header-cols.
    LOOP AT lt_tax_types INTO DATA(ls_tt).
      APPEND ls_tt-tax_type TO ls_header-cols.
    ENDLOOP.
    APPEND: 'Total Imp.'   TO ls_header-cols,
            'Neto (Cto)'   TO ls_header-cols,
            'Neto (Local)' TO ls_header-cols,
            'Mon. Cto'     TO ls_header-cols,
            'Mon. Local'   TO ls_header-cols,
            'Tasa FX'      TO ls_header-cols,
            'Delta #N'     TO ls_header-cols,
            'Status'       TO ls_header-cols,
            'Mon. Trans.'  TO ls_header-cols,
            'Neto (Trans.)' TO ls_header-cols,
            'Bruto (Trans.)' TO ls_header-cols,
            'Tasa 1'       TO ls_header-cols,
            'Tipo Tasa 1'  TO ls_header-cols,
            'Run' TO ls_header-cols, 'Linea' TO ls_header-cols, 'PcSeq' TO ls_header-cols.
    APPEND ls_header TO lt_rows.

    TYPES tt_pc_sorted TYPE SORTED TABLE OF zreing_ca_lpc_a
      WITH UNIQUE KEY calc_run_id line_num pc_seq.
    DATA lt_pc_sorted TYPE tt_pc_sorted.
    lt_pc_sorted = CORRESPONDING #( it_pcs ).
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(ls_fx_state) = zcl_reing_ca_trans_amounts=>inspect_fx(
        is_line = ls_line it_steps = line_fx_steps(
          iv_run = ls_line-calc_run_id iv_line = ls_line-line_num it_index = lt_fx_index ) ).
      DATA(lv_local_visible) = xsdbool( ls_fx_state-is_v2 = abap_false OR ls_fx_state-local_available = abap_true ).
      DATA(lv_ext) = VALUE #(
        it_contracts[ ct_uuid = ls_line-ct_uuid ]-ext_contract OPTIONAL ).
      DATA(lv_gu)  = COND string(
        WHEN ls_line-gross_up_amt <> 0 THEN 'Si' ELSE 'No' ).
      DATA(lv_delta_col) = COND string(
        WHEN ls_line-is_delta = abap_true THEN |Delta #{ ls_line-delta_seq }|
        ELSE || ).

      DATA lt_line_pcs TYPE zif_reing_ca_types=>ty_line_pc_t.
      CLEAR lt_line_pcs.
      READ TABLE lt_pc_sorted TRANSPORTING NO FIELDS WITH KEY
        calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num.
      IF sy-subrc = 0.
        DATA(lv_start_pc) = sy-tabix.
        DATA(lv_pc_offset) = lv_start_pc.
        DO lines( lt_pc_sorted ) - lv_start_pc + 1 TIMES.
          READ TABLE lt_pc_sorted INTO DATA(ls_selected_pc) INDEX lv_pc_offset.
          IF ls_selected_pc-calc_run_id <> ls_line-calc_run_id OR ls_selected_pc-line_num <> ls_line-line_num.
            EXIT.
          ENDIF.
          APPEND ls_selected_pc TO lt_line_pcs.
          lv_pc_offset += 1.
        ENDDO.
      ENDIF.
      IF ls_fx_state-is_v2 = abap_true.
        validate_trans_line( is_line = ls_line it_pcs = lt_line_pcs
          it_steps = line_fx_steps( iv_run = ls_line-calc_run_id iv_line = ls_line-line_num it_index = lt_fx_index )
          it_currencies = lt_projection_currencies iv_local_available = ls_fx_state-local_available ).
      ENDIF.
      DATA(lv_n_pcs) = lines( lt_line_pcs ).
      IF lv_n_pcs = 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |Sin apertura persistida: { ls_line-calc_run_id }/{ ls_line-line_num }|.
      ENDIF.
      DATA(lv_decimals) = VALUE i( it_currencies[ currency = ls_line-ct_currency ]-decimals DEFAULT 2 ).
      CLEAR lt_tax_acum.
      DATA lv_pc_idx TYPE i.
      CLEAR lv_pc_idx.
      DATA ls_pc LIKE LINE OF lt_line_pcs.
      DATA lv_idx_lpc TYPE i.
      lv_idx_lpc = 1.
      DO lines( lt_line_pcs ) TIMES.
        READ TABLE lt_line_pcs INTO ls_pc INDEX lv_idx_lpc.
        lv_pc_idx = lv_pc_idx + 1.
        DATA(lv_factor) = COND decfloat34(
          WHEN ls_line-bruto_amt <> 0
          THEN CONV decfloat34( ls_pc-bruto_amt ) / ls_line-bruto_amt
          ELSE 0 ).

        DATA(ls_row) = VALUE ty_excel_row( ).
        APPEND: ls_line-ct_id              TO ls_row-cols,
                lv_ext                     TO ls_row-cols,
                ls_line-bukrs_prest        TO ls_row-cols,
                ls_line-matnr              TO ls_row-cols,
                ls_line-op_type            TO ls_row-cols,
                ls_line-op_instance_num    TO ls_row-cols,
                ls_line-bukrs_recv         TO ls_row-cols,
                ls_line-country            TO ls_row-cols,
                ls_pc-prctr                TO ls_row-cols,
                ls_pc-campana              TO ls_row-cols,
                ls_pc-role_category        TO ls_row-cols,
                ls_pc-allocation           TO ls_row-cols,
                |{ ls_pc-share_abs NUMBER = RAW }|      TO ls_row-cols,
                |{ ls_line-share_pais_pct NUMBER = RAW }|  TO ls_row-cols,
                |{ ls_line-share_comb_pct NUMBER = RAW }|  TO ls_row-cols,
                lv_gu                      TO ls_row-cols,
                |{ ls_pc-calc_amt NUMBER = RAW }|       TO ls_row-cols,
                |{ ls_pc-bruto_amt NUMBER = RAW }|      TO ls_row-cols.

        DATA lv_total_tax TYPE decfloat34.
        CLEAR lv_total_tax.
        DATA ls_tt_pc LIKE LINE OF lt_tax_types.
        DATA lv_idx_tt TYPE i.
        lv_idx_tt = 1.
        DO lines( lt_tax_types ) TIMES.
          READ TABLE lt_tax_types INTO ls_tt_pc INDEX lv_idx_tt.
          DATA(lv_line_tax) = VALUE decfloat34(
            lt_step_taxes[
              calc_run_id = ls_line-calc_run_id
              line_num    = ls_line-line_num
              tax_type    = ls_tt_pc-tax_type ]-output_amt OPTIONAL ).
          READ TABLE lt_tax_acum ASSIGNING FIELD-SYMBOL(<ls_tax_acum>)
            WITH TABLE KEY tax_type = ls_tt_pc-tax_type.
          IF sy-subrc <> 0.
            INSERT VALUE #( tax_type = ls_tt_pc-tax_type )
              INTO TABLE lt_tax_acum ASSIGNING <ls_tax_acum>.
          ENDIF.
          DATA lv_tax_pc TYPE decfloat34.
          IF lv_pc_idx < lv_n_pcs.
            lv_tax_pc = round( val = lv_line_tax * lv_factor dec = lv_decimals ).
          ELSE.
            lv_tax_pc = lv_line_tax - <ls_tax_acum>-amount.
          ENDIF.
          <ls_tax_acum>-amount = <ls_tax_acum>-amount + lv_tax_pc.
          lv_total_tax = lv_total_tax + lv_tax_pc.
          APPEND COND string(
            WHEN line_exists( lt_step_taxes[
              calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num tax_type = ls_tt_pc-tax_type ] )
            THEN |{ lv_tax_pc NUMBER = RAW }| ELSE || ) TO ls_row-cols.
          lv_idx_tt = lv_idx_tt + 1.
        ENDDO.

        APPEND: |{ lv_total_tax NUMBER = RAW }|        TO ls_row-cols,
                |{ ls_pc-net_amt NUMBER = RAW }|        TO ls_row-cols,
                COND string( WHEN lv_local_visible = abap_true
                  THEN |{ ls_pc-net_local_amt NUMBER = RAW }| ELSE || ) TO ls_row-cols,
                ls_line-ct_currency        TO ls_row-cols,
                COND string( WHEN lv_local_visible = abap_true
                  THEN ls_line-local_currency ELSE || ) TO ls_row-cols,
                COND string( WHEN lv_local_visible = abap_true
                  THEN |{ ls_line-exch_rate NUMBER = RAW }| ELSE || ) TO ls_row-cols,
                lv_delta_col               TO ls_row-cols,
                ls_line-line_status        TO ls_row-cols,
                ls_line-trans_currency     TO ls_row-cols.
        APPEND COND string( WHEN ls_line-trans_currency IS INITIAL
                            THEN || ELSE |{ ls_pc-net_trans_amt NUMBER = RAW }| ) TO ls_row-cols.
        APPEND COND string( WHEN ls_line-trans_currency IS INITIAL
                            THEN || ELSE |{ ls_pc-bruto_trans_amt NUMBER = RAW }| ) TO ls_row-cols.
        APPEND COND string( WHEN ls_line-trans_currency IS INITIAL
                            THEN || ELSE |{ ls_line-exch_rate_1 NUMBER = RAW }| ) TO ls_row-cols.
        APPEND COND string( WHEN ls_line-trans_currency IS INITIAL
                            THEN || ELSE ls_line-exch_rate_1_type ) TO ls_row-cols.
        APPEND: ls_line-calc_run_id TO ls_row-cols, ls_line-line_num TO ls_row-cols,
                ls_pc-pc_seq TO ls_row-cols.
        APPEND ls_row TO lt_rows.
        add_total( EXPORTING iv_currency = ls_line-ct_currency iv_kind = 'C'
          iv_calc = CONV decfloat34( ls_pc-calc_amt ) iv_bruto = CONV decfloat34( ls_pc-bruto_amt )
          iv_tax = lv_total_tax iv_net = CONV decfloat34( ls_pc-net_amt )
          CHANGING ct_totals = lt_totals ).
        IF lv_local_visible = abap_true.
        add_total( EXPORTING iv_currency = ls_line-local_currency iv_kind = 'L'
          iv_net = CONV decfloat34( ls_pc-net_local_amt ) CHANGING ct_totals = lt_totals ).
        ENDIF.
        IF ls_fx_state-is_v2 = abap_true.
          add_total( EXPORTING iv_currency = ls_line-trans_currency
            iv_kind = zif_reing_ca_c=>export_total_kind-trans
            iv_bruto = CONV decfloat34( ls_pc-bruto_trans_amt )
            iv_net = CONV decfloat34( ls_pc-net_trans_amt ) CHANGING ct_totals = lt_totals ).
        ENDIF.
        DATA(lv_tax_total_idx) = 1.
        DO lines( lt_tax_types ) TIMES.
          DATA(lv_col) = 18 + lv_tax_total_idx.
          DATA(lv_tax_text) = ls_row-cols[ lv_col ].
          IF lv_tax_text IS NOT INITIAL.
            READ TABLE lt_tax_types INTO DATA(ls_total_type) INDEX lv_tax_total_idx.
            COLLECT VALUE ty_tax_total( currency = ls_line-ct_currency tax_type = ls_total_type-tax_type
              amount = CONV decfloat34( lv_tax_text ) ) INTO lt_tax_totals.
          ENDIF.
          lv_tax_total_idx += 1.
        ENDDO.
        lv_idx_lpc = lv_idx_lpc + 1.
      ENDDO.
    ENDLOOP.


    " Totals occupy the same numeric columns and never mix currencies.
    DATA(lv_ncols) = lines( ls_header-cols ).
    DATA(lv_taxes) = lines( lt_tax_types ).
    LOOP AT lt_totals INTO DATA(ls_total).
      CLEAR ls_row.
      DO lv_ncols TIMES. APPEND `` TO ls_row-cols. ENDDO.
      IF ls_total-kind = 'C'.
        ls_row-cols[ 1 ] = 'TOTAL CONTRATO'.
        ls_row-cols[ 17 ] = |{ ls_total-calc NUMBER = RAW }|.
        ls_row-cols[ 18 ] = |{ ls_total-bruto NUMBER = RAW }|.
        ls_row-cols[ 19 + lv_taxes ] = |{ ls_total-tax NUMBER = RAW }|.
        ls_row-cols[ 20 + lv_taxes ] = |{ ls_total-net NUMBER = RAW }|.
        ls_row-cols[ 22 + lv_taxes ] = ls_total-currency.
        DATA(lv_tax_idx) = 1.
        DO lv_taxes TIMES.
          READ TABLE lt_tax_types INTO ls_total_type INDEX lv_tax_idx.
          IF line_exists( lt_tax_totals[ currency = ls_total-currency tax_type = ls_total_type-tax_type ] ).
            ls_row-cols[ 18 + lv_tax_idx ] =
              |{ lt_tax_totals[ currency = ls_total-currency tax_type = ls_total_type-tax_type ]-amount NUMBER = RAW }|.
          ENDIF.
          lv_tax_idx += 1.
        ENDDO.
      ELSEIF ls_total-kind = zif_reing_ca_c=>export_total_kind-trans.
        ls_row-cols[ 1 ] = TEXT-001.
        ls_row-cols[ trans_col-net + lv_taxes ] = |{ ls_total-net NUMBER = RAW }|.
        ls_row-cols[ trans_col-bruto + lv_taxes ] = |{ ls_total-bruto NUMBER = RAW }|.
        ls_row-cols[ trans_col-currency + lv_taxes ] = ls_total-currency.
      ELSE.
        ls_row-cols[ 1 ] = 'TOTAL LOCAL'.
        ls_row-cols[ 21 + lv_taxes ] = |{ ls_total-net NUMBER = RAW }|.
        ls_row-cols[ 23 + lv_taxes ] = ls_total-currency.
      ENDIF.
      APPEND ls_row TO lt_rows.
    ENDLOOP.
    LOOP AT lt_rows INTO DATA(ls_output).
      APPEND ls_output-cols TO rt_rows.
    ENDLOOP.
  ENDMETHOD.

  METHOD add_total.
    COLLECT VALUE ty_total( currency = iv_currency kind = iv_kind
      calc = iv_calc bruto = iv_bruto tax = iv_tax net = iv_net ) INTO ct_totals.
  ENDMETHOD.

  METHOD numeric_cols.
    " Derive the dynamic span from the fixed schema, never from tax labels.
    DATA(lv_tax_count) = lines( it_header ) - 34.
    IF lv_tax_count < 0. RETURN. ENDIF.
    DO lines( it_header ) TIMES.
      DATA(lv_index) = sy-index.
      IF ( lv_index >= 13 AND lv_index <= 15 )
         OR ( lv_index >= 17 AND lv_index <= 21 + lv_tax_count )
         OR lv_index = 24 + lv_tax_count
         OR ( lv_index >= 28 + lv_tax_count AND lv_index <= 30 + lv_tax_count ).
        INSERT lv_index INTO TABLE rt_cols.
      ENDIF.
    ENDDO.
  ENDMETHOD.
ENDCLASS.

*--- Mantenimiento ---
* Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
* Descripcion : F3.2 Calculate + APJ - TYPES locales, nuevos metodos LHC
*               (calculate, check_scope, check_insumos) y LSC completa
*               (lsc_zi_reingcarun: save_modified + schedule_calc_job).
*               El agendamiento APJ va en la LSC, NO en el handler.
*               F3.2-DD-2 corregida, blueprint SS C.2.
* End Change ID V002 (10.07.2026 | EXT_OSCUGALD)
* Begin Change ID V017 (06.08.2026 | EXT_GONZALCA)
* Requerimiento   : P4-4
* Descripcion     : Fix save_modified - las 5 sentencias DML que filtraban
*                    solo por LINE_NUM (RANGE) ahora filtran por la clave
*                    real CALC_RUN_ID+LINE_NUM. LINE_NUM se numera POR RUN,
*                    NO es unico global -- el filtro incompleto podia tocar
*                    lineas de un RUN distinto en silencio (corrupcion
*                    cruzada entre RUNs). Buffers gt_line_del/gt_line_status
*                    (lcl_reing_ca_dml_buffer) pasan a portar calc_run_id;
*                    se ajustan los 3 productores (calculate/delete/release)
*                    y los 5 consumidores en save_modified (LOG_NUM, DELETE
*                    STEP_A/LPC_A/LINE_A, UPDATE line_status).
* Transporte      : DS4K9B5XZC
* Referencia      : S 5000049390
* End Change ID V017 (06.08.2026 | EXT_GONZALCA)
*----------------------------------------------------------------------*
* Include: definitions (LHC handler class declaration)
*----------------------------------------------------------------------*
" Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
TYPES: BEGIN OF ty_insumo_error,
         group   TYPE zreing_ca_s_group_key,
         message TYPE string,
       END OF ty_insumo_error,
       tt_insumo_error TYPE STANDARD TABLE OF ty_insumo_error WITH EMPTY KEY.

TYPES: BEGIN OF ty_created_line,
         calc_run_id TYPE zreing_ca_line_a-calc_run_id,
         line_num    TYPE zreing_ca_line_a-line_num,
       END OF ty_created_line,
       tt_created_line TYPE STANDARD TABLE OF ty_created_line WITH EMPTY KEY.

" ATC fix (NonLocal DBREAD via check_insumos): tipo global para pasar
" el pre-fetch de identidades de contrato al metodo check_insumos.
TYPES: BEGIN OF ty_identity_bulk,
         ct_uuid     TYPE zreing_ct2_a-ct_uuid,
         mat_uuid    TYPE zreing_ct2_mat_a-mat_uuid,
         ct_id       TYPE zreing_ct2_a-ct_id,
         lifnr       TYPE zreing_ct2_a-lifnr,
         bukrs_prest TYPE zreing_ct2_a-bukrs,
         matnr       TYPE zreing_ct2_mat_a-matnr,
       END OF ty_identity_bulk,
       tt_identity_bulk TYPE STANDARD TABLE OF ty_identity_bulk WITH EMPTY KEY.

" ATC fix (NonLocal DBREAD via get_me_metric en check_insumos): tipo global
" para el pre-fetch de metricas ME (zreing_me_h_a) pasado como parametro.
TYPES: BEGIN OF ty_me_metric_bulk,
         ct_id       TYPE zreing_me_h_a-ct_id,
         matnr       TYPE zreing_me_h_a-matnr,
         metric_code TYPE zreing_me_h_a-metric_code,
         met_version TYPE zreing_me_h_a-met_version,
       END OF ty_me_metric_bulk,
       tt_me_metric_bulk TYPE STANDARD TABLE OF ty_me_metric_bulk WITH EMPTY KEY.

" ATC fix (NonLocal DBREAD via get_cm_amount en check_insumos): tipo global
" para el pre-fetch de CM_H_A elegibles pasado como parametro.
" Solo se necesita la clave de grupo para verificar existencia en check_insumos.
TYPES: BEGIN OF ty_cm_bulk,
         ct_uuid   TYPE zreing_cm_h_a-ct_uuid,
         mat_uuid  TYPE zreing_cm_h_a-mat_uuid,
         op_type   TYPE zreing_cm_h_a-op_type,
         cm_h_id   TYPE zreing_cm_h_a-cm_h_id,
         load_seq  TYPE zreing_cm_h_a-load_seq,
         delta_flag TYPE zreing_cm_h_a-delta_flag,
       END OF ty_cm_bulk,
       tt_cm_bulk TYPE STANDARD TABLE OF ty_cm_bulk WITH EMPTY KEY.
" End Change ID V002 (10.07.2026 | EXT_OSCUGALD)

" Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
" Fix 002: tipos locales del helper DRY ensure_runs (find-or-create del Run).
" ty_run_request = entrada (1 por key de calculate/initializeperiod);
" ty_run_state   = salida (estado real tras el find-or-create). want_create
" gobierna CU-6 (no crear Run vacio cuando ningun grupo del key es elegible).
TYPES: BEGIN OF ty_run_request,
         cid           TYPE string,
         fiscal_year   TYPE zreing_ca_run_a-fiscal_year,
         fiscal_period TYPE zreing_ca_run_a-fiscal_period,
         want_create   TYPE abap_bool,
         calc_run_id   TYPE zreing_calc_run_id,
       END OF ty_run_request,
       tt_run_request TYPE STANDARD TABLE OF ty_run_request WITH EMPTY KEY.

TYPES: BEGIN OF ty_run_state,
         cid           TYPE string,
         calc_run_id   TYPE zreing_ca_run_a-calc_run_id,
         existed       TYPE abap_bool,
         created       TYPE abap_bool,
         needs_create  TYPE abap_bool,
         fiscal_year   TYPE zreing_ca_run_a-fiscal_year,
         fiscal_period TYPE zreing_ca_run_a-fiscal_period,
       END OF ty_run_state,
       tt_run_state TYPE STANDARD TABLE OF ty_run_state WITH EMPTY KEY.
" End Change ID V008 (15.07.2026 | EXT_GONZALCA)

" Begin Change ID V010 (17.07.2026 | EXT_GONZALCA)
" Descripcion : Fix RUNTIME_ERROR BEHAVIOR_ILLEGAL_STATEMENT (dump real
"               17.07.2026, ZBP_REINGCARUN CCIMP linea 936, INSERT LOG_A en
"               Calculate). Los metodos FOR MODIFY (calculate/release/delete)
"               corren en la fase "Modify" del ciclo RAP -- el runtime SIEMPRE
"               bloquea alli cualquier INSERT/UPDATE/DELETE/MODIFY directo a
"               tabla, EML incluida o no (confirmado por el texto del dump).
"               Fix: los 3 handlers ya NO ejecutan DML directo -- acumulan en
"               este buffer STATIC (visible tanto para el LHC como para el
"               LSC dentro del mismo LUW/sesion ABAP) y save_modified() -- la
"               fase Save real, unico punto donde el runtime SI permite DML
"               directo salvo operaciones que fuercen COMMIT -- vuelca el
"               buffer completo una sola vez al final y lo limpia.
"               LOG_A se sigue escribiendo por SQL directo a proposito (no
"               EML/composicion): debe sobrevivir si el padre (CalcLine) es
"               borrado en el mismo LUW -- ver decision ya registrada en
"               feedback-rap-audit-log-cascade-delete.
CLASS lcl_reing_ca_dml_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    "Begin Insert V017 (CC)
    " V017: a line's real identity is CALC_RUN_ID + LINE_NUM. LINE_NUM is
    "       numbered per RUN, it is NOT globally unique (fixes silent
    "       cross-RUN corruption). New key type shared by all producers/consumer.
    TYPES: BEGIN OF ty_line_del_key,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
           END OF ty_line_del_key,
           tt_line_del_key TYPE STANDARD TABLE OF ty_line_del_key WITH EMPTY KEY.
    "End Insert V017 (CC)

    TYPES: BEGIN OF ty_line_status_upd,
             "Begin Insert V017 (CC)
             " V017: carry calc_run_id so the status UPDATE is scoped to the RUN.
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             "End Insert V017 (CC)
             line_num    TYPE zreing_ca_line_a-line_num,
             line_status TYPE zreing_ca_line_a-line_status,
           END OF ty_line_status_upd,
           tt_line_status_upd TYPE STANDARD TABLE OF ty_line_status_upd WITH EMPTY KEY.

    " Begin Insert V016 (CC) - F4 (fix post-Eclipse: TYPE RANGE OF no se admite
    " inline en la firma de un metodo -- exige un tipo con nombre, ver
    " allowed_source_status mas abajo en lhc_zi_reingcarun)
    TYPES tt_line_status_range TYPE RANGE OF zreing_ca_line_a-line_status.
    " End Insert V016 (CC) - F4

    " Begin Insert V016 (CC) - F4 [fix BUG-002: prefetch_contab_data recibe el
    " conjunto de CalcRunIds de TODAS las keys de la accion en un solo rango --
    " misma razon que tt_line_status_range: "TYPE RANGE OF" inline no se admite
    " en la firma de un metodo, exige un tipo con nombre]
    TYPES tt_run_id_range TYPE RANGE OF zreing_ca_run_a-calc_run_id.
    " End Insert V016 (CC) - F4

    CLASS-DATA gt_log            TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
    "Begin Mod V017 (CC)
    " V017: gt_line_del was RANGE OF line_num (loses calc_run_id -> could
    "       delete rows of the wrong RUN). Now a table of (calc_run_id, line_num).
    "    CLASS-DATA gt_line_del       TYPE RANGE OF zreing_ca_line_a-line_num.
    CLASS-DATA gt_line_del       TYPE tt_line_del_key.
    "End Mod V017 (CC)
    CLASS-DATA gt_line_status    TYPE tt_line_status_upd.
    CLASS-DATA gt_usage          TYPE zcl_reing_ca_insumo_mgr=>ty_usage_t.
    CLASS-DATA gt_me_h_libr      TYPE zcl_reing_ca_insumo_mgr=>ty_me_h_rang.
    CLASS-DATA gt_run_ids_recalc TYPE STANDARD TABLE OF zreing_ca_run_a-calc_run_id WITH EMPTY KEY.

    " Begin Insert V018 (09.09.2026 | EXT_GONZALCA)
    " Cola de trabajo de las 3 actions de contabilizacion. Simulate/Post/Storno
    " ya NO ejecutan el Engine: el BDEF declara strict ( 2 ), que en la fase de
    " interaccion prohibe tanto el DML directo (los 3 INSERT de
    " flush_documents) como el CALL FUNCTION IN UPDATE TASK que registran
    " BAPI_ACC_DOCUMENT_POST / _REV_POST desde ZCL_REING_CONTAB_FI_POSTER.
    " El handler encola el scope aca y lsc_zi_reingcarun~save_modified -- la
    " fase SAVE -- lo ejecuta. Dump que lo forzo: ST22
    " BEHAVIOR_ILLEGAL_STATEMENT_20260909_120904 (TS4-400).
    " gt_contab_lines/_pc/_step transportan la pre-lectura hecha en el handler:
    " los SELECT son legales en las dos fases, y dejarlos alli conserva la
    " forma "una sola lectura masiva por accion" que exigio BUG-002.
    TYPES: BEGIN OF ty_contab_job,
             run_id TYPE zreing_ca_run_a-calc_run_id,
             groups TYPE zreing_ca_tt_group_key,
             mode   TYPE zreing_ca_contab_mode,
           END OF ty_contab_job,
           tt_contab_job TYPE STANDARD TABLE OF ty_contab_job WITH EMPTY KEY.
    CLASS-DATA gt_contab_jobs  TYPE tt_contab_job.
    CLASS-DATA gt_contab_lines TYPE zif_reing_ca_types=>ty_line_t.
    CLASS-DATA gt_contab_pc    TYPE zif_reing_ca_types=>ty_line_pc_t.
    CLASS-DATA gt_contab_step  TYPE zif_reing_ca_types=>ty_step_t.
    " End Insert V018 (09.09.2026 | EXT_GONZALCA)

    " Begin Mod V019 (09.09.2026 | EXT_GONZALCA)
    " Nucleo de CONTAB. Vive aca y no en lhc_zi_reingcarun porque desde V018 lo
    " ejecuta el saver, y una clase de comportamiento RAP no puede declarar
    " FRIENDS a nadie que no sea una clase de test. Esta clase ya era el punto
    " compartido entre LHC y LSC (gt_log, gt_line_f4, isolate_and_*).
    " El TEST-SEAM "engine_process" viaja con el cuerpo de run_contab_mode; la
    " TEST-INJECTION de ltcl_contab_actions lo sigue encontrando (se asocian por
    " nombre dentro del mismo pool de clases) y el estado del doble ya vivia
    " aca, asi que no hay ninguna referencia hacia adelante que resolver.
    CLASS-METHODS run_contab_mode
      IMPORTING iv_run_id    TYPE zreing_ca_run_a-calc_run_id
                it_groups    TYPE zreing_ca_tt_group_key
                iv_mode      TYPE zreing_ca_contab_mode
                it_lines_all TYPE zif_reing_ca_types=>ty_line_t
                it_pc_all    TYPE zif_reing_ca_types=>ty_line_pc_t
                it_step_all  TYPE zif_reing_ca_types=>ty_step_t
      EXPORTING et_msg       TYPE zif_reing_ca_types=>ty_log_t
                ev_has_error TYPE abap_bool.

    " Estados de origen admitidos por modo (CLAR-03 / SUP-01..03).
    CLASS-METHODS allowed_source_status
      IMPORTING iv_mode           TYPE zreing_ca_contab_mode
      RETURNING VALUE(rt_allowed) TYPE tt_line_status_range.

    " Punto UNICO de instanciacion del poster FI (CLAR-02).
    CLASS-METHODS get_fi_poster
      RETURNING VALUE(ro_poster) TYPE REF TO zif_reing_contab_fi_poster.
    " End Mod V019 (09.09.2026 | EXT_GONZALCA)

    " Begin Change ID V016 (CC) - F4 (05.08.2026 | EXT_GONZALCA)
    " (a) Payload de eventos RAP pendientes de disparar en la fase SAVE
    "     tardia. Se acumulan aca -- NO se disparan en el metodo de la
    "     accion -- porque RAP exige que el evento se levante despues del
    "     punto de no retorno (DD-F4-2, garantiza CU-12: rollback => 0 eventos).
    TYPES: BEGIN OF ty_posted_evt,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
             op_type     TYPE zreing_ca_line_a-op_type,
           END OF ty_posted_evt,
           tt_posted_evt TYPE STANDARD TABLE OF ty_posted_evt WITH EMPTY KEY.
    TYPES: BEGIN OF ty_reversed_evt,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
           END OF ty_reversed_evt,
           tt_reversed_evt TYPE STANDARD TABLE OF ty_reversed_evt WITH EMPTY KEY.

    CLASS-DATA gt_posted_evt   TYPE tt_posted_evt.
    CLASS-DATA gt_reversed_evt TYPE tt_reversed_evt.

    " (b) Buffer de LINE_A tocadas por Simulate/Post/Storno. Guarda la FILA
    "     COMPLETA ya mutada (line_status + sim_message + fi_awkey) porque
    "     esas 3 columnas cambian juntas y con valores DISTINTOS por linea:
    "     un buffer clave/valor exigiria un UPDATE por linea (hallazgo ATC
    "     DBWRT-in-loop, ya corregido en F3 en este mismo objeto). Con la
    "     fila completa el volcado es UNA sola sentencia
    "     "UPDATE zreing_ca_line_a FROM TABLE @gt_line_f4" (ver PATCH 8).
    "     Las filas provienen de la pre-lectura masiva de la MISMA LUW, bajo
    "     el lock master del BO -> no hay riesgo de pisar cambios ajenos.
    "     BR-F4-07: para un Storno con error de negocio la fila se bufferea
    "     con line_status SIN cambiar ('CONT') y solo sim_message poblado --
    "     equivalente exacto a "no hacer APPEND a gt_line_status" (DD-F4-12).
    CLASS-DATA gt_line_f4 TYPE zif_reing_ca_types=>ty_line_t.

    " (c) Estado del doble de ZCL_REING_CONTAB_ENGINE para el TEST-INJECTION
    "     del seam "engine_process" (run_contab_mode). Vive AQUI (no en la
    "     clase de test) porque el TEST-INJECTION se compila en el contexto
    "     de run_contab_mode -- dentro de este include -- y esta clase ya
    "     esta completamente definida en ese punto: cero referencia hacia
    "     adelante, cero necesidad de "DEFERRED"/"DEFINITION LOAD" (obsoleta
    "     y rechazada por esta version de ABAP) para que el seam la lea. La
    "     clase de test (ltcl_contab_actions) solo necesita escribir/leer
    "     estos mismos 4 campos por su nombre completo -- no le hace falta
    "     ninguna relacion FRIENDS para eso, PUBLIC SECTION alcanza.
    CLASS-DATA gs_engine_result TYPE zif_reing_contab_types=>ty_process_result.
    CLASS-DATA gv_engine_raise  TYPE abap_bool.
    CLASS-DATA gv_engine_text   TYPE string.
    CLASS-DATA gv_engine_calls  TYPE i.
    " End Change ID V016 (CC) - F4

    "Begin Insert V017 (CC)
    " V017 (testability refactor): pure/testable helpers extracted from the
    " calculate/delete/save_modified handlers. They carry NO business logic
    " beyond what V017 already made active inline; extracting them lets ABAP
    " Unit exercise the per-RUN isolation (CALC_RUN_ID + LINE_NUM) without
    " driving the RAP framework -- same rationale DD-F4-4 used to make
    " run_contab_mode a pure CLASS-METHODS. Public so both the handlers and
    " the test class can call them (no FRIENDS needed).

    " Named table type for gt_log so recalc_log_num_per_run can take it as a
    " typed CHANGING parameter (gt_log itself stays declared as-is; it is
    " compatible with this type).
    TYPES tt_log TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
    " V001 (CC) - GAP-001 (Delta v2): pure RUN routing under caller's period lock.
    TYPES tt_runs TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    TYPES: BEGIN OF ty_run_choice,
             calc_run_id TYPE zreing_calc_run_id,
             fresh       TYPE abap_bool,
             message     TYPE string,
           END OF ty_run_choice.
    CLASS-METHODS choose_calc_run
      IMPORTING is_group TYPE zreing_ca_s_group_key
                iv_year TYPE gjahr
                iv_period TYPE zreing_fiscal_period
                it_lines TYPE zif_reing_ca_types=>ty_line_t
      RETURNING VALUE(rs_choice) TYPE ty_run_choice.
    CLASS-METHODS next_calc_run
      IMPORTING iv_year TYPE gjahr
                iv_period TYPE zreing_fiscal_period
                it_runs TYPE tt_runs
      RETURNING VALUE(rs_choice) TYPE ty_run_choice.



    " Flatten (calc_run_id, line_nums-range) bulk rows into (calc_run_id,
    " line_num) pairs. Generic input: unifies the identical inline loops of
    " PATCH B (calculate, ty_calc_run_nums) and PATCH C (delete, ty_del_batch)
    " -- structurally equal but locally named types. DEV-1 index reset bug is
    " gone by construction (LOOP AT, no manual DO/index).
    CLASS-METHODS flatten_run_line_nums
      IMPORTING it_bulk         TYPE STANDARD TABLE
      RETURNING VALUE(rt_pairs) TYPE tt_line_del_key.

    " Recompute LOG_NUM per (calc_run_id, line_num) for the buffered LOG_A
    " rows (former PATCH E, save_modified). Reads the persisted MAX(log_num)
    " per key and renumbers gt_log in place.
    CLASS-METHODS recalc_log_num_per_run
      CHANGING ct_log TYPE tt_log.

    " Delete orphan STEP_A/LPC_A/LINE_A rows scoped to the exact
    " (calc_run_id, line_num) pairs (former PATCH F, save_modified).
    CLASS-METHODS isolate_and_delete_orphans
      IMPORTING it_pairs TYPE tt_line_del_key.

    " Update LINE_A-line_status scoped to the exact (calc_run_id, line_num)
    " pairs (former PATCH G, save_modified).
    CLASS-METHODS isolate_and_update_status
      IMPORTING it_pairs TYPE tt_line_status_upd.
    "End Insert V017 (CC)
ENDCLASS.

CLASS lcl_reing_ca_dml_buffer IMPLEMENTATION.
  "Begin Insert V017 (CC)

  METHOD choose_calc_run.
    rs_choice-calc_run_id = |RUN-{ iv_year }{ iv_period }|.
    DATA lv_history TYPE abap_bool.
    DATA lv_active_run TYPE zreing_calc_run_id.
    LOOP AT it_lines INTO DATA(ls_line)
      WHERE ct_uuid = is_group-ct_uuid AND mat_uuid = is_group-mat_uuid
        AND op_type = is_group-op_type AND op_uuid = is_group-op_uuid.
      IF ls_line-line_status = zif_reing_ca_c=>line_status-anuld.
        lv_history = abap_true.
        CONTINUE.
      ENDIF.
      IF ls_line-cm_h_id <> is_group-cm_h_id.
        CONTINUE.
      ENDIF.
      " V001 (CC) - #115 (Delta v2): reject before routing/reset/job buffers.
      " CM_H_ID was matched above: a posted base cannot block a new delta load.
      IF ls_line-line_status = zif_reing_ca_c=>line_status-libd
         OR ls_line-line_status = zif_reing_ca_c=>line_status-cont
         OR ls_line-line_status = zif_reing_ca_c=>line_status-post_err.
        rs_choice-message = |El grupo ya fue liberado o contabilizado ({ ls_line-line_status }); no admite Calcular|.
        RETURN.
      ENDIF.
      IF ls_line-line_status = zif_reing_ca_c=>line_status-anul_err.
        rs_choice-message = 'ANUL_ERR solo admite reintentar Anular'.
        RETURN.
      ENDIF.
      IF lv_active_run IS NOT INITIAL AND lv_active_run <> ls_line-calc_run_id.
        rs_choice-message = 'Hay mas de un RUN activo para la combinacion; verificar historico'.
        RETURN.
      ENDIF.
      lv_active_run = ls_line-calc_run_id.
    ENDLOOP.
    IF lv_active_run IS NOT INITIAL.
      rs_choice-calc_run_id = lv_active_run.
    ELSEIF lv_history = abap_true.
      CLEAR rs_choice-calc_run_id.
      rs_choice-fresh = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD next_calc_run.
    " Called only while holding EZREINGCARUN on canonical RUN-YYYYMM.
    DATA(lv_prefix) = |RUN-{ iv_year }{ iv_period }-|.
    DATA lv_max TYPE i.
    LOOP AT it_runs INTO DATA(ls_run)
      WHERE fiscal_year = iv_year AND fiscal_period = iv_period.
      IF ls_run-calc_run_id(11) = lv_prefix
         AND ls_run-calc_run_id+11(9) CO '0123456789'.
        DATA(lv_seq) = CONV i( ls_run-calc_run_id+11(9) ).
        lv_max = nmax( val1 = lv_max val2 = lv_seq ).
      ENDIF.
    ENDLOOP.
    IF lv_max >= 999999999.
      rs_choice-message = 'Se agoto la secuencia de RUN del periodo; no se creo calculo'.
      RETURN.
    ENDIF.
    DATA lv_next TYPE n LENGTH 9.
    lv_next = lv_max + 1.
    rs_choice-calc_run_id = |{ lv_prefix }{ lv_next }|.
  ENDMETHOD.


  METHOD flatten_run_line_nums.
    " Generic access by component name: it_bulk rows expose CALC_RUN_ID and
    " LINE_NUMS (a table of range structures whose LOW carries the line_num).
    " Works for both ty_calc_run_nums (calculate) and ty_del_batch (delete).
    " ATC fix: DO...TIMES + READ TABLE INDEX instead of nested LOOP AT/ENDLOOP
    " (same anti-nested-loop pattern already used across this object).
    " Fix (Eclipse real syntax check): "Explicit or implicit index operations
    " cannot be used on tables with type HASHED TABLE or ANY TABLE" -- READ
    " TABLE ... INDEX needs an index-capable generic type, not plain ANY TABLE.
    FIELD-SYMBOLS <row>  TYPE any.
    FIELD-SYMBOLS <rid>  TYPE any.
    FIELD-SYMBOLS <nums> TYPE INDEX TABLE.
    FIELD-SYMBOLS <nrow> TYPE any.
    FIELD-SYMBOLS <low>  TYPE any.
    DATA lv_idx_row TYPE i.
    lv_idx_row = 1.
    DO lines( it_bulk ) TIMES.
      READ TABLE it_bulk ASSIGNING <row> INDEX lv_idx_row.
      lv_idx_row = lv_idx_row + 1.
      ASSIGN COMPONENT 'CALC_RUN_ID' OF STRUCTURE <row> TO <rid>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      ASSIGN COMPONENT 'LINE_NUMS' OF STRUCTURE <row> TO <nums>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA lv_idx_num TYPE i.
      lv_idx_num = 1.
      DO lines( <nums> ) TIMES.
        READ TABLE <nums> ASSIGNING <nrow> INDEX lv_idx_num.
        lv_idx_num = lv_idx_num + 1.
        ASSIGN COMPONENT 'LOW' OF STRUCTURE <nrow> TO <low>.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        APPEND VALUE ty_line_del_key( calc_run_id = <rid>
                                      line_num    = <low> ) TO rt_pairs.
      ENDDO.
    ENDDO.
  ENDMETHOD.

  METHOD recalc_log_num_per_run.
    " Former PATCH E body, verbatim except gt_log -> ct_log. LINE_NUM is
    " numbered per RUN and NOT globally unique, so LOG_NUM is recomputed per
    " (CALC_RUN_ID, LINE_NUM). A running counter keeps incrementing for
    " several new entries of the SAME line within the same flush (avoids PK
    " collision calc_run_id+line_num+log_num).
    TYPES: BEGIN OF ty_log_max,
             calc_run_id TYPE zreing_ca_log_a-calc_run_id,
             line_num    TYPE zreing_ca_log_a-line_num,
             log_num     TYPE zreing_ca_log_a-log_num,
           END OF ty_log_max.
    DATA lt_log_max TYPE STANDARD TABLE OF ty_log_max WITH EMPTY KEY.

    " Distinct (calc_run_id, line_num) driver built from ct_log.
    DATA lt_log_keys TYPE tt_line_del_key.
    lt_log_keys = VALUE #( FOR ls_lg IN ct_log
      ( calc_run_id = ls_lg-calc_run_id line_num = ls_lg-line_num ) ).
    SORT lt_log_keys BY calc_run_id line_num.
    DELETE ADJACENT DUPLICATES FROM lt_log_keys COMPARING calc_run_id line_num.
    " FOR ALL ENTRIES guarded: empty driver would read the whole table.
    " Open SQL does not allow GROUP BY together with FOR ALL ENTRIES: read the
    " raw matching rows and compute MAX(log_num) per key in ABAP.
    IF lt_log_keys IS NOT INITIAL.
      DATA lt_log_raw TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
      SELECT calc_run_id, line_num, log_num
        FROM zreing_ca_log_a
        FOR ALL ENTRIES IN @lt_log_keys
        WHERE calc_run_id = @lt_log_keys-calc_run_id
          AND line_num    = @lt_log_keys-line_num
        INTO CORRESPONDING FIELDS OF TABLE @lt_log_raw.

      DATA ls_raw LIKE LINE OF lt_log_raw.
      DATA lv_idx_raw TYPE i.
      lv_idx_raw = 1.
      DO lines( lt_log_raw ) TIMES.
        READ TABLE lt_log_raw INTO ls_raw INDEX lv_idx_raw.
        ASSIGN lt_log_max[ calc_run_id = ls_raw-calc_run_id
                           line_num    = ls_raw-line_num ] TO FIELD-SYMBOL(<ls_lm_raw>).
        IF sy-subrc <> 0.
          APPEND VALUE ty_log_max( calc_run_id = ls_raw-calc_run_id
                                   line_num    = ls_raw-line_num
                                   log_num     = ls_raw-log_num ) TO lt_log_max.
        ELSEIF ls_raw-log_num > <ls_lm_raw>-log_num.
          <ls_lm_raw>-log_num = ls_raw-log_num.
        ENDIF.
        lv_idx_raw = lv_idx_raw + 1.
      ENDDO.
    ENDIF.

    DATA ls_log_row LIKE LINE OF ct_log.
    DATA lv_idx_log TYPE i VALUE 1.
    DO lines( ct_log ) TIMES.
      READ TABLE ct_log INTO ls_log_row INDEX lv_idx_log.
      ASSIGN lt_log_max[ calc_run_id = ls_log_row-calc_run_id
                         line_num    = ls_log_row-line_num ] TO FIELD-SYMBOL(<ls_lm>).
      IF sy-subrc = 0.
        <ls_lm>-log_num = <ls_lm>-log_num + 1.
      ELSE.
        APPEND VALUE ty_log_max( calc_run_id = ls_log_row-calc_run_id
                                 line_num    = ls_log_row-line_num
                                 log_num     = 1 ) TO lt_log_max.
        ASSIGN lt_log_max[ calc_run_id = ls_log_row-calc_run_id
                           line_num    = ls_log_row-line_num ] TO <ls_lm>.
      ENDIF.
      ls_log_row-log_num = <ls_lm>-log_num.
      MODIFY ct_log FROM ls_log_row INDEX lv_idx_log.
      lv_idx_log = lv_idx_log + 1.
    ENDDO.
  ENDMETHOD.

  METHOD isolate_and_delete_orphans.
    " Former PATCH F body, parameterized on it_pairs instead of gt_line_del.
    " STEP_A/LPC_A have a longer PK, so a partial-key FROM TABLE or a single
    " -field range is unsafe: read the affected rows by pair, then DELETE FROM
    " TABLE by full PK. LINE_A uses the same read-then-delete pattern (a
    " partial-key DELETE FROM TABLE does not resolve in this release). All
    " statements stay outside any loop (BR-4 / no DB-op-in-loop).
    IF it_pairs IS INITIAL.
      RETURN.
    ENDIF.
    " Local driver copy as FOR ALL ENTRIES source (Eclipse syntax-safe).
    DATA(lt_del_drv) = it_pairs.

    SELECT * FROM zreing_ca_step_a
      FOR ALL ENTRIES IN @lt_del_drv
      WHERE calc_run_id = @lt_del_drv-calc_run_id
        AND line_num    = @lt_del_drv-line_num
      INTO TABLE @DATA(lt_step_del).
    IF lt_step_del IS NOT INITIAL.
      DELETE zreing_ca_step_a FROM TABLE @lt_step_del.
    ENDIF.

    SELECT * FROM zreing_ca_lpc_a
      FOR ALL ENTRIES IN @lt_del_drv
      WHERE calc_run_id = @lt_del_drv-calc_run_id
        AND line_num    = @lt_del_drv-line_num
      INTO TABLE @DATA(lt_lpc_del).
    IF lt_lpc_del IS NOT INITIAL.
      DELETE zreing_ca_lpc_a FROM TABLE @lt_lpc_del.
    ENDIF.

    SELECT * FROM zreing_ca_line_a
      FOR ALL ENTRIES IN @lt_del_drv
      WHERE calc_run_id = @lt_del_drv-calc_run_id
        AND line_num    = @lt_del_drv-line_num
      INTO TABLE @DATA(lt_line_del).
    IF lt_line_del IS NOT INITIAL.
      DELETE zreing_ca_line_a FROM TABLE @lt_line_del.
    ENDIF.
  ENDMETHOD.

  METHOD isolate_and_update_status.
    " Former PATCH G body, parameterized on it_pairs instead of gt_line_status.
    " Status UPDATE scoped to (calc_run_id, line_num): read full rows, apply
    " the buffered line_status in memory, one set-based UPDATE FROM TABLE
    " outside any loop.
    IF it_pairs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_st_drv) = it_pairs.

    DATA lt_line_full_sav TYPE zif_reing_ca_types=>ty_line_t.
    SELECT * FROM zreing_ca_line_a
      FOR ALL ENTRIES IN @lt_st_drv
      WHERE calc_run_id = @lt_st_drv-calc_run_id
        AND line_num    = @lt_st_drv-line_num
      INTO TABLE @lt_line_full_sav.

    DATA ls_st_upd LIKE LINE OF lt_st_drv.
    DATA lv_idx_st TYPE i VALUE 1.
    DO lines( lt_st_drv ) TIMES.
      READ TABLE lt_st_drv INTO ls_st_upd INDEX lv_idx_st.
      lv_idx_st = lv_idx_st + 1.
      ASSIGN lt_line_full_sav[ calc_run_id = ls_st_upd-calc_run_id
                               line_num    = ls_st_upd-line_num ] TO FIELD-SYMBOL(<ls_ln_sav>).
      IF sy-subrc = 0.
        <ls_ln_sav>-line_status = ls_st_upd-line_status.
      ENDIF.
    ENDDO.

    IF lt_line_full_sav IS NOT INITIAL.
      UPDATE zreing_ca_line_a FROM TABLE @lt_line_full_sav.
    ENDIF.
  ENDMETHOD.
  "End Insert V017 (CC)

  " Begin Mod V019 (09.09.2026 | EXT_GONZALCA)
  " Los 3 cuerpos vienen TAL CUAL de lhc_zi_reingcarun (movidos, no reescritos).
  " End Mod V019 (09.09.2026 | EXT_GONZALCA)
  METHOD run_contab_mode.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " DELEGADOR. El nucleo se mudo ENTERO a ZCL_REING_CA_CONTAB_RUNNER, sin
    " cambios de logica: lo necesita tambien ZCL_REING_CA_CONTAB_JOB, que es
    " una clase GLOBAL y no ve esta clase local del behavior pool. Y el pool no
    " puede cederla por FRIENDS -- una clase de comportamiento RAP solo admite
    " como friend a una clase de test ("Here, FRIENDS is only allowed with
    " local DEFERRED FOR TESTING classes", activacion real de V018). Es el
    " mismo movimiento que V019 hizo de lhc_ a lcl_, un nivel mas afuera.
    " La firma NO cambia, asi que ni los llamadores ni ltcl_contab_actions se
    " tocan. Lo unico que hace este cuerpo es volcar a los buffers estaticos
    " del pool lo que el runner ahora devuelve como parametros: una clase
    " global no puede -- ni debe -- escribir el estado de una clase local.
    " El TEST-SEAM "engine_process" viajo con el nucleo, por lo que los tests
    " que lo inyectan viven ahora en el include de tests del runner.
    DATA lt_log_run      TYPE zif_reing_ca_types=>ty_log_t.
    DATA lt_line_upd_run TYPE zif_reing_ca_types=>ty_line_t.
    DATA lt_posted_run   TYPE zcl_reing_ca_contab_runner=>tt_posted_evt.
    DATA lt_reversed_run TYPE zcl_reing_ca_contab_runner=>tt_reversed_evt.

    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id       = iv_run_id
                it_groups       = it_groups
                iv_mode         = iv_mode
                it_lines_all    = it_lines_all
                it_pc_all       = it_pc_all
                it_step_all     = it_step_all
      IMPORTING et_msg          = et_msg
                et_log          = lt_log_run
                et_line_upd     = lt_line_upd_run
                et_posted_evt   = lt_posted_run
                et_reversed_evt = lt_reversed_run
                ev_has_error    = ev_has_error ).

    APPEND LINES OF lt_log_run      TO lcl_reing_ca_dml_buffer=>gt_log.
    APPEND LINES OF lt_line_upd_run TO lcl_reing_ca_dml_buffer=>gt_line_f4.
    APPEND LINES OF lt_posted_run   TO lcl_reing_ca_dml_buffer=>gt_posted_evt.
    APPEND LINES OF lt_reversed_run TO lcl_reing_ca_dml_buffer=>gt_reversed_evt.
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD allowed_source_status.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " DELEGADOR: la matriz CLAR-03 / SUP-01..03 vive en
    " ZCL_REING_CA_CONTAB_RUNNER, unico dueno. Mantener una copia aca la
    " haria divergir en la primera modificacion funcional -- que es
    " exactamente lo que paso con V023, cuando Post y Storno tuvieron que
    " admitir ademas su propio estado *_PROC (el que el job lee como scope).
    rt_allowed = zcl_reing_ca_contab_runner=>allowed_source_status( iv_mode ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD get_fi_poster.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " DELEGADOR: CLAR-02 exige UN solo punto de instanciacion del poster FI, y
    " ese punto es ahora ZCL_REING_CA_CONTAB_RUNNER~get_fi_poster -- alli esta
    " la nota completa sobre la frontera Cloud/Tier2 y el riesgo ATC aceptado
    " (V-03 / FUP-F4-01). Dos instanciaciones romperian justamente la
    " propiedad que CLAR-02 pide.
    ro_poster = zcl_reing_ca_contab_runner=>get_fi_poster( ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  " Begin Mod V019 (09.09.2026 | EXT_GONZALCA)
  " End Mod V019 (09.09.2026 | EXT_GONZALCA)
ENDCLASS.
" End Change ID V010 (17.07.2026 | EXT_GONZALCA)

"Begin Mod V016 (CC) - F4
" La clase de test local (include "test classes", archivo
" ZBP_ReingCARun_TEST.abap) necesita invocar run_contab_mode y
" allowed_source_status, que son PRIVATE del LHC -> friend declaration.
" DEFERRED porque el include de tests se compila despues de este.
CLASS ltcl_contab_actions DEFINITION DEFERRED FOR TESTING.
" [fix post-Eclipse, 2do intento: "DEFINITION LOAD" es obsoleta y esta
" version de ABAP la rechaza directamente ("not valid in the current ABAP
" language version"). Se descarta esa via. El problema de fondo era que el
" TEST-INJECTION (que se compila en el CONTEXTO de run_contab_mode, es decir
" DENTRO del include "implementations") referenciaba componentes estaticos
" de ltcl_contab_actions -- una clase que recien se define MAS ADELANTE, en
" el include de test (CCAU). Esa referencia hacia adelante es lo que exigia
" "DEFINITION LOAD". Solucion real: el estado del doble del Engine
" (gs_engine_result / gv_engine_raise / gv_engine_text / gv_engine_calls) se
" muda de ltcl_contab_actions a lcl_reing_ca_dml_buffer (ver PATCH 1 arriba),
" que YA esta completamente definida antes de este punto -- cero referencia
" hacia adelante, cero necesidad de DEFERRED/LOAD para este acceso. La
" FRIENDS que sigue abajo se mantiene: sigue haciendo falta para que
" ltcl_contab_actions (definida despues) pueda invocar los CLASS-METHODS
" PRIVATE de lhc_zi_reingcarun -- esa direccion NO tiene el problema de
" referencia hacia adelante (lhc_zi_reingcarun ya esta completa cuando el
" test la usa), así que DEFERRED FOR TESTING (sin LOAD) le alcanza.]
"CLASS lhc_zi_reingcarun DEFINITION INHERITING FROM cl_abap_behavior_handler.
" Begin Mod V019 (09.09.2026 | EXT_GONZALCA)
" V018 intento sumar "lsc_zi_reingcarun" a esta lista FRIENDS para que el saver
" pudiera invocar run_contab_mode. La activacion lo rechaza:
"   "Here, FRIENDS is only allowed with local DEFERRED FOR TESTING classes."
" Una clase de comportamiento RAP solo puede declarar como friend a una clase
" de test. La logica compartida entre LHC y LSC se resuelve como este include
" ya lo hacia: en lcl_reing_ca_dml_buffer, que es PUBLIC y la ven las dos --
" save_modified ya la usa para isolate_and_update_status. run_contab_mode,
" allowed_source_status y get_fi_poster se mudaron alli; aca quedan
" delegadores, para no tocar ltcl_contab_actions.
" End Mod V019 (09.09.2026 | EXT_GONZALCA)
CLASS lhc_zi_reingcarun DEFINITION INHERITING FROM cl_abap_behavior_handler
  FRIENDS ltcl_contab_actions.
"End Mod V016 (CC) - F4
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR CalcRun RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR CalcRun RESULT result.

    METHODS initializeperiod FOR MODIFY
      IMPORTING keys FOR ACTION CalcRun~InitializePeriod.

    " Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
    METHODS calculate FOR MODIFY
      IMPORTING keys FOR ACTION CalcRun~Calculate.

    METHODS check_scope
      IMPORTING iv_run_id         TYPE zreing_ca_run_a-calc_run_id
                it_groups         TYPE zreing_ca_tt_group_key
      RETURNING VALUE(rt_blocked) TYPE zreing_ca_tt_group_key.

    METHODS check_insumos
      IMPORTING iv_run_id         TYPE zreing_ca_run_a-calc_run_id
                it_groups         TYPE zreing_ca_tt_group_key
                iv_fiscal_period  TYPE zreing_ca_run_a-fiscal_period
                iv_fiscal_year    TYPE zreing_ca_run_a-fiscal_year
                it_identity_bulk  TYPE tt_identity_bulk
                it_me_metric_bulk TYPE tt_me_metric_bulk
                it_cm_bulk        TYPE tt_cm_bulk
      RETURNING VALUE(rt_errors)  TYPE tt_insumo_error.
    " End Change ID V002 (10.07.2026 | EXT_OSCUGALD)

    " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
    " Fix 002: helper DRY find-or-create del Run. Lo usan initializeperiod
    " (dormida) y calculate. CalcRunId deterministico RUN-<year><period>
    " (BR-CA-01, sin number range). want_create gobierna CU-6.
    "
    " FALLBACK (iter #5, tras fallo de activacion real EU 202 "Unable to
    " interpret FAILED"): un parametro tipado "RESPONSE FOR FAILED/REPORTED
    " LATE" NO resuelve en un metodo PRIVADO del behavior pool (mismo patron
    " ERR-007/008 que tumbo la saga original de este objeto, resuelto en el
    " intento 9 evitando pasar RESPONSE FOR ... entre metodos). Por eso
    " ensure_runs es PURO (sin EML de escritura, sin tipos derivados del BDEF).
    " Solo deriva CalcRunId, hace el SELECT de existencia bulk y DEVUELVE
    " et_run_state (cid/calc_run_id/existed + needs_create/fiscal_year/period).
    " FALLBACK iter #6 (tras fallo de activacion real EU 202 "statement before
    " CREATE not closed"): un parametro tipado "TABLE FOR CREATE zi_reingcarun"
    " TAMPOCO resuelve en la firma de un metodo de la clase local del pool (misma
    " familia que RESPONSE FOR, iter #5). Por eso ensure_runs NO devuelve el
    " payload; marca needs_create en et_run_state y CADA CALLER construye su
    " propio payload "TABLE FOR CREATE" como DATA LOCAL (ahi si es valido) y
    " ejecuta el MODIFY ENTITIES CREATE en su metodo FOR MODIFY.
    METHODS ensure_runs
      IMPORTING it_requests  TYPE tt_run_request
      EXPORTING et_run_state TYPE tt_run_state.
    " End Change ID V008 (15.07.2026 | EXT_GONZALCA)

    " Begin Change ID V003 (10.07.2026 | EXT_OSCUGALD)
    " Handler Release: transicion CALC->LIBD + registro CALCUSAGE. Sincrono.
    METHODS release FOR MODIFY
      IMPORTING keys FOR ACTION CalcRun~Release RESULT result.

    " Handler Delete: elimina grupos IS_ORPHAN. LOG/LINE/PC/STEP por SQL directo.
    METHODS delete FOR MODIFY
      IMPORTING keys FOR ACTION CalcRun~Delete RESULT result.

    " features: habilita/deshabilita Release y Delete por instancia en la UI.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR CalcRun RESULT result.

    " check_consistency_for_release: chequeo imperativo previo a Release.
    " IS_ORPHAN -> error duro. IS_STALE/receptoras -> warning (severity=warning,
    " sin %is_transition -- ese componente no existe, ver Fix 7 del addendum
    " iteracion 4; P3.3-1 sigue abierta, popup 412 sin verificar funcionalmente).
    METHODS check_consistency_for_release
      IMPORTING iv_run_id        TYPE zreing_ca_run_a-calc_run_id
                it_lines         TYPE zif_reing_ca_types=>ty_line_t
                iv_fiscal_period TYPE zreing_ca_run_a-fiscal_period
                iv_fiscal_year   TYPE zreing_ca_run_a-fiscal_year
                it_orphan_ctx    TYPE zcl_reing_ca_insumo_mgr=>tt_orphan_ctx
                it_cm_changed    TYPE zcl_reing_ca_insumo_mgr=>tt_cm_changed
                it_me_changed    TYPE zcl_reing_ca_insumo_mgr=>tt_me_changed
      EXPORTING ev_has_orphan    TYPE abap_bool
                ev_has_warning   TYPE abap_bool.

    " Begin Change ID V005 (10.07.2026 | EXT_OSCUGALD)
    " V001 (CC) - #119 (Delta v2): collection download with applied list filters.
    METHODS exportfilteredexcel FOR MODIFY
      IMPORTING keys FOR ACTION CalcRun~ExportFilteredExcel RESULT result.

    METHODS exportexcel FOR MODIFY
      IMPORTING keys FOR ACTION CalcRun~ExportExcel RESULT result.
    " End Change ID V005 (10.07.2026 | EXT_OSCUGALD)

    " Begin Change ID V016 (CC) - F4
    METHODS simulate FOR MODIFY IMPORTING keys FOR ACTION CalcRun~Simulate RESULT result.
    METHODS post     FOR MODIFY IMPORTING keys FOR ACTION CalcRun~Post     RESULT result.
    METHODS storno   FOR MODIFY IMPORTING keys FOR ACTION CalcRun~Storno   RESULT result.

    " Nucleo compartido de las 3 actions (DD-F4-4, DRY). Metodo PURO respecto
    " del BDEF: no recibe ni devuelve tipos derivados (keys/result/reported),
    " para poder probarlo con ABAP Unit sin construir payloads RAP -- mismo
    " patron que ensure_runs (V008), obligatorio en este objeto tras los
    " fallos de activacion ERR-007/008.
    " OB-003 (iteracion #2): el parametro io_engine de la iteracion #1
    " (DD-F4-7 opcion a) SE ELIMINA. ZCL_REING_CONTAB_ENGINE es
    " "DEFINITION PUBLIC FINAL CREATE PUBLIC" en el servidor real, asi que
    " cl_abap_testdouble=>create( ) sobre ella NO compila (genera una
    " subclase en runtime) y el parametro no habilitaba ningun test. El punto
    " de inyeccion pasa a ser un TEST-SEAM alrededor de la interaccion con el
    " Engine dentro de run_contab_mode (DD-F4-7 opcion b) -> la firma
    " productiva queda limpia y sin dependencia de test.
    " Begin Mod V016 (CC) - F4 [fix post-Eclipse: "Instances of the abstract
    " class LHC_ZI_REINGCARUN cannot be generated" -- el framework RAP no
    " permite "NEW lhc_zi_reingcarun( )" desde fuera del framework. Los 3
    " metodos ya eran "puros" por diseno (sin "me->", ver comentario de
    " run_contab_mode arriba) -> pasan a CLASS-METHODS: el test los invoca
    " por referencia de clase (lhc_zi_reingcarun=>...), sin instanciar nada.]
    " Begin Mod V016 (CC) - F4 [fix BUG-002 (ATC real ZMELI_CLEAN_CORE_V3,
    " "Search DB Operations in loops across modularization units", 3 Errors):
    " run_contab_mode se invoca UNA VEZ POR KEY dentro del "LOOP AT keys" de
    " simulate/post/storno, asi que sus 3 lecturas masivas (LINE_A / LPC_A /
    " STEP_A) quedaban atrapadas en una unidad de modularizacion invocada
    " repetidamente. Se hoistean al nivel de la accion -- mismo patron que ya
    " usan release/calculate (pre-lectura ANTES del LOOP AT keys, filtrado en
    " memoria adentro). run_contab_mode pasa a recibir las 3 tablas ya leidas y
    " queda con CERO SELECTs propios. Cambio de implementacion privada: el BDEF
    " y las 3 actions publicas no cambian de contrato.
    "CLASS-METHODS run_contab_mode
    "  IMPORTING iv_run_id    TYPE zreing_ca_run_a-calc_run_id
    "            it_groups    TYPE zreing_ca_tt_group_key
    "            iv_mode      TYPE zreing_ca_contab_mode
    "  EXPORTING et_msg       TYPE zif_reing_ca_types=>ty_log_t
    "            ev_has_error TYPE abap_bool.

    " Pre-lectura MASIVA unica para el conjunto COMPLETO de keys de la accion.
    " Es el unico punto con SELECTs del flujo F4 y se invoca UNA sola vez,
    " fuera del "LOOP AT keys" (BUG-002).
    CLASS-METHODS prefetch_contab_data
      IMPORTING it_run_rng TYPE lcl_reing_ca_dml_buffer=>tt_run_id_range
                it_groups  TYPE zreing_ca_tt_group_key
      EXPORTING et_lines   TYPE zif_reing_ca_types=>ty_line_t
                et_line_pc TYPE zif_reing_ca_types=>ty_line_pc_t
                et_step    TYPE zif_reing_ca_types=>ty_step_t.

    CLASS-METHODS run_contab_mode
      IMPORTING iv_run_id    TYPE zreing_ca_run_a-calc_run_id
                it_groups    TYPE zreing_ca_tt_group_key
                iv_mode      TYPE zreing_ca_contab_mode
                it_lines_all TYPE zif_reing_ca_types=>ty_line_t
                it_pc_all    TYPE zif_reing_ca_types=>ty_line_pc_t
                it_step_all  TYPE zif_reing_ca_types=>ty_step_t
      EXPORTING et_msg       TYPE zif_reing_ca_types=>ty_log_t
                ev_has_error TYPE abap_bool.
    " End Mod V016 (CC) - F4

    " Begin Mod V019 (09.09.2026 | EXT_GONZALCA)
    " get_fi_poster se mudo entero a lcl_reing_ca_dml_buffer: solo lo usaba
    " run_contab_mode, que tambien se mudo. Dejarlo aca sin llamadores solo
    " sumaria un hallazgo ATC de metodo muerto.
    " End Mod V019 (09.09.2026 | EXT_GONZALCA)

    " Estados de origen admitidos por modo (CLAR-03 / SUP-01..03).
    CLASS-METHODS allowed_source_status
      IMPORTING iv_mode           TYPE zreing_ca_contab_mode
      RETURNING VALUE(rt_allowed) TYPE lcl_reing_ca_dml_buffer=>tt_line_status_range.
    " End Mod V016 (CC) - F4
    " End Change ID V016 (CC) - F4

ENDCLASS.

" Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
CLASS lsc_zi_reingcarun DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
  PRIVATE SECTION.
    " Fix it.11 (ver iteration-log.md): el tipo "reported" de save_modified es
    " especializado internamente por el compilador para esa redefinicion
    " puntual -- no es asignable a un TYPES declarado de forma independiente
    " (aunque representen la misma estructura), ni siquiera vía CHANGING. Se
    " evita pasar "reported" entre metodos: schedule_calc_job devuelve un
    " texto de warning simple (vacio = sin problema); save_modified arma el
    " mensaje real en su propio cuerpo, donde "reported" SI tiene el tipo
    " especializado correcto de forma nativa.
    METHODS schedule_calc_job
      IMPORTING iv_run_id           TYPE zreing_ca_run_a-calc_run_id
                it_lines            TYPE tt_created_line
      EXPORTING ev_jobname          TYPE cl_apj_rt_api=>ty_jobname
      RETURNING VALUE(rv_warn_text) TYPE string.
ENDCLASS.
" End Change ID V002 (10.07.2026 | EXT_OSCUGALD)


*----------------------------------------------------------------------*
* Include: implementations (LHC handler class implementation)
*----------------------------------------------------------------------*
CLASS lhc_zi_reingcarun IMPLEMENTATION.

  METHOD get_global_authorizations.
    " V001 (CC) - provisional sin objeto PFCG propio (TR-01 pendiente, DD-B2).
    " Allow incondicional -- mismo patron ya usado en lhc_zi_reingmeheader / lhc_zi_reingctcontract2.
    " V002 (CC) - ONB-002: se elimino result-%create -- en ese momento CalcRun no
    " declaraba "create;" como operacion propia.
    " V005 (CC) - se restauro result-%create: CalcRun ahora SI declara "create;"
    " (requerido por el mecanismo interno de la factory action InitializePeriod,
    " que usa MODIFY ENTITIES ... CREATE por dentro) -- %create vuelve a ser un
    " componente valido del "result" de esta entidad.
    result-%create                  = if_abap_behv=>auth-allowed.
    result-%action-InitializePeriod = if_abap_behv=>auth-allowed.
    " Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
    " Calculate requiere autorizacion explicita para evitar denegacion silenciosa.
    result-%action-Calculate        = if_abap_behv=>auth-allowed.
    " End Change ID V002 (10.07.2026 | EXT_OSCUGALD)
    " Begin Change ID V003 (10.07.2026 | EXT_OSCUGALD)
    result-%action-Release          = if_abap_behv=>auth-allowed.
    result-%action-Delete           = if_abap_behv=>auth-allowed.
    " End Change ID V003 (10.07.2026 | EXT_OSCUGALD)
    " Begin Change ID V005 (10.07.2026 | EXT_OSCUGALD)
    " Fix (EXT_GONZALCA): faltaba autorizar ExportExcel -- mismo patron
    " provisional (sin objeto PFCG propio, TR-01 pendiente) que las demas.
    result-%action-ExportExcel      = if_abap_behv=>auth-allowed.
    " V001 (CC) - #119 (Delta v2): use the existing export authorization policy.
    result-%action-ExportFilteredExcel = if_abap_behv=>auth-allowed.
    " End Change ID V005 (10.07.2026 | EXT_OSCUGALD)
    " Begin Change ID V016 (CC) - F4
    " Esquema provisional identico al de las 6 actions ya vigentes: allow
    " incondicional sin objeto PFCG propio, porque TR-01 sigue pendiente
    " (F3.1-DD-5). Deuda: cuando TR-01 entregue ZREING_CA_FI, Post y Storno
    " son las candidatas naturales a colgar de ese rol (FUP-F4-03).
    result-%action-Simulate         = if_abap_behv=>auth-allowed.
    result-%action-Post             = if_abap_behv=>auth-allowed.
    result-%action-Storno           = if_abap_behv=>auth-allowed.
    " End Change ID V016 (CC) - F4
  ENDMETHOD.

  METHOD get_instance_authorizations.
    " V001 (CC) - provisional sin objeto PFCG propio (TR-01 pendiente, DD-B2).
    " V004 (CC) - ONB-001 (linea): %delete removido -- CalcRun nunca declara
    " delete; propio, ese componente no existe en el "result" generado.
    result = VALUE #( FOR key IN keys
      ( %tky    = key-%tky
        %update = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD initializeperiod.
    " V001 (CC) - BR-CA-01: find-or-create idempotente de CalcRun por (fiscal_year,
    " fiscal_period). CalcRunId es deterministico ('RUN-'&&fiscal_year&&fiscal_period,
    " F3.1-DD-1) -- sin number range; un INSERT duplicado del mismo periodo se trata
    " como "ya existia", nunca como error (sin ventana de carrera relevante).
    " Diseno completo: normalized-spec.md SS D (pasos 1-4), CU-1/CU-2.
    "
    " V002 (CC) - ONB-001: InitializePeriod es una factory action -- su resultado se
    " comunica exclusivamente via el parametro de respuesta MAPPED, nunca via RESULT
    " (SAP Help "Action Definition": "The result is determined via the response
    " parameter mapped. There is no result parameter", confirmado por el ejemplo
    " oficial copyTravel de /DMO/I_Travel_M, que solo llena mapped-travel a partir
    " del MAPPED del CREATE y nunca escribe en result).
    "
    " V005 (CC) - correcciones tras primer chequeo de sintaxis real:
    " (a) ENTITY zi_reingcarun -> ENTITY CalcRun (usar el alias de la behavior
    "     definition, no el nombre crudo de la entidad).
    " (b) los componentes de mapped/failed/reported pasan a usar "calcrun" (el
    "     alias en minuscula), no "zi_reingcarun".
    " (c) CreatedAt = utclong_current( ) no convertia directo a TIMESTAMPL --
    "     se usa CL_ABAP_TSTMP=>UTCLONG2TSTMP para la conversion explicita.
    "
    " V006 (CC) - todos los campos del CREATE FIELDS(...) pasaron a "readonly:update"
    " en el BDEF (no solo CalcRunId) -- ver ZI_ReingCARun.bdef V006.
    "
    " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
    " Fix 002: metodo QUEDA DORMIDO (sin boton en la toolbar UI V4, ver
    " ZC_REINGCARUN.ddlx), pero funcional. Su cuerpo se reescribe para delegar
    " en el helper DRY ensure_runs -- evita mantener 2 copias de la logica de
    " find-or-create (esta y la de calculate). Comportamiento identico al
    " anterior (find-or-create idempotente, resultado via MAPPED).
    CHECK keys IS NOT INITIAL.

    DATA lt_requests TYPE tt_run_request.
    lt_requests = VALUE #( FOR ls_key IN keys
      ( cid           = ls_key-%cid
        fiscal_year   = ls_key-%param-fiscal_year
        fiscal_period = ls_key-%param-fiscal_period
        want_create   = abap_true ) ).

    " Fallback iter #5: ensure_runs es puro y devuelve el payload; el MODIFY
    " CREATE (con failed/reported/mapped) se ejecuta AQUI, en este metodo
    " FOR MODIFY, donde esos tipos SI resuelven.
    DATA lt_state     TYPE tt_run_state.
    DATA lt_to_create TYPE TABLE FOR CREATE zi_reingcarun.
    ensure_runs(
      EXPORTING it_requests  = lt_requests
      IMPORTING et_run_state = lt_state ).

    " Payload TABLE FOR CREATE construido LOCALMENTE desde el state (needs_create).
    " El tipo derivado del BDEF es valido como DATA local de un metodo FOR MODIFY,
    " NO como parametro de metodo (fallback iter #6).
    LOOP AT lt_state INTO DATA(ls_nc) WHERE needs_create = abap_true.
      lt_to_create = VALUE #( BASE lt_to_create
        ( %cid         = ls_nc-cid
          CalcRunId    = ls_nc-calc_run_id
          FiscalYear   = ls_nc-fiscal_year
          FiscalPeriod = ls_nc-fiscal_period
          TotalLines   = 0
          TotalGroups  = 0
          CreatedBy    = sy-uname
          CreatedAt    = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) ) ).
    ENDLOOP.

    IF lt_to_create IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcarun
        ENTITY CalcRun
        CREATE FIELDS ( CalcRunId FiscalYear FiscalPeriod TotalLines TotalGroups CreatedBy CreatedAt )
        WITH lt_to_create
        MAPPED   DATA(ls_mapped)
        FAILED   DATA(ls_failed)
        REPORTED DATA(ls_reported).
      APPEND LINES OF ls_failed-calcrun   TO failed-calcrun.
      APPEND LINES OF ls_reported-calcrun TO reported-calcrun.
      " "created" = lo efectivamente persistido (via MAPPED, nunca lo fallido).
      LOOP AT ls_mapped-calcrun INTO DATA(ls_m).
        ASSIGN lt_state[ cid = ls_m-%cid ] TO FIELD-SYMBOL(<rs_ip>).
        IF sy-subrc = 0.
          <rs_ip>-created = abap_true.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Factory action: resultado exclusivamente via MAPPED. Se mapea tanto lo
    " creado como lo preexistente (idempotencia BR-CA-01, CU-2), salvo lo fallido.
    LOOP AT lt_state INTO DATA(ls_state).
      CHECK ls_state-existed = abap_true OR ls_state-created = abap_true.
      mapped-calcrun = VALUE #( BASE mapped-calcrun
        ( %cid = ls_state-cid CalcRunId = ls_state-calc_run_id ) ).
    ENDLOOP.
    " End Change ID V008 (15.07.2026 | EXT_GONZALCA)
  ENDMETHOD.

  " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
  " Fix 002: helper DRY find-or-create del Run, calcado de la logica ya probada
  " de initializeperiod (V001/BR-CA-01), generalizado con "want_create" para
  " soportar CU-6 desde calculate (no crear Run vacio si ningun grupo elegible).
  METHOD ensure_runs.
    " Metodo PURO (sin EML de escritura, sin tipos derivados del BDEF en la
    " firma). Marca needs_create en el state; el caller construye el payload
    " "TABLE FOR CREATE" local y ejecuta el MODIFY ENTITIES CREATE (fallback #6).
    CLEAR et_run_state.
    CHECK it_requests IS NOT INITIAL.

    " Step 1: derivar CalcRunId deterministico por request (ABAP puro, sin DB).
    " Se arrastran fiscal_year/period para que el caller arme el payload.
    DATA lt_state TYPE tt_run_state.
    LOOP AT it_requests INTO DATA(ls_req).
      APPEND VALUE ty_run_state(
        cid           = ls_req-cid
        calc_run_id   = COND #( WHEN ls_req-calc_run_id IS NOT INITIAL THEN ls_req-calc_run_id
          ELSE |RUN-{ ls_req-fiscal_year }{ ls_req-fiscal_period }| )
        fiscal_year   = ls_req-fiscal_year
        fiscal_period = ls_req-fiscal_period ) TO lt_state.
    ENDLOOP.

    " Step 2: find en bulk (un solo SELECT de existencia).
    SELECT calc_run_id
      FROM zreing_ca_run_a
      FOR ALL ENTRIES IN @lt_state
      WHERE calc_run_id = @lt_state-calc_run_id
      INTO TABLE @DATA(lt_existing).

    " Step 3: marcar existed; para no existentes con want_create marcar
    " needs_create, de-duplicado por CalcRunId (un solo create por periodo).
    " El caller usa needs_create para construir el payload TABLE FOR CREATE.
    LOOP AT lt_state ASSIGNING FIELD-SYMBOL(<ls_state>).
      IF line_exists( lt_existing[ calc_run_id = <ls_state>-calc_run_id ] ).
        <ls_state>-existed = abap_true.
        CONTINUE.
      ENDIF.
      READ TABLE it_requests INTO DATA(ls_r) WITH KEY cid = <ls_state>-cid.
      CHECK ls_r-want_create = abap_true.
      CHECK NOT line_exists( lt_state[ calc_run_id  = <ls_state>-calc_run_id
                                       needs_create = abap_true ] ).
      <ls_state>-needs_create = abap_true.
    ENDLOOP.

    et_run_state = lt_state.
  ENDMETHOD.
  " End Change ID V008 (15.07.2026 | EXT_GONZALCA)

  " Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
  METHOD calculate.
    " F3.2: Calculate crea LINE_A en CALC_PROC por cada grupo elegible.
    " NO agenda el APJ aca -- eso lo hace save_modified de la LSC
    " (F3.2-DD-2 corregida, blueprint SS C.2).
    " Fix (EXT_GONZALCA, iteracion 4, addendum Fix 5): "WHERE <col> IN @<itab>"
    " en un DELETE FROM exige una tabla de RANGOS (SIGN/OPTION/LOW/HIGH), no
    " una tabla plana de valores escalares -- a diferencia de SELECT, que si
    " acepta itabs planas con IN. lt_existing_nums se usa mas abajo en 3
    " DELETE FROM (step_a/lpc_a/line_a), de ahi el error real de activacion
    " "row structure incorrecta".
    "
    " Begin Change ID V025 (16.09.2026 | EXT_GONZALCA)
    " DEFECT CLASS corrected in the 9 sites marked V025 in this method --
    " state of one iteration leaking into the next one.
    "
    " (1) Five index counters of "DO lines( t ) TIMES / READ TABLE t INDEX i"
    "     filter loops were declared as "DATA i TYPE i VALUE 1" INSIDE an
    "     enclosing loop. VALUE is a declaration-time initialiser evaluated
    "     ONCE for the whole method, never per iteration, so from the second
    "     pass of the enclosing loop the counter still held lines( t ) + 1:
    "     every READ INDEX missed, the filtered table came back EMPTY and
    "     whatever depended on it silently did nothing. Declaration and
    "     assignment are now split -- the pattern lv_idx_rep, lv_idx,
    "     lv_idx_elig, lv_idx_ex, lv_idx_pend and lv_idx_fl already use in
    "     this same method.
    "
    "     Observed consequence (TS4-400, RUN-202602 / IC-0008, 16.09.2026):
    "     LV_IDX_FLT left LT_EXISTING empty for the SECOND eligible group of
    "     a single Calculate, so the recalculation RESET never ran for it --
    "     no RESET row in LOG_A, no line_num handed to GT_LINE_DEL and
    "     nothing deleted in the Save phase. The 14 previous OP_TYPE 'P'
    "     lines survived while the 14 new ones were appended at
    "     max( line_num ) + 1, leaving 14 pairs of rows that share the whole
    "     published OData key of CALineAll and make SAPUI5 reject the page
    "     with "Duplicate key predicate". OP_TYPE 'F' was the FIRST group of
    "     that same call and came out clean, which is what made the incident
    "     look like an OP_TYPE 'P' defect for two relevamientos.
    "
    " (2) Four per-key working tables were never CLEARed inside LOOP AT keys,
    "     so key N+1 still saw the rows of key N. Harmless while (1) kept
    "     those tables empty, and NOT harmless once (1) is fixed, which is
    "     why both go together: LT_EXISTING_BULK / LT_PEND_BULK are filtered
    "     by calc_run_id when they are FILLED but only by group when they are
    "     READ, so a surviving row of another run would have had its line_num
    "     pushed into GT_LINE_DEL under the WRONG calc_run_id; and
    "     LT_LOG_CALC_ALL / LT_ALL_EXISTING_NUMS are rolled up into the bulk
    "     accumulators at the end of every key, so their content was
    "     re-appended once per remaining key (duplicate LOG_A rows and
    "     duplicate delete ranges). LT_CREATE was already cleared this way --
    "     the four now follow it.
    "
    " Both defects only bite with 2+ groups or 2+ periods in one call, which
    " is why a single-group recalculation has always worked and still does.
    " End Change ID V025 (16.09.2026 | EXT_GONZALCA)
    TYPES: BEGIN OF ty_line_num_range,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE zreing_ca_line_a-line_num,
             high   TYPE zreing_ca_line_a-line_num,
           END OF ty_line_num_range,
           tt_line_num TYPE STANDARD TABLE OF ty_line_num_range WITH EMPTY KEY.
    " ATC fix (DB-in-loop): acumuladores bulk para INSERT/DELETE fuera del LOOP AT keys.
    TYPES: BEGIN OF ty_calc_run_nums,
             calc_run_id TYPE zreing_ca_run_a-calc_run_id,
             line_nums   TYPE tt_line_num,
           END OF ty_calc_run_nums.
    DATA lt_bulk_log    TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
    DATA lt_bulk_nums   TYPE STANDARD TABLE OF ty_calc_run_nums WITH EMPTY KEY.
    DATA lt_bulk_create TYPE TABLE FOR CREATE zi_reingcarun\_Line.
    DATA lt_failed_all  TYPE TABLE FOR FAILED LATE zi_reingcarun.
    DATA lt_reported_all TYPE TABLE FOR REPORTED LATE zi_reingcarun.
    " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
    " Fix 002: acumulador de requests para el find-or-create del Run (helper
    " ensure_runs). Se resuelve UNA vez, post-loop, antes del CREATE BY \_Line.
    DATA lt_run_requests TYPE tt_run_request.
    " End Change ID V008 (15.07.2026 | EXT_GONZALCA)
    CHECK keys IS NOT INITIAL.

    " ATC fix: pre-fetch RUN_CTX y MAX(line_num) en bulk antes del LOOP AT keys.
    DATA lt_run_ctx_calc TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    DATA lt_max_line_calc TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    TYPES: BEGIN OF ty_run_id_range,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE zreing_ca_run_a-calc_run_id,
             high   TYPE zreing_ca_run_a-calc_run_id,
           END OF ty_run_id_range,
           tt_run_id_range TYPE STANDARD TABLE OF ty_run_id_range WITH EMPTY KEY.
    DATA lt_run_id_range TYPE tt_run_id_range.
    " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
    " Fix 002: Calculate es static action -- las keys ya NO traen CalcRunId.
    " Se deriva CalcRunId + el contexto de periodo (fiscal_year/fiscal_period)
    " desde %param, en ABAP puro. Se ELIMINA el SELECT que llenaba
    " lt_run_ctx_calc desde zreing_ca_run_a: ese SELECT asumia el Run ya
    " persistido y devolvia vacio en CU-1 (periodo nuevo), rompiendo toda la
    " cadena de pre-fetch bulk aguas abajo (identity/me/cm quedaban vacios por
    " el guard "lt_run_ctx_calc IS NOT INITIAL" y check_insumos recibia periodo
    " en blanco). lt_run_ctx_calc se llena con el MISMO layout
    " (calc_run_id/fiscal_period/fiscal_year) para NO alterar ningun lector
    " posterior (period ranges, guards, READ TABLE por run). El SELECT de
    " MAX(line_num) SI se conserva (lee lineas reales ya persistidas; vacio
    " para periodo nuevo -> lv_next_line_num = 0).
    " V001 (CC) - GAP-001: serialize routing/allocation until RAP save/rollback.
    DATA lt_all_groups_pre TYPE zreing_ca_tt_group_key.
    DATA lt_periods TYPE lcl_reing_ca_dml_buffer=>tt_runs.
    LOOP AT keys INTO DATA(ls_key_pre).
      APPEND LINES OF ls_key_pre-%param-groups TO lt_all_groups_pre.
      APPEND VALUE #( calc_run_id = |RUN-{ ls_key_pre-%param-fiscal_year }{ ls_key_pre-%param-fiscal_period }|
        fiscal_year = ls_key_pre-%param-fiscal_year
        fiscal_period = ls_key_pre-%param-fiscal_period ) TO lt_periods.
    ENDLOOP.
    SORT lt_all_groups_pre BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_all_groups_pre COMPARING ALL FIELDS.
    SORT lt_periods BY fiscal_year fiscal_period.
    DELETE ADJACENT DUPLICATES FROM lt_periods COMPARING fiscal_year fiscal_period.
    TRY.
        DATA(lo_period_lock) = cl_abap_lock_object_factory=>get_instance( 'EZREINGCARUN' ).
        LOOP AT lt_periods INTO DATA(ls_period_lock).
          lo_period_lock->enqueue(
            it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( ls_period_lock-calc_run_id ) ) )
            _scope = if_abap_lock_object=>cs_scope-update_program ).
        ENDLOOP.
      CATCH cx_abap_foreign_lock cx_abap_lock_failure INTO DATA(lx_period_lock).
        APPEND VALUE #( %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = |No se pudo bloquear el periodo para calcular: { lx_period_lock->get_text( ) }| ) )
          TO reported-calcrun.
        RETURN.
    ENDTRY.
    DATA lt_period_runs TYPE lcl_reing_ca_dml_buffer=>tt_runs.
    IF lt_periods IS NOT INITIAL.
      SELECT * FROM zreing_ca_run_a
        FOR ALL ENTRIES IN @lt_periods
        WHERE fiscal_year = @lt_periods-fiscal_year
          AND fiscal_period = @lt_periods-fiscal_period
        INTO TABLE @lt_period_runs.
    ENDIF.
    DATA(lt_history_rng) = VALUE tt_run_id_range( FOR ls_hr IN lt_period_runs
      ( sign = 'I' option = 'EQ' low = ls_hr-calc_run_id ) ).
    DATA lt_history TYPE zif_reing_ca_types=>ty_line_t.
    IF lt_history_rng IS NOT INITIAL AND lt_all_groups_pre IS NOT INITIAL.
      " V001 (CC) - GAP-001: routing projection only; never persist these partial rows.
      SELECT calc_run_id, line_num, ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id, line_status
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_all_groups_pre
        WHERE calc_run_id IN @lt_history_rng
          AND ct_uuid = @lt_all_groups_pre-ct_uuid AND mat_uuid = @lt_all_groups_pre-mat_uuid
          AND op_type = @lt_all_groups_pre-op_type AND op_uuid = @lt_all_groups_pre-op_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_history.
    ENDIF.
    " One working key per group: preserves request contract and partitions mixed RUNs.
    TYPES: BEGIN OF ty_route_seen,
             calc_run_id TYPE zreing_calc_run_id,
             group_key TYPE zreing_ca_s_group_key,
           END OF ty_route_seen.
    DATA lt_route_seen TYPE STANDARD TABLE OF ty_route_seen WITH EMPTY KEY.
    DATA lt_work_keys LIKE keys.
    DATA lt_work_runs TYPE STANDARD TABLE OF zreing_calc_run_id WITH EMPTY KEY.
    DATA lt_new_period_runs TYPE lcl_reing_ca_dml_buffer=>tt_runs.
    LOOP AT keys INTO DATA(ls_route_key).
      DATA(lt_route_period_runs) = VALUE lcl_reing_ca_dml_buffer=>tt_runs(
        FOR ls_rr IN lt_period_runs
        WHERE ( fiscal_year = ls_route_key-%param-fiscal_year
                AND fiscal_period = ls_route_key-%param-fiscal_period ) ( ls_rr ) ).
      DATA(lt_route_rng) = VALUE tt_run_id_range( FOR ls_rp IN lt_route_period_runs
        ( sign = 'I' option = 'EQ' low = ls_rp-calc_run_id ) ).
      DATA lt_route_period_lines TYPE zif_reing_ca_types=>ty_line_t.
      CLEAR lt_route_period_lines.
      IF lt_route_rng IS NOT INITIAL.
        lt_route_period_lines = VALUE #( FOR ls_rln IN lt_history
          WHERE ( calc_run_id IN lt_route_rng ) ( ls_rln ) ).
      ENDIF.
      DATA lv_route_idx TYPE i.
      lv_route_idx = 1.
      DO lines( ls_route_key-%param-groups ) TIMES.
        READ TABLE ls_route_key-%param-groups INTO DATA(ls_route_group) INDEX lv_route_idx.
        lv_route_idx = lv_route_idx + 1.
        DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
          is_group = ls_route_group iv_year = ls_route_key-%param-fiscal_year
          iv_period = ls_route_key-%param-fiscal_period it_lines = lt_route_period_lines ).
        IF ls_choice-fresh = abap_true.
          READ TABLE lt_new_period_runs INTO DATA(ls_new_run)
            WITH KEY fiscal_year = ls_route_key-%param-fiscal_year
                     fiscal_period = ls_route_key-%param-fiscal_period.
          IF sy-subrc = 0.
            ls_choice-calc_run_id = ls_new_run-calc_run_id.
          ELSE.
            ls_choice = lcl_reing_ca_dml_buffer=>next_calc_run(
              iv_year = ls_route_key-%param-fiscal_year
              iv_period = ls_route_key-%param-fiscal_period it_runs = lt_period_runs ).
            IF ls_choice-message IS INITIAL.
              APPEND VALUE #( calc_run_id = ls_choice-calc_run_id
                fiscal_year = ls_route_key-%param-fiscal_year
                fiscal_period = ls_route_key-%param-fiscal_period ) TO lt_new_period_runs.
            ENDIF.
          ENDIF.
        ENDIF.
        IF ls_choice-message IS NOT INITIAL.
          APPEND VALUE #( %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error text = ls_choice-message ) ) TO reported-calcrun.
          CONTINUE.
        ENDIF.
        IF line_exists( lt_route_seen[
            calc_run_id = ls_choice-calc_run_id group_key = ls_route_group ] ).
          CONTINUE.
        ENDIF.
        APPEND VALUE #( calc_run_id = ls_choice-calc_run_id group_key = ls_route_group ) TO lt_route_seen.
        DATA(ls_work_key) = ls_route_key.
        ls_work_key-%param-groups = VALUE #( ( ls_route_group ) ).
        APPEND ls_work_key TO lt_work_keys.
        APPEND ls_choice-calc_run_id TO lt_work_runs.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_choice-calc_run_id ) TO lt_run_id_range.
        IF NOT line_exists( lt_run_ctx_calc[ calc_run_id = ls_choice-calc_run_id ] ).
          APPEND VALUE #( calc_run_id = ls_choice-calc_run_id
            fiscal_year = ls_route_key-%param-fiscal_year
            fiscal_period = ls_route_key-%param-fiscal_period ) TO lt_run_ctx_calc.
        ENDIF.
      ENDDO.
    ENDLOOP.
    CHECK lt_work_keys IS NOT INITIAL.
    IF lt_run_id_range IS NOT INITIAL.
      SELECT calc_run_id, MAX( line_num ) AS line_num
        FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_id_range
        GROUP BY calc_run_id
        INTO CORRESPONDING FIELDS OF TABLE @lt_max_line_calc.
    ENDIF.
    " End Change ID V008 (15.07.2026 | EXT_GONZALCA)

    " ATC fix (DB-in-loop): pre-cargar lt_existing_bulk y lt_pend_bulk en bulk
    " ANTES del LOOP AT keys usando TODOS los grupos de todos los keys como driver.
    " Dentro del loop se filtra en memoria por calc_run_id + grupo.
    DATA lt_existing_bulk_global TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    DATA lt_pend_bulk_global     TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.


    " V001 (CC) - B2 PEND is virtual: pre-load its rows by group and period.
    TYPES: BEGIN OF ty_b2_driver,
             ct_uuid      TYPE zreing_ca_line_a-ct_uuid,
             mat_uuid     TYPE zreing_ca_line_a-mat_uuid,
             op_type      TYPE zreing_ca_line_a-op_type,
             op_uuid      TYPE zreing_ca_line_a-op_uuid,
             cm_h_id      TYPE zreing_ca_line_a-cm_h_id,
             period_year  TYPE zreing_ca_run_a-fiscal_year,
             period_month TYPE zreing_ca_run_a-fiscal_period,
           END OF ty_b2_driver,
           tt_b2_driver TYPE STANDARD TABLE OF ty_b2_driver WITH EMPTY KEY.
    DATA lt_b2_driver TYPE tt_b2_driver.
    LOOP AT keys INTO DATA(ls_key_b2).
      APPEND LINES OF VALUE tt_b2_driver(
        FOR ls_group_b2 IN ls_key_b2-%param-groups
        ( ct_uuid      = ls_group_b2-ct_uuid
          mat_uuid     = ls_group_b2-mat_uuid
          op_type      = ls_group_b2-op_type
          op_uuid      = ls_group_b2-op_uuid
          cm_h_id      = ls_group_b2-cm_h_id
          period_year  = ls_key_b2-%param-fiscal_year
          period_month = ls_key_b2-%param-fiscal_period ) ) TO lt_b2_driver.
    ENDLOOP.
    SORT lt_b2_driver BY ct_uuid mat_uuid op_type op_uuid cm_h_id period_year period_month.
    DELETE ADJACENT DUPLICATES FROM lt_b2_driver COMPARING ALL FIELDS.

    DATA lt_b2_virtual_global TYPE STANDARD TABLE OF zi_reingcalineall WITH EMPTY KEY.
    IF lt_b2_driver IS NOT INITIAL.
      SELECT *
        FROM ZI_ReingCALineAll AS b2
        FOR ALL ENTRIES IN @lt_b2_driver
        WHERE b2~CtUuid      = @lt_b2_driver-ct_uuid
          AND b2~MatUuid     = @lt_b2_driver-mat_uuid
          AND b2~OpType      = @lt_b2_driver-op_type
          AND b2~OpUuid      = @lt_b2_driver-op_uuid
          AND b2~CmHId       = @lt_b2_driver-cm_h_id
          AND b2~PeriodYear  = @lt_b2_driver-period_year
          AND b2~PeriodMonth = @lt_b2_driver-period_month
          AND b2~RowType     = 'B2'
          AND b2~LineStatus  = 'PEND'
        INTO TABLE @lt_b2_virtual_global.
    ENDIF.
    IF lt_all_groups_pre IS NOT INITIAL AND lt_run_id_range IS NOT INITIAL.
      SELECT *
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_all_groups_pre
        WHERE calc_run_id IN @lt_run_id_range
          AND ct_uuid     = @lt_all_groups_pre-ct_uuid
          AND mat_uuid    = @lt_all_groups_pre-mat_uuid
          AND op_type     = @lt_all_groups_pre-op_type
          AND op_uuid     = @lt_all_groups_pre-op_uuid
          AND cm_h_id     = @lt_all_groups_pre-cm_h_id
          AND line_status <> @space
          " V001 (CC) - #105: RESET never deletes cancelled audit rows.
          AND line_status <> @zif_reing_ca_c=>line_status-anuld
        INTO CORRESPONDING FIELDS OF TABLE @lt_existing_bulk_global.
      SELECT calc_run_id, line_num, op_instance_num, bukrs_recv, ct_uuid, mat_uuid, op_type, op_uuid,
             cm_h_id, cm_load_seq, is_delta, delta_seq
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_all_groups_pre
        WHERE ct_uuid      = @lt_all_groups_pre-ct_uuid
          AND mat_uuid     = @lt_all_groups_pre-mat_uuid
          AND op_type      = @lt_all_groups_pre-op_type
          AND op_uuid      = @lt_all_groups_pre-op_uuid
          AND cm_h_id      = @lt_all_groups_pre-cm_h_id
          AND line_status  = 'PEND'
        INTO CORRESPONDING FIELDS OF TABLE @lt_pend_bulk_global.
    ENDIF.

    " ATC fix (NonLocal DBREAD via check_scope): pre-cargar lt_blocked_global
    " con el SELECT de check_scope en bulk ANTES del LOOP AT keys.
    " Dentro del loop se filtra en memoria por calc_run_id + grupo.
    DATA lt_blocked_global TYPE zreing_ca_tt_group_key.
    IF lt_all_groups_pre IS NOT INITIAL AND lt_run_id_range IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_all_groups_pre
        WHERE calc_run_id IN @lt_run_id_range
          AND ct_uuid   = @lt_all_groups_pre-ct_uuid
          AND mat_uuid  = @lt_all_groups_pre-mat_uuid
          AND op_type   = @lt_all_groups_pre-op_type
          AND op_uuid   = @lt_all_groups_pre-op_uuid
          AND cm_h_id   = @lt_all_groups_pre-cm_h_id
          AND line_status IN ( 'CALC_PROC', 'SIM_PROC', 'POST_PROC', 'ANUL_PROC', 'ANUL_ERR' )
        INTO CORRESPONDING FIELDS OF TABLE @lt_blocked_global.
      SORT lt_blocked_global. DELETE ADJACENT DUPLICATES FROM lt_blocked_global COMPARING ALL FIELDS.
    ENDIF.

    " ATC fix (NonLocal DBREAD via check_insumos): pre-cargar identidades de contrato
    " Y metricas ME en un solo SELECT con JOIN -- elimina el segundo SELECT separado
    " (que usaba lt_identity_bulk_global como driver) detectado por el check TRANSFORM.
    DATA lt_identity_bulk_global TYPE tt_identity_bulk.
    DATA lt_me_metric_bulk_global TYPE tt_me_metric_bulk.
    IF lt_all_groups_pre IS NOT INITIAL AND lt_run_ctx_calc IS NOT INITIAL.
      DATA lt_period_year_range  TYPE RANGE OF zreing_me_h_a-period_year.
      DATA lt_period_month_range TYPE RANGE OF zreing_me_h_a-period_month.
      LOOP AT lt_run_ctx_calc INTO DATA(ls_ctx_me).
        IF NOT line_exists( lt_period_year_range[ low = ls_ctx_me-fiscal_year ] ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_ctx_me-fiscal_year  ) TO lt_period_year_range.
        ENDIF.
        IF NOT line_exists( lt_period_month_range[ low = ls_ctx_me-fiscal_period ] ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_ctx_me-fiscal_period ) TO lt_period_month_range.
        ENDIF.
      ENDLOOP.
      " Begin Insert V025 (16.09.2026 | EXT_GONZALCA) - bug tracker #74, 2da mitad
      " Este pre-fetch leia ZREING_ME_H_A con el periodo del RUN y SIN
      " ME_PERIOD_OFFSET (BR-CA-40). Como el JOIN contra ME es INNER, un
      " contrato cuya metrica vive en M-1 desaparecia del resultado entero y
      " check_insumos lo rechazaba con "Contrato/material inexistente" -- un
      " mensaje que apunta al dato equivocado: el contrato y el material SI
      " existen, lo que falta es la metrica del periodo mal calculado.
      " Reportado desde TS4-400 el 16.09.2026 con IC-0015 (operacion F,
      " ME_PERIOD_OFFSET = '01', unico ME_H_A en LIBD para 2026/01) sobre el
      " run de 02/2026: el contrato aparecia en la lista como PEND -- eso ya
      " lo habia corregido fixes-029 en ZI_ReingCALineAll -- pero Calcular lo
      " rechazaba. O sea que #74 habia quedado cerrado a medias: se arreglo
      " la vista y no el handler.
      " Los rangos de arriba NO se tocan: los sigue usando el pre-fetch de CM
      " unas lineas mas abajo, y ahi el periodo del run es el correcto -- el
      " offset aplica SOLO a la metrica (ver la nota de ALCANCE en
      " ZCL_REING_CA_PIPELINE~resolve_me_period).
      " El periodo se resuelve POR GRUPO porque ME_PERIOD_OFFSET vive en la
      " OPERACION (ZREING_CT2_OPT_A por OP_UUID) y dos grupos del mismo run
      " pueden tener offsets distintos. Por eso tampoco alcanzaba con sumar
      " meses al rango: "year IN {2026} + month IN {01,02}" tambien casaria
      " (2026,01) para un contrato con offset '00' y podria traer la metrica
      " del periodo equivocado. La tabla driver compara el par exacto.
      " La aritmetica se delega en ZCL_REING_CA_SOURCES=>CALC_ME_PERIOD, la
      " MISMA que usan el pipeline y ZCL_REING_CA_INSUMO_MGR: tres puntos de
      " lectura, una sola regla de rollover de anio.
      TYPES: BEGIN OF ty_me_offset,
               op_uuid          TYPE zreing_ct2_opt_a-op_uuid,
               me_period_offset TYPE zreing_ct2_opt_a-me_period_offset,
             END OF ty_me_offset.
      DATA lt_me_offset TYPE STANDARD TABLE OF ty_me_offset WITH EMPTY KEY.
      SELECT op_uuid, me_period_offset
        FROM zreing_ct2_opt_a
        FOR ALL ENTRIES IN @lt_all_groups_pre
        WHERE op_uuid = @lt_all_groups_pre-op_uuid
        INTO CORRESPONDING FIELDS OF TABLE @lt_me_offset.

      TYPES: BEGIN OF ty_me_pair,
               ct_uuid       TYPE zreing_ct2_a-ct_uuid,
               mat_uuid      TYPE zreing_ct2_mat_a-mat_uuid,
               op_uuid       TYPE zreing_ct2_opt_a-op_uuid,
               fiscal_year   TYPE zreing_ca_run_a-fiscal_year,
               fiscal_period TYPE zreing_ca_run_a-fiscal_period,
             END OF ty_me_pair,
             tt_me_pair TYPE STANDARD TABLE OF ty_me_pair WITH EMPTY KEY.
      TYPES: BEGIN OF ty_me_driver,
               ct_uuid         TYPE zreing_ct2_a-ct_uuid,
               mat_uuid        TYPE zreing_ct2_mat_a-mat_uuid,
               me_period_year  TYPE zreing_me_h_a-period_year,
               me_period_month TYPE zreing_me_h_a-period_month,
             END OF ty_me_driver.
      DATA lt_me_driver TYPE STANDARD TABLE OF ty_me_driver WITH EMPTY KEY.
      " ATC (Loops anidados, ZMELI_CLEAN_CORE): el producto grupo x contexto
      " se arma con DOS clausulas FOR de una misma table comprehension -- una
      " sola sentencia, sin LOOP anidado -- y despues se recorre con un unico
      " DO TIMES + READ INDEX.
      " LT_ME_DRIVER no puede quedar vacio: el IF que abre este bloque ya
      " garantiza que LT_ALL_GROUPS_PRE y LT_RUN_CTX_CALC tienen filas, y el
      " producto de dos tablas no vacias tampoco lo esta. Por eso el
      " FOR ALL ENTRIES de mas abajo no necesita guard propio.
      DATA(lt_me_pair) = VALUE tt_me_pair(
        FOR ls_g_me IN lt_all_groups_pre
        FOR ls_c_me IN lt_run_ctx_calc
        ( ct_uuid       = ls_g_me-ct_uuid
          mat_uuid      = ls_g_me-mat_uuid
          op_uuid       = ls_g_me-op_uuid
          fiscal_year   = ls_c_me-fiscal_year
          fiscal_period = ls_c_me-fiscal_period ) ).
      DATA ls_pair_me LIKE LINE OF lt_me_pair.
      DATA lv_idx_me  TYPE i.
      DATA lv_me_y_pre TYPE zreing_me_h_a-period_year.
      DATA lv_me_m_pre TYPE zreing_me_h_a-period_month.
      lv_idx_me = 1.
      DO lines( lt_me_pair ) TIMES.
        READ TABLE lt_me_pair INTO ls_pair_me INDEX lv_idx_me.
        lv_idx_me = lv_idx_me + 1.
        " Sin fila en CT2_OPT_A el offset queda inicial ('00'), que es
        " exactamente el comportamiento anterior: periodo del run.
        DATA(lv_off_me) = VALUE zreing_ct2_opt_a-me_period_offset(
                            lt_me_offset[ op_uuid = ls_pair_me-op_uuid ]-me_period_offset OPTIONAL ).
        zcl_reing_ca_sources=>calc_me_period(
          EXPORTING iv_offset       = lv_off_me
                    iv_period       = ls_pair_me-fiscal_period
                    iv_year         = ls_pair_me-fiscal_year
          IMPORTING ev_period_month = lv_me_m_pre
                    ev_period_year  = lv_me_y_pre ).
        IF NOT line_exists( lt_me_driver[ ct_uuid         = ls_pair_me-ct_uuid
                                          mat_uuid        = ls_pair_me-mat_uuid
                                          me_period_year  = lv_me_y_pre
                                          me_period_month = lv_me_m_pre ] ).
          APPEND VALUE ty_me_driver( ct_uuid         = ls_pair_me-ct_uuid
                                     mat_uuid        = ls_pair_me-mat_uuid
                                     me_period_year  = lv_me_y_pre
                                     me_period_month = lv_me_m_pre ) TO lt_me_driver.
        ENDIF.
      ENDDO.
      " End Insert V025 (16.09.2026 | EXT_GONZALCA)
      " JOIN entre ct2_a, ct2_mat_a y me_h_a para un solo SELECT.
      " lt_identity_bulk_global y lt_me_metric_bulk_global se llenan en memoria desde el resultado.
      " Begin Change ID V014 (17.07.2026 | EXT_GONZALCA)
      " Fix: mismo defecto de raiz ya corregido en ZCL_REING_CA_SOURCES
      " (get_me_shares/get_me_metric) -- mas de un header ZREING_ME_H_A
      " puede quedar en LIBD para el mismo ct_id/matnr/periodo, con
      " distinto load_version. Este JOIN traia el metric_code/met_version
      " de CUALQUIERA de esas versiones (el primero que aparecia en el
      " result set, sin orden garantizado) en vez de la version vigente
      " (MAX load_version). Se agrega load_version al SELECT y se ordena
      " DESC antes de deduplicar mas abajo, para que el primer row
      " encontrado por (ct_uuid, mat_uuid) sea siempre el de mayor
      " load_version -- mismo patron que ZBP_REINGMEHEADER.
      TYPES: BEGIN OF ty_join_result,
               ct_uuid      TYPE zreing_ct2_a-ct_uuid,
               mat_uuid     TYPE zreing_ct2_mat_a-mat_uuid,
               ct_id        TYPE zreing_ct2_a-ct_id,
               lifnr        TYPE zreing_ct2_a-lifnr,
               bukrs_prest  TYPE zreing_ct2_a-bukrs,
               matnr        TYPE zreing_ct2_mat_a-matnr,
               metric_code  TYPE zreing_me_h_a-metric_code,
               met_version  TYPE zreing_me_h_a-met_version,
               load_version TYPE zreing_me_h_a-load_version,
             END OF ty_join_result.
      DATA lt_join_result TYPE STANDARD TABLE OF ty_join_result WITH EMPTY KEY.
      SELECT ct~ct_uuid, mat~mat_uuid,
             ct~ct_id, ct~lifnr, ct~bukrs AS bukrs_prest, mat~matnr,
             me~metric_code, me~met_version, me~load_version
        FROM zreing_ct2_a AS ct
        INNER JOIN zreing_ct2_mat_a AS mat ON mat~ct_uuid = ct~ct_uuid
        INNER JOIN zreing_me_h_a AS me ON  me~ct_id = ct~ct_id
                                       AND me~matnr  = mat~matnr
        " Begin Mod V025 (16.09.2026 | EXT_GONZALCA) - bug tracker #74, 2da mitad
        " El driver reemplaza a LT_ALL_GROUPS_PRE + los dos rangos de periodo:
        " trae el par (ct_uuid, mat_uuid) junto con el periodo ME ya resuelto
        " con ME_PERIOD_OFFSET, y la comparacion pasa de IN a igualdad exacta.
        " Clausulas originales, para el registro:
        "        FOR ALL ENTRIES IN @lt_all_groups_pre
        "        WHERE ct~ct_uuid   = @lt_all_groups_pre-ct_uuid
        "          AND mat~mat_uuid = @lt_all_groups_pre-mat_uuid
        "          AND me~period_year  IN @lt_period_year_range
        "          AND me~period_month IN @lt_period_month_range
        FOR ALL ENTRIES IN @lt_me_driver
        WHERE ct~ct_uuid   = @lt_me_driver-ct_uuid
          AND mat~mat_uuid = @lt_me_driver-mat_uuid
          AND me~period_year  = @lt_me_driver-me_period_year
          AND me~period_month = @lt_me_driver-me_period_month
        " End Mod V025 (16.09.2026 | EXT_GONZALCA)
          AND me~me_status    = @zif_reing_ca_c=>me_eligible_status-libd
        INTO CORRESPONDING FIELDS OF TABLE @lt_join_result.
      SORT lt_join_result BY ct_uuid mat_uuid load_version DESCENDING.
      " End Change ID V014 (17.07.2026 | EXT_GONZALCA)
      " Separar en las dos tablas en ABAP puro.
      DATA ls_jr LIKE LINE OF lt_join_result.
      DATA lv_idx_jr TYPE i VALUE 1.
      DO lines( lt_join_result ) TIMES.
        READ TABLE lt_join_result INTO ls_jr INDEX lv_idx_jr.
        IF NOT line_exists( lt_identity_bulk_global[
            ct_uuid = ls_jr-ct_uuid mat_uuid = ls_jr-mat_uuid ] ).
          APPEND VALUE ty_identity_bulk(
            ct_uuid     = ls_jr-ct_uuid
            mat_uuid    = ls_jr-mat_uuid
            ct_id       = ls_jr-ct_id
            lifnr       = ls_jr-lifnr
            bukrs_prest = ls_jr-bukrs_prest
            matnr       = ls_jr-matnr ) TO lt_identity_bulk_global.
        ENDIF.
        IF NOT line_exists( lt_me_metric_bulk_global[
            ct_id = ls_jr-ct_id matnr = ls_jr-matnr ] ).
          APPEND VALUE ty_me_metric_bulk(
            ct_id       = ls_jr-ct_id
            matnr       = ls_jr-matnr
            metric_code = ls_jr-metric_code
            met_version = ls_jr-met_version ) TO lt_me_metric_bulk_global.
        ENDIF.
        lv_idx_jr = lv_idx_jr + 1.
      ENDDO.
    ENDIF.

    " ATC fix (NonLocal DBREAD via get_cm_amount en check_insumos): pre-cargar
    " CM_H_A elegibles para todos los grupos del scope ANTES del LOOP AT keys.
    " Driver: lt_all_groups_pre (ct_uuid + mat_uuid + op_type ya disponibles).
    " Solo necesitamos la clave de grupo para verificar existencia en check_insumos.
    DATA lt_cm_bulk_global TYPE tt_cm_bulk.
    IF lt_all_groups_pre IS NOT INITIAL AND lt_run_ctx_calc IS NOT INITIAL.
      SELECT ct_uuid, mat_uuid, op_type, cm_h_id, load_seq, delta_flag
        FROM zreing_cm_h_a
        FOR ALL ENTRIES IN @lt_all_groups_pre
        WHERE ct_uuid      = @lt_all_groups_pre-ct_uuid
          AND mat_uuid     = @lt_all_groups_pre-mat_uuid
          AND op_type      = @lt_all_groups_pre-op_type
          AND cm_h_id      = @lt_all_groups_pre-cm_h_id
          AND period_year  IN @lt_period_year_range
          AND period_month IN @lt_period_month_range
          AND cm_status    = 'LIBD'
        INTO CORRESPONDING FIELDS OF TABLE @lt_cm_bulk_global.
    ENDIF.

    " ATC fix (NonLocal DBREAD via zcl_reing_ca_optype_factory=>get_instance en loop):
    " pre-cargar gt_cache de la factory con todos los op_types del scope ANTES del
    " LOOP AT keys. get_instance encontrara las entradas en cache y no ejecutara
    " SELECT SINGLE zreing_op_type_c dentro del DO TIMES anidado.
    DATA lt_op_type_rang_calc TYPE zcl_reing_ca_optype_factory=>ty_op_type_rang.
    DATA ls_grp_op_calc LIKE LINE OF lt_all_groups_pre.
    DATA lv_idx_op_calc TYPE i VALUE 1.
    DO lines( lt_all_groups_pre ) TIMES.
      READ TABLE lt_all_groups_pre INTO ls_grp_op_calc INDEX lv_idx_op_calc.
      IF NOT line_exists( lt_op_type_rang_calc[ low = ls_grp_op_calc-op_type ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_grp_op_calc-op_type ) TO lt_op_type_rang_calc.
      ENDIF.
      lv_idx_op_calc = lv_idx_op_calc + 1.
    ENDDO.
    IF lt_op_type_rang_calc IS NOT INITIAL.
      TRY.
          zcl_reing_ca_optype_factory=>warm_cache( lt_op_type_rang_calc ).
        CATCH zcx_reing_ca_calc_error.
          " warm_cache solo falla si ningun op_type es valido -- lo detectara
          " get_instance por key y reportara el error alli con el contexto correcto.
      ENDTRY.
    ENDIF.

    DATA lv_work_index TYPE i.
    LOOP AT lt_work_keys INTO DATA(ls_key).
      lv_work_index = lv_work_index + 1.
      " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
      " Fix 002: CalcRunId derivado de %param (ya no viene en la clave de la
      " static action). Reemplaza cada lectura de ls_key-CalcRunId de este loop.
      " Fix 002 (it7): tipado explicito CHAR20 (no string inferido) -> compatible
      " con iv_run_id / calc_run_id sin CONV en ningun call site.
      DATA lv_calc_run_id TYPE zreing_ca_run_a-calc_run_id.
      lv_calc_run_id = lt_work_runs[ lv_work_index ].
      " End Change ID V008 (15.07.2026 | EXT_GONZALCA)
      DATA lt_blocked TYPE zreing_ca_tt_group_key.
      CLEAR lt_blocked.
      DATA ls_blk_g LIKE LINE OF lt_blocked_global.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defect (1) -- ver la nota de cabecera de este metodo. Aqui el sintoma
      " era otro: desde el SEGUNDO key de un bulk multi-periodo, LT_BLOCKED
      " quedaba vacio y el guard de concurrencia dejaba de bloquear grupos
      " que ya estaban en *_PROC.
      " Linea original: DATA lv_idx_blk TYPE i VALUE 1.
      DATA lv_idx_blk TYPE i.
      lv_idx_blk = 1.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      DO lines( lt_blocked_global ) TIMES.
        READ TABLE lt_blocked_global INTO ls_blk_g INDEX lv_idx_blk.
        " Solo incluir grupos que pertenecen al scope de este key (calc_run_id no
        " está en zreing_ca_tt_group_key, se filtra por pertenencia al key actual).
        IF line_exists( ls_key-%param-groups[ ct_uuid = ls_blk_g-ct_uuid
                                              mat_uuid = ls_blk_g-mat_uuid
                                              op_type  = ls_blk_g-op_type
                                              op_uuid  = ls_blk_g-op_uuid
                                              cm_h_id  = ls_blk_g-cm_h_id ] ).
          APPEND ls_blk_g TO lt_blocked.
        ENDIF.
        lv_idx_blk = lv_idx_blk + 1.
      ENDDO.
      " ATC fix: pasar todos los pre-fetches a check_insumos (CERO SELECTs dentro).
      " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
      " Fix 002: iv_run_id desde lv_calc_run_id derivado; fiscal_period/year
      " desde %param (fuente directa, ya no via ls_run_ctx_chk que dependia del
      " Run persistido). Firma de check_insumos INTACTA (7 params, pre-fetch
      " bulk it_identity_bulk/it_me_metric_bulk/it_cm_bulk preservado -- OB-002).
      DATA(lt_ins_errors) = check_insumos(
        iv_run_id         = lv_calc_run_id
        it_groups         = ls_key-%param-groups
        iv_fiscal_period  = ls_key-%param-fiscal_period
        iv_fiscal_year    = ls_key-%param-fiscal_year
        it_identity_bulk  = lt_identity_bulk_global
        it_me_metric_bulk = lt_me_metric_bulk_global
        it_cm_bulk        = lt_cm_bulk_global ).
      " End Change ID V008 (15.07.2026 | EXT_GONZALCA)

      " ATC fix: DO TIMES en lugar de LOOP para reportar errores (nested loop).
      DATA lv_idx_rep TYPE i.
      lv_idx_rep = 1.
      DO lines( lt_blocked ) TIMES.
        READ TABLE lt_blocked INTO DATA(ls_blocked_rep) INDEX lv_idx_rep.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " 65 caracteres: el operador leia "Hay una operacion en curso para este
        " grupo, espere a q".
        APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_calc_run_id ) %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = 'Hay una operacion en curso para este grupo, espere a que finalice' ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        lv_idx_rep = lv_idx_rep + 1.
      ENDDO.
      lv_idx_rep = 1.
      DO lines( lt_ins_errors ) TIMES.
        READ TABLE lt_ins_errors INTO DATA(ls_ins_error_rep) INDEX lv_idx_rep.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " Mensaje de longitud variable que viene de check_insumos: nombra el
        " insumo faltante y el grupo, asi que el corte a 50 lo hacia inutil.
        APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_calc_run_id ) %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = ls_ins_error_rep-message ) ) TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        lv_idx_rep = lv_idx_rep + 1.
      ENDDO.

      DATA(lt_eligible) = ls_key-%param-groups.
      " ATC fix: DO TIMES en lugar de LOOP para evitar nested loop detection.
      DATA ls_blocked   LIKE LINE OF lt_blocked.
      DATA ls_ins_error LIKE LINE OF lt_ins_errors.
      DATA lv_idx TYPE i.
      lv_idx = 1.
      DO lines( lt_blocked ) TIMES.
        READ TABLE lt_blocked INTO ls_blocked INDEX lv_idx.
        DELETE lt_eligible WHERE ct_uuid = ls_blocked-ct_uuid AND mat_uuid = ls_blocked-mat_uuid
                             AND op_type = ls_blocked-op_type AND op_uuid  = ls_blocked-op_uuid
                             AND cm_h_id = ls_blocked-cm_h_id.
        lv_idx = lv_idx + 1.
      ENDDO.
      lv_idx = 1.
      DO lines( lt_ins_errors ) TIMES.
        READ TABLE lt_ins_errors INTO ls_ins_error INDEX lv_idx.
        DELETE lt_eligible WHERE ct_uuid = ls_ins_error-group-ct_uuid AND mat_uuid = ls_ins_error-group-mat_uuid
                             AND op_type = ls_ins_error-group-op_type AND op_uuid  = ls_ins_error-group-op_uuid
                             AND cm_h_id = ls_ins_error-group-cm_h_id.
        lv_idx = lv_idx + 1.
      ENDDO.

      " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
      " Fix 002 CU-6: acumular el request de find-or-create para este key.
      " want_create = X solo si sobrevivio >=1 grupo elegible tras los guards
      " -- un Run nunca se crea vacio. El $self de cada key se decide DESPUES
      " del loop segun el estado real devuelto por ensure_runs (existed/created),
      " nunca antes (no se devuelve la clave de un recurso no persistido). Esto
      " reemplaza el "result siempre $self" anterior (baseline instance-bound).
      APPEND VALUE ty_run_request(
        cid           = |{ ls_key-%cid }-{ lv_calc_run_id }|
        calc_run_id   = lv_calc_run_id
        fiscal_year   = ls_key-%param-fiscal_year
        fiscal_period = ls_key-%param-fiscal_period
        want_create   = xsdbool( lt_eligible IS NOT INITIAL ) ) TO lt_run_requests.
      IF lt_eligible IS INITIAL. CONTINUE. ENDIF.
      " End Change ID V008 (15.07.2026 | EXT_GONZALCA)

      " ATC fix: leer RUN_CTX y MAX(line_num) desde tablas pre-cargadas (bulk).
      DATA ls_run_ctx TYPE zreing_ca_run_a.
      CLEAR ls_run_ctx.
      READ TABLE lt_run_ctx_calc INTO ls_run_ctx
        WITH KEY calc_run_id = lv_calc_run_id.
      " Begin Mod V024 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
      " LINE_NUM se numera POR RUN (ver V017) y su maximo vive en
      " LT_MAX_LINE_CALC, pre-cargado UNA sola vez ANTES del LOOP AT keys.
      " Hasta V023 este bloque COPIABA ese maximo a LV_NEXT_LINE_NUM en cada
      " key y nunca le devolvia el valor ya consumido, asi que dos keys del
      " MISMO run arrancaban del mismo numero: LineNum y %cid duplicados en
      " el unico "CREATE BY \_Line" de mas abajo -> CREATE fallido completo
      " -> CREATE-CALCLINE vacio en la fase Save -> RETURN silencioso antes
      " de SCHEDULE_CALC_JOB. Sin job, sin mensaje y sin rastro en LOG_A: es
      " el bug #77 ("con mas de una linea no se dispara el job"). El V008
      " cubrio la colision ENTRE PERIODOS DISTINTOS (prefijo del %cid) y dejo
      " abierta la del MISMO periodo, que es justamente la que ve el usuario
      " -- todos los grupos del dialogo son del periodo filtrado en pantalla.
      " Ahora la fila de LT_MAX_LINE_CALC es la marca de agua VIVA del run:
      " se accede por field-symbol y se actualiza en cada incremento, de modo
      " que el contador sobrevive al cambio de key sin depender de ningun
      " camino de salida del loop (hay un CONTINUE mas abajo, en el TRY de
      " LV_GROUP_RUN_ID). Con un solo key el comportamiento es identico al
      " anterior. Lineas originales conservadas como referencia:
      "    DATA lv_next_line_num TYPE zreing_ca_line_a-line_num.
      "    READ TABLE lt_max_line_calc INTO DATA(ls_max_line)
      "      WITH KEY calc_run_id = lv_calc_run_id.
      "    IF sy-subrc = 0.
      "      lv_next_line_num = ls_max_line-line_num.
      "    ENDIF.
      DATA lv_next_line_num TYPE zreing_ca_line_a-line_num.
      READ TABLE lt_max_line_calc ASSIGNING FIELD-SYMBOL(<ls_hwm>)
        WITH KEY calc_run_id = lv_calc_run_id.
      IF sy-subrc <> 0.
        " Run sin lineas persistidas (periodo nuevo): la marca arranca en 0.
        APPEND VALUE #( calc_run_id = lv_calc_run_id line_num = 0 )
          TO lt_max_line_calc.
        READ TABLE lt_max_line_calc ASSIGNING <ls_hwm>
          WITH KEY calc_run_id = lv_calc_run_id.
      ENDIF.
      lv_next_line_num = <ls_hwm>-line_num.
      " End Mod V024 (16.09.2026 | EXT_GONZALCA)

      " Fix (EXT_GONZALCA, iteracion 4, addendum Fix 8, no bloqueante -- warning
      " real): CX_UUID_ERROR de create_uuid_x16_static() no estaba capturada
      " ni declarada en RAISING. Se resuelve con TRY/CATCH local (agregar
      " RAISING a la firma de "calculate" no es practicable: es un metodo de
      " framework RAP -- handler FOR MODIFY -- cuya firma no es libre de
      " modificar). lv_group_run_id se declara ANTES del TRY porque una
      " DATA(...) inline dentro de TRY...ENDTRY pierde su alcance al llegar a
      " ENDTRY, y se necesita mas abajo dentro del LOOP AT lt_eligible.
      DATA lv_group_run_id TYPE string.
      TRY.
          lv_group_run_id = |{ cl_system_uuid=>create_uuid_x16_static( ) }|.
        CATCH cx_uuid_error INTO DATA(lx_uuid).
          " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
          " El prefijo consume 46 de los 50 caracteres: del get_text( ) de la
          " excepcion sobrevivian 4.
          APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_calc_run_id ) %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error
            text = |Error generando UUID de grupo para el recalculo: { lx_uuid->get_text( ) }| ) )
            TO reported-calcrun.
          " End Mod V020 (09.09.2026 | EXT_GONZALCA)
          CONTINUE.
      ENDTRY.

      " Fix (EXT_GONZALCA, iteracion 3 -- corregido tras fallo real de
      " activacion, no solo dry-run de sintaxis): "TYPE TABLE FOR CREATE"
      " exige el NOMBRE TECNICO real de la entidad CDS (zi_reingcarun), NUNCA
      " el alias local de la behavior definition (CalcRun) -- confirmado por
      " la skill sap-abap (patron oficial "TYPE TABLE FOR CREATE root_entity",
      " siempre el nombre de entidad, nunca un alias) y por el mensaje de
      " activacion real: "The type CALCRUN is not an entity for which BEHAVIOR
      " can be defined" (SAP rechaza "CalcRun" precisamente porque intenta
      " resolverlo como si fuera una entidad, y un alias no lo es). El
      " borrador original de Oscar tenia 3 segmentos
      " (zi_reingcarun\CalcRun\_Line, alias redundante); mi primer fix quito
      " el segmento equivocado (elimino el nombre tecnico y dejo el alias);
      " este fix quita el alias y conserva el nombre tecnico + la asociacion.
      " El "ENTITY CalcRun ... CREATE BY \_Line" del MODIFY ENTITIES de mas
      " abajo SI usa el alias correctamente -- ese es un contexto distinto
      " (identifica la entidad dentro del propio EML), no la declaracion de
      " tipo de la tabla interna.
      DATA lt_create TYPE TABLE FOR CREATE zi_reingcarun\_Line.
      CLEAR lt_create.

      " ATC fix (DB-in-loop): usar tablas pre-cargadas globalmente en lugar de
      " FAE dentro del LOOP AT keys. Filtrar en memoria por calc_run_id + grupo.
      DATA lt_existing_bulk TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
      DATA lt_pend_bulk     TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defect (2) -- ver la nota de cabecera de este metodo. Las dos tablas
      " se llenan filtrando por calc_run_id pero se LEEN filtrando solo por
      " grupo, asi que arrastrar filas del key anterior podia mandar el
      " line_num de OTRO run a GT_LINE_DEL.
      CLEAR lt_existing_bulk.
      CLEAR lt_pend_bulk.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      IF lt_eligible IS NOT INITIAL.
        DATA ls_eg LIKE LINE OF lt_existing_bulk_global.
        " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
        " Defect (1). Desde el segundo key, LT_EXISTING_BULK quedaba vacio y
        " eso desactivaba el RESET de recalculo de TODOS los grupos del key.
        " Linea original: DATA lv_idx_eg TYPE i VALUE 1.
        DATA lv_idx_eg TYPE i.
        lv_idx_eg = 1.
        " End Mod V025 (16.09.2026 | EXT_GONZALCA)
        DO lines( lt_existing_bulk_global ) TIMES.
          READ TABLE lt_existing_bulk_global INTO ls_eg INDEX lv_idx_eg.
          IF ls_eg-calc_run_id = lv_calc_run_id. " Fix 002 (V008): CalcRunId derivado
            APPEND ls_eg TO lt_existing_bulk.
          ENDIF.
          lv_idx_eg = lv_idx_eg + 1.
        ENDDO.
        DATA ls_pg LIKE LINE OF lt_pend_bulk_global.
        " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
        " Defect (1). Mismo efecto sobre la reutilizacion de la fila PEND del
        " Path B/Defer: desde el segundo key no se encontraba ninguna.
        " Linea original: DATA lv_idx_pg TYPE i VALUE 1.
        DATA lv_idx_pg TYPE i.
        lv_idx_pg = 1.
        " End Mod V025 (16.09.2026 | EXT_GONZALCA)
        DO lines( lt_pend_bulk_global ) TIMES.
          READ TABLE lt_pend_bulk_global INTO ls_pg INDEX lv_idx_pg.
          IF ls_pg-calc_run_id = lv_calc_run_id. " Fix 002 (V008): CalcRunId derivado
            APPEND ls_pg TO lt_pend_bulk.
          ENDIF.
          lv_idx_pg = lv_idx_pg + 1.
        ENDDO.
      ENDIF.

      " ATC fix: acumular LOG_A y line_nums para DELETE en bulk fuera del DO ENDDO.
      DATA lt_log_calc_all TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
      DATA lt_all_existing_nums TYPE tt_line_num.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defect (2). Las dos se vuelcan a LT_BULK_LOG / LT_BULK_NUMS al final
      " de CADA key, asi que sin CLEAR el contenido del key anterior se
      " re-agregaba: filas de LOG_A duplicadas y rangos de borrado repetidos.
      CLEAR lt_log_calc_all.
      CLEAR lt_all_existing_nums.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)

      " ATC fix: DO TIMES en lugar de LOOP anidado para lt_eligible.
      DATA ls_group LIKE LINE OF lt_eligible.
      DATA lv_idx_elig TYPE i.
      lv_idx_elig = 1.
      DO lines( lt_eligible ) TIMES.
        READ TABLE lt_eligible INTO ls_group INDEX lv_idx_elig.
        lv_idx_elig = lv_idx_elig + 1.

        " Recalculo (CU-2): LOG_A RESET -- leer desde tabla pre-cargada.
        DATA lt_existing TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
        CLEAR lt_existing.
        DATA ls_ex_flt LIKE LINE OF lt_existing_bulk.
        " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
        " Defect (1) -- ESTE es el sitio que produjo el incidente de claves
        " duplicadas de CALineAll descrito en la nota de cabecera. El
        " contador vive DENTRO del DO por grupo elegible, asi que del segundo
        " grupo en adelante LT_EXISTING quedaba vacio y el grupo se recreaba
        " SIN borrar sus lineas anteriores.
        " Linea original: DATA lv_idx_flt TYPE i VALUE 1.
        DATA lv_idx_flt TYPE i.
        lv_idx_flt = 1.
        " End Mod V025 (16.09.2026 | EXT_GONZALCA)
        DO lines( lt_existing_bulk ) TIMES.
          READ TABLE lt_existing_bulk INTO ls_ex_flt INDEX lv_idx_flt.
          IF ls_ex_flt-ct_uuid  = ls_group-ct_uuid  AND ls_ex_flt-mat_uuid = ls_group-mat_uuid
         AND ls_ex_flt-op_type  = ls_group-op_type  AND ls_ex_flt-op_uuid  = ls_group-op_uuid
         AND ls_ex_flt-cm_h_id  = ls_group-cm_h_id.
            APPEND ls_ex_flt TO lt_existing.
          ENDIF.
          lv_idx_flt = lv_idx_flt + 1.
        ENDDO.

        IF lt_existing IS NOT INITIAL.
          " ATC fix: DO TIMES en lugar de LOOP anidado.
          DATA lv_idx_ex TYPE i.
          lv_idx_ex = 1.
          DO lines( lt_existing ) TIMES.
            READ TABLE lt_existing INTO DATA(ls_existing) INDEX lv_idx_ex.
            APPEND VALUE zreing_ca_log_a(
              calc_run_id  = lv_calc_run_id  line_num    = ls_existing-line_num
              log_num      = 0 " V011: placeholder, recalculado en save_modified
              action       = zif_reing_ca_c=>action-reset  status_from = ls_existing-line_status
              status_to    = space  created_by = sy-uname  group_run_id = lv_group_run_id
              created_at   = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
              message      = 'Recalculo: se reinicia la linea antes de recrearla (ET SS2.11)' )
              TO lt_log_calc_all.
            APPEND VALUE ty_line_num_range( sign = 'I' option = 'EQ' low = ls_existing-line_num )
              TO lt_all_existing_nums.
            lv_idx_ex = lv_idx_ex + 1.
          ENDDO.
        ENDIF.

        TRY.
            " ATC fix (NonLocal DBREAD via get_instance en loop): reemplaza get_instance
            " por get_instance_from_cache -- CERO SELECT, lee solo de gt_cache
            " pre-cargado por warm_cache antes del LOOP AT keys.
            DATA(lo_strategy) = zcl_reing_ca_optype_factory=>get_instance_from_cache(
              iv_op_type = ls_group-op_type
              io_sources = NEW zcl_reing_ca_sources( )
              is_context = VALUE #( calc_run_id = lv_calc_run_id
                                     period = ls_run_ctx-fiscal_period year = ls_run_ctx-fiscal_year ) ).
            DATA(lv_expand_mode) = lo_strategy->expand_mode( CORRESPONDING zreing_ca_line_a( ls_group ) ).
          CATCH zcx_reing_ca_calc_error INTO DATA(lx_dispatch).
            " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
            APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_calc_run_id ) %msg = zcx_reing_ca_msg=>new(
              severity = if_abap_behv_message=>severity-error text = lx_dispatch->mv_message ) ) TO reported-calcrun.
            " End Mod V020 (09.09.2026 | EXT_GONZALCA)
            CONTINUE.
        ENDTRY.

        DATA(ls_cm_group) = VALUE ty_cm_bulk(
          lt_cm_bulk_global[ cm_h_id = ls_group-cm_h_id ] OPTIONAL ).
        DATA(lv_delta_seq) = CONV zreing_ca_line_a-delta_seq( '00' ).
        IF ls_cm_group-delta_flag = abap_true.
          IF lt_existing IS NOT INITIAL.
            lv_delta_seq = REDUCE zreing_ca_line_a-delta_seq(
              INIT lv_seq TYPE zreing_ca_line_a-delta_seq
              FOR ls_same IN lt_existing
              NEXT lv_seq = COND #( WHEN ls_same-delta_seq > lv_seq
                                    THEN ls_same-delta_seq ELSE lv_seq ) ).
          ELSE.
            DATA(lv_prev_delta_seq) = REDUCE zreing_ca_line_a-delta_seq(
              INIT lv_seq_prev TYPE zreing_ca_line_a-delta_seq
              FOR ls_prev IN lt_existing_bulk
              WHERE ( ct_uuid = ls_group-ct_uuid
                      AND mat_uuid = ls_group-mat_uuid
                      AND op_type = ls_group-op_type
                      AND op_uuid = ls_group-op_uuid
                      AND cm_h_id = ls_group-cm_h_id
                      AND is_delta = abap_true )
              NEXT lv_seq_prev = COND #( WHEN ls_prev-delta_seq > lv_seq_prev
                                         THEN ls_prev-delta_seq ELSE lv_seq_prev ) ).
            lv_delta_seq = lv_prev_delta_seq + 1.
          ENDIF.
        ENDIF.

        CASE lv_expand_mode.
          WHEN zif_reing_ca_c=>row_type-cm_pending.
            " Begin Mod V024 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
            lv_next_line_num  = lv_next_line_num + 1.
            " Marca de agua del run: el numero consumido tiene que verlo el
            " key siguiente del mismo bulk, no solo esta iteracion.
            <ls_hwm>-line_num = lv_next_line_num.
            " End Mod V024 (16.09.2026 | EXT_GONZALCA)
            " Fix (EXT_GONZALCA, iteracion 4, addendum Fix 6 -- MAYOR RIESGO,
            " ver code-summary.md): para "TYPE TABLE FOR CREATE <root>\<assoc>"
            " creando hijos por asociacion sobre un padre YA EXISTENTE (no en
            " el mismo CREATE), la fila usa la clave del padre PLANA en el
            " nivel superior (CalcRunId = ...), NUNCA envuelta en %tky =
            " VALUE #(...) -- ese componente no es valido para este tipo de
            " fila. %target pasa a ser una TABLA (un nivel extra de
            " parentesis), no una estructura simple, porque %target aqui es
            " la lista de hijos nuevos. %cid es obligatorio dentro de cada
            " fila de %target aunque no se use para correlacionar despues.
            " Fix 002 (V008): CalcRunId derivado (lv_calc_run_id). %cid del hijo
            " prefijado con lv_calc_run_id para ser unico en el bulk multi-key
            " (ONB-002; lt_create acumula en lt_bulk_create a traves de todos
            " los keys, donde line_num podia repetirse entre periodos distintos).
            APPEND VALUE #( CalcRunId = lv_calc_run_id
              %target = VALUE #( ( %cid = |CID{ lv_calc_run_id }_{ lv_next_line_num }|
                LineNum = lv_next_line_num CtUuid = ls_group-ct_uuid
                MatUuid = ls_group-mat_uuid OpType = ls_group-op_type OpUuid = ls_group-op_uuid
                CmHId = ls_group-cm_h_id CmLoadSeq = ls_cm_group-load_seq
                IsDelta = ls_cm_group-delta_flag DeltaSeq = lv_delta_seq
                LineStatus = zif_reing_ca_c=>line_status-calc_proc
                ProcStartedAt = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) ) ) ) TO lt_create.

            " Begin Change ID V015 (17.07.2026 | EXT_GONZALCA)
            " Fix: ninguna rama de Calculate logueaba la CREACION de la
            " linea nueva -- LOG_A solo registraba el RESET de la linea
            " VIEJA que se reemplaza (o quedaba vacio si no habia linea
            " previa que resetear), nunca un evento para el line_num nuevo
            " que efectivamente queda en LINE_A. Por eso el usuario veia
            " en LOG_A solo entradas de la ejecucion ANTERIOR (line_num
            " viejo ya borrado) sin ninguna correlacion con las lineas
            " actuales -- action-create ya existia en el dominio
            " ZREING_CA_ACTION ("Alta") pero nunca se usaba.
            APPEND VALUE zreing_ca_log_a(
              calc_run_id  = lv_calc_run_id  line_num   = lv_next_line_num
              log_num      = 0 " placeholder, recalculado en save_modified
              action       = zif_reing_ca_c=>action-create
              status_from  = space  status_to = zif_reing_ca_c=>line_status-calc_proc
              created_by   = sy-uname  group_run_id = lv_group_run_id
              created_at   = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
              message      = 'Calculate: linea nueva creada en CALC_PROC (Path A/CM)' )
              TO lt_log_calc_all.
            " End Change ID V015 (17.07.2026 | EXT_GONZALCA)

          WHEN zif_reing_ca_c=>row_type-defer_pending.
            " ATC fix (DB-in-loop): leer PEND desde tabla pre-cargada lt_pend_bulk.
            DATA lt_pend TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
            CLEAR lt_pend.
            DATA ls_pend_flt LIKE LINE OF lt_pend_bulk.
            " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
            " Defect (1). Mismo sitio que lv_idx_flt pero en el Path B/Defer:
            " del segundo grupo en adelante no se encontraba la fila PEND a
            " reutilizar y se reportaba "No existe linea PEND para el grupo",
            " o se creaba una linea nueva en paralelo a la existente.
            " Linea original: DATA lv_idx_pflt TYPE i VALUE 1.
            DATA lv_idx_pflt TYPE i.
            lv_idx_pflt = 1.
            " End Mod V025 (16.09.2026 | EXT_GONZALCA)
            DO lines( lt_pend_bulk ) TIMES.
              READ TABLE lt_pend_bulk INTO ls_pend_flt INDEX lv_idx_pflt.
              IF ls_pend_flt-ct_uuid  = ls_group-ct_uuid  AND ls_pend_flt-mat_uuid = ls_group-mat_uuid
             AND ls_pend_flt-op_type  = ls_group-op_type  AND ls_pend_flt-op_uuid  = ls_group-op_uuid
             AND ls_pend_flt-cm_h_id  = ls_group-cm_h_id.
                APPEND ls_pend_flt TO lt_pend.
              ENDIF.
              lv_idx_pflt = lv_idx_pflt + 1.
            ENDDO.
            IF lt_pend IS INITIAL.
              DATA lv_idx_b2 TYPE i.
              lv_idx_b2 = 1.
              DO lines( lt_b2_virtual_global ) TIMES.
                READ TABLE lt_b2_virtual_global INTO DATA(ls_b2) INDEX lv_idx_b2.
                IF ls_b2-CtUuid      = ls_group-ct_uuid
               AND ls_b2-MatUuid     = ls_group-mat_uuid
               AND ls_b2-OpType      = ls_group-op_type
               AND ls_b2-OpUuid      = ls_group-op_uuid
               AND ls_b2-CmHId       = ls_group-cm_h_id
               AND ls_b2-PeriodYear  = ls_key-%param-fiscal_year
               AND ls_b2-PeriodMonth = ls_key-%param-fiscal_period.
                  APPEND VALUE zreing_ca_line_a(
                    ct_uuid           = ls_b2-CtUuid
                    ct_id             = ls_b2-CtId
                    lifnr             = ls_b2-Lifnr
                    bp_name           = ls_b2-BpName
                    bukrs_prest       = ls_b2-BukrsPrest
                    mat_uuid          = ls_b2-MatUuid
                    matnr             = ls_b2-Matnr
                    op_type           = ls_b2-OpType
                    op_uuid           = ls_b2-OpUuid
                    cm_h_id           = ls_b2-CmHId
                    cm_load_seq       = ls_b2-CmLoadSeq
                    op_instance_num   = ls_b2-OpInstanceNum
                    origin_run_id     = ls_b2-OriginRunId
                    origin_line_num   = ls_b2-OriginLineNum
                    parent_net_amt    = ls_b2-ParentNetAmt
                    parent_currency   = ls_b2-ParentCurrency
                    defer_pct         = ls_b2-DeferPct
                    defer_cuota_num   = ls_b2-DeferCuotaNum
                    defer_cuota_total = ls_b2-DeferCuotaTotal
                    defer_from        = ls_b2-DeferFrom
                    defer_to          = ls_b2-DeferTo
                    bukrs_recv        = ls_b2-BukrsRecv
                    country           = ls_b2-Country
                    base_amt          = ls_b2-BaseAmt
                    share_pct         = ls_b2-SharePct
                    share_pais_pct    = ls_b2-SharePaisPct
                    share_comb_pct    = ls_b2-ShareCombPct
                    ct_currency       = ls_b2-CtCurrency
                    local_currency    = ls_b2-LocalCurrency
                    exch_rate         = ls_b2-ExchRate
                    exch_rate_type    = ls_b2-ExchRateType
                    is_delta          = ls_b2-IsDelta
                    delta_seq         = ls_b2-DeltaSeq
                    delta_base_amt    = ls_b2-DeltaBaseAmt
                    line_status       = 'PEND' ) TO lt_pend.
                ENDIF.
                lv_idx_b2 = lv_idx_b2 + 1.
              ENDDO.
            ENDIF.

            " Recalculation: the anti-join hides B2 virtual rows while the
            " previous physical lines still exist. Reuse their source fields.
            IF lt_pend IS INITIAL AND lt_existing IS NOT INITIAL.
              APPEND LINES OF lt_existing TO lt_pend.
            ENDIF.

            IF lt_pend IS INITIAL.
              " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
              " El op_uuid es un UUID de 32 caracteres, asi que con el prefijo
              " el mensaje pasaba de 50 siempre y el "(Path B/C)" no llegaba.
              APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_calc_run_id ) %msg = zcx_reing_ca_msg=>new(
                severity = if_abap_behv_message=>severity-error
                text = |No existe linea PEND para el grupo op_uuid { ls_group-op_uuid } (Path B/C)| ) ) TO reported-calcrun.
              " End Mod V020 (09.09.2026 | EXT_GONZALCA)
            ELSE.
              " ATC fix: DO TIMES en lugar de LOOP anidado.
              DATA lv_idx_pend TYPE i.
              lv_idx_pend = 1.
              DO lines( lt_pend ) TIMES.
                READ TABLE lt_pend INTO DATA(ls_pend) INDEX lv_idx_pend.
                " Begin Mod V024 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
                lv_next_line_num  = lv_next_line_num + 1.
                " Misma marca de agua que en Path A.
                <ls_hwm>-line_num = lv_next_line_num.
                " End Mod V024 (16.09.2026 | EXT_GONZALCA)
                " Fix 002 (V008): mismo ajuste que Path A -- CalcRunId derivado
                " + %cid unico prefijado con lv_calc_run_id (ONB-002).
                APPEND VALUE #( CalcRunId = lv_calc_run_id
                  %target = VALUE #( ( %cid = |CID{ lv_calc_run_id }_{ lv_next_line_num }|
                    LineNum = lv_next_line_num CtUuid = ls_group-ct_uuid
                    MatUuid = ls_group-mat_uuid OpType = ls_group-op_type OpUuid = ls_group-op_uuid
                    CmHId = ls_pend-cm_h_id CmLoadSeq = ls_pend-cm_load_seq
                    IsDelta = ls_pend-is_delta DeltaSeq = ls_pend-delta_seq
                    OpInstanceNum = ls_pend-op_instance_num BukrsRecv = ls_pend-bukrs_recv
                    CtId = ls_pend-ct_id Lifnr = ls_pend-lifnr
                    BpName = ls_pend-bp_name BukrsPrest = ls_pend-bukrs_prest
                    Matnr = ls_pend-matnr ParentOpType = ls_pend-parent_op_type
                    OriginRunId = ls_pend-origin_run_id OriginLineNum = ls_pend-origin_line_num
                    ParentNetAmt = ls_pend-parent_net_amt ParentCurrency = ls_pend-parent_currency
                    DeferPct = ls_pend-defer_pct DeferCuotaNum = ls_pend-defer_cuota_num
                    DeferCuotaTotal = ls_pend-defer_cuota_total
                    DeferFrom = ls_pend-defer_from DeferTo = ls_pend-defer_to
                    Country = ls_pend-country BaseAmt = ls_pend-base_amt
                    SharePct = ls_pend-share_pct SharePaisPct = ls_pend-share_pais_pct
                    ShareCombPct = ls_pend-share_comb_pct CtCurrency = ls_pend-ct_currency
                    LocalCurrency = ls_pend-local_currency ExchRate = ls_pend-exch_rate
                    ExchRateType = ls_pend-exch_rate_type DeltaBaseAmt = ls_pend-delta_base_amt
                    LineStatus = zif_reing_ca_c=>line_status-calc_proc
                    ProcStartedAt = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) ) ) ) TO lt_create.

                " Begin Change ID V015 (17.07.2026 | EXT_GONZALCA)
                " Fix: mismo gap que Path A -- ver comentario alli.
                APPEND VALUE zreing_ca_log_a(
                  calc_run_id  = lv_calc_run_id  line_num   = lv_next_line_num
                  log_num      = 0 " placeholder, recalculado en save_modified
                  action       = zif_reing_ca_c=>action-create
                  status_from  = space  status_to = zif_reing_ca_c=>line_status-calc_proc
                  created_by   = sy-uname  group_run_id = lv_group_run_id
                  created_at   = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) )
                  message      = 'Calculate: linea nueva creada en CALC_PROC (Path B/Defer)' )
                  TO lt_log_calc_all.
                " End Change ID V015 (17.07.2026 | EXT_GONZALCA)
                lv_idx_pend = lv_idx_pend + 1.
              ENDDO.
            ENDIF.

          WHEN OTHERS.
            " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
            APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_calc_run_id ) %msg = zcx_reing_ca_msg=>new(
              severity = if_abap_behv_message=>severity-error
              text = |OP_TYPE { ls_group-op_type } sin modo de expansion valido para Calculate| ) ) TO reported-calcrun.
            " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        ENDCASE.
      ENDDO.

      " ATC fix (DB-in-loop): acumular LOG_A, line_nums y CREATE en bulk
      " para ejecutar los DMLs FUERA del LOOP AT keys.
      APPEND LINES OF lt_log_calc_all TO lt_bulk_log.
      IF lt_all_existing_nums IS NOT INITIAL.
        APPEND VALUE ty_calc_run_nums(
          calc_run_id = lv_calc_run_id
          line_nums   = lt_all_existing_nums ) TO lt_bulk_nums.
      ENDIF.
      APPEND LINES OF lt_create TO lt_bulk_create.
    ENDLOOP.

    " ATC fix (DBWRT_LOC): aplanar todos los line_nums de todos los runs en un
    " rango global y ejecutar los 3 DELETEs una sola vez, sin loop por run.
    "Begin Mod V017 (CC)
    " V017: the comment below was WRONG -- line_num is numbered PER RUN
    " (see calculate's own CalcRunId-scoped numbering), not globally unique.
    " That false premise caused silent cross-RUN corruption (root cause of
    " this fix). calc_run_id is now carried alongside line_num everywhere.
    "    line_num es unico globalmente en zreing_ca_line_a -- no necesitamos
    "    filtrar adicionalmente por calc_run_id.
    "End Mod V017 (CC)
    " Begin Change ID V010 (17.07.2026 | EXT_GONZALCA)
    " Fix RUNTIME_ERROR BEHAVIOR_ILLEGAL_STATEMENT: INSERT/DELETE directos
    " prohibidos en fase Modify -- se acumulan en el buffer estatico y se
    " ejecutan en save_modified (fase Save). Ver lcl_reing_ca_dml_buffer.
    APPEND LINES OF lt_bulk_log TO lcl_reing_ca_dml_buffer=>gt_log.
    "Begin Mod V017 (CC)
    " V017 (testability refactor): inline flatten replaced by the shared pure
    " helper (unifies calculate's flatten and delete's flatten). Same result.
    DATA lt_all_line_nums_calc TYPE lcl_reing_ca_dml_buffer=>tt_line_del_key.
    lt_all_line_nums_calc = lcl_reing_ca_dml_buffer=>flatten_run_line_nums( lt_bulk_nums ).
    "End Mod V017 (CC)
    APPEND LINES OF lt_all_line_nums_calc TO lcl_reing_ca_dml_buffer=>gt_line_del.
    " End Change ID V010 (17.07.2026 | EXT_GONZALCA)
    " Begin Change ID V008 (15.07.2026 | EXT_GONZALCA)
    " Fix 002: find-or-create del Run (helper DRY compartido con initializeperiod).
    " ORDEN CRITICO: se ejecuta ANTES del CREATE BY \_Line de abajo -- CalcRunId
    " es una clave suplida por el cliente (deterministica, no autogenerada); el
    " padre CalcRun debe estar presente en el buffer del LUW para que \_Line se
    " cree por asociacion sobre el (mismo patron "Fix 6" ya activo en este metodo).
    " result = $self por cada Run persistido (preexistente o recien creado).
    " CU-6: un key sin grupos elegibles cuyo Run NO existia queda existed=''/
    " created='' -> NO se agrega a result (no se devuelve clave de recurso
    " inexistente); con Run preexistente queda existed=X -> SI se devuelve.
    DATA lt_run_state    TYPE tt_run_state.
    DATA lt_run_tocreate TYPE TABLE FOR CREATE zi_reingcarun.
    IF lt_run_requests IS NOT INITIAL.
      " Fallback iter #6: ensure_runs es puro y devuelve solo el state; el
      " payload TABLE FOR CREATE se construye AQUI (DATA local, valida en metodo
      " FOR MODIFY) y el MODIFY CREATE se ejecuta AQUI.
      ensure_runs(
        EXPORTING it_requests  = lt_run_requests
        IMPORTING et_run_state = lt_run_state ).

      LOOP AT lt_run_state INTO DATA(ls_nc) WHERE needs_create = abap_true.
        lt_run_tocreate = VALUE #( BASE lt_run_tocreate
          ( %cid         = ls_nc-cid
            CalcRunId    = ls_nc-calc_run_id
            FiscalYear   = ls_nc-fiscal_year
            FiscalPeriod = ls_nc-fiscal_period
            TotalLines   = 0
            TotalGroups  = 0
            CreatedBy    = sy-uname
            CreatedAt    = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) ) ).
      ENDLOOP.

      IF lt_run_tocreate IS NOT INITIAL.
        MODIFY ENTITIES OF zi_reingcarun
          ENTITY CalcRun
          CREATE FIELDS ( CalcRunId FiscalYear FiscalPeriod TotalLines TotalGroups CreatedBy CreatedAt )
          WITH lt_run_tocreate
          MAPPED   DATA(ls_run_mapped)
          FAILED   DATA(ls_run_failed)
          REPORTED DATA(ls_run_reported).
        APPEND LINES OF ls_run_failed-calcrun   TO failed-calcrun.
        APPEND LINES OF ls_run_reported-calcrun TO reported-calcrun.
        " "created" = lo efectivamente persistido (via MAPPED, nunca lo fallido).
        LOOP AT ls_run_mapped-calcrun INTO DATA(ls_rm).
          ASSIGN lt_run_state[ cid = ls_rm-%cid ] TO FIELD-SYMBOL(<rs_upd>).
          IF sy-subrc = 0.
            <rs_upd>-created = abap_true.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " Fix 002 (it7): Calculate es "static action" SIN result -- una static
      " action no expone %tky para devolver $self (EU: "No component %TKY"). El
      " frontend refresca la lista (CALineAll) tras la accion; no necesita el
      " result. Los Runs creados/reutilizados quedan persistidos igualmente.
    ENDIF.
    " End Change ID V008 (15.07.2026 | EXT_GONZALCA)

    IF lt_bulk_create IS NOT INITIAL.
      MODIFY ENTITIES OF zi_reingcarun ENTITY CalcRun
        CREATE BY \_Line
        FIELDS ( LineNum CtUuid MatUuid OpType OpUuid CmHId CmLoadSeq IsDelta DeltaSeq
                 OpInstanceNum BukrsRecv CtId Lifnr BpName BukrsPrest Matnr ParentOpType
                 OriginRunId OriginLineNum ParentNetAmt ParentCurrency DeferPct
                 DeferCuotaNum DeferCuotaTotal DeferFrom DeferTo Country BaseAmt
                 SharePct SharePaisPct ShareCombPct CtCurrency LocalCurrency ExchRate
                 ExchRateType DeltaBaseAmt LineStatus ProcStartedAt )
        WITH lt_bulk_create
        MAPPED   DATA(ls_mapped_bulk)
        FAILED   DATA(ls_failed_bulk)
        REPORTED DATA(ls_reported_bulk).
      APPEND LINES OF ls_failed_bulk-CalcLine   TO failed-CalcLine.
      APPEND LINES OF ls_reported_bulk-CalcLine TO reported-CalcLine.
      " Begin Insert V024 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
      " Hasta V023, si este CREATE fallaba las filas se mandaban a
      " FAILED-CALCLINE sin ningun %msg y el usuario veia el boton Calcular
      " sin efecto: ni job, ni error, ni entrada en LOG_A (el changeset se
      " rechaza y la fase Save no llega a correr, por eso tampoco sirve
      " emitir el mensaje en el CHECK de SAVE_MODIFIED). Ese "no paso nada"
      " silencioso es un defecto en si mismo, independiente de la causa que
      " haga fallar al CREATE, y es lo que hizo que #77 se reportara sin un
      " solo dato de diagnostico.
      "
      " Atribucion por run: se cuenta contra el %cid, que es la correlacion
      " de un CREATE fallido (la clave de la instancia puede no existir
      " todavia, por eso no se usa %tky). El %cid lo construimos nosotros
      " como |CID{ run }_{ num }| unas lineas mas arriba, asi que su prefijo
      " identifica el run sin ambiguedad: todos los CalcRunId miden lo mismo
      " (RUN-AAAAPP), ninguno es prefijo de otro. Derivar la lista de runs de
      " LT_BULK_CREATE a secas -- todo lo que se INTENTO crear -- culpaba
      " tambien al run que se habia creado bien cuando el CREATE falla
      " PARCIALMENTE, y repetia el total del bulk como si fuera de cada run.
      " Se emite UN error por run afectado, nunca uno por linea: con 14
      " receptoras el frontend mostraria 14 mensajes identicos. El texto pasa
      " por ZCX_REING_CA_MSG=>NEW, que lo reparte en &1..&4 del T100
      " ZREING_CA 001 -- sin eso se corta a 50 caracteres en la cabecera
      " sap-messages de la respuesta $batch (V020 / fixes-011).
      IF ls_failed_bulk-CalcLine IS NOT INITIAL.
        TYPES: BEGIN OF ty_run_fail,
                 calc_run_id TYPE zreing_ca_run_a-calc_run_id,
                 cnt         TYPE i,
                 " Begin Insert V026 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
                 detail      TYPE string,
                 " End Insert V026 (16.09.2026 | EXT_GONZALCA)
               END OF ty_run_fail.
        DATA lt_run_fail TYPE STANDARD TABLE OF ty_run_fail WITH EMPTY KEY.
        " Begin Insert V026 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
        " El mensaje que agrego V024 confirmo que el CREATE se rechaza, pero
        " no dice CUAL grupo, y RAP no devuelve %msg propio en estas filas
        " (razon de ser de todo este bloque). Sin ese dato cada reproduccion
        " obliga a repetir la seleccion a ciegas -- que es lo que paso con el
        " reporte de Paola del 16.09.2026 sobre RUN-202602.
        " El %cid lo construimos nosotros como |CID{ run }_{ num }|, asi que
        " alcanza con mapear %cid -> grupo desde LT_BULK_CREATE y de ahi a
        " CT_ID/MATNR con LT_IDENTITY_BULK_GLOBAL, que ya esta cargado en
        " memoria (cero SELECT nuevo).
        " Se aplana con dos FOR en una sola table comprehension -- el segundo
        " recorre %target, la tabla de hijos del CREATE BY \_Line -- para no
        " introducir un LOOP anidado.
        TYPES: BEGIN OF ty_cid_group,
                 cid        TYPE string,
                 ct_id      TYPE zreing_ct2_a-ct_id,
                 matnr      TYPE zreing_ct2_mat_a-matnr,
                 op_type    TYPE zreing_op_type,
                 bukrs_recv TYPE bukrs,
               END OF ty_cid_group,
               tt_cid_group TYPE STANDARD TABLE OF ty_cid_group WITH EMPTY KEY.
        DATA(lt_cid_group) = VALUE tt_cid_group(
          FOR ls_bc_cg IN lt_bulk_create
          FOR ls_tg_cg IN ls_bc_cg-%target
          ( cid        = ls_tg_cg-%cid
            ct_id      = VALUE #( lt_identity_bulk_global[ ct_uuid  = ls_tg_cg-CtUuid
                                                           mat_uuid = ls_tg_cg-MatUuid ]-ct_id OPTIONAL )
            matnr      = VALUE #( lt_identity_bulk_global[ ct_uuid  = ls_tg_cg-CtUuid
                                                           mat_uuid = ls_tg_cg-MatUuid ]-matnr OPTIONAL )
            op_type    = ls_tg_cg-OpType
            bukrs_recv = ls_tg_cg-BukrsRecv ) ).
        " End Insert V026 (16.09.2026 | EXT_GONZALCA)
        DATA(lt_bulk_runs) = VALUE tt_created_line(
          FOR ls_fbc IN lt_bulk_create ( calc_run_id = ls_fbc-CalcRunId ) ).
        SORT lt_bulk_runs BY calc_run_id.
        DELETE ADJACENT DUPLICATES FROM lt_bulk_runs COMPARING calc_run_id.

        DATA lv_fail_total TYPE i.
        CLEAR lv_fail_total.
        LOOP AT lt_bulk_runs INTO DATA(ls_brun).
          DATA(lv_cid_pref) = |CID{ ls_brun-calc_run_id }_|.
          DATA lv_run_cnt TYPE i.
          CLEAR lv_run_cnt.
          " Begin Insert V026 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
          DATA lv_run_detail TYPE string.
          CLEAR lv_run_detail.
          " End Insert V026 (16.09.2026 | EXT_GONZALCA)
          " ATC (Loops anidados, ZMELI_CLEAN_CORE_V3): DO TIMES + READ INDEX,
          " nunca LOOP dentro de LOOP -- ya bloqueo una liberacion.
          DATA lv_idx_fl TYPE i.
          lv_idx_fl = 1.
          DO lines( ls_failed_bulk-CalcLine ) TIMES.
            READ TABLE ls_failed_bulk-CalcLine INTO DATA(ls_fline) INDEX lv_idx_fl.
            IF ls_fline-%cid CS lv_cid_pref.
              lv_run_cnt = lv_run_cnt + 1.
              " Begin Insert V026 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
              " Solo los dos primeros: el texto entra en el T100 ZREING_CA 001,
              " que son 4 tramos de 50 caracteres y TRUNCA en silencio a partir
              " de ahi (ZCX_REING_CA_MSG=>SPLIT). El resto se resume al salir
              " del DO con un "y N mas".
              IF lv_run_cnt <= 2.
                DATA(ls_cg) = VALUE ty_cid_group(
                                lt_cid_group[ cid = ls_fline-%cid ] OPTIONAL ).
                " Sin identidad resuelta se degrada a op_type/receptora en vez
                " de imprimir un UUID que no le dice nada a funcional.
                DATA(lv_desc_cg) = COND string(
                  WHEN ls_cg-ct_id IS NOT INITIAL
                    THEN |{ ls_cg-ct_id }/{ ls_cg-matnr }/{ ls_cg-op_type }/{ ls_cg-bukrs_recv }|
                  WHEN ls_cg-op_type IS NOT INITIAL
                    THEN |{ ls_cg-op_type }/{ ls_cg-bukrs_recv }|
                  ELSE `` ).
                IF lv_desc_cg IS NOT INITIAL.
                  lv_run_detail = COND string( WHEN lv_run_detail IS INITIAL
                                                 THEN lv_desc_cg
                                                 ELSE |{ lv_run_detail }, { lv_desc_cg }| ).
                ENDIF.
              ENDIF.
              " End Insert V026 (16.09.2026 | EXT_GONZALCA)
            ENDIF.
            lv_idx_fl = lv_idx_fl + 1.
          ENDDO.
          " Begin Insert V026 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
          IF lv_run_cnt > 2 AND lv_run_detail IS NOT INITIAL.
            lv_run_detail = |{ lv_run_detail } y { lv_run_cnt - 2 } mas|.
          ENDIF.
          " Tope duro: MATNR admite 40 caracteres y dos descriptores largos
          " se comerian los 200 del mensaje completo.
          IF strlen( lv_run_detail ) > 60.
            lv_run_detail = |{ substring( val = lv_run_detail off = 0 len = 57 ) }...|.
          ENDIF.
          " End Insert V026 (16.09.2026 | EXT_GONZALCA)
          APPEND VALUE #( calc_run_id = ls_brun-calc_run_id cnt = lv_run_cnt
                          detail = lv_run_detail )
            TO lt_run_fail.
          lv_fail_total = lv_fail_total + lv_run_cnt.
        ENDLOOP.

        " Salvaguarda: si el framework devolviera las filas fallidas SIN %cid,
        " ningun run matchearia y el usuario volveria a no ver nada -- que es
        " justo el defecto que este bloque cierra. En ese caso se reporta a
        " todos los runs del bulk con el total, asumiendo una atribucion
        " imprecisa antes que el silencio (limitacion documentada).
        IF lv_fail_total = 0.
          lt_run_fail = VALUE #( FOR ls_bkr IN lt_bulk_runs
            ( calc_run_id = ls_bkr-calc_run_id
              cnt         = lines( ls_failed_bulk-CalcLine ) ) ).
        ENDIF.

        LOOP AT lt_run_fail INTO DATA(ls_rfail) WHERE cnt > 0.
          APPEND VALUE #( %tky = VALUE #( CalcRunId = ls_rfail-calc_run_id )
            %msg = zcx_reing_ca_msg=>new(
              severity = if_abap_behv_message=>severity-error
              " Begin Mod V026 (16.09.2026 | EXT_GONZALCA) - bug tracker #77
              " El run pasa al frente y el grupo culpable entra entre
              " parentesis. Presupuesto: 46 (cabecera) + 63 (detalle topeado)
              " + 83 (cola) = 192 de los 200 que admite el T100.
              " Texto original, para el registro:
              "  |No se pudieron crear { ls_rfail-cnt } linea(s) de |
              "  |calculo para { ls_rfail-calc_run_id }: el calculo no |
              "  |se inicio. Reintente con un grupo a la vez; si |
              "  |persiste, informe a Soporte.|
              text     = |{ ls_rfail-calc_run_id }: no se crearon | &&
                         |{ ls_rfail-cnt } linea(s) de calculo| &&
                         COND string( WHEN ls_rfail-detail IS NOT INITIAL
                                        THEN | ({ ls_rfail-detail })|
                                      ELSE `` ) &&
                         |. El calculo no se inicio. Reintente de a un grupo; | &&
                         |si persiste, informe a Soporte.| ) )
              " End Mod V026 (16.09.2026 | EXT_GONZALCA)
            TO reported-CalcRun.
        ENDLOOP.
      ENDIF.
      " End Insert V024 (16.09.2026 | EXT_GONZALCA)
    ENDIF.
  ENDMETHOD.

  METHOD check_scope.
    " Guard concurrencia: bloquea grupos con LINE_A en estado *_PROC.
    CHECK it_groups IS NOT INITIAL.
    SELECT ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id FROM zreing_ca_line_a
      FOR ALL ENTRIES IN @it_groups
      WHERE calc_run_id = @iv_run_id AND ct_uuid = @it_groups-ct_uuid
        AND mat_uuid = @it_groups-mat_uuid AND op_type = @it_groups-op_type
        AND op_uuid  = @it_groups-op_uuid
        AND cm_h_id  = @it_groups-cm_h_id
        AND line_status IN ( 'CALC_PROC', 'SIM_PROC', 'POST_PROC', 'ANUL_PROC' )
      INTO CORRESPONDING FIELDS OF TABLE @rt_blocked.
    SORT rt_blocked. DELETE ADJACENT DUPLICATES FROM rt_blocked COMPARING ALL FIELDS.
  ENDMETHOD.

  METHOD check_insumos.
    " Guard insumos: verifica CM_H_A LIBD (BR-CA-13) y ME_H_A (BR-CA-38).
    " ATC fix (DB-in-loop): it_identity_bulk, it_me_metric_bulk e it_cm_bulk
    " recibidos como parametros -- CERO SELECTs en este metodo.
    " El llamador (calculate) pre-carga todos los datos ANTES del LOOP AT keys.
    CHECK it_groups IS NOT INITIAL.

    DATA ls_identity TYPE zif_reing_ca_types=>ty_ct_identity.
    LOOP AT it_groups INTO DATA(ls_group).
      " V001 (CC) — Devengo: Path B no requiere insumos CM/ME.
      TRY.
          DATA(lo_strategy) = zcl_reing_ca_optype_factory=>get_instance_from_cache(
            iv_op_type = ls_group-op_type
            io_sources = NEW zcl_reing_ca_sources( )
            is_context = VALUE #( calc_run_id = iv_run_id
                                   period = iv_fiscal_period
                                   year = iv_fiscal_year ) ).
          IF lo_strategy->expand_mode( CORRESPONDING zreing_ca_line_a( ls_group ) )
             = zif_reing_ca_c=>row_type-defer_pending.
            CONTINUE.
          ENDIF.
        CATCH zcx_reing_ca_calc_error INTO DATA(lx_dispatch).
          APPEND VALUE #( group = ls_group message = lx_dispatch->mv_message ) TO rt_errors.
          CONTINUE.
      ENDTRY.

      CLEAR ls_identity.
      TRY.
          " Identidad desde tabla pre-cargada (CERO SELECT).
          READ TABLE it_identity_bulk INTO DATA(ls_id_bulk)
            WITH KEY ct_uuid = ls_group-ct_uuid mat_uuid = ls_group-mat_uuid.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING
                iv_message = |Contrato/material inexistente para { ls_group-ct_uuid }/{ ls_group-mat_uuid }|.
          ENDIF.
          ls_identity-ct_id       = ls_id_bulk-ct_id.
          ls_identity-lifnr       = ls_id_bulk-lifnr.
          ls_identity-bukrs_prest = ls_id_bulk-bukrs_prest.
          ls_identity-matnr       = ls_id_bulk-matnr.

          " CM check: READ TABLE desde pre-fetch (CERO SELECT).
          " ATC fix (NonLocal DBREAD via get_cm_amount): reemplaza la llamada
          " a get_cm_amount() que hacia SELECT FROM zreing_cm_h_a.
          READ TABLE it_cm_bulk INTO DATA(ls_cm_check)
            WITH KEY cm_h_id = ls_group-cm_h_id.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING
                iv_message =
                             |No existe CM_H_A elegible (LIBD) para | &&
                             |{ ls_group-ct_uuid }/{ ls_group-mat_uuid }/{ ls_group-op_type }|.
          ENDIF.

          " ME metric check: READ TABLE desde pre-fetch (CERO SELECT).
          " ATC fix (NonLocal DBREAD via get_me_metric).
          READ TABLE it_me_metric_bulk INTO DATA(ls_me_metric)
            WITH KEY ct_id = ls_identity-ct_id matnr = ls_identity-matnr.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING
                iv_message =
                             |No existe metrica ME elegible para resolver granularidad: | &&
                             |{ ls_identity-ct_id }/{ ls_identity-matnr }|.
          ENDIF.

        CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
          APPEND VALUE #(
            group   = ls_group
            message = COND #(
              WHEN ls_identity IS NOT INITIAL
              THEN |No existen metricas para el material { ls_identity-matnr } del contrato | &&
                   |{ ls_identity-ct_id }. No es posible distribuir. Corrija la metrica antes de calcular.|
              ELSE |Contrato/material inexistente: { lx_error->mv_message }| ) ) TO rt_errors.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
  " End Change ID V002 (10.07.2026 | EXT_OSCUGALD)

  " Begin Change ID V003 (10.07.2026 | EXT_OSCUGALD)
  METHOD get_instance_features.
    " Habilita Release solo si el RUN tiene al menos una LINE_A en CALC.
    " Habilita Delete solo si el RUN tiene al menos una LINE_A IS_ORPHAN.
    " Ambas features se evaluan por CalcRunId (nivel Run, no nivel grupo).
    " ATC fix: pre-fetch bulk de los 3 flags con RANGE antes del LOOP AT keys.
    TYPES: BEGIN OF ty_run_id_range_feat,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE zreing_ca_run_a-calc_run_id,
             high   TYPE zreing_ca_run_a-calc_run_id,
           END OF ty_run_id_range_feat.
    TYPES: BEGIN OF ty_feat_flags,
             calc_run_id    TYPE zreing_ca_run_a-calc_run_id,
             has_calc       TYPE abap_bool,
             has_orphan     TYPE abap_bool,
             has_exportable TYPE abap_bool,
             " Begin Insert V016 (CC) - F4
             has_simulable   TYPE abap_bool,
             has_postable    TYPE abap_bool,
             has_stornoable  TYPE abap_bool,
             " End Insert V016 (CC) - F4
           END OF ty_feat_flags.
    DATA lt_run_range_feat TYPE STANDARD TABLE OF ty_run_id_range_feat WITH EMPTY KEY.
    DATA lt_feat_flags     TYPE STANDARD TABLE OF ty_feat_flags WITH EMPTY KEY.
    LOOP AT keys INTO DATA(ls_key_feat).
      APPEND VALUE ty_run_id_range_feat( sign = 'I' option = 'EQ' low = ls_key_feat-CalcRunId ) TO lt_run_range_feat.
      APPEND VALUE ty_feat_flags( calc_run_id = ls_key_feat-CalcRunId ) TO lt_feat_flags.
    ENDLOOP.
    IF lt_run_range_feat IS NOT INITIAL.
      SELECT DISTINCT calc_run_id FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_feat
          AND line_status IN ( @zif_reing_ca_c=>line_status-calc,
                               @zif_reing_ca_c=>line_status-sim_ok )
        INTO TABLE @DATA(lt_has_calc).
      SELECT DISTINCT calcrunid AS calc_run_id FROM zc_reingcalineall
        WHERE calcrunid IN @lt_run_range_feat AND isorphan = @abap_true
          AND linestatus <> @zif_reing_ca_c=>line_status-anuld
          AND linestatus <> @zif_reing_ca_c=>line_status-anul_err
          AND ctuuid IS NOT INITIAL
        INTO TABLE @DATA(lt_has_orphan).
      SELECT DISTINCT calc_run_id FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_feat AND line_status <> 'PEND'
        INTO TABLE @DATA(lt_has_exportable).
      " Begin Insert V016 (CC) - F4
      " CU-13: Simulate habilitado si el RUN tiene >=1 linea en CALC/SIM_ERR;
      " Post si tiene >=1 en LIBD/POST_ERR; Storno si tiene >=1 en CONT.
      " Misma matriz que allowed_source_status (CLAR-03) -- si esa matriz
      " cambia, estos 3 SELECT deben acompanarla.
      SELECT DISTINCT calc_run_id FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_feat
          AND line_status IN ( @zif_reing_ca_c=>line_status-calc,
                               @zif_reing_ca_c=>line_status-sim_err )
        INTO TABLE @DATA(lt_has_simul).
      SELECT DISTINCT calc_run_id FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_feat
          AND line_status IN ( @zif_reing_ca_c=>line_status-libd,
                               @zif_reing_ca_c=>line_status-post_err )
        INTO TABLE @DATA(lt_has_post).
      SELECT DISTINCT calc_run_id FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_feat
          AND line_status IN ( @zif_reing_ca_c=>line_status-cont,
                               @zif_reing_ca_c=>line_status-post_err,
                               @zif_reing_ca_c=>line_status-anul_err )
        INTO TABLE @DATA(lt_has_storno).
      " End Insert V016 (CC) - F4
      LOOP AT lt_feat_flags ASSIGNING FIELD-SYMBOL(<ls_flag>).
        IF line_exists( lt_has_calc[ calc_run_id = <ls_flag>-calc_run_id ] ).
          <ls_flag>-has_calc = abap_true.
        ENDIF.
        IF line_exists( lt_has_orphan[ calc_run_id = <ls_flag>-calc_run_id ] ).
          <ls_flag>-has_orphan = abap_true.
        ENDIF.
        IF line_exists( lt_has_exportable[ calc_run_id = <ls_flag>-calc_run_id ] ).
          <ls_flag>-has_exportable = abap_true.
        ENDIF.
        " Begin Insert V016 (CC) - F4
        IF line_exists( lt_has_simul[ calc_run_id = <ls_flag>-calc_run_id ] ).
          <ls_flag>-has_simulable = abap_true.
        ENDIF.
        IF line_exists( lt_has_post[ calc_run_id = <ls_flag>-calc_run_id ] ).
          <ls_flag>-has_postable = abap_true.
        ENDIF.
        IF line_exists( lt_has_storno[ calc_run_id = <ls_flag>-calc_run_id ] ).
          <ls_flag>-has_stornoable = abap_true.
        ENDIF.
        " End Insert V016 (CC) - F4
      ENDLOOP.
    ENDIF.

    LOOP AT keys INTO DATA(ls_key).
      READ TABLE lt_feat_flags INTO DATA(ls_flags)
        WITH KEY calc_run_id = ls_key-CalcRunId.
      APPEND VALUE #(
        %tky                  = ls_key-%tky
        %action-Release       = COND #( WHEN ls_flags-has_calc       = abap_true THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-Delete        = COND #( WHEN ls_flags-has_orphan      = abap_true THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        " Begin Mod V016 (CC) - F4
        "%action-ExportExcel   = COND #( WHEN ls_flags-has_exportable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ) )
        %action-ExportExcel   = COND #( WHEN ls_flags-has_exportable = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Simulate      = COND #( WHEN ls_flags-has_simulable   = abap_true THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-Post          = COND #( WHEN ls_flags-has_postable    = abap_true THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-Storno        = COND #( WHEN ls_flags-has_stornoable  = abap_true THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled ) )
        " End Mod V016 (CC) - F4
        TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_consistency_for_release.
    " Chequeo imperativo previo a Release (reemplaza "validation on save { action }"
    " que no existe en RAP estandar). Invoca ZCL_REING_CA_INSUMO_MGR=>check_consistency.
    " IS_ORPHAN -> ev_has_orphan=X (error duro, Release bloqueado).
    " IS_STALE o receptoras cambiadas -> ev_has_warning=X (warning 412, usuario decide).
    DATA(lo_mgr) = NEW zcl_reing_ca_insumo_mgr( io_sources = NEW zcl_reing_ca_sources( ) ).
    " ATC fix (DB-in-loop): pasar fiscal_period/year y datos pre-cargados para evitar
    " los 4 SELECTs internos de check_consistency (detectados como NonLocal DBREAD).
    DATA(ls_check) = lo_mgr->check_consistency(
      it_group_lines   = it_lines
      iv_fiscal_period = iv_fiscal_period
      iv_fiscal_year   = iv_fiscal_year
      it_orphan_ctx    = it_orphan_ctx
      it_cm_changed    = it_cm_changed
      it_me_changed    = it_me_changed ).

    IF ls_check-is_orphan = abap_true.
      ev_has_orphan = abap_true.
      RETURN.
    ENDIF.

    IF ls_check-is_stale = abap_true
    OR it_lines IS NOT INITIAL AND ( ls_check-added_receptors IS NOT INITIAL
                                  OR ls_check-removed_receptors IS NOT INITIAL ).
      ev_has_warning = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD release.
    " F3.3-DD-1: Release es 100% sincrono -- no hay APJ.
    " Flujo: ConsistencyCheck -> ValidarCALC -> register_usage -> CALC->LIBD -> LOG_A.
    " F3.3-DD-5: solo acepta origen CALC en esta fase (sin SIM_OK todavia).
    "
    " Begin Change ID V025 (16.09.2026 | EXT_GONZALCA)
    " Misma clase de defecto corregida en CALCULATE -- ver la nota de cabecera
    " de ese metodo. Aqui son 6 sitios, todos de alcance "por key":
    "
    " (1) Dos contadores declarados con VALUE dentro de un loop:
    "     - LV_IDX_GRP_OP: desde el 2o key, LT_OP_RANGE_REL no recogia los
    "       op_type de ese key, asi que LT_OP_FLAGS_REL llegaba incompleto a
    "       REGISTER_USAGE_BULK.
    "     - LV_IDX_GL: desde el 2o key, LT_LINES quedaba vacio y Release
    "       respondia "No se encontraron lineas para el scope indicado" sin
    "       liberar nada.
    "
    " (2) Cuatro variables de alcance por key que no se reinicializaban:
    "     - LT_LINES: sin CLEAR, el key N+1 arrastraba las lineas del key N y
    "       les escribia LOG_A y el UPDATE de LINE_STATUS bajo el CalcRunId
    "       EQUIVOCADO -- corrupcion cruzada entre runs, la misma que V017
    "       cerro por otra via.
    "     - LS_RUN_CTX_R: el READ TABLE no se comprueba, asi que un run sin
    "       contexto legible reutilizaba el fiscal_period/fiscal_year del key
    "       anterior en el ConsistencyCheck.
    "     - LT_KEY_USAGES / LT_KEY_ME_H_IDS: son parametros EXPORTING, que el
    "       framework limpia en cada llamada -- pero NO si la llamada termina
    "       en el CATCH. En ese camino conservaban el contenido del key
    "       anterior, que se volvia a acumular en LT_ALL_USAGES y encima
    "       adelantaba LV_USG_NEXT_SEQ de mas.
    "
    " Los dos grupos van juntos: mientras (1) dejaba LT_LINES vacio, la fuga
    " de (2) no se manifestaba.
    " End Change ID V025 (16.09.2026 | EXT_GONZALCA)
    CHECK keys IS NOT INITIAL.

    " ATC fix (DB-in-loop): pre-fetch fiscal_period/year en bulk antes del LOOP AT keys
    " para evitar SELECT SINGLE dentro de check_consistency (via check_consistency_for_release).
    DATA lt_run_ctx_rel TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    DATA lt_run_range_rel TYPE RANGE OF zreing_ca_run_a-calc_run_id.
    LOOP AT keys INTO DATA(ls_key_pre_rel).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_key_pre_rel-CalcRunId ) TO lt_run_range_rel.
    ENDLOOP.
    IF lt_run_range_rel IS NOT INITIAL.
      SELECT calc_run_id, fiscal_period, fiscal_year
        FROM zreing_ca_run_a
        WHERE calc_run_id IN @lt_run_range_rel
        INTO CORRESPONDING FIELDS OF TABLE @lt_run_ctx_rel.
    ENDIF.

    " Begin Insert V009 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : pre-lectura de las entidades CalcRun para poder devolver
    " el RESULT real de la action. Ver la nota extensa en el LOOP AT keys,
    " donde se arma el result. Bulk y antes del loop, igual que el resto de
    " los pre-fetch de este metodo (ATC DB-in-loop).
    DATA lt_read_keys_rel TYPE TABLE FOR READ IMPORT zi_reingcarun.
    LOOP AT keys INTO DATA(ls_key_rd_rel).
      APPEND VALUE #( %tky = ls_key_rd_rel-%tky ) TO lt_read_keys_rel.
    ENDLOOP.
    READ ENTITIES OF zi_reingcarun IN LOCAL MODE
      ENTITY CalcRun
        ALL FIELDS WITH lt_read_keys_rel
        RESULT DATA(lt_run_entity_rel).
    " End Insert V009 (08.09.2026 | EXT_GONZALCA)

    " ATC fix (DB-in-loop): pre-cargar todas las LINE_A de todos los keys y grupos
    " en bulk ANTES del LOOP AT keys. Dentro del loop se filtra en memoria.
    DATA lt_lines_global TYPE zif_reing_ca_types=>ty_line_t.
    DATA lt_all_groups_rel TYPE zreing_ca_tt_group_key.
    LOOP AT keys INTO DATA(ls_key_grp_rel).
      APPEND LINES OF ls_key_grp_rel-%param-groups TO lt_all_groups_rel.
    ENDLOOP.
    SORT lt_all_groups_rel BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_all_groups_rel
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
    IF lt_all_groups_rel IS NOT INITIAL AND lt_run_range_rel IS NOT INITIAL.
      " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-10 --
      " se agrega is_delta a la lista explicita; check_consistency lo necesita
      " para distinguir un delta_pending real (linea aun no reflejando el
      " ultimo delta de CM_H_A) de una linea que ya es delta.
      SELECT calc_run_id, line_num, ct_uuid, ct_id, mat_uuid, matnr,
             op_type, op_uuid, cm_h_id, cm_load_seq, bukrs_recv, line_status,
             insumo_check_at, proc_started_at, is_delta
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_all_groups_rel
        WHERE calc_run_id IN @lt_run_range_rel
          AND ct_uuid   = @lt_all_groups_rel-ct_uuid
          AND mat_uuid  = @lt_all_groups_rel-mat_uuid
          AND op_type   = @lt_all_groups_rel-op_type
          AND op_uuid   = @lt_all_groups_rel-op_uuid
          AND cm_h_id   = @lt_all_groups_rel-cm_h_id
          AND line_status <> @zif_reing_ca_c=>line_status-anuld
          AND line_status <> @zif_reing_ca_c=>line_status-anul_err
        INTO CORRESPONDING FIELDS OF TABLE @lt_lines_global.
      " End Change ID V003 (04.08.2026 | EXT_GONZALCA)
    ENDIF.

    " ATC fix (DB-in-loop): acumuladores bulk para UPDATE/INSERT fuera del LOOP AT keys.
    "Begin Mod V017 (CC)
    " V017: was RANGE OF line_num; now (calc_run_id, line_num) pairs so the
    "       status UPDATE in save_modified is scoped to the correct RUN.
    "    DATA lt_bulk_line_nums TYPE RANGE OF zreing_ca_line_a-line_num.
    DATA lt_bulk_line_nums TYPE lcl_reing_ca_dml_buffer=>tt_line_del_key.
    "End Mod V017 (CC)
    DATA lt_bulk_log_rel   TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
    " ATC fix: instanciar lo_mgr una vez antes del LOOP AT keys (se usaba dentro del DO TIMES).
    DATA(lo_sources_rel) = NEW zcl_reing_ca_sources( ).
    DATA(lo_mgr)         = NEW zcl_reing_ca_insumo_mgr( io_sources = lo_sources_rel ).
    " ATC fix (NonLocal DBWRITE via register_usage_bulk): acumuladores globales de usages
    " para INSERT/UPDATE FUERA del LOOP AT keys.
    DATA lt_all_usages   TYPE zcl_reing_ca_insumo_mgr=>ty_usage_t.
    DATA lt_all_me_h_ids TYPE zcl_reing_ca_insumo_mgr=>ty_me_h_rang.
    " ATC fix (NonLocal SELECT via register_usage_bulk): pre-cargar los 3 contextos
    " que register_usage_bulk necesitaba internamente -- ahora se los pasamos como
    " parametros para que el metodo tenga CERO SELECTs propios.
    " A. run context (fiscal_period/year) -- ya disponible en lt_run_ctx_rel (pre-cargado arriba).
    " B. cm_loadable por op_type.
    DATA lt_op_flags_rel TYPE zcl_reing_ca_insumo_mgr=>ty_op_flag_t.
    DATA lt_op_range_rel TYPE RANGE OF zreing_op_type_c-op_type.
    " ATC fix (nested loop): DO TIMES en lugar del LOOP interno sobre groups.
    DATA ls_key_op_do LIKE LINE OF keys.
    DATA lv_idx_key_op TYPE i VALUE 1.
    DO lines( keys ) TIMES.
      READ TABLE keys INTO ls_key_op_do INDEX lv_idx_key_op.
      DATA ls_grp_op_do LIKE LINE OF ls_key_op_do-%param-groups.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defecto (1). Linea original: DATA lv_idx_grp_op TYPE i VALUE 1.
      DATA lv_idx_grp_op TYPE i.
      lv_idx_grp_op = 1.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      DO lines( ls_key_op_do-%param-groups ) TIMES.
        READ TABLE ls_key_op_do-%param-groups INTO ls_grp_op_do INDEX lv_idx_grp_op.
        IF NOT line_exists( lt_op_range_rel[ low = ls_grp_op_do-op_type ] ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_grp_op_do-op_type ) TO lt_op_range_rel.
        ENDIF.
        lv_idx_grp_op = lv_idx_grp_op + 1.
      ENDDO.
      lv_idx_key_op = lv_idx_key_op + 1.
    ENDDO.
    IF lt_op_range_rel IS NOT INITIAL.
      SELECT op_type, cm_loadable
        FROM zreing_op_type_c
        WHERE op_type IN @lt_op_range_rel
        INTO CORRESPONDING FIELDS OF TABLE @lt_op_flags_rel.
    ENDIF.
    " C. MAX(usage_id) del dia -- un solo SELECT antes del LOOP AT keys.
    DATA(lv_usg_today)   = sy-datum.
    DATA(lv_usg_pattern) = |USG-{ lv_usg_today }-%|.
    DATA lv_usg_max_id   TYPE zreing_calcusage-usage_id.
    SELECT SINGLE MAX( usage_id ) AS usage_id
      FROM zreing_calcusage
      WHERE usage_id LIKE @lv_usg_pattern
      INTO @lv_usg_max_id.
    TYPES ty_usg_seq TYPE n LENGTH 6.
    DATA lv_usg_next_seq TYPE ty_usg_seq.
    lv_usg_next_seq = COND ty_usg_seq( WHEN lv_usg_max_id IS INITIAL THEN '000001'
                                        ELSE |{ CONV ty_usg_seq( lv_usg_max_id+13(6) ) + 1 }| ).

    " ATC fix (NonLocal DBREAD via check_consistency): pre-cargar los 3 contextos
    " que check_consistency necesita internamente -- ANTES del LOOP AT keys.
    " D. is_orphan desde zc_reingcalineall.
    DATA lt_orphan_ctx_rel TYPE zcl_reing_ca_insumo_mgr=>tt_orphan_ctx.
    IF lt_all_groups_rel IS NOT INITIAL.
      DATA lt_all_lines_for_orphan TYPE zif_reing_ca_types=>ty_line_t.
      DATA ls_ln_o LIKE LINE OF lt_lines_global.
      DATA lv_idx_o TYPE i VALUE 1.
      DO lines( lt_lines_global ) TIMES.
        READ TABLE lt_lines_global INTO ls_ln_o INDEX lv_idx_o.
        APPEND ls_ln_o TO lt_all_lines_for_orphan.
        lv_idx_o = lv_idx_o + 1.
      ENDDO.
      SORT lt_all_lines_for_orphan BY ct_uuid mat_uuid op_type op_uuid bukrs_recv.
      DELETE ADJACENT DUPLICATES FROM lt_all_lines_for_orphan
        COMPARING ct_uuid mat_uuid op_type op_uuid bukrs_recv.
      " Construir ranges de periodo desde lt_run_ctx_rel.
      DATA lt_orp_year_range  TYPE RANGE OF zc_reingcalineall-periodyear.
      DATA lt_orp_month_range TYPE RANGE OF zc_reingcalineall-periodmonth.
      DATA ls_ctx_orp LIKE LINE OF lt_run_ctx_rel.
      DATA lv_idx_ctx_orp TYPE i VALUE 1.
      DO lines( lt_run_ctx_rel ) TIMES.
        READ TABLE lt_run_ctx_rel INTO ls_ctx_orp INDEX lv_idx_ctx_orp.
        IF NOT line_exists( lt_orp_year_range[ low = ls_ctx_orp-fiscal_year ] ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_ctx_orp-fiscal_year ) TO lt_orp_year_range.
        ENDIF.
        IF NOT line_exists( lt_orp_month_range[ low = ls_ctx_orp-fiscal_period ] ).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_ctx_orp-fiscal_period ) TO lt_orp_month_range.
        ENDIF.
        lv_idx_ctx_orp = lv_idx_ctx_orp + 1.
      ENDDO.
      IF lt_all_lines_for_orphan IS NOT INITIAL AND lt_orp_year_range IS NOT INITIAL.
        SELECT ctuuid, matuuid, optype, opuuid, bukrsrecv, isorphan
          FROM zc_reingcalineall
          FOR ALL ENTRIES IN @lt_all_lines_for_orphan
          WHERE ctuuid    = @lt_all_lines_for_orphan-ct_uuid
            AND matuuid   = @lt_all_lines_for_orphan-mat_uuid
            AND optype    = @lt_all_lines_for_orphan-op_type
            AND opuuid    = @lt_all_lines_for_orphan-op_uuid
            AND bukrsrecv = @lt_all_lines_for_orphan-bukrs_recv
            AND periodyear  IN @lt_orp_year_range
            AND periodmonth IN @lt_orp_month_range
          INTO TABLE @DATA(lt_orphan_raw2).
        DATA ls_orp LIKE LINE OF lt_orphan_raw2.
        DATA lv_idx_orp TYPE i VALUE 1.
        DO lines( lt_orphan_raw2 ) TIMES.
          READ TABLE lt_orphan_raw2 INTO ls_orp INDEX lv_idx_orp.
          APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_orphan_ctx(
            ct_uuid    = ls_orp-ctuuid
            mat_uuid   = ls_orp-matuuid
            op_type    = ls_orp-optype
            op_uuid    = ls_orp-opuuid
            bukrs_recv = ls_orp-bukrsrecv
            is_orphan  = ls_orp-isorphan ) TO lt_orphan_ctx_rel.
          lv_idx_orp = lv_idx_orp + 1.
        ENDDO.
      ENDIF.
    ENDIF.
    " E. cm_changed_at desde zreing_cm_h_a.
    DATA lt_cm_changed_rel TYPE zcl_reing_ca_insumo_mgr=>tt_cm_changed.
    IF lt_all_groups_rel IS NOT INITIAL AND lt_orp_year_range IS NOT INITIAL.
      " FOR ALL ENTRIES no admite GROUP BY -- SELECT todos los rows y MAX en ABAP.
      DATA lt_cm_raw TYPE STANDARD TABLE OF zreing_cm_h_a WITH EMPTY KEY.
      SELECT ct_uuid, mat_uuid, op_type, cm_h_id, changed_at
        FROM zreing_cm_h_a
        FOR ALL ENTRIES IN @lt_all_groups_rel
        WHERE ct_uuid      = @lt_all_groups_rel-ct_uuid
          AND mat_uuid     = @lt_all_groups_rel-mat_uuid
          AND op_type      = @lt_all_groups_rel-op_type
          AND cm_h_id       = @lt_all_groups_rel-cm_h_id
          AND period_year  IN @lt_orp_year_range
          AND period_month IN @lt_orp_month_range
        INTO CORRESPONDING FIELDS OF TABLE @lt_cm_raw.
      " MAX por grupo en ABAP puro.
      DATA ls_cm_raw LIKE LINE OF lt_cm_raw.
      DATA lv_idx_cm TYPE i VALUE 1.
      DO lines( lt_cm_raw ) TIMES.
        READ TABLE lt_cm_raw INTO ls_cm_raw INDEX lv_idx_cm.
        ASSIGN lt_cm_changed_rel[
          ct_uuid  = ls_cm_raw-ct_uuid
          mat_uuid = ls_cm_raw-mat_uuid
          op_type  = ls_cm_raw-op_type
          cm_h_id   = ls_cm_raw-cm_h_id ] TO FIELD-SYMBOL(<ls_cm_chg>).
        IF sy-subrc = 0.
          IF ls_cm_raw-changed_at > <ls_cm_chg>-changed_at.
            <ls_cm_chg>-changed_at = ls_cm_raw-changed_at.
          ENDIF.
        ELSE.
          APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_cm_changed(
            ct_uuid    = ls_cm_raw-ct_uuid
            mat_uuid   = ls_cm_raw-mat_uuid
            op_type    = ls_cm_raw-op_type
            cm_h_id     = ls_cm_raw-cm_h_id
            changed_at = ls_cm_raw-changed_at ) TO lt_cm_changed_rel.
        ENDIF.
        lv_idx_cm = lv_idx_cm + 1.
      ENDDO.
    ENDIF.
    " F. me_changed_at desde zreing_me_h_a -- driver: ct_id + matnr de lt_lines_global.
    DATA lt_me_changed_rel TYPE zcl_reing_ca_insumo_mgr=>tt_me_changed.
    DATA lt_me_driver TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
    DATA ls_ln_me LIKE LINE OF lt_lines_global.
    DATA lv_idx_me TYPE i VALUE 1.
    DO lines( lt_lines_global ) TIMES.
      READ TABLE lt_lines_global INTO ls_ln_me INDEX lv_idx_me.
      IF NOT line_exists( lt_me_driver[ ct_id = ls_ln_me-ct_id matnr = ls_ln_me-matnr ] ).
        APPEND VALUE zreing_me_h_a( ct_id = ls_ln_me-ct_id matnr = ls_ln_me-matnr )
          TO lt_me_driver.
      ENDIF.
      lv_idx_me = lv_idx_me + 1.
    ENDDO.
    IF lt_me_driver IS NOT INITIAL AND lt_orp_year_range IS NOT INITIAL.
      " FOR ALL ENTRIES no admite GROUP BY -- SELECT todos los rows y MAX en ABAP.
      DATA lt_me_raw TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
      SELECT ct_id, matnr, last_changed_at
        FROM zreing_me_h_a
        FOR ALL ENTRIES IN @lt_me_driver
        WHERE ct_id        = @lt_me_driver-ct_id
          AND matnr        = @lt_me_driver-matnr
          AND period_year  IN @lt_orp_year_range
          AND period_month IN @lt_orp_month_range
        INTO CORRESPONDING FIELDS OF TABLE @lt_me_raw.
      " MAX por grupo en ABAP puro.
      DATA ls_me_raw LIKE LINE OF lt_me_raw.
      DATA lv_idx_mer TYPE i VALUE 1.
      DO lines( lt_me_raw ) TIMES.
        READ TABLE lt_me_raw INTO ls_me_raw INDEX lv_idx_mer.
        ASSIGN lt_me_changed_rel[
          ct_id = ls_me_raw-ct_id
          matnr = ls_me_raw-matnr ] TO FIELD-SYMBOL(<ls_me_chg>).
        IF sy-subrc = 0.
          IF ls_me_raw-last_changed_at > <ls_me_chg>-last_changed_at.
            <ls_me_chg>-last_changed_at = ls_me_raw-last_changed_at.
          ENDIF.
        ELSE.
          APPEND VALUE zcl_reing_ca_insumo_mgr=>ty_me_changed(
            ct_id           = ls_me_raw-ct_id
            matnr           = ls_me_raw-matnr
            last_changed_at = ls_me_raw-last_changed_at ) TO lt_me_changed_rel.
        ENDIF.
        lv_idx_mer = lv_idx_mer + 1.
      ENDDO.
    ENDIF.

    LOOP AT keys INTO DATA(ls_key).
      " Begin Mod V009 (08.09.2026 | EXT_GONZALCA)
      " Descripcion : el RESULT de la action se armaba con
      " "%param = CORRESPONDING #( ls_key-%param )", o sea con el PARAMETRO
      " DE ENTRADA (ZREING_CA_S_ACTION_SCOPE, la tabla de grupos), no con la
      " entidad de retorno. Como el BDEF declara "result [1] $self", el
      " %param del result es la entidad CalcRun, y el CORRESPONDING entre dos
      " estructuras sin campos en comun dejaba TODO vacio: el payload OData
      " devolvia CalcRunId = "", FiscalPeriod = "0", FiscalYear = "0000",
      " TotalLines = 0, TotalGroups = 0 y, al no poder resolver la instancia,
      " todos los flags de OperationControl en false.
      " Ahora se devuelve la entidad realmente leida (pre-lectura bulk arriba).
      " Nota de alcance: la transicion a LIBD la aplica save_modified en la
      " fase Save, POSTERIOR a este metodo, asi que LineStatus de las hijas
      " no puede reflejarse todavia aca -- para eso esta el side effect
      " "action Release affects ... entity _Line" del BDEF, que hace que
      " Fiori Elements recargue las lineas despues del save.
      " Linea original conservada como referencia:
      "    result = VALUE #( BASE result
      "      ( %tky = ls_key-%tky %param = CORRESPONDING #( ls_key-%param ) ) ).
      READ TABLE lt_run_entity_rel INTO DATA(ls_run_entity)
        WITH KEY CalcRunId = ls_key-CalcRunId.
      IF sy-subrc = 0.
        result = VALUE #( BASE result
          ( %tky = ls_key-%tky %param = CORRESPONDING #( ls_run_entity ) ) ).
      ELSE.
        " Sin entidad legible (borrada o sin autorizacion): se devuelve al
        " menos la clave, para que el consumidor sepa de que run se le habla.
        result = VALUE #( BASE result
          ( %tky = ls_key-%tky %param = VALUE #( CalcRunId = ls_key-CalcRunId ) ) ).
      ENDIF.
      " End Mod V009 (08.09.2026 | EXT_GONZALCA)

      " ATC fix (DB-in-loop): filtrar lt_lines desde tabla pre-cargada en memoria.
      DATA lt_lines TYPE zif_reing_ca_types=>ty_line_t.
      DATA ls_grp_key LIKE LINE OF ls_key-%param-groups.
      DATA ls_gl_line LIKE LINE OF lt_lines_global.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defecto (2): LT_LINES es de alcance por key y alimenta LOG_A y el
      " UPDATE de LINE_STATUS con el CalcRunId de ESTE key.
      " Defecto (1): linea original DATA lv_idx_gl TYPE i VALUE 1.
      CLEAR lt_lines.
      DATA lv_idx_gl TYPE i.
      lv_idx_gl = 1.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      DO lines( lt_lines_global ) TIMES.
        READ TABLE lt_lines_global INTO ls_gl_line INDEX lv_idx_gl.
        IF ls_gl_line-calc_run_id = ls_key-CalcRunId.
          APPEND ls_gl_line TO lt_lines.
        ENDIF.
        lv_idx_gl = lv_idx_gl + 1.
      ENDDO.

      IF lt_lines IS INITIAL.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = 'No se encontraron lineas para el scope indicado' ) ) TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        CONTINUE.
      ENDIF.

      " Step 1: ConsistencyCheck (IS_ORPHAN=error duro, IS_STALE=warning 412).
      DATA lv_has_orphan  TYPE abap_bool.
      DATA lv_has_warning TYPE abap_bool.
      DATA ls_run_ctx_r TYPE zreing_ca_run_a.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defecto (2): sin este CLEAR, un run sin fila en LT_RUN_CTX_REL
      " reutilizaba el periodo del key anterior (el READ no se comprueba).
      CLEAR ls_run_ctx_r.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      READ TABLE lt_run_ctx_rel INTO ls_run_ctx_r WITH KEY calc_run_id = ls_key-CalcRunId.
      check_consistency_for_release(
        EXPORTING iv_run_id        = ls_key-CalcRunId
                  it_lines         = lt_lines
                  iv_fiscal_period = ls_run_ctx_r-fiscal_period
                  iv_fiscal_year   = ls_run_ctx_r-fiscal_year
                  it_orphan_ctx    = lt_orphan_ctx_rel
                  it_cm_changed    = lt_cm_changed_rel
                  it_me_changed    = lt_me_changed_rel
        IMPORTING ev_has_orphan    = lv_has_orphan
                  ev_has_warning   = lv_has_warning ).

      IF lv_has_orphan = abap_true.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " 71 caracteres: el operador leia "El grupo contiene lineas huerfanas
        " (IS_ORPHAN). Use Delet" y perdia la instruccion de que hacer.
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = 'El grupo contiene lineas huerfanas (IS_ORPHAN). Use Delete en su lugar.' ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        CONTINUE.
      ENDIF.

      IF lv_has_warning = abap_true.
        " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-10 --
        " se reconsulta check_consistency directamente (mismos parametros
        " pre-cargados, CERO SELECT adicional salvo el TRY get_cm_amount que
        " ya hace el propio metodo) solo para distinguir si la causa de
        " IS_STALE es un delta de CM_H_A pendiente de recalcular (BR-CA-41),
        " y dar un mensaje mas especifico que el generico.
        DATA(ls_check_delta) = lo_mgr->check_consistency(
          it_group_lines   = lt_lines
          iv_fiscal_period = ls_run_ctx_r-fiscal_period
          iv_fiscal_year   = ls_run_ctx_r-fiscal_year
          it_orphan_ctx    = lt_orphan_ctx_rel
          it_cm_changed    = lt_cm_changed_rel
          it_me_changed    = lt_me_changed_rel ).

        DATA(lv_warning_text) = COND string(
          WHEN ls_check_delta-delta_pending = abap_true
          THEN 'Se detecto una carga delta de CM pendiente de recalcular (BR-CA-41). ' &&
               'Se recomienda recalcular antes de continuar.'
          ELSE 'Los insumos del grupo fueron modificados despues del ultimo calculo. ' &&
               'Se recomienda recalcular antes de continuar.' ).

        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " Las dos variantes rondan los 110 caracteres: hasta hoy la
        " recomendacion de recalcular no llegaba nunca al operador.
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity    = if_abap_behv_message=>severity-warning
          text        = lv_warning_text ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        " End Change ID V003 (04.08.2026 | EXT_GONZALCA)
      ENDIF.

      " Step 2: Validar que TODAS las lineas del scope esten en CALC (BR-CA-34).
      DATA ls_line LIKE LINE OF lt_lines.
      DATA lv_idx_val TYPE i.
      lv_idx_val = 1.
      DO lines( lt_lines ) TIMES.
        READ TABLE lt_lines INTO ls_line INDEX lv_idx_val.
        " Begin Mod V016 (CC) - F4
        " F3.3-DD-5 dejo diferido a F4 que Release acepte tambien SIM_OK
        " (cadena CALC -> Simulate -> SIM_OK -> Release -> LIBD). BR-F4-05.
        "IF ls_line-line_status <> zif_reing_ca_c=>line_status-calc.
        IF ls_line-line_status <> zif_reing_ca_c=>line_status-calc
       AND ls_line-line_status <> zif_reing_ca_c=>line_status-sim_ok.
          " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
          " ~75 caracteres: el estado actual, que es el dato util para saber
          " que hacer, quedaba fuera del corte.
          APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error
            "text = |Linea { ls_line-line_num } no esta en estado CALC (estado actual: { ls_line-line_status }).| ) )
            text = |Linea { ls_line-line_num } no esta en estado CALC ni SIM_OK (estado actual: { ls_line-line_status }).| ) )
            TO reported-calcrun.
          " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        ENDIF.
        " End Mod V016 (CC) - F4
        lv_idx_val = lv_idx_val + 1.
      ENDDO.

      " Begin Mod V009 (08.09.2026 | EXT_GONZALCA)
      " Descripcion : separacion de severidades. El CHECK original --
      " "CHECK NOT line_exists( reported-calcrun[ %tky = ls_key-%tky ] )." --
      " cortaba el flujo ante la MERA EXISTENCIA de un mensaje reportado para
      " la clave, sin mirar la severidad. Como el warning de insumos
      " modificados (IS_STALE) se agrega unas lineas mas arriba a esa misma
      " tabla, un grupo con insumos "stale" nunca llegaba a registrar el uso,
      " ni a pasar a LIBD, ni a escribir LOG_A -- y la action igual devolvia
      " HTTP 200. Esa es la causa del sintoma reportado desde TS4-400:
      " "Release responde 200 con warning pero no libera".
      " Combinado con el bug de PROC_STARTED_AT (V004 de
      " ZCL_REING_CA_CALC_JOB, corregido el mismo dia), que dejaba a TODO
      " grupo marcado como stale, el resultado era que Release no liberaba
      " NUNCA por Path A.
      " Ahora solo un mensaje de severidad ERROR aborta el grupo.
      " ATENCION -- SEMANTICA PROVISIONAL: la ET SS2.12 pide warning con
      " CONFIRMACION EXPLICITA del usuario (doble dialogo
      " [Recalcular][Continuar][Cancelar]), y ese mecanismo NO existe todavia:
      " la accion WarnAck que debia grabar INSUMO_CHECK_AT nunca se
      " construyo, y el dialogo nativo 412 sigue sin verificar (P3.3-1).
      " Hasta que se implemente, el comportamiento es "avisar y continuar",
      " que es lo mas cercano a la intencion funcional -- pero NO es la
      " semantica final. Ver el sync escalado del 08.09.2026.
      " ATC fix (Loops anidados): DO...TIMES + READ TABLE INDEX en vez de
      " LOOP AT reported-calcrun dentro del LOOP AT keys -- mismo patron
      " anti-nested-loop que el resto de este objeto.
      " Linea original conservada como referencia:
      "    CHECK NOT line_exists( reported-calcrun[ %tky = ls_key-%tky ] ).
      DATA lv_has_error_rel TYPE abap_bool.
      DATA ls_rep_rel       LIKE LINE OF reported-calcrun.
      DATA lv_idx_rep       TYPE i.
      CLEAR lv_has_error_rel.
      lv_idx_rep = 1.
      DO lines( reported-calcrun ) TIMES.
        READ TABLE reported-calcrun INTO ls_rep_rel INDEX lv_idx_rep.
        lv_idx_rep = lv_idx_rep + 1.
        IF ls_rep_rel-%tky <> ls_key-%tky.
          CONTINUE.
        ENDIF.
        IF ls_rep_rel-%msg IS BOUND
       AND ls_rep_rel-%msg->m_severity = if_abap_behv_message=>severity-error.
          lv_has_error_rel = abap_true.
        ENDIF.
      ENDDO.
      CHECK lv_has_error_rel = abap_false.
      " End Mod V009 (08.09.2026 | EXT_GONZALCA)

      " Step 3: register_usage_bulk -- CERO SELECT (todos los datos vienen pre-cargados).
      " ATC fix (NonLocal DBREAD/DBWRITE): it_runs, it_op_flags, iv_next_seq pre-cargados
      " en release ANTES del LOOP AT keys. Solo logica ABAP pura dentro del metodo.
      DATA lt_key_usages   TYPE zcl_reing_ca_insumo_mgr=>ty_usage_t.
      DATA lt_key_me_h_ids TYPE zcl_reing_ca_insumo_mgr=>ty_me_h_rang.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defecto (2). Son parametros EXPORTING, asi que el framework los limpia
      " en cada llamada -- pero NO si la llamada sale por el CATCH de abajo.
      " En ese camino conservaban lo del key anterior, que se volvia a sumar a
      " LT_ALL_USAGES y adelantaba LV_USG_NEXT_SEQ de mas.
      CLEAR lt_key_usages.
      CLEAR lt_key_me_h_ids.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      TRY.
          lo_mgr->register_usage_bulk(
            EXPORTING it_lines    = lt_lines
                      it_runs     = CORRESPONDING zcl_reing_ca_insumo_mgr=>ty_run_ctx_t( lt_run_ctx_rel )
                      it_op_flags = lt_op_flags_rel
                      iv_next_seq = lv_usg_next_seq
            IMPORTING et_usages   = lt_key_usages
                      et_me_h_ids = lt_key_me_h_ids ).
        CATCH zcx_reing_ca_calc_error INTO DATA(lx_usage_bulk).
          " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
          " El prefijo consume 34 de los 50 caracteres, asi que del mensaje
          " real del manager solo sobrevivian 16.
          APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error
            text = |Error al registrar uso de insumo: { lx_usage_bulk->mv_message }| ) )
            TO reported-calcrun.
          " End Mod V020 (09.09.2026 | EXT_GONZALCA)
      ENDTRY.
      " Avanzar el secuenciador para el proximo key (evita duplicar usage_ids).
      lv_usg_next_seq = lv_usg_next_seq + lines( lt_key_usages ).
      APPEND LINES OF lt_key_usages   TO lt_all_usages.
      APPEND LINES OF lt_key_me_h_ids TO lt_all_me_h_ids.

      " Step 4: acumular LINE_NUMS y LOG_A para UPDATE/INSERT bulk fuera del LOOP AT keys.
      DATA(lv_ts) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
      DATA lv_idx_acc TYPE i.
      lv_idx_acc = 1.
      DO lines( lt_lines ) TIMES.
        READ TABLE lt_lines INTO ls_line INDEX lv_idx_acc.
        "Begin Mod V017 (CC)
        " V017: keep calc_run_id together with line_num for this line.
        "        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_line-line_num ) TO lt_bulk_line_nums.
        APPEND VALUE #( calc_run_id = ls_key-CalcRunId
                        line_num    = ls_line-line_num ) TO lt_bulk_line_nums.
        "End Mod V017 (CC)
        APPEND VALUE zreing_ca_log_a(
          calc_run_id  = ls_key-CalcRunId
          line_num     = ls_line-line_num
          log_num      = 0 " V011: placeholder, recalculado en save_modified
          action       = zif_reing_ca_c=>action-release
          " Begin Mod V016 (CC) - F4
          " Con SIM_OK admitido como origen, hardcodear status_from = CALC
          " registraria una transicion falsa en LOG_A.
          "status_from  = zif_reing_ca_c=>line_status-calc
          status_from  = ls_line-line_status
          " End Mod V016 (CC) - F4
          status_to    = 'LIBD'
          created_by   = sy-uname
          created_at   = lv_ts
          message      = 'Release: CALC->LIBD registrado (ET SS2.8)' )
          TO lt_bulk_log_rel.
        lv_idx_acc = lv_idx_acc + 1.
      ENDDO.
    ENDLOOP.

    " Begin Change ID V010 (17.07.2026 | EXT_GONZALCA)
    " Fix RUNTIME_ERROR BEHAVIOR_ILLEGAL_STATEMENT: UPDATE/INSERT directos
    " prohibidos en fase Modify -- se acumulan en el buffer estatico y se
    " ejecutan en save_modified (fase Save). Ver lcl_reing_ca_dml_buffer.
    "Begin Mod V017 (CC)
    " V017: propagate calc_run_id into gt_line_status so save_modified can
    "       update the status of the right RUN. No DB op inside the loop (BR-4).
    DATA ls_bulk_num LIKE LINE OF lt_bulk_line_nums.
    DATA lv_idx_bn TYPE i VALUE 1.
    DO lines( lt_bulk_line_nums ) TIMES.
      READ TABLE lt_bulk_line_nums INTO ls_bulk_num INDEX lv_idx_bn.
      "      APPEND VALUE #( line_num = ls_bulk_num-low line_status = 'LIBD' )
      "        TO lcl_reing_ca_dml_buffer=>gt_line_status.
      APPEND VALUE #( calc_run_id = ls_bulk_num-calc_run_id
                      line_num    = ls_bulk_num-line_num
                      line_status = 'LIBD' )
        TO lcl_reing_ca_dml_buffer=>gt_line_status.
      "End Mod V017 (CC)
      lv_idx_bn = lv_idx_bn + 1.
    ENDDO.
    APPEND LINES OF lt_bulk_log_rel TO lcl_reing_ca_dml_buffer=>gt_log.
    APPEND LINES OF lt_all_usages   TO lcl_reing_ca_dml_buffer=>gt_usage.
    APPEND LINES OF lt_all_me_h_ids TO lcl_reing_ca_dml_buffer=>gt_me_h_libr.
    " End Change ID V010 (17.07.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD delete.
    " F3.3-DD-3: Delete elimina grupos IS_ORPHAN. LOG_A, LINE_A/PC/STEP por SQL directo.
    " F3.3-DD-4: scope mixto (huerfano+sano) -> error bloqueante, nada se borra.
    "
    " Begin Change ID V025 (16.09.2026 | EXT_GONZALCA)
    " Misma clase de defecto corregida en CALCULATE -- ver la nota de cabecera
    " de ese metodo para la explicacion completa. Aqui son 7 sitios:
    "
    " (1) Cuatro declaraciones con VALUE dentro de un loop, que por lo tanto
    "     NO se reinicializan en cada iteracion:
    "     - LV_IDX_ALG: desde el 2o key, LT_ALL_LINES quedaba vacio y Delete
    "       respondia "No se encontraron lineas para el scope indicado" sin
    "       borrar nada.
    "     - LV_IDX_NO: desde el 2o key, LT_NON_ORPHAN_GRPS quedaba vacio y el
    "       guard de scope mixto (F3.3-DD-4) dejaba de detectar los grupos NO
    "       huerfanos -- Delete habria seguido adelante sobre lineas sanas.
    "     - LV_IDX_K: el peor de los cuatro, porque NO necesita un bulk
    "       multi-key para fallar: vive dentro del DO sobre
    "       LT_NON_ORPHAN_GLOBAL, asi que a partir de la SEGUNDA fila non
    "       orphan el READ INDEX ya no encontraba nada, LV_FOUND_IN_KEY
    "       quedaba en false y el grupo no se acumulaba. Con un solo key y 2+
    "       grupos no huerfanos en el sistema, el guard ya estaba degradado.
    "     - LV_FOUND_IN_KEY: mismo defecto en el sentido CONTRARIO. Es un flag
    "       con VALUE ABAP_FALSE dentro del DO, asi que una vez puesto en true
    "       por una fila se quedaba pegado para TODAS las siguientes, y grupos
    "       que no pertenecen al key se acumulaban como si pertenecieran. Los
    "       dos errores conviven y se tapan entre si segun el orden de las
    "       filas, que es lo que hacia el sintoma erratico.
    "
    " (2) Tres variables de trabajo por key que nunca se reinicializaban:
    "     - LT_ALL_LINES: sin CLEAR, el key N+1 arrastraba las lineas del key
    "       N y sus line_num se volvian a acumular en LT_BULK_DEL_NUMS bajo el
    "       CalcRunId EQUIVOCADO (borrado cruzado entre runs, exactamente lo
    "       que V017 vino a cerrar por otra via).
    "     - LT_NON_ORPHAN_GRPS y LV_HAS_NON_ORPHAN: sin reset, un scope mixto
    "       en el key N bloqueaba tambien a todos los keys siguientes.
    "
    " Los dos grupos van juntos: mientras (1) dejaba las tablas vacias, (2) no
    " se notaba; al arreglar los contadores la fuga entre iteraciones se
    " activa.
    " End Change ID V025 (16.09.2026 | EXT_GONZALCA)
    CHECK keys IS NOT INITIAL.

    " ATC fix (DB-in-loop): acumuladores bulk para DMLs fuera del LOOP AT keys.
    TYPES: BEGIN OF ty_line_num_range,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE zreing_ca_line_a-line_num,
             high   TYPE zreing_ca_line_a-line_num,
           END OF ty_line_num_range,
           tt_line_num TYPE STANDARD TABLE OF ty_line_num_range WITH EMPTY KEY.
    TYPES: BEGIN OF ty_del_batch,
             calc_run_id TYPE zreing_ca_run_a-calc_run_id,
             line_nums   TYPE tt_line_num,
           END OF ty_del_batch.
    DATA lt_bulk_log_del  TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
    DATA lt_bulk_del_nums TYPE STANDARD TABLE OF ty_del_batch     WITH EMPTY KEY.
    DATA lt_bulk_run_ids  TYPE STANDARD TABLE OF zreing_ca_run_a-calc_run_id WITH EMPTY KEY.

    " ATC fix (DB-in-loop): pre-cargar non_orphan check en bulk ANTES del LOOP AT keys.
    " zc_reingcalineall no tiene calc_run_id -- filtramos solo por grupo en FAE global.
    DATA lt_non_orphan_global TYPE zreing_ca_tt_group_key.
    DATA lt_all_groups_del    TYPE zreing_ca_tt_group_key.
    LOOP AT keys INTO DATA(ls_key_grp_del).
      APPEND LINES OF ls_key_grp_del-%param-groups TO lt_all_groups_del.
    ENDLOOP.
    SORT lt_all_groups_del BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_all_groups_del
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
    IF lt_all_groups_del IS NOT INITIAL.
      SELECT ctuuid AS ct_uuid, matuuid AS mat_uuid, optype AS op_type,
             opuuid AS op_uuid, cmhid AS cm_h_id
        FROM zc_reingcalineall
        FOR ALL ENTRIES IN @lt_all_groups_del
        WHERE ctuuid   = @lt_all_groups_del-ct_uuid
          AND matuuid  = @lt_all_groups_del-mat_uuid
          AND optype   = @lt_all_groups_del-op_type
          AND opuuid   = @lt_all_groups_del-op_uuid
          AND cmhid    = @lt_all_groups_del-cm_h_id
          AND linestatus <> @zif_reing_ca_c=>line_status-anuld
          AND linestatus <> @zif_reing_ca_c=>line_status-anul_err
          AND isorphan <> @abap_true
        INTO CORRESPONDING FIELDS OF TABLE @lt_non_orphan_global.
    ENDIF.

    " ATC fix (DB-in-loop): pre-cargar lt_all_lines_global en bulk ANTES del LOOP AT keys.
    " Driver: todos los grupos de todos los keys + range de calc_run_ids.
    DATA lt_all_lines_global TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    DATA lt_run_range_del2   TYPE RANGE OF zreing_ca_run_a-calc_run_id.
    LOOP AT keys INTO DATA(ls_key_rid).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_key_rid-CalcRunId ) TO lt_run_range_del2.
    ENDLOOP.
    IF lt_all_groups_del IS NOT INITIAL AND lt_run_range_del2 IS NOT INITIAL.
      SELECT calc_run_id, line_num, ct_uuid, mat_uuid, op_type, op_uuid,
             cm_h_id, cm_load_seq, line_status
        FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_all_groups_del
        WHERE calc_run_id IN @lt_run_range_del2
          AND ct_uuid   = @lt_all_groups_del-ct_uuid
          AND mat_uuid  = @lt_all_groups_del-mat_uuid
          AND op_type   = @lt_all_groups_del-op_type
          AND op_uuid   = @lt_all_groups_del-op_uuid
          AND cm_h_id   = @lt_all_groups_del-cm_h_id
          AND line_status <> @zif_reing_ca_c=>line_status-anuld
          AND line_status <> @zif_reing_ca_c=>line_status-anul_err
        INTO CORRESPONDING FIELDS OF TABLE @lt_all_lines_global.
    ENDIF.

    LOOP AT keys INTO DATA(ls_key).
      result = VALUE #( BASE result
        ( %tky = ls_key-%tky %param = CORRESPONDING #( ls_key-%param ) ) ).

      " ATC fix (DB-in-loop): filtrar lt_all_lines desde tabla pre-cargada en memoria.
      DATA lt_all_lines      TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
      DATA lv_has_non_orphan TYPE abap_bool.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defecto (2). Las dos son de alcance por key y no se reiniciaban.
      CLEAR lt_all_lines.
      CLEAR lv_has_non_orphan.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)

      IF ls_key-%param-groups IS NOT INITIAL.
        DATA lt_groups_del2 TYPE zreing_ca_tt_group_key.
        lt_groups_del2 = ls_key-%param-groups.
        DATA ls_alg LIKE LINE OF lt_all_lines_global.
        " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
        " Defecto (1). Linea original: DATA lv_idx_alg TYPE i VALUE 1.
        DATA lv_idx_alg TYPE i.
        lv_idx_alg = 1.
        " End Mod V025 (16.09.2026 | EXT_GONZALCA)
        DO lines( lt_all_lines_global ) TIMES.
          READ TABLE lt_all_lines_global INTO ls_alg INDEX lv_idx_alg.
          IF ls_alg-calc_run_id = ls_key-CalcRunId.
            APPEND ls_alg TO lt_all_lines.
          ENDIF.
          lv_idx_alg = lv_idx_alg + 1.
        ENDDO.
      ENDIF.

      IF lt_all_lines IS INITIAL.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = 'No se encontraron lineas para el scope indicado' ) ) TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        CONTINUE.
      ENDIF.

      DATA lt_non_orphan_grps TYPE zreing_ca_tt_group_key.
      " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
      " Defecto (2). Sin este CLEAR, un scope mixto en un key bloqueaba
      " tambien a los keys siguientes.
      CLEAR lt_non_orphan_grps.
      " End Mod V025 (16.09.2026 | EXT_GONZALCA)
      IF ls_key-%param-groups IS NOT INITIAL.
        IF lt_groups_del2 IS NOT INITIAL.
          " ATC fix (DB-in-loop): filtrar desde tabla pre-cargada en lugar de SELECT en loop.
          DATA ls_no LIKE LINE OF lt_non_orphan_global.
          " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
          " Defecto (1). Linea original: DATA lv_idx_no TYPE i VALUE 1.
          DATA lv_idx_no TYPE i.
          lv_idx_no = 1.
          " End Mod V025 (16.09.2026 | EXT_GONZALCA)
          DO lines( lt_non_orphan_global ) TIMES.
            READ TABLE lt_non_orphan_global INTO ls_no INDEX lv_idx_no.
            " Verificar si este grupo non-orphan pertenece al scope del key actual.
            " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
            " Defecto (1), los dos sitios de este bloque interno -- el que
            " podia fallar SIN bulk multi-key. Lineas originales:
            "    DATA lv_found_in_key TYPE abap_bool VALUE abap_false.
            "    DATA lv_idx_k TYPE i VALUE 1.
            DATA lv_found_in_key TYPE abap_bool.
            DATA lv_idx_k TYPE i.
            lv_found_in_key = abap_false.
            lv_idx_k        = 1.
            " End Mod V025 (16.09.2026 | EXT_GONZALCA)
            DO lines( lt_groups_del2 ) TIMES.
              DATA ls_gk LIKE LINE OF lt_groups_del2.
              READ TABLE lt_groups_del2 INTO ls_gk INDEX lv_idx_k.
              IF ls_no-ct_uuid = ls_gk-ct_uuid AND ls_no-mat_uuid = ls_gk-mat_uuid
             AND ls_no-op_type = ls_gk-op_type AND ls_no-op_uuid  = ls_gk-op_uuid
             AND ls_no-cm_h_id = ls_gk-cm_h_id.
                lv_found_in_key = abap_true.
              ENDIF.
              lv_idx_k = lv_idx_k + 1.
            ENDDO.
            IF lv_found_in_key = abap_true.
              APPEND ls_no TO lt_non_orphan_grps.
            ENDIF.
            lv_idx_no = lv_idx_no + 1.
          ENDDO.
          IF lt_non_orphan_grps IS NOT INITIAL.
            lv_has_non_orphan = abap_true.
          ENDIF.
        ENDIF.
      ENDIF.

      IF lv_has_non_orphan = abap_true.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " 76 caracteres: hasta hoy el operador leia "El scope contiene grupos
        " no huerfanos. Delete solo elimina g" y perdia la instruccion.
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error
          text = 'El scope contiene grupos no huerfanos. Delete solo elimina grupos IS_ORPHAN.' ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
        CONTINUE.
      ENDIF.

      " Acumular LOG_A y line_nums para bulk DML post-loop.
      DATA(lv_ts) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
      DATA lt_orphan_nums TYPE tt_line_num.
      lt_orphan_nums = VALUE #( FOR ls_l IN lt_all_lines ( sign = 'I' option = 'EQ' low = ls_l-line_num ) ).

      DATA ls_del_line LIKE LINE OF lt_all_lines.
      DATA lv_idx_del TYPE i.
      lv_idx_del = 1.
      DO lines( lt_all_lines ) TIMES.
        READ TABLE lt_all_lines INTO ls_del_line INDEX lv_idx_del.
        APPEND VALUE zreing_ca_log_a(
          calc_run_id  = ls_key-CalcRunId
          line_num     = ls_del_line-line_num
          log_num      = 0 " V011: placeholder, recalculado en save_modified
          action       = zif_reing_ca_c=>action-delete
          status_from  = ls_del_line-line_status
          status_to    = space
          created_by   = sy-uname
          created_at   = lv_ts
          message      = 'ORPHAN_INSUMO: grupo huerfano eliminado (ET SS2.12)' )
          TO lt_bulk_log_del.
        lv_idx_del = lv_idx_del + 1.
      ENDDO.
      APPEND VALUE ty_del_batch( calc_run_id = ls_key-CalcRunId line_nums = lt_orphan_nums )
        TO lt_bulk_del_nums.
      APPEND ls_key-CalcRunId TO lt_bulk_run_ids.
    ENDLOOP.

    " Begin Change ID V010 (17.07.2026 | EXT_GONZALCA)
    " Fix RUNTIME_ERROR BEHAVIOR_ILLEGAL_STATEMENT: INSERT/DELETE/MODIFY
    " directos prohibidos en fase Modify -- LOG_A, los line_nums a borrar y
    " los calc_run_id a recalcular se acumulan en el buffer estatico.
    " save_modified ejecuta el DELETE real y SOLO DESPUES recalcula/graba
    " total_lines/total_groups (el orden importa: los totales deben leerse
    " ya sin las lineas huerfanas). Ver lcl_reing_ca_dml_buffer.
    APPEND LINES OF lt_bulk_log_del TO lcl_reing_ca_dml_buffer=>gt_log.
    "Begin Mod V017 (CC)
    " V017 (testability refactor): inline flatten replaced by the shared pure
    " helper (same one used by calculate). Same result.
    DATA lt_all_line_nums_del TYPE lcl_reing_ca_dml_buffer=>tt_line_del_key.
    lt_all_line_nums_del = lcl_reing_ca_dml_buffer=>flatten_run_line_nums( lt_bulk_del_nums ).
    "End Mod V017 (CC)
    APPEND LINES OF lt_all_line_nums_del TO lcl_reing_ca_dml_buffer=>gt_line_del.
    APPEND LINES OF lt_bulk_run_ids TO lcl_reing_ca_dml_buffer=>gt_run_ids_recalc.
    " End Change ID V010 (17.07.2026 | EXT_GONZALCA)
  ENDMETHOD.
  " End Change ID V003 (10.07.2026 | EXT_OSCUGALD)

  " Begin Change ID V005 (10.07.2026 | EXT_OSCUGALD)
  " Descripcion : F6-07 Export Excel - genera .xlsx sincrono con resumen
  "               de LINE_As calculadas (excluye PEND). Columnas TAX
  "               dinamicas + apertura CeBe cuando HAS_PC_BREAKDOWN=X.
  "               ET §12: CL_FDT_XL_SPREADSHEET=>CREATE_DOCUMENT.
  METHOD exportexcel.
    " V001 (CC) - #119 (Delta v2): preserve the instance action and its Run scope.
    CHECK keys IS NOT INITIAL.
    READ ENTITIES OF zi_reingcarun IN LOCAL MODE ENTITY CalcRun
      FIELDS ( CalcRunId FiscalPeriod FiscalYear ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_runs) FAILED failed.
    CHECK lt_runs IS NOT INITIAL.
    DATA(lv_run_id) = lt_runs[ 1 ]-CalcRunId.
    SELECT calc_run_id, line_num FROM zreing_ca_line_a
      WHERE calc_run_id = @lv_run_id AND line_status <> 'PEND'
      INTO TABLE @DATA(lt_legacy_ids).
    DATA lt_ids TYPE lcl_ca_export_xlsx=>tt_id.
    lt_ids = CORRESPONDING #( lt_legacy_ids ).
    TRY.
      lcl_ca_export_xlsx=>fetch( EXPORTING it_ids = lt_ids
        IMPORTING et_lines = DATA(lt_export_lines) et_pcs = DATA(lt_export_pcs)
          et_steps = DATA(lt_export_steps) et_contracts = DATA(lt_export_contracts)
          et_currencies = DATA(lt_export_currencies) ).
      DATA(lt_export_rows) = lcl_ca_export_xlsx=>build(
        it_lines = lt_export_lines it_pcs = lt_export_pcs it_steps = lt_export_steps
        it_contracts = lt_export_contracts it_currencies = lt_export_currencies ).
      IF lt_export_rows IS INITIAL.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'No hay líneas calculadas para exportar'.
      ENDIF.
      DATA(lv_xlsx) = NEW zcl_reing_ca_xls_hdl( )->export_rows( it_rows = lt_export_rows
        it_numeric_cols = lcl_ca_export_xlsx=>numeric_cols( lt_export_rows[ 1 ] ) ).
      DATA(lv_base64) = xco_cp=>xstring( lv_xlsx
        )->as_string( xco_cp_binary=>text_encoding->base64 )->value.
      DATA(lv_filename) = |CA_Export_{ lv_run_id }_{ lt_runs[ 1 ]-FiscalYear }{ lt_runs[ 1 ]-FiscalPeriod }.xlsx|.
      LOOP AT keys INTO DATA(ls_key).
        APPEND VALUE #( %tky = ls_key-%tky %param-FileContent = lv_base64
          %param-FileName = lv_filename
          %param-MimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) TO result.
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-success
          text = |{ lv_filename } generado ({ lines( lt_export_lines ) } líneas)| ) ) TO reported-CalcRun.
      ENDLOOP.
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_export).
        APPEND VALUE #( %tky = keys[ 1 ]-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error text = lx_export->get_text( ) ) ) TO reported-CalcRun.
    ENDTRY.
  ENDMETHOD.
  METHOD exportfilteredexcel.
    " V001 (CC) - #119 (Delta v2): read-only static collection action.
    CHECK keys IS NOT INITIAL.
    IF lines( keys ) <> 1.
      APPEND VALUE #( %msg = zcx_reing_ca_msg=>new(
        severity = if_abap_behv_message=>severity-error
        text = 'Invocar la descarga filtrada una vez por solicitud' ) ) TO reported-CalcRun.
      RETURN.
    ENDIF.
    DATA(ls_key) = keys[ 1 ].
    TRY.
      DATA(lo_filter) = NEW lcl_ca_export_filter( ).
      lo_filter->prepare( iv_version = ls_key-%param-filter_version
        it_nodes = CORRESPONDING #( ls_key-%param-filters ) ).
      SELECT * FROM zc_reingcalineall
        WHERE PeriodYear IN @lo_filter->mt_year AND PeriodMonth IN @lo_filter->mt_month
          AND CalcRunId IN @lo_filter->mt_run
        INTO TABLE @DATA(lt_list) UP TO 20001 ROWS.
      IF lines( lt_list ) > 20000.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'La selección supera 20000 líneas; reduzca los filtros'.
      ENDIF.
      DATA lt_ids TYPE lcl_ca_export_xlsx=>tt_id.
      DATA lv_pending TYPE i.
      LOOP AT lt_list INTO DATA(ls_list).
        IF lo_filter->matches( ls_list ) = abap_false. CONTINUE. ENDIF.
        IF ls_list-LineStatus = 'PEND'.
          lv_pending += 1.
        ELSEIF ls_list-CalcRunId IS NOT INITIAL AND ls_list-RowType = 'A'.
          INSERT VALUE #( calc_run_id = ls_list-CalcRunId line_num = ls_list-LineNum ) INTO TABLE lt_ids.
        ENDIF.
      ENDLOOP.
      IF lt_ids IS INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-warning
          text = |Sin líneas calculadas para los filtros; { lv_pending } pendientes excluidos| ) ) TO reported-CalcRun.
        result = VALUE #( ( %cid = ls_key-%cid ) ).
        RETURN.
      ENDIF.
      lcl_ca_export_xlsx=>fetch( EXPORTING it_ids = lt_ids
        IMPORTING et_lines = DATA(lt_export_lines) et_pcs = DATA(lt_export_pcs)
          et_steps = DATA(lt_export_steps) et_contracts = DATA(lt_export_contracts)
          et_currencies = DATA(lt_export_currencies) ).
      DATA(lt_export_rows) = lcl_ca_export_xlsx=>build(
        it_lines = lt_export_lines it_pcs = lt_export_pcs it_steps = lt_export_steps
        it_contracts = lt_export_contracts it_currencies = lt_export_currencies ).
      IF lt_export_rows IS INITIAL.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = 'No hay líneas calculadas para exportar'.
      ENDIF.
      DATA(lv_xlsx) = NEW zcl_reing_ca_xls_hdl( )->export_rows( it_rows = lt_export_rows
        it_numeric_cols = lcl_ca_export_xlsx=>numeric_cols( lt_export_rows[ 1 ] ) ).
      DATA(lv_base64) = xco_cp=>xstring( lv_xlsx
        )->as_string( xco_cp_binary=>text_encoding->base64 )->value.
      DATA(lv_filename) = |CA_Export_Filtrado_{ cl_abap_context_info=>get_system_date( ) }.xlsx|.
      result = VALUE #( ( %cid = ls_key-%cid %param-FileContent = lv_base64
        %param-FileName = lv_filename
        %param-MimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ) ).
      APPEND VALUE #( %cid = ls_key-%cid %msg = zcx_reing_ca_msg=>new(
        severity = if_abap_behv_message=>severity-success
        text = |{ lv_filename }: { lines( lt_export_lines ) } líneas; { lv_pending } pendientes excluidos| ) ) TO reported-CalcRun.
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_export).
        APPEND VALUE #( %cid = ls_key-%cid %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-error text = lx_export->get_text( ) ) ) TO reported-CalcRun.
    ENDTRY.
  ENDMETHOD.


  " End Change ID V005 (10.07.2026 | EXT_OSCUGALD)

  " Begin Change ID V016 (CC) - F4 (05.08.2026 | EXT_GONZALCA)
  METHOD simulate.
    " F4-03. Envoltorio delgado sobre run_contab_mode (DD-F4-4). Mode 'C'.
    " Simulate NUNCA dispara evento (solo Post/Storno) -- ET SS8b.
    CHECK keys IS NOT INITIAL.

    " Begin Insert V016 (CC) - F4 [fix BUG-002] --------------------------------
    " Pre-lectura MASIVA para TODAS las keys, ANTES del LOOP AT keys (mismo
    " patron que release/calculate). Dentro del loop no se toca la base.
    DATA lt_run_rng_sim TYPE lcl_reing_ca_dml_buffer=>tt_run_id_range.
    DATA lt_grp_all_sim TYPE zreing_ca_tt_group_key.
    LOOP AT keys INTO DATA(ls_key_pre_sim).
      IF NOT line_exists( lt_run_rng_sim[ low = ls_key_pre_sim-CalcRunId ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_key_pre_sim-CalcRunId ) TO lt_run_rng_sim.
      ENDIF.
      APPEND LINES OF ls_key_pre_sim-%param-groups TO lt_grp_all_sim.
    ENDLOOP.
    SORT lt_grp_all_sim BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_grp_all_sim
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
    prefetch_contab_data(
      EXPORTING it_run_rng = lt_run_rng_sim
                it_groups  = lt_grp_all_sim
      IMPORTING et_lines   = DATA(lt_pf_line_sim)
                et_line_pc = DATA(lt_pf_pc_sim)
                et_step    = DATA(lt_pf_step_sim) ).
    " End Insert V016 (CC) - F4 ------------------------------------------------

    " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
    " warm_config se mudo a lsc_zi_reingcarun~save_modified, pegado a las
    " llamadas a run_contab_mode que alimenta. Texto de V010 para el registro:
    "   "Precarga de la configuracion del Engine para TODO el scope, antes del
    "    LOOP AT keys" -- 16 de los 28 errores ATC del check "Search DB
    "    Operations in loops across modularization units".
    " La pre-lectura de arriba SI se queda aca: los SELECT son legales en la
    " fase de interaccion y la forma de una sola lectura por accion no cambia.
    " End Mod V018 (09.09.2026 | EXT_GONZALCA)
    " Begin Mod V022 (14.09.2026 | EXT_GONZALCA)
    " warm_config VUELVE aca junto con la ejecucion del Engine -- ver la nota
    " extensa dentro del LOOP AT keys. Sigue ANTES del loop, que es lo que
    " exigia el fix ATC de V010 (16 de los 28 findings de "Search DB
    " Operations in loops across modularization units").
    zcl_reing_contab_engine=>warm_config( lt_pf_line_sim ).
    " End Mod V022 (14.09.2026 | EXT_GONZALCA)

    " Begin Insert V009 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : chequeo de frescura de insumos antes de Simular.
    " spec-F3.3 SSC y la regla SS2.12 exigen el chequeo de consistencia
    " antes de Release Y de Simulate/Post ("se amplia a Simulate/Post cuando
    " F4 los agregue"). F4 los agrego en V012 (05.08.2026) y la ampliacion
    " quedo sin hacer: hasta hoy se podia simular un grupo cuyos insumos
    " cambiaron despues del calculo sin ningun aviso.
    " Se delega a ZCL_REING_CA_INSUMO_MGR~check_groups_stale, que encapsula
    " el pre-fetch de los tres contextos -- replicarlo aca habria sumado
    " ~150 lineas de SELECTs ya presentes en release.
    " Es un WARNING informativo y NO bloquea: la severidad definitiva
    " depende de la decision funcional del mecanismo de confirmacion
    " (WarnAck / dialogo 412), hoy escalada y sin respuesta. Mismo criterio
    " que se aplico en release (V009).
    DATA lt_run_ctx_sim TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    SELECT calc_run_id, fiscal_period, fiscal_year
      FROM zreing_ca_run_a
      WHERE calc_run_id IN @lt_run_rng_sim
      INTO CORRESPONDING FIELDS OF TABLE @lt_run_ctx_sim.

    DATA(lo_mgr_sim) = NEW zcl_reing_ca_insumo_mgr(
                          io_sources = NEW zcl_reing_ca_sources( ) ).
    DATA(lt_stale_sim) = lo_mgr_sim->check_groups_stale(
      it_runs   = CORRESPONDING zcl_reing_ca_insumo_mgr=>ty_run_ctx_t( lt_run_ctx_sim )
      it_groups = lt_grp_all_sim ).
    " End Insert V009 (08.09.2026 | EXT_GONZALCA)

    LOOP AT keys INTO DATA(ls_key).
      result = VALUE #( BASE result
        ( %tky = ls_key-%tky %param = CORRESPONDING #( ls_key-%param ) ) ).

      " V009: un solo aviso por key si alguno de sus grupos esta stale.
      " ATC fix: DO...TIMES en vez de LOOP anidado sobre los groups del key.
      DATA lv_stale_hit_sim TYPE abap_bool.
      CLEAR lv_stale_hit_sim.
      DATA ls_grp_st_sim LIKE LINE OF ls_key-%param-groups.
      DATA lv_idx_st_sim TYPE i.
      lv_idx_st_sim = 1.
      DO lines( ls_key-%param-groups ) TIMES.
        READ TABLE ls_key-%param-groups INTO ls_grp_st_sim INDEX lv_idx_st_sim.
        lv_idx_st_sim = lv_idx_st_sim + 1.
        IF line_exists( lt_stale_sim[ ct_uuid  = ls_grp_st_sim-ct_uuid
                                      mat_uuid = ls_grp_st_sim-mat_uuid
                                      op_type  = ls_grp_st_sim-op_type
                                      op_uuid  = ls_grp_st_sim-op_uuid
                                      cm_h_id  = ls_grp_st_sim-cm_h_id ] ).
          lv_stale_hit_sim = abap_true.
        ENDIF.
      ENDDO.
      IF lv_stale_hit_sim = abap_true.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " Ver la nota de zcx_reing_ca_msg: new_message_with_text dejaba el
        " texto entero en MSGV1 (CHAR50) de SABP_BEHV/100 ("&1"), asi que el
        " frontend recibia 50 caracteres. Este aviso mide ~110.
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-warning
          text     = 'Los insumos del grupo fueron modificados despues del ultimo ' &&
                     'calculo. Se recomienda recalcular antes de simular.' ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
      ENDIF.

      " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
      " Encolar en vez de ejecutar. run_contab_mode invoca al Engine, que
      " escribe a base y postea por BAPI: las dos cosas son ilegales en la fase
      " de interaccion bajo strict ( 2 ). save_modified consume esta cola.
      " La traduccion de et_msg a "reported" se mudo con el, por el mismo
      " motivo, y alli sigue siendo INLINE: un helper privado obligaria a pasar
      " %tky (tipo derivado del BDEF) en su firma, y este objeto ya tumbo 2
      " activaciones por eso (ERR-007/008, V008).
      "APPEND VALUE #( run_id = ls_key-CalcRunId
      "                groups = ls_key-%param-groups
      "                mode   = zif_reing_ca_c=>contab_mode-check )
      "  TO lcl_reing_ca_dml_buffer=>gt_contab_jobs.
      " End Mod V018 (09.09.2026 | EXT_GONZALCA)
      " Begin Mod V022 (14.09.2026 | EXT_GONZALCA)
      " Se EJECUTA de nuevo aca, en la fase de interaccion, en vez de encolar
      " para la fase SAVE. V018 movio los tres modos al saver porque la fase de
      " interaccion prohibe el DML directo y el CALL FUNCTION IN UPDATE TASK.
      " Ninguna de las dos cosas ocurre en modo 'C':
      "   - el Engine solo BUFFERIZA (persist_all llena gt_doc_pending /
      "     gt_item_pending / gt_trace_pending); el MODIFY/DELETE/INSERT real
      "     vive en flush_documents, que SIGUE en save_modified, y
      "   - ZCL_REING_CONTAB_FI_POSTER~post_document llama
      "     BAPI_ACC_DOCUMENT_POST unicamente en modo 'P'. En modo 'C' se
      "     detiene en BAPI_ACC_DOCUMENT_CHECK.
      " Lo que obliga a traerlo de vuelta es la restriccion OPUESTA: la fase
      " SAVE prohibe AUTHORITY-CHECK, y BAPI_ACC_DOCUMENT_CHECK llega a uno por
      " dentro de la cadena estandar de FI -- CHECK_COBL -> FI_VALIDATION_ITEM
      " -> validacion OB28 "MELI_P" paso 019 -> FORM U128 de ZRGGBR000 ->
      " G_SET_FETCH del set ZFI_CLASE_DOC_U128 con NO_AUTHORITY_CHECK vacio ->
      " G_SET_AUTHORITY_CHECK. Dump ST22
      " BEHAVIOR_ILLEGAL_STATEMENT_20260914_142941 (TS4-400, RUN-202601 linea
      " 26, contrato IC-0007). Ese AUTHORITY-CHECK no esta en codigo propio y
      " es perfectamente legal en la fase de interaccion.
      " Post y Storno NO pueden volver: BAPI_ACC_DOCUMENT_POST corre el mismo
      " CHECK por dentro Y ademas registra update tasks. Esos dos se agendan
      " como job APJ (ZCL_REING_CA_CONTAB_JOB).
      lcl_reing_ca_dml_buffer=>run_contab_mode(
        EXPORTING iv_run_id    = ls_key-CalcRunId
                  it_groups    = ls_key-%param-groups
                  iv_mode      = zif_reing_ca_c=>contab_mode-check
                  it_lines_all = lt_pf_line_sim
                  it_pc_all    = lt_pf_pc_sim
                  it_step_all  = lt_pf_step_sim
        IMPORTING et_msg       = DATA(lt_msg_sim) ).

      " Traduccion de las filas LOG_A a "reported". Vuelve aca desde
      " save_modified (V018/V020) sin cambio de logica: la severidad sale del
      " par (status_from, status_to) -- sin transicion, o destino *_ERR, =>
      " error. Sigue INLINE: un helper privado obligaria a pasar %tky (tipo
      " derivado del BDEF) en su firma, y este objeto ya tumbo 2 activaciones
      " por eso (ERR-007/008, V008).
      " DO ... TIMES y no LOOP: ya estamos dentro del LOOP AT keys y el check
      " ATC de loops anidados bloqueo una liberacion de este objeto (BUG-003).
      DATA ls_m_sim LIKE LINE OF lt_msg_sim.
      DATA lv_idx_msg_sim TYPE i.
      lv_idx_msg_sim = 1.
      DO lines( lt_msg_sim ) TIMES.
        READ TABLE lt_msg_sim INTO ls_m_sim INDEX lv_idx_msg_sim.
        lv_idx_msg_sim = lv_idx_msg_sim + 1.
        APPEND VALUE #( %tky = ls_key-%tky
          %msg = zcx_reing_ca_msg=>new(
            severity = COND #( WHEN ls_m_sim-status_to = ls_m_sim-status_from
                                 OR ls_m_sim-status_to = zif_reing_ca_c=>line_status-sim_err
                               THEN if_abap_behv_message=>severity-error
                               ELSE if_abap_behv_message=>severity-success )
            text     = COND #( WHEN ls_m_sim-line_num IS INITIAL THEN |{ ls_m_sim-message }|
                               ELSE |Linea { ls_m_sim-line_num }: { ls_m_sim-message }| ) ) )
          TO reported-calcrun.
      ENDDO.
      " End Mod V022 (14.09.2026 | EXT_GONZALCA)
    ENDLOOP.

    " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
    " La pre-lectura viaja a la fase SAVE junto con la cola: run_contab_mode la
    " recibe como parametro y no vuelve a tocar la base (BUG-002). Se deduplica
    " porque dos actions de contabilizacion en el mismo changeset acumularian
    " la misma linea dos veces y el Engine la procesaria dos veces.
    " El flush_documents que vivia aca es el statement que dumpeaba
    " (BEHAVIOR_ILLEGAL_STATEMENT_20260909_120904): ahora lo ejecuta
    " save_modified, la unica fase donde el runtime permite el INSERT.
    " End Mod V018 (09.09.2026 | EXT_GONZALCA)
    " Begin Mod V022 (14.09.2026 | EXT_GONZALCA)
    " El traspaso de la pre-lectura a la fase SAVE (gt_contab_lines/_pc/_step)
    " se retira: el Engine ya corrio aca con las tablas locales. Lo unico que
    " sigue viajando al saver son los buffers del propio Engine, que
    " flush_documents vuelca -- y esa llamada ya NO depende de gt_contab_jobs.
    " End Mod V022 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD post.
    " F4-04. Mode 'P'. Dispara el evento Posted (via buffer + fase SAVE)
    " solo cuando el flujo de la linea fue COMPLETAMENTE exitoso (BR-F4-03).
    CHECK keys IS NOT INITIAL.

    " Begin Insert V016 (CC) - F4 [fix BUG-002] --------------------------------
    DATA lt_run_rng_pst TYPE lcl_reing_ca_dml_buffer=>tt_run_id_range.
    DATA lt_grp_all_pst TYPE zreing_ca_tt_group_key.
    LOOP AT keys INTO DATA(ls_key_pre_pst).
      IF NOT line_exists( lt_run_rng_pst[ low = ls_key_pre_pst-CalcRunId ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_key_pre_pst-CalcRunId ) TO lt_run_rng_pst.
      ENDIF.
      APPEND LINES OF ls_key_pre_pst-%param-groups TO lt_grp_all_pst.
    ENDLOOP.
    SORT lt_grp_all_pst BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_grp_all_pst
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
    prefetch_contab_data(
      EXPORTING it_run_rng = lt_run_rng_pst
                it_groups  = lt_grp_all_pst
      IMPORTING et_lines   = DATA(lt_pf_line_pst)
                et_line_pc = DATA(lt_pf_pc_pst)
                et_step    = DATA(lt_pf_step_pst) ).
    " End Insert V016 (CC) - F4 ------------------------------------------------

    " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
    " warm_config se mudo a lsc_zi_reingcarun~save_modified, pegado a las
    " llamadas a run_contab_mode que alimenta.
    " End Mod V018 (09.09.2026 | EXT_GONZALCA)
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " warm_config ya no se invoca en esta cadena: quien ejecuta el Engine es
    " ZCL_REING_CA_CONTAB_JOB, y lo llama el mismo antes de run_contab_mode.
    " lt_pf_pc_pst / lt_pf_step_pst tampoco viajan ya a la fase SAVE -- el job
    " rehace su propia pre-lectura desde la base. Se conservan porque
    " prefetch_contab_data los exporta en la misma llamada que trae las LINE_A,
    " que si se usan aca para el gatekeeping de estados.
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)

    " Begin Insert V009 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : chequeo de frescura de insumos antes de Contabilizar.
    " Misma ampliacion que en simulate -- ver la nota extensa alli
    " (spec-F3.3 SSC / regla SS2.12, pendiente desde V012 del 05.08.2026).
    " En Post el aviso pesa mas que en Simulate: aca se generan documentos
    " FI reales, asi que contabilizar sobre insumos desactualizados tiene
    " efecto contable. Aun asi se emite como WARNING y no como error: la
    " semantica definitiva (bloquear / avisar / pedir confirmacion) es la
    " decision funcional escalada y sin respuesta, y convertirlo en error
    " aqui bloquearia Post por completo mientras INSUMO_CHECK_AT siga sin
    " escribirse (accion WarnAck no construida).
    DATA lt_run_ctx_pst TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    SELECT calc_run_id, fiscal_period, fiscal_year
      FROM zreing_ca_run_a
      WHERE calc_run_id IN @lt_run_rng_pst
      INTO CORRESPONDING FIELDS OF TABLE @lt_run_ctx_pst.

    DATA(lo_mgr_pst) = NEW zcl_reing_ca_insumo_mgr(
                          io_sources = NEW zcl_reing_ca_sources( ) ).
    DATA(lt_stale_pst) = lo_mgr_pst->check_groups_stale(
      it_runs   = CORRESPONDING zcl_reing_ca_insumo_mgr=>ty_run_ctx_t( lt_run_ctx_pst )
      it_groups = lt_grp_all_pst ).
    " End Insert V009 (08.09.2026 | EXT_GONZALCA)

    " Begin Insert V023 (14.09.2026 | EXT_GONZALCA)
    " Estados de origen admitidos (BR-CA-36), resueltos UNA vez fuera del loop.
    DATA(lt_allowed_pst) = lcl_reing_ca_dml_buffer=>allowed_source_status(
                             zif_reing_ca_c=>contab_mode-post ).
    " End Insert V023 (14.09.2026 | EXT_GONZALCA)

    LOOP AT keys INTO DATA(ls_key).
      result = VALUE #( BASE result
        ( %tky = ls_key-%tky %param = CORRESPONDING #( ls_key-%param ) ) ).

      " V009: un solo aviso por key si alguno de sus grupos esta stale.
      " ATC fix: DO...TIMES en vez de LOOP anidado sobre los groups del key.
      DATA lv_stale_hit_pst TYPE abap_bool.
      CLEAR lv_stale_hit_pst.
      DATA ls_grp_st_pst LIKE LINE OF ls_key-%param-groups.
      DATA lv_idx_st_pst TYPE i.
      lv_idx_st_pst = 1.
      DO lines( ls_key-%param-groups ) TIMES.
        READ TABLE ls_key-%param-groups INTO ls_grp_st_pst INDEX lv_idx_st_pst.
        lv_idx_st_pst = lv_idx_st_pst + 1.
        IF line_exists( lt_stale_pst[ ct_uuid  = ls_grp_st_pst-ct_uuid
                                      mat_uuid = ls_grp_st_pst-mat_uuid
                                      op_type  = ls_grp_st_pst-op_type
                                      op_uuid  = ls_grp_st_pst-op_uuid
                                      cm_h_id  = ls_grp_st_pst-cm_h_id ] ).
          lv_stale_hit_pst = abap_true.
        ENDIF.
      ENDDO.
      IF lv_stale_hit_pst = abap_true.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " new_message_with_text -> zcx_reing_ca_msg=>new: el helper estandar
        " deja el texto entero en MSGV1 (CHAR50) del mensaje SABP_BEHV/100,
        " que es "&1", asi que el frontend recibia 50 caracteres. Este aviso
        " mide ~110 y llegaba cortado en "despues del ultimo".
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-warning
          text     = 'Los insumos del grupo fueron modificados despues del ultimo ' &&
                     'calculo. Se recomienda recalcular antes de contabilizar.' ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
      ENDIF.

      " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
      " Encolar en vez de ejecutar. run_contab_mode invoca al Engine, que
      " escribe a base y postea por BAPI: las dos cosas son ilegales en la fase
      " de interaccion bajo strict ( 2 ). save_modified consume esta cola.
      "APPEND VALUE #( run_id = ls_key-CalcRunId
      "                groups = ls_key-%param-groups
      "                mode   = zif_reing_ca_c=>contab_mode-post )
      "  TO lcl_reing_ca_dml_buffer=>gt_contab_jobs.
      " End Mod V018 (09.09.2026 | EXT_GONZALCA)
      " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
      " Post deja de ejecutar el Engine en la LUW de RAP -- ni en la fase de
      " interaccion (V018 lo saco de ahi: CALL FUNCTION IN UPDATE TASK de
      " BAPI_ACC_DOCUMENT_POST) ni en la fase SAVE (dump ST22
      " BEHAVIOR_ILLEGAL_STATEMENT_20260914_142941: el CHECK interno de la BAPI
      " llega a un AUTHORITY-CHECK por la validacion FI "MELI_P" paso 019).
      " Las BAPIs de FI no toleran NINGUNA de las dos fases, asi que el posteo
      " pasa a ZCL_REING_CA_CONTAB_JOB (job APJ), reusando el patron que
      " Calculate ya usa desde F3.2.
      " El handler hace ahora solo dos cosas:
      "   1. gatekeeping de estado de origen (lo que el Engine validaba por
      "      linea) -- y asi el rechazo llega al operador EN EL MOMENTO, en vez
      "      de aparecer en un log despues de que el job corrio;
      "   2. marcar la linea en POST_PROC. Ese estado ES el scope que el job
      "      lee de base: no se pasa por parametros del job porque una group
      "      key son 4 UUIDs. A diferencia de DD-F4-6, el *_PROC ahora SI se
      "      persiste -- es la unica forma de que el job sepa que procesar.
      " La cola gt_contab_jobs se conserva, pero save_modified ya no la ejecuta:
      " la usa para AGENDAR (schedule_contab_job).
      " DO ... TIMES y no LOOP: ya estamos dentro del LOOP AT keys y el check
      " ATC de loops anidados bloqueo una liberacion de este objeto (BUG-003).
      DATA ls_ln_pst    LIKE LINE OF lt_pf_line_pst.
      DATA lv_idx_ln_pst TYPE i.
      DATA lv_ok_cnt_pst TYPE i.
      lv_idx_ln_pst = 1.
      lv_ok_cnt_pst = 0.
      DO lines( lt_pf_line_pst ) TIMES.
        READ TABLE lt_pf_line_pst INTO ls_ln_pst INDEX lv_idx_ln_pst.
        lv_idx_ln_pst = lv_idx_ln_pst + 1.

        IF ls_ln_pst-calc_run_id <> ls_key-CalcRunId.
          CONTINUE.
        ENDIF.
        IF NOT line_exists( ls_key-%param-groups[ ct_uuid  = ls_ln_pst-ct_uuid
                                                  mat_uuid = ls_ln_pst-mat_uuid
                                                  op_type  = ls_ln_pst-op_type
                                                  op_uuid  = ls_ln_pst-op_uuid
                                                  cm_h_id  = ls_ln_pst-cm_h_id ] ).
          CONTINUE.
        ENDIF.

        IF NOT ls_ln_pst-line_status IN lt_allowed_pst.
          APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error
            text     = |Linea { ls_ln_pst-line_num }: estado { ls_ln_pst-line_status } | &&
                       |no admitido para contabilizar (admitidos: LIBD, POST_ERR).| ) )
            TO reported-calcrun.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( calc_run_id = ls_ln_pst-calc_run_id
                        line_num    = ls_ln_pst-line_num
                        line_status = zif_reing_ca_c=>line_status-post_proc )
          TO lcl_reing_ca_dml_buffer=>gt_line_status.
        lv_ok_cnt_pst = lv_ok_cnt_pst + 1.
      ENDDO.

      IF lv_ok_cnt_pst > 0.
        APPEND VALUE #( run_id = ls_key-CalcRunId
                        groups = ls_key-%param-groups
                        mode   = zif_reing_ca_c=>contab_mode-post )
          TO lcl_reing_ca_dml_buffer=>gt_contab_jobs.

        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-success
          text     = |Contabilizacion agendada en segundo plano para { lv_ok_cnt_pst } | &&
                     |linea(s). El estado se actualiza al finalizar el proceso.| ) )
          TO reported-calcrun.
      ENDIF.
      " End Mod V023 (14.09.2026 | EXT_GONZALCA)
    ENDLOOP.
  ENDMETHOD.

  METHOD storno.
    " V001 (CC) - #105: mode S succeeds in terminal ANULD.
    " Error de negocio (incluido el rechazo de check_auto_reversal_guard por
    " AUTO_REVERSAL, BR-CA-37) -> la linea PERMANECE en CONT, sin evento
    " (BR-F4-07 / DD-F4-12). El rollback por timeout ANUL_PROC -> CONT con
    " verificacion BKPF NO se implementa aca: es del Orphan Recovery Job
    " (BR-F4-08).
    CHECK keys IS NOT INITIAL.

    " Begin Insert V016 (CC) - F4 [fix BUG-002] --------------------------------
    DATA lt_run_rng_stn TYPE lcl_reing_ca_dml_buffer=>tt_run_id_range.
    DATA lt_grp_all_stn TYPE zreing_ca_tt_group_key.
    LOOP AT keys INTO DATA(ls_key_pre_stn).
      IF NOT line_exists( lt_run_rng_stn[ low = ls_key_pre_stn-CalcRunId ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_key_pre_stn-CalcRunId ) TO lt_run_rng_stn.
      ENDIF.
      APPEND LINES OF ls_key_pre_stn-%param-groups TO lt_grp_all_stn.
    ENDLOOP.
    SORT lt_grp_all_stn BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_grp_all_stn
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
    prefetch_contab_data(
      EXPORTING it_run_rng = lt_run_rng_stn
                it_groups  = lt_grp_all_stn
      IMPORTING et_lines   = DATA(lt_pf_line_stn)
                et_line_pc = DATA(lt_pf_pc_stn)
                et_step    = DATA(lt_pf_step_stn) ).
    " End Insert V016 (CC) - F4 ------------------------------------------------

    " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
    " warm_config se mudo a lsc_zi_reingcarun~save_modified, pegado a las
    " llamadas a run_contab_mode que alimenta.
    " End Mod V018 (09.09.2026 | EXT_GONZALCA)
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " Igual que en post: quien ejecuta el Engine es ZCL_REING_CA_CONTAB_JOB y
    " el mismo hace warm_config y su propia pre-lectura. Aca la pre-lectura
    " queda solo para el gatekeeping de estados.
    DATA(lt_allowed_stn) = lcl_reing_ca_dml_buffer=>allowed_source_status(
                             zif_reing_ca_c=>contab_mode-storno ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)

    " V001 (CC) - GAP-001: scope exact RUN/group pairs before bulk FI reads.
    DATA lt_stn_scope TYPE zif_reing_ca_types=>ty_line_t.
    LOOP AT keys INTO DATA(ls_scope_key).
      DATA lv_scope_idx TYPE i.
      lv_scope_idx = 1.
      DO lines( lt_pf_line_stn ) TIMES.
        READ TABLE lt_pf_line_stn INTO DATA(ls_scope_line) INDEX lv_scope_idx.
        lv_scope_idx = lv_scope_idx + 1.
        IF ls_scope_line-calc_run_id = ls_scope_key-CalcRunId
           AND ls_scope_line-line_status IN lt_allowed_stn
           AND ls_scope_line-line_status <> zif_reing_ca_c=>line_status-anul_proc
           AND line_exists( ls_scope_key-%param-groups[
             ct_uuid = ls_scope_line-ct_uuid mat_uuid = ls_scope_line-mat_uuid
             op_type = ls_scope_line-op_type op_uuid = ls_scope_line-op_uuid
             cm_h_id = ls_scope_line-cm_h_id ] ).
          APPEND ls_scope_line TO lt_stn_scope.
        ENDIF.
      ENDDO.
    ENDLOOP.
    SORT lt_stn_scope BY calc_run_id line_num.
    DELETE ADJACENT DUPLICATES FROM lt_stn_scope COMPARING calc_run_id line_num.
    DATA(lt_stn_check) = zcl_reing_contab_engine=>precheck_reversal( lt_stn_scope ).
    DATA(lv_stn_ts) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).

    LOOP AT keys INTO DATA(ls_key).
      result = VALUE #( BASE result
        ( %tky = ls_key-%tky %param = CORRESPONDING #( ls_key-%param ) ) ).
      " Begin Mod V018 (09.09.2026 | EXT_GONZALCA)
      " Encolar en vez de ejecutar. run_contab_mode invoca al Engine, que
      " escribe a base y postea por BAPI: las dos cosas son ilegales en la fase
      " de interaccion bajo strict ( 2 ). save_modified consume esta cola.
      "APPEND VALUE #( run_id = ls_key-CalcRunId
      "                groups = ls_key-%param-groups
      "                mode   = zif_reing_ca_c=>contab_mode-storno )
      "  TO lcl_reing_ca_dml_buffer=>gt_contab_jobs.
      " End Mod V018 (09.09.2026 | EXT_GONZALCA)
      " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
      " Storno deja de ejecutar el Engine en la LUW de RAP: BAPI_ACC_DOCUMENT_
      " REV_POST registra update tasks (ilegal en la fase de interaccion) y su
      " CHECK interno llega a un AUTHORITY-CHECK (ilegal en la fase SAVE, dump
      " ST22 BEHAVIOR_ILLEGAL_STATEMENT_20260914_142941). Pasa a
      " ZCL_REING_CA_CONTAB_JOB. Ver la nota extensa en post( ).
      " El gatekeeping por linea se hace aca para que el rechazo llegue al
      " operador en el momento; la linea admitida se marca ANUL_PROC, que es el
      " scope que el job lee de base.
      DATA ls_ln_stn     LIKE LINE OF lt_pf_line_stn.
      DATA lv_idx_ln_stn TYPE i.
      DATA lv_ok_cnt_stn TYPE i.
      lv_idx_ln_stn = 1.
      lv_ok_cnt_stn = 0.
      DO lines( lt_pf_line_stn ) TIMES.
        READ TABLE lt_pf_line_stn INTO ls_ln_stn INDEX lv_idx_ln_stn.
        lv_idx_ln_stn = lv_idx_ln_stn + 1.

        IF ls_ln_stn-calc_run_id <> ls_key-CalcRunId.
          CONTINUE.
        ENDIF.
        IF NOT line_exists( ls_key-%param-groups[ ct_uuid  = ls_ln_stn-ct_uuid
                                                  mat_uuid = ls_ln_stn-mat_uuid
                                                  op_type  = ls_ln_stn-op_type
                                                  op_uuid  = ls_ln_stn-op_uuid
                                                  cm_h_id  = ls_ln_stn-cm_h_id ] ).
          CONTINUE.
        ENDIF.

        IF NOT ls_ln_stn-line_status IN lt_allowed_stn
           OR ls_ln_stn-line_status = zif_reing_ca_c=>line_status-anul_proc.
          APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error
            text     = |Linea { ls_ln_stn-line_num }: estado { ls_ln_stn-line_status } | &&
                       |no admitido para anular (CONT, POST_ERR, ANUL_ERR).| ) )
            TO reported-calcrun.
          CONTINUE.
        ENDIF.

        " One processing decision per RUN/LINE even for repeated action keys.
        IF NOT line_exists( lt_stn_scope[ calc_run_id = ls_ln_stn-calc_run_id
                                         line_num = ls_ln_stn-line_num ] ).
          CONTINUE.
        ENDIF.
        DELETE lt_stn_scope WHERE calc_run_id = ls_ln_stn-calc_run_id
          AND line_num = ls_ln_stn-line_num.

        READ TABLE lt_stn_check INTO DATA(ls_stn_check)
          WITH KEY calc_run_id = ls_ln_stn-calc_run_id line_num = ls_ln_stn-line_num.
        IF sy-subrc <> 0.
          ls_stn_check-state = 'E'.
          ls_stn_check-message = 'No se pudo verificar FI para la linea seleccionada'.
        ENDIF.
        DATA(ls_stn_upd) = ls_ln_stn.
        DATA(lv_stn_message) = ls_stn_check-message.
        IF ls_stn_check-state = 'R'
           OR ( ls_stn_check-state = 'N' AND ls_ln_stn-line_status = zif_reing_ca_c=>line_status-post_err ).
          ls_stn_upd-line_status = zif_reing_ca_c=>line_status-anuld.
          lv_stn_message = |Anulado: no quedan documentos FI pendientes. { lv_stn_message }|.
        ELSEIF ls_stn_check-state = 'E'.
          ls_stn_upd-line_status = zif_reing_ca_c=>line_status-anul_err.
        ELSE.
          ls_stn_upd-line_status = zif_reing_ca_c=>line_status-anul_proc.
          ls_stn_upd-proc_started_at = lv_stn_ts.
          ls_stn_upd-proc_heartbeat_at = lv_stn_ts.
          lv_ok_cnt_stn = lv_ok_cnt_stn + 1.
          lv_stn_message = |Anulacion agendada. { lv_stn_message }|.
        ENDIF.
        ls_stn_upd-sim_message = lv_stn_message.
        APPEND ls_stn_upd TO lcl_reing_ca_dml_buffer=>gt_line_f4.
        APPEND VALUE #( calc_run_id = ls_ln_stn-calc_run_id line_num = ls_ln_stn-line_num
          action = zif_reing_ca_c=>action-storno status_from = ls_ln_stn-line_status
          status_to = ls_stn_upd-line_status created_by = sy-uname created_at = lv_stn_ts
          message = lv_stn_message ) TO lcl_reing_ca_dml_buffer=>gt_log.
        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = COND #( WHEN ls_stn_upd-line_status = zif_reing_ca_c=>line_status-anul_err
            THEN if_abap_behv_message=>severity-error ELSE if_abap_behv_message=>severity-success )
          text = |Linea { ls_ln_stn-line_num }: { lv_stn_message }| ) ) TO reported-calcrun.
      ENDDO.

      IF lv_ok_cnt_stn > 0.
        APPEND VALUE #( run_id = ls_key-CalcRunId
                        groups = ls_key-%param-groups
                        mode   = zif_reing_ca_c=>contab_mode-storno )
          TO lcl_reing_ca_dml_buffer=>gt_contab_jobs.

        APPEND VALUE #( %tky = ls_key-%tky %msg = zcx_reing_ca_msg=>new(
          severity = if_abap_behv_message=>severity-success
          text     = |Anulacion agendada en segundo plano para { lv_ok_cnt_stn } | &&
                     |linea(s). El estado se actualiza al finalizar el proceso.| ) )
          TO reported-calcrun.
      ENDIF.
      " End Mod V023 (14.09.2026 | EXT_GONZALCA)
    ENDLOOP.
  ENDMETHOD.



  " Begin Insert V016 (CC) - F4 [fix BUG-002]
  " Begin Mod V019 (09.09.2026 | EXT_GONZALCA)
  " Delegadores. El cuerpo de estos 2 metodos se mudo a
  " lcl_reing_ca_dml_buffer (ver la nota de la cabecera de esta clase). Se
  " conservan aca porque ltcl_contab_actions invoca
  " lhc_zi_reingcarun=>run_contab_mode y =>allowed_source_status, y la idea es
  " que la clase de test no cambie ni una linea. get_fi_poster no se delega:
  " solo lo usaba run_contab_mode y ningun test lo invoca.
  METHOD run_contab_mode.
    lcl_reing_ca_dml_buffer=>run_contab_mode(
      EXPORTING iv_run_id    = iv_run_id
                it_groups    = it_groups
                iv_mode      = iv_mode
                it_lines_all = it_lines_all
                it_pc_all    = it_pc_all
                it_step_all  = it_step_all
      IMPORTING et_msg       = et_msg
                ev_has_error = ev_has_error ).
  ENDMETHOD.

  METHOD allowed_source_status.
    rt_allowed = lcl_reing_ca_dml_buffer=>allowed_source_status( iv_mode ).
  ENDMETHOD.
  " End Mod V019 (09.09.2026 | EXT_GONZALCA)

  METHOD prefetch_contab_data.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " DELEGADOR: las 3 lecturas masivas se mudaron a
    " ZCL_REING_CA_CONTAB_RUNNER~prefetch_contab_data, porque el job APJ
    " necesita exactamente la misma pre-lectura y no ve esta clase local.
    " Se conserva la forma que exigio BUG-002 -- una sola invocacion por
    " accion, ANTES del LOOP AT keys -- y con ella la propiedad de que
    " ninguna sentencia de BD quede dentro de un loop, directo o cruzando
    " unidades de modularizacion.
    " Sigue en lhc_ y no en lcl_ por una razon de alcance, no de diseno: los
    " tres handlers son sus unicos llamadores y su firma ya estaba publicada
    " para ltcl_contab_actions.
    zcl_reing_ca_contab_runner=>prefetch_contab_data(
      EXPORTING it_run_rng = CONV #( it_run_rng )
                it_groups  = it_groups
      IMPORTING et_lines   = et_lines
                et_line_pc = et_line_pc
                et_step    = et_step ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  " End Insert V016 (CC) - F4

  " End Change ID V016 (CC) - F4

* NOTA: NO se agrega ningun helper que reciba %tky ni ningun otro tipo
* derivado del BDEF en su firma. La traduccion de LOG_A a "reported" queda
* INLINE en simulate/post/storno: este objeto ya perdio 2 activaciones por
* pasar tipos derivados entre metodos privados (ERR-007/008, ver V008).

ENDCLASS.

" Begin Change ID V002 (10.07.2026 | EXT_OSCUGALD)
CLASS lsc_zi_reingcarun IMPLEMENTATION.

  METHOD save_modified.
    " Agenda el APJ desde el Additional Save de CalcLine. Para cuando el
    " framework invoca este metodo, el LUW RAP ya fue commiteado.
    " SAVE_MODIFIED NUNCA puede fallar -- contrato RAP obligatorio.
    "
    " Begin Change ID V025 (16.09.2026 | EXT_GONZALCA)
    " Misma clase de defecto corregida en CALCULATE -- ver la nota de cabecera
    " de ese metodo. Aqui hay UN solo sitio: LV_AG_IDX_SAV, el contador del
    " conteo de grupos, declarado con VALUE 1 DENTRO del DO que recorre
    " GT_RUN_IDS_RECALC. Desde el 2o run del buffer el READ INDEX ya no
    " encontraba nada, LV_TG_SAV se quedaba en 0 y el UPDATE grababa
    " TOTAL_GROUPS = 0 -- con TOTAL_LINES correcto, porque ese sale de un
    " SELECT COUNT agrupado y no del contador.
    " End Change ID V025 (16.09.2026 | EXT_GONZALCA)

    " Begin Change ID V010 (17.07.2026 | EXT_GONZALCA)
    " Fix RUNTIME_ERROR BEHAVIOR_ILLEGAL_STATEMENT: calculate/release/delete
    " (fase Modify) ya NO ejecutan DML directo -- solo acumulan en
    " lcl_reing_ca_dml_buffer. save_modified es la fase Save real del LUW
    " RAP, el UNICO punto donde el runtime permite estos statements. Se
    " vuelca aqui, en orden: LOG_A -> DELETE step/lpc/line -> UPDATE
    " line_status -> INSERT usage -> UPDATE me_h_a -> recalculo
    " total_lines/total_groups (DESPUES del DELETE, para no contar lineas ya
    " huerfanas eliminadas). LOG_A se persiste por SQL directo a proposito
    " (no EML/composicion) para que sobreviva si el padre es borrado en el
    " mismo LUW -- ver feedback-rap-audit-log-cascade-delete.
    " Begin Change ID V011 (17.07.2026 | EXT_GONZALCA)
    " Fix: log_num quedaba hardcodeado a 1 en los 3 handlers (calculate/
    " release/delete) -- nunca se consultaba el ultimo log_num real para esa
    " linea, perdiendo/pisando el historial de LOG_A. Se recalcula aqui el
    " log_num real:
    "Begin Mod V017 (CC)
    " V017: LINE_NUM is numbered per RUN and is NOT globally unique. LOG_NUM
    "       is therefore recomputed per (CALC_RUN_ID, LINE_NUM).
    " Begin Insert V018 (09.09.2026 | EXT_GONZALCA)
    " Ejecucion de Simulate/Post/Storno en la fase SAVE.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " V018 QUEDA SIN EFECTO: ninguno de los tres modos se ejecuta ya aca.
    "   - Simulate (modo C) volvio a la fase de interaccion (V022): la fase
    "     SAVE prohibe AUTHORITY-CHECK y BAPI_ACC_DOCUMENT_CHECK llega a uno
    "     por la cadena estandar de FI (validacion OB28 "MELI_P" paso 019 ->
    "     FORM U128 de ZRGGBR000 -> G_SET_FETCH). Dump ST22
    "     BEHAVIOR_ILLEGAL_STATEMENT_20260914_142941.
    "   - Post y Storno pasaron a job APJ (ZCL_REING_CA_CONTAB_JOB): las BAPIs
    "     de FI no toleran NINGUNA de las dos fases de RAP -- update tasks en
    "     la de interaccion, AUTHORITY-CHECK en la SAVE.
    " De V018 sobreviven dos cosas: el flush_documents (ahora incondicional,
    " para volcar lo que bufferizo Simulate) y la cola gt_contab_jobs, que ya
    " no se ejecuta sino que se usa para AGENDAR el job -- ver el bloque
    " "Agendamiento del job de CONTAB" mas abajo, que va DESPUES del UPDATE de
    " line_status a proposito.
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
    DATA lv_run_flush_sav TYPE zreing_ca_run_a-calc_run_id.

    " Volcado UNICO de documentos/posiciones/traces de las lineas procesadas en
    " esta LUW (hoy: las de Simulate, que corre en la fase de interaccion).
    " Fuera de todo IF: flush_documents hace RETURN inmediato si los tres
    " buffers del Engine estan vacios, asi que en un save de
    " calculate/release/delete no cuesta nada.
    " La excepcion se CAPTURA a proposito: save_modified corre pasado el punto
    " de no retorno y salir de una implementacion BEHAVIOR con RAISE EXCEPTION
    " es, en si misma, otra violacion de contrato -- lo dice la seccion
    " "Anal.errores" del dump que motivo V018.
    TRY.
        zcl_reing_contab_engine=>flush_documents( ).
      CATCH zcx_reing_contab INTO DATA(lx_flush_sav).
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        " Los mensajes de flush_documents (guard H-3, overflow de trazas)
        " superan holgadamente los 50 caracteres y son diagnosticos.
        " V023: el %tky sale de la primera linea tocada. Un %tky vacio dejaria
        " el mensaje sin instancia a la que colgarse en la UI.
        READ TABLE lcl_reing_ca_dml_buffer=>gt_line_f4 INTO DATA(ls_lf4_flush) INDEX 1.
        IF sy-subrc = 0.
          lv_run_flush_sav = ls_lf4_flush-calc_run_id.
        ENDIF.
        APPEND VALUE #( %tky = VALUE #( CalcRunId = lv_run_flush_sav )
          %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-error
            text     = lx_flush_sav->mv_message ) ) TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
    ENDTRY.
    " End Insert V018 (09.09.2026 | EXT_GONZALCA)

    IF lcl_reing_ca_dml_buffer=>gt_log IS NOT INITIAL.
      "Begin Mod V017 (CC)
      " V017 (testability refactor): LOG_NUM recompute extracted to the pure
      " helper so it can be unit-tested per RUN. Same result: gt_log is
      " renumbered in place per (calc_run_id, line_num).
      lcl_reing_ca_dml_buffer=>recalc_log_num_per_run(
        CHANGING ct_log = lcl_reing_ca_dml_buffer=>gt_log ).
      "End Mod V017 (CC)
      " End Change ID V011 (17.07.2026 | EXT_GONZALCA)

      INSERT zreing_ca_log_a FROM TABLE @lcl_reing_ca_dml_buffer=>gt_log.
    ENDIF.

    "Begin Mod V017 (CC)
    " V017: delete scoped to (calc_run_id, line_num). STEP_A/LPC_A have a longer
    "       PK, so a partial-key FROM TABLE or a single-field range is unsafe:
    "       read the affected rows by pair, then DELETE FROM TABLE by full PK.
    "       All statements stay outside any loop (BR-4 / no DB-op-in-loop).
    lcl_reing_ca_dml_buffer=>isolate_and_delete_orphans( lcl_reing_ca_dml_buffer=>gt_line_del ).
    "End Mod V017 (CC)

    IF lcl_reing_ca_dml_buffer=>gt_line_status IS NOT INITIAL.
      " Begin Mod V016 (CC) - F4 (DD-F4-10)
      " El supuesto original ("un solo valor de status por LUW, Release
      " siempre usa LIBD") deja de valer: Simulate/Post/Storno producen
      " valores mixtos en la misma invocacion. isolate_and_update_status lee
      " las filas completas y emite UNA sola sentencia set-based fuera de todo
      " loop (fix BUG-003 del ATC), con el scope (calc_run_id, line_num) que
      " exigio V017.
      " V023: por esta via entran ahora tambien los POST_PROC / ANUL_PROC que
      " marcan post( ) y storno( ) -- el estado intermedio SI se persiste,
      " porque es el scope que ZCL_REING_CA_CONTAB_JOB lee de base.
      lcl_reing_ca_dml_buffer=>isolate_and_update_status( lcl_reing_ca_dml_buffer=>gt_line_status ).
      "End Mod V017 (CC)
      " End Mod V016 (CC) - F4 (DD-F4-10)
    ENDIF.

    IF lcl_reing_ca_dml_buffer=>gt_usage IS NOT INITIAL.
      INSERT zreing_calcusage FROM TABLE @lcl_reing_ca_dml_buffer=>gt_usage.
    ENDIF.

    IF lcl_reing_ca_dml_buffer=>gt_me_h_libr IS NOT INITIAL.
      UPDATE zreing_me_h_a SET me_status = 'LIBR'
        WHERE me_h_id   IN @lcl_reing_ca_dml_buffer=>gt_me_h_libr
          AND me_status = @zif_reing_ca_c=>me_eligible_status-libd.
    ENDIF.

    IF lcl_reing_ca_dml_buffer=>gt_run_ids_recalc IS NOT INITIAL.
      DATA lt_run_range_sav TYPE RANGE OF zreing_ca_run_a-calc_run_id.
      lt_run_range_sav = VALUE #( FOR lv_rid IN lcl_reing_ca_dml_buffer=>gt_run_ids_recalc
        ( sign = 'I' option = 'EQ' low = lv_rid ) ).
      SELECT calc_run_id, COUNT( * ) AS total_lines
        FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_sav
        GROUP BY calc_run_id
        INTO TABLE @DATA(lt_totals_sav).
      SELECT DISTINCT calc_run_id, ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id
        FROM zreing_ca_line_a
        WHERE calc_run_id IN @lt_run_range_sav
        INTO TABLE @DATA(lt_groups_sav).
      DATA lt_run_upd_sav TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
      " V001 (CC) - GAP-001: do not wipe period/audit fields when updating totals.
      SELECT * FROM zreing_ca_run_a
        WHERE calc_run_id IN @lt_run_range_sav INTO TABLE @DATA(lt_run_full_sav).
      DATA lv_calc_run_id_sav LIKE LINE OF lcl_reing_ca_dml_buffer=>gt_run_ids_recalc.
      DATA lv_upd_idx_sav TYPE i VALUE 1.
      DO lines( lcl_reing_ca_dml_buffer=>gt_run_ids_recalc ) TIMES.
        READ TABLE lcl_reing_ca_dml_buffer=>gt_run_ids_recalc INTO lv_calc_run_id_sav INDEX lv_upd_idx_sav.
        DATA lv_tl_sav TYPE zreing_ca_run_a-total_lines.
        DATA lv_tg_sav TYPE zreing_ca_run_a-total_groups.
        READ TABLE lt_totals_sav INTO DATA(ls_tot_sav) WITH KEY calc_run_id = lv_calc_run_id_sav.
        lv_tl_sav = COND #( WHEN sy-subrc = 0 THEN ls_tot_sav-total_lines ELSE 0 ).
        lv_tg_sav = 0.
        DATA ls_ag_sav LIKE LINE OF lt_groups_sav.
        " Begin Mod V025 (16.09.2026 | EXT_GONZALCA)
        " Linea original: DATA lv_ag_idx_sav TYPE i VALUE 1.
        DATA lv_ag_idx_sav TYPE i.
        lv_ag_idx_sav = 1.
        " End Mod V025 (16.09.2026 | EXT_GONZALCA)
        DO lines( lt_groups_sav ) TIMES.
          READ TABLE lt_groups_sav INTO ls_ag_sav INDEX lv_ag_idx_sav.
          IF ls_ag_sav-calc_run_id = lv_calc_run_id_sav.
            lv_tg_sav = lv_tg_sav + 1.
          ENDIF.
          lv_ag_idx_sav = lv_ag_idx_sav + 1.
        ENDDO.
        READ TABLE lt_run_full_sav INTO DATA(ls_run_full_sav)
          WITH KEY calc_run_id = lv_calc_run_id_sav.
        IF sy-subrc = 0.
          ls_run_full_sav-total_lines = lv_tl_sav.
          ls_run_full_sav-total_groups = lv_tg_sav.
          APPEND ls_run_full_sav TO lt_run_upd_sav.
        ENDIF.
        lv_upd_idx_sav = lv_upd_idx_sav + 1.
      ENDDO.
      IF lt_run_upd_sav IS NOT INITIAL.
        UPDATE zreing_ca_run_a FROM TABLE @lt_run_upd_sav.
      ENDIF.
    ENDIF.

    " Begin Insert V016 (CC) - F4
    " (a) Volcado de las LINE_A tocadas por Simulate/Post/Storno. UNA sola
    "     sentencia con las filas completas ya mutadas en run_contab_mode
    "     (line_status + sim_message + fi_awkey cambian juntas y con valores
    "     distintos por linea; un buffer clave/valor exigiria un UPDATE por
    "     linea = hallazgo ATC DBWRT-in-loop). Las filas se leyeron en la
    "     MISMA LUW bajo el lock master del BO.
    IF lcl_reing_ca_dml_buffer=>gt_line_f4 IS NOT INITIAL.
      UPDATE zreing_ca_line_a FROM TABLE @lcl_reing_ca_dml_buffer=>gt_line_f4.
      " V001 (CC) - GAP-001: close usage only after ANULD is persisted, same LUW.
      DATA(lo_stn_usage) = NEW zcl_reing_ca_insumo_mgr( io_sources = NEW zcl_reing_ca_sources( ) ).
      lo_stn_usage->revert_usage_bulk( lcl_reing_ca_dml_buffer=>gt_line_f4 ).
    ENDIF.

    " (b) Disparo de los eventos de negocio RAP. Va aqui, no en el metodo de
    "     la accion: SAP documenta que el evento se levanta en la secuencia
    "     SAVE "after the point of no return has passed" (DD-F4-2).
    "     V023: en la practica estos dos buffers quedan VACIOS desde que Post y
    "     Storno corren como job APJ -- son los unicos dos modos que producen
    "     eventos y ya no pasan por aca. El codigo se conserva intacto porque
    "     el job NO puede levantarlos (RAISE ENTITY EVENT solo es legal en el
    "     save de RAP) y, cuando se implemente CON-08, la decision de donde
    "     dispararlo se toma de nuevo. Hoy no se pierde nada: el unico handler
    "     de estos eventos, ZCL_REING_CONTAB_EVT_POSTED, esta VACIO.
    IF lcl_reing_ca_dml_buffer=>gt_posted_evt IS NOT INITIAL.
      RAISE ENTITY EVENT zi_reingcarun~posted
        FROM VALUE #( FOR ls_ev IN lcl_reing_ca_dml_buffer=>gt_posted_evt
                      ( %key-CalcRunId  = ls_ev-calc_run_id
                        %param-LineNum = ls_ev-line_num
                        %param-OpType  = ls_ev-op_type ) ).
    ENDIF.

    IF lcl_reing_ca_dml_buffer=>gt_reversed_evt IS NOT INITIAL.
      RAISE ENTITY EVENT zi_reingcarun~reversed
        FROM VALUE #( FOR ls_rv IN lcl_reing_ca_dml_buffer=>gt_reversed_evt
                      ( %key-CalcRunId  = ls_rv-calc_run_id
                        %param-LineNum = ls_rv-line_num ) ).
      " End Mod V016 (CC) - F4
    ENDIF.
    " End Insert V016 (CC) - F4

    " Begin Insert V023 (14.09.2026 | EXT_GONZALCA)
    " --- Agendamiento del job de CONTAB (Post / Storno) --------------------
    " Va DESPUES del UPDATE de line_status a proposito: el job lee su scope de
    " ZREING_CA_LINE_A por line_status = POST_PROC / ANUL_PROC, asi que esas
    " filas tienen que estar escritas antes de agendarlo.
    " Mismo patron y mismas limitaciones que el agendamiento de Calculate, que
    " esta en produccion desde F3.2: start_immediately + UPDATE de PROC_JOB_ID
    " fuera de todo loop. En produccion hay exactamente un job por invocacion.
    IF lcl_reing_ca_dml_buffer=>gt_contab_jobs IS NOT INITIAL.
      " V001 (CC) - GAP-001: one APJ job per RUN/mode, even for multiple action keys.
      SORT lcl_reing_ca_dml_buffer=>gt_contab_jobs BY run_id mode.
      DELETE ADJACENT DUPLICATES FROM lcl_reing_ca_dml_buffer=>gt_contab_jobs COMPARING run_id mode.
      TYPES: BEGIN OF ty_ctb_pair,
               calc_run_id TYPE zreing_ca_run_a-calc_run_id,
               proc_status TYPE zreing_ca_line_status,
               jobname     TYPE cl_apj_rt_api=>ty_jobname,
             END OF ty_ctb_pair.
      DATA lt_ctb_pairs TYPE STANDARD TABLE OF ty_ctb_pair WITH EMPTY KEY.

      " DO ... TIMES en vez de LOOP AT: el check ATC de loops anidados ya
      " bloqueo una liberacion de este objeto (BUG-003).
      DATA ls_job_sav     LIKE LINE OF lcl_reing_ca_dml_buffer=>gt_contab_jobs.
      DATA lv_job_idx_sav TYPE i VALUE 1.
      DATA lv_jobname_ctb TYPE cl_apj_rt_api=>ty_jobname.
      DO lines( lcl_reing_ca_dml_buffer=>gt_contab_jobs ) TIMES.
        READ TABLE lcl_reing_ca_dml_buffer=>gt_contab_jobs INTO ls_job_sav INDEX lv_job_idx_sav.
        lv_job_idx_sav = lv_job_idx_sav + 1.
        CLEAR lv_jobname_ctb.

        DATA(lv_warn_ctb) = zcl_reing_ca_contab_runner=>schedule_contab_job(
          EXPORTING iv_run_id  = ls_job_sav-run_id
                    iv_mode    = ls_job_sav-mode
          IMPORTING ev_jobname = lv_jobname_ctb ).

        IF lv_warn_ctb IS NOT INITIAL.
          APPEND VALUE #( %tky = VALUE #( CalcRunId = ls_job_sav-run_id )
            %msg = zcx_reing_ca_msg=>new(
              severity = if_abap_behv_message=>severity-warning
              text     = lv_warn_ctb ) )
            TO reported-calcrun.
        ENDIF.

        IF lv_jobname_ctb IS NOT INITIAL.
          APPEND VALUE ty_ctb_pair(
            calc_run_id = ls_job_sav-run_id
            proc_status = COND #(
              WHEN ls_job_sav-mode = zif_reing_ca_c=>contab_mode-storno
                THEN zif_reing_ca_c=>line_status-anul_proc
              ELSE zif_reing_ca_c=>line_status-post_proc )
            jobname     = lv_jobname_ctb ) TO lt_ctb_pairs.
        ENDIF.
      ENDDO.

      " UPDATE de PROC_JOB_ID completamente fuera de cualquier loop, igual que
      " en el agendamiento de Calculate: una sola entrada en produccion.
      " V001 (CC) - GAP-001: attach each job to its actual RUN, preserving full rows.
      IF lt_ctb_pairs IS NOT INITIAL.
        SELECT * FROM zreing_ca_line_a
          FOR ALL ENTRIES IN @lt_ctb_pairs
          WHERE calc_run_id = @lt_ctb_pairs-calc_run_id
            AND line_status = @lt_ctb_pairs-proc_status
          INTO TABLE @DATA(lt_ctb_job_lines).
        LOOP AT lt_ctb_job_lines ASSIGNING FIELD-SYMBOL(<ls_ctb_job_line>).
          <ls_ctb_job_line>-proc_job_id = lt_ctb_pairs[
            calc_run_id = <ls_ctb_job_line>-calc_run_id
            proc_status = <ls_ctb_job_line>-line_status ]-jobname.
        ENDLOOP.
        UPDATE zreing_ca_line_a FROM TABLE @lt_ctb_job_lines.
      ENDIF.

      CLEAR: lcl_reing_ca_dml_buffer=>gt_contab_jobs,
             lcl_reing_ca_dml_buffer=>gt_contab_lines,
             lcl_reing_ca_dml_buffer=>gt_contab_pc,
             lcl_reing_ca_dml_buffer=>gt_contab_step.
    ENDIF.
    " End Insert V023 (14.09.2026 | EXT_GONZALCA)

    CLEAR: lcl_reing_ca_dml_buffer=>gt_log,
           lcl_reing_ca_dml_buffer=>gt_line_del,
           lcl_reing_ca_dml_buffer=>gt_line_status,
           lcl_reing_ca_dml_buffer=>gt_usage,
           lcl_reing_ca_dml_buffer=>gt_me_h_libr,
           lcl_reing_ca_dml_buffer=>gt_run_ids_recalc,
           " Begin Insert V016 (CC) - F4
           lcl_reing_ca_dml_buffer=>gt_line_f4,
           lcl_reing_ca_dml_buffer=>gt_posted_evt,
           lcl_reing_ca_dml_buffer=>gt_reversed_evt.
           " End Insert V016 (CC) - F4
    " End Change ID V010 (17.07.2026 | EXT_GONZALCA)

    CHECK create-CalcLine IS NOT INITIAL.
    DATA(lt_lines) = VALUE tt_created_line(
      FOR ls_c IN create-CalcLine ( calc_run_id = ls_c-CalcRunId line_num = ls_c-LineNum ) ).
    DATA(lt_runs) = lt_lines.
    SORT lt_runs BY calc_run_id.
    DELETE ADJACENT DUPLICATES FROM lt_runs COMPARING calc_run_id.

    " ATC fix (DBWRT_LOC + NonLocal): acumular jobnames en el LOOP sin hacer
    " UPDATE dentro. Post-loop: un UPDATE por jobname distinto fuera de todo loop.
    " En produccion siempre hay exactamente 1 run por invocacion de save_modified.
    TYPES: BEGIN OF ty_job_pair,
             calc_run_id TYPE zreing_ca_run_a-calc_run_id,
             jobname     TYPE cl_apj_rt_api=>ty_jobname,
           END OF ty_job_pair.
    DATA lt_job_pairs TYPE STANDARD TABLE OF ty_job_pair WITH EMPTY KEY.

    LOOP AT lt_runs INTO DATA(ls_run).
      DATA lv_jobname_sav TYPE cl_apj_rt_api=>ty_jobname.
      DATA(lv_warn_text) = schedule_calc_job(
        EXPORTING iv_run_id = ls_run-calc_run_id
                  it_lines  = VALUE #( FOR ls_l IN lt_lines WHERE ( calc_run_id = ls_run-calc_run_id ) ( ls_l ) )
        IMPORTING ev_jobname = lv_jobname_sav ).
      IF lv_warn_text IS NOT INITIAL.
        " Begin Mod V020 (09.09.2026 | EXT_GONZALCA)
        APPEND VALUE #( %tky = VALUE #( CalcRunId = ls_run-calc_run_id )
          %msg = zcx_reing_ca_msg=>new(
            severity = if_abap_behv_message=>severity-warning
            text = lv_warn_text ) )
          TO reported-calcrun.
        " End Mod V020 (09.09.2026 | EXT_GONZALCA)
      ENDIF.
      IF lv_jobname_sav IS NOT INITIAL.
        APPEND VALUE ty_job_pair( calc_run_id = ls_run-calc_run_id jobname = lv_jobname_sav )
          TO lt_job_pairs.
      ENDIF.
    ENDLOOP.

    " ATC fix: UPDATE proc_job_id completamente fuera de cualquier loop.
    " V001 (CC) - GAP-001: multi-RUN Calculate must track every scheduled job.
    IF lt_job_pairs IS NOT INITIAL.
      SELECT * FROM zreing_ca_line_a
        FOR ALL ENTRIES IN @lt_job_pairs
        WHERE calc_run_id = @lt_job_pairs-calc_run_id
          AND line_status = 'CALC_PROC' AND proc_job_id = @space
        INTO TABLE @DATA(lt_calc_job_lines).
      LOOP AT lt_calc_job_lines ASSIGNING FIELD-SYMBOL(<ls_calc_job_line>).
        <ls_calc_job_line>-proc_job_id = lt_job_pairs[
          calc_run_id = <ls_calc_job_line>-calc_run_id ]-jobname.
      ENDLOOP.
      UPDATE zreing_ca_line_a FROM TABLE @lt_calc_job_lines.
    ENDIF.
  ENDMETHOD.

  METHOD schedule_calc_job.
    " Agendamiento via CL_APJ_RT_API=>SCHEDULE_JOB.
    " Si SAJT 'ZREING_CA_CALC_JOBT' no existe (F3.2-H1 pendiente), lanza
    " CX_TEMPLATE_DOESNT_EXIST. Se atrapa SIEMPRE -- save_modified no falla.
    " Fix it.11: ya no escribe a "reported" directamente (tipo especializado
    " no compartible entre metodos) -- devuelve el texto de warning y deja que
    " save_modified arme el mensaje real con su propio "reported" nativo.
    " ATC fix: el UPDATE zreing_ca_line_a se mueve a save_modified (fuera del
    " loop de schedule_calc_job) -- aqui solo exportamos ev_jobname.
    TRY.
        DATA(lv_run_id) = iv_run_id.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = 'ZREING_CA_CALC_JOBT'
            iv_job_text            = |CA Calculate { lv_run_id }|
            is_start_info          = VALUE #( start_immediately = abap_true )
            it_job_parameter_value = VALUE #(
              ( name = 'P_RUNID' t_value = VALUE #( ( sign = 'I' option = 'EQ' low = lv_run_id ) ) ) )
          IMPORTING
            ev_jobname  = ev_jobname
            ev_jobcount = DATA(lv_jobcount) ).
      CATCH cx_apj_rt INTO DATA(lx_apj).
        rv_warn_text = |No se pudo agendar el job de calculo: { lx_apj->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
" End Change ID V002 (10.07.2026 | EXT_OSCUGALD)
