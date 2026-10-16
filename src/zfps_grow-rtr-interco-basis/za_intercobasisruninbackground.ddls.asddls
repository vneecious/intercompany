@EndUserText.label: 'Intercompany / Basis: Parame Action ZI_IntercoBasis-RunInBG'
define abstract entity ZA_IntercoBasisRunInBackground
{
  CompanyCode   : bukrs;
  FiscalYear    : gjahr;
  FiscalPeriod  : fins_fiscalperiod;
  PaymentType   : zint_dte_paymenttype;
  Ledger        : fins_ledger;
  AllFilters : abap.string(1000);
  Overwrite     : abap.char( 1 );
}
