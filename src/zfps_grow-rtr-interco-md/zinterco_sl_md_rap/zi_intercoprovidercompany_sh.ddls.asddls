@AbapCatalog.viewEnhancementCategory: [#NONE]
@EndUserText.label: 'Ayuda de Provider Company por Conceptos Intercompany'
define view entity ZI_IntercoProviderCompany_SH as select from ZI_IntercoRelationship
{
      @ObjectModel.text.element: ['ProviderCompanyCodeName']
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key ProviderCompanyCode     as ProviderCompanyCode,
      ProviderCompanyCodeName as ProviderCompanyCodeName,
      ProviderCountry         as ProviderCountry,
      ProviderCountryName     as ProviderCountryName
}
group by
  ProviderCompanyCode,
  ProviderCompanyCodeName,
  ProviderCountry,
  ProviderCountryName
