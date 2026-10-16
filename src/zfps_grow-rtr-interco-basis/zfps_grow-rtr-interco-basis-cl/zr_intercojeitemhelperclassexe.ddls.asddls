@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Classification Results Items'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_INTERCOJEITEMHELPERCLASSEXE
  as select from zint_a_jeitem_ce
  association to parent ZR_IntercoJEItemHelperClass as _Header        on  $projection.Ledger       = _Header.Ledger
                                                                      and $projection.CompanyCode  = _Header.CompanyCode
                                                                      and $projection.FiscalYear   = _Header.FiscalYear
                                                                      and $projection.FiscalPeriod = _Header.FiscalPeriod
                                                                      and $projection.PaymentType  = _Header.PaymentType
  association to ZI_IntercoExemption                as _ExemptionRule on  $projection.ExemptionID = _ExemptionRule.ExternalID
{
  key ledger       as Ledger,
  key companycode  as CompanyCode,
  key fiscalyear   as FiscalYear,
  key fiscalperiod as FiscalPeriod,
  key paymenttype  as PaymentType,
  key profitcenter as ProfitCenter,
  key costcenter   as CostCenter,
  key glaccount    as GLAccount,
      exemptionid  as ExemptionID,
      _Header, // Make association public
      _ExemptionRule
}
