CLASS zcl_behavior_message DEFINITION
  PUBLIC
  INHERITING FROM cl_abap_behv
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.
    CLASS-METHODS:
      class_constructor.

    CLASS-METHODS _new_message
      IMPORTING
        !id        TYPE symsgid
        !number    TYPE symsgno
        !severity  TYPE if_abap_behv_message=>t_severity
        !v1        TYPE simple OPTIONAL
        !v2        TYPE simple OPTIONAL
        !v3        TYPE simple OPTIONAL
        !v4        TYPE simple OPTIONAL
      RETURNING
        VALUE(obj) TYPE REF TO if_abap_behv_message .
    CLASS-METHODS _new_message_with_text
      IMPORTING
        !severity  TYPE if_abap_behv_message=>t_severity DEFAULT if_abap_behv_message=>severity-error
        !text      TYPE csequence OPTIONAL
      RETURNING
        VALUE(obj) TYPE REF TO if_abap_behv_message .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA: instance TYPE REF TO zcl_behavior_message.
ENDCLASS.


CLASS zcl_behavior_message IMPLEMENTATION.
  METHOD class_constructor.
    instance = NEW #( ).
  ENDMETHOD.

  METHOD _new_message.
    obj = instance->new_message(
      EXPORTING
        id       = id
        number   = number
        severity = severity
        v1       = v1
        v2       = v2
        v3       = v3
        v4       = v4
    ).
  ENDMETHOD.

  METHOD _new_message_with_text.
    obj = instance->new_message_with_text(
        severity = severity
        text     = text ).
  ENDMETHOD.

ENDCLASS.
