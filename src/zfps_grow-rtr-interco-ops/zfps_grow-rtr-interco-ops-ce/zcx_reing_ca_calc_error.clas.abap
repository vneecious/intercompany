*----------------------------------------------------------------------*
* Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Date           : 06.07.2026                                          *
* Description    : App CA - Motor de Calculo - F2 Pipeline + Estrategias + Insumo Manager *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Single domain exception for the calculation pipeline (blueprint SS6.4).
* Raised for a bounded, line/group-scoped business rule violation: no
* eligible CM_H_A row (LIBD), no eligible ME_H_A metric, missing manual
* FX rate for a receptor, future FX/TX reference period, inconsistent
* op_type customizing (Factory dispatch), or ambiguous TX scoring
* (exact score tie, BR-CA-03). ZCL_REING_CA_PIPELINE.execute() catches it
* per group/line and marks that line CALC_ERR instead of aborting the
* whole scope (P-07) — see ZCL_REING_CA_PIPELINE.
*----------------------------------------------------------------------*
CLASS zcx_reing_ca_calc_error DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    DATA mv_message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING iv_message TYPE string
                previous   TYPE REF TO cx_root OPTIONAL.

ENDCLASS.

CLASS zcx_reing_ca_calc_error IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_message = iv_message.
  ENDMETHOD.

ENDCLASS.

