@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Classification Results Items'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_IntercoJEItemHelperClassItm
  as select from zint_a_jeitem_ci
  association to parent ZR_IntercoJEItemHelperClass as _Header             on  $projection.Ledger       = _Header.Ledger
                                                                           and $projection.CompanyCode  = _Header.CompanyCode
                                                                           and $projection.FiscalYear   = _Header.FiscalYear
                                                                           and $projection.FiscalPeriod = _Header.FiscalPeriod
                                                                           and $projection.PaymentType  = _Header.PaymentType
  association to ZI_IntercoClassificationRule       as _ClassificationRule on  $projection.RuleID = _ClassificationRule.RuleID
{
  key ledger                     as Ledger,
  key companycode                as CompanyCode,
  key fiscalyear                 as FiscalYear,
  key fiscalperiod               as FiscalPeriod,
  key paymenttype                as PaymentType,
  key pandll5id                  as PandLL5ID,
  key profitcenter               as ProfitCenter,
  key costcenterstandardhierarea as CostCenterStandardHierArea,
  key ccallocation               as CcAllocation,
  key ccconsolidation            as CcConsolidation,
      ruleid                     as RuleID,
      _Header, // Make association public
      _ClassificationRule
}
