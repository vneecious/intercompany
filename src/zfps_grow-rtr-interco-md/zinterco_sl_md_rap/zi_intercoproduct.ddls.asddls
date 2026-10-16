@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'INTERCO Master Data - Definition of Concepts'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_IntercoProduct
  as select from I_Product as _Product
{
  key _Product.Product                                                                     as Product,
      _Product._Text[ Language = 'S' ].ProductName                                         as ProductName,
      _Product.ProductGroup                                                                as Metric,
      _Product._ProductGroupText_2[ Language = $session.system_language ].ProductGroupName as MetricName,
      _Product.ProductType                                                                 as ProductType,
      _Product._ProductTypeName[ Language = $session.system_language ].MaterialTypeName    as ProductTypeName,
      _Product.AuthorizationGroup                                                          as AuthorizationGroup
}
where
      ProductType         = 'ZIC'
  and IsMarkedForDeletion = ''
