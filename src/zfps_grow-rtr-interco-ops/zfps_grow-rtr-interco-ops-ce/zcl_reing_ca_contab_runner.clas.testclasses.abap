*----------------------------------------------------------------------*
* Tests de CONTAB (Simulate / Post / Storno).
*
* Vienen de ltcl_contab_actions (include "test classes" de ZBP_REINGCARUN),
* movidos aca junto con el nucleo en V023. El motivo es tecnico y no
* opinable: el TEST-INJECTION solo se asocia a su TEST-SEAM dentro del
* MISMO pool de clases. Como el seam "engine_process" viajo con el cuerpo
* de run_contab_mode, los tests que lo inyectan tienen que vivir aqui.
*
* Se mantiene el mecanismo original: ZCL_REING_CONTAB_ENGINE es
* "DEFINITION PUBLIC FINAL CREATE PUBLIC" y cl_abap_testdouble=>create( )
* genera una SUBCLASE en runtime -> imposible sobre una clase FINAL.
* TEST-SEAM / TEST-INJECTION es el mecanismo estandar para sustituir una
* dependencia FINAL sin tocar su contrato publico.
*
* Unico cambio de forma respecto del original: las aserciones ya no miran
* los buffers estaticos del behavior pool (gt_line_f4 / gt_posted_evt /
* gt_reversed_evt / gt_log) sino los parametros de salida homonimos, que es
* como el nucleo devuelve ahora sus resultados. El estado del doble
* (gs_engine_result / gv_engine_*) sigue viviendo en la clase productiva,
* no aca: el TEST-INJECTION se compila en el contexto de run_contab_mode y
* no puede referenciar componentes de una clase que se define despues.
*----------------------------------------------------------------------*
CLASS ltcl_contab_actions DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_run  TYPE zreing_ca_run_a-calc_run_id VALUE 'RUN-202608'.
    CONSTANTS c_line TYPE zreing_ca_line_a-line_num   VALUE '0000010'.

    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    " --- casos de la spec ----------------------------------------------
    " CU-2 / CU-11 / BR-F4-03
    METHODS post_ok_fires_posted_event    FOR TESTING RAISING cx_static_check.
    " CU-6 / BR-F4-03 (error parcial: has_error consolidado limpio)
    METHODS post_partial_error_no_event   FOR TESTING RAISING cx_static_check.
    " CU-7 / BR-CA-37 / BR-F4-07 (guard AUTO_REVERSAL rechaza el Storno)
    METHODS storno_auto_reversal_rejected FOR TESTING RAISING cx_static_check.
    " CU-14 / BR-F4-07 (error de negocio generico: la linea sigue en CONT)
    METHODS storno_error_is_retryable    FOR TESTING RAISING cx_static_check.
    " V001 (CC) - #105: successful Storno retains terminal history.
    METHODS storno_ok_goes_to_anuld        FOR TESTING RAISING cx_static_check.
    METHODS terminal_line_not_prefetched FOR TESTING RAISING cx_static_check.
    " CU-8 / CLAR-03 (estado de origen no admitido: no se llama al Engine)
    METHODS post_from_calc_is_rejected    FOR TESTING RAISING cx_static_check.
    " CLAR-03 / SUP-01..03 (matriz de estados de origen)
    METHODS allowed_source_matrix         FOR TESTING RAISING cx_static_check.

    METHODS post_err_without_fi FOR TESTING RAISING cx_static_check.
    METHODS external_reverse_skips_bapi FOR TESTING RAISING cx_static_check.
    METHODS unreadable_fi_is_anul_err FOR TESTING RAISING cx_static_check.
    METHODS retry_anul_err FOR TESTING RAISING cx_static_check.

    " --- helpers de test ------------------------------------------------
    METHODS given_line
      IMPORTING iv_status  TYPE zreing_ca_line_status
                iv_op_type TYPE zreing_ca_line_a-op_type DEFAULT 'ANT'.
    METHODS given_scope
      RETURNING VALUE(rt_groups) TYPE zreing_ca_tt_group_key.
    " run_contab_mode no lee la base: las 3 lecturas masivas viven en
    " prefetch_contab_data, que el llamador invoca UNA sola vez. El test hace
    " lo mismo: pre-lee contra los dobles OSQL y le pasa las 3 tablas al CUT.
    METHODS given_prefetch
      EXPORTING et_lines   TYPE zif_reing_ca_types=>ty_line_t
                et_line_pc TYPE zif_reing_ca_types=>ty_line_pc_t
                et_step    TYPE zif_reing_ca_types=>ty_step_t.
    " Configuran el comportamiento que el TEST-INJECTION reproduce.
    METHODS engine_returns
      IMPORTING is_result TYPE zif_reing_contab_types=>ty_process_result.
    METHODS engine_raises
      IMPORTING iv_text   TYPE string.

    METHODS trans_fields_prefetched FOR TESTING RAISING cx_static_check.
    " V001 (CC) - CB-05 (Delta v2): complete identity and row preservation.
    METHODS scope_keeps_full_identity FOR TESTING RAISING cx_static_check.
    METHODS populate_full_line CHANGING cs_line TYPE zreing_ca_line_a.
ENDCLASS.


