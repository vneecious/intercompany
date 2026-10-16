@EndUserText.label: 'ME - Param: Periodo Export'
define abstract entity ZI_ReingMEPeriodParam
{
  PeriodYear  : abap.numc(4);
  PeriodMonth : abap.numc(2);
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ReingCTMetricVH', element: 'MetricCode' } }]
  MetricCode  : zreing_metric_code;
}
