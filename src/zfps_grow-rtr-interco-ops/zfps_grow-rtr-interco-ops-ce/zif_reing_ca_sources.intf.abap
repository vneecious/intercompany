*----------------------------------------------------------------------*
* Modified by    : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)      *
* Requirement N° :                                                     *
* Change ID      : V001                                                *
* Date           : 02.07.2026                                          *
* Description    : Reintegro Gastos - Motor de Calculo IC - F0 Fundaciones y DDIC *
* Transport      : DS4K9B5XZC                                          *
* Reference      : 5000049390                                          *
*----------------------------------------------------------------------*
* F2 delta note (06.07.2026): same OT/Solman as F0 -> Change ID V001
* reused (no new header block). F2 is this interface's first real
* consumer (ZCL_REING_CA_SOURCES) — closes 3 gaps from blueprint SS A.4:
* get_me_shares needs the period, get_exchange_rate only ever covered
* type P (split into get_manual_exch_rate/get_average_exch_rate), and TX-02
* needed a prefilter (get_gl_tax_types) plus a granularity bridge
* (get_metric_granularity). get_me_metric is a Developer addition beyond
* the blueprint, required to feed get_metric_granularity — see
* code-summary.md "Desviaciones del Blueprint".
* Iteration #2 (07.07.2026, amendment F2-DD-6): get_ct_identity added —
* Architect-ratified resolution of the ct_uuid/mat_uuid -> ct_id/matnr
* identity gap escalated in Iteration #1.
* Change ID V002 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-06 — added
* get_op_type_permite_delta (OP_TYPE_C.permite_delta bridge) and
* get_cont_baseline (CONT lines of a base group across calc runs, for
* step_delta's baseline/DELTA_SEQ calculation).
* Change ID V003 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-07 — added
* get_cont_line_pc_baseline (LINE_PC_A baseline aggregated by the 4
* dimensions, for one receptora, used by step_pc_split on delta lines).
* get_metric_granularity/get_me_metric become obsolete after CA-07
* (step_pc_split no longer needs GRANULARITY_TYPE) but are left in place
* — no other consumer yet, retiring them is a separate cleanup, not part
* of this change.
* Change ID V004 (03.08.2026 | EXT_GONZALCA): Delta v2 CA-08 — added
* get_cm_recv_filter (BR-CA-44, lista de receptoras participantes desde
* ZREING_CM_RECV_A para el CM elegible del grupo).
* Change ID V005 (05.08.2026 | EXT_GONZALCA): Delta v2 CA-11 — retirados
* get_metric_granularity/get_me_metric (codigo muerto confirmado tras
* CA-07, sin llamador productivo; ver nota V003 arriba).
* Change ID V006 (07.09.2026 | EXT_GONZALCA): get_ct_identity devuelve
* tambien la moneda de cabecera del contrato (campo WAERS agregado a
* ty_ct_identity) - firma sin cambios, cambio documental.
*----------------------------------------------------------------------*
"Begin Insert V001 (CC)
INTERFACE zif_reing_ca_sources PUBLIC.

  METHODS:
    "Begin Mod V001 (CC)
    "get_cm_amount
    "  IMPORTING iv_ct_uuid   TYPE zreing_cm_h_a-ct_uuid
    "            iv_mat_uuid  TYPE zreing_cm_h_a-mat_uuid
    "            iv_op_type   TYPE zreing_cm_h_a-op_type
    "            iv_period    TYPE zreing_ca_run_a-fiscal_period
    "            iv_year      TYPE zreing_ca_run_a-fiscal_year
    "  RETURNING VALUE(rs_cm) TYPE zreing_cm_h_a,
    get_cm_amount
      IMPORTING iv_ct_uuid    TYPE zreing_cm_h_a-ct_uuid
                iv_mat_uuid   TYPE zreing_cm_h_a-mat_uuid
                iv_op_type    TYPE zreing_cm_h_a-op_type
                iv_period     TYPE zreing_ca_run_a-fiscal_period
                iv_year       TYPE zreing_ca_run_a-fiscal_year
                iv_cm_h_id    TYPE zreing_cm_h_a-cm_h_id OPTIONAL
                iv_op_instance_num TYPE zreing_op_instance_num OPTIONAL
      RETURNING VALUE(rs_cm)  TYPE zreing_cm_h_a
      RAISING   zcx_reing_ca_calc_error,   " F2: no eligible LIBD row found
    "End Mod V001 (CC)

    "Begin Mod V001 (CC)
    "get_me_shares
    "  IMPORTING iv_ct_id        TYPE zreing_me_h_a-ct_id
    "            iv_matnr        TYPE zreing_me_h_a-matnr
    "  RETURNING VALUE(rt_items) TYPE zif_reing_ca_types=>ty_me_item_t,
    get_me_shares
      IMPORTING iv_ct_id        TYPE zreing_me_h_a-ct_id
                iv_matnr        TYPE zreing_me_h_a-matnr
                iv_period_year  TYPE zreing_me_h_a-period_year    " F2 (was missing, F2-H3)
                iv_period_month TYPE zreing_me_h_a-period_month   " F2
      RETURNING VALUE(rt_items) TYPE zif_reing_ca_types=>ty_me_item_t
      RAISING   zcx_reing_ca_calc_error,
    "End Mod V001 (CC)

    get_ct_option
      IMPORTING iv_op_uuid    TYPE zreing_ct2_opt_a-op_uuid
      RETURNING VALUE(rs_opt) TYPE zreing_ct2_opt_a,

    "Begin Insert V001 (CC)
    get_gl_tax_types                                                  " F2: TX-02 prefilter
      IMPORTING iv_ct_uuid           TYPE zreing_ct2_gl_a-ct_uuid
                iv_mat_uuid          TYPE zreing_ct2_gl_a-mat_uuid
      RETURNING VALUE(rt_tax_types)  TYPE zif_reing_ca_types=>ty_tax_type_t,
    "End Insert V001 (CC)

    get_tx_rules
      IMPORTING iv_country      TYPE zreing_tx_rule_a-country
                iv_gross_up     TYPE zreing_tx_rule_a-gross_up
      RETURNING VALUE(rt_rules) TYPE zif_reing_ca_types=>ty_tx_rule_t,

    "Begin Mod V001 (CC)
    "get_exchange_rate
    "  IMPORTING iv_type          TYPE zreing_exrt_type
    "            iv_from_currency TYPE waers
    "            iv_to_currency   TYPE waers
    "            iv_date          TYPE dats
    "  RETURNING VALUE(rv_rate)   TYPE zreing_ca_line_a-exch_rate.
    get_manual_exch_rate                                              " F2: replaces get_exchange_rate, type M half
      IMPORTING iv_ct_uuid         TYPE zreing_ct_o_r_a-ct_uuid
                iv_mat_uuid        TYPE zreing_ct_o_r_a-mat_uuid
                iv_op_type         TYPE zreing_ct_o_r_a-op_type
                iv_op_uuid         TYPE zreing_ct_o_r_a-op_uuid
                iv_op_instance_num TYPE zreing_ct_o_r_a-op_instance_num
                iv_bukrs_recv      TYPE zreing_ct_o_r_a-bukrs_recv
      RETURNING VALUE(rv_rate)     TYPE zreing_ct_o_r_a-manual_exch_rate
      RAISING   zcx_reing_ca_calc_error,

    get_average_exch_rate                                             " F2: replaces get_exchange_rate, type P half
      IMPORTING iv_from_currency TYPE waers
                iv_to_currency   TYPE waers
                iv_date          TYPE d
      RETURNING VALUE(rv_rate)   TYPE zreing_ca_line_a-exch_rate
      RAISING   zcx_reing_ca_calc_error,
    "End Mod V001 (CC)

    "Begin Insert V001 (CC)
    " Change ID V006 (07.09.2026 | EXT_GONZALCA): the returned structure also
    " carries WAERS, the contract HEADER currency (ZREING_CT2_A-WAERS) - the
    " authoritative CT_CURRENCY source for the pipeline's Path B1. Signature
    " unchanged: the field was added to ty_ct_identity (V006).
    get_ct_identity                                                   " F2: amendment F2-DD-6 (SS9.3) — ct_uuid/mat_uuid identity bridge
      IMPORTING iv_ct_uuid          TYPE zreing_ct2_a-ct_uuid
                iv_mat_uuid         TYPE zreing_ct2_mat_a-mat_uuid
      RETURNING VALUE(rs_identity) TYPE zif_reing_ca_types=>ty_ct_identity
      RAISING   zcx_reing_ca_calc_error,
    "End Insert V001 (CC)

    "Begin Insert V002 (03.08.2026 | EXT_GONZALCA)
    " Delta v2 CA-06: bridge para step_delta.
    get_op_type_permite_delta
      IMPORTING iv_op_type              TYPE zreing_op_type_c-op_type
      RETURNING VALUE(rv_permite_delta) TYPE abap_bool,

    get_cont_baseline                                                 " CA-06: LINE_As CONT del grupo base (todos los calc_run_id), para baseline/DELTA_SEQ
      IMPORTING iv_ct_uuid       TYPE zreing_ca_line_a-ct_uuid
                iv_mat_uuid      TYPE zreing_ca_line_a-mat_uuid
                iv_op_type       TYPE zreing_ca_line_a-op_type
                iv_op_uuid       TYPE zreing_ca_line_a-op_uuid
                iv_period_year   TYPE zreing_ca_run_a-fiscal_year
                iv_period_month  TYPE zreing_ca_run_a-fiscal_period
      RETURNING VALUE(rt_lines) TYPE zif_reing_ca_types=>ty_line_t,
    "End Insert V002 (03.08.2026 | EXT_GONZALCA)

    "Begin Insert V003 (03.08.2026 | EXT_GONZALCA)
    " Delta v2 CA-07: baseline de LINE_PC_A por las 4 dimensiones para una
    " receptora puntual, usado por step_pc_split en lineas IS_DELTA.
    get_cont_line_pc_baseline
      IMPORTING iv_ct_uuid      TYPE zreing_ca_line_a-ct_uuid
                iv_mat_uuid     TYPE zreing_ca_line_a-mat_uuid
                iv_op_type      TYPE zreing_ca_line_a-op_type
                iv_op_uuid      TYPE zreing_ca_line_a-op_uuid
                iv_bukrs_recv   TYPE zreing_ca_line_a-bukrs_recv
                iv_period_year  TYPE zreing_ca_run_a-fiscal_year
                iv_period_month TYPE zreing_ca_run_a-fiscal_period
      RETURNING VALUE(rt_pc)    TYPE zif_reing_ca_types=>ty_line_pc_t,
    "End Insert V003 (03.08.2026 | EXT_GONZALCA)

    "Begin Insert V004 (03.08.2026 | EXT_GONZALCA)
    " Delta v2 CA-08: BR-CA-44 -- lista de receptoras participantes desde
    " ZREING_CM_RECV_A para el CM elegible del grupo. Tabla vacia = sin
    " restriccion (comportamiento actual, sin filtro).
    get_cm_recv_filter
      IMPORTING iv_ct_uuid      TYPE zreing_cm_h_a-ct_uuid
                iv_mat_uuid     TYPE zreing_cm_h_a-mat_uuid
                iv_op_type      TYPE zreing_cm_h_a-op_type
                iv_period       TYPE zreing_ca_run_a-fiscal_period
                iv_year         TYPE zreing_ca_run_a-fiscal_year
                iv_cm_h_id      TYPE zreing_cm_h_a-cm_h_id OPTIONAL
                iv_op_instance_num TYPE zreing_op_instance_num OPTIONAL
      RETURNING VALUE(rt_bukrs) TYPE zif_reing_ca_types=>ty_bukrs_t
      RAISING   zcx_reing_ca_calc_error.
    "End Insert V004 (03.08.2026 | EXT_GONZALCA)

ENDINTERFACE.
"End Insert V001 (CC)
