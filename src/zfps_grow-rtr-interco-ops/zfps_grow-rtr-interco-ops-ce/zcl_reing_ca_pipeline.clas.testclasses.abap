CLASS ltd_local_fx_pipe DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_reing_ca_local_fx.
    DATA calls TYPE i.
    DATA result TYPE zif_reing_ca_local_fx=>ty_result.
    DATA last_amount TYPE decfloat34.
    DATA last_date TYPE d.
ENDCLASS.

*"* use this source file for your ABAP unit test classes
* Rewritten 2026-07-14 (F2 test-classes closure sweep): the original F2
* test (never pasted) targeted a design where GL tax types / currency
* master data were only reachable through ZIF_REING_CA_SOURCES mocks.
* Iterations #5/#7 (real activation) migrated several of those internal
* SELECTs to real released CDS views (I_CompanyCode, I_Currency) and to
* ZREING_TX_TYPE_C, pre-cached once in execute() before the LOOP AT
* it_scope (NonLocal DBREAD ATC fixes) -- the class is no longer "100%
* mockable via ZIF_REING_CA_SOURCES alone". This version:
*  - Doubles ZREING_OP_TYPE_C (factory dispatch) and ZREING_CA_LINE_A
*    (PEND scope + parent FX-H lookup) via cl_osql_test_environment.
*  - Does NOT double ZREING_TX_TYPE_C -- uses ZCL_REING_CA_PIPELINE's own
*    INJECT_TX_CACHE (already built into the class for exactly this,
*    see its ABAP Doc: OSQL test doubles have a known bug with CHAR
*    comparisons on that table) to populate MT_TX_TYPE_CACHE directly,
*    bypassing the real SELECT inside EXECUTE(). INJECT_TX_CACHE expects
*    a table of STRUCTURES with components TAX_TYPE/GROSS_UP_DEFAULT
*    (it does ASSIGN COMPONENT BY NAME) -- ty_tx_cache_row/tab below,
*    NOT the scalar ty_tax_type_t (that one is only for GET_GL_TAX_TYPES'
*    return, a different, unrelated type despite the similar name).
*  - DOES double I_CompanyCode/I_Currency, so BUKRS_RECV=1000's
*    country/local currency/decimals are deterministic instead of
*    depending on whatever master data happens to exist in this system.
CLASS ltd_sources_pipe DEFINITION FOR TESTING FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_sources.

    " V001 (CC) - CA-109: explicit operation/load identity in the double.
    DATA ms_option TYPE zreing_ct2_opt_a.
    DATA mv_cm_instance TYPE zreing_op_instance_num VALUE '001'.
    DATA mv_reject_cm TYPE abap_bool.
    DATA mv_cm_amount    TYPE zreing_cm_h_a-amount.
    DATA mv_raise_me     TYPE abap_bool.
    DATA mt_me_shares    TYPE zif_reing_ca_types=>ty_me_item_t.
    DATA mv_ct_waers     TYPE waers.
    DATA mt_tax_types    TYPE zif_reing_ca_types=>ty_tax_type_t.
    DATA mt_rules_gu     TYPE zif_reing_ca_types=>ty_tx_rule_t.
    DATA mt_rules_nongu  TYPE zif_reing_ca_types=>ty_tx_rule_t.
    DATA mv_avg_rate     TYPE zreing_ca_line_a-exch_rate.
    " V001 (CC) - Integral execution fixture; existing defaults are preserved.
    DATA mv_manual_rate TYPE zreing_ca_line_a-exch_rate.
    DATA mv_average_calls TYPE i.
    DATA mv_average_from TYPE waers.
    DATA mv_average_to TYPE waers.
    DATA mv_average_date TYPE d.
    DATA ms_ct_identity  TYPE zif_reing_ca_types=>ty_ct_identity.

    " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): cobertura de delta.
    " mt_cont_pc_baseline_NNNN: una tabla por receptora en vez de un unico
    " campo -- ty_line_pc_t (ZREING_CA_LPC_A) no trae bukrs_recv propio (el
    " metodo real filtra por linea, no por ese campo), asi que el double
    " despacha por IV_BUKRS_RECV contra tablas separadas en vez de inventar
    " un campo que no existe en la estructura real.
    DATA mv_cm_delta_flag         TYPE abap_bool.
    DATA mv_permite_delta         TYPE abap_bool.
    DATA mt_cont_baseline         TYPE zif_reing_ca_types=>ty_line_t.
    DATA mt_cont_pc_baseline_1000 TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_cont_pc_baseline_2000 TYPE zif_reing_ca_types=>ty_line_pc_t.
    DATA mt_cont_pc_baseline_3000 TYPE zif_reing_ca_types=>ty_line_pc_t.
    " End Change ID V003 (04.08.2026 | EXT_GONZALCA)

ENDCLASS.

CLASS ltd_sources_pipe IMPLEMENTATION.

  METHOD zif_reing_ca_sources~get_cm_amount.
    IF mv_cm_amount IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = 'no CM (test double)'.
    ENDIF.
    rs_cm-amount     = mv_cm_amount.
    IF mv_reject_cm = abap_true.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error
        EXPORTING iv_message = 'CM context/instance rejected by Sources'.
    ENDIF.
    rs_cm-delta_flag = mv_cm_delta_flag.
    rs_cm-cm_h_id = iv_cm_h_id.
    rs_cm-op_instance_num = mv_cm_instance.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_ct_identity.
    IF ms_ct_identity IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = 'no CT identity (test double)'.
    ENDIF.
    rs_identity = ms_ct_identity.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_me_shares.
    IF mv_raise_me = abap_true OR mt_me_shares IS INITIAL.
      RAISE EXCEPTION TYPE zcx_reing_ca_calc_error EXPORTING iv_message = 'no ME shares (test double)'.
    ENDIF.
    rt_items = mt_me_shares.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_ct_option.
    rs_opt = ms_option.
    rs_opt-op_uuid = iv_op_uuid.
    IF rs_opt-op_instance_num IS INITIAL.
      rs_opt-op_instance_num = '001'.
    ENDIF.
    rs_opt-waers = mv_ct_waers.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_gl_tax_types.
    rt_tax_types = mt_tax_types.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_tx_rules.
    rt_rules = COND #( WHEN iv_gross_up = abap_true THEN mt_rules_gu ELSE mt_rules_nongu ).
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_manual_exch_rate.
    rv_rate = mv_manual_rate.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_average_exch_rate.
    mv_average_calls = mv_average_calls + 1.
    mv_average_from = iv_from_currency.
    mv_average_to = iv_to_currency.
    mv_average_date = iv_date.
    rv_rate = mv_avg_rate.
  ENDMETHOD.

  " Begin Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-06/07/08.
  " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): implementacion real
  " de los 4 stubs -- ver path_a_delta_same_receptor y
  " path_a_delta_reseq_reversal, que ahora si ejercitan IS_DELTA=X.
  METHOD zif_reing_ca_sources~get_op_type_permite_delta.
    rv_permite_delta = mv_permite_delta.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_cont_baseline.
    rt_lines = mt_cont_baseline.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_cont_line_pc_baseline.
    CASE iv_bukrs_recv.
      WHEN '1000'. rt_pc = mt_cont_pc_baseline_1000.
      WHEN '2000'. rt_pc = mt_cont_pc_baseline_2000.
      WHEN '3000'. rt_pc = mt_cont_pc_baseline_3000.
    ENDCASE.
  ENDMETHOD.

  METHOD zif_reing_ca_sources~get_cm_recv_filter.
    " Tabla vacia = sin restriccion (default) -- BR-CA-44 no es objeto de
    " esta cobertura de delta.
  ENDMETHOD.
  " End Change ID V003 (04.08.2026 | EXT_GONZALCA)
  " End Change ID V002 (03.08.2026 | EXT_GONZALCA)

ENDCLASS.


