@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Intrecompany: Billing Exemptions'
@Metadata: {
  ignorePropagatedAnnotations: true,
  allowExtensions: true
}
define root view entity ZI_INTERCOEXEMPTIONTP
  as select from ZI_IntercoExemption
  composition [1..*] of ZI_INTERCOEXEMPTIONRULETP as _ExemptionRules
  association [0..1] to ZI_IntercoCompanyCode     as _CompanyCode on _CompanyCode.CompanyCode = $projection.CompanyCode
  association [0..1] to ZI_IntercoProduct         as _Product     on _Product.Product = $projection.Product
{
  key ID,
      ExternalID,
      ExemptionName,
      @ObjectModel.foreignKey.association: '_CompanyCode'
      CompanyCode,
      @ObjectModel.foreignKey.association: '_Product'
      Product,
      ValidFrom,
      ValidTo,
      IsDeleted,
      cast (case when IsDeleted = 'X' then ' ' else 'X' end as abap_boolean )                                                 as IsActive,
      cast (case when ValidTo >= $session.user_date or ValidFrom <= $session.user_date then 'X' else '' end as abap_boolean ) as IsValid,
      cast ( case when $projection.IsValid = 'X' then 3 else 1 end as abap.int1 )                                             as IsValidCriticality,
      // Technical Fields
      $session.system_date                                                                                                    as Today,
      dats_add_days($session.system_date, -1, 'INITIAL')                                                                      as Yesterday,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      _CompanyCode,
      _Product,
      _ExemptionRules
}
