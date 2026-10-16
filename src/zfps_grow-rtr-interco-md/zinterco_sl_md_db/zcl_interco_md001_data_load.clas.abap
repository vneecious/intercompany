CLASS zcl_interco_md001_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_md001  TYPE STANDARD TABLE OF zint_a_md001 .

    CLASS-METHODS clean_table .
    CLASS-METHODS load_data
      IMPORTING
        !it_md001     TYPE ty_md001
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INTERCO_MD001_DATA_LOAD IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA: lt_md001      TYPE STANDARD TABLE OF zint_a_md001.

    zcl_interco_md001_data_load=>clean_table(  ).
    DATA(lv_len) = zcl_interco_md001_data_load=>load_data( lt_md001  ).
    out->write( |Total de registros carregados na ZINT_A_MD001: { lv_len }.| ).

  ENDMETHOD.


  METHOD clean_table.
    DELETE FROM zint_a_md001 WHERE id IS NOT NULL.
    COMMIT WORK.
  ENDMETHOD.


  METHOD load_data.
    DATA: lt_md001 TYPE TY_MD001,
          lv_valid_from TYPE sy-datum,
          lv_valid_to   TYPE sy-datum,
          lv_timestamp  TYPE timestampl,
          system_uuid   TYPE REF TO if_system_uuid,
          lv_uuid       TYPE sysuuid_c32.

    lt_md001 = IT_MD001.
    system_uuid = cl_uuid_factory=>create_system_uuid( ).
    lv_valid_from = sy-datum.
    lv_valid_to = '99991231'.
    GET TIME STAMP FIELD lv_timestamp.


    LOOP AT lt_md001 ASSIGNING FIELD-SYMBOL(<ls_md001>).
      lv_uuid = system_uuid->create_uuid_c32( ).

      <ls_md001>-id = lv_uuid.
      <ls_md001>-validfrom = lv_valid_from.
      <ls_md001>-validto = lv_valid_to.
      <ls_md001>-isblocked = abap_false.
      <ls_md001>-isdeleted = abap_false.
      <ls_md001>-createdat = lv_timestamp.
      <ls_md001>-createdby = sy-uname.
    ENDLOOP.

    MODIFY zint_a_md001 FROM TABLE @lt_md001.
    COMMIT WORK.

    rv_len = lines( lt_md001 ).

  ENDMETHOD.
ENDCLASS.
