@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Definition of Concepts by Plant'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_IntercoProductPlant
  as select from ZI_IntercoProduct as _IntercoProduct
  association [0..*] to I_Product as _Product on  _Product.Product             = $projection.Product
                                              and _Product.IsMarkedForDeletion <> 'X'
{
  key _IntercoProduct.Product                                                                  as Product,
  key _Product._ESHProductPlant.Plant                                                          as Plant,
      _IntercoProduct.ProductName                                                              as ProductName,
      _IntercoProduct.ProductType                                                              as ProductType,
      _IntercoProduct.ProductTypeName                                                          as ProductTypeName,
      _IntercoProduct.Metric                                                                   as Metric,
      _IntercoProduct.MetricName                                                               as MetricName,
      _Product._ESHProductPlant._Plant.PlantName                                               as PlantName,
      _Product.BaseUnit                                                                        as UnitOfMeasure,
      _Product._BaseUnitOfMeasureText[ Language = $session.system_language ].UnitOfMeasureName as UnitOfMeasureName

}
