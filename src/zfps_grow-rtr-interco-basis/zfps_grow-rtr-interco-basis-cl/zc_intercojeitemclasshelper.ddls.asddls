@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Classification Persistence'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_IntercoJEItemClassHelper
  provider contract transactional_query
  as projection on ZR_IntercoJEItemHelperClass
{
  key Ledger,
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
  key PaymentType,
      CreatedAt,
      CreatedBy,
      IsRuleProcessed,
      IsExemptionProcessed,
      /* Associations */
      _Items           : redirected to composition child ZC_IntercoJEItemClassHelperItm,
      _ItemsExemptions : redirected to composition child ZC_IntercoJEItemClassHelperExe
}