CLASS ltcl_pipeline DEFINITION FOR TESTING RISK LEVEL HARMLESS DURATION SHORT FINAL.

  PRIVATE SECTION.
    TYPES lty_op_type_c_tab   TYPE STANDARD TABLE OF zreing_op_type_c WITH EMPTY KEY.
    TYPES lty_line_a_tab      TYPE STANDARD TABLE OF zreing_ca_line_a WITH EMPTY KEY.
    TYPES lty_companycode_tab TYPE STANDARD TABLE OF i_companycode WITH EMPTY KEY.
    TYPES lty_currency_tab    TYPE STANDARD TABLE OF i_currency WITH EMPTY KEY.

    " Mirrors ZCL_REING_CA_PIPELINE's private ty_tx_type_cache (not
    " directly accessible -- no LOCAL FRIENDS declared for this class).
    " INJECT_TX_CACHE reads components by name (ASSIGN COMPONENT), so any
    " structure with these 2 field names works, not just the real one.
    TYPES: BEGIN OF ty_tx_cache_row,
             tax_type         TYPE zreing_tx_type_c-tax_type,
             gross_up_default TYPE zreing_tx_type_c-gross_up_default,
           END OF ty_tx_cache_row.
    TYPES ty_tx_cache_tab TYPE STANDARD TABLE OF ty_tx_cache_row WITH EMPTY KEY.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    DATA mo_sources TYPE REF TO ltd_sources_pipe.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS cm_instance_mismatch FOR TESTING RAISING cx_static_check.
    METHODS cm_instance_matches FOR TESTING RAISING cx_static_check.
    METHODS cm_source_rejects FOR TESTING RAISING cx_static_check.
    METHODS cm_instance_eba_on FOR TESTING RAISING cx_static_check.
    METHODS cm_wrong_option_group FOR TESTING RAISING cx_static_check.
    METHODS run_cm_instance
      IMPORTING iv_cm_instance TYPE zreing_op_instance_num
                iv_wrong_group TYPE abap_bool DEFAULT abap_false
                iv_reject_cm TYPE abap_bool DEFAULT abap_false
                iv_eba_on TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_result) TYPE zif_reing_ca_types=>ty_pipeline_result.
    METHODS path_a_full_happy_path FOR TESTING RAISING cx_static_check.
    METHODS path_b_defer_fx_type_h FOR TESTING RAISING cx_static_check.
    METHODS one_bad_group_no_abort FOR TESTING RAISING cx_static_check.
    " Begin Change ID V003 (04.08.2026 | EXT_GONZALCA): cobertura de delta
    " (step_delta + rama IS_DELTA de step_pc_split), sin ejercitar hasta hoy.
    METHODS path_a_delta_same_receptor  FOR TESTING RAISING cx_static_check.
    METHODS path_a_delta_reseq_reversal FOR TESTING RAISING cx_static_check.
    " End Change ID V003 (04.08.2026 | EXT_GONZALCA)
    " Begin Change ID V004 (03.09.2026 | EXT_GONZALCA): regresion del overflow
    " de RATE_PCT en step_fx -- ningun escenario previo pasaba de tasa 3,00.
    METHODS fx_rate_above_1000 FOR TESTING RAISING cx_static_check.
    " End Change ID V004 (03.09.2026 | EXT_GONZALCA)
    " Begin Change ID V013 (16.09.2026 | EXT_GONZALCA): regresion del overflow
    " de SHARE_ABS en la rama delta de step_pc_split -- los dos escenarios de
    " delta de arriba trabajan con un delta de 200,00 y nunca lo alcanzaron.
    METHODS delta_pc_share_above_1000 FOR TESTING RAISING cx_static_check.
    " End Change ID V013 (16.09.2026 | EXT_GONZALCA)

    " Begin Insert V019 (17.09.2026 | EXT_GONZALCA): bug #78 -- los campos
    " que llena el fix (STEP_DESC / TX_RULE_ID / RATE_DESC / SOURCE_TABLE)
    " no tenian NINGUNA cobertura: la suite pasaba igual quitandolos de
    " todos los record_step. path_c cubre la mitad AN2 de la discriminacion
    " B2 de ET SS7.4 (la otra mitad se asserta en path_b_defer_fx_type_h) y
    " gross_up_one_rule cubre el caso de UNA regla ganadora, donde
    " TX_RULE_ID si se llena (path_a_full_happy_path cubre el de N>1).
    METHODS path_c_an2_base_ant_desc      FOR TESTING RAISING cx_static_check.
    METHODS gross_up_one_rule_tx_rule_id  FOR TESTING RAISING cx_static_check.
    " End Insert V019 (17.09.2026 | EXT_GONZALCA)

    " Begin Insert V020 (18.09.2026 | EXT_GONZALCA): regresion de fixes-042 --
    " BR-CA-05 retirada. Ningun test cubria la inversion de signo de la nota
    " de credito, en ningun sentido: se podia reintroducir el "* -1" sin que
    " fallara nada. Este caso FIJA el comportamiento nuevo.
    METHODS nc_keeps_sign_no_inversion FOR TESTING RAISING cx_static_check.
    METHODS eba_off_uses_legacy FOR TESTING RAISING cx_static_check.
    METHODS non_eba_on_uses_legacy FOR TESTING RAISING cx_static_check.
    METHODS eba_on_requires_v2 FOR TESTING RAISING cx_static_check.

    " V001 (CC) - CA-05 (EBA Brasil): deterministic FX selection and CDS cache.
    TYPES tt_fx_cds TYPE STANDARD TABLE OF zi_reingfxrule WITH EMPTY KEY.
    METHODS new_fx_cut RETURNING VALUE(ro_cut) TYPE REF TO zcl_reing_ca_pipeline.
    METHODS pick_fx_rule
      IMPORTING io_cut TYPE REF TO zcl_reing_ca_pipeline
                it_rules TYPE zcl_reing_ca_pipeline=>tt_fx_rules
      RETURNING VALUE(rs_result) TYPE zcl_reing_ca_pipeline=>ty_fx_rule_result
      RAISING zcx_reing_ca_calc_error.
    METHODS fx_weight_order FOR TESTING RAISING cx_static_check.
    METHODS fx_discard_criteria FOR TESTING RAISING cx_static_check.
    METHODS fx_wildcard_zero FOR TESTING RAISING cx_static_check.
    METHODS fx_tie_raises FOR TESTING RAISING cx_static_check.
    METHODS fx_lower_tie FOR TESTING RAISING cx_static_check.
    METHODS fx_order_stable FOR TESTING RAISING cx_static_check.
    METHODS fx_empty_fallback FOR TESTING RAISING cx_static_check.
    METHODS fx_all_discard_fallback FOR TESTING RAISING cx_static_check.
    METHODS fx_modes_preserve FOR TESTING RAISING cx_static_check.
    METHODS fx_read_cds_mapping FOR TESTING RAISING cx_static_check.
    METHODS fx_read_provider_filter FOR TESTING RAISING cx_static_check.
    METHODS fx_off_and_empty_scope FOR TESTING RAISING cx_static_check.
    METHODS fx_refresh_empty FOR TESTING RAISING cx_static_check.
    " End Insert V020 (18.09.2026 | EXT_GONZALCA)


    " V001 (CC) - Integral execution tests with isolated contract and FX data.
    TYPES tt_exec_header TYPE STANDARD TABLE OF zreing_ct2_a WITH EMPTY KEY.
    TYPES tt_exec_option TYPE STANDARD TABLE OF zreing_ct2_opt_a WITH EMPTY KEY.
    TYPES tt_exec_manual TYPE STANDARD TABLE OF zreing_ct_o_r_a WITH EMPTY KEY.
    TYPES ty_exec_mode TYPE c LENGTH 5.
    TYPES tt_exec_lines TYPE HASHED TABLE OF zreing_ca_line_a
      WITH UNIQUE KEY calc_run_id line_num.
    TYPES tt_exec_pc TYPE HASHED TABLE OF zreing_ca_lpc_a
      WITH UNIQUE KEY calc_run_id line_num pc_seq.
    TYPES tt_exec_steps TYPE HASHED TABLE OF zreing_ca_step_a
      WITH UNIQUE KEY calc_run_id line_num step_num seq.
    CONSTANTS: co_exec_ct TYPE sysuuid_x16 VALUE '00000000000000000000000000CA0010',
               co_exec_mat TYPE sysuuid_x16 VALUE '00000000000000000000000000CA0020',
               co_exec_other_ct TYPE sysuuid_x16 VALUE '00000000000000000000000000CA0050',
               co_exec_op TYPE sysuuid_x16 VALUE '00000000000000000000000000CA0030',
               co_exec_other_op TYPE sysuuid_x16 VALUE '00000000000000000000000000CA0040',
               co_exec_run TYPE zreing_ca_line_a-calc_run_id VALUE 'INTEGRAL_FX',
               co_exec_parent TYPE zreing_ca_line_a-calc_run_id VALUE 'INTEGRAL_PARENT',
               co_exec_cm TYPE zreing_ca_line_a-op_type VALUE 'XFC',
               co_exec_defer TYPE zreing_ca_line_a-op_type VALUE 'XFD',
               co_exec_recv TYPE bukrs VALUE 'EBC',
               co_exec_non_eba TYPE bukrs VALUE 'MUR',
               co_exec_instance TYPE zreing_op_instance_num VALUE '001',
               co_exec_other_instance TYPE zreing_op_instance_num VALUE '002',
               co_exec_local TYPE ty_exec_mode VALUE 'LOCAL',
               co_exec_fixed TYPE ty_exec_mode VALUE 'FIXED',
               co_exec_same TYPE ty_exec_mode VALUE 'SAME'.
    DATA mo_exec_cut TYPE REF TO zcl_reing_ca_pipeline.
    DATA mo_exec_local TYPE REF TO ltd_local_fx_pipe.
    DATA mt_exec_scope TYPE zif_reing_ca_types=>ty_group_key_t.
    METHODS prepare_exec
      IMPORTING iv_prest TYPE bukrs DEFAULT zif_reing_ca_c=>br_isolation-eba_bukrs
                iv_local TYPE waers DEFAULT 'BRL'
                iv_type TYPE zreing_ct2_opt_a-exch_rate_type DEFAULT zif_reing_ca_c=>fx_contract_rate_type-manual
                iv_on TYPE abap_bool DEFAULT abap_true
                iv_tax TYPE abap_bool DEFAULT abap_true
                iv_mode TYPE ty_exec_mode DEFAULT co_exec_local.
    METHODS add_exec_group IMPORTING iv_manual TYPE abap_bool DEFAULT abap_true.
    METHODS assert_exec_chain
      IMPORTING is_result TYPE zif_reing_ca_types=>ty_pipeline_result
                iv_net TYPE zreing_ca_calc_amt
                iv_bruto TYPE zreing_ca_calc_amt
                iv_tax TYPE abap_bool DEFAULT abap_true.
    METHODS assert_exec_keys IMPORTING is_result TYPE zif_reing_ca_types=>ty_pipeline_result.
    METHODS assert_exec_error IMPORTING is_result TYPE zif_reing_ca_types=>ty_pipeline_result.
    METHODS assert_exec_legacy
      IMPORTING iv_type TYPE zreing_ct2_opt_a-exch_rate_type.
    METHODS exec_off_legacy_mph FOR TESTING RAISING cx_static_check.
    METHODS exec_on_non_eba FOR TESTING RAISING cx_static_check.
    METHODS exec_manual_trans_chain FOR TESTING RAISING cx_static_check.
    METHODS exec_average_trans_chain FOR TESTING RAISING cx_static_check.
    METHODS exec_parent_trans_chain FOR TESTING RAISING cx_static_check.
    METHODS exec_fallback_same_chain FOR TESTING RAISING cx_static_check.
    METHODS exec_tie_blocks_line FOR TESTING RAISING cx_static_check.
    METHODS exec_preview_missing_chain FOR TESTING RAISING cx_static_check.
    METHODS exec_scope_keys_stay_unique FOR TESTING RAISING cx_static_check.
    METHODS exec_bad_group_keeps_next FOR TESTING RAISING cx_static_check.
    METHODS exec_reloads_quotes FOR TESTING RAISING cx_static_check.
    METHODS exec_exact_manual_scope FOR TESTING RAISING cx_static_check.
    METHODS exec_future_primary_rejected FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_pipeline IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #(
        ( 'ZREING_OP_TYPE_C' ) ( 'ZREING_CA_LINE_A' )
        ( 'I_COMPANYCODE' ) ( 'I_CURRENCY' ) ( 'ZI_REINGFXRULE' )
        ( 'ZREING_CT2_A' ) ( 'ZREING_CT2_OPT_A' ) ( 'ZREING_CT_O_R_A' ) ) ).
  ENDMETHOD.

  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    TEST-INJECTION eba_pipeline_switch.
      mv_eba_off = abap_true.
    END-TEST-INJECTION.
    go_env->clear_doubles( ).
    mo_sources = NEW ltd_sources_pipe( ).
  ENDMETHOD.

  METHOD teardown.
    go_env->clear_doubles( ).
  ENDMETHOD.

  METHOD path_a_full_happy_path.
    " op_type 'PA1' (cm_loadable), 1 receptor with 100% share, two GU taxes
    " (15% + 5%) and two non-GU taxes (10% + 5%), FX type P at rate 2 -- every
    " figure below is exact by construction, no rounding ambiguity.
    " Begin Mod V009 (15.09.2026 | EXT_GONZALCA)
    " The receiving company code moves from '1000' to '2000'. It used to be
    " '1000', the SAME code as bukrs_prest, which made this an INTRA-COMPANY
    " line by accident -- the fixture reused one company code out of
    " convenience, not to test that scenario. Since V009 an intra-company line
    " carries no tax at all (see the note in find_best_rule, bug #69), so the
    " case silently stopped exercising gross-up and tax: bruto came out at
    " 1000.00 instead of 1250.00. The figures asserted below are unchanged --
    " '2000' is given the same country and local currency as '1000' -- so this
    " keeps testing exactly what it was written to test.
    " Original fixture kept for reference:
    "    ( companycode = '1000' country = 'AR' currency = 'ARS' )
    "    mo_sources->mt_me_shares = VALUE #( ( bukrs = '1000' ... ) ).
    " End Mod V009 (15.09.2026 | EXT_GONZALCA)
    " Begin Mod V010 (17.09.2026 | EXT_GONZALCA)
    " El fixture pasa de 1 impuesto GU + 1 non-GU a 2 + 2, para cubrir de una
    " sola pasada los DOS sentidos del bug que reporto Rochelle el 17.09.2026
    " (el ruteo se hacia por GROSS_UP_DEFAULT del catalogo en vez de por la
    " marca GROSS_UP de la regla):
    "   GU1: regla CON X, tipo con default X      -> caso que ya funcionaba
    "   GU2: regla CON X, tipo con default VACIO  -> antes el gross-up se
    "                                                ignoraba en silencio
    "   TX1: regla SIN X, tipo con default vacio  -> caso que ya funcionaba
    "   TX2: regla SIN X, tipo con default X      -> el bug de Rochelle
    "                                                (TAX_AMT quedaba en 0)
    " Las tasas GU se eligieron para que sumen el mismo 20% de antes, de modo
    " que BRUTO_AMT y GROSS_UP_AMT no cambien y la aritmetica siga exacta.
    " Con el codigo anterior a V010 este fixture daria BRUTO = 1176,47 (solo
    " GU1 pasaba el filtro) y TAX = 117,65 (solo TX1): el test es regresion
    " directa del bug.
    " Los importes de impuesto y el neto SI cambian respecto de la version
    " anterior del test, porque los impuestos de gross-up ahora tambien se
    " registran como pasos TAX y restan del neto (definicion de Rochelle +
    " mockup app_ca_ui5_v25.html).
    " Begin Mod V021 (18.09.2026 | EXT_GONZALCA)
    " Bug #83. This fixture is ALREADY the exact shape the bug needs -- gross-up
    " taxes AND non-gross-up taxes on the same line -- so it is the natural
    " regression for the new NET rule and no separate test case is added.
    " Only two expected values move (see the assertions below): NET_AMT and, as
    " its consequence, NET_LOCAL_AMT. TAX_AMT deliberately does NOT move.
    " End Mod V021 (18.09.2026 | EXT_GONZALCA)
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PA1' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'ARS' )
      ( companycode = '2000' country = 'AR' currency = 'ARS' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 )
      ( currency = 'ARS' decimals = 2 ) ) ).

    mo_sources->mv_cm_amount   = '1000.00'.
    mo_sources->mt_me_shares   = VALUE #( ( bukrs = '2000' share_pct = '100.000000' prctr = 'PC01' ) ).
    mo_sources->mv_ct_waers    = 'USD'.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'CT0000001' lifnr = '0000005000'
                                           bukrs_prest = '1000' matnr = 'MAT001' ).
    mo_sources->mt_tax_types   = VALUE #( ( 'GU1' ) ( 'GU2' ) ( 'TX1' ) ( 'TX2' ) ).
    mo_sources->mt_rules_gu    = VALUE #(
      ( tx_rule_id = 'R_GU1' tax_type = 'GU1' rate = '15.000000'
        valid_from = '20260101' valid_to = '20261231' )
      ( tx_rule_id = 'R_GU2' tax_type = 'GU2' rate = '5.000000'
        valid_from = '20260101' valid_to = '20261231' ) ).
    mo_sources->mt_rules_nongu = VALUE #(
      ( tx_rule_id = 'R_TX1' tax_type = 'TX1' rate = '10.000000'
        valid_from = '20260101' valid_to = '20261231' )
      ( tx_rule_id = 'R_TX2' tax_type = 'TX2' rate = '5.000000'
        valid_from = '20260101' valid_to = '20261231' ) ).
    mo_sources->mv_avg_rate    = '2.00000'.

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0001' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    " Bypass the real ZREING_TX_TYPE_C SELECT inside execute() -- see
    " class-level ABAP Doc note (OSQL test double CHAR-comparison bug).
    " V010: GROSS_UP_DEFAULT a proposito CRUZADO respecto de la marca de cada
    " regla (ver la nota de arriba). Desde V010 el catalogo no rutea nada --
    " solo tiene que existir la entrada, porque implica "tipo activo".
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab(
      ( tax_type = 'GU1' gross_up_default = abap_true )
      ( tax_type = 'GU2' gross_up_default = abap_false )
      ( tax_type = 'TX1' gross_up_default = abap_false )
      ( tax_type = 'TX2' gross_up_default = abap_true ) ) ).
    " End Mod V010 (17.09.2026 | EXT_GONZALCA)

    " CT_UUID/MAT_UUID/OP_UUID are SYSUUID_X16 (RAW16). A '...'X postfix
    " hex literal is only valid ABAP syntax in a classical DATA/CONSTANTS
    " ... VALUE statement -- it is NOT accepted as an inline operand
    " inside a VALUE #(...) constructor (confirmed empirically with an
    " isolated $TMP test: SAP rejects it at activation, "must be a space
    " ... after '...'", even though it is 32 valid hex digits). Declare
    " local x-typed constants first and reference them instead. The
    " trailing digits are just a readable tag to keep each test group
    " identity distinct.
    CONSTANTS lc_ct_uuid TYPE zreing_ca_line_a-ct_uuid VALUE '00000000000000000000000000000001'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000011'.
    CONSTANTS lc_op_uuid TYPE zreing_ca_line_a-op_uuid VALUE '00000000000000000000000000000021'.

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0001' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PA1' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].

    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-calc_amt      exp = '1000.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-bruto_amt     exp = '1250.00' ).   " 1000 / (1-0.20)
    cl_abap_unit_assert=>assert_equals( act = ls_line-gross_up_amt  exp = '250.00' ).
    " V010: TAX_AMT incluye los impuestos de gross-up.
    " GU1 1250*15% = 187,50 + GU2 1250*5% = 62,50 (= los 250 del gross-up)
    " + TX1 1250*10% = 125,00 + TX2 1250*5% = 62,50.
    " Begin Mod V021 (18.09.2026 | EXT_GONZALCA)
    " TAX_AMT stays at 437,50: it is the REAL total of taxes and that is what
    " the "Total Impuestos" column means. Only the NET changes.
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-tax_amt exp = '437.50'
      msg = 'TAX_AMT sigue siendo el total real: GU (250,00) + non-GU (187,50)' ).
    " NET_AMT deducts ONLY the gross-up taxes (GU1 187,50 + GU2 62,50 = 250,00).
    " TX1 and TX2 no longer reduce it. Previous expectation was 812,50
    " (1250 - 437,50), which is the defect Rochelle reported on 18.09.2026.
    " Original assertions, for the record:
    "    cl_abap_unit_assert=>assert_equals( act = ls_line-net_amt       exp = '812.50' ).
    "    cl_abap_unit_assert=>assert_equals( act = ls_line-net_local_amt exp = '1625.00' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-net_amt exp = '1000.00'
      msg = 'El neto solo deduce los impuestos con GROSS_UP = X (1250 - 250)' ).
    " With a pure gross-up the receiver collects the CALC_AMT in full. Asserted
    " against the field and not against a literal so the relationship itself is
    " what is pinned down, which is the whole point of the rule.
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-net_amt exp = ls_line-calc_amt
      msg = 'Proposito del gross-up: el receptor cobra integro el CALC_AMT' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-exch_rate     exp = '2.00000' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-net_local_amt exp = '2000.00'
      msg = '1000,00 x 2 -- arrastra el neto nuevo' ).
    " End Mod V021 (18.09.2026 | EXT_GONZALCA)
    cl_abap_unit_assert=>assert_equals( act = ls_line-ct_id       exp = 'CT0000001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-matnr       exp = 'MAT001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-lifnr       exp = '0000005000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-bukrs_prest exp = '1000' ).
    " V009: guard against the fixture drifting back to an intra-company setup,
    " which would make the tax assertions above vacuously true again.
    cl_abap_unit_assert=>assert_equals( act = ls_line-bukrs_recv exp = '2000' ).

    " Begin Insert V010 (17.09.2026 | EXT_GONZALCA)
    " Los cuatro impuestos dejan su propio paso TAX con su TAX_TYPE: es lo que
    " CONTAB lee para las cuentas de retencion (Regla C de
    " ET-REING-CONTAB-001 SS8.7), asi que el desglose es parte del contrato,
    " no solo cosmetica de la Secuencia de Calculo.
    DATA(lv_tax_steps) = REDUCE i( INIT n = 0 FOR ls_st IN rs_result-steps
                                   WHERE ( step_category = zif_reing_ca_c=>step_category-tax )
                                   NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_tax_steps exp = 4
      msg = 'Cada impuesto (GU y non-GU) deja su propio paso TAX' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'GU1' ]-output_amt
      exp = '187.50' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'GU2' ]-output_amt
      exp = '62.50'
      msg = 'Regla con X sobre tipo con default vacio: el gross-up se aplica' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'TX2' ]-output_amt
      exp = '62.50'
      msg = 'Regla sin X sobre tipo con default X: el impuesto se calcula (bug 17.09.2026)' ).
    " End Insert V010 (17.09.2026 | EXT_GONZALCA)

    " Begin Insert V021 (18.09.2026 | EXT_GONZALCA)
    " Bug #83, the other half of the rule: the non-gross-up taxes ARE still
    " calculated and DO still leave their TAX step -- they simply stop reducing
    " the net. Without this, a fix that just dropped them would pass too.
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'TX1' ]-output_amt
      exp = '125.00'
      msg = 'El impuesto non-GU se sigue calculando, solo no resta del neto' ).
    " The NET step of the calculation memory has to carry the same figure the
    " line does: it is what the "Secuencia de Calculo" tab shows, and the
    " screenshot Rochelle reported was precisely that row.
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-net ]-output_amt
      exp = '1000.00'
      msg = 'El paso NET de la memoria de calculo refleja el neto nuevo' ).
    " End Insert V021 (18.09.2026 | EXT_GONZALCA)

    " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
    " Bug #78: VALIDATE no llevaba texto ni tabla de origen en ningun path
    " (ET SS7.4), y TX_RULE_ID no se escribia nunca -- 0 de 629 filas en
    " TS4-400 -- porque record_step no tenia el parametro. El paso
    " GROSS_UP agregado queda con TX_RULE_ID VACIO a proposito: aca ganan
    " DOS reglas GU y el campo es CHAR 20, no admite lista (decision del
    " usuario, 17.09.2026); el caso de una sola regla lo cubre
    " gross_up_one_rule_tx_rule_id.
    DATA(ls_val_step) = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-validate ].
    cl_abap_unit_assert=>assert_equals( act = ls_val_step-step_desc
                                        exp = 'Base CM: 1000.00 USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_val_step-source_table
                                        exp = 'ZREING_CM_H_A' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'GU1' ]-tx_rule_id
      exp = 'R_GU1'
      msg = 'El paso TAX de una regla GU lleva su TX_RULE_ID' ).
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'TX1' ]-tx_rule_id
      exp = 'R_TX1'
      msg = 'El paso TAX de una regla non-GU lleva su TX_RULE_ID' ).
    cl_abap_unit_assert=>assert_not_initial(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-tax
                             tax_type      = 'TX1' ]-rate_desc
      msg = 'RATE_DESC del paso TAX (ET SS4.4)' ).
    cl_abap_unit_assert=>assert_initial(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-gross_up ]-tx_rule_id
      msg = 'GROSS_UP agregado con 2 reglas: TX_RULE_ID queda vacio' ).
    " End Insert V019 (17.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

