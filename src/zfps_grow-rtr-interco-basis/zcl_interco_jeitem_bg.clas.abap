CLASS zcl_interco_jeitem_bg DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .


  PUBLIC SECTION.

    INTERFACES if_bgmc_op_single_tx_uncontr.

    TYPES: BEGIN OF ty_range_entry,
             exclude   TYPE string,
             operation TYPE string,
             value1    TYPE string,
             value2    TYPE string,
           END OF ty_range_entry,
           tt_range_entries TYPE STANDARD TABLE OF ty_range_entry WITH DEFAULT KEY.

    " AGREGADO: value-help multi-select (Fiori manda "items", no "ranges", para filtros de seleccion de valor)
    TYPES: BEGIN OF ty_item_entry,
             key  TYPE string,
             text TYPE string,
           END OF ty_item_entry,
           tt_item_entries TYPE STANDARD TABLE OF ty_item_entry WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_filter,
             value  TYPE string,
             ranges TYPE tt_range_entries,
             items  TYPE tt_item_entries,
           END OF ty_filter.

    TYPES: BEGIN OF ty_allfilters,
             ccallocation    TYPE ty_filter,
             ccconsolidation TYPE ty_filter,
             " Inserido: Filtro de P&L todos los niveles desde el frontend ->
             pandll0id       TYPE ty_filter,
             pandll1id       TYPE ty_filter,
             pandll2id       TYPE ty_filter,
             pandll3id       TYPE ty_filter,
             pandll4id       TYPE ty_filter,
             pandll5id       TYPE ty_filter,
             " Inserido: Filtro de P&L todos los niveles desde el frontend <-
           END OF ty_allfilters.

    " AGREGADO: selection table generica (SIGN/OPTION/LOW/HIGH) reconocida por Open SQL en WHERE ... IN,
    " sin atarse al tipo exacto del campo destino (ccallocation, ccconsolidation, PandLLxId, etc.)
    TYPES: BEGIN OF ty_range_line,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE string,
             high   TYPE string,
           END OF ty_range_line,
           tt_range_line TYPE STANDARD TABLE OF ty_range_line WITH DEFAULT KEY.

    "! <p>AGREGADO: construye una selection table a partir de un ty_filter (ranges + items).
    "! ranges: soporta CONTAINS/STARTSWITH/ENDSWITH/EMPTY/NOTEMPTY + exclude (sign E/I).
    "! items: siempre inclusivos (sign I, option EQ) - value-help multi-select no manda exclude,
    "! la exclusion siempre llega via la pestaña "Condiciones" (ranges).</p>
    CLASS-METHODS build_range_from_filter
      IMPORTING is_filter       TYPE ty_filter
      RETURNING VALUE(rt_range) TYPE tt_range_line.

    "! <p>AGREGADO: regla exclusiva de PandLL0Id - intersecciona el filtro del usuario con el
    "! universo de L0 que tiene regla de clasificacion activa hoy (get_active_pandll0_range).
    "! Los demas niveles (L1-L5) NO tienen esta restriccion, son filtro directo del frontend.</p>
    CLASS-METHODS restrict_to_active_pandll0
      IMPORTING it_user_range   TYPE tt_range_line
      RETURNING VALUE(rt_range) TYPE zcl_interco_class_filter=>ty_pandl_range.

    "! <p>EXT_VINBARRI 17.11.2026: lista de campos para el SELECT del background.
    "! Columnas pedidas por la UI (separadas por coma) + obligatorias (claves, filtros aplicados en
    "! la grabacion, campos de la grabacion de la base en ZCL_INTERCO_BGPF y del join con la base
    "! actual en ZC_INTERCOJEITEMCLASSBG). Solo pasan campos que existen en ZINT_A_JEI y en
    "! ZC_INTERCOJEITEMCLASSV4 (lista blanca). Sin columnas informadas devuelve '*'.</p>
    CLASS-METHODS build_field_list
      IMPORTING iv_requested_columns TYPE string
      RETURNING VALUE(rv_fields)     TYPE string.

    METHODS: constructor
      IMPORTING
        id TYPE zr_intercojeitemclassbgtp-id.

