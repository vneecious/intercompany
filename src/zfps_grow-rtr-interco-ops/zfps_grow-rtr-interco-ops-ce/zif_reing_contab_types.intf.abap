*----------------------------------------------------------------------*
* Created by     : equipo F4 (CONTAB)                                  *
* Requirement N° :                                                     *
* Date           : 08.07.2026                                          *
* Description    : App CONTAB - Contabilizacion IC - F4 Tipos de resultado *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* Tipos de resultado del motor CONTAB (ET-REING-CONTAB-001 v39 SS6.3/SS7.2).
* Dos niveles de resultado, deliberadamente distintos:
*   - ty_step_result  : resultado de UN paso del flujo (1 documento FI).
*   - ty_process_result: resultado consolidado de process_line (todos los
*                        pasos de un LINE_A) -> es el que devuelve el Engine.
* Ambos son internos de CONTAB. El resultado que ve CA es el mas simple
* ZIF_REING_CA_TYPES=>ty_contab_result (success/message/accounting_doc),
* que arma el adapter a partir de ty_process_result.
*
* ABAP Cloud restricted (S/4 2023 PCE): no se permiten data elements no
* released (WERTV8/NUMC7) ni los genericos deprecados (CHAR*/NUMCn). Por
* eso los campos se tipan por REFERENCIA a los campos reales de las tablas
* de CA (mismo criterio que ZIF_REING_CA_TYPES de F0) y a tipos built-in
* (abap.numc / abap.char) donde no hay campo de tabla equivalente.
* Naming DDIC (D-6): tablas persistentes ZREING_CB_DOC_A/_ITEM_A/_TRC_A.
*----------------------------------------------------------------------*
INTERFACE zif_reing_contab_types PUBLIC.

  " V001 (CC) - #121: exact campaign/material mapping, warmed once per action.
  TYPES: BEGIN OF ty_campana_map,
           campana_de TYPE zreing_cmp_map_c-campana_de,
           matnr TYPE zreing_cmp_map_c-matnr,
           campana_para TYPE zreing_cmp_map_c-campana_para,
         END OF ty_campana_map,
         tt_campana_map TYPE HASHED TABLE OF ty_campana_map
           WITH UNIQUE KEY campana_de matnr.

  " V001 (CC) - bug107 CONTAB: exact CT2 material identity, warmed once per action.
  TYPES: BEGIN OF ty_contract_kostl,
           ct_uuid TYPE zreing_ct2_mat_a-ct_uuid,
           mat_uuid TYPE zreing_ct2_mat_a-mat_uuid,
           kostl TYPE zreing_ct2_mat_a-kostl,
           " V001 (CC) - #121: contractual profit center for mapped ZZZ items.
           prctr TYPE zreing_ct2_mat_a-prctr,
         END OF ty_contract_kostl,
         tt_contract_kostl TYPE HASHED TABLE OF ty_contract_kostl
           WITH UNIQUE KEY ct_uuid mat_uuid.

  " ---- Flujo de documentos (pasos de DOCFLOW_C para un OP_TYPE) ----
  " Lo devuelve ZCL_REING_CONTAB_ENGINE~load_flow_config, ordenado por SEQ.
  " Se tipa sobre la tabla real ZREING_DOCFLOW_C (incluye bukrs_rule/override
  " que resolvio PR-01), no sobre el nombre viejo zreing_doc_flow_c de la ET.
  TYPES: ty_flow_t TYPE STANDARD TABLE OF zreing_docflow_c WITH EMPTY KEY.

  " ---- Item BSEG generado (una linea contable del documento FI) ----
  " V001 (CC) - #122: FI line text is independent of the allocation concept.
  TYPES ty_item_text TYPE c LENGTH 50.
  TYPES: BEGIN OF ty_doc_item,
           item_num        TYPE n LENGTH 3,
           role_code       TYPE zreing_role_code,
           posting_context TYPE zreing_posting_context,  " GL / AR / AP -> tabla BAPI
           hkont           TYPE hkont,
           partner         TYPE zc_intercorelationship-providercustomer, " BP AR/AP (D-5)
           posting_side    TYPE shkzg,                    " S=Debe / H=Haber
           amount          TYPE zreing_ca_line_a-net_amt,
           waers           TYPE zreing_ca_line_a-ct_currency,
           kostl           TYPE kostl,
           prctr           TYPE prctr,
           campana         TYPE zreing_campana,
           allocation      TYPE zreing_alloc_type,
           zuonr           TYPE dzuonr,
           item_text       TYPE ty_item_text,
         END OF ty_doc_item,
         ty_doc_item_t TYPE STANDARD TABLE OF ty_doc_item WITH EMPTY KEY.

  " ---- Trace (evento de trazabilidad append-only) ----
  TYPES: BEGIN OF ty_trace,
           trace_seq     TYPE n LENGTH 4,
           trace_typ     TYPE c LENGTH 10,          " STEP_OK/STEP_ERR/STEP_SKIP/...
           doc_type_code TYPE zreing_doc_type_code,
           belnr         TYPE belnr_d,
           message       TYPE c LENGTH 255,
         END OF ty_trace,
         ty_trace_t TYPE STANDARD TABLE OF ty_trace WITH EMPTY KEY.

  " ---- Resultado de UN paso (un documento FI) ----
  TYPES: BEGIN OF ty_step_result,
           doc_type_code TYPE zreing_doc_type_code,
           bukrs         TYPE bukrs,
           belnr         TYPE belnr_d,
           gjahr         TYPE gjahr,
           blart         TYPE blart,
           budat         TYPE budat,
           reversal_date TYPE budat,
           reverse_belnr TYPE belnr_d,
           waers         TYPE zreing_ca_line_a-ct_currency,
           total_amount  TYPE zreing_ca_line_a-net_amt,
           simulated     TYPE abap_bool,
           has_error     TYPE abap_bool,
           error_msg     TYPE c LENGTH 255,
           payload       TYPE string,               " JSON del payload BAPI
           items         TYPE ty_doc_item_t,
           traces        TYPE ty_trace_t,
         END OF ty_step_result,
         ty_step_result_t TYPE STANDARD TABLE OF ty_step_result WITH EMPTY KEY.

  " ---- Rol resuelto para un paso (DOCTYPE_R + GL_ROLES enriquecido) ----
  " Lo devuelve ZCL_REING_CONTAB_DOC~find_roles_for_step. Cada entrada trae
  " todo lo necesario para generar la(s) linea(s) BSEG sin mas lecturas.
  TYPES: BEGIN OF ty_role_resolved,
           role_code       TYPE zreing_role_code,
           posting_side    TYPE shkzg,
           role_category   TYPE zreing_role_cat,
           posting_context TYPE zreing_posting_context,
           tax_type        TYPE zreing_tax_type,
           auto_determ     TYPE zreing_auto_determ,
           reclassify      TYPE zreing_reclassify,
           hkont           TYPE hkont,
         END OF ty_role_resolved,
         ty_role_resolved_t TYPE STANDARD TABLE OF ty_role_resolved WITH EMPTY KEY.

  " ---- Cabecera interna del documento FI (previa al mapeo BAPI) ----
  TYPES: BEGIN OF ty_header,
           bukrs         TYPE bukrs,
           blart         TYPE blart,
           budat         TYPE budat,
           bldat         TYPE budat,
           waers         TYPE waers,
           doc_type_code TYPE zreing_doc_type_code,
           reversal_date TYPE budat,
           reversal_reason TYPE stgrd,
           header_txt    TYPE bktxt,
           " V001 (CC) - CB-02: explicit CT-to-TRANS rate, Cloud-safe contract.
           exch_rate_1 TYPE zreing_ca_line_a-exch_rate_1,
           exch_rate_is_set TYPE abap_bool,
         END OF ty_header.

  " ---- Resultado crudo de la llamada BAPI ----
  TYPES: BEGIN OF ty_bapi_result,
           belnr     TYPE belnr_d,
           gjahr     TYPE gjahr,
           has_error TYPE abap_bool,
           error_msg TYPE c LENGTH 255,
         END OF ty_bapi_result.

  " ---- Resultado consolidado de process_line (lo devuelve el Engine) ----
  TYPES: BEGIN OF ty_process_result,
           calc_run_id TYPE zreing_ca_line_a-calc_run_id,
           line_num    TYPE zreing_ca_line_a-line_num,
           op_type     TYPE zreing_op_type,
           mode        TYPE zreing_ca_contab_mode,  " C=Check / P=Post / S=Storno
           has_error   TYPE abap_bool,
           error_msg   TYPE c LENGTH 255,
           documents   TYPE ty_step_result_t,
         END OF ty_process_result.

ENDINTERFACE.
