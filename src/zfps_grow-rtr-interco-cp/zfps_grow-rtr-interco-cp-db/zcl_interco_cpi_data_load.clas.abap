CLASS zcl_interco_cpi_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_cpi  TYPE STANDARD TABLE OF zfi_a_intrc_cpi.

    CLASS-METHODS clean_table .
    CLASS-METHODS load_data
      IMPORTING
        !it_cpi       TYPE ty_cpi
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_cpi_data_load IMPLEMENTATION.
  METHOD clean_table.
    DELETE FROM zfi_a_intrc_cpi WHERE id IS NOT INITIAL.
    COMMIT WORK.
  ENDMETHOD.

  METHOD load_data.
    DATA: lt_cpi        TYPE ty_cpi,
          lv_valid_from TYPE sy-datum,
          lv_valid_to   TYPE sy-datum,
          lv_timestamp  TYPE timestampl,
          system_uuid   TYPE REF TO if_system_uuid,
          lv_uuid       TYPE sysuuid_c32.

    lt_cpi = it_cpi.
    system_uuid = cl_uuid_factory=>create_system_uuid( ).
    lv_valid_from = sy-datum.
    lv_valid_to = '99991231'.
    GET TIME STAMP FIELD lv_timestamp.

*    select id from ZFI_A_INTRC_CPH into table @data(lt_cph)
*    up to 100 rows.
    SELECT id FROM zfi_a_intrc_cph WHERE isdeleted EQ @abap_false INTO TABLE @DATA(ls_cph)
    UP TO 100 ROWS.

    LOOP AT ls_cph ASSIGNING FIELD-SYMBOL(<ls_cph>).
      APPEND VALUE #( id = <ls_cph>-id item_id = '1' recipientcompanycode = 'DRM' profitcenter = '100' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '22925.19' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '2' recipientcompanycode = 'DRU' profitcenter = '100' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '80421.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '3' recipientcompanycode = 'EBA' profitcenter = '100' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '80421.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '4' recipientcompanycode = 'MCO' profitcenter = '100' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '80421.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '5' recipientcompanycode = 'MLA' profitcenter = '100' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '80421.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '6' recipientcompanycode = 'MLC' profitcenter = '100' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '80421.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '7' recipientcompanycode = 'MVL' profitcenter = '100' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '80421.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '8' recipientcompanycode = 'MAM' profitcenter = '200' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '74427.85' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '9' recipientcompanycode = 'MLA' profitcenter = '200' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '74427.85' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '10' recipientcompanycode = 'MPB' profitcenter = '200' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '74427.85' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '11' recipientcompanycode = 'MPC' profitcenter = '200' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '74427.85' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '12' recipientcompanycode = 'MPO' profitcenter = '200' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '74427.85' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '13' recipientcompanycode = 'MPU' profitcenter = '200' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '74427.85' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '14' recipientcompanycode = 'MCM' profitcenter = '250' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '42383.42' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '15' recipientcompanycode = 'MLA' profitcenter = '250' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '42383.42' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '16' recipientcompanycode = 'MPB' profitcenter = '250' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '42383.42' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '17' recipientcompanycode = 'MPC' profitcenter = '250' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '42383.42' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '18' recipientcompanycode = 'MPO' profitcenter = '250' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '42383.42' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '19' recipientcompanycode = 'MPU' profitcenter = '250' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '42383.42' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '20' recipientcompanycode = 'DRM' profitcenter = '260' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1027.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '21' recipientcompanycode = 'MLA' profitcenter = '260' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1027.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '22' recipientcompanycode = 'MLC' profitcenter = '260' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1027.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '23' recipientcompanycode = 'MPB' profitcenter = '260' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1027.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '24' recipientcompanycode = 'MPO' profitcenter = '260' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1027.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '25' recipientcompanycode = 'MPU' profitcenter = '260' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1027.47' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '26' recipientcompanycode = 'DRM' profitcenter = '300' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '27' recipientcompanycode = 'DRU' profitcenter = '300' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '28' recipientcompanycode = 'EBA' profitcenter = '300' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '29' recipientcompanycode = 'MCO' profitcenter = '300' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '30' recipientcompanycode = 'MLA' profitcenter = '300' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '31' recipientcompanycode = 'MLC' profitcenter = '300' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '32' recipientcompanycode = 'MVL' profitcenter = '300' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1262.95' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '33' recipientcompanycode = 'DRM' profitcenter = '400' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '12608' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '34' recipientcompanycode = 'DRU' profitcenter = '400' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '12608' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '35' recipientcompanycode = 'EBA' profitcenter = '400' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '12608' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '36' recipientcompanycode = 'MCO' profitcenter = '400' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '12608' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '37' recipientcompanycode = 'MLA' profitcenter = '400' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '12608' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '38' recipientcompanycode = 'MLC' profitcenter = '400' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '12608' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '39' recipientcompanycode = 'DRM' profitcenter = '500' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '85.63' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '40' recipientcompanycode = 'DRU' profitcenter = '500' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '85.63' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '41' recipientcompanycode = 'EBA' profitcenter = '500' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '85.63' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '42' recipientcompanycode = 'MCO' profitcenter = '500' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '85.63' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '43' recipientcompanycode = 'MLA' profitcenter = '500' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '85.63' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '44' recipientcompanycode = 'MLC' profitcenter = '500' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '85.63' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '45' recipientcompanycode = 'DRM' profitcenter = '630' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1840.88' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '46' recipientcompanycode = 'DRU' profitcenter = '630' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1840.88' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '47' recipientcompanycode = 'EBA' profitcenter = '630' interdivisional = 'X' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1840.88' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '48' recipientcompanycode = 'MCO' profitcenter = '630' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1840.88' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '49' recipientcompanycode = 'MLA' profitcenter = '630' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1840.88' ) TO lt_cpi.
      APPEND VALUE #( id = <ls_cph>-id item_id = '50' recipientcompanycode = 'MLC' profitcenter = '630' interdivisional = '' basecurrencyprofitcenter = 'USD' baseamountprofitcenter = '1840.88' ) TO lt_cpi.

    ENDLOOP.

    MODIFY zfi_a_intrc_cpi FROM TABLE @lt_cpi.
    COMMIT WORK.

    rv_len = lines( lt_cpi ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    DATA: lt_cpi      TYPE STANDARD TABLE OF zfi_a_intrc_cpi.

    "APPEND VALUE #( item_id = '1' fiscalperiod = '' fiscalyear = '2024' providercompanycode = 'MLA' recipientcompanycode = '' product = 'ICSRV11' profitcenter = '' interdivisional = 'X' ) TO lt_cpi.



    zcl_interco_cpi_data_load=>clean_table(  ).
    DATA(lv_len) = zcl_interco_cpi_data_load=>load_data( lt_cpi ).
    out->write( |Total de registros carregados na zfi_a_intrc_cpi { sy-sysid }.{ sy-mandt }: { lv_len }.| ).

  ENDMETHOD.

ENDCLASS.
