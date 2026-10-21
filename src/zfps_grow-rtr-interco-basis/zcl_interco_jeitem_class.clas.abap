CLASS zcl_interco_jeitem_class DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INTERCO_JEITEM_CLASS IMPLEMENTATION.


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

    " AGREGADO DS4K9B5URA: ruteo automatico V2/V3 para el path online (no-BG).
    " Se requieren AMBAS condiciones para usar V3:
    " parametro ZINTERCO_IC05_MATAG_ACTIVA = 'X' Y datos presentes en ZINT_A_JEITEM_AG.
    " Si el parametro esta desactivado (rollback), se usa V2 aunque haya datos en la tabla ag.
    DATA(use_v3) = abap_false.
    IF p_bgprocessing <> c_bgprocessing-on.
      SELECT SINGLE low FROM zi_tvarvc
        WHERE name = 'ZINTERCO_IC05_MATAG_ACTIVA'
        INTO @DATA(lv_matag_activa_online).
      IF lv_matag_activa_online = 'X'.
        SELECT COUNT(*) FROM zint_a_jeitem_ag
          WHERE companycode  = @p_companycode
            AND fiscalyear   = @p_fiscalyear
            AND fiscalperiod = @p_fiscalperiod
            AND ledger       = @p_ledger
            AND paymenttype  = @p_paymenttype
          INTO @DATA(ag_count_online).
        IF ag_count_online > 0.
          use_v3 = abap_true.
        ENDIF.
      ENDIF.
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
*   ELIMINADO DS4K9B5URA (mantenido para rollback): IF sy-subrc <> 0 no detecta CONTINUE dentro del LOOP;
*   si todos los sort_elements hacen CONTINUE, sy-subrc queda en 0 pero orderby queda vacio,
*   causando ORDER BY ('') no-determinístico y paginas inconsistentes entre requests.
*   IF sy-subrc <> 0.
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

      IF p_bgprocessing = c_bgprocessing-on.

*        SELECT COUNT(*) FROM zc_intercojeitemclassbg(
*            p_companycode = @p_companycode,
*            p_ledger = @p_ledger,
*            p_fiscalyear = @p_fiscalyear,
*            p_fiscalperiod = @p_fiscalperiod,
*            p_paymenttype = @p_paymenttype )
*                    WHERE (where)
*                         INTO @DATA(total_number_of_records).

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

      ELSEIF use_v3 = abap_true.
        " AGREGADO DS4K9B5URA: COUNT desde V3 (tabla materializada)
*        SELECT COUNT(*) FROM zc_intercojeitemclassv3(
*            p_companycode  = @p_companycode,
*            p_ledger       = @p_ledger,
*            p_fiscalyear   = @p_fiscalyear,
*            p_fiscalperiod = @p_fiscalperiod,
*            p_paymenttype  = @p_paymenttype )
*                    WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
*                         INTO @total_number_of_records.

        WITH
        +grouped AS (
          SELECT (columns) FROM zc_intercojeitemclassv3(
            p_companycode = @p_companycode,
            p_ledger = @p_ledger,
            p_fiscalyear = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype = @p_paymenttype )
          WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
          GROUP BY (groupby)
        )
        SELECT COUNT(*) FROM (lv_cte_name)
          INTO @total_number_of_records.

      ELSE.
