@EndUserText.label: 'CT V2 - Tipos Operacion Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

// Autor  : EXT_OSCUGALD
// Fecha  : 04.06.2026
// Cambio : OpUuid como key, composiciones restauradas

define view entity ZC_ReingCTOpType2
  as projection on ZI_ReingCTOpType2
{
  key CtUuid,
  key MatUuid,
  key OpType,
  key OpUuid,
      OpInstanceNum,
      OpTypeDescr,
      ExchRateDescr,
      ExchRateType,
      OpSubtype,
      DeferFrom,
      DeferTo,
      DistType,
      MePeriodOffset,
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
      _Material : redirected to parent ZC_ReingCTMaterial2,
      _Contract : redirected to ZC_ReingCTContract2,
      _Cron     : redirected to composition child ZC_ReingCTCron2,
      _OpRates  : redirected to composition child ZC_ReingCTOpRate2
}
