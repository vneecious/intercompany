" V001 (CC) — ME-13 (Delta v2)
CLASS ltc_me_upload_hdl DEFINITION DEFERRED.
CLASS zcl_reing_me_upload_hdl DEFINITION LOCAL FRIENDS ltc_me_upload_hdl.

CLASS ltc_me_upload_hdl DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS rejects_conflicting_fanout FOR TESTING.
    METHODS consolidates_equal_fanout FOR TESTING.
ENDCLASS.

CLASS ltc_me_upload_hdl IMPLEMENTATION.
  METHOD rejects_conflicting_fanout.
    DATA lt_candidates TYPE zcl_reing_me_upload_hdl=>ty_t_header_payload.
    DATA lt_messages TYPE zcl_reing_me_upload_hdl=>ty_t_message.
    DATA lt_payload TYPE zcl_reing_me_upload_hdl=>ty_t_header_payload.
    DATA lt_accepted TYPE zcl_reing_me_upload_hdl=>ty_t_accepted_source_row.

    APPEND VALUE #(
      source_row = 2 ct_id = 'CT1' matnr = 'MAT1' period_year = '2026' period_month = '07'
      metric_code = 'MET1'
      item = VALUE #( source_row = 2 bukrs = '1000' prctr = '0000000001'
                      campana = '001' role_category = 'C' allocation = '0'
                      me_value = '10.000000' ) ) TO lt_candidates.
    APPEND VALUE #(
      source_row = 3 ct_id = 'CT1' matnr = 'MAT1' period_year = '2026' period_month = '07'
      metric_code = 'MET2'
      item = VALUE #( source_row = 3 bukrs = '1000' prctr = '0000000001'
                      campana = '001' role_category = 'C' allocation = '0'
                      me_value = '20.000000' ) ) TO lt_candidates.

    zcl_reing_me_upload_hdl=>resolve_target_conflicts(
      EXPORTING it_candidates = lt_candidates
      CHANGING  ct_messages   = lt_messages
                ct_payload    = lt_payload
                ct_accepted   = lt_accepted ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_messages ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( act = lt_payload ).
    cl_abap_unit_assert=>assert_initial( act = lt_accepted ).
  ENDMETHOD.

  METHOD consolidates_equal_fanout.
    DATA lt_candidates TYPE zcl_reing_me_upload_hdl=>ty_t_header_payload.
    DATA lt_messages TYPE zcl_reing_me_upload_hdl=>ty_t_message.
    DATA lt_payload TYPE zcl_reing_me_upload_hdl=>ty_t_header_payload.
    DATA lt_accepted TYPE zcl_reing_me_upload_hdl=>ty_t_accepted_source_row.

    APPEND VALUE #(
      source_row = 2 ct_id = 'CT1' matnr = 'MAT1' period_year = '2026' period_month = '07'
      metric_code = 'MET1'
      item = VALUE #( source_row = 2 bukrs = '1000' prctr = '0000000001'
                      campana = '001' role_category = 'C' allocation = '0'
                      me_value = '10.000000' ) ) TO lt_candidates.
    APPEND VALUE #(
      source_row = 3 ct_id = 'CT1' matnr = 'MAT1' period_year = '2026' period_month = '07'
      metric_code = 'MET2'
      item = VALUE #( source_row = 3 bukrs = '1000' prctr = '0000000001'
                      campana = '001' role_category = 'C' allocation = '0'
                      me_value = '10.000000' ) ) TO lt_candidates.

    zcl_reing_me_upload_hdl=>resolve_target_conflicts(
      EXPORTING it_candidates = lt_candidates
      CHANGING  ct_messages   = lt_messages
                ct_payload    = lt_payload
                ct_accepted   = lt_accepted ).

    cl_abap_unit_assert=>assert_initial( act = lt_messages ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_payload ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_accepted ) exp = 2 ).
  ENDMETHOD.
ENDCLASS.
