*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 14.07.2026                                          *
* Description    : App CONTAB - Contabilizacion IC - F4 Excepcion dominio *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Excepcion unica de dominio del motor CONTAB (ET-REING-CONTAB-001 v39
* SS7.4). Se lanza ante errores de configuracion o de pre-condicion que
* impiden procesar la linea: sin flujo en DOCFLOW_C para el OP_TYPE,
* PROCESSING_CLASS inexistente en DOCTYPE_C, LINE_STATUS incoherente con
* el modo (gatekeeping), o anulacion manual sobre op_type con
* AUTO_REVERSAL. El Engine la traduce a ty_process_result-error_msg;
* el adapter la mapea a ty_contab_result-message para CA.
*
* Mismo patron que ZCX_REING_CA_CALC_ERROR (F2): dominio unico, mensaje
* string libre, cadena de causa opcional.
*----------------------------------------------------------------------*
CLASS zcx_reing_contab DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA mv_message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        iv_message TYPE string
        previous   TYPE REF TO cx_root OPTIONAL.

ENDCLASS.

CLASS zcx_reing_contab IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    mv_message = iv_message.
  ENDMETHOD.

ENDCLASS.

