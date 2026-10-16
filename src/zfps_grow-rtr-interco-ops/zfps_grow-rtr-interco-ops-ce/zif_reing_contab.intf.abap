*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 08.07.2026                                          *
* Description    : App CONTAB - Contabilizacion IC - F4 Contrato procesador *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Contrato de la clase procesadora de CONTAB (ET-REING-CONTAB-001 v39 SS6.3).
* NO confundir con ZIF_REING_CONTAB_DISPATCHER (fachada de CA, lado CA).
* Esta es la interface INTERNA de CONTAB: el Engine
* (ZCL_REING_CONTAB_ENGINE) interactua con las clases procesadoras
* (ZCL_REING_CONTAB_DOC y subclases _INT/_RECL) solo a traves de ella.
*
* set_context : recibe los datos de entrada (LINE_A, LINE_PC_A, STEP_A) y
*               el paso del flujo (DOCFLOW_C). Se reutilizan los tipos-tabla
*               ya definidos en ZIF_REING_CA_TYPES (ty_line_pc_t/ty_step_t).
* execute     : procesa el paso segun iv_mode (C=Check, P=Post, S=Storno) y
*               devuelve el resultado de UN paso (ty_step_result).
*               Restriccion modo S: si OP_TYPE tiene AUTO_REVERSAL=X se
*               rechaza (anulacion la gestiona SAP FI). Ver ET SS7.6.2.
* is_applicable: TRUE en la clase padre; subclases la redefinen (INT/RECL).
*----------------------------------------------------------------------*
INTERFACE zif_reing_contab PUBLIC.

  METHODS set_context
    IMPORTING
      is_line_a    TYPE zreing_ca_line_a
      it_line_pc   TYPE zif_reing_ca_types=>ty_line_pc_t
      it_step_a    TYPE zif_reing_ca_types=>ty_step_t
      is_flow_step TYPE zreing_docflow_c
      " V001 (CC) - CB-01: optional, validated nominal posting snapshot.
      is_trans_projection TYPE zif_reing_ca_types=>ty_trans_projection OPTIONAL
      it_currencies TYPE zif_reing_ca_types=>tt_currency_precision OPTIONAL
      " V001 (CC) - bug107 CONTAB: no material lookup inside document processing.
      iv_contract_kostl TYPE kostl OPTIONAL
      " V001 (CC) - #121: no database lookup while building mapped GL items.
      it_campana_map TYPE zif_reing_contab_types=>tt_campana_map OPTIONAL
      " V001 (CC) - #121: exact contractual material, no lookup in processing loops.
      iv_contract_prctr TYPE prctr OPTIONAL
      " V001 (CC) - Effective OFF captured once by the current action.
      iv_eba_off TYPE abap_bool OPTIONAL.

  METHODS execute
    IMPORTING
      iv_mode          TYPE zreing_ca_contab_mode
    RETURNING
      VALUE(rs_result) TYPE zif_reing_contab_types=>ty_step_result.

  METHODS is_applicable
    RETURNING
      VALUE(rv_applicable) TYPE abap_bool.

  "! Inyecta los documentos ya generados en el run actual (en memoria).
  "! Solo lo usa la subclase _RECL, que reclasifica los items del paso
  "! previo: por la optimizacion anti-ATC del Engine (buffer + INSERT unico
  "! al final), esos documentos aun NO estan en BD cuando se evalua el paso
  "! RECL, pero SI estan en memoria. La clase base lo implementa como no-op.
  METHODS set_prior_documents
    IMPORTING
      it_prior_docs TYPE zif_reing_contab_types=>ty_step_result_t.

  "! Inyecta el poster FI (frontera Clean Core <-> BAPIs Tier2). Lo llama el
  "! Engine (que a su vez lo recibio del adapter/test). La clase base guarda
  "! la referencia; call_bapi/reverse_step la usan. Sin poster inyectado, el
  "! posteo/estorno devuelve error controlado.
  METHODS set_fi_poster
    IMPORTING
      io_poster TYPE REF TO zif_reing_contab_fi_poster.

ENDINTERFACE.
