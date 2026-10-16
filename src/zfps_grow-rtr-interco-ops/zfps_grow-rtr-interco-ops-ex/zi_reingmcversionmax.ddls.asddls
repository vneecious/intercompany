
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Max Version per Metric Code'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingMCVersionMax
  as select from zreing_mcv_a
{
  key metric_code              as MetricCode,
      max( version_num )       as MaxVersionNum
}
group by
  metric_code
