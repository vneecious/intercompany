CLASS zcl_intercoproposalitemtp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_intercoproposalitemtp IMPLEMENTATION.
  METHOD if_rap_query_provider~select.
*    DATA results TYPE TABLE OF ZI_IntercoProposalItem.
*
*    DATA(sort_elements) = io_request->get_sort_elements( ).
*    DATA(request_elements) = io_request->get_requested_elements( ).
*    DATA(aggr_elements) = io_request->get_aggregation( )->get_aggregated_elements( ).
*    DATA(groupped_elements) = io_request->get_aggregation( )->get_grouped_elements( ).
*    DATA(offset) = io_request->get_paging( )->get_offset( ).
*    DATA(pagesize) = io_request->get_paging( )->get_page_size( ).
*    DATA orderby TYPE string.
*
*    " Build orderby
*    LOOP AT sort_elements INTO DATA(sort_element).
*      IF NOT line_exists( request_elements[ table_line = sort_element-element_name ] ).
*        CONTINUE.
*      ENDIF.
*      orderby = orderby &&
*                   COND string(  WHEN orderby IS INITIAL THEN `` ELSE `, ` ) &&
*                   sort_element-element_name &&
*                   COND string( WHEN sort_element-descending = abap_true THEN ` descending` ELSE space ).
*    ENDLOOP.
*    IF sy-subrc <> 0.
*      orderby = REDUCE string( INIT r = ``
*                                  FOR req_element IN request_elements
*                                  NEXT r = r &&
*                                  COND string( WHEN r IS NOT INITIAL THEN `, ` ELSE space ) &&
*                                  req_element ).
*    ENDIF.
*
*    " get aggregations
*    LOOP AT aggr_elements INTO DATA(aggr_element).
*      DELETE request_elements WHERE table_line = aggr_element-result_element.
*      DATA(lv_aggregation) = |{ aggr_element-aggregation_method }( { aggr_element-input_element } ) as { aggr_element-result_element }|.
*      APPEND lv_aggregation TO request_elements.
*    ENDLOOP.
*
*    " get $select
*
*    DATA(columns) = REDUCE string( INIT r = ``
*                            FOR req_element IN request_elements
*                            NEXT r = r &&
*                            COND string( WHEN r IS NOT INITIAL THEN `, ` ELSE space ) &&
*                            req_element ).
*
*    " get $filter
*    DATA(where) = io_request->get_filter( )->get_as_sql_string( ).
*    IF where IS INITIAL.
*      where = '1 = 1'.
*    ENDIF.
*
*    " get grouping
*    DATA(groupby) = concat_lines_of( table = groupped_elements sep = ', ' ).
*
*    DATA range_origin_object_type TYPE RANGE OF zi_intercojeitem-originobjecttype.
*
*    "  Parameters
*    DATA(parameters) = io_request->get_parameters( ).
**    DATA(p_companycode) = CONV bukrs( parameters[ parameter_name = 'P_COMPANYCODE' ]-value ).
**    DATA(p_ledger) = CONV fins_ledger( parameters[ parameter_name = 'P_LEDGER' ]-value ).
**    DATA(p_fiscalyear) = CONV gjahr( parameters[ parameter_name = 'P_FISCALYEAR' ]-value ).
**    DATA(p_fiscalperiod) = CONV poper( parameters[ parameter_name = 'P_FISCALPERIOD' ]-value ).
**    DATA(p_paymenttype) = CONV zint_dte_paymenttype( parameters[ parameter_name = 'P_PAYMENTTYPE' ]-value ).
**    DATA(p_createdon) = parameters[ parameter_name = 'P_CREATEDON' ]-value.
**    DATA(p_createdat) = parameters[ parameter_name = 'P_CREATEDAT' ]-value.
*
*    " Run and persist classifications
**    zcl_interco_class_engine_mult=>new( )->for(
**        i_companycode = p_companycode
**        i_fiscalperiod = p_fiscalperiod
**        i_fiscalyear = p_fiscalyear
**        i_ledger = p_ledger
**        i_paymenttype = p_paymenttype
**    )->run(  ).
*
*    IF io_request->is_total_numb_of_rec_requested( ).
*      SELECT SINGLE COUNT(*) FROM ZI_IntercoProposalItem
**                (
**                p_companycode = @p_companycode,
**                p_ledger = @p_ledger,
**                p_fiscalyear = @p_fiscalyear,
**                p_fiscalperiod = @p_fiscalperiod,
**                p_paymenttype = @p_paymenttype,
**                p_createdon = @p_createdon,
**                p_createdat = @p_createdat )
*                WHERE (where)
*                     INTO @DATA(total_number_of_records).
*      io_response->set_total_number_of_records( total_number_of_records ).
*    ENDIF.
*
*    IF NOT io_request->is_data_requested( ).
*      RETURN.
*    ENDIF.
*
*    IF pagesize <> if_rap_query_paging=>page_size_unlimited.
*      SELECT (columns) FROM ZI_IntercoProposalItem
**      (
**          p_companycode = @p_companycode,
**          p_ledger = @p_ledger,
**          p_fiscalyear = @p_fiscalyear,
**          p_fiscalperiod = @p_fiscalperiod,
**          p_paymenttype = @p_paymenttype,
**          p_createdon = @p_createdon,
**          p_createdat = @p_createdat )
*          WHERE (where)
*               GROUP BY (groupby)
*               ORDER BY (orderby)
*          INTO CORRESPONDING FIELDS OF TABLE @results
*            OFFSET @offset
*            UP TO @pagesize ROWS.
*    ELSE.
*      SELECT (columns) FROM ZI_IntercoProposalItem
**      (
**          p_companycode = @p_companycode,
**          p_ledger = @p_ledger,
**          p_fiscalyear = @p_fiscalyear,
**          p_fiscalperiod = @p_fiscalperiod,
**          p_paymenttype = @p_paymenttype,
**          p_createdon = @p_createdon,
**          p_createdat = @p_createdat )
*          WHERE (where)
*               GROUP BY (groupby)
*               ORDER BY (orderby)
*          INTO CORRESPONDING FIELDS OF TABLE @results
*          OFFSET @offset.
*    ENDIF.
*
*    io_response->set_data( results ).

  ENDMETHOD.

ENDCLASS.