protected section.
  PRIVATE SECTION.
    DATA id TYPE zr_intercojeitemclassbgtp-id.
    DATA parameters TYPE za_intercobasisruninbackground.
ENDCLASS.



CLASS ZCL_INTERCO_JEITEM_BG IMPLEMENTATION.


  METHOD constructor.
    me->id = id.
  ENDMETHOD.


  METHOD build_range_from_filter.
    LOOP AT is_filter-ranges INTO DATA(ls_range).
      DATA(lv_op)  = to_upper( ls_range-operation ).
      DATA(lv_opt) = SWITCH string( lv_op
        WHEN 'CONTAINS'      THEN 'CP'
        WHEN 'NOTCONTAINS'   THEN 'NP'
        WHEN 'STARTSWITH'    THEN 'CP'
        WHEN 'ENDSWITH'      THEN 'CP'
        WHEN 'NOTSTARTSWITH' THEN 'NP'
        WHEN 'NOTENDSWITH'   THEN 'NP'
        WHEN 'EMPTY'         THEN 'EQ'
        WHEN 'NOTEMPTY'      THEN 'NE'
        ELSE lv_op ).
      DATA(lv_low) = COND string(
        WHEN lv_op = 'CONTAINS'     OR lv_op = 'NOTCONTAINS'   THEN `*` && ls_range-value1 && `*`
        WHEN lv_op = 'STARTSWITH'   OR lv_op = 'NOTSTARTSWITH' THEN ls_range-value1 && `*`
        WHEN lv_op = 'ENDSWITH'     OR lv_op = 'NOTENDSWITH'   THEN `*` && ls_range-value1
        ELSE ls_range-value1 ).
      APPEND VALUE #(
        sign   = COND #( WHEN ls_range-exclude = 'X' THEN 'E' ELSE 'I' )
        option = lv_opt
        low    = lv_low
        high   = ls_range-value2
      ) TO rt_range.
    ENDLOOP.

    " value-help multi-select manda "items" (key/text), no "ranges" - siempre inclusivos,
    " la exclusion siempre llega via la pestaña "Condiciones" (ranges), nunca via items.
    LOOP AT is_filter-items INTO DATA(ls_item).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_item-key ) TO rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD restrict_to_active_pandll0.
    rt_range = zcl_interco_class_filter=>get_active_pandll0_range( ).
    IF it_user_range IS NOT INITIAL.
      DATA(lt_active) = rt_range.
      CLEAR rt_range.
      LOOP AT lt_active INTO DATA(ls_active).
        IF ls_active-low IN it_user_range.
          APPEND ls_active TO rt_range.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD build_field_list.
    " Sin columnas informadas (UI anterior a este ajuste): se graban todas, como antes.
    IF iv_requested_columns IS INITIAL.
      rv_fields = `*`.
      RETURN.
    ENDIF.

    " Obligatorias, se agregan aunque el usuario no las haya elegido:
    "   - claves de ZINT_A_JEI / ZC_INTERCOJEITEMCLASSBG
    "   - filtros aplicados en la grabacion (CCAllocation, CCConsolidation, P&L L0-L5)
    "   - grabacion de la base desde background (ZCL_INTERCO_BGPF) y join con la base actual
    DATA(lt_wanted) = VALUE string_table(
      ( `COMPANYCODE` ) ( `FISCALYEAR` ) ( `FISCALPERIOD` ) ( `ACCOUNTINGDOCUMENT` )
      ( `LEDGERGLLINEITEM` ) ( `LEDGER` ) ( `SOURCELEDGER` ) ( `PAYMENTTYPE` )
      ( `CCALLOCATION` ) ( `CCCONSOLIDATION` )
      ( `PANDLL0ID` ) ( `PANDLL1ID` ) ( `PANDLL2ID` ) ( `PANDLL3ID` ) ( `PANDLL4ID` ) ( `PANDLL5ID` )
      ( `GLACCOUNT` ) ( `COSTCENTERSTANDARDHIERAREA` ) ( `DEPARTMENT` ) ( `CONCEPT` )
      ( `COSTCENTER` ) ( `PROFITCENTER` )
      ( `COMPANYCODECURRENCY` ) ( `AMOUNTINCOMPANYCODECURRENCY` )
      ( `GLOBALCURRENCY` ) ( `AMOUNTINGLOBALCURRENCY` )
      ( `CREATIONDATETIME` ) ( `ISBILLABLE` ) ).

    SPLIT iv_requested_columns AT `,` INTO TABLE DATA(lt_requested).
    LOOP AT lt_requested INTO DATA(lv_requested).
      APPEND to_upper( condense( lv_requested ) ) TO lt_wanted.
    ENDLOOP.
    SORT lt_wanted.
    DELETE ADJACENT DUPLICATES FROM lt_wanted.

    " Lista blanca: solo campos que existen en la tabla destino y en la V4.
    DATA(lo_table) = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( 'ZINT_A_JEI' ) ).
    DATA(lo_v4)    = CAST cl_abap_structdescr( cl_abap_typedescr=>describe_by_name( 'ZC_INTERCOJEITEMCLASSV4' ) ).

    LOOP AT lt_wanted INTO DATA(lv_field).
      IF line_exists( lo_table->components[ name = lv_field ] )
     AND line_exists( lo_v4->components[ name = lv_field ] ).
        rv_fields = COND #( WHEN rv_fields IS INITIAL THEN lv_field ELSE |{ rv_fields }, { lv_field }| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontr~execute.

    SELECT SINGLE companycode, ledger, fiscalyear, fiscalperiod, paymenttype, allfilters, requestedcolumns FROM zint_a_jeh
      WHERE id = @me->id
      INTO CORRESPONDING FIELDS OF @parameters.

    " EXT_VINBARRI 17.11.2026: camino unico = cursor con PACKAGE SIZE sobre ZC_INTERCOJEITEMCLASSV4.
    " Se eliminan el flujo V2 (zc_intercojeitemclass), el ruteo por ZINTERCO_IC05_MATAG_ACTIVA + AG,
    " y el flujo OFFSET + cl_abap_parallel (ZINTERCO_IC05_CURSOR / _TASKS / _PERCENTAGE).
    SELECT name, low FROM zi_tvarvc
    WHERE name IN ( 'ZINTERCO_IC05_HOURS', 'ZINTERCO_IC05_PAGESIZE' )
    INTO TABLE @DATA(params).

    IF line_exists( params[ name = 'ZINTERCO_IC05_HOURS' ] ).
      DATA(hours) =  CONV int4(  params[ name = 'ZINTERCO_IC05_HOURS' ]-low ).
    ELSE.
      hours = 24.
    ENDIF.

    IF line_exists( params[ name = 'ZINTERCO_IC05_PAGESIZE' ] ).
      DATA(page_size) = CONV int4(  params[ name = 'ZINTERCO_IC05_PAGESIZE' ]-low ).
    ELSE.
      page_size = 500000.
    ENDIF.

    DATA(p_companycode) = parameters-companycode.
    DATA(p_ledger) = parameters-ledger.
    DATA(p_fiscalyear) = parameters-fiscalyear.
    DATA(p_fiscalperiod) = parameters-fiscalperiod.
    DATA(p_paymenttype) = parameters-paymenttype.

    FINAL(now) = utclong_current( ).
    FINAL(_24hbefore) = utclong_add( val = now hours = hours * -1 ).

    FINAL(where) = `createdat < @_24hbefore`. " bypassing atc

    DATA range_id_to_delete TYPE RANGE OF zint_a_jeh-id.
    SELECT 'I' AS sign, 'EQ' AS option, id AS low FROM zint_a_jeh
    WHERE (where)
      INTO TABLE @range_id_to_delete.
    IF sy-subrc = 0.
      DELETE FROM zint_a_jeh WHERE id IN @range_id_to_delete.
      DELETE FROM zint_a_jei WHERE id IN @range_id_to_delete.
    ENDIF.

    DELETE FROM zint_a_jei WHERE id = @me->id.
    COMMIT WORK AND WAIT.

    DATA ls_filters TYPE ty_allfilters.
    /ui2/cl_json=>deserialize(
           EXPORTING
             json        = parameters-allfilters
             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
           CHANGING
             data        = ls_filters ).

    " AGREGADO: mapeo de ranges+items centralizado en build_range_from_filter (antes duplicado
    " para cada campo). PandLL0Id sigue siendo el unico interseccionado con el universo activo
    " de reglas (restrict_to_active_pandll0) - L1-L5 son filtro directo del frontend.
    DATA(lt_range_ccallocation)    = build_range_from_filter( ls_filters-ccallocation ).
    DATA(lt_range_ccconsolidation) = build_range_from_filter( ls_filters-ccconsolidation ).

    DATA(lt_range_pandll0id_user) = build_range_from_filter( ls_filters-pandll0id ).
    DATA(lt_range_pandll0id)      = restrict_to_active_pandll0( lt_range_pandll0id_user ).
    DATA(lt_range_pandll1id)      = build_range_from_filter( ls_filters-pandll1id ).
    DATA(lt_range_pandll2id)      = build_range_from_filter( ls_filters-pandll2id ).
    DATA(lt_range_pandll3id)      = build_range_from_filter( ls_filters-pandll3id ).
    DATA(lt_range_pandll4id)      = build_range_from_filter( ls_filters-pandll4id ).
    DATA(lt_range_pandll5id)      = build_range_from_filter( ls_filters-pandll5id ).

    DATA(lv_source) = |zc_intercojeitemclassv4( p_companycode = @p_companycode, p_ledger = @p_ledger, | &&
                      |p_fiscalyear = @p_fiscalyear, p_fiscalperiod = @p_fiscalperiod, | &&
                      |p_paymenttype = @p_paymenttype )|.

    DATA results_db TYPE TABLE OF zint_a_jei.

