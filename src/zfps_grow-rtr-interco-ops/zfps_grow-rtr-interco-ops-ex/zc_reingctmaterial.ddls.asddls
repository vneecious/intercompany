@EndUserText.label: 'CT - Material IC Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTMaterial
  as projection on ZI_ReingCTMaterial
{
  key CtId,
  key Matnr,
      MatDesc,
      Amount,
      Waers,
      Kostl,
      Prctr,
      Saknr,
      MatStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Contract  : redirected to parent ZC_ReingCTContract,
      _OpTypes   : redirected to composition child ZC_ReingCTOpType,
      _Receivers : redirected to composition child ZC_ReingCTReceiver,
      _Metrics   : redirected to composition child ZC_ReingCTMetric,
      _GLLines   : redirected to composition child ZC_ReingCTGL
}
