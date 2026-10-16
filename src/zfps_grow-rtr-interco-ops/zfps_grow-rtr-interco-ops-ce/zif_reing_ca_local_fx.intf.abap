" V001 (CC) - Local currency conversion with an isolated standard boundary.
INTERFACE zif_reing_ca_local_fx PUBLIC.
  " Compatibility aliases; ZIF_REING_CA_TYPES owns the canonical layout.
  TYPES ty_amount TYPE zif_reing_ca_types=>ty_local_fx_amount.
  TYPES ty_multiplier TYPE zif_reing_ca_types=>ty_local_fx_multiplier.
  TYPES ty_status TYPE zif_reing_ca_types=>ty_local_fx_status.
  TYPES ty_policy_source TYPE zif_reing_ca_types=>ty_local_fx_policy.
  TYPES ty_result TYPE zif_reing_ca_types=>ty_local_fx_result.

  " Compatibility names for existing consumers; C owns the values.
  CONSTANTS: BEGIN OF status,
               ok        TYPE ty_status VALUE zif_reing_ca_c=>fx_local_status-ok,
               no_rate   TYPE ty_status VALUE zif_reing_ca_c=>fx_local_status-no_rate,
               precision TYPE ty_status VALUE zif_reing_ca_c=>fx_local_status-precision,
               range     TYPE ty_status VALUE zif_reing_ca_c=>fx_local_status-range,
               api       TYPE ty_status VALUE zif_reing_ca_c=>fx_local_status-api,
               config    TYPE ty_status VALUE zif_reing_ca_c=>fx_local_status-config,
             END OF status.
  CONSTANTS: BEGIN OF policy,
               temporary_m TYPE ty_policy_source VALUE zif_reing_ca_c=>fx_local_policy-temporary_m,
               no_op       TYPE ty_policy_source VALUE zif_reing_ca_c=>fx_local_policy-no_op,
             END OF policy.

  METHODS convert_trans_to_local
    IMPORTING
      iv_company_code   TYPE bukrs
      iv_trans_currency TYPE waers
      iv_local_currency TYPE waers
      iv_date           TYPE d
      iv_amount_trans   TYPE ty_amount
      iv_decimals_trans TYPE i
      iv_decimals_local TYPE i
    RETURNING VALUE(rs_result) TYPE ty_result.
ENDINTERFACE.
