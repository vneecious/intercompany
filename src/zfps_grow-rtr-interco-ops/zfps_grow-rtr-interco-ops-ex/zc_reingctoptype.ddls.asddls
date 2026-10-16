@EndUserText.label: 'CT - Tipos de Operacion Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTOpType
  as projection on ZI_ReingCTOpType
{
  key CtId,
  key Matnr,
  key OpType,
      OpSubtype,
      DeferFrom,
      DeferTo,
      DistType,
      Installments,
      ExchType,
      ExchRate,
      Waers,
      TotalPct,
      OpStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial,
      _Contract : redirected to ZC_ReingCTContract,
      _Cron     : redirected to composition child ZC_ReingCTCron
}
