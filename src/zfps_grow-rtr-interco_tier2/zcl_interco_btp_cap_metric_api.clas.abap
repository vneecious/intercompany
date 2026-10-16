CLASS zcl_interco_btp_cap_metric_api DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE .

  PUBLIC SECTION.

    TYPES:
      BEGIN OF  ty_item_calculated,
        FiscalPeriod           TYPE string,
        FiscalYear             TYPE string,
        IsDeleted              TYPE abap_boolean,
        IsManual               TYPE abap_boolean,
        Product                TYPE string,
        ProductName            TYPE string,
        ProfitCenter           TYPE string,
        ProviderCompanyCode    TYPE string,
        RecipientCompanyCode   TYPE string,
        ShareRate              TYPE string,
        ShareRateH             TYPE string,  "Hispano
        ShareRateLocal         TYPE string,  "Local
        SiteCode               TYPE string,
        To_Header_FiscalPeriod TYPE string,
        To_Header_FiscalYear   TYPE string,
        To_Header_Metric       TYPE string,
        To_Header_Version      TYPE string,  "Metric Version
      END OF ty_item_calculated .
    TYPES:
      tt_item_calculated TYPE STANDARD TABLE OF ty_item_calculated WITH NON-UNIQUE KEY To_Header_FiscalPeriod .
    TYPES:
      BEGIN OF  ty_item_value ,
        value TYPE tt_item_calculated,
      END OF ty_item_value .
    TYPES:
      BEGIN OF ty_metric_header,
        CreatedAt    TYPE string,
        CreatedBy    TYPE string,
        FiscalPeriod TYPE string,
        FiscalYear   TYPE string,
        Version      TYPE string,
        IsCalculated TYPE abap_boolean,
        IsReleased   TYPE abap_boolean,
        Metric       TYPE string,
        ModifiedAt   TYPE string,
        ModifiedBy   TYPE string,
        ReleasedAt   TYPE string,
        ReleasedBy   TYPE string,
      END OF ty_metric_header .
    TYPES:
      tt_metric_header TYPE STANDARD TABLE OF ty_metric_header WITH NON-UNIQUE KEY CreatedAt .
    TYPES:
      BEGIN OF ty_metric_value,
        value TYPE tt_metric_header,
      END OF ty_metric_value .

    METHODS get_regional_metric
      IMPORTING
        !iv_fiscal_period       TYPE zint_dte_fiscalperiod
        !iv_fiscal_year         TYPE gjahr
        !iv_metric_code         TYPE string
      RETURNING
        VALUE(rt_metric_header) TYPE tt_metric_header .
    METHODS get_regional_metric_items_calc
      IMPORTING
        !iv_fiscal_period          TYPE zint_dte_fiscalperiod
        !iv_fiscal_year            TYPE gjahr
        !iv_metric_code            TYPE string
        !iv_product                TYPE string
        !iv_provide_code           TYPE string
*        !iv_header_version         TYPE string
      RETURNING
        VALUE(rt_items_calculated) TYPE tt_item_calculated .
    CLASS-METHODS get_instance
      RETURNING
        VALUE(ro_instance) TYPE REF TO zcl_interco_btp_cap_metric_api .

    " ─── NUEVOS: Destino local ──────────────────────────────────
    METHODS get_local_metric
      IMPORTING
        iv_fiscal_period        TYPE zint_dte_fiscalperiod
        iv_fiscal_year          TYPE gjahr
        iv_metric_code          TYPE string
      RETURNING
        VALUE(rt_metric_header) TYPE tt_metric_header.

    METHODS get_local_metric_items_calc
      IMPORTING
        iv_fiscal_period           TYPE zint_dte_fiscalperiod
        iv_fiscal_year             TYPE gjahr
        iv_metric_code             TYPE string
        iv_product                 TYPE string
        iv_provide_code            TYPE string
      RETURNING
        VALUE(rt_items_calculated) TYPE tt_item_calculated.

    " ─── NUEVO: Fachada que decide regional vs local ────────────
    METHODS get_metric_header
      IMPORTING
        iv_fiscal_period        TYPE zint_dte_fiscalperiod
        iv_fiscal_year          TYPE gjahr
        iv_metric_code          TYPE string
        iv_is_local             TYPE abap_boolean DEFAULT abap_false
      RETURNING
        VALUE(rt_metric_header) TYPE tt_metric_header.

    METHODS get_metric_items_calc
      IMPORTING
        iv_fiscal_period           TYPE zint_dte_fiscalperiod
        iv_fiscal_year             TYPE gjahr
        iv_metric_code             TYPE string
        iv_product                 TYPE string
        iv_provide_code            TYPE string
        iv_is_local                TYPE abap_boolean DEFAULT abap_false
      RETURNING
        VALUE(rt_items_calculated) TYPE tt_item_calculated.
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_interco_btp_cap_metric_api .

    METHODS mock_metric
      RETURNING
        VALUE(rv_json) TYPE string .
    METHODS mock_items_calc
      RETURNING
        VALUE(rv_json) TYPE string .
    METHODS get_api_rest
      IMPORTING
        !iv_destination   TYPE c
        !iv_uri           TYPE string
      EXPORTING
        !rv_json          TYPE string
        !rv_status_code   TYPE i
        !rv_status_reason TYPE string .
