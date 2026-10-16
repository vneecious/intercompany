*----------------------------------------------------------------------*
* Created by     : Oscar Augusto Leal Dominguez (EXT_OSCUGALD)        *
* Requirement N° :                                                     *
* Date           : 10.07.2026                                         *
* Description    : App CA - Motor de Calculo - F3.2 Calculate + APJ   *
* Transport      : DS4K9B5XZC                                         *
* Reference      : 5000049390                                         *
*----------------------------------------------------------------------*
*
* F3.2 - Job Step del APJ que dispara ZCL_REING_CA_PIPELINE (F2) en
* background. Implementa 3 interfaces: IF_APJ_RT_EXEC_OBJECT (ejecucion
* real del job), IF_APJ_DT_EXEC_OBJECT (declaracion de parametros en
* diseno), IF_OO_ADT_CLASSRUN (debug directo desde ADT sin framework).
* Estructura 1:1 con precedente real ZCL_LEDGER_CALC_JOB del mismo
* landscape (paquete ZFPS_GROW-RTR-LEDGERS-WRAPPERS).
*
* Interfaces APJ son C1 RELEASED Clean-Core (useInSAPCloudPlatform:true),
* verificado por el Architect (normalized-spec F3.2 P3.2-1).
*
* IMPORTANTE - Paso manual post-activacion (F3.2-H1):
*   Crear en Eclipse ADT el SAJC y SAJT 'ZREING_CA_CALC_JOBT' apuntando
*   a esta clase. Sin ese paso, Calculate crea LINE_A en CALC_PROC pero
*   el agendamiento real emite warning degradado (CX_TEMPLATE_DOESNT_EXIST
*   capturado en ZBP_ReingCARun~schedule_calc_job).
*
* GAP Path A: pipeline expande 1 fila generica a N receptoras en memoria.
* run_pipeline/reconcile_lines reconcilian por CLAVE NATURAL (ct_uuid+
* mat_uuid+op_type+op_uuid[+bukrs_recv]) contra las LINE_A fisicas
* CALC_PROC -- NUNCA por el line_num que el pipeline reasigna
* internamente 1..N POR GRUPO (ver nota de fix mas abajo, 17.07.2026).
*
*----------------------------------------------------------------------*
* Inicio ajuste : 10.07.2026 | Fin ajuste: 10.07.2026
* Autor ajuste  : EXT_OSCUGALD
* Descripcion   : Creacion inicial clase Job Step APJ F3.2 Calculate
*----------------------------------------------------------------------*
* Note (Carlos Alexander Gonzalez Lopez / EXT_GONZALCA, DS4K9B5XZC,
* 5000049390): este objeto nunca se activo. Antes de su primera
* activacion se corrigieron 2 errores de sintaxis bloqueantes,
* detectados por SAPDiagnose, sin ningun cambio de diseno:
*   - METHOD execute: desajuste posicional entre la lista de columnas
*     del SELECT y el tipo completo pre-declarado de LT_LINES.
*   - METHOD increment_totals: "SELECT DISTINCT" invalido dentro de un
*     subquery anidado usado como FROM (y, en un primer intento de fix,
*     "COUNT(DISTINCT ... && ...)" tampoco valido porque "&&" exige CHAR
*     y las claves son sysuuid_x16/RAW16 -- ver fix definitivo abajo).
* Ver code-summary.md/iteration-log.md del fix (carpeta
* f3.2-f3.3-f6.07-activacion) para el detalle de cada correccion.
*----------------------------------------------------------------------*
* Fix critico (Carlos Alexander Gonzalez Lopez / EXT_GONZALCA, DS4K9B5XZC,
* 5000049390, 17.07.2026): validando una prueba real (IC-0007/202602) se
* detecto que Path A (CM_LOADABLE) dejaba huerfana para siempre la LINE_A
* generica en CALC_PROC e insertaba una fila nueva con el resultado, en
* vez de reutilizar (UPDATE) esa misma linea -- inflando ademas
* TOTAL_LINES en RUN_A. Causa raiz: el reconciliado (antes en
* PERSIST_LINE, ya no usado; despues inline en RUN_PIPELINE) decidia
* UPDATE vs. INSERT comparando el LINE_NUM que asigna el propio pipeline
* (ZCL_REING_CA_PIPELINE~step_02_distribute reinicia su contador en 0/1..N
* POR GRUPO, sin relacion con el LINE_NUM fisico correlativo a nivel de
* todo el RUN) contra el LINE_NUM ya persistido por el Handler RAP -- esa
* comparacion solo matcheaba por coincidencia numerica, nunca por diseno,
* y ademas colisionaba entre grupos distintos de un mismo scope (el
* contador del pipeline se reinicia en cada grupo). Fix: RUN_PIPELINE/
* RECONCILE_LINES/RECONCILE_ONE_LINE ahora reconcilian por CLAVE NATURAL
* de grupo (ct_uuid+mat_uuid+op_type+op_uuid), tomando el/los LINE_NUM
* fisicos ya persistidos (via IT_PHYSICAL_LINES, construida en EXECUTE)
* como candidatos a reusar -- primero por BUKRS_RECV (Path B/C,
* pass-through, ya vienen 1:1), si no hay match cualquier candidato
* fisico restante del grupo (Path A, unica generica) y solo si no queda
* ninguno se asigna un LINE_NUM nuevo (MAX()+1). LINE_PC_A/STEP_A se
* remapean linea por linea, consumiendo (DELETE) del working copy a
* medida que se procesan, para que un LINE_NUM local repetido entre dos
* grupos del mismo scope no se cruce. PERSIST_LINE quedo sin ningun
* llamador desde el ATC-fix de bulk previo -- se elimina (dead code) en
* vez de dejarlo como reliquia. La reconciliacion se separo en 2 metodos
* (RECONCILE_LINES/RECONCILE_ONE_LINE) para mantener RUN_PIPELINE por
* debajo de los limites de complejidad ciclomatica/sentencias del ATC
* (ZMELI_CLEAN_CORE_V3).
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_calc_job DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES:
      if_oo_adt_classrun,
      if_apj_dt_exec_object,
      if_apj_rt_exec_object.

    METHODS:
      constructor,

      execute
        IMPORTING
          iv_run_id TYPE zreing_ca_run_a-calc_run_id
        RAISING
          cx_apj_rt_content.

  PRIVATE SECTION.
    " V001 (CC) - AN2 APJ: shared period writer lock, private ownership.
    DATA mo_run_lock TYPE REF TO if_abap_lock_object.
    DATA mv_locked_run TYPE zreing_ca_run_a-calc_run_id.
    METHODS lock_run
      IMPORTING iv_run_id TYPE zreing_ca_run_a-calc_run_id
      RAISING cx_apj_rt_content.
    METHODS release_run RETURNING VALUE(rv_message) TYPE string.
    " Snapshot de las LINE_A fisicas en CALC_PROC al momento de arrancar
    " el job -- unica fuente confiable de correlacion con los resultados
    " del pipeline (que trae su propio LINE_NUM interno, reiniciado por
    " grupo, ver nota de fix arriba).
    TYPES: BEGIN OF ty_physical_line,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
             ct_uuid     TYPE zreing_ca_line_a-ct_uuid,
             mat_uuid    TYPE zreing_ca_line_a-mat_uuid,
             op_type     TYPE zreing_ca_line_a-op_type,
             op_uuid     TYPE zreing_ca_line_a-op_uuid,
             cm_h_id     TYPE zreing_ca_line_a-cm_h_id,
             bukrs_recv  TYPE zreing_ca_line_a-bukrs_recv,
           END OF ty_physical_line,
           ty_physical_line_t TYPE STANDARD TABLE OF ty_physical_line WITH EMPTY KEY.

    TYPES ty_lpc_bulk_t       TYPE STANDARD TABLE OF zreing_ca_lpc_a.
    TYPES ty_steps_bulk_t     TYPE STANDARD TABLE OF zreing_ca_step_a.
    TYPES ty_heartbeat_nums_t TYPE RANGE OF zreing_ca_line_a-line_num.

    DATA mt_log TYPE string_table.

    METHODS:
      add_log
        IMPORTING iv_message TYPE string,

      run_pipeline
        IMPORTING iv_run_id         TYPE zreing_ca_run_a-calc_run_id
                  it_scope          TYPE zif_reing_ca_types=>ty_group_key_t
                  it_physical_lines TYPE ty_physical_line_t
        RAISING   cx_apj_rt_content,

      reconcile_lines
        IMPORTING iv_run_id         TYPE zreing_ca_run_a-calc_run_id
                  it_scope          TYPE zif_reing_ca_types=>ty_group_key_t
                  it_physical_lines TYPE ty_physical_line_t
                  is_result         TYPE zif_reing_ca_types=>ty_pipeline_result
        EXPORTING et_to_update      TYPE zif_reing_ca_types=>ty_line_t
                  et_to_insert      TYPE zif_reing_ca_types=>ty_line_t
                  et_lpc_bulk       TYPE ty_lpc_bulk_t
                  et_steps_bulk     TYPE ty_steps_bulk_t
                  et_heartbeat_nums TYPE ty_heartbeat_nums_t,

      reconcile_one_line
        IMPORTING is_res_line       TYPE zreing_ca_line_a
        CHANGING  ct_group_physical TYPE ty_physical_line_t
                  cv_max_line_num   TYPE zreing_ca_line_a-line_num
                  ct_steps_work     TYPE zif_reing_ca_types=>ty_step_t
                  ct_pc_work        TYPE zif_reing_ca_types=>ty_line_pc_t
                  ct_to_update      TYPE zif_reing_ca_types=>ty_line_t
                  ct_to_insert      TYPE zif_reing_ca_types=>ty_line_t
                  ct_lpc_bulk       TYPE ty_lpc_bulk_t
                  ct_steps_bulk     TYPE ty_steps_bulk_t
                  ct_heartbeat_nums TYPE ty_heartbeat_nums_t,

      increment_totals
        IMPORTING iv_run_id TYPE zreing_ca_run_a-calc_run_id.
