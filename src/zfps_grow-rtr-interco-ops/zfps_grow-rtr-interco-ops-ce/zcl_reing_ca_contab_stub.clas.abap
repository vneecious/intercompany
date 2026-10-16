*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : App CONTAB - Contabilizacion IC - F4 Stub dispatcher *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Mock de ZIF_REING_CONTAB_DISPATCHER (F4-02). Permite desarrollar y
* testear las acciones RAP de CA (Simulate/Post/Storno) y el adapter sin
* depender del Engine real (ZCL_REING_CONTAB_ENGINE, aun inexistente).
*
* Comportamiento por defecto: devuelve success = abap_true con un BELNR
* ficticio determinista derivado del modo + line_num, sin tocar la base.
* Configurable via set_next_result() para forzar escenarios de error en
* los unit tests (ej. simular fallo de BAPI_ACC_DOCUMENT_POST).
*
* No persiste nada; es puro in-memory. Cuando el Engine este listo, el
* ADAPTER real (ZCL_REING_CA_CONTAB_ADAPTER) reemplaza a este stub en
* produccion; el stub queda solo para ABAP Unit.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_contab_stub DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_contab_dispatcher.

    "! Fuerza el resultado de la proxima llamada a process_line.
    "! Si no se llama, el stub devuelve exito con BELNR ficticio.
    "! @parameter iv_success | abap_true = exito / abap_false = error
    "! @parameter iv_message | mensaje a devolver (opcional)
    "! @parameter iv_accounting_doc | BELNR a devolver (opcional)
    METHODS set_next_result
      IMPORTING
        iv_success        TYPE abap_bool
        iv_message        TYPE zif_reing_ca_types=>ty_contab_result-message OPTIONAL
        iv_accounting_doc TYPE zreing_cm_h_a-accounting_doc OPTIONAL.

  PRIVATE SECTION.
    " Resultado forzado para la proxima llamada (si mv_forced = abap_true).
    DATA mv_forced         TYPE abap_bool.
    DATA ms_forced_result  TYPE zif_reing_ca_types=>ty_contab_result.

    " Contador de llamadas, util para asserts en los unit tests.
    DATA mv_call_count     TYPE i.
ENDCLASS.


CLASS zcl_reing_ca_contab_stub IMPLEMENTATION.

  METHOD set_next_result.
    mv_forced = abap_true.
    ms_forced_result = VALUE #(
      success        = iv_success
      message        = iv_message
      accounting_doc = iv_accounting_doc ).
  ENDMETHOD.


  METHOD zif_reing_contab_dispatcher~process_line.
    mv_call_count = mv_call_count + 1.

    " --- Escenario forzado (para unit tests) ---
    IF mv_forced = abap_true.
      rs_result = ms_forced_result.
      mv_forced = abap_false.          " se consume una sola vez
      RETURN.
    ENDIF.

    " --- Comportamiento por defecto: exito con BELNR ficticio ---
    " BELNR determinista: prefijo por modo + line_num, para que los
    " tests puedan predecir el valor sin acoplarse a rangos reales.
    DATA(lv_prefix) = SWITCH string( iv_mode
      WHEN 'C' THEN 'SIM'      " Check / Simular  -> no genera doc real
      WHEN 'P' THEN 'POST'     " Post / Contabilizar
      WHEN 'S' THEN 'REV'      " Storno / Anular
      ELSE 'UNK' ).

    " En modo Check (simulacion) no hay documento contable: doc vacio.
    DATA lv_doc TYPE zreing_cm_h_a-accounting_doc.
    IF iv_mode = 'C'.
      CLEAR lv_doc.
    ELSE.
      lv_doc = |{ lv_prefix }{ is_line_a-line_num }|.
    ENDIF.

    rs_result = VALUE #(
      success        = abap_true
      message        = |STUB { lv_prefix }: OK linea { is_line_a-line_num } op { is_line_a-op_type }|
      accounting_doc = lv_doc ).
  ENDMETHOD.

ENDCLASS.

