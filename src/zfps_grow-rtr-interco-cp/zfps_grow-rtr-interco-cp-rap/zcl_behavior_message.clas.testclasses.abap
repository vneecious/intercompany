*"* use this source file for your ABAP unit test classes
CLASS ltcl_messages DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS:
      on_new_message FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_messages IMPLEMENTATION.

  METHOD on_new_message.
    DATA(obj) = zcl_behavior_message=>_new_message(
      EXPORTING
        id       = 'ID'
        number   = '999'
        severity = if_abap_behv_message=>severity-error
    ).
    IF obj IS NOT BOUND.
      cl_abap_unit_assert=>fail( 'omg' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
