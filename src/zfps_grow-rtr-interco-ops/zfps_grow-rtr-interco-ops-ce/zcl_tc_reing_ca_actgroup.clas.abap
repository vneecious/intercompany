*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
* Requirement N° :
* Date           : 09.09.2026
* Description    : CA - Entidad agregada CAActionGroup para dialogos de acciones
* Transport      : DS4K9B5XZC
* Reference      : S 5000049390
*----------------------------------------------------------------------*
* Drift guard between the two controlled copies of the Can* rules (Decision D3):
*   - authoritative : lcl_reing_ca_dml_buffer=>allowed_source_status / check_scope
*                     in ZBP_REINGCARUN, plus the per-handler scope validation
*   - read mirror   : ZI_ReingCAActGrpLine / ZI_ReingCAActionGroup
* Without this test the second copy would be unacceptable, because the divergence
* would be silent.
*
* Scope note (see code-summary.md): allowed_source_status lives in a LOCAL class of a
* behavior pool, so it cannot be called from a global class, and ZBP_REINGCARUN must
* not be touched in this delivery. CU-D01 and CU-D02 are therefore asserted against
* zif_reing_ca_c, the constant interface that BOTH copies consume - which is where a
* rename or a value change would actually surface.
*
* ATC ZMELI_CLEAN_CORE_V3: nested LOOP is a P2 finding and blocks the release. All
* iteration below uses DO ... TIMES + READ TABLE ... INDEX.
*----------------------------------------------------------------------*
"! <p class="shorttext synchronized">CA - Unit tests of the aggregated action group</p>
"! Test relation for the ATC check "ABAP Unit / test relation" (P2, blocks release).
"! The object under test is the aggregated entity doubled in class_setup( ) and read
"! by when_group_is_read( ). No category prefix: DDLS: and STOB: are both rejected
"! with "Object in category ... is unknown"; the bare object name is what resolves.
"! @testing ZI_REINGCAACTIONGROUP
CLASS zcl_tc_reing_ca_actgroup DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    TYPES:
      ty_status_tab TYPE STANDARD TABLE OF zreing_ca_line_status WITH EMPTY KEY,
      BEGIN OF ty_group_row,
        can_calculate      TYPE abap_boolean,
        can_release        TYPE abap_boolean,
        can_simulate       TYPE abap_boolean,
        can_post           TYPE abap_boolean,
        can_storno         TYPE abap_boolean,
        can_delete         TYPE abap_boolean,
        is_processing      TYPE abap_boolean,
        is_orphan          TYPE abap_boolean,
        group_status_key   TYPE c LENGTH 20,
        status_criticality TYPE i,
        line_count         TYPE i,
        receiver_count     TYPE i,
        orphan_line_count  TYPE i,
        min_bukrs_recv     TYPE bukrs,
        max_bukrs_recv     TYPE bukrs,
      END OF ty_group_row.

    CONSTANTS:
      " Literal sets replicated in ZI_ReingCAActGrpLine. Keep in sync with the
      " authoritative matrix in ZBP_REINGCARUN.
      BEGIN OF cds_mirror,
        release_1  TYPE zreing_ca_line_status VALUE 'CALC',
        release_2  TYPE zreing_ca_line_status VALUE 'SIM_OK',
        simulate_1 TYPE zreing_ca_line_status VALUE 'CALC',
        simulate_2 TYPE zreing_ca_line_status VALUE 'SIM_ERR',
        post_1     TYPE zreing_ca_line_status VALUE 'LIBD',
        post_2     TYPE zreing_ca_line_status VALUE 'POST_ERR',
        storno_1   TYPE zreing_ca_line_status VALUE 'CONT',
        storno_2   TYPE zreing_ca_line_status VALUE 'POST_ERR',
        storno_3   TYPE zreing_ca_line_status VALUE 'ANUL_ERR',
        block_1    TYPE zreing_ca_line_status VALUE 'CALC_PROC',
        block_2    TYPE zreing_ca_line_status VALUE 'SIM_PROC',
        block_3    TYPE zreing_ca_line_status VALUE 'POST_PROC',
        block_4    TYPE zreing_ca_line_status VALUE 'ANUL_PROC',
      END OF cds_mirror.

    CONSTANTS:
      c_run_id      TYPE c LENGTH 20      VALUE 'RUN-202609',
      c_year        TYPE n LENGTH 4       VALUE '2026',
      c_period      TYPE n LENGTH 2       VALUE '09',
      c_op_type     TYPE zreing_op_type   VALUE 'P',
      c_ct_id       TYPE c LENGTH 10      VALUE 'CT0000001',
      c_matnr       TYPE matnr            VALUE 'MAT-0001',
      c_ct_uuid     TYPE sysuuid_x16      VALUE '11111111111111111111111111111111',
      c_mat_uuid    TYPE sysuuid_x16      VALUE '22222222222222222222222222222222',
      c_op_uuid     TYPE sysuuid_x16      VALUE '33333333333333333333333333333333',
      c_cm_h_id     TYPE sysuuid_x16      VALUE '44444444444444444444444444444444',
      c_me_h_id     TYPE sysuuid_x16      VALUE '55555555555555555555555555555555'.

    " PEND has no counterpart in zif_reing_ca_c=>line_status: the behavior pool never
    " writes it, it is produced as a literal by the B branches of ZI_ReingCAActGrpLine.
    " Branch A still maps it (StatusCriticality 'PEND' -> 0), which is what CU-S01 and
    " CU-S13 exercise, so it is declared locally instead of being faked as a mirror.
    CONSTANTS c_status_pend TYPE zreing_ca_line_status VALUE 'PEND'.

    " parent_type values of zreing_op_type_c that resolve expand mode B2 (S10).
    CONSTANTS c_parent_type_a TYPE zreing_op_type_c-parent_type VALUE 'A'.

    CLASS-DATA mo_cds_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.

    METHODS setup.
    METHODS teardown.

    " CU-D01 / CU-D02 - rule drift guard
    METHODS rules_match_allowed_status  FOR TESTING.
    METHODS blocking_status_set_is_frozen FOR TESTING.

    " CU-E01..CU-E17 - eligibility over test doubles
    METHODS can_flags_over_test_doubles FOR TESTING RAISING cx_static_check.

    " CU-E02, CU-E04, CU-E05, CU-E07, CU-E14 - eligibility, one method per scenario
    METHODS can_release_calc_and_sim_ok  FOR TESTING RAISING cx_static_check.
    METHODS can_simulate_on_sim_err      FOR TESTING RAISING cx_static_check.
    METHODS can_post_uniform_libd        FOR TESTING RAISING cx_static_check.
    METHODS can_storno_uniform_cont      FOR TESTING RAISING cx_static_check.
    METHODS no_calculate_b2_without_pend FOR TESTING RAISING cx_static_check.

    " CU-S01..CU-S14 - aggregated status precedence
    METHODS status_aggregation_precedence FOR TESTING RAISING cx_static_check.

    " CU-S01, CU-S03, CU-S04, CU-S07, CU-S08, CU-S13, CU-S14 - one method per scenario
    METHODS status_uniform_pend         FOR TESTING RAISING cx_static_check.
    METHODS status_uniform_sim_ok       FOR TESTING RAISING cx_static_check.
    METHODS status_uniform_libd         FOR TESTING RAISING cx_static_check.
    METHODS status_partial_sim_mix      FOR TESTING RAISING cx_static_check.
    METHODS status_partial_cont_pst_err FOR TESTING RAISING cx_static_check.
    METHODS status_calc_proc_over_pend  FOR TESTING RAISING cx_static_check.
    METHODS status_post_proc_wins       FOR TESTING RAISING cx_static_check.

    " CU-R01 / CU-R02 - receiver aggregation
    METHODS receiver_counts_are_distinct FOR TESTING RAISING cx_static_check.

    METHODS all_anuld_is_terminal FOR TESTING RAISING cx_static_check.
    METHODS all_anul_err_retry_only FOR TESTING RAISING cx_static_check.
    METHODS partial_anul_is_red FOR TESTING RAISING cx_static_check.
    METHODS post_err_allows_storno FOR TESTING RAISING cx_static_check.


    " V001 (CC) - #115 (Delta v2): read-side lifecycle regression.
    METHODS no_calc_posted_group FOR TESTING RAISING cx_static_check.
    METHODS no_calc_released_group FOR TESTING RAISING cx_static_check.
    METHODS no_calc_post_error_group FOR TESTING RAISING cx_static_check.
    METHODS no_calc_mixed_calc_cont FOR TESTING RAISING cx_static_check.
    METHODS no_calc_mixed_simok_libd FOR TESTING RAISING cx_static_check.
    METHODS no_calc_partial_posting FOR TESTING RAISING cx_static_check.
    METHODS calculate_calc_is_preserved FOR TESTING RAISING cx_static_check.
    METHODS calculate_simok_is_preserved FOR TESTING RAISING cx_static_check.
    METHODS calculate_pend_cm_preserved FOR TESTING RAISING cx_static_check.
    METHODS calculate_pend_b2_preserved FOR TESTING RAISING cx_static_check.
    METHODS calculate_errors_preserved FOR TESTING RAISING cx_static_check.
    METHODS posted_base_pending_delta FOR TESTING RAISING cx_static_check.

    " ---- helpers -----------------------------------------------------
    " Builds one persisted group whose lines carry the given statuses, one line per
    " receiving company code, and puts the supporting master data in place.
    METHODS given_group
      IMPORTING it_status      TYPE ty_status_tab
                iv_cm_libd     TYPE abap_boolean DEFAULT abap_true
                iv_me_libd     TYPE abap_boolean DEFAULT abap_true
                iv_active      TYPE abap_boolean DEFAULT abap_true
                iv_loadable    TYPE abap_boolean DEFAULT abap_true
                iv_parent_type TYPE zreing_op_type_c-parent_type DEFAULT space.

    METHODS when_group_is_read
      RETURNING VALUE(rs_group) TYPE ty_group_row.