ENDCLASS.



CLASS zcl_interco_btp_cap_metric_api IMPLEMENTATION.


  METHOD mock_items_calc.

    rv_json = '{"@odata.context": "$metadata#MetricCalculatedItems", "value": [{ "FiscalPeriod": "01", "FiscalYear": "2024", "IsDeleted": false, "IsManual": false, ' &&
              '"Product": "ICSRV11", "ProductName": "CUSTOMER SERVICES", "ProfitCenter": "0000000995", "ProviderCompanyCode": "MLA", "RecipientCompanyCode": "MCO", '  &&
              '"ShareRate": "25.39741", "SiteCode": "MLM", "To_Header_FiscalPeriod": "01", "To_Header_FiscalYear": "2024", "To_Header_Metric": "CORPS" },'  &&
              '{ "FiscalPeriod": "01", "FiscalYear": "2024", "IsDeleted": false, "IsManual": false, "Product": "ICSRV11", "ProductName": "CUSTOMER SERVICES", '  &&
              '"ProfitCenter": "0000000110", "ProviderCompanyCode": "MLA", "RecipientCompanyCode": "MCO", "ShareRate": "25.39741", "SiteCode": "MLM", '  &&
              '"To_Header_FiscalPeriod": "01","To_Header_FiscalYear": "2024","To_Header_Metric": "CORPS"},' &&
              '{"FiscalPeriod": "01","FiscalYear": "2024","IsDeleted": false,"IsManual": false,"Product": "ICSRV11","ProductName": "CUSTOMER SERVICES",' &&
              '"ProfitCenter": "0000000619","ProviderCompanyCode": "MLA","RecipientCompanyCode": "MCO","ShareRate": "18.45415","SiteCode": "MLM",' &&
              '"To_Header_FiscalPeriod": "01","To_Header_FiscalYear": "2024","To_Header_Metric": "CORPS"},' &&
              '{"FiscalPeriod": "01","FiscalYear": "2024","IsDeleted": false,"IsManual": false,"Product": "ICSRV11","ProductName": "CUSTOMER SERVICES",' &&
              '"ProfitCenter": "0000000407","ProviderCompanyCode": "MLA","RecipientCompanyCode": "MCO","ShareRate": "19.25788","SiteCode": "MLM",' &&
              '"To_Header_FiscalPeriod": "01","To_Header_FiscalYear": "2024","To_Header_Metric": "CORPS"},' &&
              '{"FiscalPeriod": "01","FiscalYear": "2024","IsDeleted": false,"IsManual": false,"Product": "ICSRV11","ProductName": "CUSTOMER SERVICES",' &&
              '"ProfitCenter": "300","ProviderCompanyCode": "MLA","RecipientCompanyCode": "MCO","ShareRate": "8.27822","SiteCode": "MLM",' &&
              '"To_Header_FiscalPeriod": "01","To_Header_FiscalYear": "2024","To_Header_Metric": "CORPS"}' &&
              ']}'.
  ENDMETHOD.


  METHOD mock_metric.

    rv_json = '[{"CreatedAt": "2024-12-17T13:31:57.531Z", "CreatedBy": "ext_fraacuna", "FiscalPeriod": "07", "FiscalYear": "2024", "IsCalculated": true, ' &&
              '"IsReleased": true, "Metric": "CORPS", "ModifiedAt": "2024-12-17T13:32:23.094Z", "ModifiedBy": "ext_fraacuna", ' &&
              '"ReleasedAt": "2024-12-17T13:32:23.093Z", "ReleasedBy": "ext_fraacuna"}]'.

  ENDMETHOD.


  METHOD get_api_rest.
    DATA: lt_header_fields TYPE tihttpnvp,
          mv_response      TYPE string,
          mo_http_client   TYPE REF TO  if_http_client,
          mt_header_fields TYPE  tihttpnvp.
    DATA: lv_json          TYPE /ui2/cl_json=>json.
    DATA: lo_response      TYPE REF TO if_rest_entity.

    CALL METHOD cl_http_client=>create_by_destination
      EXPORTING
        destination              = iv_destination
      IMPORTING
        client                   = mo_http_client
      EXCEPTIONS
        argument_not_found       = 1 " Connection Parameter (Destination) Not Available
        destination_not_found    = 2 " Destination not found
        destination_no_authority = 3 " No Authorization to Use HTTP Destination
        plugin_not_active        = 4 " HTTP/HTTPS communication not available
        internal_error           = 5 " Internal error (e.g. name too long)
        OTHERS                   = 6.
    IF sy-subrc <> 0.
