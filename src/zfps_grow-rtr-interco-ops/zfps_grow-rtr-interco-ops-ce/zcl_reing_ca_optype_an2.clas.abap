*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Strategy Path C (AN2, cronograma-like, cm_loadable blank, parent_type
* ='ANT', exch='P', blueprint SS6.8). No constructor — does not talk to
* Sources. load_base is a literal 1:1 copy of the parent ANT's NET_AMT
* (confirmed against ET-REING-CONTAB-001_v39 SS8b.4, no proration).
*----------------------------------------------------------------------*
CLASS zcl_reing_ca_optype_an2 DEFINITION PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_reing_ca_optype.

ENDCLASS.

CLASS zcl_reing_ca_optype_an2 IMPLEMENTATION.

  METHOD zif_reing_ca_optype~load_base.
    rv_amount = is_line-parent_net_amt.  " literal copy, no proration
  ENDMETHOD.

  METHOD zif_reing_ca_optype~is_credit_note.
    rv_flag = abap_false.  " 'AN2' is never 'NC' (blueprint SS6.8, confirmed).
  ENDMETHOD.

  METHOD zif_reing_ca_optype~fx_rate_type.
    rv_type = 'P'.
  ENDMETHOD.

  METHOD zif_reing_ca_optype~expand_mode.
    rv_mode = zif_reing_ca_c=>row_type-defer_pending.  " 'B2'
  ENDMETHOD.

ENDCLASS.

