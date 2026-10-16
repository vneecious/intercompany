CLASS lcl_query_in_parallel DEFINITION.

  PUBLIC SECTION.

    TYPES: ty_glaccount TYPE RANGE OF zi_intercojeitem-glaccount.

    INTERFACES if_abap_parallel.
    METHODS constructor IMPORTING
                          iv_id         TYPE zint_a_jeh-id
                          iv_parameters TYPE za_intercobasisruninbackground
*                          it_glaccounts TYPE ty_glaccount
                          iv_now        TYPE utclong
                          iv_pagesize   TYPE int4
                          iv_offset     TYPE int4
                          iv_use_v3     TYPE abap_boolean DEFAULT abap_false.

    DATA parameters TYPE za_intercobasisruninbackground READ-ONLY.
*    DATA glaccounts TYPE ty_glaccount READ-ONLY.
    DATA page_size TYPE int4 READ-ONLY.
    DATA offset TYPE int4 READ-ONLY.
    DATA now TYPE utclong READ-ONLY.
    DATA id TYPE zint_a_jeh-id READ-ONLY.
    DATA use_v3     TYPE abap_boolean  READ-ONLY.


ENDCLASS.

CLASS lcl_query_in_parallel IMPLEMENTATION.

  METHOD constructor.
    parameters = iv_parameters.
*    glaccounts = it_glaccounts.
    page_size = iv_pagesize.
    offset = iv_offset.
    now = iv_now.
    id = iv_id.
    use_v3     = iv_use_v3.
  ENDMETHOD.


  METHOD if_abap_parallel~do.
    DATA results TYPE TABLE OF zc_intercojeitemclass.


    DATA ls_filters TYPE zcl_interco_jeitem_bg=>ty_allfilters.
    /ui2/cl_json=>deserialize(
           EXPORTING
             json        = parameters-allfilters
             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
           CHANGING
             data        = ls_filters ).

    " AGREGADO: mismo refactor que en execute (ZCL_INTERCO_JEITEM_BG) - build_range_from_filter
    " centraliza el mapeo de ranges+items, restrict_to_active_pandll0 la regla exclusiva de L0.
    DATA(lt_range_ccallocation)    = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-ccallocation ).
    DATA(lt_range_ccconsolidation) = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-ccconsolidation ).

    DATA(lt_range_pandll0id_user) = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-pandll0id ).
    DATA(lt_range_pandll0id)      = zcl_interco_jeitem_bg=>restrict_to_active_pandll0( lt_range_pandll0id_user ).
    DATA(lt_range_pandll1id)      = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-pandll1id ).
    DATA(lt_range_pandll2id)      = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-pandll2id ).
    DATA(lt_range_pandll3id)      = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-pandll3id ).
    DATA(lt_range_pandll4id)      = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-pandll4id ).
    DATA(lt_range_pandll5id)      = zcl_interco_jeitem_bg=>build_range_from_filter( ls_filters-pandll5id ).

    DATA(columns) = `*`.

    IF me->use_v3 = abap_true.
      SELECT (columns) FROM zc_intercojeitemclassv3(
              p_companycode  = @parameters-companycode,
              p_ledger       = @parameters-ledger,
              p_fiscalyear   = @parameters-fiscalyear,
              p_fiscalperiod = @parameters-fiscalperiod,
              p_paymenttype  = @parameters-paymenttype )
        WHERE ccallocation    IN @lt_range_ccallocation
          AND ccconsolidation IN @lt_range_ccconsolidation
          AND pandll0id       IN @lt_range_pandll0id
          AND pandll1id       IN @lt_range_pandll1id
          AND pandll2id       IN @lt_range_pandll2id
          AND pandll3id       IN @lt_range_pandll3id
          AND pandll4id       IN @lt_range_pandll4id
          AND pandll5id       IN @lt_range_pandll5id
        ORDER BY companycode, fiscalyear, accountingdocument, ledger, ledgergllineitem
        INTO CORRESPONDING FIELDS OF TABLE @results
        OFFSET @offset UP TO @page_size ROWS.
    ELSE.
      SELECT (columns) FROM zc_intercojeitemclass(
              p_companycode  = @parameters-companycode,
              p_ledger       = @parameters-ledger,
              p_fiscalyear   = @parameters-fiscalyear,
              p_fiscalperiod = @parameters-fiscalperiod,
              p_paymenttype  = @parameters-paymenttype,
              p_bgprocessing = @abap_false )
        WHERE ccallocation    IN @lt_range_ccallocation
          AND ccconsolidation IN @lt_range_ccconsolidation
          AND pandll0id       IN @lt_range_pandll0id
          AND pandll1id       IN @lt_range_pandll1id
          AND pandll2id       IN @lt_range_pandll2id
          AND pandll3id       IN @lt_range_pandll3id
          AND pandll4id       IN @lt_range_pandll4id
          AND pandll5id       IN @lt_range_pandll5id
        ORDER BY companycode, fiscalyear, accountingdocument, ledger, ledgergllineitem
        INTO CORRESPONDING FIELDS OF TABLE @results
        OFFSET @offset UP TO @page_size ROWS.
    ENDIF.

    DATA results_db TYPE TABLE OF zint_a_jei.
    results_db = CORRESPONDING #( results ).

    LOOP AT results_db REFERENCE INTO DATA(result_db).
      result_db->id = id.
      result_db->bgcreatedat = now.
      result_db->bgcreatedby = sy-uname.
    ENDLOOP.

    MODIFY zint_a_jei
      FROM TABLE @results_db.

    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
