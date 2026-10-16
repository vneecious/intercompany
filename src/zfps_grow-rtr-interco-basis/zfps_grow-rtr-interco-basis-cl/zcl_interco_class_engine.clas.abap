"! <p>Main engine responsible for classifying Journal Entry Items according to defined rules and exemptions.</p>
"! <p>It also persists the classification results into ZR_IntercoJEItemHelperClass.</p>
CLASS zcl_interco_class_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
  PUBLIC SECTION.

    DATA: current_exemptions TYPE TABLE OF zr_intercojeitemhelperclassexe READ-ONLY.
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: reportar errores de la corrida
    " Preparado para que el caller consulte; el reporte paralelo aún está pendiente.
    DATA error_text TYPE string READ-ONLY.
    " Fin EXT_OSCUGALD 06.10.2026 - C12
    CLASS-METHODS:
      new
        RETURNING VALUE(results) TYPE REF TO zcl_interco_class_engine.

    METHODS:
      for
        IMPORTING
                  i_companycode  TYPE zi_intercojeitempandl-companycode
                  i_fiscalyear   TYPE zi_intercojeitempandl-fiscalyear
                  i_fiscalperiod TYPE zi_intercojeitempandl-fiscalperiod
                  i_paymenttype  TYPE zi_intercojeitempandl-paymenttype
                  i_ledger       TYPE zi_intercojeitempandl-ledger
        RETURNING VALUE(result)  TYPE REF TO zcl_interco_class_engine.

    METHODS:
      run
        IMPORTING iv_commit     TYPE abap_boolean DEFAULT abap_true
        RETURNING VALUE(result) TYPE REF TO zcl_interco_class_engine.


  PRIVATE SECTION.

    TYPES tt_classified_items TYPE TABLE OF zr_intercojeitemhelperclassitm WITH DEFAULT KEY.
    TYPES tt_excluded_items TYPE TABLE OF zr_intercojeitemhelperclassexe WITH DEFAULT KEY.
    TYPES ty_processing_type TYPE c LENGTH 1.

    CONSTANTS: BEGIN OF co_processing_type,
                 from_scratch TYPE ty_processing_type VALUE 'S',
                 delta        TYPE ty_processing_type VALUE 'D',
                 skip         TYPE ty_processing_type VALUE space,
               END OF co_processing_type.

    CLASS-DATA:instance TYPE REF TO zcl_interco_class_engine.

    DATA rule_last_changed_at TYPE abp_lastchange_tstmpl.
    DATA exemption_last_changed_at TYPE abp_lastchange_tstmpl.
    DATA docline_last_creationdate TYPE zi_intercojeitem-creationdatetime.

    DATA valid_date TYPE datum.

    DATA:
      header  TYPE zr_intercojeitemhelperclass,
      headers TYPE TABLE OF zr_intercojeitemhelperclass.

    "! <p>AGREGADO DS4K9B5URA: Pre-materializa los agrupadores del periodo en ZINT_A_JEITEM_AG.</p>
    "! <p>Lee desde ZR_IntercoJEItemClassV2 (resuelve las ~20 JOINs de jerarquias 1 sola vez)</p>
    "! <p>y escribe en la tabla fisica. apply_rules y apply_exemptions luego leen desde ahi.</p>
    METHODS materialize_agrupadores
      IMPORTING
        iv_processing_type TYPE c. " Processing mode: From Scratch, Delta, or Skip.

    "! <p>Classifies line items according to the rules defined in ZR_IntercoClassificationRules.</p>
    "! <p>The classification determines whether each line item is billable or not.</p>
    METHODS apply_rules
      IMPORTING
                iv_processing_type TYPE c
      RETURNING VALUE(result)      TYPE tt_classified_items.

    "! <p>Applies exemption rules to the previously classified items.</p>
    "! <p>Only line items that have been classified can be evaluated for exemption.</p>
    "! <p>The result is a list of items excluded from billing due to exemption criteria.</p>
    METHODS apply_exemptions
      IMPORTING
                iv_processing_type  TYPE c                   " Processing mode: From Scratch, Delta, or Skip
                it_classified_items TYPE tt_classified_items " Items previously classified as billable
      RETURNING VALUE(result)       TYPE tt_excluded_items.


    "! <p>Determines the type of processing required for the classification</p>
    METHODS evaluate_processing_strategy
      RETURNING
        VALUE(result) TYPE ty_processing_type.

ENDCLASS.



CLASS zcl_interco_class_engine IMPLEMENTATION.


  METHOD materialize_agrupadores.

    " AGREGADO DS4K9B5URA: Lee los agrupadores resueltos y los persiste en
    " ZINT_A_JEITEM_AG a nivel de JE item. Esto habilita que apply_rules y
    " apply_exemptions lean desde tabla fisica en lugar de resolver jerarquias en cada llamada.
    " MODIFICADO DS4K9B5URA: fuente cambiada de ZR_IntercoJEItemClassV2 a ZI_INTERCOJEITEMPANDL
    " (menos JOINs, filtros WHERE de intercompany ya incorporados en la view).

    " Lee page_size desde TVARVC — mismo parametro que usa ZCL_INTERCO_JEITEM_BG
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_IC05_PAGESIZE'
      INTO @DATA(lv_pagesize_str).
    DATA(page_size) = COND int4(
      WHEN lv_pagesize_str IS NOT INITIAL THEN CONV int4( lv_pagesize_str )
      ELSE 500000 ).

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: reconstrucción unificada de agrupadores
    " La cabecera vacía identifica la corrida, no una partición del origen.
    " El borrado se limita a la misma sociedad, ejercicio, período y ledgers.
    IF iv_processing_type = co_processing_type-from_scratch.
      DELETE FROM zint_a_jeitem_ag
        WHERE companycode  = @header-companycode
          AND fiscalyear   = @header-fiscalyear
          AND fiscalperiod = @header-fiscalperiod
          AND ledger       = @header-ledger
          AND sourceledger = @header-ledger.
      " AND paymenttype  = @header-paymenttype.
    ENDIF.
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    DATA lt_ag TYPE TABLE OF zint_a_jeitem_ag.
    DATA(_createdat) = cl_abap_tstmp=>utclong2tstmp_short( cl_abap_tstmp=>tstmp2utclong( header-createdat ) ).

    DATA range_pandll0id TYPE RANGE OF zi_intercojeitempandl-pandll0id.
* // Eliminado (31/07/2026): Elimina filtro de P&L L0 fijo ->
*
*    APPEND VALUE #( sign = 'I' option = 'EQ' low = '0PL_L0_02' ) TO range_pandll0id.
*    APPEND VALUE #( sign = 'I' option = 'EQ' low = '0PL_L0_03' ) TO range_pandll0id.
*    IF header-companycode = 'EBA'." OR header-companycode = 'MLB'.
*      APPEND VALUE #( sign = 'I' option = 'EQ' low = '0PL_L0_06' ) TO range_pandll0id.
*    ENDIF.
* // Eliminado (31/07/2026): Elimina filtro de P&L L0 fijo <-

* // Inserido (31/07/2026):  Limita a los P&L L0 que existen en las reglas ->
    range_pandll0id = zcl_interco_class_filter=>get_active_pandll0_range( ).
* // Inserido (31/07/2026):  Limita a los P&L L0 que existen en las reglas <-

* // AGREGADO (fix performance): PandLL0Id es columna calculada (post-join) — no puede
* // empujarse antes del join a Z_PNL_MT005. GLAccountParentNode SI es campo fisico:
* // resolver aqui el mismo universo de "P&L activo" pero en terminos de GLAccountParentNode
* // permite filtrar ANTES del join, evitando procesar lineas irrelevantes para la clasificacion.
    DATA(range_glparentnode) = zcl_interco_class_filter=>get_active_glparentnode_range( ).
