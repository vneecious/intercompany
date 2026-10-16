*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Static factory (blueprint SS6.5). Resolves the concrete Strategy by
* op_type via cm_loadable/parent_type on ZREING_OP_TYPE_C — zero
* CASE op_type, zero new catalog field (F2-DD-4). get_instance carries
* io_sources/is_context (F2-AD-1) so they can be injected exclusively
* into ZCL_REING_CA_OPTYPE_CM, the only strategy that needs them.
* (cm_loadable, parent_type) is cached per op_type in CLASS-DATA so the
* dispatch SELECT runs once per op_type per run, not once per line.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_optype_factory DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    " ATC fix: tipo publico para pasar el range de op_types a warm_cache.
    TYPES ty_op_type_rang TYPE RANGE OF zreing_op_type_c-op_type.

    CLASS-METHODS get_instance
      IMPORTING iv_op_type       TYPE zreing_op_type_c-op_type
                io_sources       TYPE REF TO zif_reing_ca_sources
                is_context       TYPE zif_reing_ca_types=>ty_context
      RETURNING VALUE(ro_optype) TYPE REF TO zif_reing_ca_optype
      RAISING   zcx_reing_ca_calc_error.

    " ATC fix (NonLocal DBREAD via get_instance en loop): pre-carga gt_cache en bulk
    " para todos los op_types del scope ANTES del LOOP AT keys. Evita que get_instance
    " ejecute SELECT SINGLE zreing_op_type_c dentro del DO TIMES anidado.
    CLASS-METHODS warm_cache
      IMPORTING it_op_types TYPE ty_op_type_rang
      RAISING   zcx_reing_ca_calc_error.

    " ATC fix (NonLocal DBREAD): retorna instancia de strategy usando SOLO gt_cache
    " (ya pre-cargado por warm_cache) -- CERO SELECT. Sustituye get_instance en el
    " DO TIMES anidado para eliminar el call path LOOP->get_instance->SELECT.
    CLASS-METHODS get_instance_from_cache
      IMPORTING iv_op_type       TYPE zreing_op_type_c-op_type
                io_sources       TYPE REF TO zif_reing_ca_sources
                is_context       TYPE zif_reing_ca_types=>ty_context
      RETURNING VALUE(ro_optype) TYPE REF TO zif_reing_ca_optype
      RAISING   zcx_reing_ca_calc_error.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_cache_entry,
             op_type     TYPE zreing_op_type_c-op_type,
             cm_loadable TYPE zreing_op_type_c-cm_loadable,
             parent_type TYPE zreing_op_type_c-parent_type,
           END OF ty_cache_entry.

    CLASS-DATA gt_cache TYPE HASHED TABLE OF ty_cache_entry WITH UNIQUE KEY op_type.

    " Dispatch compartido -- construye ro_optype desde una entrada de cache.
    CLASS-METHODS dispatch_from_entry
      IMPORTING is_entry         TYPE ty_cache_entry
                io_sources       TYPE REF TO zif_reing_ca_sources
                is_context       TYPE zif_reing_ca_types=>ty_context
      RETURNING VALUE(ro_optype) TYPE REF TO zif_reing_ca_optype
      RAISING   zcx_reing_ca_calc_error.

ENDCLASS.

CLASS zcl_reing_ca_optype_factory IMPLEMENTATION.

  METHOD get_instance.

    ASSIGN gt_cache[ op_type = iv_op_type ] TO FIELD-SYMBOL(<ls_cache>).
    IF sy-subrc <> 0.
      SELECT SINGLE cm_loadable, parent_type
        FROM zreing_op_type_c
        WHERE op_type = @iv_op_type
          AND active  = @abap_true
        INTO @DATA(ls_new).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
          EXPORTING iv_message = |OP_TYPE { iv_op_type } inexistente o inactivo en ZREING_OP_TYPE_C|.
      ENDIF.

      INSERT VALUE ty_cache_entry( op_type     = iv_op_type
                                    cm_loadable = ls_new-cm_loadable
                                    parent_type = ls_new-parent_type ) INTO TABLE gt_cache.
      ASSIGN gt_cache[ op_type = iv_op_type ] TO <ls_cache>.
    ENDIF.

    ro_optype = dispatch_from_entry(
      is_entry   = <ls_cache>
      io_sources = io_sources
      is_context = is_context ).
  ENDMETHOD.

  METHOD get_instance_from_cache.
    " ATC fix (NonLocal DBREAD): accede SOLO a gt_cache -- CERO SELECT.
    " Requiere warm_cache( ) previo. Si la entrada no existe en cache,
    " lanza excepcion (misma semántica que get_instance con cache miss).
    ASSIGN gt_cache[ op_type = iv_op_type ] TO FIELD-SYMBOL(<ls_cache>).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |OP_TYPE { iv_op_type } no encontrado en cache -- llame warm_cache antes del loop|.
    ENDIF.

    ro_optype = dispatch_from_entry(
      is_entry   = <ls_cache>
      io_sources = io_sources
      is_context = is_context ).
  ENDMETHOD.

  METHOD warm_cache.
    " ATC fix (NonLocal DBREAD via get_instance en loop): pre-carga gt_cache en bulk.
    " Un SELECT antes del LOOP AT keys evita N SELECT SINGLE dentro del DO TIMES.
    " get_instance_from_cache lee de gt_cache sin ningún SELECT.
    CHECK it_op_types IS NOT INITIAL.

    DATA lt_rows TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    SELECT op_type, cm_loadable, parent_type
      FROM zreing_op_type_c
      WHERE op_type IN @it_op_types
        AND active  = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @lt_rows.

    LOOP AT lt_rows INTO DATA(ls_row).
      INSERT VALUE ty_cache_entry(
        op_type     = ls_row-op_type
        cm_loadable = ls_row-cm_loadable
        parent_type = ls_row-parent_type ) INTO TABLE gt_cache.
    ENDLOOP.
  ENDMETHOD.

  METHOD dispatch_from_entry.
    " Static 3-way dispatch by cm_loadable/parent_type — zero CASE op_type,
    " zero new field on a catalog owned by another team (F2-DD-4).
    IF is_entry-cm_loadable = abap_true.
      ro_optype = NEW zcl_reing_ca_optype_cm( io_sources = io_sources
                                               is_context = is_context ).
    ELSEIF is_entry-parent_type = zif_reing_ca_c=>optype_root-defer_parent.
      ro_optype = NEW zcl_reing_ca_optype_defer( ).
    ELSEIF is_entry-parent_type = zif_reing_ca_c=>optype_root-ant2_parent.
      ro_optype = NEW zcl_reing_ca_optype_an2( ).
    ELSE.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message =
          |OP_TYPE { is_entry-op_type } no matchea ninguna ruta de dispatch (customizing inconsistente)|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
