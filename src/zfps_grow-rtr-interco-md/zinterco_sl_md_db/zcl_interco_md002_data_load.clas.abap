class ZCL_INTERCO_MD002_DATA_LOAD definition
  public
  final
  create public .

public section.

  interfaces IF_OO_ADT_CLASSRUN .

  types:
    ty_md002  TYPE STANDARD TABLE OF zint_a_md002 .

  class-methods CLEAN_TABLE .
  class-methods LOAD_DATA
    importing
      !IT_MD002 type TY_MD002
    returning
      value(RV_LEN) type INT4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INTERCO_MD002_DATA_LOAD IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    DATA: lt_md002      TYPE STANDARD TABLE OF zint_a_md002.

    ZCL_INTERCO_MD002_DATA_LOAD=>clean_table(  ).
    DATA(lv_len) = ZCL_INTERCO_MD002_DATA_LOAD=>load_data( lt_md002 ).
    out->write( |Total de registros cargados en la tabla ZINT_A_MD002: { lv_len }.| ).

  ENDMETHOD.


  METHOD clean_table.
    DELETE FROM zint_a_md002 WHERE id IS NOT NULL.
    COMMIT WORK.
  ENDMETHOD.


  METHOD load_data.
    DATA: lt_md002      TYPE ty_md002,
          lv_valid_from TYPE sy-datum,
          lv_valid_to   TYPE sy-datum,
          lv_timestamp  TYPE timestampl,
          system_uuid   TYPE REF TO if_system_uuid,
          lv_uuid       TYPE sysuuid_c32.

    lt_md002 = it_md002.
    system_uuid = cl_uuid_factory=>create_system_uuid( ).
    lv_valid_from = sy-datum.
    lv_valid_to = '99991231'.
    GET TIME STAMP FIELD lv_timestamp.

    LOOP AT lt_md002 ASSIGNING FIELD-SYMBOL(<ls_md002>).
      lv_uuid = system_uuid->create_uuid_c32( ).

      <ls_md002>-id = lv_uuid.
      <ls_md002>-validfrom = lv_valid_from.
      <ls_md002>-validto = lv_valid_to.
      <ls_md002>-isdeleted = abap_false.
      <ls_md002>-createdat = lv_timestamp.
      <ls_md002>-createdby = sy-uname.
    ENDLOOP.

    MODIFY zint_a_md002 FROM TABLE @lt_md002.
    COMMIT WORK.

    rv_len = lines( lt_md002 ).

  ENDMETHOD.
ENDCLASS.