* // AGREGADO (fix performance) <-

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: seleccionar gastos sin tipo de cabecera
    " OriginObjectType 02 delimita el origen; E/L lo resuelve C10.
    " Se conserva el filtro temporal existente para procesamiento delta.
    DATA(where) = |COMPANYCODE = '{ header-companycode }'| &&
      | AND FISCALYEAR = '{ header-fiscalyear }'| &&
      | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
      | AND LEDGER = '{ header-ledger }'| &&
      | AND SOURCELEDGER = '{ header-ledger }'| &&
      " | AND PAYMENTTYPE = '{ header-paymenttype }'| &&
      | AND ORIGINOBJECTTYPE = '02'| &&
      COND #( WHEN iv_processing_type = co_processing_type-delta THEN
      | AND CREATIONDATETIME >= '{ _createdat }' | ELSE space ).
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    SELECT
        sourceledger,
        companycode,
        fiscalyear,
        fiscalperiod,
        ledger,
        accountingdocument,
        ledgergllineitem,
        paymenttype,
        ccallocation,
        ccconsolidation,
        pcconsolidation,
        costcenterstandardhierarea,
        glaccountparentnode,
        pandll0id, pandll0name,
        pandll1id, pandll1name,
        pandll2id, pandll2name,
        pandll3id, pandll3name,
        pandll4id, pandll4name,
        pandll5id, pandll5name,
        profitcenter,
        costcenter,
        glaccount
    FROM zi_intercojeitempandl
    WITH PRIVILEGED ACCESS
    WHERE (where)
      AND ccallocationparentnode    IS NOT INITIAL
    AND glaccountparentnode IN @range_glparentnode
    AND pandll0id IN @range_pandll0id
    INTO CORRESPONDING FIELDS OF TABLE @lt_ag
    PACKAGE SIZE @page_size.

      INSERT zint_a_jeitem_ag FROM TABLE @lt_ag ACCEPTING DUPLICATE KEYS.
      CLEAR lt_ag.

    ENDSELECT.

    COMMIT WORK.

  ENDMETHOD.


  METHOD apply_exemptions.

    DATA excluded_items TYPE TABLE OF zr_intercojeitemhelperclassexe.
    TYPES: BEGIN OF ty_classified_items,

             companycode                TYPE zi_intercojeitempandl-companycode,
             fiscalyear                 TYPE zi_intercojeitempandl-fiscalyear,
             fiscalperiod               TYPE zi_intercojeitempandl-fiscalperiod,
             ledger                     TYPE zi_intercojeitempandl-ledger,
             paymenttype                TYPE zi_intercojeitempandl-paymenttype,
             pandll5id                  TYPE zi_intercojeitempandl-pandll5id,
             profitcenter               TYPE zi_intercojeitempandl-profitcenter,
             ccallocation               TYPE zi_intercojeitempandl-ccallocation,
             ccconsolidation            TYPE zi_intercojeitempandl-ccconsolidation,
             costcenterstandardhierarea TYPE zi_intercojeitempandl-costcenterstandardhierarea,
             costcenter                 TYPE zi_intercojeitempandl-costcenter,
             glaccount                  TYPE zi_intercojeitempandl-glaccount,
             ruleid                     TYPE zint_rule_id,
             product                    TYPE matnr,
           END OF ty_classified_items.
    DATA items TYPE TABLE OF ty_classified_items.

    IF it_classified_items IS INITIAL.
      RETURN.
    ENDIF.

    DATA(_createdat) = cl_abap_tstmp=>utclong2tstmp_short( cl_abap_tstmp=>tstmp2utclong( header-createdat ) ).
*   ELIMINADO DS4K9B5URA: WHERE con CREATIONDATETIME (solo aplica a lectura de CDS/V2)
*   DATA(where) = |COMPANYCODE = '{ header-companycode }'| &&
*     | AND FISCALYEAR = '{ header-fiscalyear }'| &&
*     | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
*     | AND LEDGER = '{ header-ledger }'| &&
*     | AND SOURCELEDGER = '{ header-ledger }'| &&
*     | AND PAYMENTTYPE = '{ header-paymenttype }'| &&
*     COND #( WHEN iv_processing_type = co_processing_type-delta THEN
*     | AND CREATIONDATETIME >= '{ _createdat }' |
*     ELSE space ).

*   ELIMINADO DS4K9B5URA: SELECT desde ZR_IntercoJEItemClassV2 (costoso - ~20 JOINs de jerarquias)
*   Reemplazado por lectura desde tabla fisica ZINT_A_JEITEM_AG (materializada en materialize_agrupadores)
*    SELECT DISTINCT
*        companycode,
*        fiscalyear,
*        fiscalperiod,
*        ledger,
*        paymenttype,
*        pandll5id,
*        profitcenter,
*        ccallocation,
*        ccconsolidation,
*        costcenterstandardhierarea,
*        costcenter,
*        glaccount
*    FROM ZR_IntercoJEItemClassV2
*    WITH PRIVILEGED ACCESS
*        WHERE (where)
*            INTO CORRESPONDING FIELDS OF TABLE @items.

    " AGREGADO DS4K9B5URA: seleccion de fuente segun parametro TVARVC ZINTERCO_IC05_MATAG_ACTIVA.
    " Con 'X': lee desde tabla fisica ZINT_A_JEITEM_AG (materializada por materialize_agrupadores).
    " Sin 'X' o parametro inexistente: flujo V2 original desde ZR_IntercoJEItemClassV2 (~20 JOINs).
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_IC05_MATAG_ACTIVA'
      INTO @DATA(lv_use_ag_exe).

    IF lv_use_ag_exe = 'X'.
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: leer gastos materializados para exclusiones
      " Anterior:
      " DATA(where_ag_exe) = |COMPANYCODE = '{ header-companycode }'| &&
      "   | AND FISCALYEAR = '{ header-fiscalyear }'| &&
      "   | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
      "   | AND LEDGER = '{ header-ledger }'| &&
      "   | AND SOURCELEDGER = '{ header-ledger }'| &&
      "   | AND PAYMENTTYPE = '{ header-paymenttype }'|.

      " Nuevo: E en AG identifica el gasto de origen, no el resultado E/L.
      DATA(where_ag_exe) = |COMPANYCODE = '{ header-companycode }'| &&
        | AND FISCALYEAR = '{ header-fiscalyear }'| &&
        | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
        | AND LEDGER = '{ header-ledger }'| &&
        | AND SOURCELEDGER = '{ header-ledger }'| &&
        | AND PAYMENTTYPE = 'E'|.
      " Fin EXT_OSCUGALD 06.10.2026 - C12

      SELECT DISTINCT
          companycode,
          fiscalyear,
          fiscalperiod,
          ledger,
          paymenttype,
          pandll5id,
          profitcenter,
          ccallocation,
          ccconsolidation,
          costcenterstandardhierarea,
          costcenter,
          glaccount
      FROM zint_a_jeitem_ag
          WHERE (where_ag_exe)
              INTO CORRESPONDING FIELDS OF TABLE @items.
    ELSE.
