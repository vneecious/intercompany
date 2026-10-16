" V001 (CC) - CA-109 (Delta v2): isolated SQL/CDS fixtures, no real data writes.
CLASS ltc_cm_sources DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES tt_cm TYPE STANDARD TABLE OF zreing_cm_h_a WITH EMPTY KEY.
    TYPES tt_recv TYPE STANDARD TABLE OF zreing_cm_recv_a WITH EMPTY KEY.
    CONSTANTS c_ct TYPE sysuuid_x16 VALUE '10900000000000000000000000000001'.
    CONSTANTS c_mat TYPE sysuuid_x16 VALUE '10900000000000000000000000000002'.
    CONSTANTS c_cm2 TYPE sysuuid_x16 VALUE '10900000000000000000000000000012'.
    CONSTANTS c_cm3 TYPE sysuuid_x16 VALUE '10900000000000000000000000000013'.
    CLASS-DATA mo_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_reing_ca_sources.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS exact_load FOR TESTING RAISING cx_static_check.
    METHODS wrong_context FOR TESTING RAISING cx_static_check.
    METHODS wrong_instance FOR TESTING RAISING cx_static_check.
    METHODS unresolved_load FOR TESTING RAISING cx_static_check.
    METHODS scoped_fallback FOR TESTING RAISING cx_static_check.
    METHODS unscoped_fallback FOR TESTING RAISING cx_static_check.
    METHODS receivers_same_load FOR TESTING RAISING cx_static_check.
    METHODS singleton_types FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_cm_sources IMPLEMENTATION.
  METHOD class_setup.
    mo_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZREING_CM_H_A' ) ( 'ZREING_CM_RECV_A' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    mo_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    mo_env->clear_doubles( ).
    mo_cut = NEW zcl_reing_ca_sources( ).
    mo_env->insert_test_data( VALUE tt_cm(
      ( client = sy-mandt cm_h_id = c_cm2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '002' period_year = '2026' period_month = '08'
        load_seq = '001' cm_status = 'LIBD' amount = 1000 currency = 'USD' )
      ( client = sy-mandt cm_h_id = c_cm3 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '003' period_year = '2026' period_month = '08'
        load_seq = '099' cm_status = 'LIBD' amount = 2000 currency = 'USD' ) ) ).
  ENDMETHOD.
  METHOD exact_load.
    DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
      iv_op_type = 'A' iv_period = '08' iv_year = '2026' iv_cm_h_id = c_cm2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_cm-amount exp = 1000 ).
    cl_abap_unit_assert=>assert_equals( act = ls_cm-op_instance_num exp = '002' ).
  ENDMETHOD.
  METHOD wrong_context.
    DATA lt_wrong TYPE tt_cm.
    lt_wrong = VALUE #(
      ( ct_uuid = c_mat mat_uuid = c_mat op_type = 'A' period_year = '2026' period_month = '08' )
      ( ct_uuid = c_ct mat_uuid = c_ct op_type = 'A' period_year = '2026' period_month = '08' )
      ( ct_uuid = c_ct mat_uuid = c_mat op_type = 'F' period_year = '2026' period_month = '08' )
      ( ct_uuid = c_ct mat_uuid = c_mat op_type = 'A' period_year = '2025' period_month = '08' )
      ( ct_uuid = c_ct mat_uuid = c_mat op_type = 'A' period_year = '2026' period_month = '07' ) ).
    LOOP AT lt_wrong INTO DATA(ls_wrong).
      TRY.
          DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = ls_wrong-ct_uuid
            iv_mat_uuid = ls_wrong-mat_uuid iv_op_type = ls_wrong-op_type
            iv_period = ls_wrong-period_month iv_year = ls_wrong-period_year iv_cm_h_id = c_cm2 ).
          cl_abap_unit_assert=>fail( msg = 'CM of another business key/period must be rejected' ).
        CATCH zcx_reing_ca_calc_error.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
  METHOD wrong_instance.
    TRY.
        DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
          iv_op_type = 'A' iv_period = '08' iv_year = '2026' iv_cm_h_id = c_cm2
          iv_op_instance_num = '003' ).
        cl_abap_unit_assert=>fail( msg = 'Explicit instance mismatch must fail' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.
  METHOD unresolved_load.
    mo_env->clear_doubles( ).
    mo_env->insert_test_data( VALUE tt_cm(
      ( client = sy-mandt cm_h_id = c_cm2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' period_year = '2026' period_month = '08' cm_status = 'LIBD' amount = 1000 ) ) ).
    TRY.
        DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
          iv_op_type = 'A' iv_period = '08' iv_year = '2026' iv_cm_h_id = c_cm2 ).
        cl_abap_unit_assert=>fail( msg = 'Historical 000 must not be consumed' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.
  METHOD scoped_fallback.
    DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
      iv_op_type = 'A' iv_period = '08' iv_year = '2026' iv_op_instance_num = '002' ).
    cl_abap_unit_assert=>assert_equals( act = ls_cm-cm_h_id exp = c_cm2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_cm-amount exp = 1000 ).
  ENDMETHOD.
  METHOD unscoped_fallback.
    TRY.
        DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
          iv_op_type = 'A' iv_period = '08' iv_year = '2026' ).
        cl_abap_unit_assert=>fail( msg = 'Missing load ID and instance must fail' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.
  METHOD receivers_same_load.
    mo_env->insert_test_data( VALUE tt_recv(
      ( client = sy-mandt cm_h_id = c_cm2 bukrs_recv = '1000' )
      ( client = sy-mandt cm_h_id = c_cm3 bukrs_recv = '2000' ) ) ).
    DATA(lt_recv) = mo_cut->get_cm_recv_filter( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
      iv_op_type = 'A' iv_period = '08' iv_year = '2026' iv_cm_h_id = c_cm2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_recv ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_recv[ 1 ] exp = '1000' ).
    lt_recv = mo_cut->get_cm_recv_filter( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
      iv_op_type = 'A' iv_period = '08' iv_year = '2026' iv_op_instance_num = '002' ).
    cl_abap_unit_assert=>assert_equals( act = lt_recv[ 1 ] exp = '1000' ).
  ENDMETHOD.
  METHOD singleton_types.
    TYPES tt_ops TYPE STANDARD TABLE OF zreing_op_type WITH EMPTY KEY.
    DATA(lt_ops) = VALUE tt_ops( ( 'F' ) ( 'P' ) ( 'NC' ) ( 'ANT' ) ).
    LOOP AT lt_ops INTO DATA(lv_op).
      mo_env->clear_doubles( ).
      mo_env->insert_test_data( VALUE tt_cm(
        ( client = sy-mandt cm_h_id = c_cm2 ct_uuid = c_ct mat_uuid = c_mat
          op_type = lv_op op_instance_num = '001' period_year = '2026' period_month = '08'
          load_seq = '001' cm_status = 'LIBD' amount = 750 currency = 'USD' ) ) ).
      mo_env->insert_test_data( VALUE tt_recv( ( client = sy-mandt cm_h_id = c_cm2 bukrs_recv = '1000' ) ) ).
      DATA(ls_cm) = mo_cut->get_cm_amount( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
        iv_op_type = lv_op iv_period = '08' iv_year = '2026' iv_cm_h_id = c_cm2 ).
      cl_abap_unit_assert=>assert_equals( act = ls_cm-amount exp = 750 ).
      DATA(lt_recv) = mo_cut->get_cm_recv_filter( iv_ct_uuid = c_ct iv_mat_uuid = c_mat
        iv_op_type = lv_op iv_period = '08' iv_year = '2026' iv_op_instance_num = '001' ).
      cl_abap_unit_assert=>assert_equals( act = lt_recv[ 1 ] exp = '1000' ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - CA-109: shared fixtures; one CDS environment per test class.
CLASS lcl_cm_cds_fixture DEFINITION ABSTRACT.
  PROTECTED SECTION.
    TYPES tt_cm TYPE STANDARD TABLE OF zreing_cm_h_a WITH EMPTY KEY.
    TYPES tt_opt TYPE STANDARD TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.
    TYPES tt_ct TYPE STANDARD TABLE OF zreing_ct2_a WITH EMPTY KEY.
    TYPES tt_mat TYPE STANDARD TABLE OF zreing_ct2_mat_a WITH EMPTY KEY.
    TYPES tt_cat TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    TYPES tt_me TYPE STANDARD TABLE OF zreing_me_h_a WITH EMPTY KEY.
    TYPES tt_ms TYPE STANDARD TABLE OF zi_reingcamesharebysoc WITH EMPTY KEY.
    TYPES tt_cmp TYPE STANDARD TABLE OF zi_reingcacmmeperiod WITH EMPTY KEY.
    TYPES tt_cme TYPE STANDARD TABLE OF zi_reingcaactgrpcmelig WITH EMPTY KEY.
    TYPES tt_ln TYPE STANDARD TABLE OF zi_reingcalineperiod WITH EMPTY KEY.
    TYPES tt_crn TYPE STANDARD TABLE OF zreing_ct2_crn_a WITH EMPTY KEY.
    TYPES tt_la TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    TYPES tt_ba TYPE STANDARD TABLE OF zi_reingcadfrbaseamt WITH EMPTY KEY.
    TYPES tt_cqs TYPE STANDARD TABLE OF zi_reingcadfrcuotaseq WITH EMPTY KEY.
    CONSTANTS c_ct TYPE sysuuid_x16 VALUE '10900000000000000000000000000001'.
    CONSTANTS c_mat TYPE sysuuid_x16 VALUE '10900000000000000000000000000002'.
    CONSTANTS c_a2 TYPE sysuuid_x16 VALUE '10900000000000000000000000000022'.
    CONSTANTS c_a3 TYPE sysuuid_x16 VALUE '10900000000000000000000000000023'.
    CONSTANTS c_d2 TYPE sysuuid_x16 VALUE '10900000000000000000000000000032'.
    CONSTANTS c_d3 TYPE sysuuid_x16 VALUE '10900000000000000000000000000033'.
    CONSTANTS c_cm2 TYPE sysuuid_x16 VALUE '10900000000000000000000000000012'.
    CONSTANTS c_cm3 TYPE sysuuid_x16 VALUE '10900000000000000000000000000013'.
    CLASS-DATA mo_env TYPE REF TO if_cds_test_environment.
    METHODS given_pending
      IMPORTING iv_single_instance TYPE zreing_op_instance_num OPTIONAL
                iv_unresolved TYPE abap_bool DEFAULT abap_false.
ENDCLASS.

CLASS lcl_cm_cds_fixture IMPLEMENTATION.
  METHOD given_pending.
    mo_env->insert_test_data( VALUE tt_ct(
      ( mandt = sy-mandt ct_uuid = c_ct ct_id = 'IC-0001' ct_status = 'AC' waers = 'USD' ) ) ).
    mo_env->insert_test_data( VALUE tt_mat(
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat matnr = 'ICSRV44' ) ) ).
    mo_env->insert_test_data( VALUE tt_opt(
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'A'
        op_uuid = c_a2 op_instance_num = '002' me_period_offset = '00' )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'A'
        op_uuid = c_a3 op_instance_num = '003' me_period_offset = '01' ) ) ).
    mo_env->insert_test_data( VALUE tt_cat(
      ( mandt = sy-mandt op_type = 'A' active = abap_true cm_loadable = abap_true permite_delta = abap_true ) ) ).
    DATA(lt_cm) = VALUE tt_cm(
      ( client = sy-mandt cm_h_id = c_cm2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '002' period_year = '2026' period_month = '08'
        cm_status = 'LIBD' amount = 1000 currency = 'USD' )
      ( client = sy-mandt cm_h_id = c_cm3 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '003' period_year = '2026' period_month = '08'
        cm_status = 'LIBD' amount = 2000 currency = 'USD' ) ).
    IF iv_single_instance IS NOT INITIAL.
      DELETE lt_cm WHERE op_instance_num <> iv_single_instance.
    ENDIF.
    IF iv_unresolved = abap_true.
      LOOP AT lt_cm ASSIGNING FIELD-SYMBOL(<cm>).
        CLEAR <cm>-op_instance_num.
      ENDLOOP.
    ENDIF.
    mo_env->insert_test_data( lt_cm ).
    mo_env->insert_test_data( VALUE tt_me(
      ( mandt = sy-mandt me_h_id = c_cm2 ct_id = 'IC-0001' matnr = 'ICSRV44'
        period_year = '2026' period_month = '08' me_status = 'LIBD' )
      ( mandt = sy-mandt me_h_id = c_cm3 ct_id = 'IC-0001' matnr = 'ICSRV44'
        period_year = '2026' period_month = '07' me_status = 'LIBD' ) ) ).
    mo_env->insert_test_data( VALUE tt_ms(
      ( CtId = 'IC-0001' Matnr = 'ICSRV44' PeriodYear = '2026' PeriodMonth = '08'
        BukrsRecv = '1000' SharePctSoc = 100 Country = 'AR' )
      ( CtId = 'IC-0001' Matnr = 'ICSRV44' PeriodYear = '2026' PeriodMonth = '07'
        BukrsRecv = '2000' SharePctSoc = 100 Country = 'CL' ) ) ).
    " Deliberately offer every pair in the dependency double: the tested
    " consumer itself must enforce CM-to-option instance equality.
    mo_env->insert_test_data( VALUE tt_cmp(
      ( CmHId = c_cm2 OpUuid = c_a2 MePeriodYear = '2026' MePeriodMonth = '08' )
      ( CmHId = c_cm2 OpUuid = c_a3 MePeriodYear = '2026' MePeriodMonth = '07' )
      ( CmHId = c_cm3 OpUuid = c_a2 MePeriodYear = '2026' MePeriodMonth = '08' )
      ( CmHId = c_cm3 OpUuid = c_a3 MePeriodYear = '2026' MePeriodMonth = '07' ) ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltc_cm_elig DEFINITION FINAL INHERITING FROM lcl_cm_cds_fixture
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS aggregation_instances FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_cm_elig IMPLEMENTATION.
  METHOD class_setup.
    mo_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_REINGCAACTGRPCMELIG' ).
  ENDMETHOD.
  METHOD class_teardown.
    mo_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    mo_env->clear_doubles( ).
  ENDMETHOD.
  METHOD aggregation_instances.
    mo_env->insert_test_data( VALUE tt_cm(
      ( client = sy-mandt cm_h_id = c_cm2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '002' period_year = '2026' period_month = '08' cm_status = 'LIBD' )
      ( client = sy-mandt cm_h_id = c_cm3 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '003' period_year = '2026' period_month = '08' cm_status = 'SUPS' ) ) ).
    SELECT * FROM zi_reingcaactgrpcmelig
      WHERE CtUuid = @c_ct AND MatUuid = @c_mat AND OpType = 'A'
        AND PeriodYear = '2026' AND PeriodMonth = '08'
      INTO TABLE @DATA(lt_elig).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_elig ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_elig[ OpInstanceNum = '002' ]-CmLibdCount exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_elig[ OpInstanceNum = '003' ]-CmLibdCount exp = 0 ).
  ENDMETHOD.
ENDCLASS.

CLASS ltc_cm_period DEFINITION FINAL INHERITING FROM lcl_cm_cds_fixture
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS offset_instances FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_cm_period IMPLEMENTATION.
  METHOD class_setup.
    mo_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_REINGCACMMEPERIOD' ).
  ENDMETHOD.
  METHOD class_teardown.
    mo_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    mo_env->clear_doubles( ).
  ENDMETHOD.
  METHOD offset_instances.
    mo_env->insert_test_data( VALUE tt_cm(
      ( client = sy-mandt cm_h_id = c_cm2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '002' period_year = '2026' period_month = '08' )
      ( client = sy-mandt cm_h_id = c_cm3 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '003' period_year = '2026' period_month = '08' ) ) ).
    mo_env->insert_test_data( VALUE tt_opt(
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'A'
        op_uuid = c_a2 op_instance_num = '002' me_period_offset = '00' )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'A'
        op_uuid = c_a3 op_instance_num = '003' me_period_offset = '01' ) ) ).
    SELECT * FROM zi_reingcacmmeperiod
      WHERE CmHId = @c_cm2 OR CmHId = @c_cm3
      INTO TABLE @DATA(lt_cmp).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_cmp ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_cmp[ CmHId = c_cm2 ]-OpUuid exp = c_a2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_cmp[ CmHId = c_cm2 ]-MePeriodMonth exp = '08' ).
    cl_abap_unit_assert=>assert_equals( act = lt_cmp[ CmHId = c_cm3 ]-OpUuid exp = c_a3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_cmp[ CmHId = c_cm3 ]-MePeriodMonth exp = '07' ).
  ENDMETHOD.
