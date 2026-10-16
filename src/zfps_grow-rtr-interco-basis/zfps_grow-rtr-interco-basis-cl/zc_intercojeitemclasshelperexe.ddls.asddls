@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Classification Persistence'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_IntercoJEItemClassHelperExe
  as projection on ZR_INTERCOJEITEMHELPERCLASSEXE
{
  key Ledger,
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
  key PaymentType,
  key ProfitCenter,
  key CostCenter,
  key GLAccount,
      ExemptionID,
      /* Associations */
      _ExemptionRule,
      _Header : redirected to parent ZC_IntercoJEItemClassHelper
}