CLASS ltcl_contab_actions IMPLEMENTATION.

  METHOD class_setup.
    sql_env = cl_osql_test_environment=>create( VALUE #(
      ( 'ZREING_CA_LINE_A' )
      ( 'ZREING_CA_LPC_A' )
      ( 'ZREING_CA_STEP_A' )
      ( 'ZREING_CA_LOG_A' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    sql_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    " El estado del doble es CLASS-DATA de la clase productiva: hay que
    " dejarlo limpio en CADA test, si no un test ve el resultado del anterior.
    zcl_reing_ca_contab_runner=>gv_reversal_state = 'P'.
    CLEAR: zcl_reing_ca_contab_runner=>gs_engine_result,
           zcl_reing_ca_contab_runner=>gv_engine_raise,
           zcl_reing_ca_contab_runner=>gv_engine_text,
           zcl_reing_ca_contab_runner=>gv_engine_calls.
  ENDMETHOD.

  METHOD teardown.
    sql_env->clear_doubles( ).
  ENDMETHOD.

  METHOD given_line.
    " Una unica LINE_A del scope, con el estado de origen que pide el caso.
    DATA lt_line TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    lt_line = VALUE #( ( calc_run_id = c_run
                         line_num    = c_line
                         ct_uuid     = '00000000000000000000000000000001'
                         mat_uuid    = '00000000000000000000000000000002'
                         op_type     = iv_op_type
                         op_uuid     = '00000000000000000000000000000003'
                         line_status = iv_status ) ).
    sql_env->insert_test_data( lt_line ).
  ENDMETHOD.

  METHOD given_scope.
    rt_groups = VALUE #( ( ct_uuid  = '00000000000000000000000000000001'
                           mat_uuid = '00000000000000000000000000000002'
                           op_type  = 'ANT'
                           op_uuid  = '00000000000000000000000000000003' ) ).
  ENDMETHOD.

  METHOD given_prefetch.
    zcl_reing_ca_contab_runner=>prefetch_contab_data(
      EXPORTING it_run_rng = VALUE #( ( sign = 'I' option = 'EQ' low = c_run ) )
                it_groups  = given_scope( )
      IMPORTING et_lines   = et_lines
                et_line_pc = et_line_pc
                et_step    = et_step ).
  ENDMETHOD.

  METHOD engine_returns.
    zcl_reing_ca_contab_runner=>gs_engine_result = is_result.
    zcl_reing_ca_contab_runner=>gv_engine_raise  = abap_false.
  ENDMETHOD.

  METHOD engine_raises.
    " El mensaje del Engine se propaga TAL CUAL a sim_message / LOG_A: CA no
    " lo reinterpreta (por eso el texto del guard AUTO_REVERSAL se asevera
    " sobre lo que viaja en la excepcion, no sobre un texto propio de CA).
    zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
    zcl_reing_ca_contab_runner=>gv_engine_text  = iv_text.
  ENDMETHOD.

  METHOD post_ok_fires_posted_event.
    " CU-2: linea en LIBD, Engine sin errores (ni consolidado ni por
    " documento) -> CONT + evento Posted exactamente 1 vez.
    given_line( iv_status = zif_reing_ca_c=>line_status-libd ).
    engine_returns( VALUE #( has_error = abap_false
                             documents = VALUE #( ( has_error = abap_false ) ) ) ).

    " OB-004: el constructor real de ZCX_REING_CONTAB exige iv_message
    " (METHODS constructor IMPORTING iv_message TYPE string previous TYPE
    " REF TO cx_root OPTIONAL) -> siempre se pasa. Un NEW zcx_reing_contab( )
    " sin ese parametro NO compila.
    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      IF zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
        RAISE EXCEPTION NEW zcx_reing_contab(
          iv_message = zcl_reing_ca_contab_runner=>gv_engine_text ).
      ENDIF.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.

    given_prefetch( IMPORTING et_lines   = DATA(lt_pf_line)
                              et_line_pc = DATA(lt_pf_pc)
                              et_step    = DATA(lt_pf_step) ).
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id       = c_run
                it_groups       = given_scope( )
                iv_mode         = zif_reing_ca_c=>contab_mode-post
                it_lines_all    = lt_pf_line
                it_pc_all       = lt_pf_pc
                it_step_all     = lt_pf_step
                it_reversal_check = VALUE #( FOR ls_check_line IN lt_pf_line
                  ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
                    state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_msg          = DATA(lt_msg)
                et_log          = DATA(lt_log)
                et_line_upd     = DATA(lt_line_upd)
                et_posted_evt   = DATA(lt_posted)
                et_reversed_evt = DATA(lt_reversed)
                ev_has_error    = DATA(lv_has_error) ).

    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 1
      msg = 'El Engine debe invocarse exactamente una vez por linea admitida' ).
    cl_abap_unit_assert=>assert_false( act = lv_has_error
      msg = 'Post exitoso no debe reportar error' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_line_upd ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_line_upd[ 1 ]-line_status
      exp = zif_reing_ca_c=>line_status-cont
      msg = 'BR-F4: Post exitoso debe dejar la linea en CONT' ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_posted ) exp = 1
      msg = 'CU-11: exactamente 1 evento Posted por linea posteada' ).
    cl_abap_unit_assert=>assert_initial(
      act = lt_reversed
      msg = 'Post no debe encolar eventos Reversed' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_msg ) exp = 1 ).
    " OB-002: log_num es placeholder 0 -- lo recalcula el llamador (V011 en
    " save_modified, persist_results en el job APJ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_log[ 1 ]-log_num exp = 0
      msg = 'log_num debe quedar en 0: lo recalcula el llamador (V011)' ).
  ENDMETHOD.

  METHOD post_partial_error_no_event.
    " CU-6 / BR-F4-03 / DD-F4-5: has_error consolidado = false pero un
    " documento en error -> POST_ERR y NINGUN evento. Este es el caso que
    " distingue una implementacion correcta de una que solo mira has_error.
    given_line( iv_status = zif_reing_ca_c=>line_status-libd ).
    engine_returns( VALUE #( has_error = abap_false
                             documents = VALUE #( ( has_error = abap_false )
                                                  ( has_error = abap_true ) ) ) ).

    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      IF zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
        RAISE EXCEPTION NEW zcx_reing_contab(
          iv_message = zcl_reing_ca_contab_runner=>gv_engine_text ).
      ENDIF.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.

    given_prefetch( IMPORTING et_lines   = DATA(lt_pf_line)
                              et_line_pc = DATA(lt_pf_pc)
                              et_step    = DATA(lt_pf_step) ).
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id     = c_run
                it_groups     = given_scope( )
                iv_mode       = zif_reing_ca_c=>contab_mode-post
                it_lines_all  = lt_pf_line
                it_pc_all     = lt_pf_pc
                it_step_all   = lt_pf_step
                it_reversal_check = VALUE #( FOR ls_check_line IN lt_pf_line
                  ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
                    state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd   = DATA(lt_line_upd)
                et_posted_evt = DATA(lt_posted)
                ev_has_error  = DATA(lv_has_error) ).

    cl_abap_unit_assert=>assert_true( act = lv_has_error ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_line_upd[ 1 ]-line_status
      exp = zif_reing_ca_c=>line_status-post_err
      msg = 'CU-6: error parcial debe dejar la linea en POST_ERR' ).
    cl_abap_unit_assert=>assert_initial(
      act = lt_posted
      msg = 'BR-F4-03: un error parcial NO debe disparar el evento Posted' ).
  ENDMETHOD.

  METHOD storno_auto_reversal_rejected.
    " CU-7 / BR-CA-37: el OP_TYPE usa AUTO_REVERSAL, el guard del Engine
    " (check_auto_reversal_guard) lanza ZCX_REING_CONTAB. CA no duplica el
    " V001 (CC) - GAP-001: explicit errors transition to retry-only ANUL_ERR.
    DATA(lv_text) = `El OP_TYPE usa anulacion automatica SAP`.
    given_line( iv_status = zif_reing_ca_c=>line_status-cont ).
    engine_raises( lv_text ).

    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      IF zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
        RAISE EXCEPTION NEW zcx_reing_contab(
          iv_message = zcl_reing_ca_contab_runner=>gv_engine_text ).
      ENDIF.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.

    given_prefetch( IMPORTING et_lines   = DATA(lt_pf_line)
                              et_line_pc = DATA(lt_pf_pc)
                              et_step    = DATA(lt_pf_step) ).
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id       = c_run
                it_groups       = given_scope( )
                iv_mode         = zif_reing_ca_c=>contab_mode-storno
                it_lines_all    = lt_pf_line
                it_pc_all       = lt_pf_pc
                it_step_all     = lt_pf_step
                it_reversal_check = VALUE #( FOR ls_check_line IN lt_pf_line
                  ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
                    state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_msg          = DATA(lt_msg)
                et_log          = DATA(lt_log)
                et_line_upd     = DATA(lt_line_upd)
                et_reversed_evt = DATA(lt_reversed)
                ev_has_error    = DATA(lv_has_error) ).

    cl_abap_unit_assert=>assert_true( act = lv_has_error
      msg = 'CU-7: el rechazo del guard AUTO_REVERSAL debe reportarse como error' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_line_upd[ 1 ]-line_status
      exp = zif_reing_ca_c=>line_status-anul_err
      msg = 'GAP-001: explicit reversal errors are retryable ANUL_ERR' ).
    " OB-004: BR-CA-37 / BR-F4-07 exigen que el TEXTO del Engine llegue tal
    " cual a sim_message y a LOG_A (CA no lo reinterpreta). Se compara con
    " assert_char_cp porque sim_message es CHAR220 (rellena con blancos y
    " trunca al largo del campo).
    cl_abap_unit_assert=>assert_char_cp(
      act = lt_line_upd[ 1 ]-sim_message
      exp = |*{ lv_text }*|
      msg = 'BR-F4-07: sim_message debe llevar el texto del Engine sin reinterpretar' ).
    cl_abap_unit_assert=>assert_initial(
      act = lt_reversed
      msg = 'CU-7: sin estorno efectivo no puede haber evento Reversed' ).
    " V001 (CC) - GAP-001: log retains CONT -> ANUL_ERR on a rejected reversal.
    cl_abap_unit_assert=>assert_equals( act = lines( lt_log ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_log[ 1 ]-status_from exp = zif_reing_ca_c=>line_status-cont
      msg = 'GAP-001: preserve original CONT status in audit log' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_log[ 1 ]-status_to exp = zif_reing_ca_c=>line_status-anul_err
      msg = 'GAP-001: reversal rejection logs retryable ANUL_ERR' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lt_log[ 1 ]-message
      exp = |*{ lv_text }*|
      msg = 'BR-CA-37: el texto del Engine debe quedar tambien en LOG_A' ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_msg[ 1 ]-action exp = zif_reing_ca_c=>action-storno ).
  ENDMETHOD.

  METHOD storno_error_is_retryable.
    " CU-14: cualquier otro error de negocio del Engine en modo S. Identico
    " a CU-7. Valida que la implementacion no invento ANUL_ERR ni reutilizo
    " POST_ERR.
    DATA(lv_text) = `Error de negocio generico del Engine`.
    given_line( iv_status = zif_reing_ca_c=>line_status-cont ).
    engine_raises( lv_text ).

    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      IF zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
        RAISE EXCEPTION NEW zcx_reing_contab(
          iv_message = zcl_reing_ca_contab_runner=>gv_engine_text ).
      ENDIF.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.

    given_prefetch( IMPORTING et_lines   = DATA(lt_pf_line)
                              et_line_pc = DATA(lt_pf_pc)
                              et_step    = DATA(lt_pf_step) ).
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id       = c_run
                it_groups       = given_scope( )
                iv_mode         = zif_reing_ca_c=>contab_mode-storno
                it_lines_all    = lt_pf_line
                it_pc_all       = lt_pf_pc
                it_step_all     = lt_pf_step
                it_reversal_check = VALUE #( FOR ls_check_line IN lt_pf_line
                  ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
                    state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd     = DATA(lt_line_upd)
                et_reversed_evt = DATA(lt_reversed)
                ev_has_error    = DATA(lv_has_error) ).

    cl_abap_unit_assert=>assert_true( act = lv_has_error ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_line_upd[ 1 ]-line_status
      exp = zif_reing_ca_c=>line_status-anul_err
      msg = 'CU-14: sin estado *_ERR de anulacion, la linea queda en CONT' ).
    cl_abap_unit_assert=>assert_char_cp(
      act = lt_line_upd[ 1 ]-sim_message
      exp = |*{ lv_text }*|
      msg = 'BR-F4-07: el texto del error del Engine se propaga a sim_message' ).
    cl_abap_unit_assert=>assert_initial( act = lt_reversed ).
  ENDMETHOD.

  METHOD storno_ok_goes_to_anuld.
    " V001 (CC) - #105: a successful FI reversal closes this row permanently.
    given_line( iv_status = zif_reing_ca_c=>line_status-cont ).
    engine_returns( VALUE #( has_error = abap_false
                             documents = VALUE #( ( has_error = abap_false ) ) ) ).

    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      IF zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
        RAISE EXCEPTION NEW zcx_reing_contab(
          iv_message = zcl_reing_ca_contab_runner=>gv_engine_text ).
      ENDIF.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.

    given_prefetch( IMPORTING et_lines   = DATA(lt_pf_line)
                              et_line_pc = DATA(lt_pf_pc)
                              et_step    = DATA(lt_pf_step) ).
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id       = c_run
                it_groups       = given_scope( )
                iv_mode         = zif_reing_ca_c=>contab_mode-storno
                it_lines_all    = lt_pf_line
                it_pc_all       = lt_pf_pc
                it_step_all     = lt_pf_step
                it_reversal_check = VALUE #( FOR ls_check_line IN lt_pf_line
                  ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
                    state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd     = DATA(lt_line_upd)
                et_posted_evt   = DATA(lt_posted)
                et_reversed_evt = DATA(lt_reversed)
                ev_has_error    = DATA(lv_has_error) ).

    cl_abap_unit_assert=>assert_false( act = lv_has_error ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_line_upd[ 1 ]-line_status
      exp = zif_reing_ca_c=>line_status-anuld
      msg = '#105: successful reversal must retain ANULD' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_reversed ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( act = lt_posted ).
  ENDMETHOD.

  METHOD post_from_calc_is_rejected.
    " CU-8 / CLAR-03: Post sobre una linea en CALC (no liberada). CA debe
    " bloquearla ANTES de invocar al Engine. Con el TEST-SEAM la prueba es
    " directa: gv_engine_calls debe quedar en 0.
    given_line( iv_status = zif_reing_ca_c=>line_status-calc ).
    engine_returns( VALUE #( has_error = abap_false
                             documents = VALUE #( ( has_error = abap_false ) ) ) ).

    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      IF zcl_reing_ca_contab_runner=>gv_engine_raise = abap_true.
        RAISE EXCEPTION NEW zcx_reing_contab(
          iv_message = zcl_reing_ca_contab_runner=>gv_engine_text ).
      ENDIF.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.

    given_prefetch( IMPORTING et_lines   = DATA(lt_pf_line)
                              et_line_pc = DATA(lt_pf_pc)
                              et_step    = DATA(lt_pf_step) ).
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id     = c_run
                it_groups     = given_scope( )
                iv_mode       = zif_reing_ca_c=>contab_mode-post
                it_lines_all  = lt_pf_line
                it_pc_all     = lt_pf_pc
                it_step_all   = lt_pf_step
                it_reversal_check = VALUE #( FOR ls_check_line IN lt_pf_line
                  ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
                    state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_msg        = DATA(lt_msg)
                et_line_upd   = DATA(lt_line_upd)
                et_posted_evt = DATA(lt_posted)
                ev_has_error  = DATA(lv_has_error) ).

    cl_abap_unit_assert=>assert_true( act = lv_has_error ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 0
      msg = 'CU-8: un estado de origen invalido NO debe llegar al Engine' ).
    cl_abap_unit_assert=>assert_initial(
      act = lt_line_upd
      msg = 'CU-8: una linea con estado de origen invalido no se transiciona' ).
    cl_abap_unit_assert=>assert_initial( act = lt_posted ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_msg[ 1 ]-status_from exp = lt_msg[ 1 ]-status_to
      msg = 'El rechazo por estado de origen se registra sin transicion' ).
  ENDMETHOD.


  METHOD post_err_without_fi.
    given_line( iv_status = 'POST_ERR' ).
    zcl_reing_ca_contab_runner=>gv_reversal_state = 'N'.
    engine_returns( VALUE #( has_error = abap_false ) ).
    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.
    given_prefetch( IMPORTING et_lines = DATA(lt_lines)
      et_line_pc = DATA(lt_pc) et_step = DATA(lt_steps) ).
    " V001 (CC) - CB-05 (Delta v2): compare every persisted field.
    populate_full_line( CHANGING cs_line = lt_lines[ 1 ] ).
    DATA(lt_groups) = given_scope( ).
    lt_groups[ 1 ]-cm_h_id = lt_lines[ 1 ]-cm_h_id.
    DATA(ls_expected) = lt_lines[ 1 ].
    ls_expected-line_status = 'ANULD'.
    ls_expected-sim_message =
      'STORNO OK: no quedan documentos FI pendientes de anular.'.
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id = c_run it_groups = lt_groups iv_mode = 'S'
        it_lines_all = lt_lines it_pc_all = lt_pc it_step_all = lt_steps
        it_reversal_check = VALUE #( FOR ls_check_line IN lt_lines
          ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
            state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd = DATA(lt_upd) ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-line_status exp = 'ANULD' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-trans_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-bruto_amt exp = lt_lines[ 1 ]-bruto_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-net_trans_amt exp = lt_lines[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-exch_rate_1 exp = lt_lines[ 1 ]-exch_rate_1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_upd ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ] exp = ls_expected ).
  ENDMETHOD.


  METHOD external_reverse_skips_bapi.
    given_line( iv_status = 'CONT' ).
    zcl_reing_ca_contab_runner=>gv_reversal_state = 'R'.
    engine_returns( VALUE #( has_error = abap_false ) ).
    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.
    given_prefetch( IMPORTING et_lines = DATA(lt_lines)
      et_line_pc = DATA(lt_pc) et_step = DATA(lt_steps) ).
    lt_lines[ 1 ]-trans_currency = 'BRL'.
    lt_lines[ 1 ]-bruto_amt = '123.45'.
    lt_lines[ 1 ]-net_trans_amt = '100.00'.
    lt_lines[ 1 ]-exch_rate_1 = '1.234567'.
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id = c_run it_groups = given_scope( ) iv_mode = 'S'
        it_lines_all = lt_lines it_pc_all = lt_pc it_step_all = lt_steps
        it_reversal_check = VALUE #( FOR ls_check_line IN lt_lines
          ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
            state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd = DATA(lt_upd) ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-line_status exp = 'ANULD' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-trans_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-bruto_amt exp = lt_lines[ 1 ]-bruto_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-net_trans_amt exp = lt_lines[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-exch_rate_1 exp = lt_lines[ 1 ]-exch_rate_1 ).
  ENDMETHOD.


  METHOD unreadable_fi_is_anul_err.
    given_line( iv_status = 'CONT' ).
    zcl_reing_ca_contab_runner=>gv_reversal_state = 'E'.
    engine_returns( VALUE #( has_error = abap_false ) ).
    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.
    given_prefetch( IMPORTING et_lines = DATA(lt_lines)
      et_line_pc = DATA(lt_pc) et_step = DATA(lt_steps) ).
    lt_lines[ 1 ]-trans_currency = 'BRL'.
    lt_lines[ 1 ]-bruto_amt = '123.45'.
    lt_lines[ 1 ]-net_trans_amt = '100.00'.
    lt_lines[ 1 ]-exch_rate_1 = '1.234567'.
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id = c_run it_groups = given_scope( ) iv_mode = 'S'
        it_lines_all = lt_lines it_pc_all = lt_pc it_step_all = lt_steps
        it_reversal_check = VALUE #( FOR ls_check_line IN lt_lines
          ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
            state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd = DATA(lt_upd) ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-line_status exp = 'ANUL_ERR' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-trans_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-bruto_amt exp = lt_lines[ 1 ]-bruto_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-net_trans_amt exp = lt_lines[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-exch_rate_1 exp = lt_lines[ 1 ]-exch_rate_1 ).
  ENDMETHOD.


  METHOD retry_anul_err.
    given_line( iv_status = 'ANUL_ERR' ).
    zcl_reing_ca_contab_runner=>gv_reversal_state = 'P'.
    engine_returns( VALUE #( has_error = abap_false ) ).
    TEST-INJECTION engine_process.
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.
    given_prefetch( IMPORTING et_lines = DATA(lt_lines)
      et_line_pc = DATA(lt_pc) et_step = DATA(lt_steps) ).
    " V001 (CC) - CB-05 (Delta v2): compare every persisted field.
    populate_full_line( CHANGING cs_line = lt_lines[ 1 ] ).
    DATA(lt_groups) = given_scope( ).
    lt_groups[ 1 ]-cm_h_id = lt_lines[ 1 ]-cm_h_id.
    DATA(ls_expected) = lt_lines[ 1 ].
    ls_expected-line_status = 'ANULD'.
    ls_expected-sim_message =
      'STORNO OK: ningun paso del flujo resulto aplicable, no se genero documento (caso tipico: linea con saldo cero).'.
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id = c_run it_groups = lt_groups iv_mode = 'S'
        it_lines_all = lt_lines it_pc_all = lt_pc it_step_all = lt_steps
        it_reversal_check = VALUE #( FOR ls_check_line IN lt_lines
          ( calc_run_id = ls_check_line-calc_run_id line_num = ls_check_line-line_num
            state = zcl_reing_ca_contab_runner=>gv_reversal_state ) )
      IMPORTING et_line_upd = DATA(lt_upd) ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-line_status exp = 'ANULD' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-trans_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-bruto_amt exp = lt_lines[ 1 ]-bruto_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-net_trans_amt exp = lt_lines[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ]-exch_rate_1 exp = lt_lines[ 1 ]-exch_rate_1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_upd ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ] exp = ls_expected ).
  ENDMETHOD.

  METHOD allowed_source_matrix.
    " CLAR-03 / SUP-01..03. Matriz confirmada por el funcional el 05.08.2026.
    " Unico test que no necesita doble del Engine.
    " V023: Post y Storno admiten ADEMAS su propio estado *_PROC. No es un
    " relajamiento de BR-CA-36: desde que esos dos modos corren como job APJ,
    " la linea llega al nucleo YA marcada en POST_PROC / ANUL_PROC -- ese
    " estado ES el scope que el job leyo de base, no una accion ajena en
    " vuelo. Quien sigue haciendo el gatekeeping real contra LIBD / POST_ERR /
    " CONT es el handler, antes de marcar la linea.
    DATA(lt_c) = zcl_reing_ca_contab_runner=>allowed_source_status(
                   zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_c ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-calc IN lt_c ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-sim_err IN lt_c ) ).
    " Simulate NO pasa por el job: su matriz no lleva SIM_PROC.
    cl_abap_unit_assert=>assert_false( act = xsdbool(
      zif_reing_ca_c=>line_status-sim_proc IN lt_c ) ).

    DATA(lt_p) = zcl_reing_ca_contab_runner=>allowed_source_status(
                   zif_reing_ca_c=>contab_mode-post ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_p ) exp = 3 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-libd IN lt_p ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-post_err IN lt_p ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-post_proc IN lt_p ) ).
    " BR-CA-36: no se postea desde SIM_OK ni se re-postea desde CONT.
    cl_abap_unit_assert=>assert_false( act = xsdbool(
      zif_reing_ca_c=>line_status-sim_ok IN lt_p ) ).
    cl_abap_unit_assert=>assert_false( act = xsdbool(
      zif_reing_ca_c=>line_status-cont IN lt_p ) ).

    DATA(lt_s) = zcl_reing_ca_contab_runner=>allowed_source_status(
                   zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_s ) exp = 4 ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-cont IN lt_s ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool(
      zif_reing_ca_c=>line_status-anul_proc IN lt_s ) ).
  ENDMETHOD.

  METHOD terminal_line_not_prefetched.
    " V001 (CC) - #105: no second accounting action includes cancelled history.
    given_line( iv_status = zif_reing_ca_c=>line_status-anuld ).
    given_prefetch( IMPORTING et_lines = DATA(lt_lines)
                             et_line_pc = DATA(lt_pc) et_step = DATA(lt_step) ).
    cl_abap_unit_assert=>assert_initial( lt_lines ).
    DATA(lt_c) = zcl_reing_ca_contab_runner=>allowed_source_status(
      zif_reing_ca_c=>contab_mode-check ).
    DATA(lt_p) = zcl_reing_ca_contab_runner=>allowed_source_status(
      zif_reing_ca_c=>contab_mode-post ).
    DATA(lt_s) = zcl_reing_ca_contab_runner=>allowed_source_status(
      zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_false(
      xsdbool( zif_reing_ca_c=>line_status-anuld IN lt_c ) ).
    cl_abap_unit_assert=>assert_false(
      xsdbool( zif_reing_ca_c=>line_status-anuld IN lt_p ) ).
    cl_abap_unit_assert=>assert_false(
      xsdbool( zif_reing_ca_c=>line_status-anuld IN lt_s ) ).
  ENDMETHOD.

  METHOD trans_fields_prefetched.
given_line( zif_reing_ca_c=>line_status-calc ).
    DATA lt_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    lt_pc = VALUE #( ( calc_run_id = c_run line_num = c_line pc_seq = 1
      bruto_trans_amt = '375.25' net_trans_amt = '300.50' )
      ( calc_run_id = 'OTHER-RUN' line_num = c_line pc_seq = 1 bruto_trans_amt = 99 ) ).
    sql_env->insert_test_data( lt_pc ).
    DATA lt_steps TYPE zif_reing_ca_types=>ty_step_t.
    lt_steps = VALUE #( ( calc_run_id = c_run line_num = c_line step_num = '04' seq = '01'
      step_category = zif_reing_ca_c=>step_category-tax output_trans_amt = '125.75' ) ).
    sql_env->insert_test_data( lt_steps ).
    given_prefetch( IMPORTING et_lines = DATA(lt_lines) et_line_pc = DATA(lt_read_pc) et_step = DATA(lt_read_steps) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_read_pc ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_read_pc[ 1 ]-bruto_trans_amt exp = CONV zreing_ca_bruto_amt( '375.25' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_read_pc[ 1 ]-net_trans_amt exp = CONV zreing_ca_net_trans_amt( '300.50' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_read_steps[ 1 ]-output_trans_amt exp = CONV zreing_ca_calc_amt( '125.75' ) ).
  ENDMETHOD.


  " V001 (CC) - CB-05 (Delta v2): distinctive non-key and audit values.
  METHOD populate_full_line.
    CONSTANTS c_cm TYPE sysuuid_x16 VALUE '00000000000000000000000000000005'.
    IF cs_line-cm_h_id IS INITIAL.
      cs_line-cm_h_id = c_cm.
    ENDIF.
    cs_line-ct_id = 'UT-CB05'.
    cs_line-lifnr = '0000000002'.
    cs_line-bp_name = 'CB05 synthetic partner'.
    cs_line-bukrs_prest = 'EBA'.
    cs_line-matnr = 'UTCB05'.
    cs_line-cm_load_seq = '007'.
    cs_line-op_instance_num = '002'.
    cs_line-parent_op_type = 'F'.
    cs_line-origin_run_id = 'UT-CB05-ORIGIN'.
    cs_line-origin_line_num = '0000042'.
    cs_line-parent_net_amt = '82.50'.
    cs_line-parent_currency = 'GBP'.
    cs_line-defer_pct = '23.45'.
    cs_line-defer_cuota_num = '02'.
    cs_line-defer_cuota_total = '06'.
    cs_line-defer_from = '202609'.
    cs_line-defer_to = '202702'.
    cs_line-bukrs_recv = 'MUR'.
    cs_line-country = 'BR'.
    cs_line-base_amt = '250.50'.
    cs_line-share_pct = '40.00'.
    cs_line-share_pais_pct = '61.00'.
    cs_line-share_comb_pct = '24.40'.
    cs_line-calc_amt = '100.00'.
    cs_line-bruto_amt = '123.45'.
    cs_line-gross_up_amt = '3.45'.
    cs_line-tax_amt = '33.45'.
    cs_line-net_amt = '90.00'.
    cs_line-ct_currency = 'USD'.
    cs_line-net_local_amt = '87.65'.
    cs_line-local_currency = 'EUR'.
    cs_line-exch_rate = '0.18327'.
    cs_line-exch_rate_type = 'M'.
    cs_line-trans_currency = 'BRL'.
    cs_line-net_trans_amt = '478.23'.
    cs_line-exch_rate_1 = '1.23456'.
    cs_line-exch_rate_1_type = 'H'.
    cs_line-is_delta = 'X'.
    cs_line-delta_seq = '03'.
    cs_line-delta_base_amt = '57.89'.
    cs_line-sim_message = 'CB05 original message'.
    cs_line-proc_started_at = '20260930120000'.
    cs_line-proc_heartbeat_at = '20260930120001'.
    cs_line-proc_job_id = 'UT-CB05-JOB'.
    cs_line-insumo_check_at = '20260930120002'.
    cs_line-fi_awkey = '12345678902026'.
    cs_line-local_last_changed_at = '20260930120003'.
  ENDMETHOD.

  METHOD scope_keeps_full_identity.
    CONSTANTS c_ct TYPE sysuuid_x16 VALUE '00000000000000000000000000000001'.
    CONSTANTS c_mat TYPE sysuuid_x16 VALUE '00000000000000000000000000000002'.
    CONSTANTS c_op TYPE sysuuid_x16 VALUE '00000000000000000000000000000003'.
    CONSTANTS c_cm TYPE sysuuid_x16 VALUE '00000000000000000000000000000005'.
    CONSTANTS c_other_ct TYPE sysuuid_x16 VALUE '00000000000000000000000000000011'.
    CONSTANTS c_other_mat TYPE sysuuid_x16 VALUE '00000000000000000000000000000012'.
    CONSTANTS c_other_op TYPE sysuuid_x16 VALUE '00000000000000000000000000000014'.
    CONSTANTS c_other_cm TYPE sysuuid_x16 VALUE '00000000000000000000000000000015'.
    DATA lt_input TYPE zif_reing_ca_types=>ty_line_t.
    DATA ls_line TYPE zreing_ca_line_a.
    ls_line = VALUE #( calc_run_id = c_run line_num = c_line
      ct_uuid = c_ct mat_uuid = c_mat op_type = 'ANT' op_uuid = c_op
      cm_h_id = c_cm line_status = 'CALC' ).
    populate_full_line( CHANGING cs_line = ls_line ).
    APPEND ls_line TO lt_input.
    ls_line-calc_run_id = 'RUN-202609'.
    APPEND ls_line TO lt_input.
    ls_line = lt_input[ 1 ].
    ls_line-line_num = 11.
    ls_line-ct_uuid = c_other_ct.
    APPEND ls_line TO lt_input.
    ls_line = lt_input[ 1 ].
    ls_line-line_num = 12.
    ls_line-mat_uuid = c_other_mat.
    APPEND ls_line TO lt_input.
    ls_line = lt_input[ 1 ].
    ls_line-line_num = 13.
    ls_line-op_type = 'F'.
    APPEND ls_line TO lt_input.
    ls_line = lt_input[ 1 ].
    ls_line-line_num = 14.
    ls_line-op_uuid = c_other_op.
    APPEND ls_line TO lt_input.
    ls_line = lt_input[ 1 ].
    ls_line-line_num = 15.
    ls_line-cm_h_id = c_other_cm.
    APPEND ls_line TO lt_input.
    cl_abap_unit_assert=>assert_equals( act = lines( lt_input ) exp = 7 ).
    sql_env->insert_test_data( lt_input ).
    DATA lt_pc_input TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA lt_st_input TYPE zif_reing_ca_types=>ty_step_t.
    LOOP AT lt_input INTO ls_line.
      APPEND VALUE #( calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num
        pc_seq = 1 bruto_trans_amt = COND #( WHEN sy-tabix = 1 THEN '77.35' ELSE '99.00' ) ) TO lt_pc_input.
      APPEND VALUE #( calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num
        step_num = '04' seq = '01' step_category = zif_reing_ca_c=>step_category-tax
        output_trans_amt = COND #( WHEN sy-tabix = 1 THEN '83.40' ELSE '99.00' ) ) TO lt_st_input.
    ENDLOOP.
    sql_env->insert_test_data( lt_pc_input ).
    sql_env->insert_test_data( lt_st_input ).
    DATA lt_groups TYPE zreing_ca_tt_group_key.
    lt_groups = VALUE #( ( ct_uuid = c_ct mat_uuid = c_mat op_type = 'ANT' op_uuid = c_op cm_h_id = c_cm ) ).
    zcl_reing_ca_contab_runner=>prefetch_contab_data(
      EXPORTING it_run_rng = VALUE #( ( sign = 'I' option = 'EQ' low = c_run ) ) it_groups = lt_groups
      IMPORTING et_lines = DATA(lt_lines) et_line_pc = DATA(lt_pc) et_step = DATA(lt_steps) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 ).
    DATA(ls_expected) = lt_input[ 1 ].
    ls_expected-mandt = sy-mandt.
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ] exp = ls_expected ).
    ls_expected-line_status = 'SIM_OK'.
    ls_expected-sim_message =
      'SIMULATE OK: ningun paso del flujo resulto aplicable, no se genero documento (caso tipico: linea con saldo cero).'.
    engine_returns( VALUE #( has_error = abap_false ) ).
    TEST-INJECTION engine_process.
      cl_abap_unit_assert=>assert_equals( act = ls_line_call-calc_run_id exp = 'RUN-202608' ).
      cl_abap_unit_assert=>assert_equals( act = ls_line_call-line_num exp = '0000010' ).
      cl_abap_unit_assert=>assert_equals( act = ls_line_call-line_status exp = 'SIM_PROC' ).
      cl_abap_unit_assert=>assert_equals( act = ls_line_call-op_uuid
        exp = CONV sysuuid_x16( '00000000000000000000000000000003' ) ).
      cl_abap_unit_assert=>assert_equals( act = ls_line_call-cm_h_id
        exp = CONV sysuuid_x16( '00000000000000000000000000000005' ) ).
      cl_abap_unit_assert=>assert_equals( act = lines( lt_pc_line ) exp = 1 ).
      cl_abap_unit_assert=>assert_equals( act = lt_pc_line[ 1 ]-calc_run_id exp = 'RUN-202608' ).
      cl_abap_unit_assert=>assert_equals( act = lt_pc_line[ 1 ]-line_num exp = '0000010' ).
      cl_abap_unit_assert=>assert_equals( act = lt_pc_line[ 1 ]-bruto_trans_amt
        exp = CONV zreing_ca_bruto_trans_amt( '77.35' ) ).
      cl_abap_unit_assert=>assert_equals( act = lines( lt_st_line ) exp = 1 ).
      cl_abap_unit_assert=>assert_equals( act = lt_st_line[ 1 ]-calc_run_id exp = 'RUN-202608' ).
      cl_abap_unit_assert=>assert_equals( act = lt_st_line[ 1 ]-line_num exp = '0000010' ).
      cl_abap_unit_assert=>assert_equals( act = lt_st_line[ 1 ]-output_trans_amt
        exp = CONV zreing_ca_output_trans_amt( '83.40' ) ).
      zcl_reing_ca_contab_runner=>gv_engine_calls = zcl_reing_ca_contab_runner=>gv_engine_calls + 1.
      ls_result = zcl_reing_ca_contab_runner=>gs_engine_result.
    END-TEST-INJECTION.
    zcl_reing_ca_contab_runner=>run_contab_mode(
      EXPORTING iv_run_id = c_run it_groups = lt_groups iv_mode = 'C'
        it_lines_all = lt_lines it_pc_all = lt_pc it_step_all = lt_steps
      IMPORTING et_line_upd = DATA(lt_upd) et_posted_evt = DATA(lt_posted)
        et_reversed_evt = DATA(lt_reversed) ev_has_error = DATA(lv_error) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_reing_ca_contab_runner=>gv_engine_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_upd ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_upd[ 1 ] exp = ls_expected ).
    cl_abap_unit_assert=>assert_false( lv_error ).
    cl_abap_unit_assert=>assert_initial( lt_posted ).
    cl_abap_unit_assert=>assert_initial( lt_reversed ).
  ENDMETHOD.
ENDCLASS.
