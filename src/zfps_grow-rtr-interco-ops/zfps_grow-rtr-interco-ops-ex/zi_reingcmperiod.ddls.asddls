@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CM - Periodo de Carga Mensual'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define root view entity ZI_ReingCMPeriod
  as select from zreing_cm_period as Period
  composition [0..*] of ZI_ReingCMHeader as _Items
{
  key Period.period_year  as PeriodYear,
  key Period.period_month as PeriodMonth,
      Period.created_by   as CreatedBy,
      Period.created_at   as CreatedAt,
      _Items
}
