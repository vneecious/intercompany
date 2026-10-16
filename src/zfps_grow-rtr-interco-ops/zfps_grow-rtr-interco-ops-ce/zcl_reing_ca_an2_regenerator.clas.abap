*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 05.08.2026                                          *
* Description    : Reintegro Gastos - Delta v2 - CON-08 (regeneracion AN2) *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Contrato CONTAB->CA (direccion inversa a ZIF_REING_CONTAB_DISPATCHER):
* CONTAB (ZCL_REING_CONTAB_EVT_POSTED, evento RAP "Posted") llama a
* REGENERATE cuando una LINE_A de tipo ANT (original o delta) transiciona
* a CONT. CA relee esa linea, resuelve la instancia AN2 vinculada
* (ZREING_CT2_OPT_A, mismo op_instance_num que el ANT), y corre el
* pipeline para dejar el AN2 en CALC, sin que el llamador necesite pasar
* el monto (se relee del propio ANT).
*
* Confirmado con Agustin (05.08.2026): el metodo no usa RAISING -- errores
* de negocio se devuelven en rs_result-success/message (mismo patron que
* ZIF_REING_CONTAB_DISPATCHER~process_line / ty_contab_result), para que
* el handler de evento no necesite TRY/CATCH.
*
* RUN_A: corregido contra el patron real de la app (ZBP_ReingCARun=>calculate,
* ZCL_REING_CA_CALC_JOB) -- NO es una corrida nueva de una sola linea (eso
* se le habia propuesto a Agustin por error): calc_run_id es deterministico,
* 'RUN-{fiscal_year}{fiscal_period}', un unico RUN_A por periodo fiscal,
* compartido por todos los grupos calculados ese periodo. Se reutiliza (o
* se crea si no existe) el RUN_A del periodo fiscal ACTUAL del sistema
* (decision de negocio confirmada 05.08.2026 -- no el periodo de origen
* del ANT), agregando la nueva linea con el siguiente line_num del run.
*
* Fix transaccionalidad (06.08.2026 | EXT_GONZALCA): REGENERATE lo invoca
* ZCL_REING_CONTAB_EVT_POSTED, un event handler RAP sincrono in-process
* sobre el evento Posted de ZI_ReingCARun -- corre DENTRO del mismo LUW
* que la secuencia de guardado (save_modified) de la accion Post/Storno
* del CalcRun. El metodo tenia un COMMIT WORK / ROLLBACK WORK nativos que
* cortarian ese LUW a mitad de la secuencia de save del framework RAP
* (restriccion documentada de RAP Business Events). Se reemplazan por
* cl_abap_tx=>save( ) (delega el commit al transaction manager que ya
* gestiona el LUW del llamador) y, en el path de error del pipeline, por
* un compensating delete puntual de lo que este metodo inserto (la linea
* semilla y, si la creo, el RUN_A del periodo) en vez de un ROLLBACK WORK
* que deshacia todo el LUW ajeno.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_an2_regenerator DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_origin,
             origin_run_id TYPE zreing_ca_line_a-origin_run_id,
             origin_line_num TYPE zreing_ca_line_a-origin_line_num,
           END OF ty_origin,
           tt_origin TYPE STANDARD TABLE OF ty_origin WITH EMPTY KEY.
    TYPES: BEGIN OF ty_batch_row,
             origin TYPE ty_origin,
             outcome TYPE c LENGTH 20,
             result TYPE zif_reing_ca_types=>ty_an2_regen_result,
           END OF ty_batch_row,
           tt_batch_row TYPE STANDARD TABLE OF ty_batch_row WITH EMPTY KEY.
    TYPES: BEGIN OF ty_batch_result,
             rows TYPE tt_batch_row,
             failed TYPE abap_bool,
             message TYPE zreing_ca_log_a-message,
           END OF ty_batch_result.
    CLASS-METHODS regenerate
      IMPORTING iv_origin_run_id TYPE zreing_ca_run_a-calc_run_id
                iv_origin_line_num TYPE zreing_ca_line_a-line_num
      RETURNING VALUE(rs_result) TYPE zif_reing_ca_types=>ty_an2_regen_result.
    CLASS-METHODS open_context
      IMPORTING it_origins TYPE tt_origin
      RETURNING VALUE(ro_context) TYPE REF TO zcl_reing_ca_an2_regenerator.
    METHODS get_origins RETURNING VALUE(rt_origins) TYPE tt_origin.
    METHODS get_error RETURNING VALUE(rv_message) TYPE zreing_ca_log_a-message.
    METHODS close_context RETURNING VALUE(rv_message) TYPE zreing_ca_log_a-message.
    METHODS regenerate_many
      IMPORTING it_eligible TYPE tt_origin
      RETURNING VALUE(rs_result) TYPE ty_batch_result.
  PRIVATE SECTION.
    TYPES tt_option TYPE STANDARD TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.
    TYPES tt_run TYPE SORTED TABLE OF zreing_ca_run_a-calc_run_id WITH UNIQUE KEY table_line.
    TYPES: BEGIN OF ty_seed_key,
             calc_run_id TYPE zreing_ca_line_a-calc_run_id,
             line_num TYPE zreing_ca_line_a-line_num,
           END OF ty_seed_key.
    DATA mt_origins TYPE tt_origin.
    DATA mt_lock_runs TYPE tt_run.
    DATA mt_owned_runs TYPE tt_run.
    DATA mo_lock TYPE REF TO if_abap_lock_object.
    DATA mv_target TYPE zreing_ca_run_a-calc_run_id.
    DATA mv_year TYPE zreing_ca_run_a-fiscal_year.
    DATA mv_period TYPE zreing_ca_run_a-fiscal_period.
    DATA mv_active TYPE abap_bool.
    DATA mv_closed TYPE abap_bool.
    DATA mv_used TYPE abap_bool.
    DATA mv_error TYPE zreing_ca_log_a-message.
    CLASS-METHODS pick_an2_option
      IMPORTING is_ant TYPE zreing_ca_line_a it_options TYPE tt_option
      RETURNING VALUE(rs_option) TYPE zreing_ct2_opt_a.
    CLASS-METHODS resolve_an2_option
      IMPORTING is_ant TYPE zreing_ca_line_a
      RETURNING VALUE(rs_option) TYPE zreing_ct2_opt_a.
    CLASS-METHODS same_seed_identity
      IMPORTING is_line TYPE zreing_ca_line_a is_ant TYPE zreing_ca_line_a
                is_option TYPE zreing_ct2_opt_a
      RETURNING VALUE(rv_same) TYPE abap_bool.
    CLASS-METHODS make_seed
      IMPORTING is_ant TYPE zreing_ca_line_a is_option TYPE zreing_ct2_opt_a
                iv_target TYPE zreing_ca_run_a-calc_run_id iv_line_num TYPE zreing_ca_line_a-line_num
      RETURNING VALUE(rs_seed) TYPE zreing_ca_line_a.
    CLASS-METHODS audit_result
      IMPORTING it_seeds TYPE zif_reing_ca_types=>ty_line_t
                is_result TYPE zif_reing_ca_types=>ty_pipeline_result
      RETURNING VALUE(rv_message) TYPE zreing_ca_log_a-message.
    CLASS-METHODS refresh_totals IMPORTING iv_target TYPE zreing_ca_run_a-calc_run_id.
    CLASS-METHODS ensure_run
      IMPORTING iv_calc_run_id TYPE zreing_ca_run_a-calc_run_id
                iv_year TYPE zreing_ca_run_a-fiscal_year iv_period TYPE zreing_ca_run_a-fiscal_period
      RETURNING VALUE(rv_created) TYPE abap_bool.
    CLASS-METHODS ensure_batch_run
      IMPORTING iv_calc_run_id TYPE zreing_ca_run_a-calc_run_id
                iv_year TYPE zreing_ca_run_a-fiscal_year iv_period TYPE zreing_ca_run_a-fiscal_period
      RETURNING VALUE(rv_created) TYPE abap_bool.
    CLASS-METHODS next_line_num
      IMPORTING iv_calc_run_id TYPE zreing_ca_run_a-calc_run_id
      RETURNING VALUE(rv_line_num) TYPE zreing_ca_line_a-line_num.
