@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Classification Persistence'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_IntercoJEItemClassHelperItm
  as projection on ZR_IntercoJEItemHelperClassItm
{
  key Ledger,
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
  key PaymentType,
  key PandLL5ID,
  key ProfitCenter,
  key CostCenterStandardHierArea,
  key CcAllocation,
  key CcConsolidation,
      RuleID,
      /* Associations */
      _ClassificationRule,
      _Header : redirected to parent ZC_IntercoJEItemClassHelper
}