METHOD path_b_defer_fx_type_h.
    " D (parent_type 'A') -- a PEND child line already exists (created
    " ahead of time by the CT parent-child mechanism), and its CONT
    " parent already carries an exch_rate to inherit (FX type H).
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PB1' active = abap_true cm_loadable = abap_false parent_type = 'A' ) ) ).

    " See path_a_full_happy_path's note: CT_UUID/MAT_UUID/OP_UUID need
    " local x-typed CONSTANTS, not an inline '...'X literal (SAP rejects
    " the postfix hex literal as an operand inside VALUE #(...)).
    CONSTANTS lc_ct_uuid TYPE zreing_ca_line_a-ct_uuid VALUE '00000000000000000000000000000002'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000012'.
    CONSTANTS lc_op_uuid_a TYPE zreing_ca_line_a-op_uuid VALUE '0000000000000000000000000000002A'.
    CONSTANTS lc_op_uuid_d TYPE zreing_ca_line_a-op_uuid VALUE '0000000000000000000000000000002D'.

    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUNPAR' line_num = '0000001' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'A' op_uuid = lc_op_uuid_a line_status = 'CONT' exch_rate = '3.00000'
        ct_currency = 'USD' local_currency = 'ARS' )
      ( calc_run_id = 'RUNPAR' line_num = '0000002' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'A' op_uuid = lc_op_uuid_a line_status = 'CONT' exch_rate = '4.00000'
        ct_currency = 'USD' local_currency = 'BRL' )
      ( calc_run_id = 'RUN0002' line_num = '0000005' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'PB1' op_uuid = lc_op_uuid_d bukrs_recv = '2000' line_status = 'PEND'
        parent_net_amt = '400.00' defer_pct = '50.000000'
        origin_run_id = 'RUNPAR' origin_line_num = '0000001'
        ct_currency = 'USD' local_currency = 'ARS' exch_rate_type = 'H' )
      ( calc_run_id = 'RUN0002' line_num = '0000006' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'PB1' op_uuid = lc_op_uuid_d bukrs_recv = '3000' line_status = 'PEND'
        parent_net_amt = '600.00' defer_pct = '25.000000'
        origin_run_id = 'RUNPAR' origin_line_num = '0000002'
        ct_currency = 'USD' local_currency = 'BRL' exch_rate_type = 'H' ) ) ).

    mo_sources->mt_tax_types = VALUE #( ).   " no GL tax types for this ct/mat.

    " Begin Change ID V002 (04.08.2026 | EXT_GONZALCA): Delta v2 CA-07 --
    " step_pc_split ahora SIEMPRE se ejecuta (ET S7.11, [v43]: ya no hay
    " condicional GRANULARITY_TYPE), incluso para lineas pass-through como
    " esta (D hereda BUKRS_RECV del padre). Antes del rework, esta linea
    " nunca llegaba a pedir ME shares porque el skip de granularidad la
    " saltaba (mecanismo ya retirado por completo en CA-11, 05.08.2026).
    " Ahora get_me_shares() se llama igual para BUKRS_RECV=2000 y el test
    " double lo rechaza si MT_ME_SHARES esta vacio -- se agrega un share
    " del 100% para esa receptora (mismo patron que path_a).
    mo_sources->mt_me_shares = VALUE #(
      ( bukrs = '2000' share_pct = '100.000000' prctr = 'PC02' )
      ( bukrs = '3000' share_pct = '100.000000' prctr = 'PC03' ) ).
    " End Change ID V002 (04.08.2026 | EXT_GONZALCA)

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0002' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    " Harmless placeholder row -- get_gl_tax_types (double) returns empty,
    " so this is never looked up; only needed so MT_TX_TYPE_CACHE is
    " non-initial and execute() skips its own real SELECT.
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    " Productive ZCL_REING_CA_CALC_JOB builds the group key without
    " CALC_RUN_ID. The pipeline must use its canonical MS_CONTEXT run.
    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PB1' op_uuid = lc_op_uuid_d ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    " Regression V001 (CC): both physical D seeds of the same group must
    " finish. The former singleton fallback returned only company 2000.
    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 2 ).
    DATA(ls_line) = rs_result-lines[ bukrs_recv = '2000' ].
    DATA(ls_line_2) = rs_result-lines[ bukrs_recv = '3000' ].

    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-base_amt      exp = '200.00' ).  " 400 * 50%
    cl_abap_unit_assert=>assert_equals( act = ls_line-calc_amt      exp = '200.00' ).  " pass-through
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_amt       exp = '200.00' ).  " no tax types
    cl_abap_unit_assert=>assert_equals( act = ls_line-exch_rate     exp = '3.00000' ). " inherited from parent
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_local_amt exp = '600.00' ).  " 200 * 3

    cl_abap_unit_assert=>assert_equals( act = ls_line_2-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line_2-base_amt      exp = '150.00' ).  " 600 * 25%
    cl_abap_unit_assert=>assert_equals( act = ls_line_2-calc_amt      exp = '150.00' ).  " pass-through
    cl_abap_unit_assert=>assert_equals( act = ls_line_2-net_amt       exp = '150.00' ).  " no tax types
    cl_abap_unit_assert=>assert_equals( act = ls_line_2-exch_rate     exp = '4.00000' ). " inherited from parent
    cl_abap_unit_assert=>assert_equals( act = ls_line_2-net_local_amt exp = '600.00' ).  " 150 * 4

    DATA(lv_validate_count) = 0.
    LOOP AT rs_result-steps TRANSPORTING NO FIELDS
      WHERE step_category = zif_reing_ca_c=>step_category-validate.
      lv_validate_count = lv_validate_count + 1.
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lv_validate_count exp = 2 ).

    " Begin Insert V019 (17.09.2026 | EXT_GONZALCA)
    " Bug #78: mitad Path B de la discriminacion B2. ET SS7.4 parte esta
    " rama en "Base padre" (aca, parent_type 'A') y "Base ANT" (AN2,
    " parent_type 'ANT'), y las DOS estrategias devuelven 'B2' en
    " expand_mode -- por eso el modo solo no alcanza y se discrimina por la
    " instancia de estrategia. Si la discriminacion se colapsa a un unico
    " texto, esta assertion y la de path_c_an2_base_ant_desc fallan en
    " direcciones opuestas.
    cl_abap_unit_assert=>assert_equals(
      act = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-validate ]-step_desc
      exp = 'Base padre: 200.00 USD' ).
    " End Insert V019 (17.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

METHOD one_bad_group_no_abort.
    " Coverage note: get_me_shares' test double cannot be made to answer
    " differently per group within the SAME execute() call, because
    " ty_group_key carries no ct_id/matnr of its own (get_ct_identity
    " resolves the SAME identity for both groups here, since both share
    " ct_uuid/mat_uuid). This test instead proves the P-07 contract with
    " two execute() calls on the SAME pipeline instance: a failing group
    " leaves no broken shared state (caches, mt_validate_step, etc.) that
    " would stop a later, healthy group from completing normally.
    " mv_raise_me is left abap_true first (forces the get_me_shares block
    " regardless of get_ct_identity succeeding).
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PA2' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'ARS' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 )
      ( currency = 'ARS' decimals = 2 ) ) ).

    mo_sources->mv_cm_amount   = '500.00'.
    mo_sources->mv_raise_me    = abap_true.   " forces get_me_shares to raise for every call in this test.
    mo_sources->mv_ct_waers    = 'USD'.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'CT0000003' lifnr = '0000005003'
                                           bukrs_prest = '1000' matnr = 'MAT003' ).
    mo_sources->mt_tax_types   = VALUE #( ).

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0003' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    " See path_a_full_happy_path's note: CT_UUID/MAT_UUID/OP_UUID need
    " local x-typed CONSTANTS, not an inline '...'X literal.
    CONSTANTS lc_ct_uuid TYPE zreing_ca_line_a-ct_uuid VALUE '00000000000000000000000000000003'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000013'.
    CONSTANTS lc_op_uuid_bad TYPE zreing_ca_line_a-op_uuid VALUE '00000000000000000000000000000BAD'.
    CONSTANTS lc_op_uuid_ok TYPE zreing_ca_line_a-op_uuid VALUE '0000000000000000000000000000002E'.

    " First execute() call: op_uuid ...BAD fails inside step_01_validate's
    " B1 probe (get_me_shares raises).
    DATA(lt_scope_bad) = VALUE zif_reing_ca_types=>ty_group_key_t(
      ( calc_run_id = 'RUN0003' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'PA2' op_uuid = lc_op_uuid_bad ) ).
    mo_sources->ms_option = CORRESPONDING #( lt_scope_bad[ 1 ] ).
    DATA(rs_result_bad) = lo_cut->execute( it_scope = lt_scope_bad ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result_bad-lines )  exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = rs_result_bad-lines[ 1 ]-line_status
                                         exp = zif_reing_ca_c=>line_status-calc_err ).
    cl_abap_unit_assert=>assert_equals( act = lines( rs_result_bad-errors ) exp = 1 ).

    " Second execute() call, same pipeline instance (mo_sources/lo_cut
    " unchanged) -- proves the caught exception left no broken shared
    " state (P-07) that would stop a later, healthy group from
    " completing normally right after a failing one.
    mo_sources->mv_raise_me  = abap_false.
    mo_sources->mt_me_shares = VALUE #( ( bukrs = '1000' share_pct = '100.000000' prctr = 'PC01' ) ).

    DATA(lt_scope_ok) = VALUE zif_reing_ca_types=>ty_group_key_t(
      ( calc_run_id = 'RUN0003' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'PA2' op_uuid = lc_op_uuid_ok ) ).
    mo_sources->ms_option = CORRESPONDING #( lt_scope_ok[ 1 ] ).
    DATA(rs_result_ok) = lo_cut->execute( it_scope = lt_scope_ok ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result_ok-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = rs_result_ok-lines[ 1 ]-line_status
                                         exp = zif_reing_ca_c=>line_status-calc ).
  ENDMETHOD.

METHOD path_a_delta_same_receptor.
    " Delta v2 CA-06/07 coverage: Path A/CM con CM_H_A.delta_flag = X y una
    " sola receptora que NO cambia respecto al baseline (mismo bukrs_recv,
    " sin altas/bajas). Verifica que step_delta calcule el DELTA PURO
    " (target - baseline), no el total, y que step_pc_split (siempre activo
    " desde CA-07) reparta ese mismo delta por dimension.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PD1' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'USD' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 ) ) ).

    CONSTANTS lc_ct_uuid  TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000041'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000042'.
    CONSTANTS lc_op_uuid  TYPE zreing_ca_line_a-op_uuid  VALUE '00000000000000000000000000000043'.

    mo_sources->mv_cm_amount     = '200.00'.   " CM delta amount (delta puro, BR-CA-41).
    mo_sources->mv_cm_delta_flag = abap_true.
    mo_sources->mv_permite_delta = abap_true.
    mo_sources->mv_ct_waers      = 'USD'.
    mo_sources->mv_avg_rate      = '2.00000'.
    mo_sources->ms_ct_identity   = VALUE #( ct_id = 'CT0000004' lifnr = '0000005004'
                                             bukrs_prest = '1000' matnr = 'MAT004' ).
    mo_sources->mt_me_shares     = VALUE #( ( bukrs = '1000' share_pct = '100.000000' prctr = 'PC01' ) ).
    mo_sources->mt_cont_baseline = VALUE #(
      ( bukrs_recv = '1000' country = 'AR' calc_amt = '1000.00' bruto_amt = '1250.00' delta_seq = '00' ) ).
    mo_sources->mt_cont_pc_baseline_1000 = VALUE #(
      ( prctr = 'PC01' calc_amt = '1000.00' bruto_amt = '1250.00' ) ).

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0004' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0004' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PD1' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].

    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-is_delta       exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-delta_seq      exp = '01' ).       " 1er delta (baseline delta_seq='00')
    cl_abap_unit_assert=>assert_equals( act = ls_line-calc_amt       exp = '200.00' ).   " delta puro, NO el total (1200)
    cl_abap_unit_assert=>assert_equals( act = ls_line-delta_base_amt exp = '1250.00' ).  " baseline bruto

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-line_pc ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = rs_result-line_pc[ 1 ]-calc_amt exp = '200.00' ).
  ENDMETHOD.

METHOD path_a_delta_reseq_reversal.
    " Delta v2 CA-06 coverage: segundo delta consecutivo sobre el mismo
    " grupo (DELTA_SEQ debe incrementar a partir del maximo ya existente
    " en el baseline, no reiniciar en 01), una receptora que sale
    " (bukrs_recv=2000, linea negativa de reversion BR-CA-43) y una
    " receptora nueva que no estaba en el baseline (bukrs_recv=3000).
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PD2' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'USD' )
      ( companycode = '2000' country = 'AR' currency = 'USD' )
      ( companycode = '3000' country = 'AR' currency = 'USD' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 ) ) ).

    CONSTANTS lc_ct_uuid  TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000051'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000052'.
    CONSTANTS lc_op_uuid  TYPE zreing_ca_line_a-op_uuid  VALUE '00000000000000000000000000000053'.

    mo_sources->mv_cm_amount     = '200.00'.
    mo_sources->mv_cm_delta_flag = abap_true.
    mo_sources->mv_permite_delta = abap_true.
    mo_sources->mv_ct_waers      = 'USD'.
    mo_sources->mv_avg_rate      = '2.00000'.
    mo_sources->ms_ct_identity   = VALUE #( ct_id = 'CT0000005' lifnr = '0000005005'
                                             bukrs_prest = '1000' matnr = 'MAT005' ).
    " Shares actuales: 1000 se mantiene (60%), 2000 desaparece, 3000 es nueva (40%).
    mo_sources->mt_me_shares     = VALUE #(
      ( bukrs = '1000' share_pct = '60.000000' prctr = 'PC01' )
      ( bukrs = '3000' share_pct = '40.000000' prctr = 'PC03' ) ).
    " Baseline: 1000 (ya tenia un delta previo, delta_seq='01') y 2000 (original, delta_seq='00').
    mo_sources->mt_cont_baseline = VALUE #(
      ( bukrs_recv = '1000' country = 'AR' calc_amt = '1000.00' bruto_amt = '1250.00' delta_seq = '01' )
      ( bukrs_recv = '2000' country = 'AR' calc_amt = '500.00'  bruto_amt = '625.00'  delta_seq = '00' ) ).
    mo_sources->mt_cont_pc_baseline_1000 = VALUE #(
      ( prctr = 'PC01' calc_amt = '1000.00' bruto_amt = '1250.00' ) ).

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0005' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0005' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PD2' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 3 ).

    LOOP AT rs_result-lines INTO DATA(ls_r).
      cl_abap_unit_assert=>assert_equals( act = ls_r-line_status exp = zif_reing_ca_c=>line_status-calc ).
      cl_abap_unit_assert=>assert_equals( act = ls_r-is_delta    exp = abap_true ).
      cl_abap_unit_assert=>assert_equals( act = ls_r-delta_seq   exp = '02' ).  " MAX(baseline)='01' + 1
    ENDLOOP.

    DATA(ls_1000) = rs_result-lines[ bukrs_recv = '1000' ].
    cl_abap_unit_assert=>assert_equals( act = ls_1000-calc_amt exp = '20.00' ).    " target 1020 - baseline 1000

    DATA(ls_2000) = rs_result-lines[ bukrs_recv = '2000' ].
    cl_abap_unit_assert=>assert_equals( act = ls_2000-calc_amt exp = '-500.00' ). " reversion: 0 - baseline 500

    DATA(ls_3000) = rs_result-lines[ bukrs_recv = '3000' ].
    cl_abap_unit_assert=>assert_equals( act = ls_3000-calc_amt exp = '680.00' ). " target 680 - baseline 0 (nueva)

    " Begin Insert V010 (15.09.2026 | EXT_GONZALCA)
    " Bug #66: SHARE_PAIS_PCT / SHARE_COMB_PCT. This case is the one that can
    " prove the aggregation instead of merely exercising it: 1000 and 3000 are
    " both 'AR', so the country total is 60 + 40 = 100 -- two receptors summed,
    " not one copied from SHARE_PCT.
    " It also pins down the precision trap. SHARE_COMB_PCT = 60 / 100 x 100 is
    " a division of two DEC(9,6): with the implicit P(8,0) inference ABAP would
    " round 0,6 to 1 and store 100,000000 instead of 60,000000, so this
    " assertion fails loudly if the CONV decfloat34 is ever dropped.
    cl_abap_unit_assert=>assert_equals( act = ls_1000-share_pct       exp = '60.000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_1000-share_pais_pct  exp = '100.000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_1000-share_comb_pct  exp = '60.000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_3000-share_pais_pct  exp = '100.000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_3000-share_comb_pct  exp = '40.000000' ).
    " Line 2000 is NOT asserted on purpose. It is created by step_delta as the
    " BR-CA-43 reversal row, AFTER step_distribute has already computed the
    " country totals, so it keeps 0,000000 in both fields. That is a known and
    " reported limitation of fixing this in step_distribute, not a verified
    " expectation -- asserting it here would freeze it as intended behaviour.
    " End Insert V010 (15.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

" Begin Change ID V004 (03.09.2026 | EXT_GONZALCA)
METHOD fx_rate_above_1000.
    " REGRESION del bug reportado desde TS4-400 (03.09.2026): step_fx hacia
    " CONV zreing_ca_step_a-rate_pct( cs_line-exch_rate ) contra un RATE_PCT
    " de DEC(9,6) -- tope 999,999999 -- mientras EXCH_RATE es DEC(9,5) --
    " tope 9999,99999. Toda tasa >= 1000 (ARS ~1500, COP ~3200) reventaba con
    " CX_SY_CONVERSION_OVERFLOW, la excepcion escapaba del pipeline y del job,
    " y el run entero quedaba mudo con sus lineas clavadas en CALC_PROC.
    " Ninguno de los escenarios previos de esta clase pasaba de una tasa de
    " 3,00 -- por eso el bug atraveso los tests. Aqui se usa una tasa COP
    " real (3238) y se verifica tanto la linea como el paso 05 de la memoria
    " de calculo, que es el registro que efectivamente desbordaba.
    " Sin impuestos ni gross-up: NET_AMT = CALC_AMT, aritmetica exacta.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PF1' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'CO' currency = 'COP' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 )
      ( currency = 'COP' decimals = 2 ) ) ).

    mo_sources->mv_cm_amount   = '1000.00'.
    mo_sources->mt_me_shares   = VALUE #( ( bukrs = '1000' share_pct = '100.000000' prctr = 'PC01' ) ).
    mo_sources->mv_ct_waers    = 'USD'.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'CT0000006' lifnr = '0000005006'
                                           bukrs_prest = '1000' matnr = 'MAT006' ).
    mo_sources->mt_tax_types   = VALUE #( ).   " sin impuestos: net = calc.
    mo_sources->mv_avg_rate    = '3238.00000'. " tasa COP real -- desbordaba DEC(9,6).

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0006' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    " Ver la nota de path_a_full_happy_path: los UUID necesitan CONSTANTS
    " x-tipadas, no un literal '...'X inline.
    CONSTANTS lc_ct_uuid  TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000061'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000062'.
    CONSTANTS lc_op_uuid  TYPE zreing_ca_line_a-op_uuid  VALUE '00000000000000000000000000000063'.

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0006' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PF1' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].

    " Antes del fix esta linea salia en CALC_ERR (con el CATCH CX_ROOT nuevo)
    " o directamente tumbaba el job entero (sin el).
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_amt       exp = '1000.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-exch_rate     exp = '3238.00000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_local_amt exp = '3238000.00' ). " 1000 * 3238

    " El registro que efectivamente desbordaba: paso 05 (FX) de STEP_A.
    DATA(ls_step_fx) = rs_result-steps[ step_num = '05' ].
    cl_abap_unit_assert=>assert_equals( act = ls_step_fx-rate_pct   exp = '3238.000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_step_fx-input_amt  exp = '1000.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_step_fx-output_amt exp = '3238000.00' ).
  ENDMETHOD.
" End Change ID V004 (03.09.2026 | EXT_GONZALCA)

