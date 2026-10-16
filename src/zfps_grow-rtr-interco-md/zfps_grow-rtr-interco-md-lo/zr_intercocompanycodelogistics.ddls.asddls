@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '##GENERATED ZINT_A_MD007'
define root view entity ZR_IntercoCompanyCodeLogistics
  as select from ZI_IntercoCompanyCodeLogistics

{
  key CompanyCode,
  key ValidFrom,
      ValidTo,
      SalesOrganization,
      PurchasingOrganization,
      Plant,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      /* Associations */
      _Plant,
      _PurchasingOrganization,
      _SalesOrganization
}
