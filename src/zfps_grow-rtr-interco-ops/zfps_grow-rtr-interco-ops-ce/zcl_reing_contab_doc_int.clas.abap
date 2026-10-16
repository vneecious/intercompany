*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : App CONTAB - Procesadora Interdivisional (INT)      *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Subclase de ZCL_REING_CONTAB_DOC para pasos interdivisionales
* (DOC_TYPE_CODE = INT / ACTINT). Config en DOCTYPE_C.PROCESSING_CLASS.
*
* Solo redefine is_applicable: el paso interdivisional aplica UNICAMENTE
* cuando prestadora = receptora (misma sociedad). Toda la logica de
* procesamiento (build_header/build_items/call_bapi/...) vive en la clase
* padre y NO se redefine (ET SS8a, SS11.2).
*----------------------------------------------------------------------*
CLASS zcl_reing_contab_doc_int DEFINITION
  PUBLIC
  INHERITING FROM zcl_reing_contab_doc
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_reing_contab~is_applicable REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_reing_contab_doc_int IMPLEMENTATION.

  METHOD zif_reing_contab~is_applicable.
    " V001 (CC) - CB-01: preserve INT routing; use the selected monetary base.
    rv_applicable = abap_false.
    IF ms_line_a-bukrs_prest <> ms_line_a-bukrs_recv. RETURN. ENDIF.
    rv_applicable = super->zif_reing_contab~is_applicable( ).
  ENDMETHOD.

ENDCLASS.


