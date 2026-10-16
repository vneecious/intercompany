@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Relación Sociedades Intercompany'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoRelationship2
  as select from    ZI_BPRelCompanyCode          as _BPRel
    left outer join I_BusinessPartner_to_BP_Role as _BPRolPC on  _BPRel.BusinessPartner1      = _BPRolPC.BusinessPartner
                                                             and _BPRolPC.BusinessPartnerRole = 'FLCU00'
    left outer join I_BusinessPartner_to_BP_Role as _BPRolPV on  _BPRel.BusinessPartner1      = _BPRolPV.BusinessPartner
                                                             and _BPRolPV.BusinessPartnerRole = 'FLVN00'
    left outer join I_BusinessPartner_to_BP_Role as _BPRolRC on  _BPRel.BusinessPartner2      = _BPRolRC.BusinessPartner
                                                             and _BPRolPC.BusinessPartnerRole = 'FLCU00'
    left outer join I_BusinessPartner_to_BP_Role as _BPRolRV on  _BPRel.BusinessPartner2      = _BPRolRV.BusinessPartner
                                                             and _BPRolRV.BusinessPartnerRole = 'FLVN00'
{
  key _BPRel._BusinessPartner1.BusinessPartner                                                      as ProviderBusinessPartner,
  key _BPRel._BusinessPartner2.BusinessPartner                                                      as RecipientBusinessPartner,

      _BPRel._Partner1CompanyCode.Country                                                           as ProviderCountry,
      _BPRel._Partner1CompanyCode._Country._Text[ Language = $session.system_language ].CountryName as ProviderCountryName,
      _BPRel._Partner1CompanyCode.CompanyCode                                                       as ProviderCompanyCode,
      _BPRel._Partner1CompanyCode.CompanyCodeName                                                   as ProviderCompanyCodeName,
      _BPRolPC.BusinessPartner                                                                      as ProviderCustomer,
      _BPRolPV.BusinessPartner                                                                      as ProviderVendor,
      _BPRel._Partner2CompanyCode.Country                                                           as RecipientCountry,
      _BPRel._Partner2CompanyCode._Country._Text[ Language = $session.system_language ].CountryName as RecipientCountryName,

      _BPRel._Partner2CompanyCode.CompanyCode                                                       as RecipientCompanyCode,
      _BPRel._Partner2CompanyCode.CompanyCodeName                                                   as RecipientCompanyCodeName,
      _BPRolRC.BusinessPartner                                                                      as RecipientCustomer,
      _BPRolRV.BusinessPartner                                                                      as RecipientVendor
}
where
  _BPRel.RelationshipCategory = 'CHM002'
