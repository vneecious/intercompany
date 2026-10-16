CLASS zcl_interco_cpic_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_cpic  TYPE STANDARD TABLE OF zfi_a_intrc_cpic .

    CLASS-METHODS clean_table .
    CLASS-METHODS load_data
      IMPORTING
        !it_cpic      TYPE ty_cpic
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_cpic_data_load IMPLEMENTATION.
  METHOD clean_table.
    DELETE FROM zfi_a_intrc_cpic WHERE id IS NOT INITIAL.
    COMMIT WORK.
  ENDMETHOD.

  METHOD load_data.
    DATA: lt_cpic       TYPE ty_cpic,
          lv_valid_from TYPE sy-datum,
          lv_valid_to   TYPE sy-datum,
          lv_timestamp  TYPE timestampl,
          system_uuid   TYPE REF TO if_system_uuid,
          lv_uuid       TYPE sysuuid_c32,
          ls_cpic       TYPE zfi_a_intrc_cpic,
          lc_status     TYPE c,
          li_status     TYPE i.

    lt_cpic = it_cpic.
*    system_uuid = cl_uuid_factory=>create_system_uuid( ).
    lv_valid_from = cl_abap_context_info=>get_system_date( ).
    lv_timestamp = cl_abap_context_info=>get_system_time( ).
    GET TIME STAMP FIELD lv_timestamp.

    SELECT id, item_id, itembasis_id FROM zfi_a_intrc_cpib
    WHERE id IS NOT INITIAL
    INTO TABLE @DATA(lt_cpib). "UP TO 100 ROWS.
*    SELECT SINGLE id, item_id FROM zfi_a_intrc_cpi INTO @DATA(ls_cph).

    LOOP AT lt_cpib ASSIGNING FIELD-SYMBOL(<ls_cpib>).
      MOVE-CORRESPONDING <ls_cpib> TO ls_cpic.
      ls_cpic-itemcalc_id = 1.
*      li_status = li_status + 1.
*      CASE li_status.
*       WHEN 1.
      lc_status = space.
*       when 2.
*       lc_status = 'S'.
*       when 3.
*       lc_status = 'E'.
*      endcASE.
*      if li_status EQ 3.
*        li_status = 0.
*      endif.
      ls_cpic-commitstatus = lc_status.
      ls_cpic-markup = '1.23'.
      ls_cpic-grossingupbase = '3.45'.
      ls_cpic-grossingupmargin = '3.668'.
      ls_cpic-latepaymentinterest = '34.657'.
      ls_cpic-providergrossingup = '33.78856'.
      ls_cpic-markupamount = '12.345'.
      ls_cpic-grossingupbaseamount = '23.456'.
      ls_cpic-grossingupmarginamount = '34.567'.
      ls_cpic-latepaymentinterestamount = '45.678'.
      ls_cpic-providergrossingupamount = '56.789'.
      ls_cpic-createdby = cl_abap_context_info=>get_user_technical_name( ).
      GET TIME STAMP FIELD ls_cpic-createdat." = lv_timestamp.
      APPEND ls_cpic TO lt_cpic.

    ENDLOOP.

    MODIFY zfi_a_intrc_cpic FROM TABLE @lt_cpic.
    COMMIT WORK.

    rv_len = lines( lt_cpic ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_cpic      TYPE STANDARD TABLE OF zfi_a_intrc_cpic.

*    APPEND VALUE #( itemcalc_id = 1 commitstatus = 'S' markup = 1 grossingupbase = 1 grossingupmargin = 1 ) TO lt_cpic.

    zcl_interco_cpic_data_load=>clean_table(  ).
    DATA(lv_len) = zcl_interco_cpic_data_load=>load_data( lt_cpic ).
    out->write( |Total de registros carregados na zfi_a_intrc_cpic { sy-sysid }.{ sy-mandt }: { lv_len }.| ).

  ENDMETHOD.

ENDCLASS.
