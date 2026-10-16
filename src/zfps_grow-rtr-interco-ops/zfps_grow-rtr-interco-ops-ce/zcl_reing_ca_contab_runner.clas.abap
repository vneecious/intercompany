*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° : 5000049390                                          *
* Date           : 14.09.2026                                          *
* Description    : CA - Nucleo de CONTAB reusable (RAP + job APJ)      *
* Transport      : DS4K9B5XZC                                          *
*----------------------------------------------------------------------*
*
* Nucleo compartido de Simulate/Post/Storno (DD-F4-4). Los cuerpos vienen
* TAL CUAL de lcl_reing_ca_dml_buffer (pool ZBP_REINGCARUN), movidos --
* no reescritos -- con un solo cambio de contrato: los buffers estaticos
* del pool (gt_log / gt_line_f4 / gt_posted_evt / gt_reversed_evt) pasan a
* ser parametros de salida. Una clase global no puede -- ni debe -- tocar
* el estado de una clase local del behavior pool.
*
* Por que existe esta clase: ZCL_REING_CA_CONTAB_JOB (job step APJ de
* Post/Storno) es una clase GLOBAL y no ve lcl_reing_ca_dml_buffer, que es
* local al pool. Y el pool no puede ceder la logica por FRIENDS: una clase
* de comportamiento RAP solo admite como friend a una clase de test
* ("Here, FRIENDS is only allowed with local DEFERRED FOR TESTING
* classes", activacion real de V018). Mismo razonamiento que llevo el
* nucleo de lhc_ a lcl_ en V019; ahora sale un nivel mas.
*
* En lcl_reing_ca_dml_buffer quedan DELEGADORES con la firma intacta, para
* no tocar ltcl_contab_actions ni la definicion de la clase local.
*
* El TEST-SEAM "engine_process" viaja con el cuerpo de run_contab_mode y
* por lo tanto la TEST-INJECTION correspondiente vive ahora en la clase de
* test LOCAL de ESTA clase (los dos se asocian por nombre dentro del mismo
* pool de clases, nunca entre pools distintos).
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_contab_runner DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " "TYPE RANGE OF" inline no se admite en la firma de un metodo: exige un
    " tipo con nombre. Mismos dos tipos que declaraba lcl_reing_ca_dml_buffer.
    TYPES tt_run_id_range      TYPE RANGE OF zreing_ca_run_a-calc_run_id.
    TYPES tt_line_status_range TYPE RANGE OF zreing_ca_line_a-line_status.

    " Eventos de negocio RAP acumulados. NO se levantan aca: RAP exige que el
    " evento se dispare despues del punto de no retorno, o sea en
    " save_modified (DD-F4-2). El job APJ, que corre fuera de todo contexto
    " RAP, simplemente no los levanta -- ver la nota de ZCL_REING_CA_CONTAB_JOB.
    TYPES: BEGIN OF ty_posted_evt,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
             op_type     TYPE zreing_ca_line_a-op_type,
           END OF ty_posted_evt,
           tt_posted_evt TYPE STANDARD TABLE OF ty_posted_evt WITH EMPTY KEY.
    TYPES: BEGIN OF ty_reversed_evt,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num    TYPE zreing_ca_line_a-line_num,
           END OF ty_reversed_evt,
           tt_reversed_evt TYPE STANDARD TABLE OF ty_reversed_evt WITH EMPTY KEY.

    " Estado del doble de ZCL_REING_CONTAB_ENGINE para el TEST-INJECTION del
    " seam "engine_process". Vive aca, y no en la clase de test, por la misma
    " razon que lo llevo a lcl_reing_ca_dml_buffer en V016: el TEST-INJECTION
    " se compila en el CONTEXTO de run_contab_mode y no puede referenciar
    " componentes de una clase que se define mas adelante.
    CLASS-DATA gs_engine_result TYPE zif_reing_contab_types=>ty_process_result.
    CLASS-DATA gv_engine_raise  TYPE abap_bool.
    CLASS-DATA gv_engine_text   TYPE string.
    CLASS-DATA gv_engine_calls  TYPE i.
    " V001 (CC) - GAP-001: harmless reversal-check test seam fixture.
    CLASS-DATA gv_reversal_state TYPE c LENGTH 1.

    " Pre-lectura MASIVA unica para el conjunto COMPLETO de keys de la accion.
    " Es el unico punto con SELECTs del flujo F4 y se invoca UNA sola vez,
    " fuera del "LOOP AT keys" (BUG-002).
    CLASS-METHODS prefetch_contab_data
      IMPORTING it_run_rng TYPE tt_run_id_range
                it_groups  TYPE zreing_ca_tt_group_key
      EXPORTING et_lines   TYPE zif_reing_ca_types=>ty_line_t
                et_line_pc TYPE zif_reing_ca_types=>ty_line_pc_t
                et_step    TYPE zif_reing_ca_types=>ty_step_t.

    CLASS-METHODS run_contab_mode
      IMPORTING iv_run_id        TYPE zreing_ca_run_a-calc_run_id
                it_groups        TYPE zreing_ca_tt_group_key
                iv_mode          TYPE zreing_ca_contab_mode
                it_lines_all     TYPE zif_reing_ca_types=>ty_line_t
                it_pc_all        TYPE zif_reing_ca_types=>ty_line_pc_t
                it_step_all      TYPE zif_reing_ca_types=>ty_step_t
                it_reversal_check TYPE zcl_reing_contab_engine=>tt_reversal_check OPTIONAL
      EXPORTING et_msg           TYPE zif_reing_ca_types=>ty_log_t
                et_log           TYPE zif_reing_ca_types=>ty_log_t
                et_line_upd      TYPE zif_reing_ca_types=>ty_line_t
                et_posted_evt    TYPE tt_posted_evt
                et_reversed_evt  TYPE tt_reversed_evt
                ev_has_error     TYPE abap_bool.

    " Estados de origen admitidos por modo (CLAR-03 / SUP-01..03).
    CLASS-METHODS allowed_source_status
      IMPORTING iv_mode           TYPE zreing_ca_contab_mode
      RETURNING VALUE(rt_allowed) TYPE tt_line_status_range.

    " Punto UNICO de instanciacion del poster FI (CLAR-02).
    CLASS-METHODS get_fi_poster
      RETURNING VALUE(ro_poster) TYPE REF TO zif_reing_contab_fi_poster.
    " Agendamiento del job APJ de Post/Storno. Gemelo de
    " lsc_zi_reingcarun~schedule_calc_job, pero vive aca y no en el pool para
    " no tocar la DEFINICION de la clase local del behavior pool (que obliga a
    " reescribir el include entero). save_modified lo invoca desde su cuerpo.
    CLASS-METHODS schedule_contab_job
      IMPORTING iv_run_id           TYPE zreing_ca_run_a-calc_run_id
                iv_mode             TYPE zreing_ca_contab_mode
      EXPORTING ev_jobname          TYPE cl_apj_rt_api=>ty_jobname
      RETURNING VALUE(rv_warn_text) TYPE string.

ENDCLASS.



CLASS zcl_reing_ca_contab_runner IMPLEMENTATION.


  METHOD prefetch_contab_data.
    " Pre-lectura MASIVA del flujo F4, para el conjunto COMPLETO de keys de la
    " accion. Las 3 sentencias viven AQUI y este metodo se invoca UNA sola vez
    " por accion, ANTES del "LOOP AT keys" -- por eso ninguna queda dentro de un
    " loop (directo ni cruzando unidades de modularizacion).
    " SELECT * justificado y deliberado en la primera lectura: el contrato de
    " process_line recibe las estructuras COMPLETAS (zreing_ca_line_a /
    " ty_line_pc_t / ty_step_t), no un subconjunto de campos -- proyectar
    " columnas romperia la llamada (NB-002, D-10). Pseudo-comentario ATC
    " estandar (CI_ALL_FIELDS_NEEDED) en las 2 sentencias que el check
    " marcaba, documentando la misma justificacion sin cambiar logica.
    CLEAR: et_lines, et_line_pc, et_step.
    IF it_run_rng IS INITIAL OR it_groups IS INITIAL.
      RETURN.
    ENDIF.

    SELECT * FROM zreing_ca_line_a
      FOR ALL ENTRIES IN @it_groups
      WHERE calc_run_id IN @it_run_rng
        AND ct_uuid     = @it_groups-ct_uuid
        AND mat_uuid    = @it_groups-mat_uuid
        AND op_type     = @it_groups-op_type
        AND op_uuid     = @it_groups-op_uuid
        AND cm_h_id     = @it_groups-cm_h_id
        " V001 (CC) - #105: archived lines never enter another FI action.
        AND line_status <> @zif_reing_ca_c=>line_status-anuld
      INTO TABLE @et_lines.
    IF et_lines IS INITIAL.
      RETURN.
    ENDIF.

    DATA lt_num_rng_pf TYPE RANGE OF zreing_ca_line_a-line_num.
    lt_num_rng_pf = VALUE #( FOR ls_nr_pf IN et_lines
      ( sign = 'I' option = 'EQ' low = ls_nr_pf-line_num ) ).
    SORT lt_num_rng_pf.
    DELETE ADJACENT DUPLICATES FROM lt_num_rng_pf COMPARING ALL FIELDS.

    SELECT calc_run_id,
           line_num,
           pc_seq,
           prctr,
           campana,
           role_category,
           allocation,
           share_abs,
           calc_amt,
           bruto_amt,
           tax_amt,
           net_amt,
           ct_currency,
           net_local_amt,
           local_currency,
           " V001 (CC) - CB-01: retain persisted nominal transaction amounts.
           bruto_trans_amt,
           net_trans_amt
      FROM zreing_ca_lpc_a                                 "#EC CI_ALL_FIELDS_NEEDED
      WHERE calc_run_id IN @it_run_rng AND line_num IN @lt_num_rng_pf
      INTO CORRESPONDING FIELDS OF TABLE @et_line_pc.

    SELECT calc_run_id,
           line_num,
           step_num,
           seq,
           step_category,
           tax_type,
           tx_rule_id,
           step_desc,
           input_amt,
           input_currency,
           rate_pct,
           rate_desc,
           output_amt,
           output_currency,
           " V001 (CC) - CB-01: retain the persisted TAX/monetary snapshot.
           output_trans_amt,
           sign,
           source_table,
           source_key

      FROM zreing_ca_step_a                                "#EC CI_ALL_FIELDS_NEEDED
      WHERE calc_run_id IN @it_run_rng AND line_num IN @lt_num_rng_pf
      INTO CORRESPONDING FIELDS OF TABLE @et_step.
  ENDMETHOD.


  METHOD run_contab_mode.
    " Nucleo compartido de Simulate/Post/Storno (DD-F4-4).
    " Contrato del Engine (verificado en vivo, NO inferido):
    "   process_line( is_line_a, it_line_pc, it_step_a, iv_mode )
    "     RETURNING rs_result TYPE zif_reing_contab_types=>ty_process_result
    "     RAISING   zcx_reing_contab
    " El Engine valida el gatekeeping (validate_preconditions) contra
    " is_line_a-line_status: exige SIM_PROC (C) / POST_PROC (P) / ANUL_PROC (S).
    " Sin traduccion de estados (BR-F4-02): se le pasa el valor real.
    CLEAR: et_msg, et_log, et_line_upd, et_posted_evt, et_reversed_evt, ev_has_error.
    IF it_groups IS INITIAL.
      RETURN.
    ENDIF.

    " Constantes derivadas del modo -- una sola vez, fuera del loop de lineas.
    DATA(lv_action) = SWITCH zreing_ca_action( iv_mode
      WHEN zif_reing_ca_c=>contab_mode-check  THEN zif_reing_ca_c=>action-simulate
      WHEN zif_reing_ca_c=>contab_mode-post   THEN zif_reing_ca_c=>action-post
      WHEN zif_reing_ca_c=>contab_mode-storno THEN zif_reing_ca_c=>action-storno
      ELSE space ).
    " Estado *_PROC que CA fija en la COPIA que recibe el Engine (DD-F4-6):
    " process_line recibe is_line_a POR VALOR, asi que no hace falta
    " persistir el intermedio -- y no persistirlo evita dejar lineas colgadas
    " en *_PROC si la LUW hace rollback.
    DATA(lv_proc_status) = SWITCH zreing_ca_line_status( iv_mode
      WHEN zif_reing_ca_c=>contab_mode-check  THEN zif_reing_ca_c=>line_status-sim_proc
      WHEN zif_reing_ca_c=>contab_mode-post   THEN zif_reing_ca_c=>line_status-post_proc
      WHEN zif_reing_ca_c=>contab_mode-storno THEN zif_reing_ca_c=>line_status-anul_proc
      ELSE space ).
    " V001 (CC) - #105: successful FI reversal is terminal, retained for audit.
    DATA(lv_ok_status) = SWITCH zreing_ca_line_status( iv_mode
      WHEN zif_reing_ca_c=>contab_mode-check  THEN zif_reing_ca_c=>line_status-sim_ok
      WHEN zif_reing_ca_c=>contab_mode-post   THEN zif_reing_ca_c=>line_status-cont
      WHEN zif_reing_ca_c=>contab_mode-storno THEN zif_reing_ca_c=>line_status-anuld
      ELSE space ).
    " Destino de error: SIM_ERR (C) | POST_ERR (P) | NINGUNO (S).
    " BR-F4-07: en Storno el dominio no tiene estado terminal de error de
    " anulacion -> vacio significa "no transicionar" (la linea queda en CONT).
    DATA(lv_err_status) = SWITCH zreing_ca_line_status( iv_mode
      WHEN zif_reing_ca_c=>contab_mode-check  THEN zif_reing_ca_c=>line_status-sim_err
      WHEN zif_reing_ca_c=>contab_mode-post   THEN zif_reing_ca_c=>line_status-post_err
      WHEN zif_reing_ca_c=>contab_mode-storno THEN zif_reing_ca_c=>line_status-anul_err
      ELSE space ).

    " Begin Mod V016 (CC) - F4 [fix BUG-002] ---------------------------------
    " --- 0.a Recorte en memoria del scope de ESTA key -----------------------
    " it_lines_all trae las LINE_A de TODAS las keys de la accion (pre-lectura
    " unica hecha por prefetch_contab_data antes del LOOP AT keys). Aca solo se
    " filtra: cero acceso a base de datos en todo el resto del metodo.
    DATA lt_lines TYPE zif_reing_ca_types=>ty_line_t.
    DATA ls_pf_line LIKE LINE OF it_lines_all.
    DATA lv_idx_pf TYPE i VALUE 1.
    DO lines( it_lines_all ) TIMES.
      READ TABLE it_lines_all INTO ls_pf_line INDEX lv_idx_pf.
      lv_idx_pf = lv_idx_pf + 1.
      IF ls_pf_line-calc_run_id <> iv_run_id.
        CONTINUE.
      ENDIF.
      IF NOT line_exists( it_groups[ ct_uuid  = ls_pf_line-ct_uuid
                                     mat_uuid = ls_pf_line-mat_uuid
                                     op_type  = ls_pf_line-op_type
                                     op_uuid  = ls_pf_line-op_uuid
                                     cm_h_id  = ls_pf_line-cm_h_id ] ).
        CONTINUE.
      ENDIF.
      APPEND ls_pf_line TO lt_lines.
    ENDDO.

    " --- 0.b Guard de concurrencia (CU-10) ----------------------------------
    " Antes se delegaba en check_scope, que hace su propio SELECT sobre LINE_A.
    " Ese SELECT quedaba dentro de la unidad de modularizacion invocada por el
    " LOOP AT keys (misma familia que BUG-002). Como la pre-lectura ya trae la
    " fila COMPLETA de cada linea del scope -- sin filtro de estado -- el mismo
    " guard se resuelve en memoria, con semantica identica: bloquea los grupos
    " que tengan alguna linea en *_PROC (otra accion en vuelo).
    " V023: el guard NO puede mirar el *_PROC que corresponde a ESTE modo. Desde
    " que Post/Storno pasaron a job APJ, la linea llega a este metodo YA en
    " POST_PROC / ANUL_PROC -- ese estado es justamente el scope que el job leyo
    " de base, no una accion ajena en vuelo. Mirarlo bloquearia el 100% de los
    " jobs contra si mismos. Los otros dos *_PROC si se siguen mirando.
    DATA lt_blocked TYPE zreing_ca_tt_group_key.
    DATA ls_scan_line LIKE LINE OF lt_lines.
    DATA lv_idx_scan TYPE i VALUE 1.
    DO lines( lt_lines ) TIMES.
      READ TABLE lt_lines INTO ls_scan_line INDEX lv_idx_scan.
      lv_idx_scan = lv_idx_scan + 1.
      IF ls_scan_line-line_status <> 'CALC_PROC' AND ls_scan_line-line_status <> 'SIM_PROC'
     AND ls_scan_line-line_status <> 'POST_PROC' AND ls_scan_line-line_status <> 'ANUL_PROC'.
        CONTINUE.
      ENDIF.
      IF ls_scan_line-line_status = lv_proc_status.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( ct_uuid  = ls_scan_line-ct_uuid
                      mat_uuid = ls_scan_line-mat_uuid
                      op_type  = ls_scan_line-op_type
                      op_uuid  = ls_scan_line-op_uuid
                      cm_h_id  = ls_scan_line-cm_h_id ) TO lt_blocked.
    ENDDO.
    SORT lt_blocked BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_blocked
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
    " End Mod V016 (CC) - F4 -------------------------------------------------
    IF lt_blocked IS NOT INITIAL.
      APPEND VALUE zreing_ca_log_a(
        calc_run_id = iv_run_id
        action      = lv_action
        status_from = space
        status_to   = space
        created_by  = sy-uname
        message     = |{ lines( lt_blocked ) } grupo(s) del scope tienen lineas en proceso. Reintente al finalizar.| )
        TO et_msg.
      ev_has_error = abap_true.
      RETURN.
    ENDIF.

    " --- 1. Recorte en memoria de PC y STEP (cero SELECT en este metodo) ----
    " Las 3 lecturas masivas (LINE_A / LPC_A / STEP_A) viven en
    " prefetch_contab_data, invocado UNA sola vez por accion antes del
    " LOOP AT keys. lt_lines ya se construyo en el paso 0.a. NO reintroducir
    " NINGUN SELECT en este metodo: se ejecuta una vez por key.
    IF lt_lines IS INITIAL.
      APPEND VALUE zreing_ca_log_a(
        calc_run_id = iv_run_id
        action      = lv_action
        created_by  = sy-uname
        message     = 'No se encontraron lineas para el scope indicado' )
        TO et_msg.
      ev_has_error = abap_true.
      RETURN.
    ENDIF.

    " Mismo criterio que tenian los 2 SELECT originales (calc_run_id + los
    " line_num del scope), resuelto ahora sobre las tablas ya pre-leidas.
    DATA lt_all_pc TYPE zif_reing_ca_types=>ty_line_pc_t.
    lt_all_pc = VALUE #( FOR ls_pc_f IN it_pc_all
      WHERE ( calc_run_id = iv_run_id ) ( ls_pc_f ) ).

    DATA lt_all_step TYPE zif_reing_ca_types=>ty_step_t.
    lt_all_step = VALUE #( FOR ls_st_f IN it_step_all
      WHERE ( calc_run_id = iv_run_id ) ( ls_st_f ) ).

    " OB-002 (iteracion #2): AQUI IBA un "SELECT line_num, MAX( log_num )
    " ... GROUP BY line_num" para calcular el proximo log_num (D-4). Se
    " ELIMINA: la premisa era falsa contra el fuente real. Desde V011 los 3
    " handlers existentes (release/calculate/delete) escriben log_num = 0 como
    " placeholder y lsc_zi_reingcarun~save_modified recalcula el valor
    " definitivo de TODAS las filas de gt_log de forma centralizada. Calcular
    " aca un log_num propio era un SELECT agregado extra por invocacion, un
    " valor que save_modified sobrescribe, y una segunda "fuente de verdad"
    " que podia pisar la mecanica central.
    " V023: el job APJ NO pasa por save_modified, asi que recalcula el log_num
    " el mismo antes de insertar (ver ZCL_REING_CA_CONTAB_JOB~persist_results).

    " Engine: una instancia por linea es deliberado y necesario (mantiene
    " estado de instancia ms_line_a / mt_step_a / mv_mode y buffer de
    " documentos; reutilizarla arrastraria estado). El doble de ABAP Unit
    " entra por el TEST-SEAM "engine_process" (DD-F4-7 opcion b).
    DATA(lt_allowed) = allowed_source_status( iv_mode ).
    DATA(lv_allowed_txt) = REDUCE string( INIT s = `` FOR ls_al IN lt_allowed
      NEXT s = COND #( WHEN s IS INITIAL THEN |{ ls_al-low }| ELSE |{ s }, { ls_al-low }| ) ).
    DATA(lv_ts) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).

    " V001 (CC) - GAP-001: caller pre-checks in bulk, no SQL in this pure runner.
    DATA(lt_rev_check) = it_reversal_check.

    LOOP AT lt_lines INTO DATA(ls_line).

      DATA(ls_log) = VALUE zreing_ca_log_a(
        calc_run_id = iv_run_id
        line_num    = ls_line-line_num
        log_num     = 0   " placeholder, recalculado por el llamador (V011)
        action      = lv_action
        status_from = ls_line-line_status
        created_by  = sy-uname
        created_at  = lv_ts ).

      " --- 2. Validar estado de origen ANTES de tocar el Engine (CU-8) -----
      " La linea invalida se SALTA; el resto del scope continua -- misma
      " semantica de error por linea que release.
      IF NOT ls_line-line_status IN lt_allowed.
        ls_log-status_to = ls_line-line_status.
        ls_log-message   = |Estado { ls_line-line_status } no admitido para { lv_action } (admitidos: { lv_allowed_txt }).|.
        APPEND ls_log TO et_msg.
        APPEND ls_log TO et_log.
        ev_has_error = abap_true.
        CONTINUE.
      ENDIF.

      " --- 3. Invocar al Engine -------------------------------------------
      DATA(ls_line_call) = ls_line.
      ls_line_call-line_status = lv_proc_status.

      " Sub-tablas de la linea, calculadas FUERA del TEST-SEAM: el seam solo
      " debe contener la interaccion con el Engine, nada de la logica propia.
      DATA(lt_pc_line) = VALUE zif_reing_ca_types=>ty_line_pc_t(
        FOR ls_pc IN lt_all_pc   WHERE ( line_num = ls_line-line_num ) ( ls_pc ) ).
      DATA(lt_st_line) = VALUE zif_reing_ca_types=>ty_step_t(
        FOR ls_st IN lt_all_step WHERE ( line_num = ls_line-line_num ) ( ls_st ) ).

      DATA(lv_full_ok) = abap_false.
      DATA lv_msg_txt  TYPE string.
      DATA lv_awkey    TYPE zreing_ca_line_a-fi_awkey.
      DATA ls_result   TYPE zif_reing_contab_types=>ty_process_result.
      DATA lo_engine   TYPE REF TO zcl_reing_contab_engine.
      CLEAR: lv_msg_txt, lv_awkey, ls_result, lo_engine.

      TRY.
          " OB-003 (iteracion #2): punto de inyeccion de ABAP Unit.
          " ZCL_REING_CONTAB_ENGINE es "FINAL CREATE PUBLIC" en el servidor
          " real -> cl_abap_testdouble=>create( ) sobre ella NO compila y el
          " io_engine de la iteracion #1 no habilitaba ningun test. TEST-SEAM
          " es el mecanismo estandar para sustituir una dependencia FINAL sin
          " tocar su contrato publico (DD-F4-7 opcion b).
          " IMPORTANTE: todas las variables que se usan DESPUES del seam
          " (ls_result, lv_msg_txt, ...) estan declaradas ARRIBA, fuera de el:
          " cuando el test lo reemplaza, el codigo interno desaparece.
          " En produccion el seam es codigo normal: cero cambio de conducta.
          DATA(lv_skip_reverse) = abap_false.
          IF iv_mode = zif_reing_ca_c=>contab_mode-storno.
            DATA(ls_rev_check) = VALUE zcl_reing_contab_engine=>ty_reversal_check(
              lt_rev_check[ calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num ] OPTIONAL ).
            IF ls_rev_check-state = 'E' OR ls_rev_check-state IS INITIAL.
              RAISE EXCEPTION TYPE zcx_reing_contab
                EXPORTING iv_message = COND #( WHEN ls_rev_check-message IS NOT INITIAL
                  THEN ls_rev_check-message ELSE 'No se pudo verificar el estado FI de la linea' ).
            ENDIF.
            lv_skip_reverse = xsdbool( ls_rev_check-state = 'R'
              OR ( ls_rev_check-state = 'N' AND ls_line-line_status = zif_reing_ca_c=>line_status-post_err ) ).
          ENDIF.
          IF lv_skip_reverse = abap_false.
          TEST-SEAM engine_process.
            lo_engine = NEW zcl_reing_contab_engine( ).
            lo_engine->set_fi_poster( get_fi_poster( ) ).
            ls_result = lo_engine->process_line(
              is_line_a  = ls_line_call
              it_line_pc = lt_pc_line
              it_step_a  = lt_st_line
              iv_mode    = iv_mode ).
          END-TEST-SEAM.
          ENDIF.

          " BR-F4-03 / DD-F4-5: exito COMPLETO = ni error consolidado ni
          " error parcial. Mirar solo rs_result-has_error dispararia el
          " evento en un posteo parcialmente fallido (CU-6 / CU-15).
          lv_full_ok = xsdbool( ls_result-has_error = abap_false
            AND NOT line_exists( ls_result-documents[ has_error = abap_true ] ) ).

          IF lv_full_ok = abap_true.
            " Begin Mod V024 (16.09.2026 | EXT_GONZALCA)
            " Bug tracker #63. Desde que ZCL_REING_CONTAB_DOC~is_applicable
            " descarta las lineas de saldo cero (definicion de Rochelle del
            " 16.09.2026), process_line puede saltear TODOS los pasos del flujo
            " con STEP_SKIP y devolver un resultado exitoso SIN documentos. El
            " texto anterior producia entonces "POST OK: 0 documento(s)
            " procesado(s)", que deja al operador con una linea en CONT, sin
            " BELNR y sin ninguna explicacion -- facil de leer como un fallo
            " silencioso en una revision de auditoria.
            " No se nombra el saldo cero como CAUSA unica: is_applicable es un
            " contrato de la interfaz y cualquier procesadora futura puede
            " declararse no aplicable por otro motivo. Se describe el hecho
            " (ningun paso aplicable) y se menciona el caso tipico.
            " Statement original, para el registro:
            "    lv_msg_txt = |{ lv_action } OK: { lines( ls_result-documents ) } documento(s) procesado(s).|.
            lv_msg_txt = COND string(
              WHEN ls_result-documents IS INITIAL
                THEN |{ lv_action } OK: ningun paso del flujo resulto aplicable, no se genero | &&
                     |documento (caso tipico: linea con saldo cero).|
              ELSE |{ lv_action } OK: { lines( ls_result-documents ) } documento(s) procesado(s).| ).
            " End Mod V024 (16.09.2026 | EXT_GONZALCA)
            " FI_AWKEY: solo el modo P produce documento FI real. El Engine
            " persiste sus propias tablas (persist_all); CA solo refleja la
            " clave en su LINE_A.
            IF lv_skip_reverse = abap_true.
              lv_msg_txt = |STORNO OK: no quedan documentos FI pendientes de anular. { ls_rev_check-message }|.
            ENDIF.
            IF iv_mode = zif_reing_ca_c=>contab_mode-post
           AND line_exists( ls_result-documents[ has_error = abap_false ] ).
              DATA(ls_doc) = ls_result-documents[ has_error = abap_false ].
              IF ls_doc-belnr IS NOT INITIAL.
                lv_awkey = |{ ls_doc-belnr }{ ls_doc-gjahr }|.
              ENDIF.
            ENDIF.
          ELSE.
            " Begin Mod V021 (10.09.2026 | EXT_GONZALCA)
            " ET-REING-CA-001 v50 SS4.2 defines SIM_MESSAGE as "Ultimo mensaje
            " de simulacion/posting" -- a MESSAGE, not a counter. The replaced
            " text carried only counters and dropped the Engine's error text
            " entirely, which is where the reason the FI document was rejected
            " actually lives. The operator saw "POST con error: 1 de 1
            " documento(s) en error." and the cause had to be dug out of
            " ZREING_CB_TRC_A by a developer (reported by Paola Romero on
            " RUN-202609 / contract IC-0007).
            "
            " The "N de M" ratio is dropped: lines( documents ) counts the
            " documents ATTEMPTED, not the steps PLANNED by the flow.
            " What that ratio DID carry and must NOT be lost (CU-6 / CU-15):
            " on a PARTIAL failure some FI documents were really posted and
            " hold a live BELNR. That is now stated explicitly instead of
            " being implied by a ratio the operator had to interpret.
            "
            " ERROR_MSG is read from the failing DOCUMENT first and from the
            " consolidated result second: on a partial failure has_error is
            " abap_false at result level and the text exists ONLY on the
            " document. On the normal path process_line copies document ->
            " result, so both agree and the order is harmless.
            DATA ls_err_doc    TYPE zif_reing_contab_types=>ty_step_result.
            DATA lv_err_head   TYPE string.
            DATA lv_err_detail TYPE string.
            DATA lv_posted_cnt TYPE i.
            DATA lv_posted_txt TYPE string.

            ls_err_doc = VALUE #( ls_result-documents[ has_error = abap_true ] OPTIONAL ).

            lv_err_head = COND string(
              WHEN ls_err_doc-doc_type_code IS NOT INITIAL
                THEN |{ lv_action } con error en el documento { ls_err_doc-doc_type_code }|
              ELSE |{ lv_action } con error| ).

            lv_err_detail = COND string(
              WHEN ls_err_doc-error_msg IS NOT INITIAL THEN |{ ls_err_doc-error_msg }|
              WHEN ls_result-error_msg  IS NOT INITIAL THEN |{ ls_result-error_msg }|
              ELSE |sin detalle devuelto por el motor de contabilizacion| ).

            " Documentos del flujo que SI quedaron generados con BELNR real.
            " El test de BELNR va en NEXT y no en WHERE: mantiene la expresion
            " FOR ... WHERE ( <una comparacion> ), que es la forma ya usada en
            " este codigo y validada por ATC. Un LOOP AT aqui seria un loop
            " anidado dentro de LOOP AT lt_lines -- hallazgo P2 del ATC.
            " En modo C (Simulate) no hay BELNR, asi que el contador da 0 y el
            " texto no se agrega: correcto sin necesidad de discriminar modo.
            lv_posted_cnt = REDUCE i( INIT n = 0
              FOR ls_ok IN ls_result-documents WHERE ( has_error = abap_false )
              NEXT n = COND i( WHEN ls_ok-belnr IS NOT INITIAL THEN n + 1 ELSE n ) ).
            lv_posted_txt = COND string(
              WHEN lv_posted_cnt > 0
                THEN | ({ lv_posted_cnt } documento(s) FI ya generado(s)).|
              ELSE || ).

            lv_msg_txt = |{ lv_err_head }: { lv_err_detail }{ lv_posted_txt }|.
            " End Mod V021 (10.09.2026 | EXT_GONZALCA)
          ENDIF.

        CATCH zcx_reing_contab INTO DATA(lx_contab).
          " El mensaje del Engine (incluye el rechazo de
          " check_auto_reversal_guard cuando el OP_TYPE usa anulacion
          " automatica, BR-CA-37 / CU-7) se propaga TAL CUAL a sim_message y
          " a et_msg -- CA no lo reinterpreta ni lo duplica.
          " BUG-004 (QA iteracion #2): ZCX_REING_CONTAB no redefine get_text()
          " (hereda de cx_static_check sin TEXTID) -- get_text() devuelve el
          " generico "An exception was raised.". El mensaje real vive en el
          " atributo publico mv_message, mismo patron que ZCX_REING_CA_CALC_ERROR
          " ya usa en release/calculate.
          lv_full_ok = abap_false.
          lv_msg_txt = lx_contab->mv_message.
      ENDTRY.

      " --- 4. Estado final -> buffer (nunca UPDATE directo aqui) -----------
      "   C: SIM_OK / SIM_ERR | P: CONT / POST_ERR
      "   S: ANULD / (sin transicion: la linea permanece en CONT, BR-F4-07)
      " V023: en Storno con error la linea vuelve a CONT y NO se queda en el
      " ANUL_PROC con el que el job la leyo -- ls_line-line_status ya no sirve
      " como "estado sin transicion" cuando el llamador es el job. Se usa el
      " estado de origen admitido, que para Storno es exactamente CONT.
      DATA(lv_new_status) = COND zreing_ca_line_status(
        WHEN lv_full_ok = abap_true       THEN lv_ok_status
        WHEN lv_err_status IS NOT INITIAL THEN lv_err_status
        WHEN ls_line-line_status = lv_proc_status
                                          THEN zif_reing_ca_c=>line_status-cont
        ELSE ls_line-line_status ).

      DATA(ls_line_upd) = ls_line.
      ls_line_upd-line_status = lv_new_status.
      ls_line_upd-sim_message = lv_msg_txt.   " CHAR220: truncado por asignacion
      IF lv_awkey IS NOT INITIAL.
        ls_line_upd-fi_awkey = lv_awkey.
      ENDIF.
      APPEND ls_line_upd TO et_line_upd.

      " --- 5. LOG_A --------------------------------------------------------
      " En el error de Storno: status_from = status_to = 'CONT' (la
      " transicion NO ocurrio) y el message lleva el texto del Engine -- es
      " un registro de intento fallido, no de transicion (DD-F4-12).
      ls_log-status_to = lv_new_status.
      ls_log-message   = lv_msg_txt.
      APPEND ls_log TO et_msg.
      APPEND ls_log TO et_log.
      IF lv_full_ok = abap_false.
        ev_has_error = abap_true.
      ENDIF.

      " --- 6. Eventos (solo exito completo; Simulate nunca dispara) --------
      IF lv_full_ok = abap_true.
        CASE iv_mode.
          WHEN zif_reing_ca_c=>contab_mode-post.
            APPEND VALUE #( calc_run_id = iv_run_id
                            line_num    = ls_line-line_num
                            op_type     = ls_line-op_type )
              TO et_posted_evt.
          WHEN zif_reing_ca_c=>contab_mode-storno.
            APPEND VALUE #( calc_run_id = iv_run_id
                            line_num    = ls_line-line_num )
              TO et_reversed_evt.
        ENDCASE.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.


  METHOD allowed_source_status.
    " Sin traduccion de estados (BR-F4-02): valores reales del dominio.
    " Corolario: una linea en cualquier *_PROC NO es origen admitido en
    " ningun modo -> el guard de concurrencia de CU-10 queda cubierto por
    " esta matriz, ademas de por check_scope.
    " V023: Post y Storno admiten ADEMAS su propio *_PROC, porque desde que
    " corren como job APJ la linea llega ya marcada -- POST_PROC/ANUL_PROC ES
    " el scope que el job leyo de base. Sin esto el job rechazaria el 100% de
    " sus propias lineas con "Estado POST_PROC no admitido para POST".
    rt_allowed = SWITCH #( iv_mode
      " C: simular una linea calculada, o reintentar una simulacion fallida
      WHEN zif_reing_ca_c=>contab_mode-check  THEN VALUE #(
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-calc )
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-sim_err ) )
      " P: solo lineas liberadas; re-post exclusivamente desde POST_ERR (BR-CA-36)
      WHEN zif_reing_ca_c=>contab_mode-post   THEN VALUE #(
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-libd )
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-post_err )
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-post_proc ) )
      " S: solo lineas efectivamente contabilizadas (BR-CA-37)
      WHEN zif_reing_ca_c=>contab_mode-storno THEN VALUE #(
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-cont )
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-post_err )
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-anul_err )
        ( sign = 'I' option = 'EQ' low = zif_reing_ca_c=>line_status-anul_proc ) )
      ELSE VALUE #( ) ).
  ENDMETHOD.


  METHOD get_fi_poster.
    " CLAR-02 resuelta (05.08.2026): instanciacion DIRECTA del poster FI, sin
    " adapter intermedio (ZCL_REING_CA_CONTAB_ADAPTER quedo descartado).
    " ZCL_REING_CONTAB_FI_POSTER vive en ZSFPS_GROW-RTR-WRAPPERS (Standard
    " ABAP) y su contrato C1 esta NOT_RELEASED -- el Engine se abstiene a
    " proposito de instanciarlo ("frontera Cloud/Tier2"). Riesgo ACEPTADO:
    " puede producir un hallazgo ATC de API no liberada (V-03), que no
    " bloquea la entrega; el seguimiento es FUP-F4-01. Se mantiene aislado en
    " este metodo unico para que, si algun dia se pasa a un adapter Tier-2,
    " el cambio cueste UN solo metodo.
    ro_poster = zcl_reing_contab_fi_poster=>create( ).
  ENDMETHOD.

  METHOD schedule_contab_job.
    " Agendamiento via CL_APJ_RT_API=>SCHEDULE_JOB, identico al de Calculate.
    " Si el SAJT 'ZREING_CA_CONTAB_JOBT' no existe todavia (alta manual en
    " Eclipse, gemela de F3.2-H1), cl_apj_rt_api lanza CX_TEMPLATE_DOESNT_EXIST
    " (subclase de CX_APJ_RT). Se atrapa SIEMPRE: save_modified no puede fallar
    " -- contrato RAP. El efecto de no agendar es que las lineas quedan en
    " POST_PROC / ANUL_PROC y el operador ve el warning, que es exactamente el
    " comportamiento degradado que ya tiene Calculate.
    " No escribe a "reported": ese tipo es especializado por el compilador para
    " cada redefinicion y no se puede pasar entre metodos (fix it.11 del
    " schedule_calc_job original). Devuelve el texto y el llamador arma el
    " mensaje con su propio "reported" nativo.
    TRY.
        DATA(lv_run_id) = iv_run_id.
        DATA(lv_mode)   = iv_mode.
        DATA(lv_text)   = COND string(
          WHEN iv_mode = zif_reing_ca_c=>contab_mode-storno
            THEN |CA Storno { lv_run_id }|
          ELSE |CA Post { lv_run_id }| ).

        " CONV #( ): IV_JOB_TEXT no es STRING y el compilador no convierte una
        " variable STRING de forma implicita en la llamada ("LV_TEXT is not
        " type-compatible with formal parameter IV_JOB_TEXT", syntax check real
        " del servidor). El literal template que usa schedule_calc_job si pasa,
        " pero aca el texto depende del modo y necesita una variable.
        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = 'ZREING_CA_CONTAB_JOBT'
            iv_job_text            = CONV #( lv_text )
            is_start_info          = VALUE #( start_immediately = abap_true )
            it_job_parameter_value = VALUE #(
              ( name = 'P_RUNID' t_value = VALUE #( ( sign = 'I' option = 'EQ' low = lv_run_id ) ) )
              ( name = 'P_MODE'  t_value = VALUE #( ( sign = 'I' option = 'EQ' low = lv_mode ) ) ) )
          IMPORTING
            ev_jobname  = ev_jobname
            ev_jobcount = DATA(lv_jobcount) ).
      CATCH cx_apj_rt INTO DATA(lx_apj).
        rv_warn_text = |No se pudo agendar el job de contabilizacion: { lx_apj->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