*      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*                 WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

    ENDIF.

    APPEND VALUE #( name = 'Content-Type' value = 'application/json' ) TO lt_header_fields.
    APPEND VALUE #( name = 'accept' value = 'application/json' ) TO lt_header_fields.

    mo_http_client->request->set_header_fields( fields = lt_header_fields ).
    mo_http_client->request->set_method( if_http_request=>co_request_method_get ) .

    cl_http_utility=>set_request_uri(
      EXPORTING
        request = mo_http_client->request
        uri     = iv_uri
    ).

    mo_http_client->send(
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3 ).

    IF sy-subrc <> 0.

    ENDIF.

    mo_http_client->receive(
     EXCEPTIONS
       http_communication_failure = 1
       http_invalid_state         = 2
       http_processing_failed     = 3 ).
*    IF sy-subrc EQ 0.
    mo_http_client->response->get_status( IMPORTING code   = rv_status_code
                                                    reason = rv_status_reason ).
    IF rv_status_code <> 200.
      CALL METHOD mo_http_client->close
        EXCEPTIONS
          http_invalid_state = 1
          OTHERS             = 2.

    ENDIF.
*    ENDIF.

    CLEAR mv_response.
    DATA(lo_rest_client) = NEW cl_rest_http_client( io_http_client = mo_http_client  ).

    lo_response = lo_rest_client->if_rest_client~get_response_entity( ).
    rv_json = lo_response->get_string_data( ).


  ENDMETHOD.


  METHOD get_regional_metric.
    DATA: ls_metric_value TYPE ty_metric_value.

    CHECK iv_metric_code IS NOT INITIAL.
    CHECK iv_fiscal_year IS NOT INITIAL.
    CHECK iv_fiscal_period IS NOT INITIAL.

