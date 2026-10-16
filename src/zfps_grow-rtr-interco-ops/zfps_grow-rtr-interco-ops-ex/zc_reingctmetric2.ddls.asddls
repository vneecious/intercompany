@EndUserText.label: 'CT V2 - Metricas Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

// Autor  : AGF
// Fecha  : 18.06.2026
// P7 - Exponer MetricDesc via asociacion a VH

define view entity ZC_ReingCTMetric2
  as projection on ZI_ReingCTMetric2
{
  key CtUuid,
  key MatUuid,
  key MetUuid,
      MetricSeq,
      MetricCode,
      VersionNum,
      _MetricVH.MetricDesc as MetricDesc,
      ValidFrom,
      ValidTo,
      MetStatus,  
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial2,
      _Contract : redirected to ZC_ReingCTContract2,
      _MetricVH
}
