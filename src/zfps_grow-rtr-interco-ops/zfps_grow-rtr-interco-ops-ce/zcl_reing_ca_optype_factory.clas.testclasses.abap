*"* use this source file for your ABAP unit test classes
CLASS ltd_sources_factory DEFINITION FOR TESTING FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_reing_ca_sources.
ENDCLASS.

CLASS ltd_sources_factory IMPLEMENTATION.
  METHOD zif_reing_ca_sources~get_cm_amount.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_me_shares.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_ct_option.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_gl_tax_types.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_tx_rules.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_manual_exch_rate.
  ENDMETHOD.
  METHOD zif_reing_ca_sources~get_average_exch_rate.
  ENDMETHOD.
ENDCLASS.

CLASS ltc_optype_factory DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.

  PRIVATE SECTION.
    TYPES lty_op_type_c_tab TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_sources TYPE REF TO ltd_sources_factory.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS dispatches_cm_loadable_to_cm FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS dispatches_parent_a_to_defer FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS dispatches_parent_ant_to_an2 FOR TESTING RAISING zcx_reing_ca_calc_error.
    METHODS raises_on_missing_op_type FOR TESTING.
    METHODS raises_on_inconsistent_catalog FOR TESTING.

ENDCLASS.

CLASS ltc_optype_factory IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZREING_OP_TYPE_C' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    mo_sources = NEW ltd_sources_factory( ).
  ENDMETHOD.

  METHOD dispatches_cm_loadable_to_cm.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'TF1' active = abap_true cm_loadable = abap_true ) ) ).

    DATA(lo_optype) = zcl_reing_ca_optype_factory=>get_instance(
                         iv_op_type = 'TF1' io_sources = mo_sources is_context = VALUE #( ) ).

    cl_abap_unit_assert=>assert_bound( lo_optype ).
    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_optype )->get_relative_name( )
      exp = 'ZCL_REING_CA_OPTYPE_CM' ).
  ENDMETHOD.

  METHOD dispatches_parent_a_to_defer.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'TF2' active = abap_true cm_loadable = abap_false parent_type = 'A' ) ) ).

    DATA(lo_optype) = zcl_reing_ca_optype_factory=>get_instance(
                         iv_op_type = 'TF2' io_sources = mo_sources is_context = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_optype )->get_relative_name( )
      exp = 'ZCL_REING_CA_OPTYPE_DEFER' ).
  ENDMETHOD.

  METHOD dispatches_parent_ant_to_an2.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'TF3' active = abap_true cm_loadable = abap_false parent_type = 'ANT' ) ) ).

    DATA(lo_optype) = zcl_reing_ca_optype_factory=>get_instance(
                         iv_op_type = 'TF3' io_sources = mo_sources is_context = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals(
      act = cl_abap_typedescr=>describe_by_object_ref( lo_optype )->get_relative_name( )
      exp = 'ZCL_REING_CA_OPTYPE_AN2' ).
  ENDMETHOD.

  METHOD raises_on_missing_op_type.
    go_env->clear_doubles( ).
    TRY.
        zcl_reing_ca_optype_factory=>get_instance(
          iv_op_type = 'TF4' io_sources = mo_sources is_context = VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'expected zcx_reing_ca_calc_error (missing op_type)' ).
      CATCH zcx_reing_ca_calc_error.
        " expected
    ENDTRY.
  ENDMETHOD.

  METHOD raises_on_inconsistent_catalog.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'TF5' active = abap_true cm_loadable = abap_false parent_type = 'ZZZ' ) ) ).
    TRY.
        zcl_reing_ca_optype_factory=>get_instance(
          iv_op_type = 'TF5' io_sources = mo_sources is_context = VALUE #( ) ).
        cl_abap_unit_assert=>fail( 'expected zcx_reing_ca_calc_error (inconsistent customizing)' ).
      CATCH zcx_reing_ca_calc_error.
        " expected
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
