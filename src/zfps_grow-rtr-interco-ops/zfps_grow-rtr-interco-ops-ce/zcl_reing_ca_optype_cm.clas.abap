*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Strategy Path A (cm_loadable = 'X': F/P/A/NC/ANT, blueprint SS6.6).
* BASE_AMT comes from the monthly CM charge via Sources — the only
* strategy that needs io_sources/is_context (F2-AD-1), because it is the
* only one that talks to an external source at all.
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_optype_cm DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_optype.

    METHODS constructor
      IMPORTING io_sources TYPE REF TO zif_reing_ca_sources
                is_context TYPE zif_reing_ca_types=>ty_context.

  PRIVATE SECTION.
    DATA mo_sources TYPE REF TO zif_reing_ca_sources.
    DATA ms_context TYPE zif_reing_ca_types=>ty_context.

ENDCLASS.

CLASS zcl_reing_ca_optype_cm IMPLEMENTATION.

  METHOD constructor.
    mo_sources = io_sources.
    ms_context = is_context.
  ENDMETHOD.

  METHOD zif_reing_ca_optype~load_base.
    " Propagates zcx_reing_ca_calc_error from get_cm_amount when no
    " eligible ZREING_CM_H_A row (LIBD) exists for ct/mat/op_type/period.
    DATA(ls_cm) = mo_sources->get_cm_amount(
                    iv_ct_uuid  = is_line-ct_uuid
                    iv_mat_uuid = is_line-mat_uuid
                    iv_op_type  = is_line-op_type
                    iv_period   = ms_context-period
                    iv_year     = ms_context-year
                    iv_cm_h_id  = is_line-cm_h_id ).
    rv_amount = ls_cm-amount.
  ENDMETHOD.

  METHOD zif_reing_ca_optype~is_credit_note.
    " Only literal tolerated outside ZIF_REING_CA_C (blueprint SS6.6/C.2):
    " 'NC' has no catalog flag of its own. Detection only — the actual
    " sign inversion of CALC_AMT (BR-CA-05) is applied by
    " ZCL_REING_CA_PIPELINE=>step_02_distribute, not here.
    rv_flag = xsdbool( is_line-op_type = 'NC' ).
  ENDMETHOD.

  METHOD zif_reing_ca_optype~fx_rate_type.
    DATA(ls_opt) = mo_sources->get_ct_option( iv_op_uuid = is_line-op_uuid ).
    rv_type = ls_opt-exch_rate_type.
    IF rv_type IS INITIAL.
      " Fallback to the op_type catalog default — CT2_OPT_A can leave
      " exch_rate_type blank for options that inherit the catalog default.
      SELECT SINGLE default_exch_rate_type
        FROM zreing_op_type_c
        WHERE op_type = @is_line-op_type
        INTO @rv_type.
    ENDIF.
  ENDMETHOD.

  METHOD zif_reing_ca_optype~expand_mode.
    rv_mode = zif_reing_ca_c=>row_type-cm_pending.  " 'B1'
  ENDMETHOD.

ENDCLASS.

