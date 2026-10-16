@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CM - Periodo de Carga Mensual'
@Metadata.allowExtensions: true

define root view entity ZC_ReingCMPeriod
  provider contract transactional_query
  as projection on ZI_ReingCMPeriod
{
  key PeriodYear,
  key PeriodMonth,
      CreatedBy,
      CreatedAt,

      _Items : redirected to composition child ZC_ReingCMHeader
}
