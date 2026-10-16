CLASS zcl_interco_bgpf DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_bgmc_op_single_tx_uncontr .

    " Definir estructura de entrada
    TYPES: BEGIN OF ty_input_params,
             companycode  TYPE bukrs,
             fiscalyear   TYPE gjahr,
             fiscalperiod TYPE fins_fiscalperiod,
             ledger       TYPE fins_ledger,
             paymenttype  TYPE zint_dte_paymenttype,
             basis_id     TYPE string,
             background   TYPE abap_boolean,
           END OF ty_input_params.

    METHODS: constructor IMPORTING iv_params TYPE ty_input_params,
      get_input_params RETURNING VALUE(rs_params) TYPE ty_input_params.
  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA: ms_input_params TYPE ty_input_params.

ENDCLASS.

CLASS zcl_interco_bgpf IMPLEMENTATION.

  METHOD constructor.
    ms_input_params = iv_params.
  ENDMETHOD.

  METHOD get_input_params.
    rs_params = ms_input_params.
  ENDMETHOD.

  METHOD if_bgmc_op_single_tx_uncontr~execute.

    DATA(lv_basis_id) = ms_input_params-basis_id.
    DATA lv_final_status TYPE ze_exec_status.

*    UPDATE zfi_a_intrc_bh
*      SET executionstatus = 'IN_PROCESS'
*      WHERE id = @lv_basis_id.

    " AGREGADO DS4K9B5URA: verificación de activación de V3 para ruteo en CreateBasis (solo path online).
    " Se requieren AMBAS condiciones: parámetro ZINTERCO_IC05_MATAG_ACTIVA = 'X' Y datos en ZINT_A_JEITEM_AG.
    SELECT SINGLE low FROM zi_tvarvc
      WHERE name = 'ZINTERCO_IC05_MATAG_ACTIVA'
      INTO @DATA(lv_matag_param).

    DATA(lv_use_v3) = abap_false.
    IF lv_matag_param = 'X' AND ms_input_params-background IS INITIAL.
      DATA(lv_ag_count) = 0.
      " Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12o (7c.2): ruteo E/L por AG técnico
      " L utiliza los mismos AG técnicos E; el tipo comercial solicitado se conserva.
      DATA(lv_ag_paymenttype) = COND zint_dte_paymenttype(
        WHEN ms_input_params-paymenttype = 'L' THEN 'E'
        ELSE ms_input_params-paymenttype ).

      " Comprobación anterior conservada como histórico.
      " SELECT COUNT(*) FROM zint_a_jeitem_ag
      "   WHERE companycode  = @ms_input_params-companycode
      "     AND fiscalyear   = @ms_input_params-fiscalyear
      "     AND fiscalperiod = @ms_input_params-fiscalperiod
      "     AND ledger       = @ms_input_params-ledger
      "     AND paymenttype  = @ms_input_params-paymenttype
      "   INTO @lv_ag_count.

      SELECT COUNT(*) FROM zint_a_jeitem_ag
        WHERE companycode  = @ms_input_params-companycode
          AND fiscalyear   = @ms_input_params-fiscalyear
          AND fiscalperiod = @ms_input_params-fiscalperiod
          AND ledger       = @ms_input_params-ledger
          AND paymenttype  = @lv_ag_paymenttype
        INTO @lv_ag_count.
      " Fin EXT_OSCUGALD 07.10.2026 - C12o (7c.2)
      IF lv_ag_count > 0.
        lv_use_v3 = abap_true.
      ENDIF.
    ENDIF.

