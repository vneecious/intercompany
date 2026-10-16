@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help Intercompany CeCo Sub Area'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Search.searchable: true
define view entity ZI_IntercoCostCenterSubArea_SH
  as select from ZI_IntercoCostCenterSubArea_T

{
      @Search: { defaultSearchElement: true,
                 fuzzinessThreshold: 0.9,
                 ranking: #HIGH }
  key CostCenterSubArea,
      @Search: { defaultSearchElement: true,
                 fuzzinessThreshold: 0.8,
                 ranking: #MEDIUM }
      CostCenterSubAreaName,
      CostCenterArea,
      CostCenterAreaName
}
group by
  CostCenterSubArea,
  CostCenterSubAreaName,
  CostCenterArea,
  CostCenterAreaName
