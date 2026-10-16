CLASS zcl_interco_cpig_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_cpig  TYPE STANDARD TABLE OF zfi_a_intrc_cpig.

    CLASS-METHODS clean_table .
    CLASS-METHODS load_data
      IMPORTING
        !it_cpig      TYPE ty_cpig
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_INTERCO_CPIG_DATA_LOAD IMPLEMENTATION.


  METHOD clean_table.
***    DELETE FROM zfi_a_intrc_cpig WHERE id IS NOT INITIAL.
***    COMMIT WORK.
  ENDMETHOD.


  METHOD load_data.
***    DATA: lt_cpig       TYPE ty_cpig,
***          lv_valid_from TYPE sy-datum,
***          lv_valid_to   TYPE sy-datum,
***          lv_timestamp  TYPE timestampl,
***          system_uuid   TYPE REF TO if_system_uuid,
***          lv_uuid       TYPE sysuuid_c32.
***
***    lt_cpig = it_cpig.
***    system_uuid = cl_uuid_factory=>create_system_uuid( ).
***    lv_valid_from = sy-datum.
***    lv_valid_to = '99991231'.
***    GET TIME STAMP FIELD lv_timestamp.
***
****    select id from ZFI_A_INTRC_CPH into table @data(lt_cph)
****    up to 100 rows.
***    SELECT id, item_id FROM zfi_a_intrc_cpi INTO TABLE @DATA(ls_cpi)
***    UP TO 100 ROWS.
***
***    LOOP AT ls_cpi ASSIGNING FIELD-SYMBOL(<ls_cpi>).
***      APPEND VALUE #( id = <ls_cpi>-id item_id = <ls_cpi>-item_id gl_account = '942055' cost_center = '2351124100' global_currency = 'USD' amount_in_global_currency = '222.22' ) TO lt_cpig.
***      APPEND VALUE #( id = <ls_cpi>-id item_id = <ls_cpi>-item_id gl_account = '942055' cost_center = '2351124100' global_currency = 'USD' amount_in_global_currency = '333.33' ) TO lt_cpig.
***      APPEND VALUE #( id = <ls_cpi>-id item_id = <ls_cpi>-item_id gl_account = '942055' cost_center = '2351124117' global_currency = 'USD' amount_in_global_currency = '444.44' ) TO lt_cpig.
***      APPEND VALUE #( id = <ls_cpi>-id item_id = <ls_cpi>-item_id gl_account = '942055' cost_center = '2351124117' global_currency = 'USD' amount_in_global_currency = '555.55' ) TO lt_cpig.
***
***    ENDLOOP.
***
***    MODIFY zfi_a_intrc_cpig FROM TABLE @lt_cpig.
***    COMMIT WORK.
***
***    rv_len = lines( lt_cpig ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
***    DATA: lt_cpig      TYPE STANDARD TABLE OF zfi_a_intrc_cpig.
***
***    "APPEND VALUE #( item_id = '1' fiscalperiod = '' fiscalyear = '2024' providercompanycode = 'MLA' recipientcompanycode = '' product = 'ICSRV11' profitcenter = '' interdivisional = 'X' ) TO lt_cpi.
***
***
***
***    zcl_interco_cpig_data_load=>clean_table(  ).
***    DATA(lv_len) = zcl_interco_cpig_data_load=>load_data( lt_cpig ).
***    out->write( |Total de registros carregados na zfi_a_intrc_cpig { sy-sysid }.{ sy-mandt }: { lv_len }.| ).

  ENDMETHOD.
ENDCLASS.
