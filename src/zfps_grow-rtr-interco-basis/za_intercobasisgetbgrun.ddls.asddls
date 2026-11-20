@EndUserText.label: 'Intercompany / Basis: Parame Action ZI_IntercoBasis-RunInBG'
define abstract entity ZA_INTERCOBASISGETBGRUN
{
  CompanyCode  : bukrs;
  FiscalYear   : gjahr;
  FiscalPeriod : fins_fiscalperiod;
  PaymentType  : zint_dte_paymenttype;
  Ledger       : fins_ledger;
  Pending      : abap_boolean;
  // EXT_VINBARRI 17.11.2026: columnas grabadas en el ultimo background (vacio = todas)
  RequestedColumns : abap.string(0);
  CreatedBy    : abp_creation_user;
  @Semantics.dateTime: true
  CreatedAt    : abp_creation_utcl;

}
