" Ini EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C21: clase nueva
" Determina el código de métrica (Metric, campo estándar ProductGroup) a usar en
" ZBP_I_INTERCOPROPOSAL->applymetric, buscando la fila más específica en
" ZI_IntercoMetricDetermination (tabla ZINT_A_MD_METRICTYPE) por Sociedad Proveedora
" (opcional) + Material (obligatorio) + PaymentType (opcional). Si no encuentra fila,
" el llamador cae al dato maestro ZI_IntercoProduct.Metric (fallback, sin cambios,
" ver especificacion_tecnica.md Fase 3.2).
" Patrón singleton (get_instance) tal como lo consume el snippet ya redactado en la
" ET funcional — a diferencia de ZCL_INTERCO_DOC_BLART/_GLACCOUNT (que se instancian
" una vez por documento con producto fijo y llaman get() muchas veces), esta clase se
" invoca una vez por ítem de propuesta con un producto distinto cada vez, por eso
" carga toda la tabla vigente una sola vez (lazy, en el primer get_instance) y
" resuelve cada búsqueda en memoria. Misma técnica de precedencia "match exacto o
" vacío" vía RANGE que BLART/GLACCOUNT — mismo riesgo aceptado de no-determinismo
" ante combinaciones ambiguas (ver nota de Fase 6, carga de datos).
CLASS zcl_interco_metric_type DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_data,
             validfrom           TYPE zi_intercometricdetermination-validfrom,
             validto             TYPE zi_intercometricdetermination-validto,
             providercompanycode TYPE zi_intercometricdetermination-providercompanycode,
             product             TYPE zi_intercometricdetermination-product,
             paymenttype         TYPE zi_intercometricdetermination-paymenttype,
             metric              TYPE zi_intercometricdetermination-metric,
           END OF ty_data.

    DATA data TYPE TABLE OF ty_data READ-ONLY.

    CLASS-METHODS get_instance
      RETURNING VALUE(result) TYPE REF TO zcl_interco_metric_type.

    METHODS get_metric_type
      IMPORTING
                iv_providercompanycode TYPE zi_intercometricdetermination-providercompanycode OPTIONAL
                iv_product             TYPE zi_intercometricdetermination-product
                iv_paymenttype         TYPE zi_intercometricdetermination-paymenttype OPTIONAL
      RETURNING VALUE(rv_metric)       TYPE zi_intercometricdetermination-metric.

  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_interco_metric_type.

    METHODS constructor.

ENDCLASS.



CLASS zcl_interco_metric_type IMPLEMENTATION.

  METHOD get_instance.

    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_interco_metric_type( ).
    ENDIF.
    result = go_instance.

  ENDMETHOD.

  METHOD constructor.

    SELECT validfrom, validto, providercompanycode, product, paymenttype, metric
      FROM zi_intercometricdetermination
      WHERE validfrom <= @sy-datum
        AND validto >= @sy-datum
        AND isdeleted IS INITIAL
      INTO TABLE @data.

  ENDMETHOD.

  METHOD get_metric_type.

    DATA range_provider_company_code TYPE RANGE OF zi_intercometricdetermination-providercompanycode.
    DATA range_paymenttype           TYPE RANGE OF zi_intercometricdetermination-paymenttype.

    IF iv_providercompanycode IS SUPPLIED.
      range_provider_company_code = VALUE #( sign = 'I' option = 'EQ'
                                  ( low = space )
                                  ( low = iv_providercompanycode ) ).
    ENDIF.

    IF iv_paymenttype IS SUPPLIED.
      range_paymenttype = VALUE #( sign = 'I' option = 'EQ'
                               ( low = space )
                               ( low = iv_paymenttype ) ).
    ENDIF.

    SELECT SINGLE data~metric FROM @data AS data
      WHERE product              = @iv_product
        AND providercompanycode IN @range_provider_company_code
        AND paymenttype          IN @range_paymenttype
      INTO @rv_metric.

    IF sy-subrc <> 0.
      " TODO: handle error
    ENDIF.

  ENDMETHOD.

ENDCLASS.
" Fin EXT_OSCUGALD 30.09.2026 - Facturación Local CH/ARG - C21
