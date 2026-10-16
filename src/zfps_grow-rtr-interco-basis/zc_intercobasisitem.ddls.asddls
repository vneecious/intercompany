@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bases Facturables Clasificadas - Items'
@Metadata.ignorePropagatedAnnotations: true

@Metadata.allowExtensions: true
define view entity ZC_INTERCOBASISITEM
  as projection on ZI_IntercoBasisItem
{
  key Id,
  key Providercompanycode as CompanyCode,
  key Fiscalyear,
  key Fiscalperiod,
  key Ledger,
  key PandLL5ID,
  key CostCenterStdHierArea,
  key CCAllocation,
  key CCConsolidation,
  key Glaccount,
  key Product,
  key Costcenter,
  key Profitcenter,
  key PaymentType,
      MinDateTime,
      MaxDateTime,
      Companycodecurrency,
      Globalcurrency,
      @Semantics.amount.currencyCode: 'Globalcurrency'
      Amountinglobalcurrency,
      @Semantics.amount.currencyCode: 'Companycodecurrency'
      Amountincompanycodecurrency,
      Department,
      IsReleased,
      /* Associations */
      _header : redirected to parent ZC_INTERCOBASIS

}