*   DATA(lv_json) = me->mock_metric( ).
    DATA(lv_uri) = |/MetricHeaders?$filter=Metric eq '{ iv_metric_code }' and FiscalPeriod eq '{ iv_fiscal_period+1(2) }' and FiscalYear eq '{ iv_fiscal_year }'|.

    me->get_api_rest(
      EXPORTING
        iv_destination   = 'BTP_INTERCO_REGIONAL_METRIC_DEST'
        iv_uri           = lv_uri
      IMPORTING
        rv_json          = DATA(lv_json)
        rv_status_code   = DATA(lv_status_code)
        rv_status_reason = DATA(lv_status_reason)
    ).

    IF lv_json IS NOT INITIAL.

      /ui2/cl_json=>deserialize(
         EXPORTING json = lv_json
         CHANGING data = ls_metric_value
      ).

      IF ls_metric_value IS NOT INITIAL.
        rt_metric_header = ls_metric_value-value.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD get_regional_metric_items_calc.
    DATA: ls_item_value TYPE ty_item_value,
          lv_count      TYPE i,
          lv_times      TYPE i,
          lv_page_size  TYPE i VALUE 5000,
          lv_top        TYPE i,
          lv_skip       TYPE i,
          lv_filter     TYPE string,
          lv_uri        TYPE string.

    CHECK iv_metric_code IS NOT INITIAL.
    CHECK iv_fiscal_year IS NOT INITIAL.
    CHECK iv_fiscal_period IS NOT INITIAL.

    lv_filter = |?$filter=To_Header_Metric eq '{ iv_metric_code }' and FiscalPeriod eq '{ iv_fiscal_period+1(2) }' and FiscalYear eq '{ iv_fiscal_year }'| &&
                | and Product eq '{ iv_product }' and ProviderCompanyCode eq '{ iv_provide_code }'|.

*   DATA(lv_json) = me->mock_items_calc( ).
    lv_uri = |/MetricCalculatedItems/$count| && lv_filter.

    me->get_api_rest(
      EXPORTING
        iv_destination   = 'BTP_INTERCO_REGIONAL_METRIC_DEST'
        iv_uri           = lv_uri
      IMPORTING
        rv_json          = DATA(lv_count_resp)
        rv_status_code   = DATA(lv_count_status_code)
        rv_status_reason = DATA(lv_count_status_reason)
    ).

    IF lv_count_status_code EQ 200.
      lv_count = CONV #( lv_count_resp ).
      lv_times = COND #( WHEN lv_count > lv_page_size THEN ( lv_count / lv_page_size ) ELSE 1 ).

      lv_skip = 0.
      lv_top = lv_page_size.

      DO lv_times TIMES.

        lv_uri = |/MetricCalculatedItems| && lv_filter &&
                 |&$top={ lv_top }&$skip={ lv_skip } |.

        me->get_api_rest(
          EXPORTING
            iv_destination   = 'BTP_INTERCO_REGIONAL_METRIC_DEST'
            iv_uri           = lv_uri
          IMPORTING
            rv_json          = DATA(lv_json)
            rv_status_code   = DATA(lv_status_code)
            rv_status_reason = DATA(lv_status_reason)
        ).

        IF lv_json IS NOT INITIAL.
          /ui2/cl_json=>deserialize(
             EXPORTING json = lv_json
             CHANGING data = ls_item_value
          ).
          LOOP AT ls_item_value-value INTO DATA(ls_item).
            APPEND ls_item TO rt_items_calculated.
          ENDLOOP.
        ENDIF.
        lv_skip = lv_skip + lv_page_size.
      ENDDO.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance.

    ro_instance = COND #( WHEN zcl_interco_btp_cap_metric_api=>go_instance IS BOUND
                           THEN zcl_interco_btp_cap_metric_api=>go_instance
                         ELSE NEW zcl_interco_btp_cap_metric_api(  )  ).
    go_instance = ro_instance.
  ENDMETHOD.
  METHOD get_local_metric.
    DATA: ls_metric_value TYPE ty_metric_value.

    CHECK iv_metric_code IS NOT INITIAL.
    CHECK iv_fiscal_year IS NOT INITIAL.
    CHECK iv_fiscal_period IS NOT INITIAL.

