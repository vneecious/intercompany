CLASS lcl_query_in_parallel DEFINITION.

  PUBLIC SECTION.

    TYPES: ty_glaccount TYPE RANGE OF zi_intercojeitem-glaccount.

    INTERFACES if_abap_parallel.
    METHODS constructor IMPORTING
                          io_request    TYPE REF TO  if_rap_query_request
                          it_glaccounts TYPE ty_glaccount.

    DATA: sort_elements     TYPE if_rap_query_request=>tt_sort_elements READ-ONLY,
          request_elements  TYPE if_rap_query_request=>tt_requested_elements READ-ONLY,
          aggr_elements     TYPE if_rap_query_aggregation=>tt_aggregation_elements READ-ONLY,
          groupped_elements TYPE if_rap_query_aggregation=>tt_grouped_elements READ-ONLY,
          offset            TYPE int8 READ-ONLY,
          pagesize          TYPE int8 READ-ONLY,
          where             TYPE string READ-ONLY,
          parameters        TYPE if_rap_query_request=>tt_parameters READ-ONLY,
          glaccounts        TYPE lcl_query_in_parallel=>ty_glaccount READ-ONLY.


    DATA results TYPE TABLE OF zc_intercojeitemclass.

ENDCLASS.

CLASS lcl_query_in_parallel IMPLEMENTATION.

  METHOD constructor.

    sort_elements = io_request->get_sort_elements( ).
    request_elements = io_request->get_requested_elements( ).
    aggr_elements = io_request->get_aggregation( )->get_aggregated_elements( ).
    groupped_elements = io_request->get_aggregation( )->get_grouped_elements( ).
    offset = io_request->get_paging( )->get_offset( ).
    pagesize = io_request->get_paging( )->get_page_size( ).
    where = io_request->get_filter( )->get_as_sql_string( ).
    parameters = io_request->get_parameters( ).
    glaccounts = it_glaccounts.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

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

    " get $filter
    IF where IS INITIAL.
      where = '1 = 1'.
    ENDIF.

    where = |{ where } AND GLACCOUNT IN @GLACCOUNTS|.

    DATA(groupby) = concat_lines_of( table = groupped_elements sep = ', ' ).

    DATA lt_range_pandll0id_q TYPE zcl_interco_class_filter=>ty_pandl_range.
    lt_range_pandll0id_q = zcl_interco_class_filter=>get_active_pandll0_range( ).

    "  Parameters
    DATA(p_companycode) = CONV bukrs( parameters[ parameter_name = 'P_COMPANYCODE' ]-value ).
    DATA(p_ledger) = CONV fins_ledger( parameters[ parameter_name = 'P_LEDGER' ]-value ).
    DATA(p_fiscalyear) = CONV gjahr( parameters[ parameter_name = 'P_FISCALYEAR' ]-value ).
    DATA(p_fiscalperiod) = CONV poper( parameters[ parameter_name = 'P_FISCALPERIOD' ]-value ).
    DATA(p_paymenttype) = CONV zint_dte_paymenttype( parameters[ parameter_name = 'P_PAYMENTTYPE' ]-value ).

    SELECT (columns) FROM zc_intercojeitemclass(
        p_companycode = @p_companycode,
        p_ledger = @p_ledger,
        p_fiscalyear = @p_fiscalyear,
        p_fiscalperiod = @p_fiscalperiod,
        p_paymenttype = @p_paymenttype,
        p_bgprocessing = @abap_false )
        WHERE (where) AND pandll0id IN @lt_range_pandll0id_q
        GROUP BY (groupby)
        INTO CORRESPONDING FIELDS OF TABLE @results.

  ENDMETHOD.

ENDCLASS.