METHODS terminate_pending_lines
      IMPORTING iv_run_id  TYPE zreing_ca_run_a-calc_run_id
                iv_message TYPE string.
    METHODS build_job_logs
      IMPORTING it_to_update  TYPE zif_reing_ca_types=>ty_line_t
                it_to_insert  TYPE zif_reing_ca_types=>ty_line_t
      RETURNING VALUE(rt_log) TYPE zif_reing_ca_types=>ty_log_t.
    METHODS write_logs
      IMPORTING it_log TYPE zif_reing_ca_types=>ty_log_t.

ENDCLASS.



CLASS zcl_reing_ca_calc_job IMPLEMENTATION.


  METHOD constructor.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    " Debug/test directo desde ADT sin framework APJ.
    " ej. execute( iv_run_id = 'RUN-2026007' ).
  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    " Declara P_RUNID para el Job Catalog Entry (SAJC/SAJT, F3.2-H1).
    et_parameter_def = VALUE #(
      ( selname        = 'P_RUNID'
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'CHAR'
        length         = 20
        param_text     = 'CalcRun ID'
        changeable_ind = abap_true
        mandatory_ind  = abap_true ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    " Punto de entrada APJ: parsea IT_PARAMETERS y delega a execute().
    " CX_APJ_RT_CONTENT declarado por la interfaz (sin gap de contrato).
    DATA lv_run_id TYPE zreing_ca_run_a-calc_run_id.
    LOOP AT it_parameters INTO DATA(ls_param).
      IF ls_param-selname = 'P_RUNID'.
        lv_run_id = ls_param-low.
      ENDIF.
    ENDLOOP.
    TRY.
        execute( iv_run_id = lv_run_id ).
      CATCH cx_apj_rt_content INTO DATA(lx_error).
        RAISE EXCEPTION lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD execute.
    " Flujo principal del Job Step (F3.2 normalized-spec SS C):
    " 1) Lee LINE_A en CALC_PROC del run dado (snapshot fisico -- se
    "    conserva LINE_NUM/BUKRS_RECV para que reconcile_lines reconcilie
    "    por clave natural, ver nota de fix en el header de la clase).
    " 2) Construye scope de group keys sin duplicados.
    " 3) run_pipeline -> ZCL_REING_CA_PIPELINE -> persistencia SQL directa
    "    reconciliada por clave natural (F3.2-DD-4, P-07).
    " 4) Cierra con increment_totals (F3-08).
    CHECK iv_run_id IS NOT INITIAL.
    " Lock conflict before snapshot does not terminalize another writer's queued lines.
    lock_run( iv_run_id ).
    TRY.

    " Fix (EXT_GONZALCA): LT_LINES estaba pre-declarada con el tipo COMPLETO
    " de ZREING_CA_LINE_A (decenas de campos), pero el SELECT solo trae 7
    " columnas explicitas -> desajuste posicional entre la lista de columnas
    " del SELECT y la estructura completa de la tabla ("The data type of the
    " component LINE_NUM of LT_LINES is not compatible with the data type of
    " CT_UUID"). Se usa declaracion inline para que el compilador infiera el
    " tipo exacto de las 7 columnas seleccionadas, sin ambiguedad posicional.
    TEST-SEAM an2_calc_snapshot.
    SELECT calc_run_id, line_num, ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id, bukrs_recv
      FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_run_id
        AND line_status = 'CALC_PROC'
      INTO TABLE @DATA(lt_lines).
    END-TEST-SEAM.
    IF lt_lines IS INITIAL.
      DATA(lv_empty_release) = release_run( ).
      IF lv_empty_release IS NOT INITIAL.
        add_log( lv_empty_release ).
        RAISE EXCEPTION TYPE cx_apj_rt_content.
      ENDIF.
      RETURN.
    ENDIF.

    " Snapshot fisico completo (line_num real + bukrs_recv) para que
    " reconcile_lines pueda reconciliar por clave natural -- ver fix.
    DATA(lt_physical_lines) = CORRESPONDING ty_physical_line_t( lt_lines ).

    DATA lt_scope TYPE zif_reing_ca_types=>ty_group_key_t.
    LOOP AT lt_lines INTO DATA(ls_line).
      APPEND VALUE zif_reing_ca_types=>ty_group_key(
        ct_uuid  = ls_line-ct_uuid
        mat_uuid = ls_line-mat_uuid
        op_type  = ls_line-op_type
        op_uuid  = ls_line-op_uuid
        cm_h_id  = ls_line-cm_h_id ) TO lt_scope.
    ENDLOOP.
    SORT lt_scope BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_scope
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.

    TRY.
        TEST-SEAM an2_calc_run.
          run_pipeline( iv_run_id = iv_run_id it_scope = lt_scope it_physical_lines = lt_physical_lines ).
        END-TEST-SEAM.
        " Lines, LPC, STEP, heartbeat, calculation logs, and counts commit together.
        TEST-SEAM an2_calc_totals.
          increment_totals( iv_run_id ).
        END-TEST-SEAM.
        TEST-SEAM an2_calc_commit.
          COMMIT WORK.
        END-TEST-SEAM.
      CATCH cx_apj_rt_content INTO DATA(lx_fatal).
        TEST-SEAM an2_calc_rollback.
          ROLLBACK WORK.
        END-TEST-SEAM.
        add_log( |Error fatal: { lx_fatal->get_text( ) }| ).
        RAISE EXCEPTION lx_fatal.

      " Begin Change ID V002 (03.09.2026 | EXT_GONZALCA)
      " Descripcion : este TRY solo capturaba CX_APJ_RT_CONTENT, y
      " run_pipeline solo captura ZCX_REING_CA_CALC_ERROR. Una excepcion
      " TECNICA (el caso real: CX_SY_CONVERSION_OVERFLOW en step_fx al
      " guardar una tasa ARS/COP en RATE_PCT) escapaba hasta aca, abortaba
      " el job con dump y dejaba TODAS las lineas del run en CALC_PROC, sin
      " heartbeat, sin COMMIT y sin un solo mensaje para el usuario: el run
      " quedaba mudo y el reintento releia la misma linea envenenada.
      " El caso normal ya lo cubre el CATCH CX_ROOT por grupo que se agrego
      " en ZCL_REING_CA_PIPELINE~execute (el job termina bien y persiste las
      " lineas en CALC_ERR); esta rama cubre lo que ocurre FUERA de ese TRY:
      " la pre-carga de caches del pipeline, la reconciliacion por clave
      " natural y la persistencia bulk de este job.
      " No sustituye a ZCL_REING_CA_ORPHAN_REC: ese job BORRA la linea
      " CALC_PROC huerfana por timeout (decide_recovery), correcto pero mudo.
      " Aqui la linea sobrevive con el motivo del fallo visible en la UI.
      CATCH cx_root INTO DATA(lx_tech).
        DATA(lv_exc_name) = cl_abap_typedescr=>describe_by_object_ref(
                              lx_tech )->get_relative_name( ).
        DATA(lv_tech_msg) = |Error tecnico { lv_exc_name }: { lx_tech->get_text( ) }|.
        add_log( |Error fatal no controlado: { lv_tech_msg }| ).
        TEST-SEAM an2_calc_technical_rollback.
          ROLLBACK WORK.
        END-TEST-SEAM.
        TEST-SEAM an2_calc_terminate.
          terminate_pending_lines( iv_run_id = iv_run_id iv_message = lv_tech_msg ).
        END-TEST-SEAM.
        RAISE EXCEPTION TYPE cx_apj_rt_content.
      " End Change ID V002 (03.09.2026 | EXT_GONZALCA)
    ENDTRY.
      CLEANUP.
        " Scope1 survives rollback; release only this instance's acquired X lock.
        TEST-SEAM an2_calc_cleanup_rollback.
          ROLLBACK WORK.
        END-TEST-SEAM.
        DATA(lv_cleanup_release) = release_run( ).
        IF lv_cleanup_release IS NOT INITIAL.
          add_log( lv_cleanup_release ).
        ENDIF.
    ENDTRY.
    DATA(lv_release) = release_run( ).
    IF lv_release IS NOT INITIAL.
      add_log( lv_release ).
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDIF.
  ENDMETHOD.


  METHOD run_pipeline.
    " Ejecuta ZCL_REING_CA_PIPELINE con fuentes reales; delega la
    " reconciliacion por CLAVE NATURAL a reconcile_lines/reconcile_one_line
    " (separados de este metodo para mantener la complejidad ciclomatica y
    " el numero de sentencias bajo los limites del ATC del proyecto) y
    " persiste todo en bulk (F3.2-DD-4, P-07).
    DATA lo_sources  TYPE REF TO zcl_reing_ca_sources.
    DATA lo_pipeline TYPE REF TO zcl_reing_ca_pipeline.
    CHECK it_scope IS NOT INITIAL.

    SELECT SINGLE calc_run_id, fiscal_period, fiscal_year
      FROM zreing_ca_run_a WHERE calc_run_id = @iv_run_id
      INTO @DATA(ls_run_ctx).

    DATA ls_context TYPE zif_reing_ca_types=>ty_context.
    ls_context-calc_run_id = ls_run_ctx-calc_run_id.
    ls_context-period      = ls_run_ctx-fiscal_period.
    ls_context-year        = ls_run_ctx-fiscal_year.

    lo_sources  = NEW zcl_reing_ca_sources( ).
    lo_pipeline = NEW zcl_reing_ca_pipeline(
      is_context = ls_context io_sources = lo_sources ).

    TRY.
        DATA(ls_result) = lo_pipeline->execute( it_scope ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_calc).
        add_log( |Pipeline error: { lx_calc->mv_message }| ).
        RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDTRY.

    reconcile_lines(
      EXPORTING iv_run_id         = iv_run_id
                it_scope          = it_scope
                it_physical_lines = it_physical_lines
                is_result         = ls_result
      IMPORTING et_to_update      = DATA(lt_to_update)
                et_to_insert      = DATA(lt_to_insert)
                et_lpc_bulk       = DATA(lt_lpc_bulk)
                et_steps_bulk     = DATA(lt_steps_bulk)
                et_heartbeat_nums = DATA(lt_heartbeat_nums) ).

    " Begin Insert V004 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : preservacion de PROC_STARTED_AT / INSUMO_CHECK_AT.
    " El UPDATE de mas abajo persiste la FILA COMPLETA que devuelve el
    " pipeline, y esa fila NO trae los timestamps operativos: en el Path
    " A/B1 step_validate arma la linea con CORRESPONDING desde ty_group_key
    " (que solo lleva calc_run_id/ct_uuid/mat_uuid/op_type/op_uuid), asi que
    " ambos campos llegan en cero y el UPDATE PISA con cero el
    " PROC_STARTED_AT que Calculate acababa de escribir.
    " Consecuencia real (verificada en TS4-400, 02 y 03/2026): con
    " PROC_STARTED_AT = 0 e INSUMO_CHECK_AT = 0,
    " ZCL_REING_CA_INSUMO_MGR~check_consistency toma cero como "momento del
    " control" y CUALQUIER LAST_CHANGED_AT real de los insumos resulta
    " posterior -- el grupo sale IS_STALE siempre, aunque nadie haya tocado
    " nada, y Release queda bloqueado por un warning que no corresponde.
    " El Path B2 no estaba afectado (lee la fila PEND completa), y
    " PROC_HEARTBEAT_AT nunca lo estuvo porque se escribe aparte, con un
    " UPDATE ... SET selectivo -- justamente el patron que este bloque
    " replica para los otros dos campos.
    " Se preserva lo que hay en BD en vez de recalcularlo: el valor
    " autoritativo es el que fijo Calculate al crear/resetear las lineas.
    IF lt_to_update IS NOT INITIAL OR lt_to_insert IS NOT INITIAL.
      SELECT calc_run_id, line_num, ct_uuid, mat_uuid, op_type, op_uuid,
             cm_h_id, proc_started_at, insumo_check_at
        FROM zreing_ca_line_a
        WHERE calc_run_id = @iv_run_id
        INTO TABLE @DATA(lt_ts_keep).

      " (a) Filas que se reusan: cada una recupera su propio timestamp.
      LOOP AT lt_to_update ASSIGNING FIELD-SYMBOL(<ls_upd>).
        READ TABLE lt_ts_keep INTO DATA(ls_keep_u)
          WITH KEY calc_run_id = <ls_upd>-calc_run_id
                   line_num    = <ls_upd>-line_num.
        IF sy-subrc = 0.
          <ls_upd>-proc_started_at = ls_keep_u-proc_started_at.
          <ls_upd>-insumo_check_at = ls_keep_u-insumo_check_at.
        ENDIF.
      ENDLOOP.

      " (b) Filas nuevas: receptoras 2..N de una expansion Path A, que
      "     todavia no existen en BD. Heredan el timestamp de la fila
      "     fisica de SU MISMO GRUPO (la generica que creo Calculate).
      "     Deliberadamente NO se usa un MIN( ) del run entero: un run
      "     acumula varios Calculate de distintos grupos y el minimo seria
      "     el del lote equivocado.
      LOOP AT lt_to_insert ASSIGNING FIELD-SYMBOL(<ls_ins>).
        READ TABLE lt_ts_keep INTO DATA(ls_keep_i)
          WITH KEY ct_uuid  = <ls_ins>-ct_uuid
                   mat_uuid = <ls_ins>-mat_uuid
                   op_type  = <ls_ins>-op_type
                   op_uuid  = <ls_ins>-op_uuid
                   cm_h_id  = <ls_ins>-cm_h_id.
        IF sy-subrc = 0.
          <ls_ins>-proc_started_at = ls_keep_i-proc_started_at.
          <ls_ins>-insumo_check_at = ls_keep_i-insumo_check_at.
        ENDIF.
      ENDLOOP.
    ENDIF.
    " End Insert V004 (08.09.2026 | EXT_GONZALCA)

    IF lt_to_update IS NOT INITIAL.
      UPDATE zreing_ca_line_a FROM TABLE @lt_to_update.
    ENDIF.
    IF lt_to_insert IS NOT INITIAL.
      INSERT zreing_ca_line_a FROM TABLE @lt_to_insert.
    ENDIF.
    IF lt_lpc_bulk IS NOT INITIAL.
      INSERT zreing_ca_lpc_a FROM TABLE @lt_lpc_bulk.
    ENDIF.
    IF lt_steps_bulk IS NOT INITIAL.
      INSERT zreing_ca_step_a FROM TABLE @lt_steps_bulk.
    ENDIF.
    IF lt_heartbeat_nums IS NOT INITIAL.
      UPDATE zreing_ca_line_a
        SET proc_heartbeat_at = @( cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) )
        WHERE calc_run_id = @iv_run_id
          AND line_num IN @lt_heartbeat_nums.
    ENDIF.

    " Begin Insert V005 (15.09.2026 | EXT_GONZALCA)
    " Bug #68: el log del calculo. Va DESPUES de persistir LINE_A y ANTES del
    " COMMIT WORK unico, para que el log y el estado compartan el LUW: si algo
    " falla no queda un log que afirme una transicion que no se guardo, ni una
    " transicion guardada sin su log. Mismo criterio que el job de CONTAB.
    write_logs( build_job_logs( it_to_update = lt_to_update
                                it_to_insert = lt_to_insert ) ).
    " End Insert V005 (15.09.2026 | EXT_GONZALCA)

    " V001 (CC) - execute owns commit after increment_totals under the same RUN lock.
  ENDMETHOD.


  METHOD reconcile_lines.
    " Reconcilia rs_result-lines/line_pc/steps (numeracion interna del
    " pipeline, reiniciada 0/1..N POR GRUPO) contra las LINE_A fisicas ya
    " creadas por el Handler RAP (it_physical_lines) -- CLAVE NATURAL de
    " grupo (ct_uuid+mat_uuid+op_type+op_uuid), nunca por line_num crudo
    " (ver nota de fix critico en el header de la clase, 17.07.2026).
    " Se procesan los grupos en el MISMO orden en que
    " ZCL_REING_CA_PIPELINE~execute() los genero (LOOP AT it_scope), para
    " que un line_num local que se repite en dos grupos distintos del
    " mismo scope no se cruce entre ellos (ver reconcile_one_line).
    DATA lt_steps_work TYPE zif_reing_ca_types=>ty_step_t.
    DATA lt_pc_work    TYPE zif_reing_ca_types=>ty_line_pc_t.
    lt_steps_work = is_result-steps.
    lt_pc_work    = is_result-line_pc.

    DATA lv_max_line_num TYPE zreing_ca_line_a-line_num.
    SELECT SINGLE MAX( line_num ) FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_run_id INTO @lv_max_line_num.

    " ATC fix (Loops anidados, ZMELI_CLEAN_CORE_V3): LOOP AT is_result-lines
    " WHERE ... anidado dentro del LOOP AT it_scope estaba bloqueando la
    " liberacion a Calidad. Patron ya establecido en este proyecto
    " (ZCL_REING_CA_PIPELINE, ZCL_REING_CA_XLS_HDL): pre-filtrar el grupo a
    " una tabla de trabajo con VALUE...FOR...WHERE y recorrerla con
    " DO...TIMES + READ TABLE INDEX -- DO anidado dentro de LOOP no dispara
    " el hallazgo (confirmado con ATC real en ambos precedentes).
    LOOP AT it_scope INTO DATA(ls_grp).
      " Candidatos fisicos CALC_PROC de ESTE grupo -- 1 para Path A
      " (generica, sin BUKRS_RECV) o N para Path B/C (ya expandidas 1:1
      " por el Handler, cada una con su propia receptora heredada).
      DATA(lt_group_physical) = VALUE ty_physical_line_t(
        FOR ls_p IN it_physical_lines
        WHERE ( ct_uuid = ls_grp-ct_uuid AND mat_uuid = ls_grp-mat_uuid
                AND op_type = ls_grp-op_type AND op_uuid = ls_grp-op_uuid
                AND cm_h_id = ls_grp-cm_h_id )
        ( ls_p ) ).

      DATA(lt_group_lines) = VALUE zif_reing_ca_types=>ty_line_t(
        FOR ls_l IN is_result-lines
        WHERE ( ct_uuid = ls_grp-ct_uuid AND mat_uuid = ls_grp-mat_uuid
                AND op_type = ls_grp-op_type AND op_uuid = ls_grp-op_uuid
                AND cm_h_id = ls_grp-cm_h_id )
        ( ls_l ) ).

      DO lines( lt_group_lines ) TIMES.
        READ TABLE lt_group_lines INTO DATA(ls_res_line) INDEX sy-index.

        reconcile_one_line(
          EXPORTING is_res_line       = ls_res_line
          CHANGING  ct_group_physical = lt_group_physical
                    cv_max_line_num   = lv_max_line_num
                    ct_steps_work     = lt_steps_work
                    ct_pc_work        = lt_pc_work
                    ct_to_update      = et_to_update
                    ct_to_insert      = et_to_insert
                    ct_lpc_bulk       = et_lpc_bulk
                    ct_steps_bulk     = et_steps_bulk
                    ct_heartbeat_nums = et_heartbeat_nums ).
      ENDDO.
    ENDLOOP.
  ENDMETHOD.


  METHOD reconcile_one_line.
    " Resuelve el LINE_NUM final de UNA linea de resultado del pipeline:
    " 1) preferir match por BUKRS_RECV (Path B/C: cada fisica ya trae su
    "    propia receptora) -- 2) si no hay, tomar cualquier candidato
    "    fisico que quede del grupo (Path A: la unica generica, sin
    "    BUKRS_RECV, para la 1ra linea del resultado) -- 3) si no queda
    "    ninguno, es una receptora adicional real (2da..Nma de Path A) ->
    "    numeracion nueva. Remapea tambien STEP_A/LPC_A (consumiendolos
    "    del working copy) y agrega el heartbeat.
    DATA(lv_old_num) = is_res_line-line_num.

    DATA lv_match_idx TYPE i.
    CLEAR lv_match_idx.
    READ TABLE ct_group_physical WITH KEY bukrs_recv = is_res_line-bukrs_recv
      TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      lv_match_idx = sy-tabix.
    ELSEIF ct_group_physical IS NOT INITIAL.
      lv_match_idx = 1.
    ENDIF.

    DATA(ls_res_line) = is_res_line.
    DATA(lv_final_num) = CONV zreing_ca_line_a-line_num( 0 ).
    IF lv_match_idx > 0.
      lv_final_num = ct_group_physical[ lv_match_idx ]-line_num.
      DELETE ct_group_physical INDEX lv_match_idx.
      ls_res_line-line_num = lv_final_num.
      APPEND ls_res_line TO ct_to_update.
    ELSE.
      cv_max_line_num = cv_max_line_num + 1.
      lv_final_num = cv_max_line_num.
      ls_res_line-line_num = lv_final_num.
      APPEND ls_res_line TO ct_to_insert.
    ENDIF.

    APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_final_num ) TO ct_heartbeat_nums.

    LOOP AT ct_steps_work INTO DATA(ls_step) WHERE line_num = lv_old_num.
      DATA(ls_step_out) = ls_step.
      ls_step_out-line_num = lv_final_num.
      APPEND CORRESPONDING zreing_ca_step_a( ls_step_out ) TO ct_steps_bulk.
    ENDLOOP.
    DELETE ct_steps_work WHERE line_num = lv_old_num.

    LOOP AT ct_pc_work INTO DATA(ls_pc) WHERE line_num = lv_old_num.
      DATA(ls_pc_out) = ls_pc.
      ls_pc_out-line_num = lv_final_num.
      APPEND CORRESPONDING zreing_ca_lpc_a( ls_pc_out ) TO ct_lpc_bulk.
    ENDLOOP.
    DELETE ct_pc_work WHERE line_num = lv_old_num.

    add_log( |Linea { lv_final_num } OK: { ls_res_line-line_status }| ).
  ENDMETHOD.


  METHOD increment_totals.
    " F3-08: actualiza TOTAL_LINES y TOTAL_GROUPS en RUN_A al cerrar scope.
    " TOTAL_GROUPS via subconsulta DISTINCT (evita incompatibilidad &&/UUID).
    DATA lv_total_lines  TYPE zreing_ca_run_a-total_lines.
    DATA lv_total_groups TYPE zreing_ca_run_a-total_groups.
    SELECT COUNT(*) FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_run_id INTO @lv_total_lines.

    " Fix (EXT_GONZALCA, iteracion 2 -- corregido por observacion bloqueante
    " OB-001 del Code Reviewer): "SELECT COUNT(*) FROM ( SELECT DISTINCT ... )"
    " no es valido en Open SQL (subquery anidado con DISTINCT de varias
    " columnas como derived table). El primer intento de fix,
    " "COUNT( DISTINCT ct_uuid && mat_uuid && op_type && op_uuid )", TAMPOCO
    " compila: confirmado por SAPDiagnose real -- "Only operands of type CHAR
    " are allowed in string chainings. The type of CT_UUID is not allowed
    " here." (ct_uuid/mat_uuid/op_uuid son sysuuid_x16/RAW16, no CHAR; "&&"
    " exige CHAR). Fix definitivo, verificado por el Reviewer: DISTINCT a una
    " tabla interna y contar sus lineas con lines( ), sin concatenacion ni
    " subquery.
    SELECT DISTINCT ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id
      FROM zreing_ca_line_a WHERE calc_run_id = @iv_run_id
      INTO TABLE @DATA(lt_distinct_groups).
    lv_total_groups = lines( lt_distinct_groups ).

    UPDATE zreing_ca_run_a
      SET total_lines  = @lv_total_lines,
          total_groups = @lv_total_groups
      WHERE calc_run_id = @iv_run_id.
  ENDMETHOD.


  METHOD add_log.
    APPEND iv_message TO mt_log.
  ENDMETHOD.
  METHOD terminate_pending_lines.
    " Begin Change ID V002 (03.09.2026 | EXT_GONZALCA)
    " Red de seguridad: termina en CALC_ERR las lineas que quedaron en
    " CALC_PROC cuando el job aborta por una excepcion TECNICA producida
    " FUERA del TRY por grupo de ZCL_REING_CA_PIPELINE~execute (pre-carga de
    " caches, reconciliacion o persistencia bulk de este job). Sin esto, el
    " run queda con todas sus lineas en CALC_PROC, sin heartbeat y sin
    " mensaje -- exactamente el sintoma reportado desde TS4-400 con el
    " overflow de RATE_PCT, donde ademas el reintento volvia a leer la
    " misma linea envenenada.
    " ROLLBACK primero: el fallo pudo dejar escrituras parciales del LUW
    " (los INSERT/UPDATE bulk de run_pipeline). Se descartan y solo se
    " persiste la terminalizacion, para que la base quede consistente.
    ROLLBACK WORK.

    DATA(lv_status_err)  = zif_reing_ca_c=>line_status-calc_err.
    DATA(lv_status_proc) = zif_reing_ca_c=>line_status-calc_proc.
    " SIM_MESSAGE es CHAR 220 -- un texto mas largo se trunca solo.
    DATA lv_msg TYPE zreing_ca_line_a-sim_message.
    lv_msg = iv_message.
    DATA(lv_now) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).

    " Begin Insert V005 (15.09.2026 | EXT_GONZALCA)
    " Bug #68: hay que leer QUE lineas se van a terminar ANTES del UPDATE --
    " despues ya no hay forma de saberlo, porque el UPDATE es masivo por
    " estado y no por clave. Hasta ahora una linea terminada por esta red de
    " seguridad quedaba en CALC_ERR con su SIM_MESSAGE pero SIN NINGUNA
    " entrada en el log de eventos, asi que el operador veia una linea en
    " error sin ningun registro de quien ni cuando la habia marcado.
    " Esto tambien le da visibilidad al #63: cuando una receptora con share 0
    " hace caer el grupo, ahora queda asentado.
    SELECT calc_run_id, line_num, bukrs_recv
      FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_run_id
        AND line_status = @lv_status_proc
      INTO TABLE @DATA(lt_doomed).
    " End Insert V005 (15.09.2026 | EXT_GONZALCA)

    UPDATE zreing_ca_line_a
      SET line_status       = @lv_status_err,
          sim_message       = @lv_msg,
          proc_heartbeat_at = @lv_now
      WHERE calc_run_id = @iv_run_id
        AND line_status = @lv_status_proc.

    " Begin Insert V005 (15.09.2026 | EXT_GONZALCA)
    " Bug #68: una fila de log por linea terminada, con el motivo real que ya
    " recibe este metodo. ZREING_CA_LOG_MSG es mas corto que SIM_MESSAGE, asi
    " que un texto largo se trunca solo -- el texto completo queda igual en
    " SIM_MESSAGE de la linea.
    " DO ... TIMES y no LOOP (loops anidados = P2 del ATC en este sistema).
    DATA lt_log   TYPE zif_reing_ca_types=>ty_log_t.
    DATA ls_doom  LIKE LINE OF lt_doomed.
    DATA lv_idx_d TYPE i VALUE 1.
    DO lines( lt_doomed ) TIMES.
      READ TABLE lt_doomed INTO ls_doom INDEX lv_idx_d.
      lv_idx_d = lv_idx_d + 1.
      APPEND VALUE #(
        calc_run_id = ls_doom-calc_run_id
        line_num    = ls_doom-line_num
        log_num     = 0
        action      = zif_reing_ca_c=>action-calc
        status_from = lv_status_proc
        status_to   = lv_status_err
        created_by  = sy-uname
        created_at  = lv_now
        message     = |Terminada por la red de seguridad del job: { iv_message }| ) TO lt_log.
    ENDDO.
    write_logs( lt_log ).
    " End Insert V005 (15.09.2026 | EXT_GONZALCA)

    COMMIT WORK.
    " End Change ID V002 (03.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD build_job_logs.
    " Begin Insert V005 (15.09.2026 | EXT_GONZALCA)
    " Bug tracker #68 -- "realice el calculo varias veces y el registro no se
    " actualizo".
    "
    " CAUSA RAIZ: este job NUNCA escribia ZREING_CA_LOG_A. add_log( ) solo
    " hace APPEND a MT_LOG, una tabla interna que no llega a ninguna tabla de
    " base de datos, y run_pipeline persistia LINE_A, LPC_A, STEP_A y el
    " heartbeat sin una sola sentencia contra LOG_A. El where-used de LOG_A
    " confirmaba los escritores reales -- el pool de comportamiento,
    " ZCL_REING_CA_CONTAB_JOB, ZCL_REING_CA_CONTAB_RUNNER y
    " ZCL_REING_CA_ORPHAN_REC -- y el calc job no estaba entre ellos.
    "
    " Eso explica el sintoma exacto que reporto Rochelle: la unica entrada que
    " ve es el CREATE que escribe la accion Calculate del pool, que crea UNA
    " linea generica por grupo; las otras 13 las inserta ESTE job, sin log. En
    " TS4 las lineas 153..166 existen y el heartbeat prueba que el job corrio,
    " pero de line_num >= 150 solo 153 y 167 tienen un CREATE: 154..166 no
    " tienen ninguna fila de log. La transicion CALC_PROC -> CALC, es decir el
    " calculo en si, no dejaba rastro nunca.
    "
    " PRECISION SOBRE EL REPORTE: en los datos, ese grupo F se calculo UNA
    " sola vez (no hay filas RESET y las 14 lineas siguen vivas); la segunda
    " corrida que vio era de op_type P, otro grupo. El defecto es real, pero
    " es "el calculo no se loguea", no "el segundo calculo se pierde".
    "
    " LOG_NUM queda en 0 como placeholder -- lo resuelve write_logs, mismo
    " reparto de responsabilidades que run_contab_mode/persist_results en el
    " job de CONTAB.
    DATA(lv_now)  = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
    DATA(lv_proc) = zif_reing_ca_c=>line_status-calc_proc.

    " (a) Lineas REUSADAS: la generica que Calculate dejo en CALC_PROC y que
    "     la reconciliacion emparejo con una fila fisica existente. Su
    "     transicion real es CALC_PROC -> CALC / CALC_ERR, y ACTION-CALC
    "     ('CALC') ya existia en ZIF_REING_CA_C y en el dominio
    "     ZREING_CA_ACTION sin que nadie la usara.
    "     DO ... TIMES y no LOOP: los loops anidados son hallazgo P2 del ATC
    "     en este sistema y ya bloquearon una liberacion.
    DATA ls_upd LIKE LINE OF it_to_update.
    DATA lv_idx_u TYPE i VALUE 1.
    DO lines( it_to_update ) TIMES.
      READ TABLE it_to_update INTO ls_upd INDEX lv_idx_u.
      lv_idx_u = lv_idx_u + 1.
      APPEND VALUE #(
        calc_run_id = ls_upd-calc_run_id
        line_num    = ls_upd-line_num
        log_num     = 0
        action      = zif_reing_ca_c=>action-calc
        status_from = lv_proc
        status_to   = ls_upd-line_status
        created_by  = sy-uname
        created_at  = lv_now
        message     = |Calculate (job APJ): { lv_proc } -> { ls_upd-line_status }| &&
                      COND string( WHEN ls_upd-bukrs_recv IS NOT INITIAL
                                   THEN |, receptora { ls_upd-bukrs_recv }|
                                   ELSE `` ) ) TO rt_log.
    ENDDO.

    " (b) Lineas NUEVAS: receptoras 2..N de una expansion Path A/CM, que el
    "     job inserta y que hasta ahora no dejaban ninguna huella. STATUS_FROM
    "     va vacio porque la fila no existia antes -- no venia de CALC_PROC.
    DATA ls_ins LIKE LINE OF it_to_insert.
    DATA lv_idx_i TYPE i VALUE 1.
    DO lines( it_to_insert ) TIMES.
      READ TABLE it_to_insert INTO ls_ins INDEX lv_idx_i.
      lv_idx_i = lv_idx_i + 1.
      APPEND VALUE #(
        calc_run_id = ls_ins-calc_run_id
        line_num    = ls_ins-line_num
        log_num     = 0
        action      = zif_reing_ca_c=>action-create
        status_from = space
        status_to   = ls_ins-line_status
        created_by  = sy-uname
        created_at  = lv_now
        message     = |Calculate (job APJ): linea expandida en { ls_ins-line_status }| &&
                      COND string( WHEN ls_ins-bukrs_recv IS NOT INITIAL
                                   THEN |, receptora { ls_ins-bukrs_recv }|
                                   ELSE `` ) ) TO rt_log.
    ENDDO.
    " End Insert V005 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD write_logs.
    " Begin Insert V005 (15.09.2026 | EXT_GONZALCA)
    " Bug #68 -- renumerado de LOG_NUM e INSERT. Portado tal cual de
    " ZCL_REING_CA_CONTAB_JOB~persist_results, el job hermano que si escribe
    " su log: el problema y la solucion son identicos, y conviene que el
    " mecanismo sea el mismo en los dos.
    " SIN COMMIT: lo hace el llamador, una sola vez, para que el log y el
    " estado viajen en el MISMO LUW -- o estan los dos, o no esta ninguno.
    CHECK it_log IS NOT INITIAL.

    " MAX(log_num) ya persistido por (calc_run_id, line_num) -- una sola
    " sentencia, FUERA de todo loop. LINE_NUM no es unico global: la clave de
    " ZREING_CA_LOG_A es (calc_run_id, line_num, log_num), asi que el maximo
    " se agrupa por el par y no por line_num (fix V017 del pool). Es lo que
    " evita repetir el DBSQL_DUPLICATE_KEY_ERROR de fixes-010/012.
    " El run sale de la primera fila y no de una expresion tabular dentro del
    " WHERE: Open SQL no admite "@it_log[ 1 ]-campo" como host expression.
    READ TABLE it_log INTO DATA(ls_first) INDEX 1.
    DATA(lv_run_log) = ls_first-calc_run_id.

    DATA lt_num_rng TYPE RANGE OF zreing_ca_line_a-line_num.
    lt_num_rng = VALUE #( FOR ls_r IN it_log
      ( sign = 'I' option = 'EQ' low = ls_r-line_num ) ).
    SORT lt_num_rng.
    DELETE ADJACENT DUPLICATES FROM lt_num_rng COMPARING ALL FIELDS.

    SELECT calc_run_id, line_num, MAX( log_num ) AS max_num
      FROM zreing_ca_log_a
      WHERE calc_run_id = @lv_run_log
        AND line_num   IN @lt_num_rng
      GROUP BY calc_run_id, line_num
      INTO TABLE @DATA(lt_max).

    " Renumerado en memoria. El contador sigue incrementando dentro de la
    " MISMA linea para que dos entradas del mismo lote no colisionen.
    DATA lt_log_new TYPE zif_reing_ca_types=>ty_log_t.
    DATA ls_log     LIKE LINE OF it_log.
    DATA lv_idx     TYPE i VALUE 1.
    DATA lv_base    TYPE zreing_ca_log_a-log_num.
    DATA lv_next    TYPE zreing_ca_log_a-log_num.
    DO lines( it_log ) TIMES.
      READ TABLE it_log INTO ls_log INDEX lv_idx.
      lv_idx = lv_idx + 1.

      READ TABLE lt_log_new TRANSPORTING NO FIELDS
        WITH KEY calc_run_id = ls_log-calc_run_id line_num = ls_log-line_num.
      IF sy-subrc = 0.
        " Ya hay una entrada de ESTA linea en el lote: seguir su numeracion.
        lv_base = REDUCE zreing_ca_log_a-log_num( INIT n = 0
          FOR ls_prev IN lt_log_new WHERE ( line_num = ls_log-line_num )
          NEXT n = COND #( WHEN ls_prev-log_num > n THEN ls_prev-log_num ELSE n ) ).
      ELSE.
        lv_base = VALUE #( lt_max[ calc_run_id = ls_log-calc_run_id
                                   line_num    = ls_log-line_num ]-max_num DEFAULT 0 ).
      ENDIF.
      lv_next = lv_base + 1.

      ls_log-log_num = lv_next.
      APPEND ls_log TO lt_log_new.
    ENDDO.

    INSERT zreing_ca_log_a FROM TABLE @lt_log_new.
    " End Insert V005 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD lock_run.
    IF iv_run_id IS INITIAL OR iv_run_id CS '*'.
      add_log( 'Calculation requires an exact, noninitial RUN lock key' ).
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDIF.
    IF mv_locked_run IS NOT INITIAL.
      add_log( 'This calculation job instance already owns a RUN lock' ).
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDIF.
    TRY.
        TEST-SEAM an2_calc_lock_factory.
          mo_run_lock = cl_abap_lock_object_factory=>get_instance( 'EZREINGCARUN' ).
        END-TEST-SEAM.
        TEST-SEAM an2_calc_enqueue.
          mo_run_lock->enqueue(
            it_table_mode = VALUE #( ( table_name = 'ZREING_CA_RUN_A'
              mode = if_abap_lock_object=>cs_mode-exclusive_lock ) )
            it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( iv_run_id ) ) )
            _scope = if_abap_lock_object=>cs_scope-no_update_program
            _wait = if_abap_lock_object=>cs_wait-no ).
        END-TEST-SEAM.
        mv_locked_run = iv_run_id.
      CATCH cx_root INTO DATA(lx_lock).
        add_log( |RUN lock not acquired: { lx_lock->get_text( ) }| ).
        RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDTRY.
  ENDMETHOD.

  METHOD release_run.
    CHECK mv_locked_run IS NOT INITIAL.
    TRY.
        TEST-SEAM an2_calc_dequeue.
          mo_run_lock->dequeue(
            it_table_mode = VALUE #( ( table_name = 'ZREING_CA_RUN_A'
              mode = if_abap_lock_object=>cs_mode-exclusive_lock ) )
            it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( mv_locked_run ) ) )
            _scope = if_abap_lock_object=>cs_scope-no_update_program
            _synchronous = if_abap_lock_object=>cs_synchronous-yes ).
        END-TEST-SEAM.
        CLEAR mv_locked_run.
      CATCH cx_abap_lock_failure INTO DATA(lx_unlock).
        rv_message = lx_unlock->get_text( ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.