*   DATA(lv_json) = me->mock_metric( ).
    DATA(lv_uri) = |/MetricHeaders?$filter=Metric eq '{ iv_metric_code }' and FiscalPeriod eq '{ iv_fiscal_period+1(2) }' and FiscalYear eq '{ iv_fiscal_year }'|.

    me->get_api_rest(
      EXPORTING
        iv_destination   = 'BTP_INTERCO_LOCAL_METRIC_DEST'
        iv_uri           = lv_uri
      IMPORTING
        rv_json          = DATA(lv_json)
        rv_status_code   = DATA(lv_status_code)
        rv_status_reason = DATA(lv_status_reason)
    ).

    IF lv_json IS NOT INITIAL.

      /ui2/cl_json=>deserialize(
         EXPORTING json = lv_json
         CHANGING data = ls_metric_value
      ).

      IF ls_metric_value IS NOT INITIAL.
        rt_metric_header = ls_metric_value-value.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD get_local_metric_items_calc.
    DATA: ls_item_value TYPE ty_item_value,
          lv_count      TYPE i,
          lv_times      TYPE i,
          lv_page_size  TYPE i VALUE 5000,
          lv_top        TYPE i,
          lv_skip       TYPE i,
          lv_filter     TYPE string,
          lv_uri        TYPE string.

    CHECK iv_metric_code IS NOT INITIAL.
    CHECK iv_fiscal_year IS NOT INITIAL.
    CHECK iv_fiscal_period IS NOT INITIAL.

    lv_filter = |?$filter=To_Header_Metric eq '{ iv_metric_code }' and FiscalPeriod eq '{ iv_fiscal_period+1(2) }' and FiscalYear eq '{ iv_fiscal_year }'| &&
                | and Product eq '{ iv_product }' and ProviderCompanyCode eq '{ iv_provide_code }'|.

*   DATA(lv_json) = me->mock_items_calc( ).
    lv_uri = |/MetricCalculatedItems/$count| && lv_filter.

    me->get_api_rest(
      EXPORTING
        iv_destination   = 'BTP_INTERCO_LOCAL_METRIC_DEST'
        iv_uri           = lv_uri
      IMPORTING
        rv_json          = DATA(lv_count_resp)
        rv_status_code   = DATA(lv_count_status_code)
        rv_status_reason = DATA(lv_count_status_reason)
    ).

    IF lv_count_status_code EQ 200.
      lv_count = CONV #( lv_count_resp ).
      lv_times = COND #( WHEN lv_count > lv_page_size THEN ( lv_count / lv_page_size ) ELSE 1 ).

      lv_skip = 0.
      lv_top = lv_page_size.

      DO lv_times TIMES.

        lv_uri = |/MetricCalculatedItems| && lv_filter &&
                 |&$top={ lv_top }&$skip={ lv_skip } |.

        me->get_api_rest(
          EXPORTING
            iv_destination   = 'BTP_INTERCO_LOCAL_METRIC_DEST'
            iv_uri           = lv_uri
          IMPORTING
            rv_json          = DATA(lv_json)
            rv_status_code   = DATA(lv_status_code)
            rv_status_reason = DATA(lv_status_reason)
        ).

        IF lv_json IS NOT INITIAL.
          /ui2/cl_json=>deserialize(
             EXPORTING json = lv_json
             CHANGING data = ls_item_value
          ).
          LOOP AT ls_item_value-value INTO DATA(ls_item).
            APPEND ls_item TO rt_items_calculated.
          ENDLOOP.
        ENDIF.
        lv_skip = lv_skip + lv_page_size.
      ENDDO.
    ENDIF.
  ENDMETHOD.

  METHOD get_metric_header.
    IF iv_is_local = abap_true.
      rt_metric_header = me->get_local_metric(
        iv_fiscal_period = iv_fiscal_period
        iv_fiscal_year   = iv_fiscal_year
        iv_metric_code   = iv_metric_code ).
    ELSE.
      rt_metric_header = me->get_regional_metric(
        iv_fiscal_period = iv_fiscal_period
        iv_fiscal_year   = iv_fiscal_year
        iv_metric_code   = iv_metric_code ).
    ENDIF.
  ENDMETHOD.

  METHOD get_metric_items_calc.
    IF iv_is_local = abap_true.
      rt_items_calculated = me->get_local_metric_items_calc(
        iv_fiscal_period = iv_fiscal_period
        iv_fiscal_year   = iv_fiscal_year
        iv_metric_code   = iv_metric_code
        iv_product       = iv_product
        iv_provide_code  = iv_provide_code ).
    ELSE.
      rt_items_calculated = me->get_regional_metric_items_calc(
        iv_fiscal_period = iv_fiscal_period
        iv_fiscal_year   = iv_fiscal_year
        iv_metric_code   = iv_metric_code
        iv_product       = iv_product
        iv_provide_code  = iv_provide_code ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
