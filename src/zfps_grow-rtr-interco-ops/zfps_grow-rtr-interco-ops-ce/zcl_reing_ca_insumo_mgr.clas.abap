*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_insumo_mgr DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " ATC fix (NonLocal DBWRITE/DBREAD): tipos publicos para register_usage_bulk.
    TYPES ty_usage_t    TYPE STANDARD TABLE OF zreing_calcusage WITH EMPTY KEY.
    TYPES ty_me_h_rang  TYPE RANGE OF zreing_me_h_a-me_h_id.
    " Tipo para el pre-fetch de op_type -> cm_loadable (pasado por el llamador).
    TYPES: BEGIN OF ty_op_flag,
             op_type     TYPE zreing_ca_line_a-op_type,
             cm_loadable TYPE abap_bool,
           END OF ty_op_flag.
    TYPES ty_op_flag_t TYPE STANDARD TABLE OF ty_op_flag WITH EMPTY KEY.
    " Tipo para el pre-fetch de run context (pasado por el llamador).
    TYPES ty_run_ctx_t TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.

    " ATC fix (NonLocal DBREAD via check_consistency en loop): tipos para pre-fetch
    " de los datos que check_consistency necesita internamente.
    " is_orphan desde zc_reingcalineall.
    TYPES: BEGIN OF ty_orphan_ctx,
             ct_uuid   TYPE zreing_ct2_a-ct_uuid,
             mat_uuid  TYPE zreing_ct2_mat_a-mat_uuid,
             op_type   TYPE zreing_ca_line_a-op_type,
             op_uuid   TYPE zreing_ca_line_a-op_uuid,
             bukrs_recv TYPE zreing_ca_line_a-bukrs_recv,
             is_orphan TYPE abap_bool,
           END OF ty_orphan_ctx,
           tt_orphan_ctx TYPE STANDARD TABLE OF ty_orphan_ctx WITH EMPTY KEY.
    " cm_changed_at desde zreing_cm_h_a.
    TYPES: BEGIN OF ty_cm_changed,
             ct_uuid    TYPE zreing_cm_h_a-ct_uuid,
             mat_uuid   TYPE zreing_cm_h_a-mat_uuid,
             op_type    TYPE zreing_cm_h_a-op_type,
             cm_h_id     TYPE zreing_cm_h_a-cm_h_id,
             changed_at TYPE zreing_cm_h_a-changed_at,
           END OF ty_cm_changed,
           tt_cm_changed TYPE STANDARD TABLE OF ty_cm_changed WITH EMPTY KEY.
    " me_changed_at desde zreing_me_h_a.
    TYPES: BEGIN OF ty_me_changed,
             ct_id           TYPE zreing_me_h_a-ct_id,
             matnr           TYPE zreing_me_h_a-matnr,
             last_changed_at TYPE zreing_me_h_a-last_changed_at,
           END OF ty_me_changed,
           tt_me_changed TYPE STANDARD TABLE OF ty_me_changed WITH EMPTY KEY.

    METHODS constructor
      IMPORTING io_sources TYPE REF TO zif_reing_ca_sources.

    " ATC fix (NonLocal DBREAD via check_consistency): parametros opcionales para
    " recibir datos pre-cargados -- si se pasan, CERO SELECTs en este metodo.
    METHODS check_consistency
      IMPORTING it_group_lines   TYPE zif_reing_ca_types=>ty_line_t
                iv_fiscal_period TYPE zreing_ca_run_a-fiscal_period OPTIONAL
                iv_fiscal_year   TYPE zreing_ca_run_a-fiscal_year   OPTIONAL
                it_orphan_ctx    TYPE tt_orphan_ctx                  OPTIONAL
                it_cm_changed    TYPE tt_cm_changed                  OPTIONAL
                it_me_changed    TYPE tt_me_changed                  OPTIONAL
      RETURNING VALUE(rs_check)  TYPE zif_reing_ca_types=>ty_consistency_result.

    METHODS register_usage
      IMPORTING is_line TYPE zreing_ca_line_a
      RAISING   zcx_reing_ca_calc_error.

    " ATC fix (NonLocal DBWRITE/DBREAD in loop): version bulk de register_usage.
    " CERO SELECT aqui -- el llamador pre-carga todos los datos antes del LOOP AT keys
    " y los pasa como parametros. Solo logica ABAP pura y construccion de tablas.
    " El llamador ejecuta INSERT/UPDATE FUERA del LOOP AT keys.
    METHODS register_usage_bulk
      IMPORTING it_lines    TYPE zif_reing_ca_types=>ty_line_t
                it_runs     TYPE ty_run_ctx_t
                it_op_flags TYPE ty_op_flag_t
                iv_next_seq TYPE n
      EXPORTING et_usages   TYPE ty_usage_t
                et_me_h_ids TYPE ty_me_h_rang
      RAISING   zcx_reing_ca_calc_error.

    METHODS revert_usage
      IMPORTING iv_calc_run_id TYPE zreing_ca_line_a-calc_run_id
                iv_line_num    TYPE zreing_ca_line_a-line_num.

    " V001 (CC) - #105: batch cancellation, shared-reservation guard.
    METHODS revert_usage_bulk
      IMPORTING it_lines TYPE zif_reing_ca_types=>ty_line_t.

    METHODS set_reserved
      IMPORTING iv_me_h_id TYPE zreing_me_h_a-me_h_id.
