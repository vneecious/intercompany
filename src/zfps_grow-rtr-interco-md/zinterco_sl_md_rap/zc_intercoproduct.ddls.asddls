@EndUserText.label: 'INTERCO Master Data - Definition of Concepts'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_IntercoProduct as projection on ZI_IntercoProductPlant
{
    @ObjectModel.text.element:  [ 'ProductName' ]
    key Product,
    @ObjectModel.text.element:  [ 'PlantName' ]
    key Plant,
    ProductName,
    PlantName,
    @ObjectModel.text.element:  [ 'UnitOfMeasureName' ]
    UnitOfMeasure,
    UnitOfMeasureName,
    @ObjectModel.text.element:  [ 'MetricName' ]
    Metric,
    MetricName,
    @ObjectModel.text.element:  [ 'ProductTypeName' ]
    ProductType,
    ProductTypeName
}
