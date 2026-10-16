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

    "! <p>AGREGADO: construye una selection table a partir de un ty_filter (ranges + items),
    "! reemplazando el mapeo de operation->option duplicado en execute y lcl_query_in_parallel.
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

    METHODS: constructor
      IMPORTING
        id TYPE zr_intercojeitemclassbgtp-id.

  PRIVATE SECTION.
    DATA id TYPE zr_intercojeitemclassbgtp-id.
    DATA parameters TYPE za_intercobasisruninbackground.
ENDCLASS.



CLASS zcl_interco_jeitem_bg IMPLEMENTATION.

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

  METHOD if_bgmc_op_single_tx_uncontr~execute.

    DATA clean TYPE i.

    SELECT SINGLE companycode, ledger, fiscalyear, fiscalperiod, paymenttype, allfilters FROM zint_a_jeh
      WHERE id = @me->id
      INTO CORRESPONDING FIELDS OF @parameters.

    SELECT name, low FROM zi_tvarvc
    WHERE name IN ( 'ZINTERCO_IC05_HOURS', 'ZINTERCO_IC05_PAGESIZE', 'ZINTERCO_IC05_TASKS',
                    'ZINTERCO_IC05_PERCENTAGE', 'ZINTERCO_IC05_CURSOR', 'ZINTERCO_IC05_MATAG_ACTIVA' )
    INTO TABLE @DATA(params).

    IF line_exists( params[ name = 'ZINTERCO_IC05_HOURS' ] ).
      DATA(hours) =  CONV int4(  params[ name = 'ZINTERCO_IC05_HOURS' ]-low ).
    ELSE.
      hours = 24.
    ENDIF.

    IF line_exists( params[ name = 'ZINTERCO_IC05_TASKS' ] ).
      DATA(tasks) =  CONV int4(  params[ name = 'ZINTERCO_IC05_TASKS' ]-low ).
    ELSE.
      tasks = 10.
    ENDIF.

    IF line_exists( params[ name = 'ZINTERCO_IC05_PAGESIZE' ] ).
      DATA(page_size) = CONV int4(  params[ name = 'ZINTERCO_IC05_PAGESIZE' ]-low ).
    ELSE.
      page_size = 500000.
    ENDIF.

    IF line_exists( params[ name = 'ZINTERCO_IC05_PERCENTAGE' ] ).
      DATA(percentage) =  CONV int4(  params[ name = 'ZINTERCO_IC05_PERCENTAGE' ]-low ).
    ELSE.
      percentage = 20.
    ENDIF.

    DATA(use_cursor) = COND abap_bool(
      WHEN line_exists( params[ name = 'ZINTERCO_IC05_CURSOR' ] )
       AND params[ name = 'ZINTERCO_IC05_CURSOR' ]-low = 'X'
      THEN abap_true ELSE abap_false ).

    " AGREGADO DS4K9B5URA: flag de activacion de la nueva clasificacion por materializacion.
    " Se requiere AMBAS condiciones para usar V3: parametro = 'X' Y datos en tabla ag.
    DATA(lv_matag_activa_bg) = COND abap_bool(
      WHEN line_exists( params[ name = 'ZINTERCO_IC05_MATAG_ACTIVA' ] )
       AND params[ name = 'ZINTERCO_IC05_MATAG_ACTIVA' ]-low = 'X'
      THEN abap_true ELSE abap_false ).

    DATA results TYPE TABLE OF zc_intercojeitemclass.
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

    DATA results_db TYPE TABLE OF zint_a_jei.

    IF use_cursor = abap_true.
