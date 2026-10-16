CLASS zcl_interco_feature DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_interco.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_feature,
        companycode TYPE zi_intercofeaturetoggle-companycode,
        feature     TYPE zi_intercofeaturetoggle-feature,
        "Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: nuevos campos opcionales Product/PandLId en el buffer de features =====
        product     TYPE zi_intercofeaturetoggle-product,
        pandlid     TYPE zi_intercofeaturetoggle-pandlid,
        "Fin - EXT_OSCUGALD - 02.09.2026 =====
        enabled     TYPE zi_intercofeaturetoggle-enabled,
        validfrom   TYPE zi_intercofeaturetoggle-validfrom,
      END OF ty_feature.

    METHODS get
      IMPORTING i_feature_name TYPE zi_intercofeaturetoggle-feature
      RETURNING VALUE(result)  TYPE REF TO zcl_interco_feature.

    METHODS for
      IMPORTING
                iv_companycode TYPE zi_intercofeaturetoggle-companycode
                "Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: iv_product/iv_pandlid opcionales, "mas especifico gana" =====
                iv_product     TYPE zi_intercofeaturetoggle-product OPTIONAL
                iv_pandlid     TYPE zi_intercofeaturetoggle-pandlid OPTIONAL
                "Fin - EXT_OSCUGALD - 02.09.2026 =====
                iv_validat     TYPE sy-datum DEFAULT sy-datum
      RETURNING VALUE(result)  TYPE ty_feature.


  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA mt_features TYPE TABLE OF ty_feature.
    "Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: helper privado para resolver una combinacion puntual =====
    METHODS find_best_match
      IMPORTING iv_companycode TYPE zi_intercofeaturetoggle-companycode
                iv_product     TYPE zi_intercofeaturetoggle-product
                iv_pandlid     TYPE zi_intercofeaturetoggle-pandlid
                iv_validat     TYPE sy-datum
      RETURNING VALUE(result)  TYPE ty_feature.
    "Fin - EXT_OSCUGALD - 02.09.2026 =====
ENDCLASS.



CLASS zcl_interco_feature IMPLEMENTATION.

  METHOD get.
    SELECT companycode, feature,
    product, pandlid,  "EXT_OSCUGALD - 02.09.2026
    enabled, validfrom FROM zi_intercofeaturetoggle
    WHERE feature = @i_feature_name
      INTO TABLE @mt_features.

    RETURN me.
  ENDMETHOD.

  METHOD for.

*    DATA range_companycode TYPE RANGE OF zi_intercofeaturetoggle-companycode.
*    range_companycode = VALUE #( sign = 'I' option = 'EQ' ( low = ' ' ) ( low = iv_companycode ) ).
*
*    SELECT SINGLE companycode, feature, enabled, validfrom FROM @mt_features AS features
*      WHERE companycode IN @range_companycode
*      AND validfrom <= @iv_validat
*      INTO @result.

    "Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: cascada de especificidad Product+PandLId ("mas especifico gana", ET v2.1 par.3.2).
    " No se ordena por un campo de "especificidad" calculado (mas dificil de leer/testear); se prueba en
    " cascada de mayor a menor especificidad y se corta en el primer match. Si no vienen iv_product/iv_pandlid,
    " el comportamiento es identico al de hoy (compatibilidad hacia atras garantizada).
    DATA(lv_product_filled) = xsdbool( iv_product IS SUPPLIED AND iv_product IS NOT INITIAL ).
    DATA(lv_pandlid_filled) = xsdbool( iv_pandlid IS SUPPLIED AND iv_pandlid IS NOT INITIAL ).

    " 1) CompanyCode + Product + PandLId (la mas especifica)
    IF lv_product_filled = abap_true AND lv_pandlid_filled = abap_true.
      result = find_best_match( iv_companycode = iv_companycode
                                 iv_product     = iv_product
                                 iv_pandlid     = iv_pandlid
                                 iv_validat     = iv_validat ).
      IF result IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.
    " 2) CompanyCode + Product
    IF lv_product_filled = abap_true.
      result = find_best_match( iv_companycode = iv_companycode
                                 iv_product     = iv_product
                                 iv_pandlid     = ''
                                 iv_validat     = iv_validat ).
      IF result IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    " 3) CompanyCode + PandLId
    IF lv_pandlid_filled = abap_true.
      result = find_best_match( iv_companycode = iv_companycode
                                 iv_product     = ''
                                 iv_pandlid     = iv_pandlid
                                 iv_validat     = iv_validat ).
      IF result IS NOT INITIAL.
        RETURN.
      ENDIF.
    ENDIF.

    " 4) Solo CompanyCode / generico -> comportamiento identico al que existe hoy
    result = find_best_match( iv_companycode = iv_companycode
                               iv_product     = ''
                               iv_pandlid     = ''
                               iv_validat     = iv_validat ).
    "Fin - EXT_OSCUGALD - 02.09.2026 =====
  ENDMETHOD.

  METHOD find_best_match.
    "Ini - EXT_OSCUGALD - 02.09.2026 - HU-01: implementacion del helper find_best_match.
    " De regalo corrige una ambiguedad que ya existia hoy: el FOR() actual hace SELECT SINGLE con
    " companycode IN ('', iv_companycode) SIN order by, por lo que si existen ambas filas (generica y
    " especifica) para la misma feature, el resultado no era deterministico. Esta version SIEMPRE
    " prioriza la fila de CompanyCode especifico sobre la generica.
    DATA lt_matches TYPE TABLE OF ty_feature.

    LOOP AT mt_features INTO DATA(ls_feature)
      WHERE product     = iv_product
        AND pandlid     = iv_pandlid
        AND validfrom  <= iv_validat
        AND ( companycode = iv_companycode OR companycode = '' ).
      APPEND ls_feature TO lt_matches.
    ENDLOOP.

    READ TABLE lt_matches INTO result WITH KEY companycode = iv_companycode.
    IF sy-subrc <> 0.
      READ TABLE lt_matches INTO result WITH KEY companycode = ''.
    ENDIF.
    "Fin - EXT_OSCUGALD - 02.09.2026 =====
  ENDMETHOD.

ENDCLASS.
