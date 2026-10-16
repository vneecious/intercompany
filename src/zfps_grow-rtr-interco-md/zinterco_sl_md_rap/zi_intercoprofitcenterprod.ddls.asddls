@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Profit Center - Product'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_IntercoProfitCenterProd
  //  as select distinct from ZI_INTERCOPROFITCENTERBU as _ProfitCenter
  as select distinct from ZI_PNL_PROD as _ProfitCenter
{
  key ProfitCenter,
      Product,
      ProductName,
      Subbu,
      SubbuName,
      BusinessUnit,
      BusinessUnitName
}
group by
  ProfitCenter,
  Product,
  ProductName,
  Subbu,
  SubbuName,
  BusinessUnit,
  BusinessUnitName
