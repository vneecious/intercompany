*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations
*CLASS lcl_proposal_bo_recl_gasto_par DEFINITION
*  INHERITING FROM zcl_proposal_bo_recl_gasto.
*
*  PUBLIC SECTION.
*    INTERFACES if_abap_parallel.
*
*    METHODS constructor
*      IMPORTING
*        io_instance TYPE REF TO zcl_proposal_bo_recl_gasto.
*
*  PROTECTED SECTION.
*
*  PRIVATE SECTION.
*
*ENDCLASS.
*
*CLASS lcl_proposal_bo_recl_gasto_par IMPLEMENTATION.
*  METHOD constructor.
*    super->constructor(
*      is_header      = io_instance->gs_header
*      it_items       = io_instance->gtd_items_add
*      it_bases       = io_instance->gtd_bases
*      it_calc        = io_instance->gtd_calc
*      it_doc         = io_instance->gtd_doc
*      it_glaccount   = io_instance->gtd_glaccount
*      iv_process     = io_instance->gv_process
*      iv_documentkey = io_instance->gv_documentkey
*      it_doc_map     = io_instance->gt_doc_map
*    ).
*
*    me->gta_je_deep = io_instance->gta_je_deep.
*    me->gta_jr_rev = io_instance->gta_jr_rev.
*  ENDMETHOD.
*
*  METHOD if_abap_parallel~do.
*    exe_bo_sec( EXPORTING it_map_id_doc = gt_doc_map ).
*
**    save_log( ).
*  ENDMETHOD.
*ENDCLASS.