*     Flujo V2 original - fallback cuando ZINTERCO_IC05_MATAG_ACTIVA <> 'X'
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: seleccionar gastos en fallback de exclusiones
      " Anterior:
      " DATA(where_exe) = |COMPANYCODE = '{ header-companycode }'| &&
      "   | AND FISCALYEAR = '{ header-fiscalyear }'| &&
      "   | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
      "   | AND LEDGER = '{ header-ledger }'| &&
      "   | AND SOURCELEDGER = '{ header-ledger }'| &&
      "   | AND PAYMENTTYPE = '{ header-paymenttype }'| &&
      "   COND #( WHEN iv_processing_type = co_processing_type-delta THEN
      "   | AND CREATIONDATETIME >= '{ _createdat }' |
      "   ELSE space ).

      " Nuevo: seleccionar origen 02 y conservar la fecha del delta.
      DATA(where_exe) = |COMPANYCODE = '{ header-companycode }'| &&
        | AND FISCALYEAR = '{ header-fiscalyear }'| &&
        | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
        | AND LEDGER = '{ header-ledger }'| &&
        | AND SOURCELEDGER = '{ header-ledger }'| &&
        | AND ORIGINOBJECTTYPE = '02'| &&
        COND #( WHEN iv_processing_type = co_processing_type-delta THEN
        | AND CREATIONDATETIME >= '{ _createdat }' |
        ELSE space ).
      " Fin EXT_OSCUGALD 06.10.2026 - C12

      SELECT DISTINCT
          companycode,
          fiscalyear,
          fiscalperiod,
          ledger,
          paymenttype,
          pandll5id,
          profitcenter,
          ccallocation,
          ccconsolidation,
          costcenterstandardhierarea,
          costcenter,
          glaccount
      FROM zr_intercojeitemclassv2
      WITH PRIVILEGED ACCESS
          WHERE (where_exe)
              INTO CORRESPONDING FIELDS OF TABLE @items.
    ENDIF.

    SELECT ruleid, product FROM zr_intercoclassificationrule
      FOR ALL ENTRIES IN @it_classified_items
        WHERE ruleid = @it_classified_items-ruleid
        INTO TABLE @DATA(lt_classification_rules).


    LOOP AT  items REFERENCE INTO  DATA(lr_classified_item_complete).
      DATA(index) = sy-tabix.
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C11: cruzar con el resultado de clasificación
      " El tipo de origen puede ser E y la regla ganadora asignar L.
      " Compararlos aquí descartaría el ítem antes de evaluar sus exclusiones.
      READ TABLE it_classified_items REFERENCE INTO DATA(lr_classified_item)
        WITH KEY fiscalyear = lr_classified_item_complete->fiscalyear
                     fiscalperiod = lr_classified_item_complete->fiscalperiod
                     ledger = lr_classified_item_complete->ledger
                     " paymenttype = lr_classified_item_complete->paymenttype
                     pandll5id = lr_classified_item_complete->pandll5id
                     profitcenter = lr_classified_item_complete->profitcenter
                     ccallocation = lr_classified_item_complete->ccallocation
                     ccconsolidation = lr_classified_item_complete->ccconsolidation
                     costcenterstandardhierarea = lr_classified_item_complete->costcenterstandardhierarea.

      IF sy-subrc <> 0.
        DELETE items INDEX index.
        CONTINUE.
      ENDIF.

      " Las exclusiones reciben el tipo ya resuelto por C10.
      lr_classified_item_complete->paymenttype = lr_classified_item->paymenttype.
      lr_classified_item_complete->ruleid = lr_classified_item->ruleid.
      " Fin EXT_OSCUGALD 06.10.2026 - C11
      TRY.
          " Correcion de BUG (31/7/2026) ->
          " lr_classified_item_complete->product = lt_classification_rules[ ruleid = lr_classified_item->ruleid ].
          lr_classified_item_complete->product = lt_classification_rules[ ruleid = lr_classified_item->ruleid ]-product.
          " Correcion de BUG (31/7/2026) <-
        CATCH cx_sy_itab_line_not_found.
      ENDTRY.

    ENDLOOP.

    IF iv_processing_type = co_processing_type-delta.
      SELECT
      ledger,
      companycode,
      fiscalyear,
      fiscalperiod,
      paymenttype,
      profitcenter,
      costcenter,
      glaccount,
      exemptionid
  FROM zr_intercojeitemhelperclassexe WITH PRIVILEGED ACCESS
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: recuperar exclusiones E/L para delta
      " Anterior:
      " WHERE companycode = @header-companycode
      "   AND fiscalyear = @header-fiscalyear
      "   AND fiscalperiod = @header-fiscalperiod
      "   AND ledger = @header-ledger
      "   AND paymenttype = @header-paymenttype
      " INTO TABLE @DATA(db_exemptions).

      " Nuevo: recuperar ambos tipos resueltos dentro del mismo ámbito.
      WHERE companycode = @header-companycode
        AND fiscalyear = @header-fiscalyear
        AND fiscalperiod = @header-fiscalperiod
        AND ledger = @header-ledger
        AND paymenttype IN ( 'E', 'L' )
      INTO TABLE @DATA(db_exemptions).
      " Fin EXT_OSCUGALD 06.10.2026 - C12

      " Check whether the new items were already classified or not
      LOOP AT items REFERENCE INTO DATA(item).
        index = sy-tabix.
        " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: distinguir tipo resuelto en delta
        " Anterior:
        " IF line_exists( db_exemptions[ profitcenter = item->profitcenter
        "                              costcenter = item->costcenter
        "                              glaccount = item->glaccount ] ).
        "   DELETE items INDEX index.
        " ENDIF.

        " Nuevo: una exclusión E previa no debe omitir evaluar un ítem L.
        " C11 ya propagó a item el tipo ganador antes de este bloque.
        IF line_exists( db_exemptions[
                          paymenttype = item->paymenttype
                          profitcenter = item->profitcenter
                          costcenter = item->costcenter
                          glaccount = item->glaccount ] ).
          DELETE items INDEX index.
        ENDIF.
        " Fin EXT_OSCUGALD 06.10.2026 - C12
      ENDLOOP.

      excluded_items = CORRESPONDING #( db_exemptions ).
    ENDIF.

    IF items IS INITIAL.
      RETURN excluded_items.
    ENDIF.

    " Get exemptions
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C11: leer tipo de la exclusión
    " Antes la consulta no recuperaba PaymentType.
    " SELECT id, product, externalid, companycode,
    "        profitcenter, costcenter, glaccount
    " FROM zi_intercoexemptionruleflat WITH PRIVILEGED ACCESS
    " WHERE ( companycode = @header-companycode OR companycode IS INITIAL )
    "   AND validfrom <= @valid_date AND validto >= @valid_date
    " ORDER BY score DESCENDING
    " INTO TABLE @DATA(exemptions).

    SELECT id,
          product,
          externalid,
          companycode,
          paymenttype,
          profitcenter,
          costcenter,
          glaccount
        FROM zi_intercoexemptionruleflat WITH PRIVILEGED ACCESS
        WHERE ( companycode = @header-companycode OR companycode IS INITIAL )
          AND validfrom <= @valid_date AND validto >= @valid_date
