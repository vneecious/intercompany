*"* use this source file for your ABAP unit test classes
*----------------------------------------------------------------------*
* MODIFY / DELTA-PATCH — ZBP_ReingCARun, include "test classes"
*----------------------------------------------------------------------*
* Change ID (CORREGIDO en iteracion #2 por OB-001): el objeto NO tiene
* cabecera de cambios en ningun include y su serie de marcadores in-line
* REAL llega hasta V015 (17.07.2026) -> el marcador de este delta es
* V016 (05.08.2026 | EXT_GONZALCA), el mismo que el resto del objeto.
* La premisa de la iteracion #1 ("se reutiliza V001 por mismo Transport y
* Reference que la cabecera vigente") era FALSA: esa cabecera no existe.
*
* Este archivo NO es un objeto TADIR propio: representa el include de
* clases de test locales del CLAS ZBP_ReingCARun (misma convencion ya
* usada en F3.1 / F2). Se entrega COMPLETO porque el include de tests del
* objeto vivo esta vacio (F3.1 dejo ltcl_initialize_period alli; si el
* include real ya contiene esa clase, este bloque se AGREGA al final, no
* la reemplaza).
*
* ABAP Unit de las 3 actions nuevas (V-04 / DD-F4-7).
*
* Punto de inyeccion (REESCRITO en iteracion #2 por OB-003): TEST-SEAM
* "engine_process" dentro de run_contab_mode (DD-F4-7 opcion b). El
* parametro io_engine de la iteracion #1 se elimino: en el servidor real
* ZCL_REING_CONTAB_ENGINE es "DEFINITION PUBLIC FINAL CREATE PUBLIC", y
* cl_abap_testdouble=>create( ) genera una SUBCLASE en runtime -> imposible
* sobre una clase FINAL (process_line tampoco es redefinible). Los 6 tests
* que dependian de ese doble no compilaban. TEST-SEAM / TEST-INJECTION es
* el mecanismo estandar para sustituir una dependencia FINAL sin tocar su
* contrato publico ni la firma productiva del consumidor.
*
* Se prueba run_contab_mode -- NO los metodos FOR MODIFY: la firma de un
* handler RAP esta atada al framework y no es invocable directamente. Por
* eso run_contab_mode se diseno PURO respecto del BDEF (DD-F4-4), lo que
* permite ejercitar el 95% de la logica de las 3 actions sin construir
* payloads RAP.
*
* Dobles usados:
*   - CL_OSQL_TEST_ENVIRONMENT para LINE_A / LPC_A / STEP_A / LOG_A.
*     [ACTUALIZADO V016 fix BUG-002] run_contab_mode ya NO lee la base: las 3
*     lecturas masivas viven en prefetch_contab_data (invocado una sola vez por
*     accion, antes del LOOP AT keys) y el guard de concurrencia se resuelve en
*     memoria. Los dobles OSQL siguen haciendo falta porque el test invoca
*     prefetch_contab_data (helper given_prefetch) para armar las 3 tablas.
*   - TEST-INJECTION del seam "engine_process" para el Engine (ya NO se usa
*     CL_ABAP_TESTDOUBLE: la clase es FINAL).
*
* [ACTUALIZADO tras 2do fix de activacion real: "DEFINITION LOAD" es
* obsoleta, esta version de ABAP la rechaza -- no se puede usar para
* resolver la referencia hacia adelante que el TEST-INJECTION necesitaria
* si el estado del doble viviera aca.] El estado del doble
* (gs_engine_result / gv_*) vive en LCL_REING_CA_DML_BUFFER (include
* "implementations", PATCH 1), NO en esta clase de test: esa clase ya esta
* completamente definida cuando el TEST-INJECTION se compila (en el
* contexto de run_contab_mode, dentro de "implementations"), asi que no hay
* referencia hacia adelante que resolver. La friend declaration del PATCH 2
* sigue haciendo falta para la direccion opuesta: que esta clase de test
* pueda invocar los CLASS-METHODS PRIVATE de lhc_zi_reingcarun
* (run_contab_mode / allowed_source_status) -- esa direccion no tiene el
* problema de referencia hacia adelante, DEFERRED FOR TESTING (sin LOAD)
* alcanza.
*
* Las aserciones van contra lcl_reing_ca_dml_buffer (gt_line_f4,
* gt_posted_evt, gt_reversed_evt, gt_log): run_contab_mode NUNCA escribe a
* la base -- todo pasa por el buffer y se vuelca en save_modified.
*----------------------------------------------------------------------*

" Begin Insert V016 (CC) - F4 (05.08.2026 | EXT_GONZALCA)
CLASS ltcl_contab_actions DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PUBLIC SECTION.
    " Begin Mod V016 (CC) - F4 [fix post-Eclipse, 2do intento: "DEFINITION
    " LOAD" es obsoleta, esta version de ABAP la rechaza. El estado del
    " doble del Engine se mudo a LCL_REING_CA_DML_BUFFER (PATCH 1, include
    " "implementations"), que ya esta definida antes de este punto -- sin
    " eso, el TEST-INJECTION (compilado en el contexto de run_contab_mode)
    " no puede ver componentes de una clase que recien se define aqui.]
    " CLASS-DATA gs_engine_result TYPE zif_reing_contab_types=>ty_process_result.
    " CLASS-DATA gv_engine_raise  TYPE abap_bool.
    " CLASS-DATA gv_engine_text   TYPE string.
    " CLASS-DATA gv_engine_calls  TYPE i.
    " End Mod V016 (CC) - F4

  PRIVATE SECTION.
    CONSTANTS c_run  TYPE zreing_ca_run_a-calc_run_id VALUE 'RUN-202608'.
    CONSTANTS c_line TYPE zreing_ca_line_a-line_num   VALUE '0000010'.

    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.

    " Begin Mod V016 (CC) - F4 [fix post-Eclipse: "Instances of the abstract
    " class LHC_ZI_REINGCARUN cannot be generated" -- RAP no permite
    " "NEW lhc_zi_reingcarun( )" fuera del framework. run_contab_mode /
    " get_fi_poster / allowed_source_status pasaron a CLASS-METHODS (ver
    " ZBP_ReingCARun.abap PATCH 3): se invocan por referencia de clase,
    " sin instancia -- mo_cut ya no hace falta.]
    " DATA mo_cut TYPE REF TO lhc_zi_reingcarun.
    " End Mod V016 (CC) - F4

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
    METHODS storno_error_stays_in_cont    FOR TESTING RAISING cx_static_check.
    " CU-3 / BR-F4-06 (exito de Storno -> LIBD + evento Reversed)
    METHODS storno_ok_goes_to_libd        FOR TESTING RAISING cx_static_check.
    " CU-8 / CLAR-03 (estado de origen no admitido: no se llama al Engine)
    METHODS post_from_calc_is_rejected    FOR TESTING RAISING cx_static_check.
    " CLAR-03 / SUP-01..03 (matriz de estados de origen)
    METHODS allowed_source_matrix         FOR TESTING RAISING cx_static_check.

    " --- helpers de test ------------------------------------------------
    METHODS given_line
      IMPORTING iv_status  TYPE zreing_ca_line_status
                iv_op_type TYPE zreing_ca_line_a-op_type DEFAULT 'ANT'.
    METHODS given_scope
      RETURNING VALUE(rt_groups) TYPE zreing_ca_tt_group_key.
    " Begin Insert V016 (CC) - F4 [fix BUG-002: run_contab_mode ya no lee la
    " base -- las 3 lecturas masivas se hoistearon a prefetch_contab_data, que
    " las actions invocan UNA sola vez antes del LOOP AT keys. El test hace lo
    " mismo: pre-lee contra los dobles OSQL y le pasa las 3 tablas al CUT.]
    METHODS given_prefetch
      EXPORTING et_lines   TYPE zif_reing_ca_types=>ty_line_t
                et_line_pc TYPE zif_reing_ca_types=>ty_line_pc_t
                et_step    TYPE zif_reing_ca_types=>ty_step_t.
    " End Insert V016 (CC) - F4
    " Configuran el comportamiento que el TEST-INJECTION reproduce.
    METHODS engine_returns
      IMPORTING is_result TYPE zif_reing_contab_types=>ty_process_result.
    METHODS engine_raises
      IMPORTING iv_text   TYPE string.

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
    " mo_cut = NEW lhc_zi_reingcarun( ). -- ya no aplica, ver Mod V016 arriba.
    " Los buffers son CLASS-DATA: hay que dejarlos limpios en CADA test,
    " si no un test ve los eventos del anterior (la misma regresion que el
    " CLEAR de save_modified previene en produccion, CU-11).
    CLEAR: lcl_reing_ca_dml_buffer=>gt_line_f4,
           lcl_reing_ca_dml_buffer=>gt_posted_evt,
           lcl_reing_ca_dml_buffer=>gt_reversed_evt,
           lcl_reing_ca_dml_buffer=>gt_log,
           lcl_reing_ca_dml_buffer=>gt_line_status.
    " Estado del doble del Engine: tambien es CLASS-DATA.
    CLEAR: lcl_reing_ca_dml_buffer=>gs_engine_result, lcl_reing_ca_dml_buffer=>gv_engine_raise,
           lcl_reing_ca_dml_buffer=>gv_engine_text, lcl_reing_ca_dml_buffer=>gv_engine_calls.
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
                         bukrs_recv  = '1000'
                         line_status = iv_status ) ).
    sql_env->insert_test_data( lt_line ).
  ENDMETHOD.

  METHOD given_scope.
    rt_groups = VALUE #( ( ct_uuid  = '00000000000000000000000000000001'
                           mat_uuid = '00000000000000000000000000000002'
                           op_type  = 'ANT'
                           op_uuid  = '00000000000000000000000000000003' ) ).
  ENDMETHOD.

  " Begin Insert V016 (CC) - F4 [fix BUG-002]
  METHOD given_prefetch.
    lhc_zi_reingcarun=>prefetch_contab_data(
      EXPORTING it_run_rng = VALUE #( ( sign = 'I' option = 'EQ' low = c_run ) )
                it_groups  = given_scope( )
      IMPORTING et_lines   = et_lines
                et_line_pc = et_line_pc
                et_step    = et_step ).
  ENDMETHOD.
  " End Insert V016 (CC) - F4

  METHOD engine_returns.
    lcl_reing_ca_dml_buffer=>gs_engine_result = is_result.
    lcl_reing_ca_dml_buffer=>gv_engine_raise  = abap_false.
  ENDMETHOD.

  METHOD engine_raises.
    " El mensaje del Engine se propaga TAL CUAL a sim_message / LOG_A: CA no
    " lo reinterpreta (por eso el texto del guard AUTO_REVERSAL se asevera
    " sobre lo que viaja en la excepcion, no sobre un texto propio de CA).
    CLEAR lcl_reing_ca_dml_buffer=>gs_engine_result.
    lcl_reing_ca_dml_buffer=>gv_engine_raise = abap_true.
    lcl_reing_ca_dml_buffer=>gv_engine_text  = iv_text.
  ENDMETHOD.

  METHOD post_ok_fires_posted_event.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " El caso se MOVIO a ltcl_contab_actions de ZCL_REING_CA_CONTAB_RUNNER,
    " junto con el nucleo y su TEST-SEAM "engine_process": un TEST-INJECTION
    " solo se asocia a su seam dentro del MISMO pool de clases, asi que no
    " puede quedarse aca. El cuerpo vive alli sin cambios de logica.
    " El metodo se conserva vacio y marcado como skipped -- borrarlo obligaria
    " a reescribir la DEFINITION de esta clase local, que se hace en el include
    " completo, y no hay ninguna ganancia en eso.
    cl_abap_unit_assert=>skip(
      msg = 'Movido a ZCL_REING_CA_CONTAB_RUNNER (V023)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD post_partial_error_no_event.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " Movido a ltcl_contab_actions de ZCL_REING_CA_CONTAB_RUNNER -- ver la
    " nota en post_ok_fires_posted_event.
    cl_abap_unit_assert=>skip(
      msg = 'Movido a ZCL_REING_CA_CONTAB_RUNNER (V023)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD storno_auto_reversal_rejected.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " Movido a ltcl_contab_actions de ZCL_REING_CA_CONTAB_RUNNER -- ver la
    " nota en post_ok_fires_posted_event.
    cl_abap_unit_assert=>skip(
      msg = 'Movido a ZCL_REING_CA_CONTAB_RUNNER (V023)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD storno_error_stays_in_cont.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " Movido a ltcl_contab_actions de ZCL_REING_CA_CONTAB_RUNNER -- ver la
    " nota en post_ok_fires_posted_event.
    cl_abap_unit_assert=>skip(
      msg = 'Movido a ZCL_REING_CA_CONTAB_RUNNER (V023)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD storno_ok_goes_to_libd.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " Movido a ltcl_contab_actions de ZCL_REING_CA_CONTAB_RUNNER -- ver la
    " nota en post_ok_fires_posted_event.
    cl_abap_unit_assert=>skip(
      msg = 'Movido a ZCL_REING_CA_CONTAB_RUNNER (V023)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD post_from_calc_is_rejected.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " Movido a ltcl_contab_actions de ZCL_REING_CA_CONTAB_RUNNER -- ver la
    " nota en post_ok_fires_posted_event.
    cl_abap_unit_assert=>skip(
      msg = 'Movido a ZCL_REING_CA_CONTAB_RUNNER (V023)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD allowed_source_matrix.
    " Begin Mod V023 (14.09.2026 | EXT_GONZALCA)
    " La matriz se asevera ahora en ZCL_REING_CA_CONTAB_RUNNER, que es donde
    " vive la implementacion. Lo que se conserva AQUI es lo unico que el test
    " del runner no puede cubrir: que la cadena de delegacion del pool
    " (lhc_zi_reingcarun -> lcl_reing_ca_dml_buffer -> runner) devuelva
    " exactamente lo mismo. Si alguien reintroduce una copia de la matriz en
    " el pool, este test lo detecta.
    DATA(lt_c_pool) = lhc_zi_reingcarun=>allowed_source_status(
                        zif_reing_ca_c=>contab_mode-check ).
    DATA(lt_c_run)  = zcl_reing_ca_contab_runner=>allowed_source_status(
                        zif_reing_ca_c=>contab_mode-check ).
    cl_abap_unit_assert=>assert_equals( act = lt_c_pool exp = lt_c_run
      msg = 'El delegador del pool debe devolver la matriz del runner (modo C)' ).

    DATA(lt_p_pool) = lhc_zi_reingcarun=>allowed_source_status(
                        zif_reing_ca_c=>contab_mode-post ).
    DATA(lt_p_run)  = zcl_reing_ca_contab_runner=>allowed_source_status(
                        zif_reing_ca_c=>contab_mode-post ).
    cl_abap_unit_assert=>assert_equals( act = lt_p_pool exp = lt_p_run
      msg = 'El delegador del pool debe devolver la matriz del runner (modo P)' ).

    DATA(lt_s_pool) = lhc_zi_reingcarun=>allowed_source_status(
                        zif_reing_ca_c=>contab_mode-storno ).
    DATA(lt_s_run)  = zcl_reing_ca_contab_runner=>allowed_source_status(
                        zif_reing_ca_c=>contab_mode-storno ).
    cl_abap_unit_assert=>assert_equals( act = lt_s_pool exp = lt_s_run
      msg = 'El delegador del pool debe devolver la matriz del runner (modo S)' ).
    " End Mod V023 (14.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

ENDCLASS.
" End Insert V016 (CC) - F4

"Begin Insert V017 (CC)
" ABAP Unit for the per-RUN isolation that V017 fixes (BUG-001 del
" qa-test-designer). Targets the pure/testable helpers extracted above, NOT
" the RAP handlers directly -- that is exactly what the testability refactor
" buys. Doubles: cl_osql_test_environment over LINE_A/STEP_A/LPC_A/LOG_A
" (same mechanism as ltcl_contab_actions).
CLASS ltcl_run_isolation DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS c_run_a TYPE zreing_ca_line_a-calc_run_id VALUE 'RUN-A01'.
    CONSTANTS c_run_b TYPE zreing_ca_line_a-calc_run_id VALUE 'RUN-B01'.
    CONSTANTS c_line  TYPE zreing_ca_line_a-line_num    VALUE '0000001'.
    " Distinguishable per-RUN value to detect cross-contamination.
    CONSTANTS c_mat_a TYPE zreing_ca_line_a-mat_uuid
      VALUE '0000000000000000000000000000000A'.
    CONSTANTS c_mat_b TYPE zreing_ca_line_a-mat_uuid
      VALUE '0000000000000000000000000000000B'.

    CLASS-DATA sql_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS teardown.

    " CU-1/CU-2: flatten + orphan delete scoped to RUN-A01 only.
    METHODS calc_and_delete_isolate_runs FOR TESTING RAISING cx_static_check.
    " CU-3: status update (release CALC->LIBD) scoped to RUN-A01 only.
    METHODS release_isolates_runs             FOR TESTING RAISING cx_static_check.
    " CU-4: LOG_NUM recompute independent per RUN (both go 3 -> 4).
    METHODS log_num_recalc_indep_per_run FOR TESTING RAISING cx_static_check.

    " --- helpers de test ------------------------------------------------
    METHODS seed_line
      IMPORTING iv_run    TYPE zreing_ca_line_a-calc_run_id
                iv_mat    TYPE zreing_ca_line_a-mat_uuid
                iv_status TYPE zreing_ca_line_a-line_status
                            DEFAULT zif_reing_ca_c=>line_status-calc.
    METHODS seed_step_lpc
      IMPORTING iv_run TYPE zreing_ca_line_a-calc_run_id.
    METHODS seed_log
      IMPORTING iv_run     TYPE zreing_ca_log_a-calc_run_id
                iv_log_num TYPE zreing_ca_log_a-log_num.
ENDCLASS.

CLASS ltcl_run_isolation IMPLEMENTATION.

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

  METHOD teardown.
    sql_env->clear_doubles( ).
    " Buffers are CLASS-DATA of lcl_reing_ca_dml_buffer: leave them clean so
    " one test never sees another's rows (same discipline as ltcl_contab_actions).
    CLEAR: lcl_reing_ca_dml_buffer=>gt_log,
           lcl_reing_ca_dml_buffer=>gt_line_del,
           lcl_reing_ca_dml_buffer=>gt_line_status.
  ENDMETHOD.

  METHOD seed_line.
    DATA lt_line TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    lt_line = VALUE #( ( calc_run_id = iv_run
                         line_num    = c_line
                         mat_uuid    = iv_mat
                         line_status = iv_status ) ).
    sql_env->insert_test_data( lt_line ).
  ENDMETHOD.

  METHOD seed_step_lpc.
    DATA lt_step TYPE STANDARD TABLE OF zreing_ca_step_a WITH EMPTY KEY.
    lt_step = VALUE #( ( calc_run_id = iv_run line_num = c_line ) ).
    sql_env->insert_test_data( lt_step ).
    DATA lt_lpc TYPE STANDARD TABLE OF zreing_ca_lpc_a WITH EMPTY KEY.
    lt_lpc = VALUE #( ( calc_run_id = iv_run line_num = c_line ) ).
    sql_env->insert_test_data( lt_lpc ).
  ENDMETHOD.

  METHOD seed_log.
    DATA lt_log TYPE STANDARD TABLE OF zreing_ca_log_a WITH EMPTY KEY.
    lt_log = VALUE #( ( calc_run_id = iv_run
                        line_num    = c_line
                        log_num     = iv_log_num ) ).
    sql_env->insert_test_data( lt_log ).
  ENDMETHOD.

  METHOD calc_and_delete_isolate_runs.
    " CU-1/CU-2: two RUNs share LINE_NUM=1. Flatten RUN-A01's bulk, then delete
    " orphans for RUN-A01 ONLY. RUN-B01 must survive untouched.
    seed_line( iv_run = c_run_a iv_mat = c_mat_a ).
    seed_line( iv_run = c_run_b iv_mat = c_mat_b ).
    seed_step_lpc( c_run_a ).
    seed_step_lpc( c_run_b ).

    " --- flatten: a calculate/delete-shaped bulk row for RUN-A01 only. ---
    TYPES: BEGIN OF ty_num_rng,
             sign   TYPE c LENGTH 1,
             option TYPE c LENGTH 2,
             low    TYPE zreing_ca_line_a-line_num,
             high   TYPE zreing_ca_line_a-line_num,
           END OF ty_num_rng,
           tt_num_rng TYPE STANDARD TABLE OF ty_num_rng WITH EMPTY KEY,
           BEGIN OF ty_bulk,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_nums   TYPE tt_num_rng,
           END OF ty_bulk,
           tt_bulk TYPE STANDARD TABLE OF ty_bulk WITH EMPTY KEY.
    DATA(lt_bulk) = VALUE tt_bulk(
      ( calc_run_id = c_run_a
        line_nums   = VALUE #( ( sign = 'I' option = 'EQ' low = c_line ) ) ) ).

    DATA(lt_pairs) = lcl_reing_ca_dml_buffer=>flatten_run_line_nums( lt_bulk ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_pairs ) exp = 1
      msg = 'flatten debe producir 1 par (calc_run_id, line_num)' ).
    cl_abap_unit_assert=>assert_equals( act = lt_pairs[ 1 ]-calc_run_id exp = c_run_a
      msg = 'flatten debe conservar el calc_run_id' ).
    cl_abap_unit_assert=>assert_equals( act = lt_pairs[ 1 ]-line_num exp = c_line ).

    " --- delete orphans for RUN-A01 only. ---
    lcl_reing_ca_dml_buffer=>isolate_and_delete_orphans( lt_pairs ).

    " ATC fix: WHERE explicito acotado a los 2 RUNs del test (el doble solo
    " contiene esas filas; sin este WHERE el check "sin condicion WHERE"
    " lo marcaba, aunque el resultado era el mismo).
    SELECT * FROM zreing_ca_line_a
      WHERE calc_run_id = @c_run_a OR calc_run_id = @c_run_b
      INTO TABLE @DATA(lt_line_after).
    SELECT * FROM zreing_ca_step_a
      WHERE calc_run_id = @c_run_a OR calc_run_id = @c_run_b
      INTO TABLE @DATA(lt_step_after).
    SELECT * FROM zreing_ca_lpc_a
      WHERE calc_run_id = @c_run_a OR calc_run_id = @c_run_b
      INTO TABLE @DATA(lt_lpc_after).

    " RUN-A01 rows gone; RUN-B01 rows survive with their original mat_uuid.
    cl_abap_unit_assert=>assert_equals( act = lines( lt_line_after ) exp = 1
      msg = 'CU-1: solo RUN-B01 debe permanecer en LINE_A' ).
    cl_abap_unit_assert=>assert_equals( act = lt_line_after[ 1 ]-calc_run_id exp = c_run_b
      msg = 'CU-1: el borrado no debe tocar el otro RUN' ).
    cl_abap_unit_assert=>assert_equals( act = lt_line_after[ 1 ]-mat_uuid exp = c_mat_b
      msg = 'CU-2: RUN-B01 conserva su MAT_UUID (sin cross-contamination)' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_step_after ) exp = 1
      msg = 'CU-1: solo RUN-B01 debe permanecer en STEP_A' ).
    cl_abap_unit_assert=>assert_equals( act = lt_step_after[ 1 ]-calc_run_id exp = c_run_b ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_lpc_after ) exp = 1
      msg = 'CU-1: solo RUN-B01 debe permanecer en LPC_A' ).
    cl_abap_unit_assert=>assert_equals( act = lt_lpc_after[ 1 ]-calc_run_id exp = c_run_b ).
  ENDMETHOD.

  METHOD release_isolates_runs.
    " CU-3: both RUNs at LINE_NUM=1 / CALC. Release RUN-A01 (CALC->LIBD) only.
    seed_line( iv_run = c_run_a iv_mat = c_mat_a iv_status = zif_reing_ca_c=>line_status-calc ).
    seed_line( iv_run = c_run_b iv_mat = c_mat_b iv_status = zif_reing_ca_c=>line_status-calc ).

    DATA(lt_upd) = VALUE lcl_reing_ca_dml_buffer=>tt_line_status_upd(
      ( calc_run_id = c_run_a line_num = c_line
        line_status = zif_reing_ca_c=>line_status-libd ) ).
    lcl_reing_ca_dml_buffer=>isolate_and_update_status( lt_upd ).

    " ATC fix: WHERE explicito acotado a los 2 RUNs del test (mismo motivo
    " que en calc_and_delete_isolate_runs).
    SELECT calc_run_id, line_status FROM zreing_ca_line_a
      WHERE calc_run_id = @c_run_a OR calc_run_id = @c_run_b
      ORDER BY calc_run_id
      INTO TABLE @DATA(lt_after).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_after ) exp = 2 ).
    " RUN-A01 -> LIBD.
    READ TABLE lt_after INTO DATA(ls_a) WITH KEY calc_run_id = c_run_a.
    cl_abap_unit_assert=>assert_equals( act = ls_a-line_status
      exp = zif_reing_ca_c=>line_status-libd
      msg = 'CU-3: RUN-A01 debe pasar a LIBD' ).
    " RUN-B01 stays CALC.
    READ TABLE lt_after INTO DATA(ls_b) WITH KEY calc_run_id = c_run_b.
    cl_abap_unit_assert=>assert_equals( act = ls_b-line_status
      exp = zif_reing_ca_c=>line_status-calc
      msg = 'CU-3: RUN-B01 debe permanecer en CALC (aislamiento por RUN)' ).
  ENDMETHOD.

  METHOD log_num_recalc_indep_per_run.
    " CU-4: both RUNs have a persisted LOG_A row LOG_NUM=3 for LINE_NUM=1. A
    " new buffered log entry per RUN (placeholder log_num=0) must be renumbered
    " to 4 for EACH run independently (no cross-RUN jump, no PK collision).
    seed_log( iv_run = c_run_a iv_log_num = 3 ).
    seed_log( iv_run = c_run_b iv_log_num = 3 ).

    " gt_log carries one NEW entry per RUN (as calculate/release/delete would
    " have appended, with log_num placeholder 0).
    lcl_reing_ca_dml_buffer=>gt_log = VALUE #(
      ( calc_run_id = c_run_a line_num = c_line log_num = 0 )
      ( calc_run_id = c_run_b line_num = c_line log_num = 0 ) ).

    lcl_reing_ca_dml_buffer=>recalc_log_num_per_run(
      CHANGING ct_log = lcl_reing_ca_dml_buffer=>gt_log ).

    READ TABLE lcl_reing_ca_dml_buffer=>gt_log INTO DATA(ls_a)
      WITH KEY calc_run_id = c_run_a.
    cl_abap_unit_assert=>assert_equals( act = ls_a-log_num exp = 4
      msg = 'CU-4: RUN-A01 debe obtener LOG_NUM=4 (MAX 3 +1)' ).
    READ TABLE lcl_reing_ca_dml_buffer=>gt_log INTO DATA(ls_b)
      WITH KEY calc_run_id = c_run_b.
    cl_abap_unit_assert=>assert_equals( act = ls_b-log_num exp = 4
      msg = 'CU-4: RUN-B01 debe obtener LOG_NUM=4 independiente (sin salto por cross-RUN)' ).
  ENDMETHOD.