ENDCLASS.


CLASS zcl_tc_reing_ca_actgroup IMPLEMENTATION.

  METHOD class_setup.
    " Begin Mod V002 (09.09.2026 | EXT_GONZALCA)
    " Default parameters on purpose. For a unit test the framework builds doubles for
    " the FIRST-LEVEL dependencies of the entity under test only -- here the views
    " ZI_ReingCAActGrpLine and ZI_ReingCAActGrpRecv -- and given_group( ) feeds
    " exactly those.
    " Do NOT add i_select_base_dependencies = abap_true to reach the base tables: it
    " walks the hierarchy down to T001 and TKA02 and dies in CLASS_SETUP with
    " "Creation of test doubles is not permitted for T001 , TKA02", taking the whole
    " class down (0 tests executed). SAP documents that parameter as not to be used
    " for unit tests.
    mo_cds_env = cl_cds_test_environment=>create( i_for_entity = 'ZI_REINGCAACTIONGROUP' ).
    " End Mod V002 (09.09.2026 | EXT_GONZALCA)
  ENDMETHOD.

  METHOD class_teardown.
    mo_cds_env->destroy( ).
  ENDMETHOD.

  METHOD setup.
    mo_cds_env->clear_doubles( ).
  ENDMETHOD.

  METHOD teardown.
    mo_cds_env->clear_doubles( ).
  ENDMETHOD.

  METHOD rules_match_allowed_status.
    " CU-D01. The CDS mirror must keep quoting the very same status values that the
    " behavior pool consumes through zif_reing_ca_c. A rename or a value change on
    " either side lands here.
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-release_1  exp = zif_reing_ca_c=>line_status-calc
      msg = 'CanRelease mirror drifted from zif_reing_ca_c-line_status-calc' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-release_2  exp = zif_reing_ca_c=>line_status-sim_ok
      msg = 'CanRelease mirror drifted from zif_reing_ca_c-line_status-sim_ok' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-simulate_1 exp = zif_reing_ca_c=>line_status-calc
      msg = 'CanSimulate mirror drifted from zif_reing_ca_c-line_status-calc' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-simulate_2 exp = zif_reing_ca_c=>line_status-sim_err
      msg = 'CanSimulate mirror drifted from zif_reing_ca_c-line_status-sim_err' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-post_1     exp = zif_reing_ca_c=>line_status-libd
      msg = 'CanPost mirror drifted from zif_reing_ca_c-line_status-libd' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-post_2     exp = zif_reing_ca_c=>line_status-post_err
      msg = 'CanPost mirror drifted from zif_reing_ca_c-line_status-post_err' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-storno_1   exp = zif_reing_ca_c=>line_status-cont
      msg = 'CanStorno mirror drifted from zif_reing_ca_c-line_status-cont' ).
  ENDMETHOD.

  METHOD blocking_status_set_is_frozen.
    " CU-D02. The blocking set of the CDS must be exactly the set check_scope uses.
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-block_1 exp = zif_reing_ca_c=>line_status-calc_proc
      msg = 'IsProcessing mirror drifted from line_status-calc_proc' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-block_2 exp = zif_reing_ca_c=>line_status-sim_proc
      msg = 'IsProcessing mirror drifted from line_status-sim_proc' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-block_3 exp = zif_reing_ca_c=>line_status-post_proc
      msg = 'IsProcessing mirror drifted from line_status-post_proc' ).
    cl_abap_unit_assert=>assert_equals(
      act = cds_mirror-block_4 exp = zif_reing_ca_c=>line_status-anul_proc
      msg = 'IsProcessing mirror drifted from line_status-anul_proc' ).
  ENDMETHOD.

  METHOD can_flags_over_test_doubles.

    " Scenario reset: clear_doubles( ) is called directly instead of setup( ).
    " ABAP Unit reserves SETUP as a special method and forbids calling it from test
    " code ("The special method SETUP cannot be called directly").

    " CU-E01 - all lines CALC, no orphans, nothing in progress.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_e01) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e01-can_release  exp = abap_true  msg = 'CU-E01 CanRelease' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e01-can_simulate exp = abap_true  msg = 'CU-E01 CanSimulate' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e01-can_post     exp = abap_false msg = 'CU-E01 CanPost' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e01-can_storno   exp = abap_false msg = 'CU-E01 CanStorno' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e01-can_delete   exp = abap_false msg = 'CU-E01 CanDelete' ).

    " CU-E03 - CALC + LIBD. Key scenario of the FOR-ALL / EXISTS asymmetry:
    " Release needs every line admitted, Simulate and Post only need one.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-libd ) ) ).
    DATA(ls_e03) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e03-can_release  exp = abap_false msg = 'CU-E03 CanRelease must be false (for-all fails)' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e03-can_simulate exp = abap_true  msg = 'CU-E03 CanSimulate must be true (exists CALC)' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e03-can_post     exp = abap_true  msg = 'CU-E03 CanPost must be true (exists LIBD)' ).

    " CU-E06 - CONT + POST_ERR.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-cont )
                          ( zif_reing_ca_c=>line_status-post_err ) ) ).
    DATA(ls_e06) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e06-can_post    exp = abap_true  msg = 'CU-E06 CanPost' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e06-can_storno  exp = abap_true  msg = 'CU-E06 CanStorno' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e06-can_release exp = abap_false msg = 'CU-E06 CanRelease' ).

    " CU-E08 - one line in progress disables every action.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_proc )
                          ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_e08) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-is_processing exp = abap_true  msg = 'CU-E08 IsProcessing' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-can_calculate exp = abap_false msg = 'CU-E08 CanCalculate' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-can_release   exp = abap_false msg = 'CU-E08 CanRelease' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-can_simulate  exp = abap_false msg = 'CU-E08 CanSimulate' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-can_post      exp = abap_false msg = 'CU-E08 CanPost' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-can_storno    exp = abap_false msg = 'CU-E08 CanStorno' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e08-can_delete    exp = abap_false msg = 'CU-E08 CanDelete' ).

    " CU-E09 - fully orphan group: Delete yes, Release no ("use Delete instead").
    " Orphan means cm_loadable op_type with no CM row for the period, so removing
    " the CM row makes every line of the group orphan at once.
    mo_cds_env->clear_doubles( ).
    given_group( it_status  = VALUE #( ( zif_reing_ca_c=>line_status-calc )
                                       ( zif_reing_ca_c=>line_status-calc ) )
                 iv_cm_libd = abap_false ).
    DATA(ls_e09) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e09-can_delete        exp = abap_true  msg = 'CU-E09 CanDelete' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e09-can_release       exp = abap_false msg = 'CU-E09 CanRelease' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e09-is_orphan         exp = abap_true  msg = 'CU-E09 IsOrphan' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e09-orphan_line_count exp = ls_e09-line_count
                                        msg = 'CU-E09 OrphanLineCount' ).

    " CU-E10 (mixed orphan scope) is NOT covered here on purpose: IsOrphan is derived
    " from (ct_uuid, mat_uuid, op_type, period) only, so it is identical for every
    " line of a group and OrphanLineCount can only be 0 or LineCount. A mixed scope
    " is unreachable through this data model - reported in code-summary.md so the
    " reviewer and QA can decide whether the scenario is real at all.

    " CU-E12 - op_type not active: the factory never dispatches it.
    mo_cds_env->clear_doubles( ).
    given_group( it_status = VALUE #( ( zif_reing_ca_c=>line_status-calc ) )
                 iv_active = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-can_calculate
                                        exp = abap_false msg = 'CU-E12 CanCalculate with inactive op_type' ).

    " CU-E13 - neither cm_loadable nor a parent_type that resolves an expand mode.
    mo_cds_env->clear_doubles( ).
    given_group( it_status   = VALUE #( ( zif_reing_ca_c=>line_status-calc ) )
                 iv_loadable = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-can_calculate
                                        exp = abap_false msg = 'CU-E13 CanCalculate without expand mode' ).

    " CU-E15 - the CM of the period is no longer LIBD: check_insumos fails.
    mo_cds_env->clear_doubles( ).
    given_group( it_status  = VALUE #( ( zif_reing_ca_c=>line_status-calc ) )
                 iv_cm_libd = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-can_calculate
                                        exp = abap_false msg = 'CU-E15 CanCalculate without CM LIBD' ).

    " CU-E16 - metric not in LIBD (H2): listed, but Calculate would reject it.
    mo_cds_env->clear_doubles( ).
    given_group( it_status  = VALUE #( ( zif_reing_ca_c=>line_status-calc ) )
                 iv_me_libd = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-can_calculate
                                        exp = abap_false msg = 'CU-E16 CanCalculate without ME LIBD' ).

    " CU-E17 - recalculation of a persisted CALC group with sound inputs.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc ) ) ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-can_calculate
                                        exp = abap_true msg = 'CU-E17 CanCalculate on recalculation' ).

  ENDMETHOD.


  METHOD can_release_calc_and_sim_ok.
    " CU-E02 - CALC + SIM_OK: both are admitted source states of Release, so the
    " FOR-ALL quantifier still holds even though the group is not uniform.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-sim_ok ) ) ).
    DATA(ls_e02) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e02-can_release      exp = abap_true  msg = 'CU-E02 CanRelease' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e02-can_simulate     exp = abap_true  msg = 'CU-E02 CanSimulate (exists CALC)' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e02-can_post         exp = abap_false msg = 'CU-E02 CanPost' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e02-group_status_key exp = 'parcial'  msg = 'CU-E02 GroupStatusKey' ).
  ENDMETHOD.

  METHOD can_simulate_on_sim_err.
    " CU-E04 - SIM_OK + SIM_ERR: Release fails the FOR-ALL because SIM_ERR is not an
    " admitted source state, Simulate holds because SIM_ERR is retriable.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_ok )
                          ( zif_reing_ca_c=>line_status-sim_err ) ) ).
    DATA(ls_e04) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e04-can_release  exp = abap_false msg = 'CU-E04 CanRelease' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e04-can_simulate exp = abap_true  msg = 'CU-E04 CanSimulate (exists SIM_ERR)' ).
  ENDMETHOD.

  METHOD can_post_uniform_libd.
    " CU-E05 - every line released: Post is the only action left.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-libd )
                          ( zif_reing_ca_c=>line_status-libd ) ) ).
    DATA(ls_e05) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e05-can_post     exp = abap_true  msg = 'CU-E05 CanPost' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e05-can_release  exp = abap_false msg = 'CU-E05 CanRelease' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e05-can_simulate exp = abap_false msg = 'CU-E05 CanSimulate' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e05-can_storno   exp = abap_false msg = 'CU-E05 CanStorno' ).
  ENDMETHOD.

  METHOD can_storno_uniform_cont.
    " CU-E07 - every line posted: Storno yes, Post no (CONT is not a Post source).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-cont )
                          ( zif_reing_ca_c=>line_status-cont ) ) ).
    DATA(ls_e07) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_e07-can_storno exp = abap_true  msg = 'CU-E07 CanStorno' ).
    cl_abap_unit_assert=>assert_equals( act = ls_e07-can_post   exp = abap_false msg = 'CU-E07 CanPost' ).
  ENDMETHOD.

  METHOD no_calculate_b2_without_pend.
    " CU-E14 - expand mode B2 (op_type not cm_loadable but with parent_type 'A') and
    " no PEND line: Path B/C requires at least one PEND line, so Calculate is off.
    " The scenario is only reachable over persisted lines: the B-2 branch of
    " ZI_ReingCAActGrpLine emits LineStatus 'PEND' as a literal, so a pending B-2 row
    " always carries PendFlag = 1 and could never model "B2 without PEND".
    given_group( it_status      = VALUE #( ( zif_reing_ca_c=>line_status-calc ) )
                 iv_loadable    = abap_false
                 iv_parent_type = c_parent_type_a ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-can_calculate
                                        exp = abap_false msg = 'CU-E14 CanCalculate on B2 without PEND lines' ).
  ENDMETHOD.

  METHOD status_aggregation_precedence.

    " Scenario reset: clear_doubles( ) is called directly instead of setup( ).
    " ABAP Unit reserves SETUP as a special method and forbids calling it from test
    " code ("The special method SETUP cannot be called directly").

    " CU-S02 - uniform CALC.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_s02) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s02-group_status_key   exp = 'CALC' msg = 'CU-S02 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s02-status_criticality exp = 2      msg = 'CU-S02 StatusCriticality' ).

    " CU-S05 - uniform CONT.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-cont ) ) ).
    DATA(ls_s05) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s05-group_status_key   exp = 'CONT' msg = 'CU-S05 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s05-status_criticality exp = 3      msg = 'CU-S05 StatusCriticality' ).

    " CU-S06 - mixed CALC + SIM_ERR is partial, not error.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-sim_err ) ) ).
    DATA(ls_s06) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s06-group_status_key   exp = 'parcial' msg = 'CU-S06 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s06-status_criticality exp = 2         msg = 'CU-S06 StatusCriticality' ).

    " CU-S09 - every line in a terminal error status.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_err )
                          ( zif_reing_ca_c=>line_status-sim_err ) ) ).
    DATA(ls_s09) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s09-group_status_key   exp = 'error' msg = 'CU-S09 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s09-status_criticality exp = 1       msg = 'CU-S09 StatusCriticality' ).

    " CU-S10 - all terminal errors but of different kinds: still error, not partial.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc_err )
                          ( zif_reing_ca_c=>line_status-post_err ) ) ).
    DATA(ls_s10) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s10-group_status_key   exp = 'error' msg = 'CU-S10 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s10-status_criticality exp = 1       msg = 'CU-S10 StatusCriticality' ).

    " CU-S11 - processing wins over every other precedence level.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_proc )
                          ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_s11) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s11-group_status_key   exp = 'procesando' msg = 'CU-S11 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s11-status_criticality exp = 0            msg = 'CU-S11 StatusCriticality' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s11-is_processing      exp = abap_true    msg = 'CU-S11 IsProcessing' ).

    " CU-S12 - ANUL_PROC also wins, even over a CONT majority.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-anul_proc )
                          ( zif_reing_ca_c=>line_status-cont ) ) ).
    cl_abap_unit_assert=>assert_equals( act = when_group_is_read( )-group_status_key
                                        exp = 'procesando' msg = 'CU-S12 GroupStatusKey' ).

  ENDMETHOD.


  METHOD status_uniform_pend.
    " CU-S01 - every line PEND: neutral criticality and nothing in progress.
    given_group( VALUE #( ( c_status_pend )
                          ( c_status_pend ) ) ).
    DATA(ls_s01) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s01-group_status_key   exp = 'PEND'    msg = 'CU-S01 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s01-status_criticality exp = 0         msg = 'CU-S01 StatusCriticality' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s01-is_processing      exp = abap_false msg = 'CU-S01 IsProcessing' ).
  ENDMETHOD.

  METHOD status_uniform_sim_ok.
    " CU-S03 - uniform SIM_OK.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_ok )
                          ( zif_reing_ca_c=>line_status-sim_ok ) ) ).
    DATA(ls_s03) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s03-group_status_key   exp = 'SIM_OK' msg = 'CU-S03 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s03-status_criticality exp = 3        msg = 'CU-S03 StatusCriticality' ).
  ENDMETHOD.

  METHOD status_uniform_libd.
    " CU-S04 - uniform LIBD.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-libd )
                          ( zif_reing_ca_c=>line_status-libd ) ) ).
    DATA(ls_s04) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s04-group_status_key   exp = 'LIBD' msg = 'CU-S04 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s04-status_criticality exp = 3      msg = 'CU-S04 StatusCriticality' ).
  ENDMETHOD.

  METHOD status_partial_sim_mix.
    " CU-S07 - SIM_OK + SIM_ERR: not every line is in error, so it is partial and the
    " criticality of a mixed group is 2, never the 1 of the failing line.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_ok )
                          ( zif_reing_ca_c=>line_status-sim_err ) ) ).
    DATA(ls_s07) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s07-group_status_key   exp = 'parcial' msg = 'CU-S07 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s07-status_criticality exp = 2         msg = 'CU-S07 StatusCriticality' ).
  ENDMETHOD.

  METHOD status_partial_cont_pst_err.
    " CU-S08 - CONT + POST_ERR.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-cont )
                          ( zif_reing_ca_c=>line_status-post_err ) ) ).
    DATA(ls_s08) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s08-group_status_key   exp = 'parcial' msg = 'CU-S08 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s08-status_criticality exp = 2         msg = 'CU-S08 StatusCriticality' ).
  ENDMETHOD.

  METHOD status_calc_proc_over_pend.
    " CU-S13 - CALC_PROC over PEND lines: processing wins over the uniform branch.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc_proc )
                          ( c_status_pend ) ) ).
    DATA(ls_s13) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s13-group_status_key   exp = 'procesando' msg = 'CU-S13 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s13-status_criticality exp = 0            msg = 'CU-S13 StatusCriticality' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s13-is_processing      exp = abap_true    msg = 'CU-S13 IsProcessing' ).
  ENDMETHOD.

  METHOD status_post_proc_wins.
    " CU-S14 - POST_PROC over an otherwise released group.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-post_proc )
                          ( zif_reing_ca_c=>line_status-libd ) ) ).
    DATA(ls_s14) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_s14-group_status_key   exp = 'procesando' msg = 'CU-S14 GroupStatusKey' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s14-status_criticality exp = 0            msg = 'CU-S14 StatusCriticality' ).
    cl_abap_unit_assert=>assert_equals( act = ls_s14-is_processing      exp = abap_true    msg = 'CU-S14 IsProcessing' ).
  ENDMETHOD.

  METHOD receiver_counts_are_distinct.

    " Scenario reset: clear_doubles( ) is called directly instead of setup( ).
    " ABAP Unit reserves SETUP as a special method and forbids calling it from test
    " code ("The special method SETUP cannot be called directly").

    " CU-R01 - three receivers produce one group row with ReceiverCount = 3.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-calc )
                          ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_r01) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_r01-receiver_count exp = 3 msg = 'CU-R01 ReceiverCount' ).
    cl_abap_unit_assert=>assert_equals( act = ls_r01-line_count     exp = 3 msg = 'CU-R01 LineCount' ).
    cl_abap_unit_assert=>assert_differs( act = ls_r01-min_bukrs_recv exp = ls_r01-max_bukrs_recv
                                         msg = 'CU-R01 Min/MaxBukrsRecv' ).

    " CU-R02 - a single receiver: Min and Max collapse.
    mo_cds_env->clear_doubles( ).
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_r02) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_r02-receiver_count exp = 1 msg = 'CU-R02 ReceiverCount' ).
    cl_abap_unit_assert=>assert_equals( act = ls_r02-min_bukrs_recv exp = ls_r02-max_bukrs_recv
                                        msg = 'CU-R02 Min = Max' ).

  ENDMETHOD.



  METHOD all_anuld_is_terminal.
    given_group( it_status = VALUE #( ( 'ANULD' ) ( 'ANULD' ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-group_status_key exp = 'ANULD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-status_criticality exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-can_storno exp = abap_false ).
    cl_abap_unit_assert=>assert_false( ls_group-can_calculate ).
    cl_abap_unit_assert=>assert_false( ls_group-can_release ).
    cl_abap_unit_assert=>assert_false( ls_group-can_simulate ).
    cl_abap_unit_assert=>assert_false( ls_group-can_post ).
    cl_abap_unit_assert=>assert_false( ls_group-can_delete ).
  ENDMETHOD.


  METHOD all_anul_err_retry_only.
    given_group( it_status = VALUE #( ( 'ANUL_ERR' ) ( 'ANUL_ERR' ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-group_status_key exp = 'ANUL_ERR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-status_criticality exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-can_storno exp = abap_true ).
    cl_abap_unit_assert=>assert_false( ls_group-can_calculate ).
    cl_abap_unit_assert=>assert_false( ls_group-can_release ).
    cl_abap_unit_assert=>assert_false( ls_group-can_simulate ).
    cl_abap_unit_assert=>assert_false( ls_group-can_post ).
    cl_abap_unit_assert=>assert_false( ls_group-can_delete ).
  ENDMETHOD.


  METHOD partial_anul_is_red.
    given_group( it_status = VALUE #( ( 'ANULD' ) ( 'ANUL_ERR' ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-group_status_key exp = 'ANUL_PARTIAL' ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-status_criticality exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-can_storno exp = abap_true ).
    cl_abap_unit_assert=>assert_false( ls_group-can_calculate ).
    cl_abap_unit_assert=>assert_false( ls_group-can_release ).
    cl_abap_unit_assert=>assert_false( ls_group-can_simulate ).
    cl_abap_unit_assert=>assert_false( ls_group-can_post ).
    cl_abap_unit_assert=>assert_false( ls_group-can_delete ).
  ENDMETHOD.


  METHOD post_err_allows_storno.
    given_group( it_status = VALUE #( ( 'POST_ERR' ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-group_status_key exp = 'error' ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-status_criticality exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_group-can_storno exp = abap_true ).

  ENDMETHOD.

  METHOD no_calc_posted_group.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-cont ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_false ).
  ENDMETHOD.

  METHOD no_calc_released_group.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-libd ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_false ).
  ENDMETHOD.

  METHOD no_calc_post_error_group.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-post_err ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_false ).
  ENDMETHOD.

  METHOD no_calc_mixed_calc_cont.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc ) ( zif_reing_ca_c=>line_status-cont ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_false ).
  ENDMETHOD.

  METHOD no_calc_mixed_simok_libd.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_ok ) ( zif_reing_ca_c=>line_status-libd ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_false ).
  ENDMETHOD.

  METHOD no_calc_partial_posting.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-cont ) ( zif_reing_ca_c=>line_status-post_err ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_false ).
  ENDMETHOD.

  METHOD calculate_calc_is_preserved.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_true ).
  ENDMETHOD.

  METHOD calculate_simok_is_preserved.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-sim_ok ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_true ).
  ENDMETHOD.

  METHOD calculate_pend_cm_preserved.
    given_group( VALUE #( ( c_status_pend ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_true ).
  ENDMETHOD.

  METHOD calculate_pend_b2_preserved.
    given_group( it_status = VALUE #( ( c_status_pend ) )
      iv_loadable = abap_false iv_parent_type = c_parent_type_a ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_true ).
  ENDMETHOD.

  METHOD calculate_errors_preserved.
    given_group( VALUE #( ( zif_reing_ca_c=>line_status-calc_err ) ( zif_reing_ca_c=>line_status-sim_err ) ) ).
    DATA(ls_group) = when_group_is_read( ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_group-can_calculate exp = abap_true ).
  ENDMETHOD.

  METHOD posted_base_pending_delta.
    " Both loads share business dimensions; CM_H_ID keeps eligibility independent.
    CONSTANTS c_delta_cm TYPE sysuuid_x16 VALUE '66666666666666666666666666666666'.
    DATA lt_lines TYPE STANDARD TABLE OF zi_reingcaactgrpline WITH EMPTY KEY.
    lt_lines = VALUE #(
      ( ctuuid = c_ct_uuid matuuid = c_mat_uuid optype = c_op_type opuuid = c_op_uuid
        cmhid = c_cm_h_id bukrsrecv = '2001' periodyear = c_year periodmonth = c_period
        calcrunid = c_run_id rowtype = 'A' ctid = c_ct_id bukrsprest = 'MUR'
        linestatus = 'CONT' expandmode = 'B1' expandokflag = 1 cmeligflag = 1 meeligflag = 1 )
      ( ctuuid = c_ct_uuid matuuid = c_mat_uuid optype = c_op_type opuuid = c_op_uuid
        cmhid = c_delta_cm bukrsrecv = '2001' periodyear = c_year periodmonth = c_period
        rowtype = 'B1' ctid = c_ct_id bukrsprest = 'MUR' isdelta = 'X' deltaseq = '01'
        linestatus = 'PEND' pendflag = 1 expandmode = 'B1' expandokflag = 1 cmeligflag = 1 meeligflag = 1 ) ).
    mo_cds_env->insert_test_data( lt_lines ).
    SELECT CmHId, CanCalculate FROM zi_reingcaactiongroup
      WHERE CtUuid = @c_ct_uuid AND MatUuid = @c_mat_uuid
        AND OpType = @c_op_type AND OpUuid = @c_op_uuid
        AND PeriodYear = @c_year AND PeriodMonth = @c_period
      INTO TABLE @DATA(lt_groups).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_groups ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( lt_groups[ CmHId = c_cm_h_id ]-CanCalculate ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_groups[ CmHId = c_delta_cm ]-CanCalculate exp = abap_true ).
  ENDMETHOD.

  METHOD given_group.

    " Begin Mod V002 (09.09.2026 | EXT_GONZALCA)
    " Feeds the double of ZI_ReingCAActGrpLine -- the FIRST-LEVEL dependency of the
    " entity under test -- instead of the base tables one level below, which a unit
    " test never gets doubles for (see class_setup).
    " Every flag below is derived exactly as branch A of ZI_ReingCAActGrpLine derives
    " it, so the scenarios keep modelling persisted groups and the parameters keep
    " the same meaning they had when they fed zreing_ca_line_a & friends.
    DATA lt_line        TYPE STANDARD TABLE OF zi_reingcaactgrpline WITH EMPTY KEY.
    DATA lv_expand_mode TYPE c LENGTH 2.

    " ---- op_type customizing: constant for the whole group ---------------
    " ExpandMode   'B1' = active + cm_loadable / 'B2' = active + parent_type A|ANT
    " ExpandOkFlag active AND ( cm_loadable OR parent_type A|ANT )
    DATA(lv_b2_parent) = xsdbool( iv_parent_type = 'A' OR iv_parent_type = 'ANT' ).

    lv_expand_mode = COND #(
      WHEN iv_active = abap_true AND iv_loadable  = abap_true THEN 'B1'
      WHEN iv_active = abap_true AND lv_b2_parent = abap_true THEN 'B2'
      ELSE space ).

    DATA(lv_expand_ok) = COND i(
      WHEN iv_active = abap_true
       AND ( iv_loadable = abap_true OR lv_b2_parent = abap_true ) THEN 1
      ELSE 0 ).

    " OrphanFlag: cm_loadable op_type with no CM row for the period. iv_cm_libd
    " decides whether that CM row exists at all, so it drives both the orphan
    " predicate and CmEligFlag -- the very coupling the base tables produced, kept
    " deliberately so CU-E09 and CU-E15 keep meaning what they meant.
    DATA(lv_orphan) = COND i(
      WHEN iv_loadable = abap_true AND iv_cm_libd = abap_false THEN 1 ELSE 0 ).

    DATA(lv_cm_elig) = COND i( WHEN iv_cm_libd = abap_true THEN 1 ELSE 0 ).
    DATA(lv_me_elig) = COND i( WHEN iv_me_libd = abap_true THEN 1 ELSE 0 ).

    " Constant inside the group, so the max( ) that carries it up is a no-op.
    DATA(lv_group_key) = |{ c_ct_id } 1000 { c_matnr } { c_op_type } 001|.

    " One line per receiving company code. DO ... TIMES instead of a nested LOOP:
    " nested loops are a P2 finding of ZMELI_CLEAN_CORE_V3 and block the release.
    DATA(lv_lines) = lines( it_status ).
    DO lv_lines TIMES.
      DATA(lv_idx) = sy-index.
      READ TABLE it_status INDEX lv_idx INTO DATA(lv_status).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      " ---- status-derived flags, verbatim from branch A ------------------
      DATA(lv_proc) = COND i(
        WHEN lv_status = zif_reing_ca_c=>line_status-calc_proc
          OR lv_status = zif_reing_ca_c=>line_status-sim_proc
          OR lv_status = zif_reing_ca_c=>line_status-post_proc
          OR lv_status = zif_reing_ca_c=>line_status-anul_proc THEN 1 ELSE 0 ).

      DATA(lv_err) = COND i(
        WHEN lv_status = zif_reing_ca_c=>line_status-calc_err
          OR lv_status = zif_reing_ca_c=>line_status-sim_err
          OR lv_status = zif_reing_ca_c=>line_status-post_err
          OR lv_status = zif_reing_ca_c=>line_status-anul_err THEN 1 ELSE 0 ).

      DATA(lv_rel_ok) = COND i(
        WHEN lv_status = zif_reing_ca_c=>line_status-calc
          OR lv_status = zif_reing_ca_c=>line_status-sim_ok THEN 1 ELSE 0 ).

      DATA(lv_sim_ok) = COND i(
        WHEN lv_status = zif_reing_ca_c=>line_status-calc
          OR lv_status = zif_reing_ca_c=>line_status-sim_err THEN 1 ELSE 0 ).

      DATA(lv_post_ok) = COND i(
        WHEN lv_status = zif_reing_ca_c=>line_status-libd
          OR lv_status = zif_reing_ca_c=>line_status-post_err THEN 1 ELSE 0 ).

      DATA(lv_storno_ok) = COND i(
        WHEN lv_status = zif_reing_ca_c=>line_status-cont
          OR lv_status = zif_reing_ca_c=>line_status-post_err
          OR lv_status = zif_reing_ca_c=>line_status-anul_err THEN 1 ELSE 0 ).

      DATA(lv_pend) = COND i( WHEN lv_status = c_status_pend THEN 1 ELSE 0 ).

      " 0 neutral / 1 error / 2 warning / 3 success.
      DATA(lv_criticality) = SWITCH i( lv_status
        WHEN c_status_pend                          THEN 0
        WHEN zif_reing_ca_c=>line_status-sim_err    THEN 1
        WHEN zif_reing_ca_c=>line_status-calc_err   THEN 1
        WHEN zif_reing_ca_c=>line_status-post_err   THEN 1
        WHEN zif_reing_ca_c=>line_status-anul_err   THEN 1
        WHEN zif_reing_ca_c=>line_status-anuld      THEN 1
        WHEN zif_reing_ca_c=>line_status-calc       THEN 2
        WHEN zif_reing_ca_c=>line_status-sim_ok     THEN 3
        WHEN zif_reing_ca_c=>line_status-libd       THEN 3
        WHEN zif_reing_ca_c=>line_status-cont       THEN 3
        ELSE 0 ).

      APPEND VALUE #( ctuuid            = c_ct_uuid
                      matuuid           = c_mat_uuid
                      optype            = c_op_type
                      opuuid            = c_op_uuid
                      bukrsrecv         = |{ 2000 + lv_idx }|
                      periodyear        = c_year
                      periodmonth       = c_period

                      rowtype           = 'A'
                      calcrunid         = c_run_id

                      ctid              = c_ct_id
                      lifnr             = '0000100000'
                      bpname            = 'BP TEST'
                      bukrsprest        = '1000'
                      matnr             = c_matnr
                      opinstancenum     = '001'
                      country           = 'AR'
                      isdelta           = space
                      deltaseq          = '00'
                      groupkey          = lv_group_key

                      linestatus        = lv_status
                      statuscriticality = lv_criticality
                      isorphan          = COND #( WHEN lv_orphan = 1 THEN 'X' ELSE space )

                      isprocflag        = lv_proc
                      iserrflag         = lv_err
                      relokflag         = lv_rel_ok
                      simokflag         = lv_sim_ok
                      postokflag        = lv_post_ok
                      stornookflag      = lv_storno_ok
                      orphanflag        = lv_orphan
                      pendflag          = lv_pend

                      expandmode        = lv_expand_mode
                      expandokflag      = COND #( WHEN lv_status = zif_reing_ca_c=>line_status-anuld
                        OR lv_status = zif_reing_ca_c=>line_status-anul_err THEN 0 ELSE lv_expand_ok )
                      cmeligflag        = lv_cm_elig
                      meeligflag        = lv_me_elig ) TO lt_line.
    ENDDO.

    mo_cds_env->insert_test_data( lt_line ).
    " End Mod V002 (09.09.2026 | EXT_GONZALCA)

  ENDMETHOD.

  METHOD when_group_is_read.

    DATA lt_group TYPE STANDARD TABLE OF ty_group_row WITH EMPTY KEY.

    " INTO CORRESPONDING FIELDS OF matches by exact component name and the underscore
    " is significant, so every CDS element is aliased to its snake_case counterpart in
    " ty_group_row. Without the aliases not a single field would be filled.
    SELECT FROM zi_reingcaactiongroup
      FIELDS CanCalculate      AS can_calculate,
             CanRelease        AS can_release,
             CanSimulate       AS can_simulate,
             CanPost           AS can_post,
             CanStorno         AS can_storno,
             CanDelete         AS can_delete,
             IsProcessing      AS is_processing,
             IsOrphan          AS is_orphan,
             GroupStatusKey    AS group_status_key,
             StatusCriticality AS status_criticality,
             LineCount         AS line_count,
             ReceiverCount     AS receiver_count,
             OrphanLineCount   AS orphan_line_count,
             MinBukrsRecv      AS min_bukrs_recv,
             MaxBukrsRecv      AS max_bukrs_recv
      WHERE CtUuid  = @c_ct_uuid
        AND MatUuid = @c_mat_uuid
        AND OpType  = @c_op_type
        AND OpUuid  = @c_op_uuid
      INTO CORRESPONDING FIELDS OF TABLE @lt_group.

    " The WHERE does not restrict PeriodYear / PeriodMonth / CalcRunId, which are also
    " part of the key of the entity. Reading the row count instead of a SELECT SINGLE
    " keeps an accidentally split group from passing green on an arbitrary row.
    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_group )
      exp = 1
      msg = 'The actionable group entity must return exactly one row for the test group' ).

    READ TABLE lt_group INDEX 1 INTO rs_group.
    cl_abap_unit_assert=>assert_subrc( act = sy-subrc
                                       msg = 'The actionable group entity returned no row for the test group' ).

  ENDMETHOD.

ENDCLASS.

