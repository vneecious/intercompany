*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Change ID      : V001                                                *
* Date           : 11.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* F2-DD-12 (blueprint SS6.13/SS9.5): first-ever modification of this F0
* object — the active source (created cleanly in F0, never re-touched
* since) carries no prior Change ID header, so V001 is added fresh here
* (Change ID rule: "sin cabecera previa -> agregar V001"), same OT/Solman
* as the rest of F0/F2 (DS4K9B5XZC / 5000049390), confirmed live by the
* Architect, not assumed.
*
* Real bug found by the Code Reviewer's own SAPDiagnose(unittest) run:
* load_base did not declare RAISING zcx_reing_ca_calc_error, so
* ZCL_REING_CA_OPTYPE_CM~load_base (F2, calls
* mo_sources->get_cm_amount(...), which DOES declare RAISING) could not
* propagate the exception cleanly — breaks P-07 (error isolation per
* group) for the whole Path A/CM (F/P/A/NC/ANT). Confirmed live
* (SAPDiagnose syntax/unittest): only load_base needed the change —
* is_credit_note/fx_rate_type/expand_mode call nothing that declares
* RAISING, so they stay untouched. ZCL_REING_CA_OPTYPE_DEFER/_AN2 adopt
* this interface in block (INTERFACES zif_reing_ca_optype.), so they
* inherit the new signature automatically without any source change —
* they only need reactivation. ZCL_REING_CA_PIPELINE needs no change
* either — step_01_validate already declares RAISING and execute()
* already wraps each group in TRY/CATCH; the missing link was only this
* interface. See technical-blueprint.md SS9.5 for the full analysis.
*----------------------------------------------------------------------*
INTERFACE zif_reing_ca_optype PUBLIC.

  METHODS:
    "Begin Mod V001 (CC)
    "load_base
    "  IMPORTING is_line          TYPE zreing_ca_line_a
    "  RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-base_amt,
    load_base
      IMPORTING is_line          TYPE zreing_ca_line_a
      RETURNING VALUE(rv_amount) TYPE zreing_ca_line_a-base_amt
      RAISING   zcx_reing_ca_calc_error,
    "End Mod V001 (CC)

    is_credit_note
      IMPORTING is_line        TYPE zreing_ca_line_a
      RETURNING VALUE(rv_flag) TYPE abap_bool,

    fx_rate_type
      IMPORTING is_line        TYPE zreing_ca_line_a
      RETURNING VALUE(rv_type) TYPE zreing_exrt_type,

    expand_mode
      IMPORTING is_line        TYPE zreing_ca_line_a
      RETURNING VALUE(rv_mode) TYPE zreing_ca_row_type.

ENDINTERFACE.
