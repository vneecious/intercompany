@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Exexmptions Flatted'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoExemptionRuleFlat
  as select from ZI_IntercoExemptionRule
{
  key ID,
  key RuleID,
      _Exemption.ExternalID,
      _Exemption.ExemptionName,
      _Exemption.CompanyCode,
      _Exemption.Product,
      -- AGREGADO EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09: expone PaymentType de la exclusión
      _Exemption.PaymentType,
      -- Fin EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09
      _Exemption.ValidFrom,
      _Exemption.ValidTo,
      FiscalYear,
      AccountingDocument,
      AccountingDocumentType,
      GLAccount,
      ProfitCenter,
      CostCenter,
      case when _Exemption.CompanyCode is not initial then 1 else 0 end +
      case when FiscalYear is not initial then 1 else 0 end +
      case when AccountingDocument is not initial then 1 else 0 end +
      case when AccountingDocumentType is not initial then 1 else 0 end +
      case when GLAccount is not initial then 1 else 0 end +
      case when ProfitCenter is not initial then 1 else 0 end +
      case when CostCenter is not initial then 1 else 0 end +
      -- AGREGADO EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09: suma PaymentType al score de especificidad
      case when _Exemption.PaymentType is not initial then 1 else 0 end
      -- Fin EXT_OSCUGALD 28.09.2026 - Facturación Local CH/ARG - C09
  as Score,
      _Exemption
}