ENDCLASS.

CLASS ltc_cm_lines DEFINITION FINAL INHERITING FROM lcl_cm_cds_fixture
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS pending_lines_instances FOR TESTING RAISING cx_static_check.
    METHODS calculated_other_instance FOR TESTING RAISING cx_static_check.
    METHODS defer_parent_instances FOR TESTING RAISING cx_static_check.
    METHODS delta_instances FOR TESTING RAISING cx_static_check.
    METHODS single_activation_available FOR TESTING RAISING cx_static_check.
    METHODS unresolved_not_pending FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_cm_lines IMPLEMENTATION.
  METHOD class_setup.
    mo_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_REINGCALINEALL' ).
  ENDMETHOD.
  METHOD class_teardown.
    mo_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    mo_env->clear_doubles( ).
  ENDMETHOD.
  METHOD pending_lines_instances.
    given_pending( ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B1' INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a2 ]-CmHId exp = c_cm2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a2 ]-BaseAmt exp = 1000 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a2 ]-BukrsRecv exp = '1000' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a3 ]-CmHId exp = c_cm3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a3 ]-BaseAmt exp = 2000 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a3 ]-BukrsRecv exp = '2000' ).
  ENDMETHOD.
  METHOD calculated_other_instance.
    given_pending( ).
    mo_env->insert_test_data( VALUE tt_ln(
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'A' OpUuid = c_a3 CmHId = c_cm2
        BukrsRecv = '1000' PeriodYear = '2026' PeriodMonth = '08' LineStatus = 'CONT' ) ) ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B1' AND OpUuid = @c_a2
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
  ENDMETHOD.
  METHOD defer_parent_instances.
    mo_env->insert_test_data( VALUE tt_ct( ( mandt = sy-mandt ct_uuid = c_ct ct_id = 'IC-0001' ) ) ).
    mo_env->insert_test_data( VALUE tt_mat( ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat ) ) ).
    mo_env->insert_test_data( VALUE tt_cat(
      ( mandt = sy-mandt op_type = 'D' active = abap_true parent_type = 'A' ) ) ).
    mo_env->insert_test_data( VALUE tt_opt(
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'A' op_uuid = c_a2 op_instance_num = '002' )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'A' op_uuid = c_a3 op_instance_num = '003' )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'D' op_uuid = c_d2
        op_instance_num = '002' parent_instance_id = c_a2 installments = '005' )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'D' op_uuid = c_d3
        op_instance_num = '003' parent_instance_id = c_a3 installments = '001' ) ) ).
    mo_env->insert_test_data( VALUE tt_la(
      ( mandt = sy-mandt calc_run_id = 'PARENT' line_num = 2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_uuid = c_a2 cm_h_id = c_cm2 bukrs_recv = '1000' line_status = 'CONT' net_amt = 1000 )
      ( mandt = sy-mandt calc_run_id = 'PARENT' line_num = 3 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_uuid = c_a3 cm_h_id = c_cm3 bukrs_recv = '1000' line_status = 'CONT' net_amt = 2000 ) ) ).
    mo_env->insert_test_data( VALUE tt_crn(
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'D' op_uuid = c_d2
        cron_year = '2026' cron_month = '08' cron_status = 'PL' percentage = 20 )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'D' op_uuid = c_d2
        cron_year = '2026' cron_month = '10' cron_status = 'PL' percentage = 20 )
      ( mandt = sy-mandt ct_uuid = c_ct mat_uuid = c_mat op_type = 'D' op_uuid = c_d3
        cron_year = '2026' cron_month = '08' cron_status = 'PL' percentage = 100 ) ) ).
    mo_env->insert_test_data( VALUE tt_cqs(
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'D' OpUuid = c_d2 CronYear = '2026' CronMonth = '08' CuotaNum = 3 )
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'D' OpUuid = c_d2 CronYear = '2026' CronMonth = '10' CuotaNum = 5 )
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'D' OpUuid = c_d3 CronYear = '2026' CronMonth = '08' CuotaNum = 1 ) ) ).
    mo_env->insert_test_data( VALUE tt_ba(
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'D' OpUuid = c_d2 CronYear = '2026'
        CronMonth = '08' BukrsRecv = '1000' BaseAmt = 200 CtCurrency = 'USD' )
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'D' OpUuid = c_d2 CronYear = '2026'
        CronMonth = '10' BukrsRecv = '1000' BaseAmt = 200 CtCurrency = 'USD' )
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'D' OpUuid = c_d3 CronYear = '2026'
        CronMonth = '08' BukrsRecv = '1000' BaseAmt = 2000 CtCurrency = 'USD' ) ) ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B2' AND PeriodMonth = '08' INTO TABLE @DATA(lt_aug).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_aug ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d2 ]-CmHId exp = c_cm2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d2 ]-OriginLineNum exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d2 ]-ParentNetAmt exp = 1000 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d2 ]-BaseAmt exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d2 ]-DeferCuotaNum exp = '003' ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d2 ]-DeferCuotaTotal exp = '005' ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d3 ]-CmHId exp = c_cm3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d3 ]-OriginLineNum exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d3 ]-ParentNetAmt exp = 2000 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d3 ]-BaseAmt exp = 2000 ).
    cl_abap_unit_assert=>assert_equals( act = lt_aug[ OpUuid = c_d3 ]-DeferCuotaTotal exp = '001' ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B2' AND PeriodMonth = '10' INTO TABLE @DATA(lt_oct).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_oct ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_oct[ 1 ]-OpUuid exp = c_d2 ).
  ENDMETHOD.
  METHOD delta_instances.
    given_pending( ).
    mo_env->insert_test_data( VALUE tt_cm(
      ( client = sy-mandt cm_h_id = c_d2 ct_uuid = c_ct mat_uuid = c_mat
        op_type = 'A' op_instance_num = '002' period_year = '2026' period_month = '08'
        cm_status = 'LIBD' load_seq = '002' delta_flag = abap_true amount = 300 currency = 'USD' ) ) ).
    mo_env->insert_test_data( VALUE tt_cmp(
      ( CmHId = c_d2 OpUuid = c_a2 MePeriodYear = '2026' MePeriodMonth = '08' )
      ( CmHId = c_d2 OpUuid = c_a3 MePeriodYear = '2026' MePeriodMonth = '07' ) ) ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B1' INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ CmHId = c_d2 ]-OpUuid exp = c_a2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ CmHId = c_d2 ]-BaseAmt exp = 300 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ CmHId = c_d2 ]-IsDelta exp = abap_true ).
  ENDMETHOD.
  METHOD single_activation_available.
    given_pending( iv_single_instance = '002' ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B1' INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-OpUuid exp = c_a2 ).
    " Repeat the inverse using the same option/ME doubles.
    mo_env->clear_doubles( ).
    given_pending( iv_single_instance = '003' ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B1' INTO TABLE @lt_rows.
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-OpUuid exp = c_a3 ).
  ENDMETHOD.
  METHOD unresolved_not_pending.
    given_pending( iv_unresolved = abap_true ).
    SELECT * FROM zi_reingcalineall WHERE RowType = 'B1' INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_initial( act = lt_rows ).
  ENDMETHOD.
ENDCLASS.

CLASS ltc_cm_groups DEFINITION FINAL INHERITING FROM lcl_cm_cds_fixture
  FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS pending_groups_instances FOR TESTING RAISING cx_static_check.
    METHODS cancelled_does_not_suppress FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltc_cm_groups IMPLEMENTATION.
  METHOD class_setup.
    mo_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_REINGCAACTGRPLINE' ).
  ENDMETHOD.
  METHOD class_teardown.
    mo_env->destroy( ).
  ENDMETHOD.
  METHOD setup.
    mo_env->clear_doubles( ).
  ENDMETHOD.
  METHOD pending_groups_instances.
    given_pending( ).
    mo_env->insert_test_data( VALUE tt_cme(
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'A' OpInstanceNum = '002'
        PeriodYear = '2026' PeriodMonth = '08' CmCount = 1 CmLibdCount = 1 )
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'A' OpInstanceNum = '003'
        PeriodYear = '2026' PeriodMonth = '08' CmCount = 1 CmLibdCount = 0 ) ) ).
    SELECT * FROM zi_reingcaactgrpline WHERE RowType = 'B1' INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a2 ]-CmHId exp = c_cm2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a3 ]-CmHId exp = c_cm3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a2 ]-CmEligFlag exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ OpUuid = c_a3 ]-CmEligFlag exp = 0 ).
  ENDMETHOD.
  METHOD cancelled_does_not_suppress.
    given_pending( ).
    mo_env->insert_test_data( VALUE tt_ln(
      ( CtUuid = c_ct MatUuid = c_mat OpType = 'A' OpUuid = c_a2 CmHId = c_cm2
        BukrsRecv = '1000' PeriodYear = '2026' PeriodMonth = '08' LineStatus = 'ANULD' ) ) ).
    SELECT * FROM zi_reingcaactgrpline WHERE RowType = 'B1' INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - Bugs 113/114 (Delta v2): preserve exact CM load identity.
