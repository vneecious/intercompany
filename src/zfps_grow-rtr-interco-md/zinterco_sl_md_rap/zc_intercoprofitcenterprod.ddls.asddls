@EndUserText.label: 'Intercompany - Profit Center - Product'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_IntercoProfitCenterProd
  as projection on ZI_IntercoProfitCenterProd
{
  key ProfitCenter,
      Product,
      ProductName,
      Subbu,
      SubbuName,
      BusinessUnit,
      BusinessUnitName
}
