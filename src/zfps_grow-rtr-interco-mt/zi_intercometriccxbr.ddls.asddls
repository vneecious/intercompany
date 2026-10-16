@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany / Metrics: CX Brasil'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoMetricCXBR
  as select from ZI_IntercoPandLSpread
{
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
      _IntercoCompanyCode.SiteCode,
      _IntercoCompanyCode.Country,
      concat( concat( FiscalYear, FiscalPeriod ), '01' ) as FiscalDate,
      CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      sum(AmountInCompanyCodeCurrency)                   as TotalInCompanyCodeCurrency,
      GlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      sum(AmountInGlobalCurrency)                        as TotalInGlobalCurrency
}
where
      Ledger                      = 'L1'
  and _MT005.IdL0                 = '0PL_L0_01'
  and _IntercoCompanyCode.Country = 'BR'
group by
  CompanyCode,
  FiscalYear,
  FiscalPeriod,
  _IntercoCompanyCode.SiteCode,
  _IntercoCompanyCode.Country,
  CompanyCodeCurrency,
  GlobalCurrency