ENDCLASS.
"End Insert V017 (CC)
" V001 (CC) - GAP-001 (Delta v2): pure routing; no EML, FI or live enqueue.
CLASS ltcl_gap001_runs DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS initial_run FOR TESTING.
    METHODS active_run_is_reused FOR TESTING.
    METHODS canceled_needs_new_run FOR TESTING.
    METHODS corrected_cm_needs_new_run FOR TESTING.
    METHODS ambiguous_active_is_rejected FOR TESTING.
    METHODS anul_err_blocks_calculate FOR TESTING.

    " V001 (CC) - #115 (Delta v2): execution-side lifecycle regression.
    METHODS posted_load_rejects_calculate FOR TESTING.
    METHODS released_load_rejects_calc FOR TESTING.
    METHODS post_error_rejects_calculate FOR TESTING.
    METHODS mixed_posted_rejects_calc FOR TESTING.
    METHODS simok_keeps_recalculate FOR TESTING.
    METHODS pend_keeps_calculate FOR TESTING.
    METHODS pre_release_errors_preserved FOR TESTING.
    METHODS posted_base_new_delta_allowed FOR TESTING.
    METHODS posted_delta_rejects_own_load FOR TESTING.

    METHODS sequence_fits_char20 FOR TESTING.
    METHODS sequence_exhaustion FOR TESTING.
