@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - relationship'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_INTERCORELATIONSHIP_2
  as select distinct from ZI_IntercoRelationship
{
  key ProviderBusinessPartner,
  key RecipientBusinessPartner,
      ProviderCountry,
      ProviderCountryName,
      ProviderCompanyCode,
      ProviderCompanyCodeName,
      ProviderCustomer,
      ProviderVendor,
      RecipientCountry,
      RecipientCountryName,
      RecipientCompanyCode,
      RecipientCompanyCodeName,
      RecipientCustomer,
      RecipientVendor
}
group by
  ProviderBusinessPartner,
  RecipientBusinessPartner,
  ProviderCountry,
  ProviderCountryName,
  ProviderCompanyCode,
  ProviderCompanyCodeName,
  ProviderCustomer,
  ProviderVendor,
  RecipientCountry,
  RecipientCountryName,
  RecipientCompanyCode,
  RecipientCompanyCodeName,
  RecipientCustomer,
  RecipientVendor