*   ELIMINADO DS4K9B5URA: path online leía directamente de zc_intercojeitemclass sin verificar
*   si existen datos materializados en zint_a_jeitem_ag. Se reemplaza por bloque con ruteo V2/V3.
*    IF ms_input_params-background IS INITIAL.
*      SELECT
*            FROM zc_intercojeitemclass( p_companycode  = @ms_input_params-companycode,
*                                        p_fiscalperiod = @ms_input_params-fiscalperiod,
*                                        p_fiscalyear   = @ms_input_params-fiscalyear,
*                                        p_ledger       = @ms_input_params-ledger,
*                                        p_paymenttype  = @ms_input_params-paymenttype,
*                                        p_bgprocessing = @abap_false
*                                      )
*            FIELDS companycode                        AS providercompanycode,
*                   glaccount,
*                   fiscalyear,
*                   fiscalperiod,
*                   ledger,
*                   pandll5id,
*                   costcenterstandardhierarea AS costcenterstdhierarea,
*                   ccallocation,
*                   ccconsolidation,
*                   department,
*                   concept                            AS product,
*                   paymenttype,
*                   costcenter,
*                   profitcenter,
*                   companycodecurrency,
*                   globalcurrency,
*                   SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
*                   SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
*                   MIN( creationdatetime ) AS mindatetime,
*                   MAX( creationdatetime ) AS maxdatetime
**       WHERE IsBillableFilter = @abap_true  "ext_oscugald 12.11.2025
*            WHERE isbillable  = 'B'
*                  AND ( isreleased IS INITIAL OR isreleased IS NULL )
*            GROUP BY companycode, glaccount, fiscalyear, fiscalperiod, ledger, pandll5id, costcenterstandardhierarea, ccallocation, ccconsolidation, department, concept, paymenttype, costcenter, profitcenter,
*                     companycodecurrency, globalcurrency
*            INTO TABLE @DATA(billable_items).
*    ELSE.
*      SELECT
*     FROM zc_intercojeitemclassbg( p_companycode  = @ms_input_params-companycode,
*                                 p_fiscalperiod = @ms_input_params-fiscalperiod,
*                                 p_fiscalyear   = @ms_input_params-fiscalyear,
*                                 p_ledger       = @ms_input_params-ledger,
*                                 p_paymenttype  = @ms_input_params-paymenttype
*                               )
*     FIELDS companycode                        AS providercompanycode,
*            glaccount,
*            fiscalyear,
*            fiscalperiod,
*            ledger,
*            pandll5id,
*            costcenterstandardhierarea AS costcenterstdhierarea,
*            ccallocation,
*            ccconsolidation,
*            department,
*            concept                            AS product,
*            paymenttype,
*            costcenter,
*            profitcenter,
*            companycodecurrency,
*            globalcurrency,
*            SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
*            SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
*            MIN( creationdatetime ) AS mindatetime,
*            MAX( creationdatetime ) AS maxdatetime
**       WHERE IsBillableFilter = @abap_true  "ext_oscugald 12.11.2025
*     WHERE isbillable  = 'B'
*           AND ( isreleased IS INITIAL OR isreleased IS NULL )
*     GROUP BY companycode, glaccount, fiscalyear, fiscalperiod, ledger, pandll5id, costcenterstandardhierarea, ccallocation, ccconsolidation, department, concept, paymenttype, costcenter, profitcenter,
*              companycodecurrency, globalcurrency
*     INTO TABLE @billable_items.
*    ENDIF.

    " AGREGADO DS4K9B5URA: ruteo V2/V3 para path online. Background sin modificaciones.
    " Si el parámetro está activo y hay datos en ZINT_A_JEITEM_AG, usa V3; sino continúa por V2.
    IF ms_input_params-background IS INITIAL.
      IF lv_use_v3 = abap_true.
        " AGREGADO DS4K9B5URA: V3 - tabla materializada (reemplaza ~20 JOINs de jerarquías en path online).
        SELECT
              FROM zc_intercojeitemclassv3( p_companycode  = @ms_input_params-companycode,
                                            p_fiscalperiod = @ms_input_params-fiscalperiod,
                                            p_fiscalyear   = @ms_input_params-fiscalyear,
                                            p_ledger       = @ms_input_params-ledger,
                                            p_paymenttype  = @ms_input_params-paymenttype
                                          )
              FIELDS companycode                        AS providercompanycode,
                     glaccount,
                     fiscalyear,
                     fiscalperiod,
                     ledger,
                     pandll5id,
"Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: PandLL2Id necesario para la excepcion de Department por PandLId (ET v2.1 par.3.1) =====
                     pandll2id,