ENDCLASS.
CLASS ltcl_gap001_runs IMPLEMENTATION.
  METHOD initial_run.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02' it_lines = VALUE #( ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_choice-calc_run_id exp = 'RUN-202602' ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.
  METHOD active_run_is_reused.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602-000000002' line_status = 'CALC' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_choice-calc_run_id exp = 'RUN-202602-000000002' ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.
  METHOD canceled_needs_new_run.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'ANULD' ) ) ).
    cl_abap_unit_assert=>assert_true( ls_choice-fresh ).
    cl_abap_unit_assert=>assert_initial( ls_choice-calc_run_id ).
  ENDMETHOD.
  METHOD corrected_cm_needs_new_run.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( cm_h_id = '11111111111111111111111111111111' )
      iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'ANULD'
        cm_h_id = '22222222222222222222222222222222' ) ) ).
    cl_abap_unit_assert=>assert_true( ls_choice-fresh ).
  ENDMETHOD.
  METHOD ambiguous_active_is_rejected.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'CALC' )
        ( calc_run_id = 'RUN-202602-000000001' line_status = 'CALC' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
  ENDMETHOD.
  METHOD anul_err_blocks_calculate.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'ANUL_ERR' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
  ENDMETHOD.
  METHOD posted_load_rejects_calculate.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'CONT' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD released_load_rejects_calc.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'LIBD' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD post_error_rejects_calculate.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'POST_ERR' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD mixed_posted_rejects_calc.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'CALC' )
        ( calc_run_id = 'RUN-202602' line_status = 'CONT' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD simok_keeps_recalculate.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'SIM_OK' ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD pend_keeps_calculate.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'PEND' ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD pre_release_errors_preserved.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'CALC_ERR' )
        ( calc_run_id = 'RUN-202602' line_status = 'SIM_ERR' ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD posted_base_new_delta_allowed.
    CONSTANTS c_base_cm TYPE sysuuid_x16 VALUE '44444444444444444444444444444444'.
    CONSTANTS c_delta_cm TYPE sysuuid_x16 VALUE '66666666666666666666666666666666'.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( cm_h_id = c_delta_cm ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'CONT' cm_h_id = c_base_cm ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
    cl_abap_unit_assert=>assert_equals( act = ls_choice-calc_run_id exp = 'RUN-202602' ).
  ENDMETHOD.

  METHOD posted_delta_rejects_own_load.
    CONSTANTS c_delta_cm TYPE sysuuid_x16 VALUE '66666666666666666666666666666666'.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>choose_calc_run(
      is_group = VALUE #( cm_h_id = c_delta_cm ) iv_year = '2026' iv_period = '02'
      it_lines = VALUE #( ( calc_run_id = 'RUN-202602' line_status = 'CONT'
        cm_h_id = c_delta_cm is_delta = abap_true delta_seq = '01' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_false( ls_choice-fresh ).
  ENDMETHOD.

  METHOD sequence_fits_char20.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>next_calc_run(
      iv_year = '2026' iv_period = '02'
      it_runs = VALUE #( ( calc_run_id = 'RUN-202602' fiscal_year = '2026' fiscal_period = '02' )
        ( calc_run_id = 'RUN-202602-000000004' fiscal_year = '2026' fiscal_period = '02' )
        ( calc_run_id = 'RUN-202603-000000009' fiscal_year = '2026' fiscal_period = '03' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_choice-calc_run_id exp = 'RUN-202602-000000005' ).
    cl_abap_unit_assert=>assert_equals( act = strlen( ls_choice-calc_run_id ) exp = 20 ).
  ENDMETHOD.
  METHOD sequence_exhaustion.
    DATA(ls_choice) = lcl_reing_ca_dml_buffer=>next_calc_run(
      iv_year = '2026' iv_period = '02'
      it_runs = VALUE #( ( calc_run_id = 'RUN-202602-999999999' fiscal_year = '2026' fiscal_period = '02' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_choice-message ).
    cl_abap_unit_assert=>assert_initial( ls_choice-calc_run_id ).
  ENDMETHOD.
ENDCLASS.
" V001 (CC) - #119 (Delta v2): harmless tests without business data or SQL.
CLASS ltcl_ca_filtered_export DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS empty_filter FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS boolean_tree FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS numeric_range FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS literal_text FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS invalid_tree FOR TESTING.
    METHODS invalid_value FOR TESTING.
    METHODS safe_prefilter FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS tax_pivot FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS negative_residual FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS currency_precision FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS same_line_two_runs FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS missing_apertura FOR TESTING.
    METHODS zero_bruto FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS numeric_columns FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS fixture
      IMPORTING iv_negative TYPE abap_bool DEFAULT abap_false iv_decimals TYPE i DEFAULT 2
      RETURNING VALUE(rt_rows) TYPE zcl_reing_ca_xls_hdl=>ty_rows
      RAISING zcx_reing_ca_calc_error.
ENDCLASS.

CLASS ltcl_ca_filtered_export IMPLEMENTATION.
  METHOD empty_filter.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    lo_filter->prepare( iv_version = '01' it_nodes = VALUE #( ) ).
    cl_abap_unit_assert=>assert_true( lo_filter->matches( VALUE #( ) ) ).
  ENDMETHOD.

  METHOD boolean_tree.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
      ( node_id = 1 node_kind = 'AND' )
      ( node_id = 2 parent_id = 1 node_kind = 'OR' )
      ( node_id = 3 parent_id = 2 node_kind = 'CMP' field_name = 'CtId' operator = 'EQ' low = 'IC-0020' )
      ( node_id = 4 parent_id = 2 node_kind = 'CMP' field_name = 'CtId' operator = 'EQ' low = 'IC-0019' )
      ( node_id = 5 parent_id = 1 node_kind = 'NOT' )
      ( node_id = 6 parent_id = 5 node_kind = 'CMP' field_name = 'LineStatus' operator = 'EQ' low = 'CONT' ) ) ).
    cl_abap_unit_assert=>assert_true( lo_filter->matches( VALUE #( CtId = 'IC-0020' LineStatus = 'CALC' ) ) ).
    cl_abap_unit_assert=>assert_false( lo_filter->matches( VALUE #( CtId = 'IC-0019' LineStatus = 'CONT' ) ) ).
    cl_abap_unit_assert=>assert_false( lo_filter->matches( VALUE #( CtId = 'IC-0018' LineStatus = 'CALC' ) ) ).
  ENDMETHOD.

  METHOD numeric_range.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
      ( node_id = 1 node_kind = 'CMP' field_name = 'NetAmt' operator = 'BT' low = '2.00' high = '10.50' ) ) ).
    cl_abap_unit_assert=>assert_true( lo_filter->matches( VALUE #( NetAmt = '10.50' ) ) ).
    cl_abap_unit_assert=>assert_false( lo_filter->matches( VALUE #( NetAmt = '11.00' ) ) ).
    cl_abap_unit_assert=>assert_false( lo_filter->matches( VALUE #( NetAmt = '1.99' ) ) ).
  ENDMETHOD.

  METHOD literal_text.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
      ( node_id = 1 node_kind = 'CMP' field_name = 'HeaderTitle' operator = 'CONTAINS' low = '*' ) ) ).
    cl_abap_unit_assert=>assert_false( lo_filter->matches( VALUE #( HeaderTitle = 'FUT TRACKER 90' ) ) ).
    cl_abap_unit_assert=>assert_true( lo_filter->matches( VALUE #( HeaderTitle = 'FUT*90' ) ) ).
  ENDMETHOD.

  METHOD invalid_tree.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    TRY.
        lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
          ( node_id = 1 node_kind = 'CMP' field_name = 'CtId' operator = 'EQ' )
          ( node_id = 2 parent_id = 3 node_kind = 'NOT' )
          ( node_id = 3 parent_id = 2 node_kind = 'NOT' ) ) ).
        cl_abap_unit_assert=>fail( 'A cycle was accepted' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
    TRY.
        lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
          ( node_id = 1 node_kind = 'CMP' field_name = '_Line/NetAmt' operator = 'EQ' low = '1' ) ) ).
        cl_abap_unit_assert=>fail( 'An unsupported navigation filter was ignored' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD invalid_value.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    TRY.
        lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
          ( node_id = 1 node_kind = 'CMP' field_name = 'NetAmt' operator = 'EQ' low = '2.001' ) ) ).
        cl_abap_unit_assert=>fail( 'Loss of decimal precision was accepted' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
    TRY.
        lo_filter->prepare( iv_version = '02' it_nodes = VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'An unsupported version was accepted' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD safe_prefilter.
    DATA(lo_filter) = NEW lcl_ca_export_filter( ).
    lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
      ( node_id = 1 node_kind = 'OR' )
      ( node_id = 2 parent_id = 1 node_kind = 'CMP' field_name = 'PeriodYear' operator = 'EQ' low = '2026' )
      ( node_id = 3 parent_id = 1 node_kind = 'CMP' field_name = 'PeriodYear' operator = 'EQ' low = '2025' ) ) ).
    cl_abap_unit_assert=>assert_initial( lo_filter->mt_year ).
    lo_filter->prepare( iv_version = '01' it_nodes = VALUE #(
      ( node_id = 1 node_kind = 'AND' )
      ( node_id = 2 parent_id = 1 node_kind = 'CMP' field_name = 'PeriodYear' operator = 'EQ' low = '2026' )
      ( node_id = 3 parent_id = 1 node_kind = 'CMP' field_name = 'PeriodMonth' operator = 'EQ' low = '6' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lo_filter->mt_month[ 1 ]-low exp = '06' ).
    cl_abap_unit_assert=>assert_true( lo_filter->matches( VALUE #( PeriodYear = '2026' PeriodMonth = '06' ) ) ).
  ENDMETHOD.

  METHOD fixture.
    DATA(lv_sign) = COND decfloat34( WHEN iv_negative = abap_true THEN -1 ELSE 1 ).
    rt_rows = lcl_ca_export_xlsx=>build(
      it_lines = VALUE #( ( calc_run_id = 'RUN-202606' line_num = '0000001'
        ct_id = 'IC-0020' bruto_amt = 100 * lv_sign gross_up_amt = 10 * lv_sign ct_currency = 'USD'
        local_currency = 'MXN' net_amt = 90 * lv_sign net_local_amt = 180 * lv_sign ) )
      it_pcs = VALUE #( ( calc_run_id = 'RUN-202606' line_num = '0000001' pc_seq = '001'
        prctr = '999' campana = '001' role_category = 'E' allocation = '0'
        bruto_amt = 33 * lv_sign calc_amt = 30 * lv_sign net_amt = 30 * lv_sign net_local_amt = 60 * lv_sign )
        ( calc_run_id = 'RUN-202606' line_num = '0000001' pc_seq = '002'
        prctr = '999' campana = '002' role_category = 'C' allocation = '1'
        bruto_amt = 67 * lv_sign calc_amt = 60 * lv_sign net_amt = 60 * lv_sign net_local_amt = 120 * lv_sign ) )
      it_steps = VALUE #( ( calc_run_id = 'RUN-202606' line_num = '0000001' step_category = 'TAX'
        tax_type = 'WHT' output_amt = 1 * lv_sign )
        ( calc_run_id = 'RUN-202606' line_num = '0000001' step_category = 'TAX' tax_type = 'PIS' output_amt = 2 * lv_sign )
        ( calc_run_id = 'RUN-202606' line_num = '0000001' step_category = 'TAX' tax_type = 'PIS' output_amt = 3 * lv_sign )
        ( calc_run_id = 'RUN-202606' line_num = '0000001' step_category = 'TAX' tax_type = 'COFINS' output_amt = 0 )
        ( calc_run_id = 'RUN-202606' line_num = '0000002' step_category = 'TAX' tax_type = 'OTHER' output_amt = 500 ) )
      it_contracts = VALUE #( ) it_currencies = VALUE #( ( Currency = 'USD' Decimals = iv_decimals ) ) ).
  ENDMETHOD.

  METHOD tax_pivot.
    DATA(lt_rows) = fixture( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 5 ).
    DATA(lt_header) = lt_rows[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = lt_header[ 19 ] exp = 'COFINS' ).
    cl_abap_unit_assert=>assert_equals( act = lt_header[ 20 ] exp = 'PIS' ).
    cl_abap_unit_assert=>assert_equals( act = lt_header[ 21 ] exp = 'WHT' ).
    DATA(lt_first) = lt_rows[ 2 ].
    DATA(lt_last) = lt_rows[ 3 ].
    cl_abap_unit_assert=>assert_not_initial( lt_first[ 19 ] ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 19 ] ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 20 ] ) + CONV decfloat34( lt_last[ 20 ] ) exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 22 ] ) exp = '1.98' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_last[ 22 ] ) exp = '4.02' ).
  ENDMETHOD.

  METHOD negative_residual.
    DATA(lt_rows) = fixture( iv_negative = abap_true ).
    DATA(lt_first) = lt_rows[ 2 ]. DATA(lt_last) = lt_rows[ 3 ].
    cl_abap_unit_assert=>assert_equals( act = lt_first[ 16 ] exp = 'Si' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 21 ] ) + CONV decfloat34( lt_last[ 21 ] ) exp = -1 ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 22 ] ) + CONV decfloat34( lt_last[ 22 ] ) exp = -6 ).
  ENDMETHOD.

  METHOD currency_precision.
    DATA(lt_rows) = fixture( iv_decimals = 0 ).
    DATA(lt_first) = lt_rows[ 2 ].
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 21 ] ) exp = 0 ).
    lt_rows = fixture( iv_decimals = 3 ).
    lt_first = lt_rows[ 2 ].
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_first[ 21 ] ) exp = '0.330' ).
  ENDMETHOD.

  METHOD same_line_two_runs.
    DATA(lt_rows) = lcl_ca_export_xlsx=>build(
      it_lines = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' bruto_amt = 100 ct_currency = 'USD' local_currency = 'USD' )
        ( calc_run_id = 'RUN-B' line_num = '0000001' bruto_amt = 100 ct_currency = 'EUR' local_currency = 'EUR' ) )
      it_pcs = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' pc_seq = '001' bruto_amt = 100 )
        ( calc_run_id = 'RUN-B' line_num = '0000001' pc_seq = '001' bruto_amt = 100 ) )
      it_steps = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' step_category = 'TAX' tax_type = 'WHT' output_amt = 2 )
        ( calc_run_id = 'RUN-B' line_num = '0000001' step_category = 'TAX' tax_type = 'PIS' output_amt = 3 ) )
      it_contracts = VALUE #( ) it_currencies = VALUE #( ) ).
    DATA(lt_a) = lt_rows[ 2 ]. DATA(lt_b) = lt_rows[ 3 ].
    cl_abap_unit_assert=>assert_initial( lt_a[ 19 ] ).
    cl_abap_unit_assert=>assert_initial( lt_b[ 20 ] ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_a[ 20 ] ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_b[ 19 ] ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 7 ).
  ENDMETHOD.

  METHOD missing_apertura.
    TRY.
        DATA(lt_rows) = lcl_ca_export_xlsx=>build(
          it_lines = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' ) )
          it_pcs = VALUE #( ) it_steps = VALUE #( ) it_contracts = VALUE #( ) it_currencies = VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'A calculated line without dimensions was silently omitted' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD zero_bruto.
    DATA(lt_rows) = lcl_ca_export_xlsx=>build(
      it_lines = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' ct_currency = 'USD' local_currency = 'USD' ) )
      it_pcs = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' pc_seq = '001' )
        ( calc_run_id = 'RUN-A' line_num = '0000001' pc_seq = '002' ) )
      it_steps = VALUE #( ( calc_run_id = 'RUN-A' line_num = '0000001' step_category = 'TAX' tax_type = 'WHT' output_amt = 1 ) )
      it_contracts = VALUE #( ) it_currencies = VALUE #( ) ).
    DATA(lt_a) = lt_rows[ 2 ]. DATA(lt_b) = lt_rows[ 3 ].
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_a[ 19 ] ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_b[ 19 ] ) exp = 1 ).
  ENDMETHOD.

  METHOD numeric_columns.
    DATA(lt_rows) = fixture( ).
    DATA(lt_cols) = lcl_ca_export_xlsx=>numeric_cols( lt_rows[ 1 ] ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_cols[ table_line = 19 ] ) ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_cols[ table_line = 9 ] ) ) ).
    DATA(lt_contract) = lt_rows[ 5 ].
    cl_abap_unit_assert=>assert_equals( act = lt_contract[ 1 ] exp = 'TOTAL CONTRATO' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_contract[ 23 ] ) exp = 90 ).
    DATA(lt_local) = lt_rows[ 4 ].
    cl_abap_unit_assert=>assert_equals( act = lt_local[ 1 ] exp = 'TOTAL LOCAL' ).
    cl_abap_unit_assert=>assert_equals( act = CONV decfloat34( lt_local[ 24 ] ) exp = 180 ).
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - Stored FX provenance and worksheet totals.
CLASS ltcl_ca_trans_export DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA ms_line TYPE zreing_ca_line_a.
    DATA mt_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_steps TYPE zif_reing_ca_types=>ty_step_t.
    METHODS setup.
    METHODS unavailable.
    METHODS build RETURNING VALUE(rt_rows) TYPE zcl_reing_ca_xls_hdl=>ty_rows
      RAISING zcx_reing_ca_calc_error.
    METHODS unavailable_local_blank FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS valid_zero_local_numeric FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS trans_total_no_duplication FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS historical_backfill_legacy FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS bad_marker_rejected FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS stale_trans_amount_rejected FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS tax_columns_preserved FOR TESTING RAISING zcx_reing_ca_calc_error.
