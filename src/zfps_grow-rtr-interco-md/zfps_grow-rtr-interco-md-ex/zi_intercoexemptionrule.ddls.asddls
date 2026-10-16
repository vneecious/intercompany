@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Exemptions'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoExemptionRule
  as select from zint_a_md005
  association [1..1] to ZI_IntercoExemption as _Exemption on _Exemption.ID = $projection.ID
{
  key id         as ID,
  key rule_id    as RuleID,
      gjahr      as FiscalYear,
      belnr      as AccountingDocument,
      blart      as AccountingDocumentType,
      hkont      as GLAccount,
      prctr      as ProfitCenter,
      kostl      as CostCenter,
      _Exemption
}