"Fin - EXT_OSCUGALD - 02.09.2026 =====
                     costcenterstandardhierarea AS costcenterstdhierarea,
                     ccallocation,
                     ccconsolidation,
                     department,
                     concept                            AS product,
                     paymenttype,
                     costcenter,
                     profitcenter,
                     companycodecurrency,
                     globalcurrency,
                     SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
                     SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
                     MIN( creationdatetime ) AS mindatetime,
                     MAX( creationdatetime ) AS maxdatetime
              WHERE isbillable  = 'B'
                    AND ( isreleased IS INITIAL OR isreleased IS NULL )
"Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: pandll2id agregado al GROUP BY (va junto a pandll5id) =====
              GROUP BY companycode, glaccount, fiscalyear, fiscalperiod, ledger, pandll5id, pandll2id, costcenterstandardhierarea, ccallocation, ccconsolidation, department, concept, paymenttype, costcenter, profitcenter,
                       companycodecurrency, globalcurrency
"Fin - EXT_OSCUGALD - 02.09.2026 =====
              INTO TABLE @DATA(billable_items).
      ELSE.
        " ELIMINADO DS4K9B5URA (mantenido para rollback): V2 online original (~20 JOINs de jerarquías).
        " Se ejecuta cuando el parámetro está inactivo o no hay datos en ZINT_A_JEITEM_AG.
        SELECT
              FROM zc_intercojeitemclass( p_companycode  = @ms_input_params-companycode,
                                          p_fiscalperiod = @ms_input_params-fiscalperiod,
                                          p_fiscalyear   = @ms_input_params-fiscalyear,
                                          p_ledger       = @ms_input_params-ledger,
                                          p_paymenttype  = @ms_input_params-paymenttype,
                                          p_bgprocessing = @abap_false
                                        )
              FIELDS companycode                        AS providercompanycode,
                     glaccount,
                     fiscalyear,
                     fiscalperiod,
                     ledger,
                     pandll5id,
"Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: PandLL2Id necesario para la excepcion de Department por PandLId (ET v2.1 par.3.1) =====
                     pandll2id,
"Fin - EXT_OSCUGALD - 02.09.2026 =====
                     costcenterstandardhierarea AS costcenterstdhierarea,
                     ccallocation,
                     ccconsolidation,
                     department,
                     concept                            AS product,
                     paymenttype,
                     costcenter,
                     profitcenter,
                     companycodecurrency,
                     globalcurrency,
                     SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
                     SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
                     MIN( creationdatetime ) AS mindatetime,
                     MAX( creationdatetime ) AS maxdatetime
*       WHERE IsBillableFilter = @abap_true  "ext_oscugald 12.11.2025 - evalua variable booleana, si es verdadero indica que isbillable = B. el cálculo del campo esta directamente en la vista de consumo zc_intercojeitemclass
              WHERE isbillable  = 'B'
                    AND ( isreleased IS INITIAL OR isreleased IS NULL )
"Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: pandll2id agregado al GROUP BY (va junto a pandll5id) =====
              GROUP BY companycode, glaccount, fiscalyear, fiscalperiod, ledger, pandll5id, pandll2id, costcenterstandardhierarea, ccallocation, ccconsolidation, department, concept, paymenttype, costcenter, profitcenter,
                       companycodecurrency, globalcurrency
"Fin - EXT_OSCUGALD - 02.09.2026 =====
              INTO TABLE @billable_items.
      ENDIF.
    ELSE.
      SELECT
     FROM zc_intercojeitemclassbg( p_companycode  = @ms_input_params-companycode,
                                 p_fiscalperiod = @ms_input_params-fiscalperiod,
                                 p_fiscalyear   = @ms_input_params-fiscalyear,
                                 p_ledger       = @ms_input_params-ledger,
                                 p_paymenttype  = @ms_input_params-paymenttype
                               )
     FIELDS companycode                        AS providercompanycode,
            glaccount,
            fiscalyear,
            fiscalperiod,
            ledger,
            pandll5id,
"Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: PandLL2Id necesario para la excepcion de Department por PandLId (ET v2.1 par.3.1) =====
            pandll2id,
