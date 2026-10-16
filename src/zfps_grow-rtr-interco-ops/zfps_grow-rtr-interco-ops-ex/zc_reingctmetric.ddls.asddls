@EndUserText.label: 'CT - Metricas Asignadas Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTMetric
  as projection on ZI_ReingCTMetric
{
  key CtId,
  key Matnr,
  key MetricSeq,
      MetricCode,
      VersionNum,
      Granularity,
      ValidFrom,
      ValidTo,
      MetStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial,
      _Contract : redirected to ZC_ReingCTContract
}