*** ====================================================================
*** CURSOR: passe unico com PACKAGE SIZE.
*** Computa o CDS 1x; cursor entrega page_size registros por iteracao
*** sem OFFSET, sem recompute.
*** ====================================================================
    " EXT_VINBARRI 17.11.2026: solo las columnas pedidas por la UI + obligatorias (antes FIELDS *).
    " HANA deja de calcular lo que nadie pidio (textos P&L, Campana, Index*, nombres de regla/concepto).
    DATA(lv_fields) = build_field_list( parameters-requestedcolumns ).

    SELECT FROM (lv_source)
           FIELDS (lv_fields)
           WHERE ccallocation    IN @lt_range_ccallocation
             AND ccconsolidation IN @lt_range_ccconsolidation
             " Inserido - Filtro de P&L todos los niveles viene desde el Frontend ->
             AND PandLL0Id       IN @lt_range_pandll0id
             AND PandLL1Id       IN @lt_range_pandll1id
             AND PandLL2Id       IN @lt_range_pandll2id
             AND PandLL3Id       IN @lt_range_pandll3id
             AND PandLL4Id       IN @lt_range_pandll4id
             AND PandLL5Id       IN @lt_range_pandll5id
             " Inserido - Filtro de P&L todos los niveles viene desde el Frontend <-
           INTO CORRESPONDING FIELDS OF TABLE @results_db
           PACKAGE SIZE @page_size.

      DO lines( results_db ) TIMES.
        DATA(result_db) = REF #( results_db[ sy-index ] ).
        result_db->id          = me->id.
        result_db->bgcreatedat = now.
        result_db->bgcreatedby = sy-uname.
      ENDDO.

      MODIFY zint_a_jei FROM TABLE @results_db.
    ENDSELECT.

    COMMIT WORK.

    DATA bg_processing TYPE zr_intercojeitemclassbgtp.
    FINAL(all_fields) = `*`.
    SELECT SINGLE (all_fields) FROM  zi_intercojeitemclassbg
    WHERE  companycode = @parameters-companycode
         AND fiscalyear = @parameters-fiscalyear
          AND fiscalperiod = @parameters-fiscalperiod
          AND ledger = @parameters-ledger
          AND paymenttype = @parameters-paymenttype
          INTO CORRESPONDING FIELDS OF @bg_processing.

    CLEAR bg_processing-pending.

    MODIFY ENTITIES OF zr_intercojeitemclassbgtp
      ENTITY header
      UPDATE FIELDS ( pending ) WITH VALUE #( ( %key = CORRESPONDING #( bg_processing ) pending = space ) ).
    COMMIT WORK.

  ENDMETHOD.
ENDCLASS.