" Begin Change ID V013 (16.09.2026 | EXT_GONZALCA)
METHOD delta_pc_share_above_1000.
    " REGRESION del bug reportado desde TS4-400 (16.09.2026, bug tracker #77):
    " la rama delta de step_pc_split asignaba LV_DELTA_DIM -- un importe
    " CURR(15,2) -- al campo SHARE_ABS de ZREING_CA_LPC_A, que es
    " ZREING_PERCENT_9_6, o sea DEC(9,6) con tope 999,999999. Cualquier delta
    " de 1.000 o mas reventaba con CX_SY_CONVERSION_OVERFLOW; como
    " step_pc_split solo declara RAISING ZCX_REING_CA_CALC_ERROR, la excepcion
    " se convertia en CX_SY_NO_HANDLER y la linea terminaba en CALC_ERR con un
    " "Error tecnico" sin causa legible.
    " Caso real: IC-0001/ICSRV44, op P, delta D01, receptora DRM, CALC_AMT
    " 38.709.755,00 sobre un BASE_AMT de 100.000.000,00.
    " Es el mismo patron que fx_rate_above_1000 (V004): un campo de porcentaje
    " recibiendo un importe. Los dos escenarios de delta ya existentes usan un
    " delta de 200,00 y por eso nunca lo tocaron -- aqui el delta es 200.000,00
    " sobre un baseline de 1.000.000,00, con una sola combinacion al 100%, de
    " modo que la aritmetica queda exacta y sin ambiguedad de redondeo.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PD2' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'USD' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 ) ) ).

    CONSTANTS lc_ct_uuid  TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000071'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000072'.
    CONSTANTS lc_op_uuid  TYPE zreing_ca_line_a-op_uuid  VALUE '00000000000000000000000000000073'.

    mo_sources->mv_cm_amount     = '200000.00'.   " delta puro (BR-CA-41).
    mo_sources->mv_cm_delta_flag = abap_true.
    mo_sources->mv_permite_delta = abap_true.
    mo_sources->mv_ct_waers      = 'USD'.
    mo_sources->mv_avg_rate      = '2.00000'.
    mo_sources->ms_ct_identity   = VALUE #( ct_id = 'CT0000007' lifnr = '0000005007'
                                             bukrs_prest = '1000' matnr = 'MAT007' ).
    mo_sources->mt_me_shares     = VALUE #( ( bukrs = '1000' share_pct = '100.000000' prctr = 'PC01' ) ).
    mo_sources->mt_cont_baseline = VALUE #(
      ( bukrs_recv = '1000' country = 'AR' calc_amt = '1000000.00' bruto_amt = '1250000.00' delta_seq = '00' ) ).
    mo_sources->mt_cont_pc_baseline_1000 = VALUE #(
      ( prctr = 'PC01' calc_amt = '1000000.00' bruto_amt = '1250000.00' ) ).

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0007' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0007' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PD2' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].

    " Antes del fix esta linea salia en CALC_ERR, atrapada por el CATCH
    " CX_ROOT de execute -- nunca en CALC.
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-is_delta  exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-calc_amt  exp = '200000.00' ).

    " El campo que desbordaba: SHARE_ABS lleva el PORCENTAJE de la
    " combinacion, no el importe del delta (que viaja por CALC_AMT).
    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-line_pc ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = rs_result-line_pc[ 1 ]-share_abs exp = '100.000000' ).
    cl_abap_unit_assert=>assert_equals( act = rs_result-line_pc[ 1 ]-calc_amt  exp = '200000.00' ).
  ENDMETHOD.
" End Change ID V013 (16.09.2026 | EXT_GONZALCA)


" Begin Insert V019 (17.09.2026 | EXT_GONZALCA): cobertura del bug #78.
METHOD path_c_an2_base_ant_desc.
    " Path C (AN2): parent_type 'ANT', cm_loadable vacio. Misma forma que
    " path_b_defer_fx_type_h -- una linea PEND hija con su padre en CONT --
    " pero con la estrategia AN2, que copia PARENT_NET_AMT 1:1 SIN prorateo
    " (ver ZCL_REING_CA_OPTYPE_AN2~load_base) y fija FX tipo 'P'. De ahi
    " que BASE_AMT sea 400,00 y no 200,00 como en Path B, aunque el
    " DEFER_PCT del fixture sea el mismo: es justamente lo que distingue a
    " las dos ramas B2.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PC1' active = abap_true cm_loadable = abap_false parent_type = 'ANT' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'ARS' )
      ( companycode = '2000' country = 'AR' currency = 'ARS' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 )
      ( currency = 'ARS' decimals = 2 ) ) ).

    CONSTANTS lc_ct_uuid   TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000003'.
    CONSTANTS lc_mat_uuid  TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000013'.
    CONSTANTS lc_op_uuid_p TYPE zreing_ca_line_a-op_uuid  VALUE '0000000000000000000000000000003A'.
    CONSTANTS lc_op_uuid_c TYPE zreing_ca_line_a-op_uuid  VALUE '0000000000000000000000000000003C'.

    go_env->insert_test_data( VALUE lty_line_a_tab(
      ( calc_run_id = 'RUNANT' line_num = '0000001' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'ANT' op_uuid = lc_op_uuid_p line_status = 'CONT'
        ct_currency = 'USD' local_currency = 'ARS' )
      ( calc_run_id = 'RUN0003' line_num = '0000005' ct_uuid = lc_ct_uuid
        mat_uuid = lc_mat_uuid
        op_type = 'PC1' op_uuid = lc_op_uuid_c bukrs_recv = '2000' line_status = 'PEND'
        parent_net_amt = '400.00' defer_pct = '50.000000'
        origin_run_id = 'RUNANT' origin_line_num = '0000001'
        ct_currency = 'USD' local_currency = 'ARS' ) ) ).

    mo_sources->mt_tax_types = VALUE #( ).
    mo_sources->mt_me_shares = VALUE #( ( bukrs = '2000' share_pct = '100.000000' prctr = 'PC02' ) ).
    mo_sources->mv_avg_rate  = '2.00000'.

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0003' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0003' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PC1' op_uuid = lc_op_uuid_c ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-base_amt exp = '400.00'
                                        msg = 'AN2 copia PARENT_NET_AMT sin prorateo' ).

    " El texto es el punto del test: antes del fix esta rama reportaba
    " "Base padre" tambien para AN2 -- texto EQUIVOCADO, no ausente.
    DATA(ls_val_step) = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-validate ].
    cl_abap_unit_assert=>assert_equals( act = ls_val_step-step_desc
                                        exp = 'Base ANT: 400.00 USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_val_step-source_table
                                        exp = 'ZREING_CA_LINE_A'
                                        msg = 'ET SS7.4 no define tabla propia para ANT: LINE_A del padre' ).
  ENDMETHOD.

METHOD gross_up_one_rule_tx_rule_id.
    " Bug #78, caso complementario de path_a_full_happy_path: con UNA sola
    " regla de gross-up ganadora el paso GROSS_UP agregado SI lleva su
    " TX_RULE_ID (con N>1 queda vacio porque el campo es CHAR 20 y la
    " lista vive en SOURCE_KEY). Fixture minimo: un unico tipo GU al 20%,
    " sin reglas non-GU, para que BRUTO siga siendo exacto (1000 / 0,8).
    " BUKRS_PREST '1000' distinto de BUKRS_RECV '2000' a proposito: una
    " linea intra-sociedad no lleva impuesto desde V009 y volveria
    " vacuamente cierta la assertion.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'PA3' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'ARS' )
      ( companycode = '2000' country = 'AR' currency = 'ARS' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 )
      ( currency = 'ARS' decimals = 2 ) ) ).

    CONSTANTS lc_ct_uuid  TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000004'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000014'.
    CONSTANTS lc_op_uuid  TYPE zreing_ca_line_a-op_uuid  VALUE '0000000000000000000000000000004A'.

    mo_sources->mv_cm_amount   = '1000.00'.
    mo_sources->mt_me_shares   = VALUE #( ( bukrs = '2000' share_pct = '100.000000' prctr = 'PC01' ) ).
    mo_sources->mv_ct_waers    = 'USD'.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'CT0000005' lifnr = '0000005005'
                                           bukrs_prest = '1000' matnr = 'MAT005' ).
    mo_sources->mt_tax_types   = VALUE #( ( 'GU1' ) ).
    mo_sources->mt_rules_gu    = VALUE #(
      ( tx_rule_id = 'R_ONLY_GU' tax_type = 'GU1' rate = '20.000000'
        valid_from = '20260101' valid_to = '20261231' ) ).
    mo_sources->mt_rules_nongu = VALUE #( ).
    mo_sources->mv_avg_rate    = '2.00000'.

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0004' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'GU1' gross_up_default = abap_true ) ) ).

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0004' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'PA3' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_line-bruto_amt exp = '1250.00'
                                        msg = 'El gross-up realmente corrio (1000 / 1-0,20)' ).

    DATA(ls_gu_step) = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-gross_up ].
    cl_abap_unit_assert=>assert_equals( act = ls_gu_step-tx_rule_id
                                        exp = 'R_ONLY_GU'
                                        msg = 'Una sola regla ganadora: TX_RULE_ID se llena' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_gu_step-rate_desc
                                             msg = 'RATE_DESC del GROSS_UP (ET SS4.4)' ).
  ENDMETHOD.
" End Insert V019 (17.09.2026 | EXT_GONZALCA)
" Begin Insert V020 (18.09.2026 | EXT_GONZALCA)
METHOD nc_keeps_sign_no_inversion.
    " REGRESION de fixes-042: BR-CA-05 (inversion de signo x -1 para notas de
    " credito) fue RETIRADA de ET-REING-CA-001 v50 y del codigo. Hasta este
    " test NINGUN caso unitario ejercitaba esa inversion, ni para confirmarla
    " ni para negarla, asi que nada impedia reintroducir el "* -1".
    "
    " El escenario es el MINIMO que hace verdadera la condicion retirada:
    " op_type = 'NC' es el UNICO valor para el que
    " ZCL_REING_CA_OPTYPE_CM~is_credit_note( ) devuelve true (literal en ese
    " metodo, el catalogo no tiene flag propio -- de hecho ZREING_OP_TYPE_C no
    " tiene campo IS_NC, que es parte de por que la ET dio de baja la regla), y
    " cm_loadable = X es lo que hace que la factory despache a esa estrategia.
    "
    " Sin impuestos: NET_AMT = BRUTO_AMT = CALC_AMT. La aritmetica es exacta y
    " sin ambiguedad de redondeo, de modo que el SIGNO es lo unico que este
    " test puede llegar a ver mal.
    "
    " BUKRS_PREST '1000' distinto de BUKRS_RECV '2000' a proposito: varios
    " fixtures de esta clase usaban la misma sociedad de los dos lados por
    " accidente, lo que dispara el descarte intra-sociedad de V009.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'NC' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'ARS' )
      ( companycode = '2000' country = 'AR' currency = 'ARS' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 )
      ( currency = 'ARS' decimals = 2 ) ) ).

    CONSTANTS lc_ct_uuid  TYPE zreing_ca_line_a-ct_uuid  VALUE '00000000000000000000000000000081'.
    CONSTANTS lc_mat_uuid TYPE zreing_ca_line_a-mat_uuid VALUE '00000000000000000000000000000082'.
    CONSTANTS lc_op_uuid  TYPE zreing_ca_line_a-op_uuid  VALUE '00000000000000000000000000000083'.

    mo_sources->mv_cm_amount   = '1000.00'.
    mo_sources->mt_me_shares   = VALUE #( ( bukrs = '2000' share_pct = '100.000000' prctr = 'PC01' ) ).
    mo_sources->mv_ct_waers    = 'USD'.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'CT0000008' lifnr = '0000005008'
                                           bukrs_prest = '1000' matnr = 'MAT008' ).
    mo_sources->mt_tax_types   = VALUE #( ).   " sin impuestos: net = bruto = calc.
    mo_sources->mv_avg_rate    = '2.00000'.

    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
                     is_context = VALUE #( calc_run_id = 'RUN0008' period = '06' year = '2026' )
                     io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).

    DATA(ls_scope) = VALUE zif_reing_ca_types=>ty_group_key(
                       calc_run_id = 'RUN0008' ct_uuid = lc_ct_uuid
                       mat_uuid = lc_mat_uuid
                       op_type = 'NC' op_uuid = lc_op_uuid ).
    mo_sources->ms_option = CORRESPONDING #( ls_scope ).
    DATA(rs_result) = lo_cut->execute( it_scope = VALUE #( ( ls_scope ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( rs_result-lines ) exp = 1 ).
    DATA(ls_line) = rs_result-lines[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).

    " EL PUNTO DEL TEST. Con BR-CA-05 vigente esto valia -1000,00.
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-calc_amt exp = '1000.00'
      msg = 'BR-CA-05 retirada (ET v50): una NC ya NO invierte el signo de CALC_AMT' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-net_amt exp = '1000.00'
      msg = 'Sin impuestos el neto arrastra el mismo signo que el calculado' ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_line-net_local_amt exp = '2000.00'
      msg = 'La conversion a moneda local tampoco reintroduce el signo' ).

    " El paso DISTRIBUTE de la memoria de calculo es el registro que llevaba el
    " importe invertido: si alguien reintroduce el "* -1" en cualquiera de las
    " dos ramas de step_distribute, esta assertion lo delata.
    DATA(ls_step_dist) = rs_result-steps[ step_category = zif_reing_ca_c=>step_category-distribute ].
    cl_abap_unit_assert=>assert_equals(
      act = ls_step_dist-output_amt exp = '1000.00'
      msg = 'El paso DISTRIBUTE registra el importe sin invertir' ).
  ENDMETHOD.
