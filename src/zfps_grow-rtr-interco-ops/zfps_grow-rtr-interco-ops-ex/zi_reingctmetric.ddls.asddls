@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Metricas Asignadas'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTMetric
  as select from zreing_ct_met_a
  association to parent ZI_ReingCTMaterial as _Material
    on  _Material.CtId  = $projection.CtId
    and _Material.Matnr = $projection.Matnr
  association [1] to ZI_ReingCTContract as _Contract
    on _Contract.CtId = $projection.CtId
{
  key ct_id       as CtId,
  key matnr       as Matnr,
  key metric_seq  as MetricSeq,
      metric_code as MetricCode,
      version_num as VersionNum,
      granularity as Granularity,
      valid_from  as ValidFrom,
      valid_to    as ValidTo,
      met_status  as MetStatus,
      created_by  as CreatedBy,
      created_at  as CreatedAt,
      changed_by  as ChangedBy,
      changed_at  as ChangedAt,
      _Material,
      _Contract
}
