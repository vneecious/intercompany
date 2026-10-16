*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° : 5000049390                                          *
* Date           : 14.09.2026                                          *
* Description    : CA - Job Step APJ para Post/Storno (CONTAB)         *
* Transport      : DS4K9B5XZC                                          *
*----------------------------------------------------------------------*
*
* Post y Storno de la app CA, ejecutados FUERA del contrato transaccional
* de RAP. Estructura 1:1 con ZCL_REING_CA_CALC_JOB (F3.2), que ya hace lo
* mismo para Calculate.
*
* POR QUE EXISTE (dump ST22 BEHAVIOR_ILLEGAL_STATEMENT_20260914_142941,
* TS4-400, RUN-202601 linea 26, contrato IC-0007):
* las BAPIs de FI no toleran ninguna de las dos fases de RAP.
*   - Fase de interaccion: BAPI_ACC_DOCUMENT_POST / _REV_POST registran
*     CALL FUNCTION IN UPDATE TASK, prohibido bajo strict ( 2 ).
*   - Fase SAVE: BAPI_ACC_DOCUMENT_CHECK -- que la BAPI de posteo corre
*     tambien por dentro -- llega a un AUTHORITY-CHECK a traves de la
*     cadena estandar de FI (CHECK_COBL -> FI_VALIDATION_ITEM ->
*     validacion OB28 "MELI_P" paso 019 -> FORM U128 de ZRGGBR000 ->
*     G_SET_FETCH del set ZFI_CLASE_DOC_U128 con NO_AUTHORITY_CHECK
*     vacio), y la fase SAVE prohibe AUTHORITY-CHECK.
* Ese AUTHORITY-CHECK no esta en codigo propio y no se puede quitar sin
* tocar ZRGGBR000, que es objeto FI cross del cliente -- y detras quedan
* F_BKPF_BLA (LFACIFSP), cl_sacf=>auth_check_spec y cualquier validacion
* GGB0 que FI agregue en el futuro. La unica salida estable es sacar
* CONTAB del contexto transaccional, que es lo que hace este job.
*
* Simulate NO pasa por aca: en modo 'C' el poster FI se detiene en el
* CHECK y el Engine solo bufferiza, asi que corre en la fase de
* interaccion (ZBP_REINGCARUN~simulate, V022).
*
* V001 (CC) - AN2 APJ: invoke the existing regenerator after FI commit.
* No RAP event is raised from this job. The local RAP event consumer
* exists and has a separate controlled transaction; its historical
* comments are not the transaction contract for this APJ bridge.
*
* PASO MANUAL POST-ACTIVACION (gemelo de F3.2-H1):
*   Crear en Eclipse ADT el SAJC y el SAJT 'ZREING_CA_CONTAB_JOBT'
*   apuntando a esta clase. Sin ese paso, Post/Storno dejan la linea en
*   POST_PROC / ANUL_PROC y el agendamiento emite un warning degradado
*   (CX_TEMPLATE_DOESNT_EXIST capturado en
*   lsc_zi_reingcarun~schedule_contab_job).
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_contab_job DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES:
      if_oo_adt_classrun,
      if_apj_dt_exec_object,
      if_apj_rt_exec_object.

    METHODS execute
      IMPORTING iv_run_id TYPE zreing_ca_run_a-calc_run_id
                iv_mode   TYPE zreing_ca_contab_mode
      RAISING   cx_apj_rt_content.

    " V001 (CC) - Backend recovery of exact origins outside RAP; no FI repost.
    METHODS retry_ant_derivations
      IMPORTING it_origins TYPE zcl_reing_ca_an2_regenerator=>tt_origin
      RETURNING VALUE(rs_result) TYPE zcl_reing_ca_an2_regenerator=>ty_batch_result.

  PRIVATE SECTION.
    METHODS process_ant_derivations
      IMPORTING it_origins TYPE zcl_reing_ca_an2_regenerator=>tt_origin
                iv_defer_reason TYPE zreing_ca_log_a-message OPTIONAL
      RETURNING VALUE(rs_result) TYPE zcl_reing_ca_an2_regenerator=>ty_batch_result.
    METHODS classify_ant_fi
      IMPORTING it_origins TYPE zcl_reing_ca_an2_regenerator=>tt_origin
                it_lines TYPE zif_reing_ca_types=>ty_line_t
                it_docs TYPE zcl_reing_contab_engine=>tt_reversal_docs
                it_journal TYPE zcl_reing_contab_engine=>tt_journal
      RETURNING VALUE(rt_rows) TYPE zcl_reing_ca_an2_regenerator=>tt_batch_row.
    METHODS build_an2_logs
      IMPORTING it_rows TYPE zcl_reing_ca_an2_regenerator=>tt_batch_row
                it_lines TYPE zif_reing_ca_types=>ty_line_t
      RETURNING VALUE(rt_log) TYPE zif_reing_ca_types=>ty_log_t.
    METHODS write_an2_logs IMPORTING it_log TYPE zif_reing_ca_types=>ty_log_t.
    METHODS normalize_failed_batch
      IMPORTING it_eligible TYPE zcl_reing_ca_an2_regenerator=>tt_origin
                iv_message TYPE zreing_ca_log_a-message
      CHANGING ct_rows TYPE zcl_reing_ca_an2_regenerator=>tt_batch_row.
    DATA mt_log TYPE string_table.

    METHODS add_log
      IMPORTING iv_message TYPE string.

    " Estado *_PROC que el handler dejo persistido y que define el scope del
    " job: POST_PROC (P) / ANUL_PROC (S). Vacio => modo no soportado.
    METHODS proc_status_for_mode
      IMPORTING iv_mode          TYPE zreing_ca_contab_mode
      RETURNING VALUE(rv_status) TYPE zreing_ca_line_status.

    METHODS persist_results
      IMPORTING it_line_upd TYPE zif_reing_ca_types=>ty_line_t
                it_log      TYPE zif_reing_ca_types=>ty_log_t.

    " V001 (CC) - Devengo: consume la cuota D y su cuota A padre solo
    " despues de una contabilizacion completa y exitosa.
    METHODS mark_defer_cron_ex
      IMPORTING iv_run_id  TYPE zreing_ca_run_a-calc_run_id
                iv_mode    TYPE zreing_ca_contab_mode
                it_line_upd TYPE zif_reing_ca_types=>ty_line_t.

    " Red de seguridad: termina las lineas que quedaron en *_PROC cuando el
    " job aborta por una excepcion tecnica. Calcada de la homonima de
    " ZCL_REING_CA_CALC_JOB (V002, 03.09.2026).
    METHODS terminate_pending_lines
      IMPORTING iv_run_id  TYPE zreing_ca_run_a-calc_run_id
                iv_mode    TYPE zreing_ca_contab_mode
                iv_message TYPE string.