METHODS check_groups_stale
      IMPORTING it_runs         TYPE ty_run_ctx_t
                it_groups       TYPE zreing_ca_tt_group_key
      RETURNING VALUE(rt_stale) TYPE zreing_ca_tt_group_key.

  PRIVATE SECTION.
METHODS resolve_me_period
      IMPORTING iv_op_uuid      TYPE zreing_ca_line_a-op_uuid
                iv_period       TYPE zreing_ca_run_a-fiscal_period
                iv_year         TYPE zreing_ca_run_a-fiscal_year
      EXPORTING ev_period_month TYPE zreing_me_h_a-period_month
                ev_period_year  TYPE zreing_me_h_a-period_year.
    DATA mo_sources TYPE REF TO zif_reing_ca_sources.

ENDCLASS.

CLASS zcl_reing_ca_insumo_mgr IMPLEMENTATION.

  METHOD constructor.
    mo_sources = io_sources.
  ENDMETHOD.

  METHOD check_consistency.
    " ATC fix (NonLocal DBREAD): todos los datos vienen pre-cargados como parametros.
    " CERO SELECTs -- los fallbacks SELECT fueron eliminados porque el unico llamador
    " de produccion (check_consistency_for_release via release) siempre pasa
    " iv_fiscal_period/year + it_orphan_ctx + it_cm_changed + it_me_changed.
    IF it_group_lines IS INITIAL.
      RETURN.
    ENDIF.

    DATA(ls_first) = it_group_lines[ 1 ].

    " Run context: siempre provisto por el llamador en produccion.
    DATA ls_run TYPE zreing_ca_run_a.
    ls_run-fiscal_period = iv_fiscal_period.
    ls_run-fiscal_year   = iv_fiscal_year.

    " is_orphan desde tabla pre-cargada (CERO SELECT).
    IF it_orphan_ctx IS NOT INITIAL.
      READ TABLE it_orphan_ctx INTO DATA(ls_orphan_ctx)
        WITH KEY ct_uuid    = ls_first-ct_uuid
                 mat_uuid   = ls_first-mat_uuid
                 op_type    = ls_first-op_type
                 op_uuid    = ls_first-op_uuid
                 bukrs_recv = ls_first-bukrs_recv.
      IF sy-subrc = 0.
        rs_check-is_orphan = ls_orphan_ctx-is_orphan.
      ENDIF.
    ENDIF.

    DATA(lv_check_at) = COND timestampl( WHEN ls_first-insumo_check_at IS NOT INITIAL
                                          THEN ls_first-insumo_check_at
                                          ELSE ls_first-proc_started_at ).

    " cm_changed_at desde tabla pre-cargada (CERO SELECT).
    DATA lv_cm_changed_at TYPE timestampl.
    IF it_cm_changed IS NOT INITIAL.
      READ TABLE it_cm_changed INTO DATA(ls_cm_chg)
        WITH KEY ct_uuid  = ls_first-ct_uuid
                 mat_uuid = ls_first-mat_uuid
                 op_type  = ls_first-op_type
                 cm_h_id  = ls_first-cm_h_id.
      IF sy-subrc = 0.
        lv_cm_changed_at = ls_cm_chg-changed_at.
      ENDIF.
    ENDIF.

    " me_changed_at desde tabla pre-cargada (CERO SELECT).
    DATA lv_me_changed_at TYPE timestampl.
    IF it_me_changed IS NOT INITIAL.
      READ TABLE it_me_changed INTO DATA(ls_me_chg)
        WITH KEY ct_id = ls_first-ct_id
                 matnr = ls_first-matnr.
      IF sy-subrc = 0.
        lv_me_changed_at = ls_me_chg-last_changed_at.
      ENDIF.
    ENDIF.

    rs_check-is_stale = xsdbool( lv_cm_changed_at > lv_check_at OR lv_me_changed_at > lv_check_at ).

    " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-10 --
    " distingue si la causa de un CM_H_A modificado es especificamente un
    " delta pendiente de recalcular (BR-CA-41), en vez de dejar solo el
    " mensaje generico de IS_STALE. Reutiliza get_cm_amount (misma fuente
    " que step_validate usa para detectar delta_flag) en modo solo-lectura;
    " sin CM elegible (tipos no CM_LOADABLE, o sin carga LIBD) no es un
    " error de este chequeo -- se deja DELTA_PENDING en abap_false.
    TRY.
        DATA(ls_cm_check) = mo_sources->get_cm_amount(
                               iv_ct_uuid  = ls_first-ct_uuid
                               iv_mat_uuid = ls_first-mat_uuid
                               iv_op_type  = ls_first-op_type
                               iv_period   = iv_fiscal_period
                               iv_year     = iv_fiscal_year
                               iv_cm_h_id  = ls_first-cm_h_id ).
        IF ls_cm_check-delta_flag = abap_true AND ls_first-is_delta <> abap_true.
          rs_check-delta_pending = abap_true.
        ENDIF.
      CATCH zcx_reing_ca_calc_error.
        " Sin CM_H_A elegible: no aplica (tipo no CM_LOADABLE, u otra causa
        " de IS_STALE ajena al mecanismo delta).
    ENDTRY.
    " End Change ID V003 (04.08.2026 | EXT_GONZALCA)

    " Begin Mod V004 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : los shares "vivos" se leian con el periodo del RUN,
    " mientras que las lineas contra las que se comparan se calculan con el
    " periodo M-offset (BR-CA-40, ver V006 del pipeline). Para un contrato
    " con ME_PERIOD_OFFSET = '01' eso enfrentaba dos universos distintos de
    " receptoras -- las de M-1 (calculadas) contra las de M (vivas) -- y
    " producia ADDED_RECEPTORS / REMOVED_RECEPTORS inexistentes, o sea un
    " warning de consistencia espurio en CADA Release del grupo.
    " Ahora se compara contra el mismo periodo que alimento el calculo.
    " Lineas originales conservadas como referencia:
    "    iv_period_year  = ls_run-fiscal_year
    "    iv_period_month = ls_run-fiscal_period
    DATA lv_me_month TYPE zreing_me_h_a-period_month.
    DATA lv_me_year  TYPE zreing_me_h_a-period_year.
    resolve_me_period( EXPORTING iv_op_uuid      = ls_first-op_uuid
                                 iv_period       = ls_run-fiscal_period
                                 iv_year         = ls_run-fiscal_year
                       IMPORTING ev_period_month = lv_me_month
                                 ev_period_year  = lv_me_year ).

    DATA lt_live_shares TYPE zif_reing_ca_types=>ty_me_item_t.
    TRY.
        lt_live_shares = mo_sources->get_me_shares(
                            iv_ct_id        = ls_first-ct_id
                            iv_matnr        = ls_first-matnr
                            iv_period_year  = lv_me_year
                            iv_period_month = lv_me_month ).
      CATCH zcx_reing_ca_calc_error.
        CLEAR lt_live_shares.
    ENDTRY.
    " End Mod V004 (08.09.2026 | EXT_GONZALCA)

    DATA lt_current_bukrs TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY.
    DATA lt_live_bukrs     TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY.

    LOOP AT it_group_lines INTO DATA(ls_gl).
      APPEND ls_gl-bukrs_recv TO lt_current_bukrs.
    ENDLOOP.
    SORT lt_current_bukrs.
    DELETE ADJACENT DUPLICATES FROM lt_current_bukrs.

    LOOP AT lt_live_shares INTO DATA(ls_live_share).
      APPEND ls_live_share-bukrs TO lt_live_bukrs.
    ENDLOOP.
    SORT lt_live_bukrs.
    DELETE ADJACENT DUPLICATES FROM lt_live_bukrs.

    LOOP AT lt_live_bukrs INTO DATA(lv_live_b).
      IF NOT line_exists( lt_current_bukrs[ table_line = lv_live_b ] ).
        APPEND lv_live_b TO rs_check-added_receptors.
      ENDIF.
    ENDLOOP.

    LOOP AT lt_current_bukrs INTO DATA(lv_cur_b).
      IF NOT line_exists( lt_live_bukrs[ table_line = lv_cur_b ] ).
        APPEND lv_cur_b TO rs_check-removed_receptors.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD register_usage.
    SELECT SINGLE fiscal_period, fiscal_year
      FROM zreing_ca_run_a
      WHERE calc_run_id = @is_line-calc_run_id
      INTO @DATA(ls_run).

    SELECT SINGLE cm_loadable
      FROM zreing_op_type_c
      WHERE op_type = @is_line-op_type
      INTO @DATA(lv_cm_loadable).

    DATA(lv_today)   = sy-datum.
    DATA(lv_pattern) = |USG-{ lv_today }-%|.
    SELECT SINGLE MAX( usage_id ) AS usage_id
      FROM zreing_calcusage
      WHERE usage_id LIKE @lv_pattern
      INTO @DATA(lv_max_id).

    TYPES ty_usage_seq TYPE n LENGTH 6.
    DATA(lv_next) = COND ty_usage_seq( WHEN lv_max_id IS INITIAL THEN '000001'
                                        ELSE |{ CONV ty_usage_seq( lv_max_id+13(6) ) + 1 }| ).

    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    DATA ls_usage TYPE zreing_calcusage.
    ls_usage-usage_id    = |USG-{ lv_today }-{ lv_next }|.
    ls_usage-calc_run_id = is_line-calc_run_id.
    ls_usage-line_num    = is_line-line_num.
    ls_usage-used_at     = lv_ts.

    IF lv_cm_loadable = abap_true.
      DATA(ls_cm) = mo_sources->get_cm_amount(
                       iv_ct_uuid  = is_line-ct_uuid
                       iv_mat_uuid = is_line-mat_uuid
                       iv_op_type  = is_line-op_type
                       iv_period   = ls_run-fiscal_period
                       iv_year     = ls_run-fiscal_year
                       iv_cm_h_id  = is_line-cm_h_id ).
      ls_usage-insumo_type = zif_reing_ca_c=>insumo_type-cm.
      TRY.
          cl_system_uuid=>if_system_uuid_static~convert_uuid_x16(
            EXPORTING uuid     = ls_cm-cm_h_id
            IMPORTING uuid_c32 = DATA(lv_cm_h_c32) ).
          ls_usage-cm_h_id = lv_cm_h_c32(20).
        CATCH cx_uuid_error INTO DATA(lo_uuid_error).
          RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
            EXPORTING
              iv_message = |cm_h_id invalido al registrar uso: { lo_uuid_error->get_text( ) }|
              previous   = lo_uuid_error.
      ENDTRY.
      ls_usage-cm_load_seq = ls_cm-load_seq.
    ELSE.
      " Begin Mod V004 (08.09.2026 | EXT_GONZALCA)
      " Mismo fix que en register_usage_bulk: el ME_H_ID registrado como
      " insumo consumido tiene que ser el del periodo que el calculo leyo
      " (ME_PERIOD_OFFSET, BR-CA-40) y no el del periodo del run. Ver la
      " nota completa alli.
      " Lineas originales conservadas como referencia:
      "    iv_period_year  = ls_run-fiscal_year
      "    iv_period_month = ls_run-fiscal_period
      DATA lv_me_month TYPE zreing_me_h_a-period_month.
      DATA lv_me_year  TYPE zreing_me_h_a-period_year.
      resolve_me_period( EXPORTING iv_op_uuid      = is_line-op_uuid
                                   iv_period       = ls_run-fiscal_period
                                   iv_year         = ls_run-fiscal_year
                         IMPORTING ev_period_month = lv_me_month
                                   ev_period_year  = lv_me_year ).

      DATA(lt_shares) = mo_sources->get_me_shares(
                           iv_ct_id        = is_line-ct_id
                           iv_matnr        = is_line-matnr
                           iv_period_year  = lv_me_year
                           iv_period_month = lv_me_month ).
      " End Mod V004 (08.09.2026 | EXT_GONZALCA)
      DATA(ls_my_share) = VALUE #( lt_shares[ bukrs = is_line-bukrs_recv ] OPTIONAL ).
      ls_usage-insumo_type = zif_reing_ca_c=>insumo_type-me.
      ls_usage-me_h_id     = ls_my_share-me_h_id.
      IF ls_usage-me_h_id IS NOT INITIAL.
        ls_usage-libr_set_at = lv_ts.
      ENDIF.
    ENDIF.

    INSERT zreing_calcusage FROM @ls_usage.

    IF ls_usage-insumo_type = zif_reing_ca_c=>insumo_type-me AND ls_usage-me_h_id IS NOT INITIAL.
      set_reserved( iv_me_h_id = ls_usage-me_h_id ).
    ENDIF.
  ENDMETHOD.

  METHOD register_usage_bulk.
    " ATC fix (NonLocal DBWRITE/DBREAD via register_usage en LOOP AT keys):
    " CERO SELECT aqui. Todos los datos vienen pre-cargados como parametros
    " (it_runs, it_op_flags, iv_next_seq) -- el llamador (release) los obtiene
    " con SELECTs bulk ANTES del LOOP AT keys. Solo logica ABAP pura.
    CHECK it_lines IS NOT INITIAL.

    DATA(lv_today) = sy-datum.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.

    TYPES ty_usage_seq TYPE n LENGTH 6.
    DATA lv_next_seq TYPE ty_usage_seq.
    lv_next_seq = iv_next_seq.

    LOOP AT it_lines INTO DATA(ls_line).
      " Run context desde tabla pre-cargada (CERO SELECT).
      READ TABLE it_runs INTO DATA(ls_run) WITH KEY calc_run_id = ls_line-calc_run_id.
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      " cm_loadable desde tabla pre-cargada (CERO SELECT).
      READ TABLE it_op_flags INTO DATA(ls_op) WITH KEY op_type = ls_line-op_type.
      DATA(lv_cm_loadable) = COND abap_bool( WHEN sy-subrc = 0 THEN ls_op-cm_loadable
                                              ELSE abap_false ).

      DATA ls_usage TYPE zreing_calcusage.
      ls_usage-usage_id    = |USG-{ lv_today }-{ lv_next_seq }|.
      ls_usage-calc_run_id = ls_line-calc_run_id.
      ls_usage-line_num    = ls_line-line_num.
      ls_usage-used_at     = lv_ts.

      IF lv_cm_loadable = abap_true.
        DATA(ls_cm) = mo_sources->get_cm_amount(
                         iv_ct_uuid  = ls_line-ct_uuid
                         iv_mat_uuid = ls_line-mat_uuid
                         iv_op_type  = ls_line-op_type
                         iv_period   = ls_run-fiscal_period
                         iv_year     = ls_run-fiscal_year
                         iv_cm_h_id  = ls_line-cm_h_id ).
        ls_usage-insumo_type = zif_reing_ca_c=>insumo_type-cm.
        TRY.
            cl_system_uuid=>if_system_uuid_static~convert_uuid_x16(
              EXPORTING uuid     = ls_cm-cm_h_id
              IMPORTING uuid_c32 = DATA(lv_cm_h_c32) ).
            ls_usage-cm_h_id = lv_cm_h_c32(20).
          CATCH cx_uuid_error INTO DATA(lo_uuid_error).
            RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
              EXPORTING
                iv_message = |cm_h_id invalido al registrar uso: { lo_uuid_error->get_text( ) }|
                previous   = lo_uuid_error.
        ENDTRY.
        ls_usage-cm_load_seq = ls_cm-load_seq.
      ELSE.
        " Begin Mod V004 (08.09.2026 | EXT_GONZALCA)
        " Descripcion : el ME_H_ID que se registra como insumo consumido (y
        " que pasa a LIBR via et_me_h_ids) debe ser el del periodo que el
        " calculo REALMENTE leyo, o sea el resuelto con ME_PERIOD_OFFSET
        " (BR-CA-40). Con el periodo del run, un contrato con offset '01'
        " reservaba el header de M y dejaba libre el de M-1 -- justo el que
        " alimento el calculo -- de modo que la metrica efectivamente usada
        " quedaba modificable despues de liberar.
        " ALCANCE REAL: esta rama solo corre para OP_TYPEs que NO son
        " CM_LOADABLE; los afectados por el offset en el caso reportado
        " (F/P/A/NC) entran por la rama CM de arriba y no pasan por aca. Se
        " corrige por consistencia y para que no quede una segunda lectura
        " de ME con criterio distinto al del pipeline.
        " Lineas originales conservadas como referencia:
        "    iv_period_year  = ls_run-fiscal_year
        "    iv_period_month = ls_run-fiscal_period
        DATA lv_me_month TYPE zreing_me_h_a-period_month.
        DATA lv_me_year  TYPE zreing_me_h_a-period_year.
        resolve_me_period( EXPORTING iv_op_uuid      = ls_line-op_uuid
                                     iv_period       = ls_run-fiscal_period
                                     iv_year         = ls_run-fiscal_year
                           IMPORTING ev_period_month = lv_me_month
                                     ev_period_year  = lv_me_year ).

        DATA(lt_shares) = mo_sources->get_me_shares(
                             iv_ct_id        = ls_line-ct_id
                             iv_matnr        = ls_line-matnr
                             iv_period_year  = lv_me_year
                             iv_period_month = lv_me_month ).
        " End Mod V004 (08.09.2026 | EXT_GONZALCA)
        DATA(ls_my_share) = VALUE #( lt_shares[ bukrs = ls_line-bukrs_recv ] OPTIONAL ).
        ls_usage-insumo_type = zif_reing_ca_c=>insumo_type-me.
        ls_usage-me_h_id     = ls_my_share-me_h_id.
        IF ls_usage-me_h_id IS NOT INITIAL.
          ls_usage-libr_set_at = lv_ts.
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_usage-me_h_id ) TO et_me_h_ids.
        ENDIF.
      ENDIF.

      APPEND ls_usage TO et_usages.
      lv_next_seq = lv_next_seq + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD revert_usage.
    " V001 (CC) - #105: keep the existing API; persisted ANULD is revalidated.
    revert_usage_bulk( VALUE #( ( calc_run_id = iv_calc_run_id
                                 line_num = iv_line_num
                                 line_status = zif_reing_ca_c=>line_status-anuld ) ) ).
  ENDMETHOD.

  METHOD revert_usage_bulk.
    " V001 (CC) - #105: preserve usage history; no COMMIT in this helper.
    CHECK it_lines IS NOT INITIAL.
    DATA lt_keys TYPE zif_reing_ca_types=>ty_line_t.
    lt_keys = VALUE #( FOR ls_line IN it_lines
      WHERE ( line_status = zif_reing_ca_c=>line_status-anuld )
      ( calc_run_id = ls_line-calc_run_id line_num = ls_line-line_num ) ).
    SORT lt_keys BY calc_run_id line_num.
    DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING calc_run_id line_num.
    CHECK lt_keys IS NOT INITIAL.

    DATA lv_initial_ts TYPE timestampl.
    DATA lv_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_ts.
    " A failed reversal remains CONT. Check the stored image as well as the input.
    SELECT u~usage_id, u~insumo_type, u~me_h_id
      FROM zreing_calcusage AS u
      INNER JOIN zreing_ca_line_a AS l
        ON l~calc_run_id = u~calc_run_id AND l~line_num = u~line_num
      FOR ALL ENTRIES IN @lt_keys
      WHERE u~calc_run_id = @lt_keys-calc_run_id
        AND u~line_num = @lt_keys-line_num
        AND l~line_status = @zif_reing_ca_c=>line_status-anuld
        AND ( u~libr_rev_at = @lv_initial_ts OR u~libr_rev_at IS NULL )
      INTO TABLE @DATA(lt_usage).
    CHECK lt_usage IS NOT INITIAL.

    DATA lt_usage_ids TYPE RANGE OF zreing_calcusage-usage_id.
    lt_usage_ids = VALUE #( FOR ls_usage IN lt_usage
      ( sign = 'I' option = 'EQ' low = ls_usage-usage_id ) ).
    DATA lt_me_ids TYPE ty_me_h_rang.
    lt_me_ids = VALUE #( FOR ls_usage IN lt_usage
      WHERE ( insumo_type = zif_reing_ca_c=>insumo_type-me
              AND me_h_id IS NOT INITIAL )
      ( sign = 'I' option = 'EQ' low = ls_usage-me_h_id ) ).
    SORT lt_me_ids BY low.
    DELETE ADJACENT DUPLICATES FROM lt_me_ids COMPARING low.

    UPDATE zreing_calcusage SET libr_rev_at = @lv_ts
      WHERE usage_id IN @lt_usage_ids
        AND ( libr_rev_at = @lv_initial_ts OR libr_rev_at IS NULL ).

    IF lt_me_ids IS NOT INITIAL.
      " Check remaining users atomically with the status update, including other runs.
      UPDATE zreing_me_h_a SET me_status = 'LIBD'
        WHERE me_h_id IN @lt_me_ids AND me_status = 'LIBR'
          AND NOT EXISTS ( SELECT * FROM zreing_calcusage AS u
            WHERE u~me_h_id = zreing_me_h_a~me_h_id
              AND u~insumo_type = @zif_reing_ca_c=>insumo_type-me
              AND ( u~libr_rev_at = @lv_initial_ts OR u~libr_rev_at IS NULL ) ).
    ENDIF.
  ENDMETHOD.

  METHOD set_reserved.
    UPDATE zreing_me_h_a SET me_status = 'LIBR'
      WHERE me_h_id   = @iv_me_h_id
        AND me_status = @zif_reing_ca_c=>me_eligible_status-libd.
  ENDMETHOD.

  METHOD resolve_me_period.
    " Begin Change ID V004 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : resuelve el periodo de lectura de la metrica ME segun
    " ME_PERIOD_OFFSET del op_uuid (BR-CA-40), delegando la aritmetica a
    " ZCL_REING_CA_SOURCES=>CALC_ME_PERIOD -- la MISMA que usa el pipeline
    " en ZCL_REING_CA_PIPELINE~resolve_me_period.
    "
    " Por que hace falta aca: esta clase comparaba las receptoras del
    " calculo contra las "vivas" de ME leidas con el periodo del RUN. Desde
    " V006 del pipeline (08.09.2026) las lineas se calculan con los shares
    " del periodo M-offset, asi que para un contrato con offset '01' la
    " comparacion enfrentaba dos universos distintos (receptoras de M-1
    " contra receptoras de M) y reportaba ADDED_RECEPTORS /
    " REMOVED_RECEPTORS que no existen -- un warning de consistencia
    " espurio en cada Release.
    "
    " get_ct_option es un SELECT SINGLE. Este metodo se llama una vez por
    " grupo (check_consistency) o por linea (register_usage*), igual que el
    " get_cm_amount / get_me_shares que estos metodos ya invocaban -- no
    " introduce un patron de acceso nuevo respecto del que la clase ya
    " tenia. Si el ATC llegara a marcarlo, el pre-fetch corresponde al
    " llamador (release), que es quien tiene el bulk de grupos.
    DATA(ls_ct_opt) = mo_sources->get_ct_option( iv_op_uuid = iv_op_uuid ).

    zcl_reing_ca_sources=>calc_me_period(
      EXPORTING iv_offset       = ls_ct_opt-me_period_offset
                iv_period       = iv_period
                iv_year         = iv_year
      IMPORTING ev_period_month = ev_period_month
                ev_period_year  = ev_period_year ).
    " End Change ID V004 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
  METHOD check_groups_stale.
    " Begin Change ID V004 (08.09.2026 | EXT_GONZALCA)
    " Descripcion : chequeo de frescura de insumos en BULK para los grupos
    " de uno o varios runs. Devuelve los grupos que dieron IS_STALE o con
    " receptoras agregadas/quitadas.
    "
    " Por que existe: spec-F3.3 SSC y la regla SS2.12 piden el chequeo de
    " consistencia antes de Release Y de Simulate/Post ("se amplia a
    " Simulate/Post cuando F4 los agregue"). F4 los agrego el 05.08.2026
    " (V012) y la ampliacion nunca se hizo: hasta hoy solo Release lo
    " invocaba, asi que se podia simular y contabilizar un grupo con
    " insumos cambiados sin ningun aviso.
    " El pre-fetch de los contextos vive aca y no en el behavior pool a
    " proposito: es responsabilidad del Insumo Manager, y replicarlo por
    " tercera vez en ZBP_REINGCARUN habria significado ~150 lineas de
    " SELECTs duplicadas en el objeto mas fragil del proyecto.
    "
    " ALCANCE -- por que NO se lee IS_ORPHAN aca (Mod V005, 08.09.2026):
    " este metodo solo evalua FRESCURA. IS_ORPHAN es un error duro con su
    " propio tratamiento en Release ("use Delete en su lugar") y no un aviso
    " de insumos desactualizados, asi que rs_check-is_orphan se descarta unas
    " lineas mas abajo. La primera version igual pre-cargaba IT_ORPHAN_CTX
    " desde ZC_REINGCALINEALL para pasarselo a check_consistency: era una
    " lectura de una vista CDS con UNION cuyo unico resultado se tiraba.
    " Al no pasarlo, check_consistency deja IS_ORPHAN vacio -- que es
    " exactamente lo que corresponde -- y de paso desaparece el hallazgo ATC
    " CL_CI_TEST_FOR_ALL_ENTR_HANA/TRANSFORM (prioridad 1 para el cliente,
    " bloqueaba la liberacion de la orden): ese SELECT usaba como driver de
    " FOR ALL ENTRIES el resultado de otro SELECT.
    " NO reintroducir la lectura de orphan aca sin antes darle un uso real.
    "
    " LIMITACION CONSCIENTE: el tipo de retorno ZREING_CA_TT_GROUP_KEY no
    " tiene CALC_RUN_ID (ty_group_key es ct_uuid+mat_uuid+op_type+op_uuid),
    " asi que un grupo se devuelve como stale si lo es en CUALQUIERA de los
    " runs de IT_RUNS. Con varios runs en la misma llamada y el mismo grupo
    " en estados distintos, el aviso puede sobrar para uno de ellos. Es
    " aceptable porque el resultado alimenta un WARNING INFORMATIVO, no una
    " decision de bloqueo -- y en la practica Simulate/Post se invocan sobre
    " un unico run. Si algun dia hace falta precision por run, el camino es
    " un tipo de retorno propio, no cambiar ty_group_key (lo consume el
    " %param de las cuatro actions).
    "
    " DEUDA CONOCIDA: RELEASE sigue armando su propio pre-fetch inline
    " (bloques D/E/F de su codigo). No se unifico porque Release es el camino
    " critico que se corrigio y verifico el mismo dia. La unificacion
    " corresponde hacerla junto con la semantica definitiva del warning
    " (accion WarnAck o dialogo 412), hoy escalada y sin respuesta: hacerla
    " antes obligaria a tocar los mismos lugares dos veces.
    CHECK it_groups IS NOT INITIAL AND it_runs IS NOT INITIAL.

    DATA lt_run_rng   TYPE RANGE OF zreing_ca_run_a-calc_run_id.
    DATA lt_year_rng  TYPE RANGE OF zreing_me_h_a-period_year.
    DATA lt_month_rng TYPE RANGE OF zreing_me_h_a-period_month.
    LOOP AT it_runs INTO DATA(ls_run_in).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_run_in-calc_run_id ) TO lt_run_rng.
      IF NOT line_exists( lt_year_rng[ low = ls_run_in-fiscal_year ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_run_in-fiscal_year ) TO lt_year_rng.
      ENDIF.
      IF NOT line_exists( lt_month_rng[ low = ls_run_in-fiscal_period ] ).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_run_in-fiscal_period ) TO lt_month_rng.
      ENDIF.
    ENDLOOP.

    " Lineas de todos los grupos de todos los runs -- un solo SELECT.
    DATA lt_lines TYPE zif_reing_ca_types=>ty_line_t.
    SELECT calc_run_id, line_num, ct_uuid, ct_id, mat_uuid, matnr,
           op_type, op_uuid, cm_h_id, cm_load_seq, bukrs_recv, line_status,
           insumo_check_at, proc_started_at, is_delta
      FROM zreing_ca_line_a
      FOR ALL ENTRIES IN @it_groups
      WHERE calc_run_id IN @lt_run_rng
        AND ct_uuid   = @it_groups-ct_uuid
        AND mat_uuid  = @it_groups-mat_uuid
        AND op_type   = @it_groups-op_type
        AND op_uuid   = @it_groups-op_uuid
        AND cm_h_id   = @it_groups-cm_h_id
      INTO CORRESPONDING FIELDS OF TABLE @lt_lines.
    IF lt_lines IS INITIAL.
      RETURN.
    ENDIF.

    " cm_changed_at: MAX por grupo, en ABAP (FOR ALL ENTRIES no admite GROUP BY).
    " El driver es IT_GROUPS (un parametro), no el resultado de otro SELECT.
    DATA lt_cm_changed TYPE tt_cm_changed.
    SELECT ct_uuid, mat_uuid, op_type, cm_h_id, changed_at
      FROM zreing_cm_h_a
      FOR ALL ENTRIES IN @it_groups
      WHERE ct_uuid      = @it_groups-ct_uuid
        AND mat_uuid     = @it_groups-mat_uuid
        AND op_type      = @it_groups-op_type
        AND cm_h_id       = @it_groups-cm_h_id
        AND period_year  IN @lt_year_rng
        AND period_month IN @lt_month_rng
      INTO TABLE @DATA(lt_cm_raw).
    LOOP AT lt_cm_raw INTO DATA(ls_cm_raw).
      ASSIGN lt_cm_changed[ ct_uuid  = ls_cm_raw-ct_uuid
                            mat_uuid = ls_cm_raw-mat_uuid
                            op_type  = ls_cm_raw-op_type
                            cm_h_id  = ls_cm_raw-cm_h_id ] TO FIELD-SYMBOL(<ls_cm>).
      IF sy-subrc = 0.
        IF ls_cm_raw-changed_at > <ls_cm>-changed_at.
          <ls_cm>-changed_at = ls_cm_raw-changed_at.
        ENDIF.
      ELSE.
        APPEND VALUE ty_cm_changed( ct_uuid    = ls_cm_raw-ct_uuid
                                     mat_uuid   = ls_cm_raw-mat_uuid
                                     op_type    = ls_cm_raw-op_type
                                     cm_h_id     = ls_cm_raw-cm_h_id
                                     changed_at = ls_cm_raw-changed_at ) TO lt_cm_changed.
      ENDIF.
    ENDLOOP.

    " me_changed_at: MAX por ct_id+matnr, mismo patron.
    DATA lt_me_changed TYPE tt_me_changed.
    DATA lt_me_driver  TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
    LOOP AT lt_lines INTO DATA(ls_ln_drv).
      IF NOT line_exists( lt_me_driver[ ct_id = ls_ln_drv-ct_id matnr = ls_ln_drv-matnr ] ).
        APPEND VALUE zreing_me_h_a( ct_id = ls_ln_drv-ct_id matnr = ls_ln_drv-matnr )
          TO lt_me_driver.
      ENDIF.
    ENDLOOP.
    IF lt_me_driver IS NOT INITIAL.
      SELECT ct_id, matnr, last_changed_at
        FROM zreing_me_h_a
        FOR ALL ENTRIES IN @lt_me_driver
        WHERE ct_id        = @lt_me_driver-ct_id
          AND matnr        = @lt_me_driver-matnr
          AND period_year  IN @lt_year_rng
          AND period_month IN @lt_month_rng
        INTO TABLE @DATA(lt_me_raw).
      LOOP AT lt_me_raw INTO DATA(ls_me_raw).
        ASSIGN lt_me_changed[ ct_id = ls_me_raw-ct_id
                              matnr = ls_me_raw-matnr ] TO FIELD-SYMBOL(<ls_me>).
        IF sy-subrc = 0.
          IF ls_me_raw-last_changed_at > <ls_me>-last_changed_at.
            <ls_me>-last_changed_at = ls_me_raw-last_changed_at.
          ENDIF.
        ELSE.
          APPEND VALUE ty_me_changed( ct_id           = ls_me_raw-ct_id
                                       matnr           = ls_me_raw-matnr
                                       last_changed_at = ls_me_raw-last_changed_at ) TO lt_me_changed.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Evaluacion por (run, grupo). check_consistency ya es CERO SELECT con
    " estos contextos pre-cargados, asi que este recorrido no toca la base.
    " ATC fix (Loops anidados, ZMELI_CLEAN_CORE): DO...TIMES + READ TABLE
    " INDEX en vez de LOOP AT dentro de LOOP AT -- mismo patron que ya usa
    " ZBP_REINGCARUN y ZCL_REING_CA_CALC_JOB~reconcile_lines, donde este
    " mismo hallazgo llego a bloquear la liberacion a Calidad.
    DATA ls_run_ev  LIKE LINE OF it_runs.
    DATA ls_grp_ev  LIKE LINE OF it_groups.
    DATA lv_idx_run TYPE i.
    DATA lv_idx_grp TYPE i.
    DATA lt_grp_lines TYPE zif_reing_ca_types=>ty_line_t.

    lv_idx_run = 1.
    DO lines( it_runs ) TIMES.
      READ TABLE it_runs INTO ls_run_ev INDEX lv_idx_run.
      lv_idx_run = lv_idx_run + 1.

      lv_idx_grp = 1.
      DO lines( it_groups ) TIMES.
        READ TABLE it_groups INTO ls_grp_ev INDEX lv_idx_grp.
        lv_idx_grp = lv_idx_grp + 1.

        CLEAR lt_grp_lines.
        lt_grp_lines = VALUE #( FOR ls_l IN lt_lines
          WHERE ( calc_run_id = ls_run_ev-calc_run_id
                  AND ct_uuid = ls_grp_ev-ct_uuid AND mat_uuid = ls_grp_ev-mat_uuid
                  AND op_type = ls_grp_ev-op_type AND op_uuid  = ls_grp_ev-op_uuid
                  AND cm_h_id = ls_grp_ev-cm_h_id )
          ( ls_l ) ).
        IF lt_grp_lines IS INITIAL.
          CONTINUE.
        ENDIF.

        " IT_ORPHAN_CTX se omite deliberadamente (ver ALCANCE arriba):
        " IS_ORPHAN no se evalua en este metodo.
        DATA(ls_chk) = check_consistency(
          it_group_lines   = lt_grp_lines
          iv_fiscal_period = ls_run_ev-fiscal_period
          iv_fiscal_year   = ls_run_ev-fiscal_year
          it_cm_changed    = lt_cm_changed
          it_me_changed    = lt_me_changed ).

        IF ls_chk-is_stale = abap_true
        OR ls_chk-added_receptors IS NOT INITIAL
        OR ls_chk-removed_receptors IS NOT INITIAL.
          " Sin CALC_RUN_ID (ver LIMITACION arriba) y sin duplicar el grupo
          " si resulta stale en mas de un run del lote.
          IF NOT line_exists( rt_stale[ ct_uuid  = ls_grp_ev-ct_uuid
                                        mat_uuid = ls_grp_ev-mat_uuid
                                        op_type  = ls_grp_ev-op_type
                                        op_uuid  = ls_grp_ev-op_uuid ] ).
            APPEND VALUE #( ct_uuid  = ls_grp_ev-ct_uuid
                            mat_uuid = ls_grp_ev-mat_uuid
                            op_type  = ls_grp_ev-op_type
                            op_uuid  = ls_grp_ev-op_uuid ) TO rt_stale.
          ENDIF.
        ENDIF.
      ENDDO.
    ENDDO.
    " End Change ID V004 (08.09.2026 | EXT_GONZALCA)
  ENDMETHOD.
ENDCLASS.
