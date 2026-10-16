CLASS zcl_interco DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    CLASS-DATA:
      authority TYPE REF TO zcl_interco_authority READ-ONLY,
      log       TYPE REF TO zcl_interco_log READ-ONLY,
      feature   TYPE REF TO zcl_interco_feature READ-ONLY.

    CLASS-METHODS:
      class_constructor.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco IMPLEMENTATION.

  METHOD class_constructor.
    authority = NEW #( ).
    log = NEW #( ).
    feature = NEW #( ).
  ENDMETHOD.
ENDCLASS.