*        and isdeleted is initial
          ORDER BY score DESCENDING
          INTO TABLE @DATA(exemptions).
    " Fin EXT_OSCUGALD 06.10.2026 - C11

    "  APply exemptions
    DO lines( items ) TIMES.
      item = REF #( items[ sy-index ] ).

      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C11: matching por tipo resuelto
      " Antes el matching no distinguía Exportación de Locales.
      " LOOP AT exemptions REFERENCE INTO DATA(exemption)
      "     WHERE ( companycode = item->companycode OR companycode IS INITIAL ) AND
      "           ( product = item->product OR product IS INITIAL ) AND
      "           ( profitcenter = item->profitcenter OR profitcenter IS INITIAL ) AND
      "           ( costcenter = item->costcenter OR costcenter IS INITIAL ) AND
      "           ( glaccount = item->glaccount OR glaccount IS INITIAL ).

      " Ini Facturación Local CH/ARG EXT_OSCUGALD 08.10.2026 - C11: vacío compatible solo con E
      " Código anterior conservado; el vacío también permitía excluir Locales.
      " Tipo vacío en la exclusión: aplica a E y L.
      " LOOP AT exemptions REFERENCE INTO DATA(exemption)
      "     WHERE ( companycode = item->companycode OR companycode IS INITIAL ) AND
      "           ( product = item->product OR product IS INITIAL ) AND
      "           ( paymenttype = item->paymenttype OR paymenttype IS INITIAL ) AND
      "           ( profitcenter = item->profitcenter OR profitcenter IS INITIAL ) AND
      "           ( costcenter = item->costcenter OR costcenter IS INITIAL ) AND
      "           ( glaccount = item->glaccount OR glaccount IS INITIAL ).

      " Para E se admite también vacío; para L se admite únicamente L.
      DATA(compatible_exemption_type) = COND zint_dte_paymenttype(
        WHEN item->paymenttype = 'E' THEN space
        ELSE item->paymenttype ).

      LOOP AT exemptions REFERENCE INTO DATA(exemption)
          WHERE ( companycode = item->companycode OR companycode IS INITIAL ) AND
                ( product = item->product OR product IS INITIAL ) AND
                ( paymenttype = item->paymenttype OR
                  paymenttype = compatible_exemption_type ) AND
                ( profitcenter = item->profitcenter OR profitcenter IS INITIAL ) AND
                ( costcenter = item->costcenter OR costcenter IS INITIAL ) AND
                ( glaccount = item->glaccount OR glaccount IS INITIAL ).
        " Fin EXT_OSCUGALD 08.10.2026 - C11
        " Fin EXT_OSCUGALD 06.10.2026 - C11

        APPEND INITIAL LINE TO excluded_items REFERENCE INTO DATA(line_excluded).
        line_excluded->* = CORRESPONDING #( item->* ).
        line_excluded->companycode = header-companycode.
        line_excluded->ledger = header-ledger.
        line_excluded->fiscalyear = header-fiscalyear.
        line_excluded->fiscalperiod = header-fiscalperiod.
        " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C11: conservar tipo del ítem excluido
        " El header identifica la corrida, no el tipo resuelto del ítem.
        " line_excluded->paymenttype = header-paymenttype.
        line_excluded->paymenttype = item->paymenttype.
        " Fin EXT_OSCUGALD 06.10.2026 - C11
        line_excluded->exemptionid = exemption->externalid.
        EXIT.
      ENDLOOP.

    ENDDO.

    RETURN excluded_items.

  ENDMETHOD.


  METHOD apply_rules.

    DATA(_createdat) = cl_abap_tstmp=>utclong2tstmp_short( cl_abap_tstmp=>tstmp2utclong( header-createdat ) ).
*   ELIMINADO DS4K9B5URA: WHERE con CREATIONDATETIME (solo aplica a lectura de CDS/V2)
*   DATA(where) = |COMPANYCODE = '{ header-companycode }'| &&
*     | AND FISCALYEAR = '{ header-fiscalyear }'| &&
*     | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
*     | AND LEDGER = '{ header-ledger }'| &&
*     | AND SOURCELEDGER = '{ header-ledger }'| &&
*     | AND PAYMENTTYPE = '{ header-paymenttype }'| &&
*     COND #( WHEN iv_processing_type = co_processing_type-delta THEN
*     | AND CREATIONDATETIME >= '{ _createdat }' |
*     ELSE space ).

*   ELIMINADO DS4K9B5URA: SELECT DISTINCT desde ZR_IntercoJEItemClassV2 (costoso - ~20 JOINs de jerarquias)
*   Reemplazado por lectura desde tabla fisica ZINT_A_JEITEM_AG (materializada en materialize_agrupadores)
*    SELECT DISTINCT
*        companycode,
*        fiscalyear,
*        fiscalperiod,
*        ledger,
*        paymenttype,
*        pandll0id,
*        pandll1id,
*        pandll2id,
*        pandll3id,
*        pandll4id,
*        pandll5id,
*        profitcenter,
*        costcenterstandardhierarea,
*        ccallocation,
*        ccconsolidation
*    FROM ZR_IntercoJEItemClassV2
*    WITH PRIVILEGED ACCESS
*        WHERE (where)
*            INTO TABLE @DATA(items).

    " AGREGADO DS4K9B5URA: seleccion de fuente segun parametro TVARVC ZINTERCO_IC05_MATAG_ACTIVA.
    " Con 'X': lee desde tabla fisica ZINT_A_JEITEM_AG (materializada por materialize_agrupadores).
    " Sin 'X' o parametro inexistente: flujo V2 original desde ZR_IntercoJEItemClassV2 (~20 JOINs).
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_IC05_MATAG_ACTIVA'
      INTO @DATA(lv_use_ag_rules).

    IF lv_use_ag_rules = 'X'.
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: leer agrupadores de gastos
      " AG conserva el tipo de origen: E corresponde a OriginObjectType 02.
      " Este filtro no limita el tipo E/L que asigna la regla ganadora.
      DATA(where_ag) = |COMPANYCODE = '{ header-companycode }'| &&
        | AND FISCALYEAR = '{ header-fiscalyear }'| &&
        | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
        | AND LEDGER = '{ header-ledger }'| &&
        | AND SOURCELEDGER = '{ header-ledger }'| &&
        " | AND PAYMENTTYPE = '{ header-paymenttype }'|.
        | AND PAYMENTTYPE = 'E'|.
      " Fin EXT_OSCUGALD 06.10.2026 - C12

      SELECT DISTINCT
          companycode,
          fiscalyear,
          fiscalperiod,
          ledger,
          paymenttype,
          pandll0id,
          pandll1id,
          pandll2id,
          pandll3id,
          pandll4id,
          pandll5id,
          profitcenter,
          costcenterstandardhierarea,
          ccallocation,
          ccconsolidation
      FROM zint_a_jeitem_ag
          WHERE (where_ag)
              INTO TABLE @DATA(items).
    ELSE.
*     Flujo V2 original - fallback cuando ZINTERCO_IC05_MATAG_ACTIVA <> 'X'
*      DATA(where) = |COMPANYCODE = '{ header-companycode }'| &&
*        | AND FISCALYEAR = '{ header-fiscalyear }'| &&
*        | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
*        | AND LEDGER = '{ header-ledger }'| &&
*        | AND SOURCELEDGER = '{ header-ledger }'| &&
*        | AND PAYMENTTYPE = '{ header-paymenttype }'| &&
*        COND #( WHEN iv_processing_type = co_processing_type-delta THEN
*        | AND CREATIONDATETIME >= '{ _createdat }' |
*        ELSE space ).
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: seleccionar gastos en fallback V2
      " La cabecera vacía no debe excluir los gastos de origen.
      " Se conserva el filtro temporal del delta.
      DATA(where) = |COMPANYCODE = '{ header-companycode }'| &&
        | AND FISCALYEAR = '{ header-fiscalyear }'| &&
        | AND FISCALPERIOD = '{ header-fiscalperiod }'| &&
        | AND LEDGER = '{ header-ledger }'| &&
        | AND SOURCELEDGER = '{ header-ledger }'| &&
        " | AND PAYMENTTYPE = '{ header-paymenttype }'| &&
        | AND ORIGINOBJECTTYPE = '02'| &&
        COND #( WHEN iv_processing_type = co_processing_type-delta THEN
        | AND CREATIONDATETIME >= '{ _createdat }' |
        ELSE space ).
      " Fin EXT_OSCUGALD 06.10.2026 - C12
      SELECT DISTINCT
          companycode,
          fiscalyear,
          fiscalperiod,
          ledger,
          paymenttype,
          pandll0id,
          pandll1id,
          pandll2id,
          pandll3id,
          pandll4id,
          pandll5id,
          profitcenter,
          costcenterstandardhierarea,
          ccallocation,
          ccconsolidation
      FROM zr_intercojeitemclassv2
      WITH PRIVILEGED ACCESS
          WHERE (where)
              INTO TABLE @items.
    ENDIF.

    DATA classified_items TYPE TABLE OF zr_intercojeitemhelperclassitm.

    IF iv_processing_type = co_processing_type-delta.
