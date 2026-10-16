@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Historial de Cambios Version'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingMCVerHist
  as select from zreing_mc_hist_a
  association to parent ZI_ReingMCVersion as _Version
    on  _Version.MetricCode = $projection.MetricCode
    and _Version.VersionNum = $projection.VersionNum
{
  key metric_code as MetricCode,
  key version_num as VersionNum,
  key hist_uuid   as HistUuid,
      changed_at  as ChangedAt,
      changed_by  as ChangedBy,
      action      as Action,
      field_name  as FieldName,
      value_old   as ValueOld,
      value_new   as ValueNew,
      _Version
}
