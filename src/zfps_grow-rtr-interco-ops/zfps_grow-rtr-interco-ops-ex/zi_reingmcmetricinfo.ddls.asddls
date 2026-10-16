
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Metric Header Info'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingMCMetricInfo
  as select from zreing_mc_a
{
  key metric_code   as MetricCode,
      metric_desc   as MetricDesc,
      metric_type   as MetricType,
      data_source   as DataSource,
      responsible   as Responsible,
      status        as Status,
      last_vers_num as LastVersNum,
      created_by    as CreatedBy,
      created_at    as CreatedAt,
      changed_by    as ChangedBy,
      changed_at    as ChangedAt
}