CLASS ltc_exact_cm_orphan DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    TYPES tt_lines TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    TYPES tt_runs TYPE STANDARD TABLE OF zreing_ca_run_a WITH EMPTY KEY.
    TYPES tt_cm TYPE STANDARD TABLE OF zreing_cm_h_a WITH EMPTY KEY.
    TYPES tt_ops TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    CONSTANTS c_ct TYPE sysuuid_x16 VALUE '11300000000000000000000000000001'.
    CONSTANTS c_mat TYPE sysuuid_x16 VALUE '11300000000000000000000000000002'.
    CONSTANTS c_op TYPE sysuuid_x16 VALUE '11300000000000000000000000000003'.
    CONSTANTS c_original TYPE sysuuid_x16 VALUE '11300000000000000000000000000004'.
    CONSTANTS c_base TYPE sysuuid_x16 VALUE '11300000000000000000000000000005'.
    CONSTANTS c_delta TYPE sysuuid_x16 VALUE '11300000000000000000000000000006'.
    CONSTANTS c_run TYPE zreing_calc_run_id VALUE 'TST-ORPH-202601'.
    CLASS-DATA mo_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS original_with_other_loads FOR TESTING RAISING cx_static_check.
    METHODS replacement_is_not_original FOR TESTING RAISING cx_static_check.
    METHODS deleted_original_is_orphan FOR TESTING RAISING cx_static_check.
    METHODS deferred_does_not_need_cm FOR TESTING RAISING cx_static_check.
    METHODS given_line
      IMPORTING iv_original TYPE abap_bool DEFAULT abap_false
                iv_replacements TYPE abap_bool DEFAULT abap_false
                iv_loadable TYPE abap_bool DEFAULT abap_true
                iv_brazil_payload TYPE abap_bool DEFAULT abap_false.
    METHODS assert_orphan
      IMPORTING iv_expected TYPE abap_bool
                iv_brazil_payload TYPE abap_bool DEFAULT abap_false.
