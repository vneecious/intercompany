" BORRADOR TECNICO. No transportar hasta validar hooks, sintaxis y LUW en DS4.
" Coordinador exclusivo de etapa 1 TR: cálculo previo al IC; persistencia por grupo
" antes del COMMIT estándar de FI_INTIT_POST. Esta clase no hace COMMIT.
" La prueba controlada aún debe confirmar si BAPI_FTR_IRATE_DEALCHANGE participa
" de la LUW de FINT. BUKRS + ARRAY identifica el contrato TR.
" FI_INTIT_POST identifica un grupo por BUKRS_TO + ACCOUNT_TO + KOART_TO +
" ARRAY + INT_CURR (confirmado en el fuente estándar DS4). La clave de contrato
" que recibe TR sigue siendo BUKRS + ARRAY de la partida original.
" El hook precommit cubre NOPAY si el flujo llega al COMMIT; FI_INTIT_POST tiene
" un RETURN previo para NOINT/LT_ACCIT inicial, que requiere prueba/decisión.
CLASS zcl_fi_int_luw_coordinator DEFINITION
  PUBLIC FINAL CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_group_state,
        bukrs         TYPE intipf-bukrs,
        account       TYPE intipf-account,
        koart         TYPE intipf-koart,
        array         TYPE intipf-array,
        int_curr      TYPE intipf-int_curr,
        tr_apply_done TYPE abap_bool,
      END OF ty_group_state,
      tt_group_state TYPE HASHED TABLE OF ty_group_state
        WITH UNIQUE KEY bukrs account koart array int_curr,
      BEGIN OF ty_group_failure,
        bukrs    TYPE intipf-bukrs,
        account  TYPE intipf-account,
        koart    TYPE intipf-koart,
        array    TYPE intipf-array,
        int_curr TYPE intipf-int_curr,
        message  TYPE string,
      END OF ty_group_failure,
      tt_group_failure TYPE HASHED TABLE OF ty_group_failure
        WITH UNIQUE KEY bukrs account koart array int_curr,
      BEGIN OF ty_tr_pending,
        group_bukrs    TYPE intipf-bukrs,
        account        TYPE intipf-account,
        koart          TYPE intipf-koart,
        group_array    TYPE intipf-array,
        int_curr       TYPE intipf-int_curr,
        contract_bukrs TYPE bukrs,
        contract_array TYPE intipf-array,
      END OF ty_tr_pending,
      tt_tr_pending TYPE SORTED TABLE OF ty_tr_pending
        WITH UNIQUE KEY group_bukrs account koart group_array int_curr
                        contract_bukrs contract_array.

    CLASS-METHODS begin_execution.

    "Cierra y limpia el estado estático al final de END_OF_PROGRAMM.
    CLASS-METHODS end_execution.

    CLASS-METHODS register_tr_calculation
      IMPORTING
        it_items     TYPE fint_tt_intit_extf
        it_contracts TYPE zif_fi_int_tr_handler=>tt_contract_key
        iv_testrun   TYPE abap_bool.

    CLASS-METHODS register_tr_calc_failure
      IMPORTING
        it_items   TYPE fint_tt_intit_extf
        iv_message TYPE string.


    CLASS-METHODS before_group_commit
      IMPORTING
                is_ipf            TYPE intipf
                it_items          TYPE fint_tt_intit_extf
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    CLASS-METHODS after_group_commit
      IMPORTING is_ipf TYPE intipf.

    CLASS-METHODS on_group_error
      IMPORTING
        is_ipf     TYPE intipf
        it_items   TYPE fint_tt_intit_extf
        iv_message TYPE string OPTIONAL.

    CLASS-METHODS queue_tr_warning
      IMPORTING iv_text TYPE string.

    CLASS-METHODS append_tr_warning_to_log
      CHANGING
        ct_log TYPE fint_tt_log.

    " En A_TESTL FINT no llama FI_INTIT_PROCESS; simula la BAPI una vez al
    " finalizar, conservando el comportamiento anterior con IV_TESTRUN = X.
    CLASS-METHODS report_unapplied_tr_contracts.

    CLASS-METHODS apply_tr_test_run.

  PRIVATE SECTION.
    CONSTANTS c_tr_class TYPE seoclsname
      VALUE 'ZTR_C000123_AMORT_FINANC_VEIC'.

    CLASS-DATA:
      gt_groups           TYPE tt_group_state,
      gt_group_failures   TYPE tt_group_failure,
      gt_tr_pending       TYPE tt_tr_pending,
      gv_tr_testrun       TYPE abap_bool,
      gv_tr_warning_text  TYPE string,
      gv_execution_active TYPE abap_bool.

    CLASS-METHODS register_group
      IMPORTING
        iv_bukrs    TYPE bukrs
        iv_account  TYPE intipf-account
        iv_koart    TYPE intipf-koart
        iv_array    TYPE intipf-array
        iv_int_curr TYPE intipf-int_curr.

    CLASS-METHODS apply_tr_for_group
      IMPORTING
                is_ipf              TYPE intipf
                it_items            TYPE fint_tt_intit_extf
      RETURNING VALUE(rv_available) TYPE abap_bool.

    CLASS-METHODS cleanup_group_state
      IMPORTING is_ipf TYPE intipf.
