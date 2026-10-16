@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@EndUserText.label: 'CA - Cabecera Ejecucion V2'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define root view entity ZC_ReingCARun_V2
  provider contract transactional_query
  as projection on ZI_ReingCARun
{
  key CalcRunId,
      FiscalPeriod,
      FiscalYear,
      TotalLines,
      TotalGroups,
      CreatedBy,
      CreatedAt,
      LocalLastChangedAt,
      _Line : redirected to composition child ZC_ReingCALine_V2
}
