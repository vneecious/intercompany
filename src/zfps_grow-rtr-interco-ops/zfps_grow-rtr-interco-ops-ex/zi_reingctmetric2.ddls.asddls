@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - Metricas Asignadas'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

// Autor  : AGF
// Fecha  : 18.06.2026
// P7 - Asociacion a ZI_ReingCTMetricVH para obtener MetricDesc

define view entity ZI_ReingCTMetric2
  as select from zreing_ct2_met_a
  association     to parent ZI_ReingCTMaterial2 as _Material
    on  _Material.CtUuid  = $projection.CtUuid
    and _Material.MatUuid = $projection.MatUuid
  association [1] to ZI_ReingCTContract2 as _Contract
    on _Contract.CtUuid = $projection.CtUuid
  association [0..1] to ZI_ReingCTMetricVH as _MetricVH
    on  _MetricVH.MetricCode = $projection.MetricCode
    and _MetricVH.VersionNum = $projection.VersionNum
{
  key ct_uuid           as CtUuid,
  key mat_uuid          as MatUuid,
  key met_uuid          as MetUuid,
      metric_seq        as MetricSeq,
      metric_code       as MetricCode,
      version_num       as VersionNum,
      valid_from        as ValidFrom,
      valid_to          as ValidTo,
      met_status        as MetStatus,
      @Semantics.user.createdBy: true
      created_by        as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at        as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by        as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at        as ChangedAt,
      _Material,
      _Contract,
      _MetricVH
}