*      SELECT
*      ledger,
*      companycode,
*      fiscalyear,
*      fiscalperiod,
*      paymenttype,
*      pandll5id,
*      profitcenter,
*      costcenterstandardhierarea,
*      ccallocation,
*      ccconsolidation,
*      ruleid
*  FROM zr_intercojeitemhelperclassitm
*      WITH PRIVILEGED ACCESS
*      WHERE companycode = @header-companycode
*        AND fiscalyear = @header-fiscalyear
*        AND fiscalperiod = @header-fiscalperiod
*        AND ledger = @header-ledger
*        AND paymenttype = @header-paymenttype
*      INTO TABLE @DATA(db_items).
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: recuperar resultados E/L para delta
      " Recuperar ambos tipos resueltos, no el tipo vacío de la cabecera.
      " No arrastrar tipos legados I/vacío fuera del resultado válido E/L.
      SELECT
          ledger,
          companycode,
          fiscalyear,
          fiscalperiod,
          paymenttype,
          pandll5id,
          profitcenter,
          costcenterstandardhierarea,
          ccallocation,
          ccconsolidation,
          ruleid
        FROM zr_intercojeitemhelperclassitm
        WITH PRIVILEGED ACCESS
        WHERE companycode  = @header-companycode
          AND fiscalyear   = @header-fiscalyear
          AND fiscalperiod = @header-fiscalperiod
          AND ledger       = @header-ledger
          " AND paymenttype = @header-paymenttype
          AND paymenttype IN ( 'E', 'L' )
        INTO TABLE @DATA(db_items).
      " Fin EXT_OSCUGALD 06.10.2026 - C12

      " Check wheter the new items were already classified or not
      LOOP AT items REFERENCE INTO DATA(item).
        DATA(index) = sy-tabix.
        IF line_exists( db_items[ pandll5id = item->pandll5id
                                             profitcenter = item->profitcenter
                                             costcenterstandardhierarea = item->costcenterstandardhierarea
                                             ccallocation = item->ccallocation
                                             ccconsolidation = item->ccconsolidation ] ).
          DELETE items INDEX index.
        ENDIF.
      ENDLOOP.

      classified_items = CORRESPONDING #( db_items ).
    ENDIF.

    IF items IS INITIAL.
      RETURN classified_items.
    ENDIF.

    "  Get Rules
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C10: leer PaymentType de las reglas
    " Consulta anterior: no recuperaba el tipo de facturación de la regla.
    " SELECT id,
    "     ruleid,
    "     companycode,
    "     ledger,
    "     pandlid,
    "     pandllevel,
    "     profitcenter,
    "     ccstdhierarea,
    "     ccallocation,
    "     ccconsolidation,
    "     lastchangedat
    " FROM zi_intercoclassificationrule
    " WITH PRIVILEGED ACCESS
    " WHERE ( companycode = @header-companycode OR companycode IS INITIAL )
    "     AND validfrom <= @valid_date AND validto >= @valid_date
    "     AND isdeleted IS INITIAL
    "     ORDER BY score DESCENDING
    "     INTO TABLE @DATA(rules).

    " PaymentType es una salida de la regla ganadora.
    " Se conserva el orden por Score y el matching existente por Ledger.
    SELECT id,
        ruleid,
        companycode,
        ledger,
        paymenttype,
        pandlid,
        pandllevel,
        profitcenter,
        ccstdhierarea,
        ccallocation,
        ccconsolidation,
        lastchangedat
    FROM zi_intercoclassificationrule
    WITH PRIVILEGED ACCESS
    WHERE ( companycode = @header-companycode OR companycode IS INITIAL )
        AND validfrom <= @valid_date AND validto >= @valid_date
        AND isdeleted IS INITIAL
        ORDER BY score DESCENDING
        INTO TABLE @DATA(rules).
    " Fin EXT_OSCUGALD 06.10.2026 - C10

    " Apply Rules
    DO lines( items ) TIMES.
      item = REF #( items[ sy-index ] ).

      " AGREGADO DS4K9B5URA: items sin CCConsolidation no se clasifican.
      " Replica comportamiento V2: JOIN SQL "= NULL" nunca matchea rule → IsBillable = '-'.
      " En V3: item existe en AG pero sin entrada en CI → aparece como no tratado.
      IF item->ccconsolidation IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT rules REFERENCE INTO DATA(rule)
          WHERE ( companycode = item->companycode OR companycode IS INITIAL ) AND
                ledger = item->ledger AND
                ( ccstdhierarea = item->costcenterstandardhierarea OR ccstdhierarea IS INITIAL ) AND
                ( profitcenter = item->profitcenter OR profitcenter IS INITIAL ) AND
                ( ccallocation = item->ccallocation OR ccallocation IS INITIAL ) AND
                ( ccconsolidation = item->ccconsolidation OR ccconsolidation IS INITIAL ) AND
                (  pandlid = item->pandll5id OR
                   pandlid = item->pandll4id OR
                   pandlid = item->pandll3id OR
                   pandlid = item->pandll2id OR
                   pandlid = item->pandll1id OR
                   pandlid = item->pandll0id OR
                   pandlid IS INITIAL ).

        APPEND INITIAL LINE TO classified_items REFERENCE INTO DATA(line_classified).
        line_classified->* = CORRESPONDING #( item->* ).
        line_classified->companycode = header-companycode.
        line_classified->ledger = header-ledger.
        line_classified->fiscalyear = header-fiscalyear.
        line_classified->fiscalperiod = header-fiscalperiod.
        " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C10: asignar tipo de la regla ganadora
        " Antes se copiaba el tipo del header; ahora lo determina la regla.
        " line_classified->paymenttype = header-paymenttype.

        " Una regla con tipo vacío conserva Exportación como fallback.
        line_classified->paymenttype =
          COND #( WHEN rule->paymenttype IS NOT INITIAL
                  THEN rule->paymenttype
                  ELSE 'E' ).
        " Fin EXT_OSCUGALD 06.10.2026 - C10
        line_classified->ruleid = rule->ruleid.
        EXIT.
      ENDLOOP.

    ENDDO.

    RETURN classified_items.

  ENDMETHOD.


  METHOD evaluate_processing_strategy.

    IF header-isruleprocessed IS INITIAL OR
       header-createdat <= rule_last_changed_at OR
       header-createdat <= exemption_last_changed_at.
      RETURN co_processing_type-from_scratch.
    ELSEIF header-createdat IS NOT INITIAL AND docline_last_creationdate >= header-createdat.
      RETURN co_processing_type-delta.
    ENDIF.

  ENDMETHOD.


  METHOD for.
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: inicio FOR anterior conservado
    "
    "    valid_date = i_fiscalyear && i_fiscalperiod+1 && '01'.
    "    SELECT SINGLE * FROM zr_intercojeitemhelperclass
    "        WHERE companycode  = @i_companycode
    "           AND fiscalyear   = @i_fiscalyear
    "           AND fiscalperiod = @i_fiscalperiod
    "           AND ledger       = @i_ledger
    "           AND paymenttype  = @i_paymenttype
    "                  INTO @header.
    "
    "    IF sy-subrc = 0.
    "      APPEND header TO headers.
    "    ELSE.
    "      header-companycode = i_companycode.
    "      header-fiscalyear = i_fiscalyear.
    "      header-fiscalperiod = i_fiscalperiod.
    "      header-ledger = i_ledger.
    "      header-paymenttype = i_paymenttype.
    "      APPEND header TO headers.
    "      RETURN instance.
    "    ENDIF.
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: normalizar E/L antes de leer la estrategia
    " El singleton no debe arrastrar fechas ni flags de otro ámbito.
    CLEAR: header, headers, rule_last_changed_at,
           exemption_last_changed_at, docline_last_creationdate.
    valid_date = i_fiscalyear && i_fiscalperiod+1 && '01'.

    DATA(run_paymenttype) = i_paymenttype.
    DATA(force_pending) = abap_false.

    IF i_paymenttype = 'E' OR i_paymenttype = 'L'.
      " Conservar la solicitud pendiente del padre E/L antes de consultar el coordinador.
      SELECT SINGLE isruleprocessed, isexemptionprocessed
        FROM zr_intercojeitemhelperclass
        WHERE companycode = @i_companycode
          AND fiscalyear = @i_fiscalyear
          AND fiscalperiod = @i_fiscalperiod
          AND ledger = @i_ledger
          AND paymenttype = @i_paymenttype
        INTO @DATA(requested_status).
      force_pending = xsdbool(
        sy-subrc <> 0 OR
        requested_status-isruleprocessed IS INITIAL OR
        requested_status-isexemptionprocessed IS INITIAL ).

      " Normalizar solo E/L; I y otros valores no se reinterpretan como una corrida nueva.
      CLEAR run_paymenttype.
    ENDIF.

    SELECT SINGLE * FROM zr_intercojeitemhelperclass
      WHERE companycode = @i_companycode
        AND fiscalyear = @i_fiscalyear
        AND fiscalperiod = @i_fiscalperiod
        AND ledger = @i_ledger
        AND paymenttype = @run_paymenttype
      INTO @header.

    IF sy-subrc = 0.
      IF force_pending = abap_true.
        " Un coordinador completo no cancela una solicitud pendiente del padre E/L.
        " Los flags vacíos fuerzan from_scratch en evaluate_processing_strategy.
        " Conservar CreatedAt y el flujo de comprobaciones posterior.
        CLEAR: header-isruleprocessed, header-isexemptionprocessed.
      ENDIF.
      APPEND header TO headers.
    ELSE.
      " Header quedó limpio al iniciar: sin metadata heredada de un período anterior.
      header-companycode = i_companycode.
      header-fiscalyear = i_fiscalyear.
      header-fiscalperiod = i_fiscalperiod.
      header-ledger = i_ledger.
      header-paymenttype = run_paymenttype.
      APPEND header TO headers.
      RETURN instance.
    ENDIF.
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    " Retrieve all previously used rules to check if any were modified after the last classification
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: detectar cambios de reglas en resultados E/L
    " Código anterior conservado para trazabilidad:
    " SELECT COUNT(*)
    "   FROM zr_intercojeitemhelperclassitm AS usage
    "   LEFT OUTER JOIN zi_intercoclassificationrule WITH PRIVILEGED ACCESS AS ex
    "     ON ex~ruleid = usage~ruleid
    "   WHERE usage~companycode  = @header-companycode
    "     AND usage~fiscalyear   = @header-fiscalyear
    "     AND usage~fiscalperiod = @header-fiscalperiod
    "     AND usage~ledger       = @header-ledger
    "     AND usage~paymenttype  = @header-paymenttype
    "     AND ( ex~lastchangedat   >= @header-createdat OR
    "           ( ex~ruleid IS NULL OR ex~ruleid IS INITIAL ) )
    "     INTO @DATA(changed_rules_count).

    " La cabecera unificada tiene tipo vacío; los resultados conservan E/L.
    SELECT COUNT(*)
      FROM zr_intercojeitemhelperclassitm AS usage
      LEFT OUTER JOIN zi_intercoclassificationrule WITH PRIVILEGED ACCESS AS ex
        ON ex~ruleid = usage~ruleid
      WHERE usage~companycode  = @header-companycode
        AND usage~fiscalyear   = @header-fiscalyear
        AND usage~fiscalperiod = @header-fiscalperiod
        AND usage~ledger       = @header-ledger
        AND usage~paymenttype  IN ( 'E', 'L' )
        AND ( ex~lastchangedat   >= @header-createdat OR
              ( ex~ruleid IS NULL OR ex~ruleid IS INITIAL ) )
        INTO @DATA(changed_rules_count).
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    " If any of them were changed, force reprocessing from scratch
    IF changed_rules_count > 0.
      CLEAR: header-isruleprocessed, header-isexemptionprocessed.
      RETURN instance.
    ENDIF.

    " Check if any rule relevant to the current classification was modified after the last classification
    " This covers rules that were not previously applicable but now affect the classification logic
    SELECT SINGLE MAX( lastchangedat )
        FROM zi_intercoclassificationrule
        WITH PRIVILEGED ACCESS
        WHERE companycode = @i_companycode OR companycode IS INITIAL
            AND validfrom <= @valid_date AND validto >= @valid_date
            AND isdeleted IS INITIAL
            INTO @rule_last_changed_at.

    " If any relevant rule has changed, trigger a reprocessing from scratch
    IF rule_last_changed_at >= header-createdat.
      CLEAR: header-isruleprocessed, header-isexemptionprocessed.
      RETURN instance.
    ENDIF.

    " Check if any previously used exemption was changed after the last classification
    " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: detectar cambios de exclusiones en resultados E/L
    " Código anterior conservado para trazabilidad:
    " SELECT COUNT(*)
    "   FROM zr_intercojeitemhelperclassexe AS usage
    "   LEFT OUTER JOIN zi_intercoexemption WITH PRIVILEGED ACCESS AS ex
    "     ON ex~externalid = usage~exemptionid
    "   WHERE usage~companycode  = @header-companycode
    "     AND usage~fiscalyear   = @header-fiscalyear
    "     AND usage~fiscalperiod = @header-fiscalperiod
    "     AND usage~ledger       = @header-ledger
    "     AND usage~paymenttype  = @header-paymenttype
    "     AND ( ex~lastchangedat   >= @( cl_abap_tstmp=>tstmp2utclong( header-createdat ) ) OR
    "          ( ex~externalid IS NULL OR ex~externalid IS INITIAL ) )
    "     INTO @DATA(changed_exemptions_count).

    " La cabecera unificada tiene tipo vacío; las exclusiones conservan E/L.
    SELECT COUNT(*)
      FROM zr_intercojeitemhelperclassexe AS usage
      LEFT OUTER JOIN zi_intercoexemption WITH PRIVILEGED ACCESS AS ex
        ON ex~externalid = usage~exemptionid
      WHERE usage~companycode  = @header-companycode
        AND usage~fiscalyear   = @header-fiscalyear
        AND usage~fiscalperiod = @header-fiscalperiod
        AND usage~ledger       = @header-ledger
        AND usage~paymenttype  IN ( 'E', 'L' )
        AND ( ex~lastchangedat   >= @( cl_abap_tstmp=>tstmp2utclong( header-createdat ) ) OR
             ( ex~externalid IS NULL OR ex~externalid IS INITIAL ) )
        INTO @DATA(changed_exemptions_count).
    " Fin EXT_OSCUGALD 06.10.2026 - C12

    " If any of them were changed, force reprocessing from scratch
    IF changed_exemptions_count > 0.
      CLEAR: header-isruleprocessed, header-isexemptionprocessed.
      RETURN instance.
    ENDIF.

    SELECT SINGLE tstmpl_from_utcl( MAX( lastchangedat ) )
      FROM zi_intercoexemption WITH PRIVILEGED ACCESS
      WHERE companycode = @i_companycode OR companycode IS INITIAL
        AND validfrom <= @valid_date AND validto >= @valid_date
      " and isdeleted is initial
          INTO @exemption_last_changed_at.

    IF exemption_last_changed_at >= header-createdat.
      CLEAR: header-isruleprocessed, header-isexemptionprocessed.
      RETURN instance.
    ENDIF.

    " In case no rules or exemptions were changed after the last classification,
    " we look for new generated documents that may be classified thogh delta processing
    IF header-isexemptionprocessed = abap_true OR
       header-isruleprocessed = abap_true.

      " Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C12: detectar nuevos gastos por OriginObjectType 02
      " Código anterior conservado para trazabilidad:
      " SELECT SINGLE MAX( creationdatetime )
      " FROM zi_intercojeitem
      " WITH PRIVILEGED ACCESS
      " WHERE sourceledger = @i_ledger
      " AND companycode = @i_companycode
      " AND fiscalyear = @i_fiscalyear
      " AND fiscalperiod = @i_fiscalperiod
      " AND paymenttype = @i_paymenttype
      " INTO @docline_last_creationdate.

      " El tipo de cabecera no identifica el gasto; el origen 02 sí.
      SELECT SINGLE MAX( creationdatetime )
      FROM zi_intercojeitem
      WITH PRIVILEGED ACCESS
      WHERE sourceledger = @i_ledger
      AND companycode = @i_companycode
      AND fiscalyear = @i_fiscalyear
      AND fiscalperiod = @i_fiscalperiod
      AND originobjecttype = '02'
      INTO @docline_last_creationdate.
      " Fin EXT_OSCUGALD 06.10.2026 - C12

    ENDIF.

    RETURN instance.

  ENDMETHOD.


  METHOD new.
    IF instance IS NOT BOUND.
      instance = NEW #( ).
    ENDIF.
    RETURN instance.
  ENDMETHOD.

  METHOD run.

    " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 -
    " C12-6c.2: preparación común y reemplazo controlado E/L
    CONSTANTS:
      error_data TYPE string VALUE
        'Los datos de la clasificación requieren revisión. Contacte a soporte.',
      error_save TYPE string VALUE
        'No se pudo completar la clasificación. Contacte a soporte.',
      error_undo TYPE string VALUE
        'No se pudo confirmar la recuperación. Contacte a soporte.'.

    CLEAR error_text.
    DATA(db_pending) = abap_false.
    DATA(is_coordinator) = xsdbool( header-paymenttype IS INITIAL ).

    IF is_coordinator = abap_true AND
       ( header-companycode IS INITIAL OR
         header-fiscalyear IS INITIAL OR
         header-fiscalperiod IS INITIAL OR
         header-ledger IS INITIAL ).
      error_text = error_data.
      RETURN instance.
    ENDIF.

    DATA(processing_type) = evaluate_processing_strategy( ).

    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_IC05_MATAG_ACTIVA'
      INTO @DATA(lv_matag_activa).

    IF processing_type = co_processing_type-skip.
      RETURN.
    ENDIF.

    " Proteger hijos históricos vacíos antes del COMMIT interno de AG.
    IF is_coordinator = abap_true.
      SELECT SINGLE paymenttype FROM zint_a_jeitem_ci
        WHERE companycode  = @header-companycode
          AND fiscalyear   = @header-fiscalyear
          AND fiscalperiod = @header-fiscalperiod
          AND ledger       = @header-ledger
          AND paymenttype  = @space
        INTO @DATA(existing_blank_ci).
      IF sy-subrc = 0.
        error_text = error_data.
        RETURN instance.
      ENDIF.

      SELECT SINGLE paymenttype FROM zint_a_jeitem_ce
        WHERE companycode  = @header-companycode
          AND fiscalyear   = @header-fiscalyear
          AND fiscalperiod = @header-fiscalperiod
          AND ledger       = @header-ledger
          AND paymenttype  = @space
        INTO @DATA(existing_blank_ce).
      IF sy-subrc = 0.
        error_text = error_data.
        RETURN instance.
      ENDIF.
    ENDIF.

    TRY.
        IF lv_matag_activa = 'X'.
          " Si AG falla antes de confirmar, queda DML para revertir.
          db_pending = abap_true.
          materialize_agrupadores( iv_processing_type = processing_type ).
          db_pending = abap_false.
        ENDIF.

        " Secuencia original: C10/C11 conservan el matching y resuelven E/L.
        DATA(classified_items) =
          apply_rules( iv_processing_type = processing_type ).
        DATA(exemption_items) =
          apply_exemptions(
            iv_processing_type  = processing_type
            it_classified_items = classified_items ).

        DATA create TYPE TABLE FOR CREATE zr_intercojeitemhelperclass.
        create = VALUE #( (
          %cid                 = 'create'
          companycode          = header-companycode
          fiscalperiod         = header-fiscalperiod
          fiscalyear           = header-fiscalyear
          paymenttype          = header-paymenttype
          ledger               = header-ledger
          isexemptionprocessed = abap_true
          isruleprocessed      = abap_true ) ).

        DATA ch_tab TYPE TABLE OF zint_a_jeitem_ch.
        DATA ci_tab TYPE TABLE OF zint_a_jeitem_ci.
        DATA ce_tab TYPE TABLE OF zint_a_jeitem_ce.

        ch_tab = CORRESPONDING #( create MAPPING FROM ENTITY ).
        IF is_coordinator = abap_true.
          " Reutilizar la cabecera para agregar los padres de resultados.
          DATA(parent_ch) = ch_tab[ 1 ].
          parent_ch-paymenttype = 'E'.
          APPEND parent_ch TO ch_tab.
          parent_ch-paymenttype = 'L'.
          APPEND parent_ch TO ch_tab.
        ENDIF.

        " Conversión y deduplicación de filas idénticas del RUN original.
        SORT ch_tab.
        DELETE ADJACENT DUPLICATES FROM ch_tab.
        ci_tab = CORRESPONDING #( classified_items ).
        SORT ci_tab.
        DELETE ADJACENT DUPLICATES FROM ci_tab.
        ce_tab = CORRESPONDING #( exemption_items ).
        SORT ce_tab.
        DELETE ADJACENT DUPLICATES FROM ce_tab.

        IF is_coordinator = abap_true.
          " Mandante implícito de Open SQL; RuleID/ExemptionID no son clave.
          DATA ci_keys TYPE HASHED TABLE OF zint_a_jeitem_ci
            WITH UNIQUE KEY ledger companycode fiscalyear fiscalperiod
              paymenttype pandll5id profitcenter costcenterstandardhierarea
              ccallocation ccconsolidation.
          DATA ce_keys TYPE HASHED TABLE OF zint_a_jeitem_ce
            WITH UNIQUE KEY ledger companycode fiscalyear fiscalperiod
              paymenttype profitcenter costcenter glaccount.

          LOOP AT ci_tab INTO DATA(ci_row).
            IF ci_row-companycode  <> header-companycode OR
               ci_row-fiscalyear   <> header-fiscalyear OR
               ci_row-fiscalperiod <> header-fiscalperiod OR
               ci_row-ledger       <> header-ledger OR
               ( ci_row-paymenttype <> 'E' AND ci_row-paymenttype <> 'L' ).
              error_text = error_data.
              RETURN instance.
            ENDIF.
            INSERT ci_row INTO TABLE ci_keys.
            IF sy-subrc <> 0.
              error_text = error_data.
              RETURN instance.
            ENDIF.
          ENDLOOP.

          LOOP AT ce_tab INTO DATA(ce_row).
            IF ce_row-companycode  <> header-companycode OR
               ce_row-fiscalyear   <> header-fiscalyear OR
               ce_row-fiscalperiod <> header-fiscalperiod OR
               ce_row-ledger       <> header-ledger OR
               ( ce_row-paymenttype <> 'E' AND ce_row-paymenttype <> 'L' ).
              error_text = error_data.
              RETURN instance.
            ENDIF.
            INSERT ce_row INTO TABLE ce_keys.
            IF sy-subrc <> 0.
              error_text = error_data.
              RETURN instance.
            ENDIF.
          ENDLOOP.

          db_pending = abap_true.
          DELETE FROM zint_a_jeitem_ce
            WHERE companycode  = @header-companycode
              AND fiscalyear   = @header-fiscalyear
              AND fiscalperiod = @header-fiscalperiod
              AND ledger       = @header-ledger
              AND paymenttype IN ( 'E', 'L' ).
          DELETE FROM zint_a_jeitem_ci
            WHERE companycode  = @header-companycode
              AND fiscalyear   = @header-fiscalyear
              AND fiscalperiod = @header-fiscalperiod
              AND ledger       = @header-ledger
              AND paymenttype IN ( 'E', 'L' ).
          DELETE FROM zint_a_jeitem_ch
            WHERE companycode  = @header-companycode
              AND fiscalyear   = @header-fiscalyear
              AND fiscalperiod = @header-fiscalperiod
              AND ledger       = @header-ledger
              AND ( paymenttype = @space OR paymenttype IN ( 'E', 'L' ) ).
        ELSE.
          " Mecanismo de borrado anterior para cabeceras no normalizadas.
          DATA delete TYPE TABLE FOR DELETE zr_intercojeitemhelperclass.
          IF header-createdat IS NOT INITIAL.
            APPEND CORRESPONDING #( header ) TO delete.
            CLEAR header-createdat.
          ENDIF.
          MODIFY ENTITIES OF zr_intercojeitemhelperclass
            ENTITY header DELETE FROM delete.
          COMMIT ENTITIES.
        ENDIF.

        GET TIME STAMP FIELD DATA(created_at).
        LOOP AT ch_tab REFERENCE INTO DATA(ch).
          ch->created_at = created_at.
          ch->created_by = sy-uname.
        ENDLOOP.

        " INSERT comunes: cada resultado conserva su PaymentType.
        db_pending = abap_true.
        INSERT zint_a_jeitem_ch FROM TABLE @ch_tab.
        IF is_coordinator = abap_true AND
           ( sy-subrc <> 0 OR sy-dbcnt <> lines( ch_tab ) ).
          error_text = error_save.
        ENDIF.

        IF error_text IS INITIAL.
          INSERT zint_a_jeitem_ci FROM TABLE @ci_tab.
          IF is_coordinator = abap_true AND
             ( sy-subrc <> 0 OR sy-dbcnt <> lines( ci_tab ) ).
            error_text = error_save.
          ENDIF.
        ENDIF.

        IF error_text IS INITIAL.
          INSERT zint_a_jeitem_ce FROM TABLE @ce_tab.
          IF is_coordinator = abap_true AND
             ( sy-subrc <> 0 OR sy-dbcnt <> lines( ce_tab ) ).
            error_text = error_save.
          ENDIF.
        ENDIF.

        IF error_text IS INITIAL AND iv_commit = abap_true.
          COMMIT ENTITIES.
          IF is_coordinator = abap_true AND sy-subrc <> 0.
            error_text = error_save.
          ELSE.
            db_pending = abap_false.
          ENDIF.
        ENDIF.
      CATCH cx_root.
        error_text = error_save.
    ENDTRY.

    IF error_text IS NOT INITIAL AND db_pending = abap_true.
      TRY.
          ROLLBACK WORK.
        CATCH cx_root.
          error_text = error_undo.
      ENDTRY.
    ENDIF.

    " iv_commit=false deja los INSERT pendientes a cargo del caller.
    " El rollback no revierte AG si MATERIALIZE ya hizo su COMMIT.
    RETURN instance.
    " Fin EXT_OSCUGALD 07.10.2026 - C12-6c.2

