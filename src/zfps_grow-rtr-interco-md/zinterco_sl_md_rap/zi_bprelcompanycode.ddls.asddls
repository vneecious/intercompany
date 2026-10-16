@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'INTERCO Master Data - Link BP Trading Partner to CompanyCode'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_BPRelCompanyCode
  as select from I_BPRelationship_2
  association [0..1] to I_CompanyCode                as _Partner1CompanyCode  on _Partner1CompanyCode.CompanyCode = $projection.TradingPartner1
  association [0..1] to I_CompanyCode                as _Partner2CompanyCode  on _Partner2CompanyCode.CompanyCode = $projection.TradingPartner2
{
  key I_BPRelationship_2.RelationshipNumber,
  key I_BPRelationship_2.BusinessPartner1                                         as BusinessPartnerCompany,
  key I_BPRelationship_2.BusinessPartner2                                         as BusinessPartnerPerson,
  key I_BPRelationship_2.ValidityEndDate,
      I_BPRelationship_2.BusinessPartner1,
      I_BPRelationship_2._BusinessPartner1._BPFinancialServicesExt.TradingPartner as TradingPartner1,
      I_BPRelationship_2.BusinessPartner2,
      I_BPRelationship_2._BusinessPartner2._BPFinancialServicesExt.TradingPartner as TradingPartner2,
      I_BPRelationship_2.ValidityStartDate,
      I_BPRelationship_2.IsStandardRelationship,
      I_BPRelationship_2.RelationshipCategory,
      I_BPRelationship_2.BPRelationshipType,
      I_BPRelationship_2.BusPartRelshpIsRoleDefinition,
      I_BPRelationship_2.CreatedByUser,
      I_BPRelationship_2.CreationDate,
      I_BPRelationship_2.CreationTime,
      I_BPRelationship_2.LastChangedByUser,
      I_BPRelationship_2.LastChangeDate,
      I_BPRelationship_2.LastChangeTime,
//      cast( '' as abap.char( 10 ) ) as ProviderCustomer,
//      cast( '' as abap.char( 10 ) ) as ProviderVendor,
//      cast( '' as abap.char( 10 ) ) as RecipientCustomer,
//      cast( '' as abap.char( 10 ) ) as RecipientVendor,
      /* Associations */
      I_BPRelationship_2._BusinessPartner1                                        as _BusinessPartner1,
      I_BPRelationship_2._BusinessPartner2                                        as _BusinessPartner2,
      _Partner1CompanyCode,
      _Partner2CompanyCode
}