"Fin - EXT_OSCUGALD - 02.09.2026 =====
            costcenterstandardhierarea AS costcenterstdhierarea,
            ccallocation,
            ccconsolidation,
            department,
            concept                            AS product,
            paymenttype,
            costcenter,
            profitcenter,
            companycodecurrency,
            globalcurrency,
            SUM( amountinglobalcurrency )      AS amountinglobalcurrency,
            SUM( amountincompanycodecurrency ) AS amountincompanycodecurrency,
            MIN( creationdatetime ) AS mindatetime,
            MAX( creationdatetime ) AS maxdatetime
*       WHERE IsBillableFilter = @abap_true  "ext_oscugald 12.11.2025 - evalua variable booleana, si es verdadero indica que isbillable = B. el cálculo del campo esta directamente en la vista de consumo zc_intercojeitemclass
     WHERE isbillable  = 'B'
           AND ( isreleased IS INITIAL OR isreleased IS NULL )
"Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: pandll2id agregado al GROUP BY (va junto a pandll5id) =====
     GROUP BY companycode, glaccount, fiscalyear, fiscalperiod, ledger, pandll5id, pandll2id, costcenterstandardhierarea, ccallocation, ccconsolidation, department, concept, paymenttype, costcenter, profitcenter,
              companycodecurrency, globalcurrency
"Fin - EXT_OSCUGALD - 02.09.2026 =====
     INTO TABLE @billable_items.
    ENDIF.


    IF sy-subrc <> 0. "  NO BILLABLE ITEMS
      DATA lv_error_message TYPE c LENGTH 255.

      MESSAGE  e210(zfi_interco) INTO lv_error_message.

      UPDATE zfi_a_intrc_bh
        SET executionstatus = 'FAILED',
            last_error_message = @lv_error_message
      WHERE id = @lv_basis_id.
      RETURN.
    ENDIF.