*       ELIMINADO DS4K9B5URA (mantenido para rollback): COUNT desde V2 (~20 JOINs de jerarquias)
*        SELECT COUNT(*) FROM zc_intercojeitemclass(
*            p_companycode = @p_companycode,
*            p_ledger = @p_ledger,
*            p_fiscalyear = @p_fiscalyear,
*            p_fiscalperiod = @p_fiscalperiod,
*            p_paymenttype = @p_paymenttype,
*            p_bgprocessing = @p_bgprocessing )
*                    WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
*                         INTO @total_number_of_records.

        WITH
        +grouped AS (
          SELECT (columns) FROM zc_intercojeitemclass(
            p_companycode = @p_companycode,
            p_ledger = @p_ledger,
            p_fiscalyear = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype = @p_paymenttype,
            p_bgprocessing = @p_bgprocessing )
          WHERE (where) AND  pandll0id IN @lt_range_pandll0id_q
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
      IF p_bgprocessing = c_bgprocessing-on.
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
      ELSEIF use_v3 = abap_true.
        " AGREGADO DS4K9B5URA: SELECT desde V3 con pagina (tabla materializada)
        SELECT (columns) FROM zc_intercojeitemclassv3(
            p_companycode  = @p_companycode,
            p_ledger       = @p_ledger,
            p_fiscalyear   = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype  = @p_paymenttype )
            WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
              OFFSET @offset
              UP TO @pagesize ROWS.
      ELSE.
*       ELIMINADO DS4K9B5URA (mantenido para rollback): SELECT desde V2 con pagina (~20 JOINs de jerarquias)
        SELECT (columns) FROM zc_intercojeitemclass(
      p_companycode = @p_companycode,
      p_ledger = @p_ledger,
      p_fiscalyear = @p_fiscalyear,
      p_fiscalperiod = @p_fiscalperiod,
      p_paymenttype = @p_paymenttype,
      p_bgprocessing = @p_bgprocessing )
      WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
           GROUP BY (groupby)
           ORDER BY (orderby)
      INTO CORRESPONDING FIELDS OF TABLE @results
        OFFSET @offset
        UP TO @pagesize ROWS.
      ENDIF.
    ELSE.
      IF p_bgprocessing = c_bgprocessing-on.
        SELECT (columns) FROM zc_intercojeitemclassbg(
            p_companycode = @p_companycode,
            p_ledger = @p_ledger,
            p_fiscalyear = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype = @p_bgprocessing )
            WHERE (where)
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
            OFFSET @offset.
      ELSEIF use_v3 = abap_true.
        " AGREGADO DS4K9B5URA: SELECT desde V3 sin limite (tabla materializada)
        SELECT (columns) FROM zc_intercojeitemclassv3(
            p_companycode  = @p_companycode,
            p_ledger       = @p_ledger,
            p_fiscalyear   = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype  = @p_paymenttype )
            WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
                 GROUP BY (groupby)
                 ORDER BY (orderby)
            INTO CORRESPONDING FIELDS OF TABLE @results
            OFFSET @offset.
      ELSE.
*       ELIMINADO DS4K9B5URA (mantenido para rollback): SELECT desde V2 sin limite (~20 JOINs de jerarquias)
        SELECT (columns) FROM zc_intercojeitemclass(
  p_companycode = @p_companycode,
  p_ledger = @p_ledger,
  p_fiscalyear = @p_fiscalyear,
  p_fiscalperiod = @p_fiscalperiod,
  p_paymenttype = @p_paymenttype,
  p_bgprocessing = @p_bgprocessing )
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
      IF p_bgprocessing = c_bgprocessing-on.
        SELECT COUNT(*) FROM zc_intercojeitemclassbg(
            p_companycode = @p_companycode,
            p_ledger      = @p_ledger,
            p_fiscalyear  = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype  = @p_paymenttype )
          WHERE (where) INTO @lv_safety_total.
      ELSEIF use_v3 = abap_true.
        SELECT COUNT(*) FROM zc_intercojeitemclassv3(
            p_companycode  = @p_companycode,
            p_ledger       = @p_ledger,
            p_fiscalyear   = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype  = @p_paymenttype )
          WHERE (where) AND pandll0id IN @lt_range_pandll0id_q INTO @lv_safety_total.
      ELSE.
        SELECT COUNT(*) FROM zc_intercojeitemclass(
            p_companycode  = @p_companycode,
            p_ledger       = @p_ledger,
            p_fiscalyear   = @p_fiscalyear,
            p_fiscalperiod = @p_fiscalperiod,
            p_paymenttype  = @p_paymenttype,
            p_bgprocessing = @p_bgprocessing )
          WHERE (where) AND pandll0id IN @lt_range_pandll0id_q INTO @lv_safety_total.
      ENDIF.
      io_response->set_total_number_of_records( lv_safety_total ).
    ENDIF.
    io_response->set_data( it_data = results ).

  ENDMETHOD.
ENDCLASS.
