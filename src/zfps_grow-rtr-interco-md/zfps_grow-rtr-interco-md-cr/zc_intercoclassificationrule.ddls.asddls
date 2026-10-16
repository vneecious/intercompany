@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: 'Projection View for ZR_INTERCOCLASSIFICATIONRULE'
@ObjectModel.semanticKey: [ 'ID' ]
define root view entity ZC_INTERCOCLASSIFICATIONRULE
  provider contract transactional_query
  as projection on ZR_INTERCOCLASSIFICATIONRULE
  association [0..1] to ZI_IntercoCompanyCode  as _CompanyCode  on  _CompanyCode.CompanyCode = $projection.CompanyCode
  association [0..*] to ZI_IntercoProfitCenter as _ProfitCenter on  _ProfitCenter.ControllingArea = 'ML00'
                                                                and _ProfitCenter.ProfitCenter    = $projection.ProfitCenter
                                                                and _ProfitCenter.ValidityEndDate >= $projection.ValidFrom
  association [0..*] to ZC_IntercoMDLog        as _Log          on  _Log.ChangeDocObject = 'ZINT_A_MD_CR'
                                                                and _Log.ID              = $projection.ID

{
  key ID,
      RuleID,
      RuleName,
      @Semantics: {  calendar.yearMonth: true }
      ValidFrom,
      @Semantics: {  calendar.yearMonth: true }
      ValidTo,
      CompanyCode,
      Ledger,
      PandLLevel,
      @ObjectModel.text.element: ['PAndLName']
      PAndLID,
      PAndLName,
      ProfitCenter,
      @ObjectModel.text.element: ['CcStdHierAreaName']
      CcStdHierArea,
      CcStdHierAreaName,
      @ObjectModel.text.element: ['CcAllocationName']
      CcAllocation,
      CcAllocationName,
      @ObjectModel.text.element: ['CcConsolidationName']
      CcConsolidation,
      CcConsolidationName,
      @ObjectModel.text.element: [ 'ProductName' ]
      Product,
      ProductName,
      IsNotBillable,
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 06.10.2026 - C13F: exponer tipo de pago en la aplicación de reglas
      PaymentType,
      -- Fin EXT_OSCUGALD 06.10.2026 - C13F
      IsDeleted,
      IsNotDeleted,
      RuleCriticality,
      Score,
      LocalLastChangedAt,
      IsValid,
      IsValidCriticality,
      Today,
      Yesterday,
      ExcelLineNumber,
      CreatedAt,
      CreatedBy,
      _CompanyCode,
      _ProfitCenter,
      _PandL,
      _CcAllocation,
      _CcConsolidation,
      _CcStdHierArea,
      _Log

}