ENDCLASS.

CLASS zcl_reing_ca_an2_regenerator IMPLEMENTATION.
  METHOD regenerate.
    rs_result-success = abap_false.

    " 1) Releer el ANT recien contabilizado -- debe existir y estar en CONT.
    SELECT SINGLE *
      FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_origin_run_id
        AND line_num    = @iv_origin_line_num
      INTO @DATA(ls_ant).
    IF sy-subrc <> 0.
      rs_result-message = |No existe LINE_A { iv_origin_run_id }/{ iv_origin_line_num }|.
      RETURN.
    ENDIF.
    IF ls_ant-line_status <> zif_reing_ca_c=>line_status-cont.
      rs_result-message = |LINE_A { iv_origin_run_id }/{ iv_origin_line_num } no esta en CONT|.
      RETURN.
    ENDIF.

    " 2) Resolver la instancia AN2 vinculada (mismo op_instance_num que el ANT).
    DATA(ls_an2_option) = resolve_an2_option( ls_ant ).
    IF ls_an2_option-op_uuid IS INITIAL OR ls_an2_option-op_instance_num IS INITIAL.
      rs_result-message = |No existe instancia AN2 vinculada al ANT (op_uuid { ls_ant-op_uuid })|.
      RETURN.
    ENDIF.

    " 3) Periodo fiscal actual del sistema (decision de negocio 05.08.2026)
    "    + calc_run_id deterministico, mismo patron que ZBP_ReingCARun=>calculate.
    DATA(lv_year)   = CONV zreing_ca_run_a-fiscal_year( sy-datum(4) ).
    DATA(lv_period) = CONV zreing_ca_run_a-fiscal_period( sy-datum+4(2) ).
    DATA(lv_calc_run_id) = CONV zreing_ca_run_a-calc_run_id( |RUN-{ lv_year }{ lv_period }| ).

    DATA(lv_run_created) = ensure_run( iv_calc_run_id = lv_calc_run_id iv_year = lv_year iv_period = lv_period ).
    DATA(lv_line_num) = next_line_num( lv_calc_run_id ).

    " 4) Insertar la fila semilla PEND (el pipeline nunca inserta -- solo
    "    procesa lineas PEND ya existentes, ver step_validate rama B2).
    DATA(ls_seed) = VALUE zreing_ca_line_a(
      calc_run_id     = lv_calc_run_id
      line_num        = lv_line_num
      ct_uuid         = ls_ant-ct_uuid
      mat_uuid        = ls_ant-mat_uuid
      ct_id           = ls_ant-ct_id
      lifnr           = ls_ant-lifnr
      bp_name         = ls_ant-bp_name
      bukrs_prest     = ls_ant-bukrs_prest
      matnr           = ls_ant-matnr
      op_type         = 'AN2'
      op_uuid         = ls_an2_option-op_uuid
      " V001 (CC) - #111: retain the resolved AN2 instance through pipeline B2.
      op_instance_num = ls_an2_option-op_instance_num
      parent_op_type  = 'ANT'
      origin_run_id   = iv_origin_run_id
      origin_line_num = iv_origin_line_num
      parent_net_amt  = ls_ant-net_amt
      parent_currency = ls_ant-ct_currency
      bukrs_recv      = ls_ant-bukrs_recv
      country         = ls_ant-country
      ct_currency     = ls_ant-ct_currency
      local_currency  = ls_ant-local_currency
      line_status     = 'PEND' ).
    INSERT zreing_ca_line_a FROM @ls_seed.

    " 5) Correr el pipeline para ese grupo (mismo patron que
    "    ZCL_REING_CA_CALC_JOB=>run_pipeline).
    DATA(lo_sources)  = NEW zcl_reing_ca_sources( ).
    DATA(lo_pipeline) = NEW zcl_reing_ca_pipeline(
      is_context = VALUE zif_reing_ca_types=>ty_context(
                     calc_run_id = lv_calc_run_id period = lv_period year = lv_year )
      io_sources = lo_sources ).

    DATA(lt_scope) = VALUE zif_reing_ca_types=>ty_group_key_t(
      ( calc_run_id = lv_calc_run_id
        ct_uuid     = ls_ant-ct_uuid
        mat_uuid    = ls_ant-mat_uuid
        op_type     = 'AN2'
        op_uuid     = ls_an2_option-op_uuid ) ).

    TRY.
        DATA(ls_pipeline_result) = lo_pipeline->execute( lt_scope ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_calc).
        " Fix transaccionalidad (06.08.2026 | EXT_GONZALCA): compensating
        " delete puntual en vez de ROLLBACK WORK -- ver nota de clase.
        DELETE FROM zreing_ca_line_a
          WHERE calc_run_id = @lv_calc_run_id
            AND line_num    = @lv_line_num.
        IF lv_run_created = abap_true.
          DELETE FROM zreing_ca_run_a
            WHERE calc_run_id = @lv_calc_run_id.
        ENDIF.
        rs_result-message = |Error de pipeline al regenerar AN2: { lx_calc->mv_message }|.
        RETURN.
    ENDTRY.

    " 6) Persistir el resultado (la linea ya trae el mismo calc_run_id/
    "    line_num de la semilla -- step_validate B2 la lee de it_pend_scope).
    IF ls_pipeline_result-lines IS NOT INITIAL.
      UPDATE zreing_ca_line_a FROM TABLE @ls_pipeline_result-lines.
    ENDIF.
    IF ls_pipeline_result-line_pc IS NOT INITIAL.
      INSERT zreing_ca_lpc_a FROM TABLE @ls_pipeline_result-line_pc.
    ENDIF.
    IF ls_pipeline_result-steps IS NOT INITIAL.
      INSERT zreing_ca_step_a FROM TABLE @ls_pipeline_result-steps.
    ENDIF.

    UPDATE zreing_ca_run_a
      SET total_lines  = total_lines  + 1,
          total_groups = total_groups + 1
      WHERE calc_run_id = @lv_calc_run_id.

    " Fix transaccionalidad (06.08.2026 | EXT_GONZALCA) - revision reviewer:
    " se retiro cl_abap_tx=>save( ) sin reemplazo. El unico llamador real de
    " este metodo es ZCL_REING_CONTAB_EVT_POSTED, un event handler RAP
    " sincrono in-process sobre el evento Posted de ZI_ReingCARun -- corre
    " DENTRO del mismo LUW que la secuencia de save (save_modified) de la
    " accion Post/Storno de CalcRun. cl_abap_tx=>save( ) arranca con
    " cl_abap_behv_ctrl=>enter_tx_phase( phase = 'S' test = 'X' ), que
    " dumpea si la transicion de fase no es valida -- exactamente la
    " situacion de estar ya dentro de una secuencia de save ajena, la misma
    " clase de problema que el COMMIT WORK original. Como las operaciones de
    " este metodo son INSERT/UPDATE nativos sobre tablas Z (no EML), no
    " necesitan frontera transaccional propia: el commit final lo dispara
    " el framework RAP al cerrar la secuencia de save del Post/Storno que
    " contiene a este handler. Ver review.md del fix para el analisis
    " completo (lectura de CL_ABAP_TX=>SAVE + verificacion de que este es
    " el unico caller productivo del metodo).

    rs_result-success     = abap_true.
    rs_result-calc_run_id = lv_calc_run_id.
    rs_result-line_num    = lv_line_num.
  ENDMETHOD.

  METHOD resolve_an2_option.
    " V001 (CC) - #111: resolve by the exact ANT identity; reject missing/ambiguous children.
    IF is_ant-op_type <> 'ANT'.
      RETURN.
    ENDIF.

    SELECT SINGLE ct_uuid, mat_uuid, op_uuid, op_instance_num
      FROM zreing_ct2_opt_a
      WHERE ct_uuid = @is_ant-ct_uuid
        AND mat_uuid = @is_ant-mat_uuid
        AND op_type = 'ANT'
        AND op_uuid = @is_ant-op_uuid
      INTO @DATA(ls_parent).
    IF sy-subrc <> 0 OR ls_parent-op_instance_num IS INITIAL.
      RETURN.
    ENDIF.
    IF is_ant-op_instance_num IS NOT INITIAL
      AND is_ant-op_instance_num <> ls_parent-op_instance_num.
      RETURN.
    ENDIF.

    " Older children may lack ParentInstanceId; accept only a unique matching business identity.
    DATA lv_initial_uuid TYPE sysuuid_x16.
    SELECT *
      FROM zreing_ct2_opt_a
      WHERE ct_uuid = @ls_parent-ct_uuid
        AND mat_uuid = @ls_parent-mat_uuid
        AND op_type = 'AN2'
        AND op_instance_num = @ls_parent-op_instance_num
        AND ( parent_instance_id = @ls_parent-op_uuid
           OR parent_instance_id = @lv_initial_uuid )
      INTO TABLE @DATA(lt_children).
    IF lines( lt_children ) <> 1.
      RETURN.
    ENDIF.
    rs_option = lt_children[ 1 ].
  ENDMETHOD.

  METHOD ensure_run.
    SELECT SINGLE calc_run_id
      FROM zreing_ca_run_a
      WHERE calc_run_id = @iv_calc_run_id
      INTO @DATA(lv_existing).
    IF sy-subrc = 0.
      rv_created = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_new_run) = VALUE zreing_ca_run_a(
      calc_run_id   = iv_calc_run_id
      fiscal_year   = iv_year
      fiscal_period = iv_period
      total_lines   = 0
      total_groups  = 0
      created_by    = sy-uname
      created_at    = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) ).
    INSERT zreing_ca_run_a FROM @ls_new_run.
    rv_created = abap_true.
  ENDMETHOD.

  METHOD next_line_num.
    SELECT SINGLE MAX( line_num )
      FROM zreing_ca_line_a
      WHERE calc_run_id = @iv_calc_run_id
      INTO @DATA(lv_max).
    rv_line_num = lv_max + 1.
  ENDMETHOD.

  METHOD ensure_batch_run.
    SELECT SINGLE calc_run_id
      FROM zreing_ca_run_a
      WHERE calc_run_id = @iv_calc_run_id
      INTO @DATA(lv_existing).
    IF sy-subrc = 0.
      rv_created = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_new_run) = VALUE zreing_ca_run_a(
      calc_run_id   = iv_calc_run_id
      fiscal_year   = iv_year
      fiscal_period = iv_period
      total_lines   = 0
      total_groups  = 0
      created_by    = sy-uname
      created_at    = cl_abap_tstmp=>utclong2tstmp( utclong_current( ) ) ).
    DATA lv_inserted TYPE abap_bool.
    TEST-SEAM an2_insert_run.
      INSERT zreing_ca_run_a FROM @ls_new_run.
      lv_inserted = xsdbool( sy-subrc = 0 ).
    END-TEST-SEAM.
    rv_created = lv_inserted.
  ENDMETHOD.

  METHOD open_context.
    " V001 (CC) - AN2 APJ: context factory binds immutable origin and target keys.
    " Four legacy method bodies are preserved; their same-SAVE comments are historical.
    ro_context = NEW #( ).
    ro_context->mt_origins = it_origins.
    ro_context->mv_year = sy-datum(4).
    ro_context->mv_period = sy-datum+4(2).
    ro_context->mv_target = |RUN-{ ro_context->mv_year }{ ro_context->mv_period }|.
    IF it_origins IS INITIAL.
      ro_context->mv_error = 'AN2 context requires explicit origins'.
      RETURN.
    ENDIF.
    DATA lt_seen TYPE HASHED TABLE OF ty_origin
      WITH UNIQUE KEY origin_run_id origin_line_num.
    LOOP AT it_origins INTO DATA(ls_origin).
      IF ls_origin-origin_run_id IS INITIAL OR ls_origin-origin_line_num IS INITIAL
          OR ls_origin-origin_run_id CS '*'.
        ro_context->mv_error = 'AN2 context contains an invalid origin'.
        RETURN.
      ENDIF.
      INSERT ls_origin INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        ro_context->mv_error = 'AN2 context contains duplicate origins'.
        RETURN.
      ENDIF.
      INSERT ls_origin-origin_run_id INTO TABLE ro_context->mt_lock_runs.
    ENDLOOP.
    INSERT ro_context->mv_target INTO TABLE ro_context->mt_lock_runs.
    TRY.
        TEST-SEAM an2_lock_factory.
          ro_context->mo_lock = cl_abap_lock_object_factory=>get_instance( 'EZREINGCARUN' ).
        END-TEST-SEAM.
        LOOP AT ro_context->mt_lock_runs INTO DATA(lv_run).
          TEST-SEAM an2_enqueue.
            ro_context->mo_lock->enqueue(
              it_table_mode = VALUE #( ( table_name = 'ZREING_CA_RUN_A'
                mode = if_abap_lock_object=>cs_mode-exclusive_lock ) )
              it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( lv_run ) ) )
              _scope = if_abap_lock_object=>cs_scope-no_update_program
              _wait = if_abap_lock_object=>cs_wait-no ).
          END-TEST-SEAM.
          INSERT lv_run INTO TABLE ro_context->mt_owned_runs.
        ENDLOOP.
        ro_context->mv_active = abap_true.
      CATCH cx_root INTO DATA(lx_lock).
        ro_context->mv_error = lx_lock->get_text( ).
        " Only successfully acquired X locks belong to this context.
        DATA(lv_release) = ro_context->close_context( ).
        IF lv_release IS NOT INITIAL.
          ro_context->mv_error = |{ ro_context->mv_error }; { lv_release }|.
        ENDIF.
    ENDTRY.
  ENDMETHOD.

  METHOD get_error.
    rv_message = mv_error.
    IF mv_closed = abap_true AND rv_message IS INITIAL.
      rv_message = 'AN2 context is closed'.
    ELSEIF mv_active = abap_false AND rv_message IS INITIAL.
      rv_message = 'AN2 context was not opened by the factory'.
    ENDIF.
  ENDMETHOD.

  METHOD get_origins.
    rt_origins = mt_origins.
  ENDMETHOD.

  METHOD close_context.
    mv_active = abap_false.
    mv_closed = abap_true.
    DATA lt_released TYPE tt_run.
    LOOP AT mt_owned_runs INTO DATA(lv_run).
      TRY.
          TEST-SEAM an2_dequeue.
            mo_lock->dequeue(
              it_table_mode = VALUE #( ( table_name = 'ZREING_CA_RUN_A'
                mode = if_abap_lock_object=>cs_mode-exclusive_lock ) )
              it_parameter = VALUE #( ( name = 'CALC_RUN_ID' value = REF #( lv_run ) ) )
              _scope = if_abap_lock_object=>cs_scope-no_update_program
              _synchronous = if_abap_lock_object=>cs_synchronous-yes ).
          END-TEST-SEAM.
          INSERT lv_run INTO TABLE lt_released.
        CATCH cx_abap_lock_failure INTO DATA(lx_unlock).
          rv_message = lx_unlock->get_text( ).
      ENDTRY.
    ENDLOOP.
    LOOP AT lt_released INTO lv_run.
      DELETE TABLE mt_owned_runs FROM lv_run.
    ENDLOOP.
    IF rv_message IS NOT INITIAL.
      mv_error = rv_message.
    ENDIF.
  ENDMETHOD.

  METHOD pick_an2_option.
    IF is_ant-op_type <> 'ANT'.
      RETURN.
    ENDIF.
    READ TABLE it_options INTO DATA(ls_parent)
      WITH KEY ct_uuid = is_ant-ct_uuid mat_uuid = is_ant-mat_uuid
        op_type = 'ANT' op_uuid = is_ant-op_uuid.
    IF sy-subrc <> 0 OR ls_parent-op_instance_num IS INITIAL.
      RETURN.
    ENDIF.
    IF is_ant-op_instance_num IS NOT INITIAL
        AND is_ant-op_instance_num <> ls_parent-op_instance_num.
      RETURN.
    ENDIF.
    DATA lv_matches TYPE i.
    LOOP AT it_options INTO DATA(ls_child)
      WHERE ct_uuid = ls_parent-ct_uuid AND mat_uuid = ls_parent-mat_uuid
        AND op_type = 'AN2' AND op_instance_num = ls_parent-op_instance_num.
      IF ls_child-parent_instance_id IS INITIAL
          OR ls_child-parent_instance_id = ls_parent-op_uuid.
        lv_matches = lv_matches + 1.
        rs_option = ls_child.
      ENDIF.
    ENDLOOP.
    IF lv_matches <> 1.
      CLEAR rs_option.
    ENDIF.
  ENDMETHOD.

  METHOD same_seed_identity.
    rv_same = xsdbool(
      is_line-op_type = 'AN2'
      AND is_line-ct_uuid = is_ant-ct_uuid AND is_line-mat_uuid = is_ant-mat_uuid
      AND is_line-op_uuid = is_option-op_uuid
      AND is_line-op_instance_num = is_option-op_instance_num
      AND is_line-origin_run_id = is_ant-calc_run_id
      AND is_line-origin_line_num = is_ant-line_num
      AND is_line-parent_op_type = 'ANT' AND is_line-bukrs_recv = is_ant-bukrs_recv ).
  ENDMETHOD.

  METHOD make_seed.
    rs_seed = VALUE #(
      calc_run_id = iv_target line_num = iv_line_num
      ct_uuid = is_ant-ct_uuid mat_uuid = is_ant-mat_uuid ct_id = is_ant-ct_id
      lifnr = is_ant-lifnr bp_name = is_ant-bp_name bukrs_prest = is_ant-bukrs_prest
      matnr = is_ant-matnr op_type = 'AN2' op_uuid = is_option-op_uuid
      op_instance_num = is_option-op_instance_num parent_op_type = 'ANT'
      origin_run_id = is_ant-calc_run_id origin_line_num = is_ant-line_num
      parent_net_amt = is_ant-net_amt parent_currency = is_ant-ct_currency
      bukrs_recv = is_ant-bukrs_recv country = is_ant-country
      ct_currency = is_ant-ct_currency local_currency = is_ant-local_currency
      line_status = zif_reing_ca_c=>line_status-pend ).
  ENDMETHOD.

  METHOD audit_result.
    IF is_result-errors IS NOT INITIAL OR lines( is_result-lines ) <> lines( it_seeds ).
      rv_message = 'AN2 pipeline returned errors or an incomplete line set'.
      RETURN.
    ENDIF.
    DATA lt_seen TYPE HASHED TABLE OF ty_seed_key WITH UNIQUE KEY calc_run_id line_num.
    LOOP AT is_result-lines INTO DATA(ls_line).
      READ TABLE it_seeds INTO DATA(ls_seed)
        WITH KEY calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num.
      IF sy-subrc <> 0 OR ls_line-line_status <> zif_reing_ca_c=>line_status-calc
          OR ls_line-ct_uuid <> ls_seed-ct_uuid OR ls_line-mat_uuid <> ls_seed-mat_uuid
          OR ls_line-op_uuid <> ls_seed-op_uuid OR ls_line-op_type <> 'AN2'
          OR ls_line-op_instance_num <> ls_seed-op_instance_num
          OR ls_line-bukrs_recv <> ls_seed-bukrs_recv
          OR ls_line-parent_op_type <> ls_seed-parent_op_type
          OR ls_line-parent_net_amt <> ls_seed-parent_net_amt
          OR ls_line-parent_currency <> ls_seed-parent_currency
          OR ls_line-ct_currency <> ls_seed-ct_currency
          OR ls_line-origin_run_id <> ls_seed-origin_run_id
          OR ls_line-origin_line_num <> ls_seed-origin_line_num.
        rv_message = 'AN2 pipeline changed a physical seed key or identity'.
        RETURN.
      ENDIF.
      INSERT VALUE #( calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num ) INTO TABLE lt_seen.
      IF sy-subrc <> 0.
        rv_message = 'AN2 pipeline returned a duplicate physical seed'.
        RETURN.
      ENDIF.
    ENDLOOP.
    DATA lt_pc_seen TYPE HASHED TABLE OF zreing_ca_lpc_a
      WITH UNIQUE KEY calc_run_id line_num pc_seq.
    LOOP AT is_result-line_pc INTO DATA(ls_pc).
      IF NOT line_exists( lt_seen[ calc_run_id = ls_pc-calc_run_id line_num = ls_pc-line_num ] ).
        rv_message = 'AN2 pipeline returned an unrelated LPC row'.
        RETURN.
      ENDIF.
      INSERT CORRESPONDING #( ls_pc ) INTO TABLE lt_pc_seen.
      IF sy-subrc <> 0.
        rv_message = 'AN2 pipeline returned a duplicate LPC key'.
        RETURN.
      ENDIF.
    ENDLOOP.
    DATA lt_step_seen TYPE HASHED TABLE OF zreing_ca_step_a
      WITH UNIQUE KEY calc_run_id line_num step_num seq.
    LOOP AT is_result-steps INTO DATA(ls_step).
      IF NOT line_exists( lt_seen[ calc_run_id = ls_step-calc_run_id line_num = ls_step-line_num ] ).
        rv_message = 'AN2 pipeline returned an unrelated STEP row'.
        RETURN.
      ENDIF.
      INSERT CORRESPONDING #( ls_step ) INTO TABLE lt_step_seen.
      IF sy-subrc <> 0.
        rv_message = 'AN2 pipeline returned a duplicate STEP key'.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD refresh_totals.
    SELECT COUNT( * ) FROM zreing_ca_line_a WHERE calc_run_id = @iv_target
      INTO @DATA(lv_lines).
    SELECT DISTINCT ct_uuid, mat_uuid, op_type, op_uuid, cm_h_id
      FROM zreing_ca_line_a WHERE calc_run_id = @iv_target INTO TABLE @DATA(lt_groups).
    DATA(lv_groups) = lines( lt_groups ).
    UPDATE zreing_ca_run_a SET total_lines = @lv_lines, total_groups = @lv_groups
      WHERE calc_run_id = @iv_target.
  ENDMETHOD.

  METHOD regenerate_many.
    IF mv_active = abap_false OR mv_closed = abap_true OR mv_error IS NOT INITIAL OR mv_used = abap_true.
      rs_result-message = 'AN2 context is invalid, closed, or already used'.
      rs_result-failed = abap_true.
      RETURN.
    ENDIF.
    mv_used = abap_true.
    " Eligible subset cannot widen the immutable lock context.
    DATA lt_eligible TYPE HASHED TABLE OF ty_origin WITH UNIQUE KEY origin_run_id origin_line_num.
    LOOP AT it_eligible INTO DATA(ls_eligible).
      IF NOT line_exists( mt_origins[ origin_run_id = ls_eligible-origin_run_id
                                     origin_line_num = ls_eligible-origin_line_num ] ).
        rs_result-message = 'AN2 eligible key is outside the locked context'.
        rs_result-failed = abap_true.
        RETURN.
      ENDIF.
      INSERT ls_eligible INTO TABLE lt_eligible.
      IF sy-subrc <> 0.
        rs_result-message = 'AN2 eligible keys contain a duplicate'.
        rs_result-failed = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
    IF lt_eligible IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        " V001 (CC) - AN2 APJ: retain every field consumed by the source/seed contracts.
        DATA lt_sources TYPE zif_reing_ca_types=>ty_line_t.
        SELECT calc_run_id, line_num, ct_uuid, mat_uuid, ct_id, lifnr, bp_name,
               bukrs_prest, matnr, op_type, op_uuid, op_instance_num, net_amt,
               bukrs_recv, country, ct_currency, local_currency, line_status
          FROM zreing_ca_line_a FOR ALL ENTRIES IN @lt_eligible
          WHERE calc_run_id = @lt_eligible-origin_run_id AND line_num = @lt_eligible-origin_line_num
          INTO CORRESPONDING FIELDS OF TABLE @lt_sources.
        DATA lt_options TYPE tt_option.
        IF lt_sources IS NOT INITIAL.
          " Join the source snapshot; DISTINCT preserves the former FAE option tuple cardinality.
          SELECT DISTINCT option~ct_uuid, option~mat_uuid, option~op_type, option~op_uuid,
                 option~op_instance_num, option~parent_instance_id
            FROM @lt_sources AS origin
            INNER JOIN zreing_ct2_opt_a AS option
              ON option~ct_uuid = origin~ct_uuid AND option~mat_uuid = origin~mat_uuid
            WHERE option~op_type = 'ANT' OR option~op_type = 'AN2'
            INTO CORRESPONDING FIELDS OF TABLE @lt_options.
        ENDIF.
        DATA lt_existing TYPE zif_reing_ca_types=>ty_line_t.
        SELECT calc_run_id, line_num, ct_uuid, mat_uuid, op_type, op_uuid,
               op_instance_num, origin_run_id, origin_line_num, parent_op_type,
               bukrs_recv, line_status
          FROM zreing_ca_line_a FOR ALL ENTRIES IN @lt_eligible
          WHERE origin_run_id = @lt_eligible-origin_run_id
            AND origin_line_num = @lt_eligible-origin_line_num
            AND op_type = 'AN2' INTO CORRESPONDING FIELDS OF TABLE @lt_existing.

        DATA lt_seeds TYPE zif_reing_ca_types=>ty_line_t.
        DATA lt_scope TYPE zif_reing_ca_types=>ty_group_key_t.
        DATA lt_keys TYPE zcl_reing_ca_pipeline=>tt_pending_key.
        SELECT SINGLE MAX( line_num ) FROM zreing_ca_line_a
          WHERE calc_run_id = @mv_target INTO @DATA(lv_max).

        LOOP AT lt_eligible INTO ls_eligible.
          DATA(ls_row) = VALUE ty_batch_row( origin = ls_eligible outcome = 'INVALID' ).
          READ TABLE lt_sources INTO DATA(ls_ant)
            WITH KEY calc_run_id = ls_eligible-origin_run_id line_num = ls_eligible-origin_line_num.
          IF sy-subrc <> 0 OR ls_ant-op_type <> 'ANT' OR ls_ant-line_status <> zif_reing_ca_c=>line_status-cont.
            ls_row-result-message = 'Origin is not an existing ANT in CONT'.
            APPEND ls_row TO rs_result-rows.
            CONTINUE.
          ENDIF.
          DATA(ls_option) = pick_an2_option( is_ant = ls_ant it_options = lt_options ).
          IF ls_option-op_uuid IS INITIAL OR ls_option-op_instance_num IS INITIAL.
            ls_row-result-message = 'Missing, ambiguous, or inconsistent AN2 option'.
            APPEND ls_row TO rs_result-rows.
            CONTINUE.
          ENDIF.
          DATA(lt_for_origin) = VALUE zif_reing_ca_types=>ty_line_t(
            FOR ls_existing IN lt_existing
            WHERE ( origin_run_id = ls_eligible-origin_run_id
              AND origin_line_num = ls_eligible-origin_line_num ) ( ls_existing ) ).
          IF lt_for_origin IS NOT INITIAL.
            ls_row-outcome = 'CONFLICT'.
            IF lines( lt_for_origin ) = 1.
              DATA(ls_old) = lt_for_origin[ 1 ].
              IF same_seed_identity( is_line = ls_old is_ant = ls_ant is_option = ls_option ) = abap_true.
                ls_row-result-calc_run_id = ls_old-calc_run_id.
                ls_row-result-line_num = ls_old-line_num.
                ls_row-outcome = 'EXISTS_PENDING'.
                CASE ls_old-line_status.
                  WHEN 'CALC' OR 'LIBD' OR 'SIM_OK' OR 'SIM_ERR' OR 'SIM_PROC'
                      OR 'POST_PROC' OR 'CONT' OR 'POST_ERR' OR 'ANUL_PROC' OR 'ANUL_ERR'.
                    ls_row-outcome = 'EXISTS_CALC'.
                    ls_row-result-success = abap_true.
                  WHEN 'ANULD'.
                    ls_row-outcome = 'EXISTS_CLOSED'.
                ENDCASE.
                ls_row-result-message = |Existing AN2 status { ls_old-line_status }|.
              ENDIF.
            ENDIF.
            IF ls_row-outcome = 'CONFLICT'.
              ls_row-result-message = 'Origin has multiple or mismatched AN2 derivations'.
            ENDIF.
            APPEND ls_row TO rs_result-rows.
            CONTINUE.
          ENDIF.
          IF lv_max >= 9999999.
            rs_result-failed = abap_true.
            rs_result-message = 'AN2 physical line number capacity exceeded'.
            RETURN.
          ENDIF.
          lv_max = lv_max + 1.
          DATA(ls_seed) = make_seed( is_ant = ls_ant is_option = ls_option
            iv_target = mv_target iv_line_num = lv_max ).
          APPEND ls_seed TO lt_seeds.
          APPEND VALUE #( calc_run_id = mv_target line_num = lv_max ) TO lt_keys.
          APPEND VALUE #( calc_run_id = mv_target ct_uuid = ls_seed-ct_uuid
            mat_uuid = ls_seed-mat_uuid op_type = ls_seed-op_type op_uuid = ls_seed-op_uuid ) TO lt_scope.
          ls_row-outcome = 'PREPARED'.
          ls_row-result-calc_run_id = mv_target.
          ls_row-result-line_num = lv_max.
          APPEND ls_row TO rs_result-rows.
        ENDLOOP.
        IF lt_seeds IS INITIAL.
          RETURN.
        ENDIF.
        SORT lt_scope BY ct_uuid mat_uuid op_type op_uuid cm_h_id.
        DELETE ADJACENT DUPLICATES FROM lt_scope COMPARING ct_uuid mat_uuid op_type op_uuid cm_h_id.
        ensure_batch_run( iv_calc_run_id = mv_target iv_year = mv_year iv_period = mv_period ).
        TEST-SEAM an2_seed_insert.
          INSERT zreing_ca_line_a FROM TABLE @lt_seeds.
        END-TEST-SEAM.
        DATA(lo_pipeline) = NEW zcl_reing_ca_pipeline(
          is_context = VALUE #( calc_run_id = mv_target year = mv_year period = mv_period )
          io_sources = NEW zcl_reing_ca_sources( ) ).
        DATA ls_pipeline_result TYPE zif_reing_ca_types=>ty_pipeline_result.
        TEST-SEAM an2_batch_pipeline.
          ls_pipeline_result = lo_pipeline->execute( it_scope = lt_scope it_pending_keys = lt_keys ).
        END-TEST-SEAM.
        rs_result-message = audit_result( it_seeds = lt_seeds is_result = ls_pipeline_result ).
        IF rs_result-message IS NOT INITIAL.
          rs_result-failed = abap_true.
          RETURN.
        ENDIF.
        IF ls_pipeline_result-lines IS NOT INITIAL.
          UPDATE zreing_ca_line_a FROM TABLE @ls_pipeline_result-lines.
        ENDIF.
        IF ls_pipeline_result-line_pc IS NOT INITIAL.
          INSERT zreing_ca_lpc_a FROM TABLE @ls_pipeline_result-line_pc.
        ENDIF.
        IF ls_pipeline_result-steps IS NOT INITIAL.
          INSERT zreing_ca_step_a FROM TABLE @ls_pipeline_result-steps.
        ENDIF.
        refresh_totals( mv_target ).
        LOOP AT rs_result-rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE outcome = 'PREPARED'.
          <ls_row>-outcome = 'READY_CALC'.
          <ls_row>-result-success = abap_true.
        ENDLOOP.
      CATCH cx_root INTO DATA(lx_batch).
        rs_result-failed = abap_true.
        rs_result-message = lx_batch->get_text( ).
    ENDTRY.
    " Caller JOB owns the second LUW and must rollback every failed batch before logs.
  ENDMETHOD.

ENDCLASS.