ENDCLASS.



CLASS zcl_reing_ca_contab_job IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    " Debug/test directo desde ADT sin framework APJ.
    " ej. execute( iv_run_id = 'RUN-202601' iv_mode = 'P' ).
  ENDMETHOD.


  METHOD if_apj_dt_exec_object~get_parameters.
    " Declara P_RUNID y P_MODE para el Job Catalog Entry (SAJC/SAJT).
    et_parameter_def = VALUE #(
      ( selname        = 'P_RUNID'
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'CHAR'
        length         = 20
        param_text     = 'CalcRun ID'
        changeable_ind = abap_true
        mandatory_ind  = abap_true )
      ( selname        = 'P_MODE'
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'CHAR'
        length         = 1
        param_text     = 'Modo CONTAB (P=Post, S=Storno)'
        changeable_ind = abap_true
        mandatory_ind  = abap_true ) ).
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    " Punto de entrada APJ: parsea IT_PARAMETERS y delega a execute().
    " CX_APJ_RT_CONTENT declarado por la interfaz (sin gap de contrato).
    DATA lv_run_id TYPE zreing_ca_run_a-calc_run_id.
    DATA lv_mode   TYPE zreing_ca_contab_mode.
    LOOP AT it_parameters INTO DATA(ls_param).
      CASE ls_param-selname.
        WHEN 'P_RUNID'.
          lv_run_id = ls_param-low.
        WHEN 'P_MODE'.
          lv_mode = ls_param-low.
      ENDCASE.
    ENDLOOP.
    TRY.
        execute( iv_run_id = lv_run_id iv_mode = lv_mode ).
      CATCH cx_apj_rt_content INTO DATA(lx_error).
        RAISE EXCEPTION lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD execute.
    " 1) Lee de base el scope que el handler dejo marcado en *_PROC -- misma
    "    mecanica que ZCL_REING_CA_CALC_JOB con CALC_PROC. El scope NO viaja
    "    por parametros del job: las group keys son 4 UUIDs por grupo y no
    "    entran en un parametro de seleccion.
    " 2) Pre-lectura masiva + warm_config (una sola vez, fuera de todo loop).
    " 3) run_contab_mode -- aqui ocurre el posteo FI real.
    " 4) Persistencia y COMMIT.
    CHECK iv_run_id IS NOT INITIAL.

    DATA(lv_proc_status) = proc_status_for_mode( iv_mode ).
    IF lv_proc_status IS INITIAL.
      add_log( |Modo { iv_mode } no soportado por este job (solo P / S)| ).
      RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDIF.

    SELECT calc_run_id, line_num, ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id
      FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_run_id
        AND line_status = @lv_proc_status
      INTO TABLE @DATA(lt_lines).
    CHECK lt_lines IS NOT INITIAL.

    DATA lt_scope TYPE zreing_ca_tt_group_key.
    LOOP AT lt_lines INTO DATA(ls_line).
      APPEND VALUE #( ct_uuid  = ls_line-ct_uuid
                      mat_uuid = ls_line-mat_uuid
                      op_type  = ls_line-op_type
                      op_uuid  = ls_line-op_uuid
                      cm_h_id  = ls_line-cm_h_id ) TO lt_scope.
    ENDLOOP.
    SORT lt_scope BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
    DELETE ADJACENT DUPLICATES FROM lt_scope
      COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.

    DATA lt_run_rng TYPE zcl_reing_ca_contab_runner=>tt_run_id_range.
    lt_run_rng = VALUE #( ( sign = 'I' option = 'EQ' low = iv_run_id ) ).

    DATA lv_fi_commit_rc TYPE sysubrc.
    DATA lt_posted TYPE zcl_reing_ca_contab_runner=>tt_posted_evt.
    TRY.
        zcl_reing_ca_contab_runner=>prefetch_contab_data(
          EXPORTING it_run_rng = lt_run_rng
                    it_groups  = lt_scope
          IMPORTING et_lines   = DATA(lt_pf_line)
                    et_line_pc = DATA(lt_pf_pc)
                    et_step    = DATA(lt_pf_step) ).

        " V001 (CC) - GAP-001: only lines explicitly queued by the action.
        DELETE lt_pf_line WHERE line_status <> lv_proc_status.
        zcl_reing_contab_engine=>warm_config( lt_pf_line ).
        DATA lt_rev_check TYPE zcl_reing_contab_engine=>tt_reversal_check.
        IF iv_mode = zif_reing_ca_c=>contab_mode-storno.
          lt_rev_check = zcl_reing_contab_engine=>precheck_reversal( lt_pf_line ).
        ENDIF.

        zcl_reing_ca_contab_runner=>run_contab_mode(
          EXPORTING iv_run_id    = iv_run_id
                    it_groups    = lt_scope
                    iv_mode      = iv_mode
                    it_lines_all = lt_pf_line
                    it_pc_all    = lt_pf_pc
                    it_step_all  = lt_pf_step
                    it_reversal_check = lt_rev_check
          IMPORTING et_log       = DATA(lt_log)
                    et_line_upd  = DATA(lt_line_upd)
                    et_posted_evt = lt_posted ).

        " flush_documents ANTES del UPDATE de LINE_A, mismo orden que
        " lsc_zi_reingcarun~save_modified. Si rechaza el lote, se descarta
        " TODO con ROLLBACK: aca -- a diferencia del saver -- estamos antes
        " del COMMIT, asi que el rollback tambien descarta los CALL FUNCTION
        " IN UPDATE TASK que el poster FI ya registro y NO queda ningun
        " documento FI posteado sin su fila en ZREING_CB_DOC_A.
        zcl_reing_contab_engine=>flush_documents( ).

        persist_results( it_line_upd = lt_line_upd
                         it_log      = lt_log ).
        " V001 (CC) - #105: close cancelled usage in the same persistence LUW.
        IF iv_mode = zif_reing_ca_c=>contab_mode-storno.
          DATA(lo_usage_mgr) = NEW zcl_reing_ca_insumo_mgr(
            io_sources = NEW zcl_reing_ca_sources( ) ).
          lo_usage_mgr->revert_usage_bulk( lt_line_upd ).
        ENDIF.
        mark_defer_cron_ex( iv_run_id   = iv_run_id
                            iv_mode     = iv_mode
                            it_line_upd = lt_line_upd ).
        IF iv_mode = zif_reing_ca_c=>contab_mode-post
            AND line_exists( lt_posted[ op_type = 'ANT' ] ).
          TEST-SEAM an2_fi_commit.
            COMMIT WORK AND WAIT.
            lv_fi_commit_rc = sy-subrc.
          END-TEST-SEAM.
        ELSE.
          COMMIT WORK.
        ENDIF.

      CATCH zcx_reing_contab INTO DATA(lx_contab).
        add_log( |Rechazo del motor de contabilizacion: { lx_contab->mv_message }| ).
        terminate_pending_lines( iv_run_id  = iv_run_id
                                 iv_mode    = iv_mode
                                 iv_message = lx_contab->mv_message ).
        RAISE EXCEPTION TYPE cx_apj_rt_content.

      CATCH cx_root INTO DATA(lx_tech).
        " Misma red de seguridad que ZCL_REING_CA_CALC_JOB~execute (V002):
        " sin esto, una excepcion TECNICA deja TODAS las lineas del run en
        " *_PROC, sin mensaje, y el reintento vuelve a leer la misma linea
        " envenenada.
        DATA(lv_exc_name) = cl_abap_typedescr=>describe_by_object_ref(
                              lx_tech )->get_relative_name( ).
        DATA(lv_tech_msg) = |Error tecnico { lv_exc_name }: { lx_tech->get_text( ) }|.
        add_log( |Error fatal no controlado: { lv_tech_msg }| ).
        terminate_pending_lines( iv_run_id  = iv_run_id
                                 iv_mode    = iv_mode
                                 iv_message = lv_tech_msg ).
        RAISE EXCEPTION TYPE cx_apj_rt_content.
    ENDTRY.

    " V001 (CC) - Second LUW is outside the original FI terminalization CATCH.
    IF iv_mode = zif_reing_ca_c=>contab_mode-post AND lt_posted IS NOT INITIAL.
      DATA(lt_origins) = VALUE zcl_reing_ca_an2_regenerator=>tt_origin(
        FOR ls_posted IN lt_posted WHERE ( op_type = 'ANT' )
        ( origin_run_id = ls_posted-calc_run_id origin_line_num = ls_posted-line_num ) ).
      IF lt_origins IS NOT INITIAL.
        DATA lv_commit_message TYPE zreing_ca_log_a-message.
        IF lv_fi_commit_rc <> 0.
          lv_commit_message = 'Original V1 update completion could not be confirmed'.
        ENDIF.
        DATA(ls_derivation) = process_ant_derivations(
          it_origins = lt_origins iv_defer_reason = lv_commit_message ).
        IF ls_derivation-failed = abap_true.
          add_log( |AN2 postprocessing failed: { ls_derivation-message }| ).
          RAISE EXCEPTION TYPE cx_apj_rt_content.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD mark_defer_cron_ex.
    " V001 (CC) - Devengo: la cuota se consume al CONTABILIZAR, no al
    " calcular. Solo un lote D completamente contabilizado consume tanto
    " la cuota D como la cuota A padre del mismo periodo.
    IF iv_mode <> zif_reing_ca_c=>contab_mode-post
       OR it_line_upd IS INITIAL.
      RETURN.
    ENDIF.

    TYPES:
      BEGIN OF ty_defer_opt,
        ct_uuid        TYPE zreing_ct2_opt_a-ct_uuid,
        mat_uuid       TYPE zreing_ct2_opt_a-mat_uuid,
        child_op_type  TYPE zreing_ct2_opt_a-op_type,
        child_op_uuid  TYPE zreing_ct2_opt_a-op_uuid,
        parent_op_type TYPE zreing_ct2_opt_a-op_type,
        parent_op_uuid TYPE zreing_ct2_opt_a-op_uuid,
      END OF ty_defer_opt,
      BEGIN OF ty_failed_opt,
        ct_uuid       TYPE zreing_ca_line_a-ct_uuid,
        mat_uuid      TYPE zreing_ca_line_a-mat_uuid,
        child_op_type TYPE zreing_ca_line_a-op_type,
        child_op_uuid TYPE zreing_ca_line_a-op_uuid,
      END OF ty_failed_opt,
      BEGIN OF ty_cron_key,
        ct_uuid  TYPE zreing_ct2_crn_a-ct_uuid,
        mat_uuid TYPE zreing_ct2_crn_a-mat_uuid,
        op_type  TYPE zreing_ct2_crn_a-op_type,
        op_uuid  TYPE zreing_ct2_crn_a-op_uuid,
      END OF ty_cron_key.

    DATA lv_initial_parent TYPE zreing_ct2_opt_a-parent_instance_id.
    DATA lt_defer_opt TYPE STANDARD TABLE OF ty_defer_opt WITH EMPTY KEY.

    " La relacion nueva usa PARENT_INSTANCE_ID. El segundo brazo conserva
    " compatibilidad con contratos TS4 existentes, como IC-0008.
    SELECT child~ct_uuid,
           child~mat_uuid,
           child~op_type AS child_op_type,
           child~op_uuid AS child_op_uuid,
           cfg~parent_type AS parent_op_type,
           parent~op_uuid AS parent_op_uuid
      FROM zreing_ct2_opt_a AS child
      INNER JOIN zreing_op_type_c AS cfg
        ON cfg~op_type = child~op_type
      INNER JOIN zreing_ct2_opt_a AS parent
        ON parent~ct_uuid = child~ct_uuid
       AND parent~mat_uuid = child~mat_uuid
       AND parent~op_type = cfg~parent_type
       AND ( ( child~parent_instance_id <> @lv_initial_parent
               AND parent~op_uuid = child~parent_instance_id )
          OR ( child~parent_instance_id = @lv_initial_parent
               AND parent~op_instance_num = child~op_instance_num ) )
      FOR ALL ENTRIES IN @it_line_upd
      WHERE child~ct_uuid = @it_line_upd-ct_uuid
        AND child~mat_uuid = @it_line_upd-mat_uuid
        AND child~op_type = @it_line_upd-op_type
        AND child~op_uuid = @it_line_upd-op_uuid
        AND cfg~parent_type = @zif_reing_ca_c=>optype_root-defer_parent
        AND cfg~active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @lt_defer_opt.

    SORT lt_defer_opt BY ct_uuid mat_uuid child_op_type child_op_uuid.
    DELETE ADJACENT DUPLICATES FROM lt_defer_opt
      COMPARING ct_uuid mat_uuid child_op_type child_op_uuid.
    IF lt_defer_opt IS INITIAL.
      RETURN.
    ENDIF.

    " PERSIST_RESULTS ya dejo la imagen final en base dentro de esta LUW.
    " Cualquier linea distinta de CONT impide consumir la cuota completa.
    DATA lt_failed_opt TYPE STANDARD TABLE OF ty_failed_opt WITH EMPTY KEY.
    SELECT ct_uuid,
           mat_uuid,
           op_type AS child_op_type,
           op_uuid AS child_op_uuid
      FROM zreing_ca_line_a
      FOR ALL ENTRIES IN @lt_defer_opt
      WHERE calc_run_id = @iv_run_id
        AND ct_uuid = @lt_defer_opt-ct_uuid
        AND mat_uuid = @lt_defer_opt-mat_uuid
        AND op_type = @lt_defer_opt-child_op_type
        AND op_uuid = @lt_defer_opt-child_op_uuid
        AND line_status <> @zif_reing_ca_c=>line_status-cont
      INTO CORRESPONDING FIELDS OF TABLE @lt_failed_opt.

    SORT lt_failed_opt BY ct_uuid mat_uuid child_op_type child_op_uuid.
    DELETE ADJACENT DUPLICATES FROM lt_failed_opt
      COMPARING ct_uuid mat_uuid child_op_type child_op_uuid.

    DATA lt_cron_key TYPE SORTED TABLE OF ty_cron_key
      WITH UNIQUE KEY ct_uuid mat_uuid op_type op_uuid.
    LOOP AT lt_defer_opt INTO DATA(ls_defer_opt).
      READ TABLE lt_failed_opt TRANSPORTING NO FIELDS
        WITH KEY ct_uuid       = ls_defer_opt-ct_uuid
                 mat_uuid      = ls_defer_opt-mat_uuid
                 child_op_type = ls_defer_opt-child_op_type
                 child_op_uuid = ls_defer_opt-child_op_uuid
        BINARY SEARCH.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      INSERT VALUE #( ct_uuid  = ls_defer_opt-ct_uuid
                      mat_uuid = ls_defer_opt-mat_uuid
                      op_type  = ls_defer_opt-child_op_type
                      op_uuid  = ls_defer_opt-child_op_uuid )
        INTO TABLE lt_cron_key.
      INSERT VALUE #( ct_uuid  = ls_defer_opt-ct_uuid
                      mat_uuid = ls_defer_opt-mat_uuid
                      op_type  = ls_defer_opt-parent_op_type
                      op_uuid  = ls_defer_opt-parent_op_uuid )
        INTO TABLE lt_cron_key.
    ENDLOOP.
    IF lt_cron_key IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE fiscal_year, fiscal_period
      FROM zreing_ca_run_a
      WHERE calc_run_id = @iv_run_id
      INTO (@DATA(lv_fiscal_year), @DATA(lv_fiscal_period)).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA lt_cron TYPE STANDARD TABLE OF zreing_ct2_crn_a WITH EMPTY KEY.
    SELECT *
      FROM zreing_ct2_crn_a
      FOR ALL ENTRIES IN @lt_cron_key
      WHERE ct_uuid = @lt_cron_key-ct_uuid
        AND mat_uuid = @lt_cron_key-mat_uuid
        AND op_type = @lt_cron_key-op_type
        AND op_uuid = @lt_cron_key-op_uuid
        AND cron_year = @lv_fiscal_year
        AND cron_month = @lv_fiscal_period
        AND ( cron_status = 'PL' OR cron_status = @space )
      INTO TABLE @lt_cron.
    IF lt_cron IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_changed_at) =
      cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
    LOOP AT lt_cron ASSIGNING FIELD-SYMBOL(<ls_cron>).
      <ls_cron>-cron_status = 'EX'.
      <ls_cron>-changed_by  = sy-uname.
      <ls_cron>-changed_at  = lv_changed_at.
    ENDLOOP.

    UPDATE zreing_ct2_crn_a FROM TABLE @lt_cron.
  ENDMETHOD.


  METHOD proc_status_for_mode.
    rv_status = SWITCH zreing_ca_line_status( iv_mode
      WHEN zif_reing_ca_c=>contab_mode-post   THEN zif_reing_ca_c=>line_status-post_proc
      WHEN zif_reing_ca_c=>contab_mode-storno THEN zif_reing_ca_c=>line_status-anul_proc
      ELSE space ).
  ENDMETHOD.


  METHOD persist_results.
    " Equivalente, fuera de RAP, de los dos bloques que
    " lsc_zi_reingcarun~save_modified dedica a CONTAB: el UPDATE masivo de
    " LINE_A con las filas completas ya mutadas, y el INSERT de LOG_A con el
    " LOG_NUM recalculado (V011 -- run_contab_mode deja 0 como placeholder).
    " Sin COMMIT aca: lo hace el llamador, una sola vez.
    IF it_line_upd IS NOT INITIAL.
      UPDATE zreing_ca_line_a FROM TABLE @it_line_upd.
    ENDIF.

    CHECK it_log IS NOT INITIAL.

    " MAX(log_num) ya persistido por (calc_run_id, line_num) -- una sola
    " sentencia, fuera de todo loop. LINE_NUM NO es unico global: la clave de
    " ZREING_CA_LOG_A es (calc_run_id, line_num, log_num), asi que el maximo
    " se agrupa por el par, no por line_num (fix V017 del pool).
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
  ENDMETHOD.


  METHOD terminate_pending_lines.
    " ROLLBACK primero: el fallo pudo dejar escrituras parciales de la LUW
    " (el UPDATE/INSERT de persist_results, el DML de flush_documents) y,
    " sobre todo, los CALL FUNCTION IN UPDATE TASK que el poster FI registro.
    " Descartarlos es lo que evita que queden documentos FI reales posteados
    " sin ninguna fila en las tablas Z. Despues se persiste SOLO la
    " terminalizacion, para que la base quede consistente y el operador vea
    " el motivo.
    ROLLBACK WORK.

    DATA(lv_status_proc) = proc_status_for_mode( iv_mode ).
    IF lv_status_proc IS INITIAL.
      RETURN.
    ENDIF.

    " Destino de error: POST_ERR en modo P. En Storno el dominio no tiene
    " estado terminal de error (BR-F4-07) -> la linea vuelve a CONT, que es
    " el estado del que salio.
    DATA(lv_status_err) = COND zreing_ca_line_status(
      WHEN iv_mode = zif_reing_ca_c=>contab_mode-post
        THEN zif_reing_ca_c=>line_status-post_err
      ELSE zif_reing_ca_c=>line_status-anul_err ).

    " SIM_MESSAGE es CHAR 220 -- un texto mas largo se trunca solo.
    DATA lv_msg TYPE zreing_ca_line_a-sim_message.
    lv_msg = iv_message.
    DATA(lv_now) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).

    UPDATE zreing_ca_line_a
      SET line_status       = @lv_status_err,
          sim_message       = @lv_msg,
          proc_heartbeat_at = @lv_now
      WHERE calc_run_id = @iv_run_id
        AND line_status = @lv_status_proc.

    COMMIT WORK.
  ENDMETHOD.


  METHOD add_log.
    APPEND iv_message TO mt_log.
  ENDMETHOD.

  METHOD retry_ant_derivations.
    " V001 (CC) - Exact backend recovery outside RAP; never invokes FI posting.
    rs_result = process_ant_derivations( it_origins ).
  ENDMETHOD.

  METHOD classify_ant_fi.
    LOOP AT it_origins INTO DATA(ls_origin).
      DATA(ls_row) = VALUE zcl_reing_ca_an2_regenerator=>ty_batch_row(
        origin = ls_origin outcome = 'INVALID' ).
      READ TABLE it_lines INTO DATA(ls_line)
        WITH KEY calc_run_id = ls_origin-origin_run_id line_num = ls_origin-origin_line_num.
      IF sy-subrc <> 0 OR ls_line-op_type <> 'ANT' OR ls_line-line_status <> zif_reing_ca_c=>line_status-cont.
        ls_row-result-message = 'Origin is not an existing ANT in CONT'.
        APPEND ls_row TO rt_rows.
        CONTINUE.
      ENDIF.
      DATA(lt_docs) = VALUE zcl_reing_contab_engine=>tt_reversal_docs(
        FOR ls_doc IN it_docs WHERE ( calc_run_id = ls_origin-origin_run_id
          AND line_num = ls_origin-origin_line_num ) ( ls_doc ) ).
      IF lt_docs IS INITIAL.
        ls_row-outcome = 'SKIP_NO_FI'.
        ls_row-result-message = 'No document headers; no AN2 derivation'.
        APPEND ls_row TO rt_rows.
        CONTINUE.
      ENDIF.
      DATA(lv_has_fi) = abap_false.
      DATA(lv_consistent) = abap_true.
      DATA lv_doc_index TYPE i.
      lv_doc_index = 1.
      DO lines( lt_docs ) TIMES.
        READ TABLE lt_docs INTO DATA(ls_header) INDEX lv_doc_index.
        IF sy-subrc <> 0.
          lv_consistent = abap_false.
          ls_row-result-message = 'Document header traversal is inconsistent'.
          EXIT.
        ENDIF.
        lv_doc_index = lv_doc_index + 1.
        IF ls_header-simulated = abap_true OR ls_header-status <> 'OK'.
          lv_consistent = abap_false.
          ls_row-result-message = 'Document header is simulated, failed, or reversed'.
          EXIT.
        ENDIF.
        IF ls_header-belnr IS INITIAL.
          " Zero amount steps without a document do not prove FI exists.
          CONTINUE.
        ENDIF.
        IF ls_header-bukrs IS INITIAL OR ls_header-gjahr IS INITIAL.
          lv_consistent = abap_false.
          ls_row-result-message = 'Original document triple is incomplete'.
          EXIT.
        ENDIF.
        lv_has_fi = abap_true.
        READ TABLE it_journal INTO DATA(ls_journal)
          WITH KEY companycode = ls_header-bukrs accountingdocument = ls_header-belnr
            fiscalyear = ls_header-gjahr.
        IF sy-subrc <> 0 OR ls_journal-isreversed = abap_true.
          lv_consistent = abap_false.
          ls_row-result-message = 'Original FI document is not visible or is reversed'.
          EXIT.
        ENDIF.
      ENDDO.
      IF lv_consistent = abap_false.
        ls_row-outcome = 'DEFER_FI'.
      ELSEIF lv_has_fi = abap_false.
        ls_row-outcome = 'SKIP_NO_FI'.
        ls_row-result-message = 'No real BELNR; no AN2 derivation'.
      ELSE.
        ls_row-outcome = 'ELIGIBLE'.
      ENDIF.
      APPEND ls_row TO rt_rows.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_an2_logs.
    DATA(lv_now) = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ).
    LOOP AT it_rows INTO DATA(ls_row).
      READ TABLE it_lines INTO DATA(ls_origin)
        WITH KEY calc_run_id = ls_row-origin-origin_run_id line_num = ls_row-origin-origin_line_num.
      IF sy-subrc <> 0 OR ls_origin-op_type <> 'ANT' OR ls_origin-line_status <> zif_reing_ca_c=>line_status-cont.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( calc_run_id = ls_origin-calc_run_id line_num = ls_origin-line_num
        action = zif_reing_ca_c=>action-post
        status_from = zif_reing_ca_c=>line_status-cont status_to = zif_reing_ca_c=>line_status-cont
        created_by = sy-uname created_at = lv_now
        message = |AN2 postprocessing: { ls_row-outcome }; | &&
          |origin { ls_origin-calc_run_id }/{ ls_origin-line_num }; | &&
          |derived { ls_row-result-calc_run_id }/{ ls_row-result-line_num }; { ls_row-result-message }| ) TO rt_log.
      IF ls_row-outcome = 'READY_CALC'.
        APPEND VALUE #( calc_run_id = ls_row-result-calc_run_id line_num = ls_row-result-line_num
          action = zif_reing_ca_c=>action-create status_to = zif_reing_ca_c=>line_status-pend
          created_by = sy-uname created_at = lv_now
          message = |AN2 from { ls_origin-calc_run_id }/{ ls_origin-line_num }| ) TO rt_log.
        APPEND VALUE #( calc_run_id = ls_row-result-calc_run_id line_num = ls_row-result-line_num
          action = zif_reing_ca_c=>action-calc status_from = zif_reing_ca_c=>line_status-pend
          status_to = zif_reing_ca_c=>line_status-calc created_by = sy-uname created_at = lv_now
          message = |AN2 calculation from { ls_origin-calc_run_id }/{ ls_origin-line_num }| ) TO rt_log.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD write_an2_logs.
    CHECK it_log IS NOT INITIAL.
    DATA lt_runs TYPE RANGE OF zreing_ca_log_a-calc_run_id.
    DATA lt_nums TYPE RANGE OF zreing_ca_log_a-line_num.
    lt_runs = VALUE #( FOR ls_run IN it_log ( sign = 'I' option = 'EQ' low = ls_run-calc_run_id ) ).
    lt_nums = VALUE #( FOR ls_num IN it_log ( sign = 'I' option = 'EQ' low = ls_num-line_num ) ).
    SORT lt_runs.
    DELETE ADJACENT DUPLICATES FROM lt_runs COMPARING ALL FIELDS.
    SORT lt_nums.
    DELETE ADJACENT DUPLICATES FROM lt_nums COMPARING ALL FIELDS.
    SELECT calc_run_id, line_num, MAX( log_num ) AS max_num FROM zreing_ca_log_a
      WHERE calc_run_id IN @lt_runs AND line_num IN @lt_nums
      GROUP BY calc_run_id, line_num INTO TABLE @DATA(lt_max).
    TYPES: BEGIN OF ty_counter,
             calc_run_id TYPE zreing_ca_log_a-calc_run_id,
             line_num TYPE zreing_ca_log_a-line_num,
             max_num TYPE zreing_ca_log_a-log_num,
           END OF ty_counter.
    DATA lt_counter TYPE HASHED TABLE OF ty_counter WITH UNIQUE KEY calc_run_id line_num.
    lt_counter = CORRESPONDING #( lt_max ).
    DATA lt_new TYPE zif_reing_ca_types=>ty_log_t.
    LOOP AT it_log INTO DATA(ls_log).
      READ TABLE lt_counter ASSIGNING FIELD-SYMBOL(<ls_counter>)
        WITH TABLE KEY calc_run_id = ls_log-calc_run_id line_num = ls_log-line_num.
      IF sy-subrc <> 0.
        INSERT VALUE #( calc_run_id = ls_log-calc_run_id line_num = ls_log-line_num )
          INTO TABLE lt_counter ASSIGNING <ls_counter>.
      ENDIF.
      <ls_counter>-max_num = <ls_counter>-max_num + 1.
      ls_log-log_num = <ls_counter>-max_num.
      APPEND ls_log TO lt_new.
    ENDLOOP.
    INSERT zreing_ca_log_a FROM TABLE @lt_new.
  ENDMETHOD.

  METHOD process_ant_derivations.
    DATA(lo_context) = zcl_reing_ca_an2_regenerator=>open_context( it_origins ).
    rs_result-message = lo_context->get_error( ).
    IF rs_result-message IS NOT INITIAL.
      rs_result-failed = abap_true.
      DATA(lv_early_release) = lo_context->close_context( ).
      IF lv_early_release IS NOT INITIAL.
        rs_result-message = |{ rs_result-message }; { lv_early_release }|.
      ENDIF.
      RETURN.
    ENDIF.
    DATA lt_sources TYPE zif_reing_ca_types=>ty_line_t.
    DATA lt_eligible TYPE zcl_reing_ca_an2_regenerator=>tt_origin.
    TRY.
        " Context is locked before all source, FI, and idempotency rereads.
        " V001 (CC) - AN2 APJ: FI classification and logging consume only these source fields.
        SELECT calc_run_id, line_num, op_type, line_status
          FROM zreing_ca_line_a FOR ALL ENTRIES IN @it_origins
          WHERE calc_run_id = @it_origins-origin_run_id AND line_num = @it_origins-origin_line_num
          INTO CORRESPONDING FIELDS OF TABLE @lt_sources.
        DATA lt_docs TYPE zcl_reing_contab_engine=>tt_reversal_docs.
        SELECT calc_run_id, line_num, status, simulated, bukrs, belnr, gjahr
          FROM zreing_cb_doc_a FOR ALL ENTRIES IN @it_origins
          WHERE calc_run_id = @it_origins-origin_run_id AND line_num = @it_origins-origin_line_num
          INTO CORRESPONDING FIELDS OF TABLE @lt_docs.
        DATA(lt_fi_docs) = lt_docs.
        DELETE lt_fi_docs WHERE simulated = abap_true OR belnr IS INITIAL
          OR bukrs IS INITIAL OR gjahr IS INITIAL.
        DATA lt_journal TYPE zcl_reing_contab_engine=>tt_journal.
        IF lt_fi_docs IS NOT INITIAL.
          SELECT companycode, accountingdocument, fiscalyear, isreversed,
                 reversedocument, reversedocumentfiscalyear FROM i_journalentry
            FOR ALL ENTRIES IN @lt_fi_docs
            WHERE companycode = @lt_fi_docs-bukrs AND accountingdocument = @lt_fi_docs-belnr
              AND fiscalyear = @lt_fi_docs-gjahr INTO CORRESPONDING FIELDS OF TABLE @lt_journal.
        ENDIF.
        rs_result-rows = classify_ant_fi( it_origins = it_origins it_lines = lt_sources
          it_docs = lt_docs it_journal = lt_journal ).
        IF iv_defer_reason IS NOT INITIAL.
          LOOP AT rs_result-rows ASSIGNING FIELD-SYMBOL(<ls_defer>) WHERE outcome = 'ELIGIBLE'.
            <ls_defer>-outcome = 'DEFER_COMMIT'.
            <ls_defer>-result-message = iv_defer_reason.
          ENDLOOP.
        ENDIF.
        lt_eligible = VALUE #( FOR ls_row IN rs_result-rows WHERE ( outcome = 'ELIGIBLE' ) ( ls_row-origin ) ).
        IF lt_eligible IS NOT INITIAL.
          DATA(ls_batch) = lo_context->regenerate_many( lt_eligible ).
          DELETE rs_result-rows WHERE outcome = 'ELIGIBLE'.
          APPEND LINES OF ls_batch-rows TO rs_result-rows.
          IF ls_batch-failed = abap_true.
            TEST-SEAM an2_job_rollback_batch.
              ROLLBACK WORK.
            END-TEST-SEAM.
            rs_result-message = ls_batch-message.
            rs_result-failed = abap_true.
            normalize_failed_batch( EXPORTING it_eligible = lt_eligible iv_message = ls_batch-message
              CHANGING ct_rows = rs_result-rows ).
          ENDIF.
        ENDIF.
        write_an2_logs( build_an2_logs( it_rows = rs_result-rows it_lines = lt_sources ) ).
        TEST-SEAM an2_job_commit_result.
          COMMIT WORK.
        END-TEST-SEAM.
        LOOP AT rs_result-rows ASSIGNING FIELD-SYMBOL(<ls_done>).
          IF <ls_done>-outcome = 'READY_CALC'.
            <ls_done>-outcome = 'CREATED'.
          ELSEIF <ls_done>-outcome <> 'EXISTS_CALC' AND <ls_done>-outcome <> 'SKIP_NO_FI'.
            rs_result-failed = abap_true.
          ENDIF.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_derive).
        TEST-SEAM an2_job_rollback_error.
          ROLLBACK WORK.
        END-TEST-SEAM.
        rs_result-failed = abap_true.
        rs_result-message = lx_derive->get_text( ).
        " Source FI was committed before this method; discard only second-LUW tentative keys.
        normalize_failed_batch( EXPORTING it_eligible = it_origins iv_message = rs_result-message
          CHANGING ct_rows = rs_result-rows ).
        TRY.
            write_an2_logs( build_an2_logs( it_rows = rs_result-rows it_lines = lt_sources ) ).
            TEST-SEAM an2_job_commit_error.
              COMMIT WORK.
            END-TEST-SEAM.
          CATCH cx_root INTO DATA(lx_log).
            TEST-SEAM an2_job_rollback_log.
              ROLLBACK WORK.
            END-TEST-SEAM.
            rs_result-message = |AN2 failure could not be logged: { lx_log->get_text( ) }|.
        ENDTRY.
    ENDTRY.
    DATA(lv_release) = lo_context->close_context( ).
    IF lv_release IS NOT INITIAL.
      rs_result-failed = abap_true.
      rs_result-message = |{ rs_result-message }; context release: { lv_release }|.
    ENDIF.
  ENDMETHOD.

  METHOD normalize_failed_batch.
    LOOP AT it_eligible INTO DATA(ls_origin).
      READ TABLE ct_rows ASSIGNING FIELD-SYMBOL(<ls_row>)
        WITH KEY origin-origin_run_id = ls_origin-origin_run_id
          origin-origin_line_num = ls_origin-origin_line_num.
      IF sy-subrc <> 0.
        APPEND VALUE #( origin = ls_origin ) TO ct_rows ASSIGNING <ls_row>.
      ENDIF.
      IF <ls_row>-outcome = 'EXISTS_CALC' OR <ls_row>-outcome = 'EXISTS_PENDING'
          OR <ls_row>-outcome = 'EXISTS_CLOSED' OR <ls_row>-outcome = 'CONFLICT'
          OR <ls_row>-outcome = 'INVALID' OR <ls_row>-outcome = 'SKIP_NO_FI'
          OR <ls_row>-outcome = 'DEFER_FI' OR <ls_row>-outcome = 'DEFER_COMMIT'.
        CONTINUE.
      ENDIF.
      <ls_row>-outcome = 'TECH_FAILED'.
      CLEAR <ls_row>-result.
      <ls_row>-result-message = iv_message.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

