@AccessControl.authorizationCheck:#CHECK
@EndUserText.label: 'Intrecompany: Billing Exemptions'
@Metadata: {
  ignorePropagatedAnnotations: false,
  allowExtensions: true
}
define root view entity ZC_IntercoExemptionTP
  as projection on ZI_INTERCOEXEMPTIONTP
{
  key ID,
      ExternalID,
      ExemptionName,
      @ObjectModel.foreignKey.association: '_CompanyCode'
      @ObjectModel.text.element: ['CompanyCodeName']
      CompanyCode,
      @ObjectModel.foreignKey.association: '_Product'
      @ObjectModel.text.element: ['ProductName']
      Product,
      -- AGREGADO EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09: expone PaymentType (proyección, sin cambio de BDEF — es "use")
      PaymentType,
      -- Fin EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09
      ValidFrom,
      ValidTo,
      IsValid,
      _Product.ProductName as ProductName,
      _CompanyCode.CompanyCodeName,
      Today,
      Yesterday,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LastChangedBy,
      _CompanyCode,
      _Product,
      _ExemptionRules : redirected to composition child ZC_IntercoExemptionRuleTP
}
