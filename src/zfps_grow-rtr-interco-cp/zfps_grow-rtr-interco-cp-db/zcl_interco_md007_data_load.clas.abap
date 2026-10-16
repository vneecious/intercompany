CLASS zcl_interco_md007_data_load DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .

    TYPES:
      ty_MD007  TYPE STANDARD TABLE OF zint_a_md007 .

    CLASS-METHODS clean_table.
    CLASS-METHODS load_data
      IMPORTING
        !it_MD007     TYPE ty_MD007
      RETURNING
        VALUE(rv_len) TYPE int4 .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_md007_data_load IMPLEMENTATION.


  METHOD clean_table.
    DELETE FROM zint_a_md007 WHERE bukrs IS NOT INITIAL.
    COMMIT WORK.
  ENDMETHOD.


  METHOD load_data.
    DATA: lt_MD007        TYPE ty_MD007.

    lt_MD007 = it_MD007.

    SELECT DISTINCT valuationarea, companycode
    FROM i_productvaluationbasic
    WHERE product IS NOT INITIAL
    INTO TABLE @DATA(LT_Valuation).

    LOOP AT lt_valuation INTO DATA(ls_valuation).
      APPEND INITIAL LINE TO lt_MD007 ASSIGNING FIELD-SYMBOL(<FS_MD007>).
      <FS_MD007>-bukrs      = ls_valuation-CompanyCode.
      <FS_MD007>-valid_from = '20240101'.
      <FS_MD007>-valid_to   = '99991231'.
      <FS_MD007>-vkorg      = 'TEST'.
      <FS_MD007>-ekorg      = 'TEST'.
      <FS_MD007>-werks      = ls_valuation-ValuationArea.
      <FS_MD007>-created_at = utclong_current( ).
      <FS_MD007>-created_by = cl_abap_context_info=>get_user_technical_name( ).
    ENDLOOP.



*    LOOP AT lt_cph ASSIGNING FIELD-SYMBOL(<ls_cph>).
*      lv_uuid = system_uuid->create_uuid_c32( ).
*
*      <ls_cph>-id = lv_uuid.
*      <ls_cph>-intercobasisid = system_uuid->create_uuid_c32( ).
*      <ls_cph>-isdeleted = abap_false.
*      <ls_cph>-createdat = lv_timestamp.
*      <ls_cph>-createdby = sy-uname.
*    ENDLOOP.

    MODIFY zint_a_md007 FROM TABLE @lt_MD007.
    COMMIT WORK.

    rv_len = lines( lt_MD007 ).
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    DATA: lt_cph      TYPE STANDARD TABLE OF zint_a_md007.

*    CASE sy-sysid.
*      WHEN 'DS4'.
*        APPEND VALUE #( bukrs = 'FLA' valid_from = '20240101' valid_to = '99991231' vkorg = 'TEST' ekorg = 'TEST' werks = 'USD' created_at = utclong_current( ) created_by = cl_abap_context_info=>get_user_technical_name( ) ) TO lt_cph.
*      WHEN 'TS4'.
*        "UAT Test Gabriel
*    ENDCASE.
    zcl_interco_md007_data_load=>clean_table(  ).
    DATA(lv_len) = zcl_interco_md007_data_load=>load_data( lt_cph ).
    out->write( |Total de registros carregados na zint_a_md007 { sy-sysid }.{ sy-mandt }: { lv_len }.| ).

  ENDMETHOD.
ENDCLASS.