ENDCLASS.

CLASS ltcl_ca_trans_export IMPLEMENTATION.
  METHOD setup.
    ms_line = VALUE #( calc_run_id = 'UT-EXPORT' line_num = 1 bukrs_prest = 'EBA'
      ct_currency = 'USD' trans_currency = 'BRL' local_currency = 'BRL'
      calc_amt = 100 bruto_amt = 100 net_amt = 100 share_pct = 100
      net_trans_amt = 500 net_local_amt = 500 exch_rate_1 = 5 exch_rate = 1
      line_status = zif_reing_ca_c=>line_status-calc ).
    mt_pc = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 1 ct_currency = 'USD'
        share_abs = 60 calc_amt = 60 bruto_amt = 60 net_amt = 60
        bruto_trans_amt = 300 net_trans_amt = 300 net_local_amt = 300 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 pc_seq = 2 ct_currency = 'USD'
        share_abs = 40 calc_amt = 40 bruto_amt = 40 net_amt = 40
        bruto_trans_amt = 200 net_trans_amt = 200 net_local_amt = 200 ) ).
    mt_steps = VALUE #(
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '01'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 100 input_currency = 'USD'
        output_amt = 500 output_currency = 'BRL' rate_pct = 5 )
      ( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '05' seq = '02'
        step_category = zif_reing_ca_c=>step_category-fx input_amt = 500 input_currency = 'BRL'
        output_amt = 500 output_currency = 'BRL' rate_pct = 1 ) ).
  ENDMETHOD.
  METHOD build.
    rt_rows = lcl_ca_export_xlsx=>build( it_lines = VALUE #( ( ms_line ) )
      it_pcs = mt_pc it_steps = mt_steps it_contracts = VALUE #( )
      it_currencies = VALUE #( ( Currency = 'USD' Decimals = 2 ) ( Currency = 'BRL' Decimals = 2 ) ) ).
  ENDMETHOD.
  METHOD unavailable.
    CLEAR: ms_line-net_local_amt, ms_line-exch_rate,
      mt_pc[ 1 ]-net_local_amt, mt_pc[ 2 ]-net_local_amt.
    ASSIGN mt_steps[ step_num = '05' seq = '02' ] TO FIELD-SYMBOL(<local>).
    CLEAR: <local>-output_amt, <local>-output_currency, <local>-rate_pct.
  ENDMETHOD.

  METHOD unavailable_local_blank.

    unavailable( ). DATA(lt_rows) = build( ). DATA(lt_detail) = lt_rows[ 2 ].
    cl_abap_unit_assert=>assert_initial( lt_detail[ 21 ] ).
    cl_abap_unit_assert=>assert_initial( lt_detail[ 23 ] ).
    cl_abap_unit_assert=>assert_initial( lt_detail[ 24 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 300 act = CONV decfloat34( lt_detail[ 28 ] ) ).
    cl_abap_unit_assert=>assert_equals( exp = 5 act = lines( lt_rows ) ).
  ENDMETHOD.

  METHOD valid_zero_local_numeric.

    ms_line-net_amt = 0. ms_line-net_trans_amt = 0. ms_line-net_local_amt = 0.
    CLEAR: mt_pc[ 1 ]-net_amt, mt_pc[ 2 ]-net_amt,
      mt_pc[ 1 ]-net_trans_amt, mt_pc[ 2 ]-net_trans_amt,
      mt_pc[ 1 ]-net_local_amt, mt_pc[ 2 ]-net_local_amt.
    mt_steps[ 1 ]-input_amt = 0. mt_steps[ 1 ]-output_amt = 0.
    mt_steps[ 2 ]-input_amt = 0. mt_steps[ 2 ]-output_amt = 0.
    DATA(lt_rows) = build( ). DATA(lt_detail) = lt_rows[ 2 ].
    cl_abap_unit_assert=>assert_not_initial( lt_detail[ 21 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = CONV decfloat34( lt_detail[ 21 ] ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'BRL' act = lt_detail[ 23 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 6 act = lines( lt_rows ) ).
  ENDMETHOD.

  METHOD trans_total_no_duplication.

    DATA(lt_rows) = build( ).
    DATA lv_net TYPE decfloat34. DATA lv_bruto TYPE decfloat34. DATA lv_totals TYPE i.
    LOOP AT lt_rows INTO DATA(lt_row).
      IF lt_row[ 27 ] = 'BRL' AND lt_row[ 32 ] IS INITIAL.
        lv_totals += 1. lv_net = CONV #( lt_row[ 28 ] ). lv_bruto = CONV #( lt_row[ 29 ] ).
      ENDIF.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lv_totals ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = lv_net ).
    cl_abap_unit_assert=>assert_equals( exp = 500 act = lv_bruto ).
  ENDMETHOD.

  METHOD historical_backfill_legacy.

    DELETE mt_steps WHERE step_num = '05' AND seq = '02'.
    DATA(lt_rows) = build( ).
    cl_abap_unit_assert=>assert_equals( exp = 5 act = lines( lt_rows ) ).
    DATA(lt_detail) = lt_rows[ 2 ].
    cl_abap_unit_assert=>assert_equals( exp = 300 act = CONV decfloat34( lt_detail[ 21 ] ) ).
  ENDMETHOD.

  METHOD bad_marker_rejected.

    mt_steps[ 2 ]-output_currency = 'USD'.
    TRY.
        DATA(lt_rows) = build( ). cl_abap_unit_assert=>fail( ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->mv_message ).
    ENDTRY.
  ENDMETHOD.

  METHOD stale_trans_amount_rejected.

    mt_pc[ 1 ]-net_trans_amt = 0.
    TRY.
        DATA(lt_rows) = build( ). cl_abap_unit_assert=>fail( ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->mv_message ).
    ENDTRY.
  ENDMETHOD.

  METHOD tax_columns_preserved.

    APPEND VALUE #( calc_run_id = ms_line-calc_run_id line_num = 1 step_num = '04' seq = '01'
      step_category = zif_reing_ca_c=>step_category-tax tax_type = 'T1' output_amt = 10 ) TO mt_steps.
    DATA(lt_rows) = build( ). DATA(lt_header) = lt_rows[ 1 ].
    DATA(lt_first) = lt_rows[ 2 ]. DATA(lt_second) = lt_rows[ 3 ].
    cl_abap_unit_assert=>assert_equals( exp = 'T1' act = lt_header[ 19 ] ).
    cl_abap_unit_assert=>assert_equals( exp = 6 act = CONV decfloat34( lt_first[ 19 ] ) ).
    cl_abap_unit_assert=>assert_equals( exp = 4 act = CONV decfloat34( lt_second[ 19 ] ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'Mon. Trans.' act = lt_header[ 28 ] ).
  ENDMETHOD.
ENDCLASS.
