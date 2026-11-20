CLASS zcl_im_im_fi_int_sap01 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ex_fi_int_sap01.

  PRIVATE SECTION.
    CONSTANTS c_tr_indicator TYPE knb1-vzskz VALUE 'TR'.
ENDCLASS.


CLASS zcl_im_im_fi_int_sap01 IMPLEMENTATION.

  METHOD if_ex_fi_int_sap01~int_add_items.
    zcl_fi_int_luw_coordinator=>begin_execution( ).
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_modify_items.
    zcl_fi_int_luw_coordinator=>begin_execution( ).

    " Limitar los fallos de cálculo a los grupos que contienen partidas TR.
    DATA lt_tr_items TYPE fint_tt_intit_extf.

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_tr_item>)
         WHERE int_ind = c_tr_indicator.
      APPEND <ls_tr_item> TO lt_tr_items.
    ENDLOOP.

    IF lt_tr_items IS INITIAL.
      RETURN.
    ENDIF.

    " El handler trabaja sobre una copia. La BAdI solo devuelve INT_AMOUNT
    " y descarta el resultado si el handler cambia cantidad, orden o identidad.
    DATA lt_items_before     TYPE fint_tt_intit_extf.
    DATA lt_items_calculated TYPE fint_tt_intit_extf.
    lt_items_before     = ct_items.
    lt_items_calculated = ct_items.

    DATA lt_contracts TYPE zif_fi_int_tr_handler=>tt_contract_key.
    DATA lo_tr        TYPE REF TO zif_fi_int_tr_handler.
    DATA lv_tr_class  TYPE seoclsname VALUE
      'ZTR_C000123_AMORT_FINANC_VEIC'.

    DATA(lv_testrun) = xsdbool(
      VALUE #( it_frange[ fieldname = 'A_TESTL' ]-selopt_t[ 1 ]-low OPTIONAL )
        = abap_true ).

    TRY.
        CREATE OBJECT lo_tr TYPE (lv_tr_class).

        lo_tr->calculate_multa(
          IMPORTING
            et_contracts = lt_contracts
          CHANGING
            ct_items     = lt_items_calculated ).

      CATCH cx_root INTO DATA(lx_calculation).
        zcl_fi_int_luw_coordinator=>register_tr_calc_failure(
          it_items   = lt_tr_items
          iv_message = |No se pudo ejecutar calculate_multa: { lx_calculation->get_text( ) }| ).
        RETURN.
    ENDTRY.

    DATA(lv_same_structure) = xsdbool(
      lines( lt_items_before ) = lines( lt_items_calculated ) ).

    IF lv_same_structure = abap_true.
      LOOP AT lt_items_calculated ASSIGNING FIELD-SYMBOL(<ls_calculated>).
        DATA(lv_index) = sy-tabix.

        READ TABLE lt_items_before ASSIGNING FIELD-SYMBOL(<ls_before>)
          INDEX lv_index.

        IF sy-subrc <> 0.
          lv_same_structure = abap_false.
          EXIT.
        ENDIF.

        IF <ls_calculated>-bukrs  <> <ls_before>-bukrs
        OR <ls_calculated>-belnr  <> <ls_before>-belnr
        OR <ls_calculated>-gjahr  <> <ls_before>-gjahr
        OR <ls_calculated>-buzei  <> <ls_before>-buzei
        OR <ls_calculated>-array  <> <ls_before>-array
        OR <ls_calculated>-int_ind <> <ls_before>-int_ind.
          lv_same_structure = abap_false.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF lv_same_structure = abap_false.
      zcl_fi_int_luw_coordinator=>register_tr_calc_failure(
        it_items   = lt_tr_items
        iv_message = 'El handler TR cambió cantidad, orden o identidad de CT_ITEMS; se descarta su resultado.' ).
      RETURN.
    ENDIF.

    " Devolver únicamente INT_AMOUNT de las partidas TR, por posición.
    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_output>).
      IF <ls_output>-int_ind <> c_tr_indicator.
        CONTINUE.
      ENDIF.

      DATA(lv_output_index) = sy-tabix.
      READ TABLE lt_items_calculated ASSIGNING <ls_calculated>
        INDEX lv_output_index.

      IF sy-subrc = 0.
        <ls_output>-int_amount = <ls_calculated>-int_amount.
      ENDIF.
    ENDLOOP.

    " El coordinador asocia los contratos TR con su grupo FINT y conserva
    " A_TESTL para la fase persistente.
    zcl_fi_int_luw_coordinator=>register_tr_calculation(
      it_items     = ct_items
      it_contracts = lt_contracts
      iv_testrun   = lv_testrun ).

  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_post.
    " Se llama por grupo, antes de que FINT genere el documento y llegue
    " al COMMIT estándar. El coordinador no hace nada si el grupo no tiene TR.
    IF zcl_fi_int_luw_coordinator=>before_group_commit(
         is_ipf   = cs_ipf
         it_items = ct_items ) = abap_false.
      cd_post_status = 'ERROR'.
      RETURN.
    ENDIF.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~end_of_programm.
    " Detecta contratos TR que no llegaron al hook por grupo,
    " por ejemplo, los que terminaron en NOINT.
    zcl_fi_int_luw_coordinator=>report_unapplied_tr_contracts( ).

    " Entrega los avisos pendientes al log estándar de FINT.
    zcl_fi_int_luw_coordinator=>append_tr_warning_to_log(
      CHANGING
        ct_log = ct_log ).

    " Limpia el estado de la ejecución después de copiar los avisos.
    zcl_fi_int_luw_coordinator=>end_execution( ).
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~get_int_sign.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_sel_mod.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_show_buttons.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_list_01.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_list_02.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_list_03.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_group.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_print_options.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_print_results.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_formula.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_change_items.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_write_items.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_reverse.
    ed_reversed = abap_false.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~int_print_spool_closed.
  ENDMETHOD.


  METHOD if_ex_fi_int_sap01~sort_master_data.
  ENDMETHOD.

ENDCLASS.
