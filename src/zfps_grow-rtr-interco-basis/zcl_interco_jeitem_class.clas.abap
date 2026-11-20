CLASS zcl_interco_jeitem_class DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_jeitem_class IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    CONSTANTS: BEGIN OF c_bgprocessing,
                 on        TYPE zint_bgprocessing VALUE 'Y',
                 off       TYPE zint_bgprocessing VALUE 'N',
                 undefined TYPE zint_bgprocessing VALUE '-',
               END OF c_bgprocessing.

    DATA(parameters) = io_request->get_parameters( ).

    DATA results TYPE TABLE OF zc_intercojeitemclass.
    DATA(p_companycode) = CONV bukrs( parameters[ parameter_name = 'P_COMPANYCODE' ]-value ).
    DATA(p_ledger) = CONV fins_ledger( parameters[ parameter_name = 'P_LEDGER' ]-value ).
    DATA(p_fiscalyear) = CONV gjahr( parameters[ parameter_name = 'P_FISCALYEAR' ]-value ).
    DATA(p_fiscalperiod) = CONV poper( parameters[ parameter_name = 'P_FISCALPERIOD' ]-value ).
    DATA(p_paymenttype) = CONV zint_dte_paymenttype( parameters[ parameter_name = 'P_PAYMENTTYPE' ]-value ).
    DATA(p_bgprocessing) = CONV zint_bgprocessing( parameters[ parameter_name = 'P_BGPROCESSING' ]-value  ).

    " EXT_VINBARRI 17.11.2026: dos caminos unicos.
    "   - BG (P_BGPROCESSING = 'Y'): resultado ya procesado, zc_intercojeitemclassbg.
    "   - Online: ZC_INTERCOJEITEMCLASSV4.
    " Se eliminan el flujo V2 (zc_intercojeitemclass) y el ruteo por ZINTERCO_IC05_MATAG_ACTIVA + AG.
    DATA(is_bg) = xsdbool( p_bgprocessing = c_bgprocessing-on ).

    " P_WithRevenue va como LITERAL en el FROM dinamico (no host variable) para que HANA
    " elimine la rama de ingresos cuando la sociedad no tiene la feature REVENUE_LINES.
    DATA lv_source TYPE string.
    IF is_bg = abap_false.
      DATA(lv_with_revenue) = zcl_interco_jeitem_bg=>get_with_revenue( iv_companycode  = p_companycode
                                                                       iv_fiscalyear   = p_fiscalyear
                                                                       iv_fiscalperiod = p_fiscalperiod ).
      lv_source = |zc_intercojeitemclassv4( p_companycode = @p_companycode, p_ledger = @p_ledger, | &&
                  |p_fiscalyear = @p_fiscalyear, p_fiscalperiod = @p_fiscalperiod, | &&
                  |p_paymenttype = @p_paymenttype, p_withrevenue = '{ lv_with_revenue }' )|.
    ENDIF.

    "  build results
    DATA(sort_elements) = io_request->get_sort_elements( ).
    DATA(request_elements) = io_request->get_requested_elements( ).
    DATA(aggr_elements) = io_request->get_aggregation( )->get_aggregated_elements( ).
    DATA(groupped_elements) = io_request->get_aggregation( )->get_grouped_elements( ).
    DATA(offset) = io_request->get_paging( )->get_offset( ).
    DATA(pagesize) = io_request->get_paging( )->get_page_size( ).
    DATA orderby TYPE string.

    " Build orderby
    LOOP AT sort_elements INTO DATA(sort_element).
      IF NOT line_exists( request_elements[ table_line = sort_element-element_name ] ).
        CONTINUE.
      ENDIF.
      orderby = orderby &&
                   COND string(  WHEN orderby IS INITIAL THEN `` ELSE `, ` ) &&
                   sort_element-element_name &&
                   COND string( WHEN sort_element-descending = abap_true THEN ` descending` ELSE space ).
    ENDLOOP.
    " AGREGADO DS4K9B5URA: usar IS INITIAL para detectar orderby vacio
    " independientemente de si el LOOP itero o no
    IF orderby IS INITIAL.
      orderby = REDUCE string( INIT r = ``
                                  FOR req_element IN request_elements
                                  NEXT r = r &&
                                  COND string( WHEN r IS NOT INITIAL THEN `, ` ELSE space ) &&
                                  req_element ).
    ENDIF.

    " get aggregations
    LOOP AT aggr_elements INTO DATA(aggr_element).
      DELETE request_elements WHERE table_line = aggr_element-result_element.
      DATA(lv_aggregation) = |{ aggr_element-aggregation_method }( { aggr_element-input_element } ) as { aggr_element-result_element }|.
      APPEND lv_aggregation TO request_elements.
    ENDLOOP.

    " get $select

    DATA(columns) = REDUCE string( INIT r = ``
                            FOR req_element IN request_elements
                            NEXT r = r &&
                            COND string( WHEN r IS NOT INITIAL THEN `, ` ELSE space ) &&
                            req_element ).

    DATA(where) = io_request->get_filter( )->get_as_sql_string( ).
    IF where IS INITIAL.
      where = '1 = 1'.
    ENDIF.

    " get grouping
    DATA(groupby) = concat_lines_of( table = groupped_elements sep = ', ' ).

    DATA(lv_cte_name) = '+grouped'.
    DATA lt_range_pandll0id_q TYPE zcl_interco_class_filter=>ty_pandl_range.
    lt_range_pandll0id_q = zcl_interco_class_filter=>get_active_pandll0_range( ).

    IF io_request->is_total_numb_of_rec_requested( ).

      IF is_bg = abap_true.
        WITH
        +grouped AS (
          SELECT (columns) FROM zc_intercojeitemclassbg(
            p_companycode = @p_companycode,
            p_ledger = @p_ledger,
            p_fiscalyear = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype = @p_paymenttype )
          WHERE (where)
          GROUP BY (groupby)
        )
        SELECT COUNT(*) FROM (lv_cte_name)
          INTO @DATA(total_number_of_records).
      ELSE.
        WITH
        +grouped AS (
          SELECT (columns) FROM (lv_source)
          WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
          GROUP BY (groupby)
        )
        SELECT COUNT(*) FROM (lv_cte_name)
          INTO @total_number_of_records.
      ENDIF.
      io_response->set_total_number_of_records( total_number_of_records ).

      " AGREGADO DS4K9B5URA: guarda contra offset que supera el total ya conocido en la misma llamada.
      " Evita ejecutar el SELECT de datos cuando el Fiori manda $skip >= total (probe de fin de datos).
      IF io_request->is_data_requested( ) AND offset >= total_number_of_records.
        io_response->set_data( it_data = results ).
        RETURN.
      ENDIF.
    ENDIF.

    IF NOT io_request->is_data_requested( ).
      RETURN.
    ENDIF.

    IF pagesize <> if_rap_query_paging=>page_size_unlimited.
      IF is_bg = abap_true.
        SELECT (columns) FROM zc_intercojeitemclassbg(
            p_companycode = @p_companycode,
            p_ledger = @p_ledger,
            p_fiscalyear = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype = @p_paymenttype )
            WHERE (where)
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
              OFFSET @offset
              UP TO @pagesize ROWS.
      ELSE.
        SELECT (columns) FROM (lv_source)
            WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
              OFFSET @offset
              UP TO @pagesize ROWS.
      ENDIF.
    ELSE.
      IF is_bg = abap_true.
        " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12o (7c.3): tipo comercial en consulta BG sin límite
        SELECT (columns) FROM zc_intercojeitemclassbg(
            p_companycode = @p_companycode,
            p_ledger = @p_ledger,
            p_fiscalyear = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype = @p_paymenttype )
            WHERE (where)
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
            OFFSET @offset.
        " Fin EXT_OSCUGALD 07.10.2026 - C12o (7c.3)
      ELSE.
        SELECT (columns) FROM (lv_source)
            WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
            OFFSET @offset.
      ENDIF.
    ENDIF.

    " AGREGADO DS4K9B5URA: si el SELECT devolvio vacio con offset > 0 (overshoot de scroll),
    " el Fiori interpretaria el resultado vacio como "no hay registros" y limpiaría la pantalla.
    " Para evitarlo, se informa el total real via set_total_number_of_records para que el
    " framework sepa que el offset supero el fin del conjunto y deje de paginar sin limpiar.
    IF results IS INITIAL AND offset > 0.
      DATA lv_safety_total TYPE int8.
      IF is_bg = abap_true.
        SELECT COUNT(*) FROM zc_intercojeitemclassbg(
            p_companycode = @p_companycode,
            p_ledger      = @p_ledger,
            p_fiscalyear  = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype  = @p_paymenttype )
          WHERE (where) INTO @lv_safety_total.
      ELSE.
        SELECT COUNT(*) FROM (lv_source)
          WHERE (where) AND pandll0id IN @lt_range_pandll0id_q INTO @lv_safety_total.
      ENDIF.
      io_response->set_total_number_of_records( lv_safety_total ).
    ENDIF.
    io_response->set_data( it_data = results ).

  ENDMETHOD.
ENDCLASS.
