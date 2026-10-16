*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Strategy Path B (D, cronograma, cm_loadable blank, parent_type='A',
* exch='H', blueprint SS6.7). No constructor — does not talk to Sources,
* load_base is pure arithmetic over fields step_02_distribute already
* resolved on the line (parent LINE_A + ZREING_CT2_CRN_A.percentage).
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_optype_defer DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_optype.

ENDCLASS.

CLASS zcl_reing_ca_optype_defer IMPLEMENTATION.

  METHOD zif_reing_ca_optype~load_base.
    rv_amount = is_line-parent_net_amt * is_line-defer_pct / 100.
  ENDMETHOD.

  METHOD zif_reing_ca_optype~is_credit_note.
    rv_flag = abap_false.  " 'D' is never 'NC' (blueprint SS6.7, confirmed).
  ENDMETHOD.

  METHOD zif_reing_ca_optype~fx_rate_type.
    rv_type = 'H'.  " Inherited from the parent — constant, catalog-independent.
  ENDMETHOD.

  METHOD zif_reing_ca_optype~expand_mode.
    rv_mode = zif_reing_ca_c=>row_type-defer_pending.  " 'B2'
  ENDMETHOD.

ENDCLASS.

