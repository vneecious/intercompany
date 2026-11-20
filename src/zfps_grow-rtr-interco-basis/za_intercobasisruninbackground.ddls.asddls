@EndUserText.label: 'Intercompany / Basis: Parame Action ZI_IntercoBasis-RunInBG'
define abstract entity ZA_IntercoBasisRunInBackground
{
  CompanyCode   : bukrs;
  FiscalYear    : gjahr;
  FiscalPeriod  : fins_fiscalperiod;
  PaymentType   : zint_dte_paymenttype;
  Ledger        : fins_ledger;
  AllFilters : abap.string(1000);
  // EXT_VINBARRI 17.11.2026: $select de la tabla + campos del filter bar, separados por coma
  RequestedColumns : abap.string(0);
  Overwrite     : abap.char( 1 );
}
