@EndUserText.label: 'Proposal Items GLAccount - CECO on BRF'
@ClientHandling.type: #CLIENT_DEPENDENT
@ClientHandling.algorithm: #SESSION_VARIABLE
define table function zi_CostCenterCode_brf
  with parameters
    @Environment.systemField: #CLIENT
    i_mandt          : abap.clnt,
    i_product        : matnr,
    i_cconsolidation : zint_cc_cons
returns
{
  mandt          : mandt;
  product        : matnr;
  ccconsolidation : zint_cc_cons;
  CostCenterCode : zde_cc_code;

}
implemented by method
  zcl_interco_brf_wht=>get_ampd_cc_code;
