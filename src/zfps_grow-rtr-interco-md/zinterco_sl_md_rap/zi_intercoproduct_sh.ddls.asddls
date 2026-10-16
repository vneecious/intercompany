@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help Intercomapy Product'
@Search.searchable: true
define view entity ZI_IntercoProduct_SH
  as select from ZI_IntercoProduct
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key Product,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      ProductName,
      ProductType,
      ProductTypeName

}
group by
  Product,
  ProductName,
  ProductType,
  ProductTypeName