*    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ ms_input_params-fiscalyear }{ ms_input_params-fiscalperiod+1 }01| ).
*    DATA(is_feature_department_enabled) = zcl_interco=>feature->get( 'DEPARTMENT' )->for( iv_companycode = ms_input_params-companycode iv_validat = last_day_of_month )-enabled.
*
*    IF is_feature_department_enabled = abap_true AND line_exists( billable_items[ department = '' ] ).
*      lv_error_message = 'Department cannot be empty'(001).
*      UPDATE zfi_a_intrc_bh
*    SET executionstatus = 'FAILED',
*        last_error_message = @lv_error_message
*    WHERE id = @lv_basis_id.
*      RETURN.
*    ENDIF.
    "===== INICIO AJUSTE - EXT_OSCUGALD - 02.09.2026 - HU-01: valida Department por item (Product+PandLL2Id),
    " reemplaza la validacion unica por toda la Base (ET v2.1 par.3.2). Usa cache en memoria para no
    " repetir la llamada a FOR() por cada item cuando Product+PandLL2Id se repiten dentro del batch.
    FINAL(last_day_of_month) = zcl_interco_utils=>rp_last_day_of_months( day_in = |{ ms_input_params-fiscalyear }{ ms_input_params-fiscalperiod+1 }01| ).

    TYPES: BEGIN OF ty_toggle_cache,
             product TYPE matnr,
             pandlid TYPE hrynode,
             enabled TYPE abap_boolean,
           END OF ty_toggle_cache.
    DATA lt_toggle_cache TYPE HASHED TABLE OF ty_toggle_cache WITH UNIQUE KEY product pandlid.

    DATA(lo_department_feature) = zcl_interco=>feature->get( 'DEPARTMENT' ).
    DATA(lv_department_error) = abap_false.

    LOOP AT billable_items ASSIGNING FIELD-SYMBOL(<ls_billable>).

      READ TABLE lt_toggle_cache ASSIGNING FIELD-SYMBOL(<ls_cache>)
        WITH TABLE KEY product = <ls_billable>-product pandlid = <ls_billable>-pandll2id.
      IF sy-subrc <> 0.
        DATA(ls_toggle) = lo_department_feature->for(
                             iv_companycode = ms_input_params-companycode
                             iv_product     = <ls_billable>-product
                             iv_pandlid     = <ls_billable>-pandll2id
                             iv_validat     = last_day_of_month ).
        INSERT VALUE #( product = <ls_billable>-product
                         pandlid = <ls_billable>-pandll2id
                         enabled = ls_toggle-enabled ) INTO TABLE lt_toggle_cache
          ASSIGNING <ls_cache>.
      ENDIF.

      IF <ls_cache>-enabled = abap_true AND <ls_billable>-department = ''.
        lv_department_error = abap_true.
        EXIT.
      ENDIF.

    ENDLOOP.

    " AGREGADO: UPDATE movido fuera del LOOP (hallazgo ATC - DB access dentro de loop)
    IF lv_department_error = abap_true.
      lv_error_message = 'Department cannot be empty'(001).
      UPDATE zfi_a_intrc_bh
        SET executionstatus = 'FAILED',
            last_error_message = @lv_error_message
        WHERE id = @lv_basis_id.
      RETURN.
    ENDIF.
    "===== FIN AJUSTE - EXT_OSCUGALD - 02.09.2026 =====
    DATA lt_billable_items_db TYPE STANDARD TABLE OF zfi_a_intrc_bi.

    " Mapeo de campos del resultado del SELECT a la tabla de base de datos
    lt_billable_items_db = VALUE #( FOR item IN billable_items (
        id                             = lv_basis_id  " UUID de la cabecera (zfi_a_intrc_bh)
        companycode                    = item-providercompanycode " companycode es la clave del SELECT
        fiscalyear                     = item-fiscalyear
        fiscalperiod                   = item-fiscalperiod
        ledger                         = item-ledger
        pandll5id                      = item-pandll5id
        costcenterstandardhierarea     = item-costcenterstdhierarea
        ccallocation                   = item-ccallocation
        ccconsolidation                = item-ccconsolidation
        glaccount                      = item-glaccount
        costcenter                     = item-costcenter
        profitcenter                   = item-profitcenter
        paymenttype                    = item-paymenttype
        product                        = item-product " Corresponde a 'concept' en el SELECT
        mindatetime                    = item-mindatetime
        maxdatetime                    = item-maxdatetime
        companycodecurrency            = item-companycodecurrency
        globalcurrency                 = item-globalcurrency
        amountinglobalcurrency         = item-amountinglobalcurrency
        amountincompanycodecurrency    = item-amountincompanycodecurrency
        depto                          = item-department " El SELECT usa 'department'
        is_released                    = abap_false  " Se inicializa como no liberado
    ) ).

    " AGREGADO DS4K9B5Z46: idempotencia bajo retry del BGMC (borra registros del ID antes de reinsertar)
    DELETE FROM zfi_a_intrc_bi WHERE id = @lv_basis_id.

    " AGREGADO DS4K9B5Z46: deduplicacion por clave DB — conserva primer department encontrado
    SORT lt_billable_items_db BY companycode fiscalyear fiscalperiod ledger
                                  pandll5id costcenterstandardhierarea
                                  ccallocation ccconsolidation glaccount
                                  costcenter profitcenter paymenttype product.
    DELETE ADJACENT DUPLICATES FROM lt_billable_items_db
        COMPARING companycode fiscalyear fiscalperiod ledger
                  pandll5id costcenterstandardhierarea
                  ccallocation ccconsolidation glaccount
                  costcenter profitcenter paymenttype product.

    " Realizar la inserción directa
    INSERT zfi_a_intrc_bi FROM TABLE @lt_billable_items_db.
    IF sy-subrc = 0.
      " Inserción exitosa. Actualizamos el estado.
      UPDATE zfi_a_intrc_bh
        SET executionstatus = 'COMPLETED'
        WHERE id = @lv_basis_id.
      RETURN.
    ENDIF.

    " Manejo de error de base de datos
    UPDATE zfi_a_intrc_bh
      SET executionstatus = 'FAILED',
      last_error_message = 'Technical error'
      WHERE id = @lv_basis_id.

  ENDMETHOD.
ENDCLASS.