ENDCLASS.

CLASS zcl_fi_int_luw_coordinator IMPLEMENTATION.

  METHOD begin_execution.
    " INT_ADD_ITEMS puede repetirse dentro de una misma ejecución FINT.
    " Inicializar solo en el primer callback: no perder contratos/grupos ya
    " registrados por INT_MODIFY_ITEMS de iteraciones previas.
    IF gv_execution_active = abap_true.
      RETURN.
    ENDIF.

    CLEAR: gt_groups, gt_group_failures, gt_tr_pending,
           gv_tr_testrun, gv_tr_warning_text.
    gv_execution_active = abap_true.
  ENDMETHOD.

  METHOD report_unapplied_tr_contracts.
    IF gv_tr_testrun = abap_true OR gt_tr_pending IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_unapplied_contracts TYPE zif_fi_int_tr_handler=>tt_contract_key.
    LOOP AT gt_tr_pending ASSIGNING FIELD-SYMBOL(<ls_pending>).
      INSERT VALUE #(
        bukrs = <ls_pending>-contract_bukrs
        array = <ls_pending>-contract_array )
        INTO TABLE lt_unapplied_contracts.
    ENDLOOP.

    IF lt_unapplied_contracts IS NOT INITIAL.
      queue_tr_warning(
        iv_text = |La BAPI TR no llegó al hook pre-COMMIT para { lines( lt_unapplied_contracts ) } contrato(s). Revisar flujo NOINT y estado de la actualización.| ).
    ENDIF.
  ENDMETHOD.
  METHOD end_execution.
    CLEAR: gt_groups, gt_group_failures, gt_tr_pending,
           gv_tr_testrun, gv_tr_warning_text.
    gv_execution_active = abap_false.
  ENDMETHOD.

  METHOD register_group.
    READ TABLE gt_groups TRANSPORTING NO FIELDS
      WITH TABLE KEY bukrs    = iv_bukrs
                     account  = iv_account
                     koart    = iv_koart
                     array    = iv_array
                     int_curr = iv_int_curr.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    INSERT VALUE #(
      bukrs    = iv_bukrs
      account  = iv_account
      koart    = iv_koart
      array    = iv_array
      int_curr = iv_int_curr ) INTO TABLE gt_groups.
  ENDMETHOD.

  METHOD register_tr_calculation.

    DATA lt_found_contracts TYPE zif_fi_int_tr_handler=>tt_contract_key.

    gv_tr_testrun = iv_testrun.

    " Recorrer las partidas una sola vez y asociar las que correspondan
    " a contratos devueltos por calculate_multa.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).

      IF NOT line_exists( it_contracts[
           bukrs = <ls_item>-bukrs
           array = <ls_item>-array ] ).
        CONTINUE.
      ENDIF.

      INSERT VALUE #(
        bukrs = <ls_item>-bukrs
        array = <ls_item>-array )
        INTO TABLE lt_found_contracts.

      register_group(
        iv_bukrs    = <ls_item>-bukrs_to
        iv_account  = <ls_item>-account_to
        iv_koart    = <ls_item>-koart_to
        iv_array    = <ls_item>-array
        iv_int_curr = <ls_item>-int_curr ).

      INSERT VALUE #(
        group_bukrs    = <ls_item>-bukrs_to
        account        = <ls_item>-account_to
        koart          = <ls_item>-koart_to
        group_array    = <ls_item>-array
        int_curr       = <ls_item>-int_curr
        contract_bukrs = <ls_item>-bukrs
        contract_array = <ls_item>-array )
        INTO TABLE gt_tr_pending.

    ENDLOOP.

    " Registrar los contratos informados por el handler que no pudieron
    " asociarse con ninguna partida recibida.
    LOOP AT it_contracts ASSIGNING FIELD-SYMBOL(<ls_contract>).

      IF line_exists( lt_found_contracts[
           bukrs = <ls_contract>-bukrs
           array = <ls_contract>-array ] ).
        CONTINUE.
      ENDIF.

      register_tr_calc_failure(
        it_items   = it_items
        iv_message = |No se pudo asociar el contrato TR { <ls_contract>-bukrs }/{ <ls_contract>-array } con un grupo FINT.| ).

    ENDLOOP.

  ENDMETHOD.

  METHOD register_tr_calc_failure.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      register_group(
        iv_bukrs    = <ls_item>-bukrs_to
        iv_account  = <ls_item>-account_to
        iv_koart    = <ls_item>-koart_to
        iv_array    = <ls_item>-array
        iv_int_curr = <ls_item>-int_curr ).

      INSERT VALUE #(
        bukrs    = <ls_item>-bukrs_to
        account  = <ls_item>-account_to
        koart    = <ls_item>-koart_to
        array    = <ls_item>-array
        int_curr = <ls_item>-int_curr
        message  = iv_message ) INTO TABLE gt_group_failures.
    ENDLOOP.

    queue_tr_warning( iv_text = iv_message ).
  ENDMETHOD.

  METHOD apply_tr_for_group.
    rv_available = abap_false.
    DATA lt_contracts TYPE zif_fi_int_tr_handler=>tt_contract_key.

    LOOP AT gt_tr_pending ASSIGNING FIELD-SYMBOL(<ls_pending>)
      WHERE group_bukrs = is_ipf-bukrs
        AND account     = is_ipf-account
        AND koart       = is_ipf-koart
        AND group_array = is_ipf-array
        AND int_curr    = is_ipf-int_curr.
      IF NOT line_exists( it_items[
           bukrs        = <ls_pending>-contract_bukrs
           array        = <ls_pending>-contract_array
           bukrs_to     = is_ipf-bukrs
           account_to   = is_ipf-account
           koart_to     = is_ipf-koart
           int_curr     = is_ipf-int_curr ] ).
        queue_tr_warning(
          iv_text = |El contrato TR { <ls_pending>-contract_bukrs }/{ <ls_pending>-contract_array } asociado al grupo { is_ipf-bukrs }/{ is_ipf-array } no está en CT_ITEMS del grupo.| ).
        RETURN.
      ENDIF.
      INSERT VALUE #(
        bukrs = <ls_pending>-contract_bukrs
        array = <ls_pending>-contract_array ) INTO TABLE lt_contracts.
    ENDLOOP.

    IF lt_contracts IS INITIAL.
      queue_tr_warning(
        iv_text = |Hay estado TR para el grupo { is_ipf-bukrs }/{ is_ipf-array }, pero no se pudo determinar ningún contrato.| ).
      RETURN.
    ENDIF.

    TRY.
        DATA lo_tr TYPE REF TO zif_fi_int_tr_handler.
        CREATE OBJECT lo_tr TYPE (c_tr_class).

        DATA lv_success TYPE abap_bool.
        DATA lv_message TYPE string.
        lo_tr->apply_multa(
          EXPORTING
            iv_testrun   = gv_tr_testrun
            it_contracts = lt_contracts
          IMPORTING
            ev_success   = lv_success
            ev_message   = lv_message ).

        " La llamada técnica terminó. ev_success = false representa el error
        " funcional de BAPI que TR mantiene como no bloqueante; su log detallado
        " ya lo registra la clase TR y FINT continúa como en el comportamiento actual.
        rv_available = abap_true.

        IF lv_success = abap_false AND lv_message IS INITIAL.
          queue_tr_warning(
            iv_text = |El handler TR informó un fallo de BAPI sin detalle para el grupo { is_ipf-bukrs }/{ is_ipf-array }; se conserva el comportamiento actual y FINT continúa.| ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_error).
        queue_tr_warning(
          iv_text = |No se pudo ejecutar el handler TR del grupo { is_ipf-bukrs }/{ is_ipf-array }: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD before_group_commit.
    rv_allowed = abap_true.

    READ TABLE gt_group_failures TRANSPORTING NO FIELDS
      WITH TABLE KEY bukrs    = is_ipf-bukrs
                     account  = is_ipf-account
                     koart    = is_ipf-koart
                     array    = is_ipf-array
                     int_curr = is_ipf-int_curr.
    IF sy-subrc = 0.
      rv_allowed = abap_false.
      RETURN.
    ENDIF.

    READ TABLE gt_groups ASSIGNING FIELD-SYMBOL(<ls_group>)
      WITH TABLE KEY bukrs    = is_ipf-bukrs
                     account  = is_ipf-account
                     koart    = is_ipf-koart
                     array    = is_ipf-array
                     int_curr = is_ipf-int_curr.
    DATA(lv_group_found) = xsdbool( sy-subrc = 0 ).

    IF lv_group_found = abap_false.
      RETURN.
    ENDIF.

    " Evitar repetir la BAPI si FINT invoca el hook más de una vez para el
    " mismo grupo antes de su commit.
    IF <ls_group>-tr_apply_done = abap_true.
      RETURN.
    ENDIF.

    " TR: toda persistencia pendiente ocurre por grupo antes del COMMIT.
    " Una clase/interfaz no disponible o una excepción técnica bloquea el grupo;
    " un error de negocio devuelto por la BAPI conserva el comportamiento actual.
    rv_allowed = apply_tr_for_group(
      is_ipf   = is_ipf
      it_items = it_items ).
    IF rv_allowed = abap_true.
      <ls_group>-tr_apply_done = abap_true.
    ENDIF.
  ENDMETHOD.

  METHOD after_group_commit.
    cleanup_group_state( is_ipf = is_ipf ).
  ENDMETHOD.

  METHOD cleanup_group_state.
    DELETE TABLE gt_groups FROM VALUE #(
      bukrs    = is_ipf-bukrs
      account  = is_ipf-account
      koart    = is_ipf-koart
      array    = is_ipf-array
      int_curr = is_ipf-int_curr ).

    DELETE gt_tr_pending WHERE group_bukrs = is_ipf-bukrs
                           AND account     = is_ipf-account
                           AND koart       = is_ipf-koart
                           AND group_array = is_ipf-array
                           AND int_curr    = is_ipf-int_curr.
    DELETE TABLE gt_group_failures FROM VALUE #(
      bukrs    = is_ipf-bukrs
      account  = is_ipf-account
      koart    = is_ipf-koart
      array    = is_ipf-array
      int_curr = is_ipf-int_curr ).
  ENDMETHOD.

  METHOD on_group_error.
    READ TABLE gt_groups TRANSPORTING NO FIELDS
      WITH TABLE KEY bukrs    = is_ipf-bukrs
                     account  = is_ipf-account
                     koart    = is_ipf-koart
                     array    = is_ipf-array
                     int_curr = is_ipf-int_curr.
    DATA(lv_has_group_state) = xsdbool( sy-subrc = 0 ).
    IF lv_has_group_state = abap_false.
      READ TABLE gt_group_failures TRANSPORTING NO FIELDS
        WITH TABLE KEY bukrs    = is_ipf-bukrs
                       account  = is_ipf-account
                       koart    = is_ipf-koart
                       array    = is_ipf-array
                       int_curr = is_ipf-int_curr.
      lv_has_group_state = xsdbool( sy-subrc = 0 ).
    ENDIF.

    " Idempotencia ante invocaciones repetidas del enhancement de error: después
    " de limpiar el estado no se vuelve a ejecutar ROLLBACK para este grupo.
    IF lv_has_group_state = abap_false.
      RETURN.
    ENDIF.

    " Priorizar el error concreto en el log (FI_INT_LOG_FROM_BADI lo presenta
    " como información). Se conserva un solo registro agregado por ejecución.
    IF iv_message IS NOT INITIAL.
      DATA(lv_previous_warning) = gv_tr_warning_text.
      CLEAR gv_tr_warning_text.
      queue_tr_warning(
        iv_text = |Error FINT en grupo { is_ipf-bukrs }/{ is_ipf-array }: { iv_message }| ).
      queue_tr_warning( iv_text = lv_previous_warning ).
    ENDIF.

    " Solo revierte el trabajo de la LUW del grupo actual. Los grupos previos
    " ya fueron confirmados por FI_INTIT_POST. Validar hook y secuencia en DS4.
    ROLLBACK WORK.
    cleanup_group_state( is_ipf = is_ipf ).
  ENDMETHOD.

  METHOD queue_tr_warning.
    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.
    IF gv_tr_warning_text IS INITIAL.
      gv_tr_warning_text = iv_text.
    ELSEIF gv_tr_warning_text CS iv_text.
      RETURN.
    ELSE.
      gv_tr_warning_text = |{ gv_tr_warning_text }; { iv_text }|.
    ENDIF.
  ENDMETHOD.

  METHOD append_tr_warning_to_log.
    IF gv_tr_warning_text IS INITIAL.
      RETURN.
    ENDIF.

    APPEND INITIAL LINE TO ct_log
      ASSIGNING FIELD-SYMBOL(<ls_log>).

    <ls_log>-ltext =
      |Información TR: { gv_tr_warning_text }|.

    CLEAR gv_tr_warning_text.
  ENDMETHOD.

  METHOD apply_tr_test_run.
    IF gv_tr_testrun <> abap_true.
      RETURN.
    ENDIF.

    DATA lt_contracts TYPE zif_fi_int_tr_handler=>tt_contract_key.
    LOOP AT gt_tr_pending ASSIGNING FIELD-SYMBOL(<ls_pending>).
      INSERT VALUE #(
        bukrs = <ls_pending>-contract_bukrs
        array = <ls_pending>-contract_array ) INTO TABLE lt_contracts.
    ENDLOOP.

    IF lt_contracts IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA lo_tr TYPE REF TO zif_fi_int_tr_handler.
        CREATE OBJECT lo_tr TYPE (c_tr_class).

        DATA lv_success TYPE abap_bool.
        DATA lv_message TYPE string.
        lo_tr->apply_multa(
          EXPORTING
            iv_testrun   = abap_true
            it_contracts = lt_contracts
          IMPORTING
            ev_success   = lv_success
            ev_message   = lv_message ).

        " En modo prueba no hay contabilización por grupo. Se mantiene la
        " simulación de la BAPI que hacía la implementación TR anterior.
        IF lv_success = abap_false AND lv_message IS INITIAL.
          queue_tr_warning(
            iv_text = 'El handler TR devolvió un fallo de BAPI sin detalle durante el test run.' ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_error).
        queue_tr_warning(
          iv_text = |No se pudo simular la actualización TR durante el test run: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