ENDCLASS.

CLASS ltc_exact_cm_orphan IMPLEMENTATION.
  METHOD class_setup.
    " Double direct dependencies, including the exact CM table reference.
    " Standard CDS dependencies remain view doubles; do not expand them
    " into protected SAP base tables. Match the existing CDS test pattern.
    mo_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_REINGCALINEALL' ).
  ENDMETHOD.

  METHOD class_teardown.
    IF mo_env IS BOUND.
      mo_env->destroy( ).
    ENDIF.
  ENDMETHOD.

  METHOD setup.
    mo_env->clear_doubles( ).
  ENDMETHOD.

  METHOD given_line.
    DATA(lv_op_type) = CONV zreing_op_type(
      COND #( WHEN iv_loadable = abap_true THEN 'P' ELSE 'D' ) ).
    mo_env->insert_test_data( VALUE tt_runs(
      ( mandt = sy-mandt calc_run_id = c_run fiscal_year = '2026' fiscal_period = '01' ) ) ).
    mo_env->insert_test_data( VALUE tt_ops(
      ( mandt = sy-mandt op_type = lv_op_type active = abap_true cm_loadable = iv_loadable ) ) ).
    mo_env->insert_test_data( VALUE tt_lines(
      ( mandt = sy-mandt calc_run_id = c_run line_num = '0000001'
        ct_uuid = c_ct ct_id = 'IC-TST113' mat_uuid = c_mat matnr = 'ICSRV45'
        op_uuid = c_op op_type = lv_op_type op_instance_num = '001'
        cm_h_id = c_original cm_load_seq = '001' bukrs_recv = 'DAB'
        line_status = 'SIM_OK' base_amt = 178000 ct_currency = 'USD'
        trans_currency = COND #( WHEN iv_brazil_payload = abap_true THEN 'BRL' ELSE 'USD' )
        net_trans_amt = COND #( WHEN iv_brazil_payload = abap_true THEN 890000 ELSE 178000 )
        exch_rate_1 = COND #( WHEN iv_brazil_payload = abap_true THEN 5 ELSE 1 )
        exch_rate_1_type = 'M'
        delta_seq = '00' ) ) ).

    DATA lt_cm TYPE tt_cm.
    IF iv_original = abap_true.
      APPEND VALUE #( client = sy-mandt cm_h_id = c_original
        ct_uuid = c_ct mat_uuid = c_mat op_type = lv_op_type op_instance_num = '001'
        period_year = '2026' period_month = '01' cm_status = 'LIBD'
        load_seq = '001' amount = 178000 currency = 'USD' ) TO lt_cm.
    ENDIF.
    IF iv_replacements = abap_true.
      APPEND VALUE #( client = sy-mandt cm_h_id = c_base
        ct_uuid = c_ct mat_uuid = c_mat op_type = lv_op_type op_instance_num = '001'
        period_year = '2026' period_month = '01' cm_status = 'LIBD'
        load_seq = '001' amount = 178000 currency = 'USD' ) TO lt_cm.
      APPEND VALUE #( client = sy-mandt cm_h_id = c_delta
        ct_uuid = c_ct mat_uuid = c_mat op_type = lv_op_type op_instance_num = '001'
        period_year = '2026' period_month = '01' cm_status = 'LIBD'
        load_seq = '001' delta_flag = abap_true amount = 2000 currency = 'USD' ) TO lt_cm.
    ENDIF.
    IF lt_cm IS NOT INITIAL.
      mo_env->insert_test_data( lt_cm ).
    ENDIF.
  ENDMETHOD.

  METHOD assert_orphan.
    SELECT CalcRunId, LineNum, RowType, LineStatus, CmHId, BaseAmt, IsOrphan,
           CtCurrency, TransCurrency, NetTransAmt, ExchRate1, ExchRate1Type
      FROM zi_reingcalineall
      WHERE CalcRunId = @c_run AND LineNum = '0000001' AND RowType = 'A'
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1
      msg = 'Several CM loads must not multiply a persisted calculation line' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-IsOrphan exp = iv_expected ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-CmHId exp = c_original ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-LineStatus exp = 'SIM_OK' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-BaseAmt exp = 178000 ).
    " Verify projection retention only; this fixture does not run the FX pipeline.
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-CtCurrency exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-TransCurrency
      exp = CONV zreing_trans_waers(
        COND #( WHEN iv_brazil_payload = abap_true THEN 'BRL' ELSE 'USD' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-NetTransAmt
      exp = CONV zreing_ca_net_trans_amt(
        COND #( WHEN iv_brazil_payload = abap_true THEN 890000 ELSE 178000 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-ExchRate1
      exp = CONV zreing_ca_exch_rate_1(
        COND #( WHEN iv_brazil_payload = abap_true THEN 5 ELSE 1 ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-ExchRate1Type exp = 'M' ).
  ENDMETHOD.

  METHOD original_with_other_loads.
    given_line( iv_original = abap_true iv_replacements = abap_true iv_brazil_payload = abap_true ).
    assert_orphan( iv_expected = abap_false iv_brazil_payload = abap_true ).
  ENDMETHOD.

  METHOD replacement_is_not_original.
    given_line( iv_replacements = abap_true ).
    assert_orphan( abap_true ).
  ENDMETHOD.

  METHOD deleted_original_is_orphan.
    given_line( ).
    assert_orphan( abap_true ).
  ENDMETHOD.

  METHOD deferred_does_not_need_cm.
    given_line( iv_loadable = abap_false ).
    assert_orphan( abap_false ).
  ENDMETHOD.
ENDCLASS.
