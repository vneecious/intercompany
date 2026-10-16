CLASS lhc_header DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR header RESULT result.

ENDCLASS.

CLASS lhc_header IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zr_intercojeitemclassbgtp DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.

CLASS lsc_zr_intercojeitemclassbgtp IMPLEMENTATION.

  METHOD save_modified.
    LOOP AT create-header REFERENCE INTO DATA(header).

      DATA(bg_operation) = NEW zcl_interco_jeitem_bg( id = header->id ).
      TRY.
          DATA(bg_process) = cl_bgmc_process_factory=>get_default( )->create( ).
          bg_process->set_name( 'Interco Basis Background Execution'
                    )->set_operation_tx_uncontrolled( bg_operation
                    )->save_for_execution( ).
        CATCH cx_bgmc.
      ENDTRY.

    ENDLOOP.

    LOOP AT update-header REFERENCE INTO DATA(upd_header).

      IF upd_header->pending = abap_true.
        bg_operation = NEW zcl_interco_jeitem_bg( id = upd_header->id ).
        TRY.
            bg_process = cl_bgmc_process_factory=>get_default( )->create( ).
            bg_process->set_name( 'Interco Basis Background Execution'
                      )->set_operation_tx_uncontrolled( bg_operation
                      )->save_for_execution( ).
          CATCH cx_bgmc.
        ENDTRY.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD cleanup_finalize.
  ENDMETHOD.

ENDCLASS.
