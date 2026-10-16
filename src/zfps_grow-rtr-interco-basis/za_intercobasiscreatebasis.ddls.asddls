define abstract entity ZA_IntercoBasisCreateBasis
{
  CompanyCode      : bukrs;
  FiscalYear       : gjahr;
  FiscalPeriod     : fins_fiscalperiod;
  PaymentType      : zint_dte_paymenttype;
  Ledger           : fins_ledger;
  Description      : zint_dte_description;
  ReportExecutedAt : abap.utclong;
  Overwrite        : abap.char( 1 );
  Background       : abap_boolean;
}