" End Insert V020 (18.09.2026 | EXT_GONZALCA)

  " V001 (CC) - ISO-01: compiled OFF keeps EBA on the current FX path.
  METHOD eba_off_uses_legacy.
    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
      is_context = VALUE #( )
      io_sources = mo_sources ).
    DATA(ls_line) = VALUE zreing_ca_line_a(
      line_num = 1 bukrs_prest = 'EBA'
      ct_currency = 'USD' local_currency = 'USD' net_amt = '100.00' ).
    DATA lt_steps TYPE zif_reing_ca_types=>ty_step_t.

    lo_cut->step_fx(
      CHANGING cs_line = ls_line ct_steps = lt_steps ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-exch_rate exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_local_amt exp = '100.00' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_steps ) exp = 1 ).
  ENDMETHOD.

  " V001 (CC) - ISO-01: enabling EBA cannot change MUR or USA FX.
  METHOD non_eba_on_uses_legacy.
    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
      is_context = VALUE #( )
      io_sources = mo_sources ).
    lo_cut->mv_eba_off = abap_false.
    DATA lt_steps TYPE zif_reing_ca_types=>ty_step_t.

    DATA lt_prest TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY.
    lt_prest = VALUE #( ( 'MUR' ) ( 'USA' ) ).
    LOOP AT lt_prest INTO DATA(lv_prest).
      DATA(ls_line) = VALUE zreing_ca_line_a(
        line_num = sy-tabix bukrs_prest = lv_prest
        ct_currency = 'USD' local_currency = 'USD' net_amt = '100.00' ).
      CLEAR lt_steps.
      lo_cut->step_fx(
        CHANGING cs_line = ls_line ct_steps = lt_steps ).
      cl_abap_unit_assert=>assert_equals( act = ls_line-net_local_amt exp = '100.00' ).
      cl_abap_unit_assert=>assert_equals( act = lines( lt_steps ) exp = 1 ).
    ENDLOOP.
  ENDMETHOD.

  " V001 (CC) - CA-06: replace only the obsolete V2 stub expectation.
  METHOD eba_on_requires_v2.
    DATA(lo_cut) = NEW zcl_reing_ca_pipeline( is_context = VALUE #( ) io_sources = mo_sources ).
    lo_cut->mv_eba_off = abap_false.
    lo_cut->mt_currency_decimals = VALUE #( ( currency = 'USD' decimals = 2 ) ).
    lo_cut->mt_bukrs_cache = VALUE #( ( bukrs = 'EBA' country = 'BR' currency = 'USD' )
                                    ( bukrs = 'EBC' country = 'BR' currency = 'USD' ) ).
    DATA(ls_line) = VALUE zreing_ca_line_a( line_num = 1 bukrs_prest = 'EBA' bukrs_recv = 'EBC'
      ct_currency = 'USD' local_currency = 'USD' net_amt = '100.00' ).
    DATA lt_steps TYPE zif_reing_ca_types=>ty_step_t.
    lo_cut->step_fx( CHANGING cs_line = ls_line ct_steps = lt_steps ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_trans_amt exp = '100.00' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_steps ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( act = ls_line-exch_rate_1_type ).
  ENDMETHOD.


  " V001 (CC) - CA-05 (EBA Brasil): isolated FX fixtures, no business writes.
  METHOD new_fx_cut.
    ro_cut = NEW zcl_reing_ca_pipeline(
      is_context = VALUE #( ) io_sources = mo_sources ).
    ro_cut->inject_tx_cache(
      VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' gross_up_default = abap_false ) ) ).
  ENDMETHOD.

  METHOD pick_fx_rule.
    rs_result = io_cut->find_fx_rule(
      it_rules = it_rules iv_ct_currency = 'USD' iv_same_country = 'D'
      iv_country_prest = 'BR' iv_country_recv = 'CL'
      iv_bukrs_prest = 'EBA' iv_bukrs_recv = 'EBC' ).
  ENDMETHOD.

  METHOD fx_weight_order.
    " ET weights: each criterion must outrank all lower criteria together.
    TYPES: BEGIN OF ty_pair,
             higher TYPE zreing_fx_rule_a,
             lower TYPE zreing_fx_rule_a,
           END OF ty_pair.
    DATA lt_pairs TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.
    lt_pairs = VALUE #(
      ( higher = VALUE #( bukrs_recv = 'EBC' )
        lower = VALUE #( bukrs_prest = 'EBA' ct_currency = 'USD'
          country_recv = 'CL' country_prest = 'BR' same_country = 'D' ) )
      ( higher = VALUE #( bukrs_prest = 'EBA' )
        lower = VALUE #( ct_currency = 'USD'
          country_recv = 'CL' country_prest = 'BR' same_country = 'D' ) )
      ( higher = VALUE #( ct_currency = 'USD' )
        lower = VALUE #( country_recv = 'CL' country_prest = 'BR' same_country = 'D' ) )
      ( higher = VALUE #( country_recv = 'CL' )
        lower = VALUE #( country_prest = 'BR' same_country = 'D' ) )
      ( higher = VALUE #( country_prest = 'BR' ) lower = VALUE #( same_country = 'D' ) )
      ( higher = VALUE #( same_country = 'D' ) ) ).
    DATA(lo_cut) = new_fx_cut( ).
    LOOP AT lt_pairs INTO DATA(ls_pair).
      ls_pair-higher-fx_rule_id = 'HIGH'.
      ls_pair-lower-fx_rule_id = 'LOW'.
      ls_pair-higher-trans_currency_mode = 'SAME'.
      ls_pair-lower-trans_currency_mode = 'LOCAL'.
      DATA(ls_result) = pick_fx_rule(
        io_cut = lo_cut it_rules = VALUE #( ( ls_pair-lower ) ( ls_pair-higher ) ) ).
      cl_abap_unit_assert=>assert_equals(
        act = ls_result-rule-fx_rule_id exp = 'HIGH'
        msg = |Higher criterion must win for pair { sy-tabix }| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD fx_discard_criteria.
    " A single nonmatching criterion excludes the rule, regardless of weight.
    DATA lt_bad TYPE zcl_reing_ca_pipeline=>tt_fx_rules.
    lt_bad = VALUE #( ( ct_currency = 'EUR' ) ( same_country = 'S' )
      ( country_prest = 'AR' ) ( country_recv = 'PE' )
      ( bukrs_prest = 'MUR' ) ( bukrs_recv = 'USA' ) ).
    DATA(lo_cut) = new_fx_cut( ).
    LOOP AT lt_bad INTO DATA(ls_bad).
      ls_bad-fx_rule_id = 'BAD'.
      ls_bad-trans_currency_mode = 'FIXED'.
      DATA(ls_result) = pick_fx_rule( io_cut = lo_cut it_rules = VALUE #(
        ( ls_bad ) ( fx_rule_id = 'GENERIC' trans_currency_mode = 'SAME' ) ) ).
      cl_abap_unit_assert=>assert_equals( act = ls_result-rule-fx_rule_id exp = 'GENERIC' ).
    ENDLOOP.
  ENDMETHOD.

  METHOD fx_wildcard_zero.
    DATA(ls_result) = pick_fx_rule( io_cut = new_fx_cut( ) it_rules = VALUE #(
      ( fx_rule_id = 'REAL_ZERO' trans_currency_mode = 'SAME' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-rule-fx_rule_id exp = 'REAL_ZERO' ).
    cl_abap_unit_assert=>assert_false( act = ls_result-is_fallback ).
  ENDMETHOD.

  METHOD fx_tie_raises.
    " Same output is still ambiguous; IDs order diagnostics, never break ties.
    TRY.
        pick_fx_rule( io_cut = new_fx_cut( ) it_rules = VALUE #(
          ( fx_rule_id = 'TIE_B' bukrs_prest = 'EBA' trans_currency_mode = 'LOCAL' )
          ( fx_rule_id = 'TIE_A' bukrs_prest = 'EBA' trans_currency_mode = 'LOCAL' ) ) ).
        cl_abap_unit_assert=>fail( msg = 'Top-score ties must raise a domain exception' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lx_error->mv_message CS 'score 16' ) ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lx_error->mv_message CS 'TIE_A,TIE_B' ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD fx_lower_tie.
    DATA(ls_result) = pick_fx_rule( io_cut = new_fx_cut( ) it_rules = VALUE #(
      ( fx_rule_id = 'LOW_A' trans_currency_mode = 'LOCAL' )
      ( fx_rule_id = 'WIN' bukrs_prest = 'EBA' trans_currency_mode = 'SAME' )
      ( fx_rule_id = 'LOW_B' trans_currency_mode = 'LOCAL' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-rule-fx_rule_id exp = 'WIN' ).
    cl_abap_unit_assert=>assert_false( act = ls_result-is_fallback ).
  ENDMETHOD.

  METHOD fx_order_stable.
    DATA lt_rules TYPE zcl_reing_ca_pipeline=>tt_fx_rules.
    lt_rules = VALUE #(
      ( fx_rule_id = 'A' ct_currency = 'USD' trans_currency_mode = 'LOCAL' )
      ( fx_rule_id = 'B' bukrs_prest = 'EBA' trans_currency_mode = 'FIXED'
        trans_currency_fixed = 'EUR' )
      ( fx_rule_id = 'C' trans_currency_mode = 'SAME' ) ).
    DATA(lo_cut) = new_fx_cut( ).
    DATA(ls_first) = pick_fx_rule( io_cut = lo_cut it_rules = lt_rules ).
    SORT lt_rules BY fx_rule_id DESCENDING.
    DATA(ls_reversed) = pick_fx_rule( io_cut = lo_cut it_rules = lt_rules ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-rule-fx_rule_id exp = 'B' ).
    cl_abap_unit_assert=>assert_equals( act = ls_reversed exp = ls_first ).
  ENDMETHOD.

  METHOD fx_empty_fallback.
    DATA(ls_result) = pick_fx_rule( io_cut = new_fx_cut( ) it_rules = VALUE #( ) ).
    DATA(ls_expected) = VALUE zcl_reing_ca_pipeline=>ty_fx_rule_result(
      rule = VALUE #( trans_currency_mode = 'SAME' ) is_fallback = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result exp = ls_expected ).
  ENDMETHOD.

  METHOD fx_all_discard_fallback.
    DATA(ls_result) = pick_fx_rule( io_cut = new_fx_cut( ) it_rules = VALUE #(
      ( fx_rule_id = 'BAD_CT' bukrs_recv = 'EBC' bukrs_prest = 'EBA'
        ct_currency = 'EUR' trans_currency_mode = 'FIXED' trans_currency_fixed = 'JPY' )
      ( fx_rule_id = 'BAD_COUNTRY' country_recv = 'PE' trans_currency_mode = 'LOCAL' ) ) ).
    DATA(ls_expected) = VALUE zcl_reing_ca_pipeline=>ty_fx_rule_result(
      rule = VALUE #( trans_currency_mode = 'SAME' ) is_fallback = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_result exp = ls_expected ).
  ENDMETHOD.

  METHOD fx_modes_preserve.
    DATA lt_modes TYPE STANDARD TABLE OF zreing_fx_rule_a-trans_currency_mode WITH EMPTY KEY.
    lt_modes = VALUE #( ( 'SAME' ) ( 'LOCAL' ) ( 'FIXED' ) ).
    DATA(lo_cut) = new_fx_cut( ).
    LOOP AT lt_modes INTO DATA(lv_mode).
      DATA(ls_rule) = VALUE zreing_fx_rule_a(
        mandt = sy-mandt fx_rule_id = 'FULL' ct_currency = 'USD' same_country = 'D'
        country_prest = 'BR' country_recv = 'CL' bukrs_prest = 'EBA' bukrs_recv = 'EBC'
        trans_currency_mode = lv_mode
        trans_currency_fixed = COND #( WHEN lv_mode = 'FIXED' THEN 'JPY' ELSE space ) ).
      DATA(ls_result) = pick_fx_rule( io_cut = lo_cut it_rules = VALUE #( ( ls_rule ) ) ).
      cl_abap_unit_assert=>assert_equals( act = ls_result-rule exp = ls_rule ).
      cl_abap_unit_assert=>assert_false( act = ls_result-is_fallback ).
    ENDLOOP.
  ENDMETHOD.

  METHOD fx_read_cds_mapping.
    DATA(lt_fixture) = VALUE tt_fx_cds( (
      fxruleid = 'MAP' ctcurrency = 'USD' samecountry = 'D'
      countryprest = 'BR' countryrecv = 'CL' bukrsprest = 'EBA' bukrsrecv = 'EBC'
      transcurrencymode = 'FIXED' transcurrencyfixed = 'EUR' ) ).
    go_env->insert_test_data( lt_fixture ).
    DATA(lo_cut) = new_fx_cut( ).
    lo_cut->mv_eba_off = abap_false.
    lo_cut->load_fx_rules( iv_bukrs_prest = 'EBA' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_cut->mt_fx_rules ) exp = 1 ).
    DATA(ls_expected) = VALUE zreing_fx_rule_a(
      fx_rule_id = 'MAP' ct_currency = 'USD' same_country = 'D'
      country_prest = 'BR' country_recv = 'CL' bukrs_prest = 'EBA' bukrs_recv = 'EBC'
      trans_currency_mode = 'FIXED' trans_currency_fixed = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = lo_cut->mt_fx_rules[ 1 ] exp = ls_expected ).
  ENDMETHOD.

  METHOD fx_read_provider_filter.
    DATA(lt_fixture) = VALUE tt_fx_cds(
      ( fxruleid = 'EBA' bukrsprest = 'EBA' transcurrencymode = 'LOCAL' )
      ( fxruleid = 'WILD' transcurrencymode = 'SAME' )
      ( fxruleid = 'OTHER' bukrsprest = 'MUR' transcurrencymode = 'FIXED' ) ).
    go_env->insert_test_data( lt_fixture ).
    DATA(lo_cut) = new_fx_cut( ).
    lo_cut->mv_eba_off = abap_false.
    lo_cut->load_fx_rules( iv_bukrs_prest = 'EBA' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_cut->mt_fx_rules ) exp = 2 ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( lo_cut->mt_fx_rules[ fx_rule_id = 'EBA' ] ) ) ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( lo_cut->mt_fx_rules[ fx_rule_id = 'WILD' ] ) ) ).
    cl_abap_unit_assert=>assert_false(
      act = xsdbool( line_exists( lo_cut->mt_fx_rules[ fx_rule_id = 'OTHER' ] ) ) ).
  ENDMETHOD.

  METHOD fx_off_and_empty_scope.
    DATA(lt_fixture) = VALUE tt_fx_cds(
      ( fxruleid = 'AVAILABLE' bukrsprest = 'EBA' transcurrencymode = 'LOCAL' ) ).
    go_env->insert_test_data( lt_fixture ).
    DATA(lo_cut) = new_fx_cut( ).
    lo_cut->mt_fx_rules = VALUE #( ( fx_rule_id = 'STALE' trans_currency_mode = 'FIXED' ) ).
    lo_cut->load_fx_rules( iv_bukrs_prest = 'EBA' ).
    cl_abap_unit_assert=>assert_initial( act = lo_cut->mt_fx_rules ).
    lo_cut->mt_fx_rules = VALUE #( ( fx_rule_id = 'STALE' trans_currency_mode = 'FIXED' ) ).
    DATA(ls_off) = lo_cut->execute( it_scope = VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( act = lo_cut->mt_fx_rules ).
    cl_abap_unit_assert=>assert_initial( act = ls_off-lines ).
    lo_cut->mv_eba_off = abap_false.
    lo_cut->mt_fx_rules = VALUE #( ( fx_rule_id = 'STALE' trans_currency_mode = 'FIXED' ) ).
    DATA(ls_empty) = lo_cut->execute( it_scope = VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( act = lo_cut->mt_fx_rules ).
    cl_abap_unit_assert=>assert_initial( act = ls_empty-lines ).
  ENDMETHOD.

  METHOD fx_refresh_empty.
    DATA(lt_fixture) = VALUE tt_fx_cds(
      ( fxruleid = 'FIRST' bukrsprest = 'EBA' transcurrencymode = 'LOCAL' ) ).
    go_env->insert_test_data( lt_fixture ).
    DATA(lo_cut) = new_fx_cut( ).
    lo_cut->mv_eba_off = abap_false.
    lo_cut->load_fx_rules( iv_bukrs_prest = 'EBA' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_cut->mt_fx_rules ) exp = 1 ).
    go_env->clear_doubles( ).
    lo_cut->load_fx_rules( iv_bukrs_prest = 'EBA' ).
    cl_abap_unit_assert=>assert_initial( act = lo_cut->mt_fx_rules ).
  ENDMETHOD.


  " V001 (CC) - CA-109: execute() must expose CALC_ERR before FX/FI.
  METHOD run_cm_instance.
    CONSTANTS lc_ct TYPE sysuuid_x16 VALUE '10900000000000000000000000000001'.
    CONSTANTS lc_mat TYPE sysuuid_x16 VALUE '10900000000000000000000000000002'.
    CONSTANTS lc_op TYPE sysuuid_x16 VALUE '10900000000000000000000000000003'.
    CONSTANTS lc_cm TYPE sysuuid_x16 VALUE '10900000000000000000000000000004'.
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = 'A' active = abap_true cm_loadable = abap_true default_exch_rate_type = 'P' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = '1000' country = 'AR' currency = 'USD' ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab( ( currency = 'USD' decimals = 2 ) ) ).
    mo_sources->mv_cm_amount = '1000.00'.
    mo_sources->mv_cm_instance = iv_cm_instance.
    mo_sources->mv_reject_cm = iv_reject_cm.
    mo_sources->mv_ct_waers = 'USD'.
    mo_sources->mv_avg_rate = 1.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'IC-0001' bukrs_prest = '1000' matnr = 'ICSRV44' ).
    mo_sources->mt_me_shares = VALUE #( ( bukrs = '1000' prctr = 'PC01' share_pct = 100 ) ).
    mo_sources->ms_option = VALUE #( ct_uuid = lc_ct mat_uuid = lc_mat
      op_type = 'A' op_uuid = lc_op op_instance_num = '002' ).
    IF iv_wrong_group = abap_true.
      mo_sources->ms_option-mat_uuid = lc_ct.
    ENDIF.
    DATA(lo_cut) = NEW zcl_reing_ca_pipeline(
      is_context = VALUE #( calc_run_id = 'RUN-CA109' period = '08' year = '2026' )
      io_sources = mo_sources ).
    lo_cut->inject_tx_cache( VALUE ty_tx_cache_tab( ( tax_type = 'ZZZ' ) ) ).
    IF iv_eba_on = abap_true.
      lo_cut->mv_eba_off = abap_false.
      mo_sources->ms_ct_identity-bukrs_prest = 'EBA'.
    ENDIF.
    rs_result = lo_cut->execute( it_scope = VALUE #(
      ( calc_run_id = 'RUN-CA109' ct_uuid = lc_ct mat_uuid = lc_mat
        op_type = 'A' op_uuid = lc_op cm_h_id = lc_cm ) ) ).
  ENDMETHOD.

  METHOD cm_instance_mismatch.
    DATA(ls_result) = run_cm_instance( '003' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-errors ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = 'CALC_ERR' ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-line_pc ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-lines[ 1 ]-calc_amt ).
  ENDMETHOD.

  METHOD cm_instance_matches.
    DATA(ls_result) = run_cm_instance( '002' ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-errors ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = 'CALC' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-op_instance_num exp = '002' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-calc_amt exp = '1000.00' ).
  ENDMETHOD.

  METHOD cm_wrong_option_group.
    DATA(ls_result) = run_cm_instance( iv_cm_instance = '002' iv_wrong_group = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-errors ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = 'CALC_ERR' ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-lines[ 1 ]-calc_amt ).
  ENDMETHOD.

  METHOD cm_source_rejects.
    DATA(ls_result) = run_cm_instance( iv_cm_instance = '003' iv_reject_cm = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-errors ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = 'CALC_ERR' ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-lines[ 1 ]-calc_amt ).
  ENDMETHOD.

  METHOD cm_instance_eba_on.
    DATA(ls_result) = run_cm_instance( iv_cm_instance = '003' iv_eba_on = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-errors ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = 'CALC_ERR' ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( ls_result-errors[ 1 ]-message CS 'instancia' ) ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-lines[ 1 ]-calc_amt ).
  ENDMETHOD.


  METHOD prepare_exec.
    " Every scenario owns its doubles; no production table or global switch changes.
    go_env->clear_doubles( ).
    mo_sources = NEW #( ).
    DATA(lv_defer) = xsdbool( iv_type = zif_reing_ca_c=>fx_contract_rate_type-inherited ).
    DATA(lv_op_type) = COND zreing_ca_line_a-op_type(
      WHEN lv_defer = abap_true THEN co_exec_defer ELSE co_exec_cm ).
    go_env->insert_test_data( VALUE lty_op_type_c_tab(
      ( op_type = co_exec_cm active = abap_true cm_loadable = abap_true
        default_exch_rate_type = zif_reing_ca_c=>fx_contract_rate_type-manual )
      ( op_type = co_exec_defer active = abap_true parent_type = 'A' ) ) ).
    go_env->insert_test_data( VALUE lty_companycode_tab(
      ( companycode = iv_prest country = 'BR' currency = 'BRL' )
      ( companycode = co_exec_recv country = COND #( WHEN iv_local = 'ARS' THEN 'AR' ELSE 'BR' )
        currency = iv_local ) ) ).
    go_env->insert_test_data( VALUE lty_currency_tab(
      ( currency = 'USD' decimals = 2 ) ( currency = 'BRL' decimals = 2 ) ( currency = 'ARS' decimals = 2 ) ) ).
    go_env->insert_test_data( VALUE tt_exec_header(
      ( ct_uuid = co_exec_ct bukrs = iv_prest waers = 'USD' ct_id = 'IC-FX-TEST' ) ) ).
    mt_exec_scope = VALUE #( ( calc_run_id = co_exec_run ct_uuid = co_exec_ct mat_uuid = co_exec_mat
      op_type = lv_op_type op_uuid = co_exec_op ) ).
    mo_sources->ms_option = CORRESPONDING #( mt_exec_scope[ 1 ] ).
    mo_sources->ms_option-op_instance_num = co_exec_instance.
    mo_sources->ms_option-exch_rate_type = iv_type.
    go_env->insert_test_data( VALUE tt_exec_option( ( mo_sources->ms_option ) ) ).
    go_env->insert_test_data( VALUE tt_exec_manual(
      ( ct_uuid = co_exec_ct mat_uuid = co_exec_mat op_type = lv_op_type op_uuid = co_exec_op
        op_instance_num = co_exec_instance bukrs_recv = co_exec_recv manual_exch_rate = 2 ) ) ).
    IF iv_mode IS NOT INITIAL.
      go_env->insert_test_data( VALUE tt_fx_cds(
        ( fxruleid = 'INTEGRAL' bukrsprest = iv_prest transcurrencymode = iv_mode
          transcurrencyfixed = COND #( WHEN iv_mode = co_exec_fixed THEN 'BRL' ELSE space ) ) ) ).
    ENDIF.
    mo_sources->mv_cm_amount = 100.
    mo_sources->mv_ct_waers = 'USD'.
    mo_sources->mv_manual_rate = 2.
    mo_sources->mv_avg_rate = 3.
    mo_sources->ms_ct_identity = VALUE #( ct_id = 'IC-FX-TEST' lifnr = '0000005000'
      bukrs_prest = iv_prest matnr = 'FX-SERVICE' ).
    mo_sources->mt_me_shares = VALUE #(
      ( bukrs = co_exec_recv share_pct = 60 prctr = 'PC60' )
      ( bukrs = co_exec_recv share_pct = 40 prctr = 'PC40' ) ).
    IF iv_tax = abap_true.
      mo_sources->mt_tax_types = VALUE #( ( 'GU1' ) ( 'TX1' ) ).
      mo_sources->mt_rules_gu = VALUE #( ( tx_rule_id = 'INTEGRAL_GU' tax_type = 'GU1'
        rate = 20 valid_from = '19000101' valid_to = '99991231' ) ).
      mo_sources->mt_rules_nongu = VALUE #( ( tx_rule_id = 'INTEGRAL_TX' tax_type = 'TX1'
        rate = 10 valid_from = '19000101' valid_to = '99991231' ) ).
    ENDIF.
    mo_exec_local = NEW #( ).
    mo_exec_local->result = VALUE #( available = abap_true multiplier = 5
      rate_type = zif_reing_ca_c=>fx_sap_rate_type-local_temporary
      policy_source = zif_reing_ca_c=>fx_local_policy-temporary_m
      status_code = zif_reing_ca_c=>fx_local_status-ok ).
    mo_exec_cut = NEW #( is_context = VALUE #( calc_run_id = co_exec_run period = '06' year = '2020' )
      io_sources = mo_sources io_local_fx = mo_exec_local ).
    mo_exec_cut->mv_eba_off = xsdbool( iv_on = abap_false ).
    mo_exec_cut->inject_tx_cache( VALUE ty_tx_cache_tab(
      ( tax_type = 'GU1' gross_up_default = abap_true )
      ( tax_type = 'TX1' gross_up_default = abap_false ) ) ).
    IF lv_defer = abap_true.
      go_env->insert_test_data( VALUE lty_line_a_tab(
        ( calc_run_id = co_exec_parent line_num = 1 ct_uuid = co_exec_ct mat_uuid = co_exec_mat
          op_type = 'A' line_status = zif_reing_ca_c=>line_status-cont
          exch_rate = 2 exch_rate_1 = 2 ct_currency = 'USD' trans_currency = 'BRL' )
        ( calc_run_id = co_exec_parent line_num = 2 ct_uuid = co_exec_ct mat_uuid = co_exec_mat
          op_type = 'A' line_status = zif_reing_ca_c=>line_status-cont
          exch_rate = 9 exch_rate_1 = 9 ct_currency = 'USD' trans_currency = 'BRL' )
        ( calc_run_id = co_exec_run line_num = 7 ct_uuid = co_exec_ct mat_uuid = co_exec_mat
          op_type = co_exec_defer op_uuid = co_exec_op op_instance_num = co_exec_instance
          line_status = zif_reing_ca_c=>line_status-pend bukrs_prest = iv_prest bukrs_recv = co_exec_recv
          ct_id = 'IC-FX-TEST' matnr = 'FX-SERVICE' lifnr = '0000005000' country = 'BR' share_pct = 100
          parent_net_amt = 200 defer_pct = 50 origin_run_id = co_exec_parent origin_line_num = 1
          ct_currency = 'USD' local_currency = iv_local
          exch_rate_type = zif_reing_ca_c=>fx_contract_rate_type-inherited ) ) ).
    ENDIF.
  ENDMETHOD.

  METHOD add_exec_group.
    DATA(ls_group) = mt_exec_scope[ 1 ].
    ls_group-op_uuid = co_exec_other_op.
    APPEND ls_group TO mt_exec_scope.
    DATA(ls_option) = mo_sources->ms_option.
    ls_option-op_uuid = co_exec_other_op.
    go_env->insert_test_data( VALUE tt_exec_option( ( ls_option ) ) ).
    IF iv_manual = abap_true.
      go_env->insert_test_data( VALUE tt_exec_manual(
        ( ct_uuid = co_exec_ct mat_uuid = co_exec_mat op_type = co_exec_cm op_uuid = co_exec_other_op
          op_instance_num = co_exec_instance bukrs_recv = co_exec_recv manual_exch_rate = 2 ) ) ).
    ENDIF.
  ENDMETHOD.

  METHOD assert_exec_chain.
    cl_abap_unit_assert=>assert_initial( is_result-errors ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-line_pc ) exp = 2 ).
    DATA(ls_line) = is_result-lines[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_line-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-calc_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-bruto_amt exp = COND zreing_ca_calc_amt(
      WHEN iv_tax = abap_true THEN 125 ELSE 100 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-tax_amt exp = COND zreing_ca_calc_amt(
      WHEN iv_tax = abap_true THEN '37.50' ELSE 0 ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-net_trans_amt exp = iv_net ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-ct_currency exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-trans_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_pc[ prctr = 'PC60' ]-net_amt exp = 60 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_pc[ prctr = 'PC40' ]-net_amt exp = 40 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_pc[ prctr = 'PC60' ]-net_trans_amt exp = CONV decfloat34( iv_net ) * CONV decfloat34( '0.60' ) ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_pc[ prctr = 'PC40' ]-net_trans_amt exp = CONV decfloat34( iv_net ) * CONV decfloat34( '0.40' ) ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_pc[ prctr = 'PC60' ]-bruto_trans_amt exp = CONV decfloat34( iv_bruto ) * CONV decfloat34( '0.60' ) ).
    cl_abap_unit_assert=>assert_equals( act = is_result-line_pc[ prctr = 'PC40' ]-bruto_trans_amt exp = CONV decfloat34( iv_bruto ) * CONV decfloat34( '0.40' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = is_result-steps[ step_category = zif_reing_ca_c=>step_category-net ]-output_trans_amt exp = iv_net ).
    cl_abap_unit_assert=>assert_equals(
      act = is_result-steps[ step_num = zif_reing_ca_c=>fx_step-number
        seq = zif_reing_ca_c=>fx_step-primary_seq ]-output_amt exp = iv_net ).
    cl_abap_unit_assert=>assert_equals(
      act = is_result-steps[ step_num = zif_reing_ca_c=>fx_step-number
        seq = zif_reing_ca_c=>fx_step-primary_seq ]-input_currency exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals(
      act = is_result-steps[ step_num = zif_reing_ca_c=>fx_step-number
        seq = zif_reing_ca_c=>fx_step-primary_seq ]-output_currency exp = 'BRL' ).
    IF iv_tax = abap_true.
      cl_abap_unit_assert=>assert_equals( act = is_result-steps[
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'GU1' ]-output_amt exp = 25 ).
      cl_abap_unit_assert=>assert_equals( act = is_result-steps[
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'TX1' ]-output_amt exp = '12.50' ).
      cl_abap_unit_assert=>assert_equals( act = is_result-steps[
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'GU1' ]-output_trans_amt exp = CONV decfloat34( iv_net ) * CONV decfloat34( '0.25' ) ).
      cl_abap_unit_assert=>assert_equals( act = is_result-steps[
        step_category = zif_reing_ca_c=>step_category-tax tax_type = 'TX1' ]-output_trans_amt exp = CONV decfloat34( iv_net ) * CONV decfloat34( '0.125' ) ).
    ENDIF.
    assert_exec_keys( is_result ).
  ENDMETHOD.

  METHOD assert_exec_keys.
    DATA lt_lines TYPE tt_exec_lines.
    DATA lt_pc TYPE tt_exec_pc.
    DATA lt_steps TYPE tt_exec_steps.
    LOOP AT is_result-lines INTO DATA(ls_line).
      INSERT ls_line INTO TABLE lt_lines.
      cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 0 msg = 'Unique physical LINE key' ).
      cl_abap_unit_assert=>assert_equals( act = ls_line-calc_run_id exp = co_exec_run ).
    ENDLOOP.
    LOOP AT is_result-line_pc INTO DATA(ls_pc).
      INSERT ls_pc INTO TABLE lt_pc.
      cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 0 msg = 'Unique physical LPC key' ).
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
        lt_lines[ calc_run_id = ls_pc-calc_run_id line_num = ls_pc-line_num ] ) ) ).
    ENDLOOP.
    LOOP AT is_result-steps INTO DATA(ls_step).
      INSERT ls_step INTO TABLE lt_steps.
      cl_abap_unit_assert=>assert_equals( act = sy-subrc exp = 0 msg = 'Unique physical STEP key' ).
      cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
        lt_lines[ calc_run_id = ls_step-calc_run_id line_num = ls_step-line_num ] ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD assert_exec_error.
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = is_result-lines[ 1 ]-line_status
      exp = zif_reing_ca_c=>line_status-calc_err ).
    cl_abap_unit_assert=>assert_equals( act = lines( is_result-errors ) exp = 1 ).
    cl_abap_unit_assert=>assert_not_initial( is_result-lines[ 1 ]-sim_message ).
    cl_abap_unit_assert=>assert_initial( is_result-line_pc ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( is_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-primary_seq ] ) ) ).
    cl_abap_unit_assert=>assert_not_initial( is_result-steps ).
    assert_exec_keys( is_result ).
  ENDMETHOD.

  METHOD exec_off_legacy_mph.
    " Execute every business modality without a caller loop around SQL precargas.
    assert_exec_legacy( zif_reing_ca_c=>fx_contract_rate_type-manual ).
    assert_exec_legacy( zif_reing_ca_c=>fx_contract_rate_type-average ).
    assert_exec_legacy( zif_reing_ca_c=>fx_contract_rate_type-inherited ).
  ENDMETHOD.

  METHOD assert_exec_legacy.
    prepare_exec( iv_type = iv_type iv_on = abap_false iv_tax = abap_false ).
    DATA(ls_eba) = mo_exec_cut->execute( mt_exec_scope ).
    cl_abap_unit_assert=>assert_initial( ls_eba-errors ).
    cl_abap_unit_assert=>assert_equals( act = ls_eba-lines[ 1 ]-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_eba-lines[ 1 ]-net_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = ls_eba-lines[ 1 ]-net_local_amt
      exp = COND zreing_ca_calc_amt( WHEN iv_type = zif_reing_ca_c=>fx_contract_rate_type-average THEN 300 ELSE 200 ) ).
    cl_abap_unit_assert=>assert_initial( ls_eba-lines[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_initial( ls_eba-lines[ 1 ]-exch_rate_1 ).
    cl_abap_unit_assert=>assert_initial( ls_eba-lines[ 1 ]-trans_currency ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( ls_eba-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-local_seq ] ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
    prepare_exec( iv_prest = co_exec_non_eba iv_type = iv_type iv_on = abap_false iv_tax = abap_false ).
    DATA(ls_other) = mo_exec_cut->execute( mt_exec_scope ).
    cl_abap_unit_assert=>assert_initial( ls_other-errors ).
    cl_abap_unit_assert=>assert_equals( act = ls_other-lines[ 1 ]-net_amt exp = ls_eba-lines[ 1 ]-net_amt ).
    cl_abap_unit_assert=>assert_equals( act = ls_other-lines[ 1 ]-net_local_amt exp = ls_eba-lines[ 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_equals( act = ls_other-lines[ 1 ]-exch_rate exp = ls_eba-lines[ 1 ]-exch_rate ).
    cl_abap_unit_assert=>assert_equals( act = ls_other-lines[ 1 ]-exch_rate_type exp = iv_type ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.

  METHOD exec_on_non_eba.
    prepare_exec( iv_prest = co_exec_non_eba iv_type = zif_reing_ca_c=>fx_contract_rate_type-average ).
    " An unrelated EBA contract and rule must not select V2 for the MUR scope.
    go_env->insert_test_data( VALUE tt_exec_header(
      ( ct_uuid = co_exec_other_ct bukrs = zif_reing_ca_c=>br_isolation-eba_bukrs
        waers = 'USD' ct_id = 'IC-FX-OTHER' ) ) ).
    go_env->insert_test_data( VALUE tt_exec_option(
      ( ct_uuid = co_exec_other_ct mat_uuid = co_exec_mat op_type = co_exec_cm
        op_uuid = co_exec_other_op op_instance_num = co_exec_instance
        exch_rate_type = zif_reing_ca_c=>fx_contract_rate_type-manual ) ) ).
    go_env->insert_test_data( VALUE tt_exec_manual(
      ( ct_uuid = co_exec_other_ct mat_uuid = co_exec_mat op_type = co_exec_cm
        op_uuid = co_exec_other_op op_instance_num = co_exec_instance
        bukrs_recv = co_exec_recv manual_exch_rate = 9 ) ) ).
    go_env->insert_test_data( VALUE tt_fx_cds(
      ( fxruleid = 'OTHER_EBA' bukrsprest = zif_reing_ca_c=>br_isolation-eba_bukrs
        transcurrencymode = co_exec_fixed transcurrencyfixed = 'BRL' ) ) ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    cl_abap_unit_assert=>assert_initial( ls_result-errors ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-net_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-bruto_amt exp = 125 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-net_local_amt exp = 300 ).
    cl_abap_unit_assert=>assert_initial( ls_result-lines[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_initial( ls_result-lines[ 1 ]-exch_rate_1 ).
    " Legacy memory keeps its existing numeric rate text; P maps to ICRG in Sources.
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_type
      exp = zif_reing_ca_c=>fx_contract_rate_type-average ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_date exp = '20200630' ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( ls_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-local_seq ] ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.

  METHOD exec_manual_trans_chain.
    prepare_exec( ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_result iv_net = 200 iv_bruto = 250 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_1 exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_1_type
      exp = zif_reing_ca_c=>fx_contract_rate_type-manual ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-net_local_amt exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-local_seq ]-output_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.

  METHOD exec_average_trans_chain.
    prepare_exec( iv_type = zif_reing_ca_c=>fx_contract_rate_type-average ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_result iv_net = 300 iv_bruto = 375 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_1_type
      exp = zif_reing_ca_c=>fx_contract_rate_type-average ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_from exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_to exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_date exp = '20200630' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-primary_seq ]-source_key
      CS zif_reing_ca_c=>fx_sap_rate_type-contract_average ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.

  METHOD exec_parent_trans_chain.
    prepare_exec( iv_type = zif_reing_ca_c=>fx_contract_rate_type-inherited iv_tax = abap_false ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_result iv_net = 200 iv_bruto = 200 iv_tax = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_num exp = 7 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-origin_run_id exp = co_exec_parent ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-origin_line_num exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_1 exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_1_type
      exp = zif_reing_ca_c=>fx_contract_rate_type-inherited ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.

  METHOD exec_fallback_same_chain.
    prepare_exec( iv_mode = space ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    cl_abap_unit_assert=>assert_initial( ls_result-errors ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-net_trans_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-trans_currency exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-exch_rate_1 exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-lines[ 1 ]-net_local_amt exp = 500 ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-lines[ 1 ]-sim_message CS 'BR-FX-02' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-line_pc[ prctr = 'PC60' ]-net_trans_amt exp = 60 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-line_pc[ prctr = 'PC40' ]-net_trans_amt exp = 40 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-primary_seq ]-output_currency exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-local_seq ]-output_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 1 ).
    assert_exec_keys( ls_result ).
  ENDMETHOD.

  METHOD exec_tie_blocks_line.
    prepare_exec( ).
    go_env->insert_test_data( VALUE tt_fx_cds(
      ( fxruleid = 'EQUAL' bukrsprest = zif_reing_ca_c=>br_isolation-eba_bukrs
        transcurrencymode = co_exec_local ) ) ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_error( ls_result ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-errors[ 1 ]-message CS 'score 16' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.

  METHOD exec_preview_missing_chain.
    prepare_exec( iv_local = 'ARS' iv_mode = co_exec_fixed ).
    mo_exec_local->result = VALUE #( status_code = zif_reing_ca_c=>fx_local_status-no_rate
      policy_source = zif_reing_ca_c=>fx_local_policy-temporary_m message = 'Synthetic missing local quote' ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_result iv_net = 200 iv_bruto = 250 ).
    cl_abap_unit_assert=>assert_initial( ls_result-lines[ 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_initial( ls_result-lines[ 1 ]-exch_rate ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-lines[ 1 ]-sim_message CS 'BR-CA-52' ) ).
    cl_abap_unit_assert=>assert_initial( ls_result-steps[
      step_num = zif_reing_ca_c=>fx_step-number seq = zif_reing_ca_c=>fx_step-local_seq ]-output_currency ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 1 ).
    DATA(ls_projection) = zcl_reing_ca_trans_amounts=>project_line(
      is_line = ls_result-lines[ 1 ] it_line_pc = ls_result-line_pc it_steps = ls_result-steps
      it_currencies = VALUE #( ( currency = 'USD' decimals = 2 )
        ( currency = 'BRL' decimals = 2 ) ( currency = 'ARS' decimals = 2 ) ) iv_eba_off = abap_false ).
    cl_abap_unit_assert=>assert_true( ls_projection-use_trans ).
    cl_abap_unit_assert=>assert_false( ls_projection-local_available ).
    cl_abap_unit_assert=>assert_equals( act = ls_projection-line-net_trans_amt exp = 200 ).
  ENDMETHOD.

  METHOD exec_scope_keys_stay_unique.
    prepare_exec( ).
    add_exec_group( ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    cl_abap_unit_assert=>assert_initial( ls_result-errors ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-line_pc ) exp = 4 ).
    assert_exec_keys( ls_result ).
    DATA(ls_first) = ls_result-lines[ op_uuid = co_exec_op ].
    DATA(ls_second) = ls_result-lines[ op_uuid = co_exec_other_op ].
    cl_abap_unit_assert=>assert_differs( act = ls_first-line_num exp = ls_second-line_num ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-net_trans_amt exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = ls_second-net_trans_amt exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = REDUCE zreing_ca_calc_amt(
      INIT total = CONV zreing_ca_calc_amt( 0 ) FOR ls_pc IN ls_result-line_pc
      WHERE ( line_num = ls_first-line_num ) NEXT total = total + ls_pc-net_trans_amt ) exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = REDUCE zreing_ca_calc_amt(
      INIT total = CONV zreing_ca_calc_amt( 0 ) FOR ls_pc IN ls_result-line_pc
      WHERE ( line_num = ls_second-line_num ) NEXT total = total + ls_pc-net_trans_amt ) exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-steps[ line_num = ls_first-line_num
      step_category = zif_reing_ca_c=>step_category-net ]-output_trans_amt exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-steps[ line_num = ls_second-line_num
      step_category = zif_reing_ca_c=>step_category-net ]-output_trans_amt exp = 200 ).
  ENDMETHOD.

  METHOD exec_bad_group_keeps_next.
    prepare_exec( ).
    go_env->get_double( 'ZREING_CT_O_R_A' )->clear( ).
    add_exec_group( ).
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-errors ) exp = 1 ).
    DATA(ls_bad) = ls_result-lines[ op_uuid = co_exec_op ].
    DATA(ls_good) = ls_result-lines[ op_uuid = co_exec_other_op ].
    cl_abap_unit_assert=>assert_equals( act = ls_bad-line_status exp = zif_reing_ca_c=>line_status-calc_err ).
    cl_abap_unit_assert=>assert_equals( act = ls_good-line_status exp = zif_reing_ca_c=>line_status-calc ).
    cl_abap_unit_assert=>assert_equals( act = ls_good-net_trans_amt exp = 200 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-line_pc ) exp = 2 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( ls_result-line_pc[ line_num = ls_bad-line_num ] ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-steps[ line_num = ls_good-line_num
      step_category = zif_reing_ca_c=>step_category-net ]-output_trans_amt exp = 200 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( ls_result-steps[ line_num = ls_bad-line_num
      step_category = zif_reing_ca_c=>step_category-validate ] ) ) ).
    assert_exec_keys( ls_result ).
  ENDMETHOD.

  METHOD exec_reloads_quotes.
    prepare_exec( iv_type = zif_reing_ca_c=>fx_contract_rate_type-average ).
    mo_sources->mv_avg_rate = 2.
    DATA(ls_first) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_first iv_net = 200 iv_bruto = 250 ).
    mo_sources->mv_avg_rate = 3.
    DATA(ls_second) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_second iv_net = 300 iv_bruto = 375 ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_calls exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_first-steps ) exp = lines( ls_second-steps ) ).
  ENDMETHOD.

  METHOD exec_exact_manual_scope.
    prepare_exec( ).
    go_env->insert_test_data( VALUE tt_exec_manual(
      ( ct_uuid = co_exec_ct mat_uuid = co_exec_mat op_type = co_exec_cm op_uuid = co_exec_op
        op_instance_num = co_exec_other_instance bukrs_recv = co_exec_recv manual_exch_rate = 9 )
      ( ct_uuid = co_exec_ct mat_uuid = co_exec_mat op_type = co_exec_cm op_uuid = co_exec_op
        op_instance_num = co_exec_instance bukrs_recv = co_exec_non_eba manual_exch_rate = 9 ) ) ).
    DATA(ls_exact) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_chain( is_result = ls_exact iv_net = 200 iv_bruto = 250 ).
    go_env->get_double( 'ZREING_CT_O_R_A' )->clear( ).
    go_env->insert_test_data( VALUE tt_exec_manual(
      ( ct_uuid = co_exec_ct mat_uuid = co_exec_mat op_type = co_exec_cm op_uuid = co_exec_op
        op_instance_num = co_exec_other_instance bukrs_recv = co_exec_recv manual_exch_rate = 9 )
      ( ct_uuid = co_exec_ct mat_uuid = co_exec_mat op_type = co_exec_cm op_uuid = co_exec_op
        op_instance_num = co_exec_instance bukrs_recv = co_exec_non_eba manual_exch_rate = 9 ) ) ).
    DATA(ls_missing) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_error( ls_missing ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_missing-errors[ 1 ]-message CS 'FX' ) ).
  ENDMETHOD.

  METHOD exec_future_primary_rejected.
    prepare_exec( iv_type = zif_reing_ca_c=>fx_contract_rate_type-average ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    mo_exec_cut->ms_context-year = CONV i( lv_today(4) ) + 1.
    mo_exec_cut->ms_context-period = '01'.
    DATA(ls_result) = mo_exec_cut->execute( mt_exec_scope ).
    assert_exec_error( ls_result ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_result-errors[ 1 ]-message CS 'FX' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_sources->mv_average_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_exec_local->calls exp = 0 ).
  ENDMETHOD.
ENDCLASS.
" V001 (CC) - Exact B2 seed selection, proposed tests; existing suite retained.
CLASS ltcl_an2_exact DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_reing_ca_pipeline.
    DATA mt_scope TYPE zif_reing_ca_types=>ty_group_key_t.
    DATA mt_pending TYPE zif_reing_ca_types=>ty_line_t.
    METHODS setup.
    METHODS supplied_empty_rejects FOR TESTING.
    METHODS duplicate_keys_reject FOR TESTING.
    METHODS exact_subset_only FOR TESTING.
    METHODS uncovered_group_reject FOR TESTING.
    METHODS omitted_empty_preserved FOR TESTING RAISING cx_static_check.
ENDCLASS.
CLASS ltcl_an2_exact IMPLEMENTATION.
  METHOD setup.
    TEST-INJECTION eba_pipeline_switch.
      mv_eba_off = abap_true.
    END-TEST-INJECTION.
    mo_cut = NEW #( is_context = VALUE #( calc_run_id = 'RUN-202610' year = '2026' period = '10' )
      io_sources = NEW ltd_sources_pipe( ) ).
    mt_scope = VALUE #( ( calc_run_id = 'RUN-202610' ct_uuid = CONV #( '11' ) mat_uuid = CONV #( '22' )
      op_type = 'AN2' op_uuid = CONV #( '44' ) ) ).
    mt_pending = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150'
      ct_uuid = mt_scope[ 1 ]-ct_uuid mat_uuid = mt_scope[ 1 ]-mat_uuid
      op_type = 'AN2' op_uuid = mt_scope[ 1 ]-op_uuid parent_op_type = 'ANT'
      op_instance_num = '003' origin_run_id = 'RUN-202604' origin_line_num = '0000001' )
      ( calc_run_id = 'RUN-202610' line_num = '0000167'
      ct_uuid = mt_scope[ 1 ]-ct_uuid mat_uuid = mt_scope[ 1 ]-mat_uuid
      op_type = 'AN2' op_uuid = mt_scope[ 1 ]-op_uuid parent_op_type = 'ANT'
      op_instance_num = '003' origin_run_id = 'RUN-202604' origin_line_num = '0000002' ) ).
  ENDMETHOD.
  METHOD supplied_empty_rejects.
    DATA(ls_result) = mo_cut->execute( it_scope = mt_scope it_pending_keys = VALUE #( ) ).
    cl_abap_unit_assert=>assert_not_initial( ls_result-errors ).
    cl_abap_unit_assert=>assert_initial( ls_result-lines ).
    cl_abap_unit_assert=>assert_initial( ls_result-line_pc ).
    cl_abap_unit_assert=>assert_initial( ls_result-steps ).
  ENDMETHOD.
  METHOD duplicate_keys_reject.
    DATA(lv_message) = mo_cut->check_pending_input( it_scope = mt_scope it_pending_keys = VALUE #(
      ( calc_run_id = 'RUN-202610' line_num = '0000150' )
      ( calc_run_id = 'RUN-202610' line_num = '0000150' ) ) ).
    cl_abap_unit_assert=>assert_not_initial( lv_message ).
  ENDMETHOD.
  METHOD exact_subset_only.
    mo_cut->restrict_pending_scope( EXPORTING it_scope = mt_scope it_pending = mt_pending
      it_pending_keys = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' ) )
      IMPORTING et_selected = DATA(lt_selected) ev_message = DATA(lv_message) ).
    cl_abap_unit_assert=>assert_initial( lv_message ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_selected ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_selected[ 1 ]-line_num exp = '0000150' ).
    cl_abap_unit_assert=>assert_equals( act = mt_pending[ 2 ]-line_num exp = '0000167' ).
  ENDMETHOD.
  METHOD uncovered_group_reject.
    APPEND VALUE #( BASE mt_scope[ 1 ] op_uuid = CONV #( '55' ) ) TO mt_scope.
    mo_cut->restrict_pending_scope( EXPORTING it_scope = mt_scope it_pending = mt_pending
      it_pending_keys = VALUE #( ( calc_run_id = 'RUN-202610' line_num = '0000150' ) )
      IMPORTING et_selected = DATA(lt_selected) ev_message = DATA(lv_message) ).
    cl_abap_unit_assert=>assert_not_initial( lv_message ).
    cl_abap_unit_assert=>assert_initial( lt_selected ).
  ENDMETHOD.
  METHOD omitted_empty_preserved.
    DATA(lo_env) = cl_osql_test_environment=>create( VALUE #(
      ( 'I_COMPANYCODE' ) ( 'I_CURRENCY' ) ( 'ZREING_TX_TYPE_C' ) ) ).
    TRY.
        DATA(ls_omitted) = mo_cut->execute( it_scope = VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( ls_omitted-errors ).
        cl_abap_unit_assert=>assert_initial( ls_omitted-lines ).
        DATA(ls_supplied) = mo_cut->execute( it_scope = VALUE #( ) it_pending_keys = VALUE #( ) ).
        cl_abap_unit_assert=>assert_not_initial( ls_supplied-errors ).
      CLEANUP.
        lo_env->destroy( ).
    ENDTRY.
    lo_env->destroy( ).
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - CA-06: deterministic FX protocol and monetary boundaries.

CLASS ltd_local_fx_pipe IMPLEMENTATION.
  METHOD zif_reing_ca_local_fx~convert_trans_to_local.
    calls = calls + 1.
    last_amount = iv_amount_trans.
    last_date = iv_date.
    rs_result = result.
    IF rs_result-available = abap_true.
      rs_result-amount_local = round( val = iv_amount_trans * rs_result-multiplier
        dec = iv_decimals_local mode = cl_abap_math=>round_half_up ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_fx_v2 DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_reing_ca_pipeline.
    DATA sources TYPE REF TO ltd_sources_pipe.
    DATA local_fx TYPE REF TO ltd_local_fx_pipe.
    DATA line TYPE zreing_ca_line_a.
    DATA steps TYPE zif_reing_ca_types=>ty_step_t.
    METHODS setup.
    METHODS run_fx RAISING zcx_reing_ca_calc_error.
    METHODS primary_mode IMPORTING iv_type TYPE zreing_exrt_type.
    METHODS same_two_steps FOR TESTING RAISING cx_static_check.
    METHODS local_mode_manual FOR TESTING RAISING cx_static_check.
    METHODS fixed_mode_manual FOR TESTING RAISING cx_static_check.
    METHODS manual_exact_instance FOR TESTING RAISING cx_static_check.
    METHODS manual_missing FOR TESTING.
    METHODS manual_zero FOR TESTING.
    METHODS primary_type_invalid FOR TESTING.
    METHODS manual_canonical_five FOR TESTING RAISING cx_static_check.
    METHODS manual_three_decimals FOR TESTING.
    METHODS average_pair FOR TESTING RAISING cx_static_check.
    METHODS average_currency_scale FOR TESTING RAISING cx_static_check.
    METHODS average_future FOR TESTING.
    METHODS parent_rate_exact FOR TESTING RAISING cx_static_check.
    METHODS parent_missing_stage FOR TESTING.
    METHODS parent_wrong_direction FOR TESTING.
    METHODS local_zero_valid FOR TESTING RAISING cx_static_check.
    METHODS local_missing_quote FOR TESTING RAISING cx_static_check.
    METHODS local_config_warning FOR TESTING RAISING cx_static_check.
    METHODS local_date_warning FOR TESTING RAISING cx_static_check.
    METHODS local_precision_warning FOR TESTING RAISING cx_static_check.
    METHODS local_cache_amount FOR TESTING RAISING cx_static_check.
    METHODS generic_not_fallback FOR TESTING RAISING cx_static_check.
    METHODS fallback_warning_reset FOR TESTING RAISING cx_static_check.
    METHODS legacy_resets_marker FOR TESTING RAISING cx_static_check.
    METHODS preserves_other_steps FOR TESTING RAISING cx_static_check.
    METHODS invalid_currency FOR TESTING.
    METHODS warning_semicolon_reset FOR TESTING RAISING cx_static_check.
    METHODS local_technical_warning FOR TESTING RAISING cx_static_check.
    METHODS execution_cache_reset FOR TESTING RAISING cx_static_check.
    " V001 (CC) - Projection/index integration fixtures.
    METHODS trans_fixture RETURNING VALUE(rt_pc) TYPE zif_reing_ca_types=>ty_line_pc_t.
    METHODS trans_duplicate_tail FOR TESTING RAISING cx_static_check.
    METHODS trans_bounded_index FOR TESTING RAISING cx_static_check.
    METHODS trans_recovers_deleted_index FOR TESTING RAISING cx_static_check.
    METHODS trans_foreign_tail_rejected FOR TESTING RAISING cx_static_check.
    METHODS trans_stale_index_rejected FOR TESTING RAISING cx_static_check.
    METHODS trans_compensated_delta FOR TESTING RAISING cx_static_check.
    METHODS trans_local_precision_warning FOR TESTING RAISING cx_static_check.
    METHODS trans_preview_unavailable FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltcl_fx_v2 IMPLEMENTATION.
  METHOD setup.
    TEST-INJECTION eba_pipeline_switch.
      mv_eba_off = abap_true.
    END-TEST-INJECTION.
    sources = NEW #( ).
    local_fx = NEW #( ).
    local_fx->result = VALUE #( available = abap_true multiplier = 5 rate_type = 'M'
                               policy_source = 'TEMP_M' status_code = 'OK' ).
    cut = NEW #( is_context = VALUE #( period = '01' year = '2026' calc_run_id = 'FX_TEST' )
                 io_sources = sources io_local_fx = local_fx ).
    cut->mv_eba_off = abap_false.
    cut->mt_currency_decimals = VALUE #( ( currency = 'USD' decimals = 2 )
      ( currency = 'BRL' decimals = 2 ) ( currency = 'JPY' decimals = 0 ) ( currency = 'KWD' decimals = 3 ) ).
    cut->mt_bukrs_cache = VALUE #( ( bukrs = 'EBA' country = 'BR' currency = 'BRL' )
                                  ( bukrs = 'EBC' country = 'AR' currency = 'BRL' ) ).
    cut->mt_fx_rules = VALUE #( ( fx_rule_id = 'GENERIC' trans_currency_mode = 'SAME' ) ).
    line = VALUE #( line_num = 1 calc_run_id = 'FX_TEST' bukrs_prest = 'EBA' bukrs_recv = 'EBC'
      country = 'AR' op_type = 'A' op_instance_num = '001' ct_currency = 'USD' local_currency = 'BRL' net_amt = 10 ).
  ENDMETHOD.
  METHOD run_fx.
    cut->step_fx( CHANGING cs_line = line ct_steps = steps ).
  ENDMETHOD.
  METHOD primary_mode.
    cut->mt_fx_rules = VALUE #( ( fx_rule_id = 'FIXED' trans_currency_mode = 'FIXED' trans_currency_fixed = 'BRL' ) ).
    line-exch_rate_type = iv_type.
    cut->mt_fx_options = VALUE #( ( ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid op_type = line-op_type
      op_uuid = line-op_uuid op_instance_num = line-op_instance_num exch_rate_type = iv_type ) ).
    cut->mt_manual_fx = VALUE #( ( ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid op_type = line-op_type
      op_uuid = line-op_uuid op_instance_num = '001' bukrs_recv = 'EBC' manual_exch_rate = 2 ) ).
  ENDMETHOD.
  METHOD same_two_steps.
    line-local_currency = 'USD'.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 10 ).
    cl_abap_unit_assert=>assert_equals( act = line-net_local_amt exp = 10 ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1 exp = 1 ).
    cl_abap_unit_assert=>assert_initial( line-exch_rate_type ).
    cl_abap_unit_assert=>assert_equals( act = steps[ step_num = '05' seq = '02' ]-output_currency exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 0 ).
  ENDMETHOD.
  METHOD local_mode_manual.
    primary_mode( 'M' ).
    cut->mt_fx_rules[ 1 ]-trans_currency_mode = 'LOCAL'.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 20 ).
    cl_abap_unit_assert=>assert_equals( act = line-net_local_amt exp = 20 ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1_type exp = 'M' ).
    cl_abap_unit_assert=>assert_initial( line-exch_rate_type ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 0 ).
  ENDMETHOD.
  METHOD fixed_mode_manual.
    primary_mode( 'M' ).
    line-local_currency = 'USD'.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-trans_currency exp = 'BRL' ).
    cl_abap_unit_assert=>assert_equals( act = line-net_local_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_type exp = 'M' ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->last_amount exp = 20 ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->last_date exp = '20260131' ).
  ENDMETHOD.
  METHOD manual_exact_instance.
    primary_mode( 'M' ).
    INSERT VALUE #( ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid op_type = line-op_type op_uuid = line-op_uuid
      op_instance_num = '002' bukrs_recv = 'EBC' manual_exch_rate = 9 ) INTO TABLE cut->mt_manual_fx.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1 exp = 2 ).
  ENDMETHOD.
  METHOD manual_missing.
    primary_mode( 'M' ). CLEAR cut->mt_manual_fx.
    TRY. run_fx( ). cl_abap_unit_assert=>fail( 'Expected missing manual error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'manual' ) ). ENDTRY.
  ENDMETHOD.
  METHOD manual_zero.
    primary_mode( 'M' ). cut->mt_manual_fx[ ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid op_type = line-op_type op_uuid = line-op_uuid
      op_instance_num = '001' bukrs_recv = 'EBC' ]-manual_exch_rate = 0.
    TRY. run_fx( ). cl_abap_unit_assert=>fail( 'Expected zero rate error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'rango' ) ). ENDTRY.
  ENDMETHOD.
  METHOD primary_type_invalid.
    primary_mode( space ).
    TRY. run_fx( ). cl_abap_unit_assert=>fail( 'Expected invalid type error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'Tipo' ) ). ENDTRY.
  ENDMETHOD.
  METHOD manual_canonical_five.
    primary_mode( 'M' ). cut->mt_manual_fx[ ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid op_type = line-op_type op_uuid = line-op_uuid
      op_instance_num = '001' bukrs_recv = 'EBC' ]-manual_exch_rate = '1.234566'.
    line-net_amt = 100.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1 exp = '1.23457' ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = '123.46' ).
  ENDMETHOD.
  METHOD manual_three_decimals.
    primary_mode( 'M' ). cut->mt_fx_rules[ 1 ]-trans_currency_fixed = 'KWD'.
    cut->mt_manual_fx[ ct_uuid = line-ct_uuid mat_uuid = line-mat_uuid op_type = line-op_type op_uuid = line-op_uuid
      op_instance_num = '001' bukrs_recv = 'EBC' ]-manual_exch_rate = '0.3065'.
    TRY. run_fx( ). cl_abap_unit_assert=>fail( 'Expected CURR2 precision error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'representable' ) ). ENDTRY.
  ENDMETHOD.
  METHOD average_pair.
    primary_mode( 'P' ). sources->mv_avg_rate = 3.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 30 ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1_type exp = 'P' ).
    cl_abap_unit_assert=>assert_equals( act = steps[ seq = '01' ]-source_key exp = 'ICRG/USD/BRL/20260131' ).
  ENDMETHOD.
  METHOD average_currency_scale.
    primary_mode( 'P' ). cut->mt_fx_rules[ 1 ]-trans_currency_fixed = 'JPY'.
    sources->mv_avg_rate = '1.5'.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1 exp = 150 ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 1500 ).
  ENDMETHOD.
  METHOD average_future.
    primary_mode( 'P' ). cut->ms_context-year = '2099'.
    TRY. run_fx( ). cl_abap_unit_assert=>fail( 'Expected future P error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'futuro' ) ). ENDTRY.
  ENDMETHOD.
  METHOD parent_rate_exact.
    primary_mode( 'H' ). line-origin_run_id = 'PARENT'. line-origin_line_num = 7.
    cut->step_fx( EXPORTING it_parent_fx = VALUE #( ( origin_run_id = 'OTHER' origin_line_num = 7
      exch_rate_1 = 9 ct_currency = 'USD' trans_currency = 'BRL' )
      ( origin_run_id = 'PARENT' origin_line_num = 7 exch_rate_1 = '1.23457'
        ct_currency = 'USD' trans_currency = 'BRL' ) ) CHANGING cs_line = line ct_steps = steps ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1 exp = '1.23457' ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1_type exp = 'H' ).
  ENDMETHOD.
  METHOD parent_missing_stage.
    primary_mode( 'H' ). line-origin_run_id = 'PARENT'. line-origin_line_num = 7.
    TRY.
      cut->step_fx( EXPORTING it_parent_fx = VALUE #( ( origin_run_id = 'PARENT' origin_line_num = 7
        exch_rate = 2 ct_currency = 'USD' trans_currency = 'BRL' ) ) CHANGING cs_line = line ct_steps = steps ).
      cl_abap_unit_assert=>fail( 'Expected missing stage1 error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'Padre' ) ). ENDTRY.
  ENDMETHOD.
  METHOD parent_wrong_direction.
    primary_mode( 'H' ). line-origin_run_id = 'PARENT'. line-origin_line_num = 7.
    TRY.
      cut->step_fx( EXPORTING it_parent_fx = VALUE #( ( origin_run_id = 'PARENT' origin_line_num = 7
        exch_rate_1 = 2 ct_currency = 'BRL' trans_currency = 'USD' ) ) CHANGING cs_line = line ct_steps = steps ).
      cl_abap_unit_assert=>fail( 'Expected incompatible direction error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'incompatible' ) ). ENDTRY.
  ENDMETHOD.
  METHOD local_zero_valid.
    line-net_amt = 0. run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = line-net_local_amt exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = steps[ seq = '02' ]-output_currency exp = 'BRL' ).
  ENDMETHOD.
  METHOD local_missing_quote.
    local_fx->result = VALUE #( rate_type = 'M' status_code = 'NO_RATE' policy_source = 'TEMP_M' message = 'Sin tasa' ).
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 10 ).
    cl_abap_unit_assert=>assert_equals( act = line-exch_rate_1 exp = 1 ).
    cl_abap_unit_assert=>assert_initial( line-exch_rate ).
    cl_abap_unit_assert=>assert_initial( steps[ seq = '02' ]-output_currency ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-CA-52]' ) ).
  ENDMETHOD.
  METHOD local_config_warning.
    line-local_currency = 'ZZZ'. run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 10 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-CA-FX-CONFIG]' ) ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 0 ).
  ENDMETHOD.
  METHOD local_date_warning.
    cut->ms_context-year = '2099'. run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 10 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-CA-FX-DATE]' ) ).
  ENDMETHOD.
  METHOD local_precision_warning.
    line-local_currency = 'KWD'. local_fx->result-multiplier = '0.3065'. run_fx( ).
    cl_abap_unit_assert=>assert_initial( line-exch_rate ).
    cl_abap_unit_assert=>assert_initial( line-net_local_amt ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-CA-FX-PRECISION]' ) ).
  ENDMETHOD.
  METHOD local_cache_amount.
    run_fx( ). line-net_amt = 20. run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_local_amt exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 2 ).
    run_fx( ). cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 2 ).
  ENDMETHOD.
  METHOD generic_not_fallback.
    run_fx( ). cl_abap_unit_assert=>assert_initial( line-sim_message ).
  ENDMETHOD.
  METHOD fallback_warning_reset.
    CLEAR cut->mt_fx_rules. run_fx( ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-FX-02]' ) ).
    cut->mt_fx_rules = VALUE #( ( fx_rule_id = 'GENERIC' trans_currency_mode = 'SAME' ) ).
    line-sim_message = '[BR-CA-52] Anterior; [EXT] Conservar'.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-sim_message exp = '[EXT] Conservar' ).
  ENDMETHOD.
  METHOD legacy_resets_marker.
    run_fx( ). cut->mv_eba_off = abap_true. line-local_currency = 'USD'. run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = lines( steps ) exp = 1 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( steps[ seq = '02' ] ) ) ).
  ENDMETHOD.
  METHOD preserves_other_steps.
    steps = VALUE #( ( line_num = 1 step_num = '04' seq = '01' )
                    ( line_num = 9 step_num = '05' seq = '02' ) ).
    run_fx( ). cl_abap_unit_assert=>assert_equals( act = lines( steps ) exp = 4 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( steps[ line_num = 9 seq = '02' ] ) ) ).
  ENDMETHOD.
  METHOD invalid_currency.
    line-ct_currency = 'ZZZ'.
    TRY. run_fx( ). cl_abap_unit_assert=>fail( 'Expected invalid primary currency error' ).
      CATCH zcx_reing_ca_calc_error INTO DATA(err).
        cl_abap_unit_assert=>assert_true( xsdbool( err->mv_message CS 'Moneda' ) ). ENDTRY.
  ENDMETHOD.
  METHOD warning_semicolon_reset.
    local_fx->result = VALUE #( rate_type = 'M' policy_source = 'TEMP_M' status_code = 'NO_RATE'
                               message = 'Sin cotizacion; detalle API' ).
    run_fx( ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS 'cotizacion, detalle' ) ).
    cut->preload_v2_fx( VALUE #( ) ).
    local_fx->result = VALUE #( available = abap_true multiplier = 5 rate_type = 'M'
                               policy_source = 'TEMP_M' status_code = 'OK' ).
    run_fx( ).
    cl_abap_unit_assert=>assert_initial( line-sim_message ).
  ENDMETHOD.
  METHOD local_technical_warning.
    TEST-INJECTION local_preview_validation.
      RAISE EXCEPTION TYPE cx_sy_zerodivide.
    END-TEST-INJECTION.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = line-net_trans_amt exp = 10 ).
    cl_abap_unit_assert=>assert_initial( line-net_local_amt ).
    cl_abap_unit_assert=>assert_initial( line-exch_rate ).
    cl_abap_unit_assert=>assert_initial( steps[ seq = '02' ]-output_currency ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-CA-FX-API]' ) ).
  ENDMETHOD.
  METHOD execution_cache_reset.
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 1 ).
    cut->preload_v2_fx( VALUE #( ) ).
    run_fx( ).
    cl_abap_unit_assert=>assert_equals( act = local_fx->calls exp = 2 ).
  ENDMETHOD.
  METHOD trans_fixture.
    line-calc_amt = 10. line-bruto_amt = 10. line-tax_amt = 0. line-share_pct = 100.
    steps = VALUE #(
      ( calc_run_id = line-calc_run_id line_num = 1 step_num = '01' seq = '01'
        step_category = zif_reing_ca_c=>step_category-validate output_amt = 10 )
      ( calc_run_id = line-calc_run_id line_num = 2 step_num = '01' seq = '01'
        step_category = zif_reing_ca_c=>step_category-validate output_amt = 999 ) ).
    rt_pc = VALUE #(
      ( calc_run_id = line-calc_run_id line_num = 1 pc_seq = 1 ct_currency = 'USD'
        local_currency = line-local_currency share_abs = 60 calc_amt = 6 bruto_amt = 6 net_amt = 6 )
      ( calc_run_id = line-calc_run_id line_num = 1 pc_seq = 2 ct_currency = 'USD'
        local_currency = line-local_currency share_abs = 40 calc_amt = 4 bruto_amt = 4 net_amt = 4 ) ).
  ENDMETHOD.

  METHOD trans_duplicate_tail.

    DATA(lt_pc) = trans_fixture( ).
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1.
    run_fx( ).

    APPEND steps[ step_num = '05' seq = '01' ] TO steps.
    TRY.
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

        cl_abap_unit_assert=>fail( 'Duplicate primary key in new tail must be rejected' ).
      CATCH zcx_reing_ca_calc_error.
    ENDTRY.
  ENDMETHOD.

  METHOD trans_bounded_index.

    DATA(lt_pc) = trans_fixture( ).
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1.
    run_fx( ).
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

    cl_abap_unit_assert=>assert_equals( exp = 6 act = lt_pc[ 1 ]-net_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 30 act = lt_pc[ 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 10 act = steps[ line_num = 1 step_num = '01' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 999 act = steps[ line_num = 2 ]-output_amt ).
    cl_abap_unit_assert=>assert_initial( steps[ line_num = 2 ]-output_trans_amt ).
  ENDMETHOD.

  METHOD trans_recovers_deleted_index.

    DATA(lt_pc) = trans_fixture( ).
    INSERT VALUE #( calc_run_id = line-calc_run_id line_num = 1 step_num = '05' seq = '01'
      step_category = zif_reing_ca_c=>step_category-fx output_amt = 999 ) INTO steps INDEX 1.
    INSERT VALUE #( calc_run_id = line-calc_run_id line_num = 1 step_num = '05' seq = '02'
      step_category = zif_reing_ca_c=>step_category-fx output_amt = 999 ) INTO steps INDEX 2.
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1.
    run_fx( ).
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

    cl_abap_unit_assert=>assert_equals( exp = 2 act = cut->mv_removed_fx_steps ).
    cl_abap_unit_assert=>assert_equals( exp = 4 act = lines( steps ) ).
    cl_abap_unit_assert=>assert_equals( exp = 10 act = steps[ step_num = '05' seq = '01' ]-output_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 999 act = steps[ line_num = 2 ]-output_amt ).
  ENDMETHOD.

  METHOD trans_foreign_tail_rejected.

    DATA(lt_pc) = trans_fixture( ).
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1.
    run_fx( ).

    APPEND VALUE #( calc_run_id = line-calc_run_id line_num = 2 step_num = '99' seq = '01' ) TO steps.
    TRY.
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

        cl_abap_unit_assert=>fail( ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->mv_message ).
    ENDTRY.
  ENDMETHOD.

  METHOD trans_stale_index_rejected.

    DATA(lt_pc) = trans_fixture( ).
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1.
    run_fx( ).

    lt_index = VALUE #( ( calc_run_id = line-calc_run_id line_num = 1 table_index = 2 ) ).
    TRY.
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

        cl_abap_unit_assert=>fail( ).
      CATCH zcx_reing_ca_calc_error INTO DATA(lx_expected).
        cl_abap_unit_assert=>assert_not_initial( lx_expected->mv_message ).
    ENDTRY.
  ENDMETHOD.

  METHOD trans_compensated_delta.

    DATA(lt_pc) = trans_fixture( ).
    line-is_delta = abap_true. line-calc_amt = 0. line-bruto_amt = 0. line-net_amt = 0.
    lt_pc[ 1 ]-calc_amt = 40. lt_pc[ 2 ]-calc_amt = -40.
    lt_pc[ 1 ]-bruto_amt = 0. lt_pc[ 2 ]-bruto_amt = 0.
    lt_pc[ 1 ]-net_amt = 0. lt_pc[ 2 ]-net_amt = 0.
    steps[ line_num = 1 ]-output_amt = 0.
    primary_mode( 'M' ).
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1. run_fx( ).
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

    cl_abap_unit_assert=>assert_equals( exp = 40 act = lt_pc[ 1 ]-calc_amt ).
    cl_abap_unit_assert=>assert_equals( exp = -40 act = lt_pc[ 2 ]-calc_amt ).
    cl_abap_unit_assert=>assert_initial( lt_pc[ 1 ]-bruto_trans_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = line-net_trans_amt ).
  ENDMETHOD.

  METHOD trans_local_precision_warning.

    line-local_currency = 'KWD'.
    local_fx->result-multiplier = '1.001'.
    DATA(lt_pc) = trans_fixture( ).
    lt_pc[ 1 ]-share_abs = 50. lt_pc[ 2 ]-share_abs = 50.
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1. run_fx( ).
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

    cl_abap_unit_assert=>assert_equals( exp = 10 act = line-net_trans_amt ).
    cl_abap_unit_assert=>assert_initial( line-exch_rate ).
    cl_abap_unit_assert=>assert_initial( lt_pc[ 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_initial( steps[ step_num = '05' seq = '02' ]-output_currency ).
    cl_abap_unit_assert=>assert_true( xsdbool( line-sim_message CS '[BR-CA-FX-PRECISION]' ) ).
  ENDMETHOD.

  METHOD trans_preview_unavailable.

    local_fx->result-available = abap_false. local_fx->result-status_code = 'NO_RATE'.

    DATA(lt_pc) = trans_fixture( ).
    DATA(lt_index) = cut->index_trans_steps( steps ).
    DATA(lv_first) = lines( steps ) + 1.
    run_fx( ).
    cut->propagate_trans( EXPORTING iv_new_from = lv_first
      CHANGING cs_line = line ct_pc = lt_pc ct_steps = steps ct_index = lt_index ).

    cl_abap_unit_assert=>assert_equals( exp = 10 act = line-net_trans_amt ).
    cl_abap_unit_assert=>assert_initial( lt_pc[ 1 ]-net_local_amt ).
    cl_abap_unit_assert=>assert_equals( exp = 10 act = steps[ step_num = '05' seq = '02' ]-output_trans_amt ).
  ENDMETHOD.
ENDCLASS.

" V001 (CC) - A pipeline keeps its captured decision until a new instance.
CLASS ltcl_eba_pipeline DEFINITION DEFERRED.
CLASS zcl_reing_ca_pipeline DEFINITION LOCAL FRIENDS ltcl_eba_pipeline.
CLASS ltcl_eba_pipeline DEFINITION FINAL FOR TESTING DURATION SHORT RISK LEVEL HARMLESS.
  PUBLIC SECTION.
    CLASS-DATA resolved_off TYPE abap_bool.
  PRIVATE SECTION.
    METHODS setup.
    METHODS captures_effective_on FOR TESTING.
    METHODS instance_snapshot_is_stable FOR TESTING.
    METHODS next_instance_refreshes FOR TESTING.
ENDCLASS.
CLASS ltcl_eba_pipeline IMPLEMENTATION.
  METHOD setup.
    resolved_off = abap_false.
    TEST-INJECTION eba_pipeline_switch.
      mv_eba_off = ltcl_eba_pipeline=>resolved_off.
    END-TEST-INJECTION.
  ENDMETHOD.
  METHOD captures_effective_on.
    DATA(cut) = NEW zcl_reing_ca_pipeline( is_context = VALUE #( ) io_sources = NEW ltd_sources_pipe( ) ).
    cl_abap_unit_assert=>assert_false( cut->mv_eba_off ).
  ENDMETHOD.
  METHOD instance_snapshot_is_stable.
    DATA(cut) = NEW zcl_reing_ca_pipeline( is_context = VALUE #( ) io_sources = NEW ltd_sources_pipe( ) ).
    resolved_off = abap_true.
    cl_abap_unit_assert=>assert_false( cut->mv_eba_off ).
  ENDMETHOD.
  METHOD next_instance_refreshes.
    DATA(first) = NEW zcl_reing_ca_pipeline( is_context = VALUE #( ) io_sources = NEW ltd_sources_pipe( ) ).
    resolved_off = abap_true.
    DATA(second) = NEW zcl_reing_ca_pipeline( is_context = VALUE #( ) io_sources = NEW ltd_sources_pipe( ) ).
    cl_abap_unit_assert=>assert_false( first->mv_eba_off ).
    cl_abap_unit_assert=>assert_true( second->mv_eba_off ).
  ENDMETHOD.
ENDCLASS.
