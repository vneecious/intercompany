@EndUserText.label: 'Intercompany relationship between companies'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_IntercoRelationship provider contract transactional_query as projection on ZI_INTERCORELATIONSHIP_2
{   
     key ProviderBusinessPartner,
     key RecipientBusinessPartner,
     //@ObjectModel.text.element:  [ 'ProviderCountryName' ]
     ProviderCountry,
     @Semantics.text: true
     ProviderCountryName,
     //@ObjectModel.text.element:  [ 'ProviderCompanyCodeName' ]
     ProviderCompanyCode,
     @Semantics.text: true
     ProviderCompanyCodeName,
     ProviderCustomer,
     ProviderVendor,
     //@ObjectModel.text.element:  [ 'RecipientCountryName' ]
     RecipientCountry,
     @Semantics.text: true
     RecipientCountryName,
     //@ObjectModel.text.element:  [ 'RecipientCompanyCodeName' ]   
     RecipientCompanyCode,
     @Semantics.text: true
     RecipientCompanyCodeName,
     RecipientCustomer,
     RecipientVendor
    
}
