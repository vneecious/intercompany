CLASS zcl_interco_master_upload DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      BEGIN OF gty_tab,
        validfrom            TYPE string,
        validto              TYPE string,
        product              TYPE string,
        providercompanycode  TYPE string,
        pandlid              TYPE string,
        profitcenter         TYPE string,
        costcentersubarea    TYPE string,
        costcenterallocation TYPE string,
        isnotbilable         TYPE string,
        isdeleted            TYPE string,
        zindex               TYPE string,
      END OF gty_tab,
      gtt_tab TYPE TABLE OF gty_tab WITH EMPTY KEY.

    TYPES:
      BEGIN OF gty_tab_product,
        material         TYPE string,
        providerCompany  TYPE string,
        recipientCompany TYPE string,
        profitCenter     TYPE string,
        validFrom        TYPE string,
        validTo          TYPE string,
        rate             TYPE string,
        flow             TYPE string,
        isPromo          TYPE string,
        zindex           TYPE string,
      END OF gty_tab_product,
      gtt_tab_product TYPE TABLE OF gty_tab_product WITH EMPTY KEY.

    DATA GT_relprodbill    TYPE gtt_tab.
    DATA gt_reported       TYPE RESPONSE FOR REPORTED EARLY zi_intercocompanyrelprodbill.
    DATA gt_failed         TYPE RESPONSE FOR FAILED EARLY zi_intercocompanyrelprodbill.
    DATA gt_mapped         TYPE RESPONSE FOR MAPPED EARLY zi_intercocompanyrelprodbill.

    METHODS upload_relprodbill
      IMPORTING is_params        TYPE zinterco_str_params_relation
      RETURNING VALUE(et_result) TYPE gtt_tab.

    METHODS upload_companyProduct
      IMPORTING is_params        TYPE zinterco_str_params_relation
      RETURNING VALUE(et_result) TYPE gtt_tab_product.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_interco_master_upload IMPLEMENTATION.
  METHOD upload_relprodbill.
    DATA lt_result TYPE gtt_tab.

    DATA(lv_json_string) = is_params-data.
    xco_cp_json=>data->from_string( lv_json_string )->apply( VALUE #(
*      ( xco_cp_json=>transformation->camel_case_to_underscore )
                                                                 ( xco_cp_json=>transformation->boolean_to_abap_bool ) )
    )->write_to( REF #( lt_result ) ).

    DELETE lt_result WHERE     validfrom            IS INITIAL
                           AND validto              IS INITIAL
                           AND product              IS INITIAL
                           AND providercompanycode  IS INITIAL
                           AND pandlid              IS INITIAL
                           AND profitcenter         IS INITIAL
                           AND costcentersubarea    IS INITIAL
                           AND costcenterallocation IS INITIAL
                           AND isnotbilable         IS INITIAL
                           AND isdeleted            IS INITIAL.

    et_result[] = lt_result[].
  ENDMETHOD.

  METHOD upload_companyproduct.
    DATA: lt_result TYPE gtt_tab_product,
          lv_date   TYPE datum.

    DATA(lv_json_string) = is_params-data.
    xco_cp_json=>data->from_string( lv_json_string )->apply( VALUE #(
*      ( xco_cp_json=>transformation->camel_case_to_underscore )
                                                                 ( xco_cp_json=>transformation->boolean_to_abap_bool ) )
    )->write_to( REF #( lt_result ) ).

    DELETE lt_result WHERE     material         IS INITIAL
                           AND providerCompany  IS INITIAL
                           AND recipientCompany IS INITIAL
                           AND profitCenter     IS INITIAL
                           AND validFrom        IS INITIAL
                           AND validTo          IS INITIAL
                           AND rate             IS INITIAL
                           AND flow             IS INITIAL.
*                           AND isPromo          IS INITIAL.
    DATA(lv_flag) = abap_false.
    DATA lv_rate_original TYPE string.
    DATA lv_has_dot       TYPE abap_bool.
    DATA lv_has_comma     TYPE abap_bool.
    DATA lv_last_comma    TYPE i.
    DATA lv_last_dot      TYPE i.
    DATA lv_rate_check    TYPE p LENGTH 5 DECIMALS 6.
    LOOP AT lt_result ASSIGNING FIELD-SYMBOL(<fs_result>).
*      "Se comenta para el ticket FPSRUNFI-5784
*      "REPLACE ALL OCCURRENCES OF ',' IN <fs_result>-rate WITH '.'.
*      IF <fs_result>-rate IS NOT INITIAL.
*        DATA(lv_rate_original) = <fs_result>-rate.
*
*        IF lv_rate_original CS '.' AND NOT ( lv_rate_original CS ',' ).
*          REPLACE ALL OCCURRENCES OF '.' IN <fs_result>-rate WITH ','.
*
*        ELSEIF lv_rate_original CS ',' AND NOT ( lv_rate_original CS '.' ).
*
*        ELSEIF lv_rate_original CS '.' AND lv_rate_original CS ','.
*          DATA(lv_last_comma) = strlen( lv_rate_original ) - find( val = reverse( lv_rate_original ) sub = ',' ) - 1.
*          DATA(lv_last_dot) = strlen( lv_rate_original ) - find( val = reverse( lv_rate_original ) sub = '.' ) - 1.
*
*          IF lv_last_comma > lv_last_dot.
*            REPLACE ALL OCCURRENCES OF '.' IN <fs_result>-rate WITH ''.
*          ELSE.
*            REPLACE ALL OCCURRENCES OF ',' IN <fs_result>-rate WITH ''.
*            REPLACE ALL OCCURRENCES OF '.' IN <fs_result>-rate WITH ','.
*          ENDIF.
*        ENDIF.
*      ENDIF.

*Ini EXT_OSCUGALD - Ajuste separador decimal para carga de archivo
      "Normalización del rate: el formato final debe usar PUNTO como separador decimal
      "para ser compatible con DEC(9,6) ZINT_DTE_RATE (corrige FPSRUNFI-5784).
      "
      "Entradas posibles desde Fiori (depende del locale del navegador):
      "  Anglosajón:  "1,234.567890"  o  "0.123456"  (punto = decimal, coma = miles)
      "  Europeo:     "1.234,567890"  o  "0,123456"  (coma = decimal, punto = miles)
      "  Sin formato: "1234.567890"   o  "1234,567890"
      "
      "Salida esperada: siempre con PUNTO decimal, sin separador de miles.
      "  Ejemplo: "0.123456", "1234.567890"
      IF <fs_result>-rate IS NOT INITIAL.
        lv_rate_original = <fs_result>-rate.
        lv_has_dot   = boolc( lv_rate_original CS '.' ).
        lv_has_comma = boolc( lv_rate_original CS ',' ).

        IF lv_has_dot = abap_true AND lv_has_comma = abap_false.
          "Solo punto presente.
          "Si hay un solo punto → es separador decimal → dejarlo.
          "Si hay múltiples puntos → son separadores de miles → quitarlos.
          IF count( val = lv_rate_original sub = '.' ) > 1.
            REPLACE ALL OCCURRENCES OF '.' IN <fs_result>-rate WITH ''.
          ENDIF.
          "Un solo punto: ya es formato correcto (ej. "0.123456", "123.45")

        ELSEIF lv_has_comma = abap_true AND lv_has_dot = abap_false.
          "Solo coma presente.
          "Si hay una sola coma → es separador decimal → reemplazar por punto.
          "Si hay múltiples comas → son separadores de miles → quitarlas.
          IF count( val = lv_rate_original sub = ',' ) = 1.
            REPLACE ALL OCCURRENCES OF ',' IN <fs_result>-rate WITH '.'.
          ELSE.
            REPLACE ALL OCCURRENCES OF ',' IN <fs_result>-rate WITH ''.
          ENDIF.

        ELSEIF lv_has_dot = abap_true AND lv_has_comma = abap_true.
          "Ambos presentes: el separador decimal es el que aparece ÚLTIMO.
          lv_last_comma = find( val = reverse( lv_rate_original ) sub = ',' ).
          lv_last_dot   = find( val = reverse( lv_rate_original ) sub = '.' ).
          "Nota: find en el string invertido → un valor MENOR = más a la derecha en el original.

          IF lv_last_comma < lv_last_dot.
            "Coma está más a la derecha → formato europeo (ej. "1.234,567890")
            REPLACE ALL OCCURRENCES OF '.' IN <fs_result>-rate WITH ''.
            REPLACE ALL OCCURRENCES OF ',' IN <fs_result>-rate WITH '.'.
          ELSE.
            "Punto está más a la derecha → formato anglosajón (ej. "1,234.567890")
            REPLACE ALL OCCURRENCES OF ',' IN <fs_result>-rate WITH ''.
          ENDIF.
        ENDIF.
        "Validar rango DEC(9,6): máx 999.999999. Previene dump CONVT_OVERFLOW.
        TRY.
            lv_rate_check = <fs_result>-rate.
          CATCH cx_sy_conversion_overflow.
            CLEAR <fs_result>-rate.
            lv_flag = abap_true.
        ENDTRY.
      ENDIF.
*Fin EXT_OSCUGALD - Ajuste separador decimal para carga de archivo

      TRY.
          lv_date = EXACT d( <fs_result>-validFrom ).
        CATCH cx_sy_conversion_no_date.
          CLEAR lv_date.
          <fs_result>-validfrom = lv_date.
          lv_flag = abap_true.
      ENDTRY.

      TRY.
          lv_date = EXACT d( <fs_result>-validto ).
        CATCH cx_sy_conversion_no_date.
          CLEAR lv_date.
          <fs_result>-validto = lv_date.
          lv_flag = abap_true.
      ENDTRY.
    ENDLOOP.
    IF lv_flag = abap_false.
      et_result[] = lt_result[].
    ENDIF.
  ENDMETHOD.

ENDCLASS.
