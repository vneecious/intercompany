@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Procider Company Code SH'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Search.searchable: true
define view entity ZI_IntercoProviderCompany_SH2
  as select from ZI_IntercoRelationship2
{
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