*** ====================================================================
*** CURSOR (ZINTERCO_IC05_CURSOR = 'X'): passe unico com PACKAGE SIZE.
*** Computa o CDS 1x; cursor entrega page_size registros por iteracao
*** sem OFFSET, sem recompute, sem cl_abap_parallel.
*** ====================================================================
      " AGREGADO DS4K9B5URA: ruteo automatico V2/V3 - se requieren AMBAS condiciones:
      " parametro ZINTERCO_IC05_MATAG_ACTIVA = 'X' Y datos presentes en ZINT_A_JEITEM_AG.
      " Si solo hay datos en la tabla pero el parametro esta desactivado (rollback),
      " se usa V2 para evitar leer datos obsoletos de la tabla ag.
      IF lv_matag_activa_bg = abap_true.
        " AGREGADO DS4K9B5URA: V3 - tabla materializada (reemplaza ~20 JOINs de jerarquias)
        SELECT FROM zc_intercojeitemclassv3(
                      p_companycode  = @p_companycode,
                      p_ledger       = @p_ledger,
                      p_fiscalyear   = @p_fiscalyear,
                      p_fiscalperiod = @p_fiscalperiod,
                      p_paymenttype  = @p_paymenttype )
               FIELDS *
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
               INTO CORRESPONDING FIELDS OF TABLE @results
               PACKAGE SIZE @page_size.

          results_db = CORRESPONDING #( results ).
          DO lines( results_db ) TIMES.
            DATA(result_db) = REF #( results_db[ sy-index ] ).
            result_db->id          = me->id.
            result_db->bgcreatedat = now.
            result_db->bgcreatedby = sy-uname.
          ENDDO.

          MODIFY zint_a_jei FROM TABLE @results_db.
        ENDSELECT.
      ELSE.
        " ELIMINADO DS4K9B5URA (mantenido para rollback): flujo V2 original (~20 JOINs de jerarquias).
        " Se ejecuta cuando no hay datos materializados en ZINT_A_JEITEM_AG para el periodo.
        SELECT FROM zc_intercojeitemclass(
                      p_companycode  = @p_companycode,
                      p_ledger       = @p_ledger,
                      p_fiscalyear   = @p_fiscalyear,
                      p_fiscalperiod = @p_fiscalperiod,
                      p_paymenttype  = @p_paymenttype,
                      p_bgprocessing = @abap_false )
               FIELDS *
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
               INTO CORRESPONDING FIELDS OF TABLE @results
               PACKAGE SIZE @page_size.

          results_db = CORRESPONDING #( results ).
          DO lines( results_db ) TIMES.
            result_db = REF #( results_db[ sy-index ] ).
            result_db->id          = me->id.
            result_db->bgcreatedat = now.
            result_db->bgcreatedby = sy-uname.
          ENDDO.

          MODIFY zint_a_jei FROM TABLE @results_db.
        ENDSELECT.
      ENDIF.

      COMMIT WORK.

    ELSE.
*** ====================================================================
*** OFFSET + cl_abap_parallel (ZINTERCO_IC05_CURSOR ausente ou <> 'X').
*** Fallback: recomputa o CDS por pagina via OFFSET; cada task
*** paralela commita independentemente.
*** ====================================================================
      DATA(lv_use_v3_offset) = lv_matag_activa_bg.

      TRY.
          IF lv_use_v3_offset = abap_true.
            SELECT SINGLE COUNT(*) AS qtd FROM zc_intercojeitemclassv3(
                p_companycode  = @p_companycode,
                p_ledger       = @p_ledger,
                p_fiscalyear   = @p_fiscalyear,
                p_fiscalperiod = @p_fiscalperiod,
                p_paymenttype  = @p_paymenttype )
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
              INTO @DATA(total_qtd).
          ELSE.
            SELECT SINGLE COUNT(*) AS qtd FROM zc_intercojeitemclass(
                p_companycode  = @p_companycode,
                p_ledger       = @p_ledger,
                p_fiscalyear   = @p_fiscalyear,
                p_fiscalperiod = @p_fiscalperiod,
                p_paymenttype  = @p_paymenttype,
                p_bgprocessing = @abap_false )
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
              INTO @total_qtd.
          ENDIF.
        CATCH cx_sy_open_sql_db.
      ENDTRY.

      DATA: task_id           TYPE i VALUE 0,
            current_task_load TYPE int8.

      DATA parallel TYPE REF TO lcl_query_in_parallel.
      DATA parallel_instances_in TYPE cl_abap_parallel=>t_in_inst_tab.

      DATA(offset)            = CONV int4( 0 ).
      DATA(processed_batches) = CONV int4( 0 ).

      WHILE offset < total_qtd.

        DATA(batch_size) = page_size.
        IF offset + batch_size > total_qtd.
          batch_size = total_qtd - offset.
        ENDIF.

        parallel = NEW #(
                      iv_id         = me->id
                      iv_now        = now
                      iv_parameters = parameters
                      iv_offset     = offset
                      iv_pagesize   = batch_size
                      iv_use_v3     = lv_use_v3_offset ).

        APPEND parallel TO parallel_instances_in.
        offset            = offset + batch_size.
        processed_batches = processed_batches + 1.

      ENDWHILE.

      DATA(parallel_processor) = NEW cl_abap_parallel(
        p_percentage   = percentage
        p_num_tasks    = tasks
        p_local_server = abap_true
       ).

      DATA debug TYPE abap_boolean.
      parallel_processor->run_inst(
        EXPORTING
          p_in_tab  = parallel_instances_in
          p_debug   = debug
        IMPORTING
          p_out_tab = DATA(parallel_instances_out)
      ).

    ENDIF.

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