***  METHOD run.
***
***    DATA(processing_type) = evaluate_processing_strategy( ).
***
***    SELECT SINGLE low FROM zi_tvarvc
***      WHERE name = 'ZINTERCO_IC05_MATAG_ACTIVA'
***      INTO @DATA(lv_matag_activa).
***
***    IF processing_type = co_processing_type-skip.
***      RETURN.
***    ENDIF.
***
***    IF lv_matag_activa = 'X'.
***      materialize_agrupadores( iv_processing_type = processing_type ).
***    ENDIF.
***
***    DATA(classified_items) = apply_rules( iv_processing_type = processing_type ).
***    DATA(exemption_items) = apply_exemptions( iv_processing_type  = processing_type
***                                              it_classified_items = classified_items ).
***
***    DATA delete TYPE TABLE FOR DELETE zr_intercojeitemhelperclass.
***    DATA create TYPE TABLE FOR CREATE zr_intercojeitemhelperclass.
***    DATA create_exemptions TYPE TABLE FOR CREATE zr_intercojeitemhelperclass\_itemsexemptions.
***    DATA create_items TYPE TABLE FOR CREATE zr_intercojeitemhelperclass\_items.
***
***    IF header-createdat IS NOT INITIAL.
***      APPEND CORRESPONDING #( header ) TO delete.
***      CLEAR header-createdat.
***    ENDIF.
***
***    create = VALUE #( ( %cid                 = 'create'
***                        companycode          = header-companycode
***                        fiscalperiod         = header-fiscalperiod
***                        fiscalyear           = header-fiscalyear
***                        paymenttype          = header-paymenttype
***                        ledger               = header-ledger
***                        isexemptionprocessed = abap_true
***                        isruleprocessed      = abap_true ) ).
***
***    create_items = VALUE #( ( %cid_ref = 'create'
***                              %target  = VALUE #( FOR c IN classified_items ( CORRESPONDING #( c ) ) )
***    ) ).
***
***    create_exemptions = VALUE #( ( %cid_ref = 'create'
***                                   %target  = VALUE #( FOR e IN exemption_items
***                                                    ( CORRESPONDING #( e ) ) )
***    ) ).
***
***    MODIFY ENTITIES OF zr_intercojeitemhelperclass
***    ENTITY header
***      DELETE FROM delete.
***    COMMIT ENTITIES.
***
***    DATA ch_tab TYPE TABLE OF zint_a_jeitem_ch.
***    DATA ci_tab TYPE TABLE OF zint_a_jeitem_ci.
***    DATA ce_tab TYPE TABLE OF zint_a_jeitem_ce.
***
***    ch_tab = CORRESPONDING #( create MAPPING FROM ENTITY ).
***    SORT ch_tab.
***    DELETE ADJACENT DUPLICATES FROM ch_tab.
***    ci_tab = CORRESPONDING #( classified_items ).
***    SORT ci_tab.
***    DELETE ADJACENT DUPLICATES FROM ci_tab.
***    ce_tab = CORRESPONDING #( exemption_items ).
***    SORT ce_tab.
***    DELETE ADJACENT DUPLICATES FROM ce_tab.
***
***    LOOP AT ch_tab REFERENCE INTO DATA(ch).
***      GET TIME STAMP FIELD ch->created_at.
***      ch->created_by = sy-uname.
***    ENDLOOP.
***
***    INSERT zint_a_jeitem_ch FROM TABLE @ch_tab.
***    INSERT zint_a_jeitem_ci FROM TABLE @ci_tab.
***    INSERT zint_a_jeitem_ce FROM TABLE @ce_tab.
***
****    MODIFY ENTITIES OF zr_intercojeitemhelperclass
****    ENTITY header
****      CREATE FIELDS ( companycode fiscalyear fiscalperiod ledger paymenttype isexemptionprocessed isruleprocessed ) WITH create
****      CREATE BY \_items FIELDS ( ccallocation ccconsolidation costcenterstandardhierarea pandll5id profitcenter ruleid ) AUTO FILL CID WITH create_items
****      CREATE BY \_itemsexemptions FIELDS ( costcenter profitcenter glaccount exemptionid ) AUTO FILL CID WITH create_exemptions
****      MAPPED DATA(mapped)
****      REPORTED DATA(reported)
****      FAILED DATA(failed).
***
***    IF iv_commit = abap_true.
***      COMMIT ENTITIES.
***    ENDIF.
***
***    RETURN instance.
***  ENDMETHOD.
  ENDMETHOD.

ENDCLASS.
