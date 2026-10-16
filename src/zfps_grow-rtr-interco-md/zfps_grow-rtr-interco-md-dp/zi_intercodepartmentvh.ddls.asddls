@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Department'
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}

@Search.searchable: true
@Consumption.ranked: true
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_IntercoDepartmentVH
  as select from ZI_IntercoDepartment
{
      @ObjectModel.text.element: ['Description']
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key Department,
      @Semantics.text: true
      @Search: { defaultSearchElement: true, ranking: #LOW }
      @Search.fuzzinessThreshold: 0.8
      Description
}
where
  IsDeleted is initial
