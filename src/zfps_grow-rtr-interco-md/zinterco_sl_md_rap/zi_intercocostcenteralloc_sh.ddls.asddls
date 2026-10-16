@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help Intercompany CeCo Allocation'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@Search.searchable: true
define view entity ZI_IntercoCostCenterAlloc_SH
  as select from ZI_IntercoCostCenter as _Base
  association [0..1] to I_CostCenterHierarchyNode as _Node on  _Node.ControllingArea     = _Base.ControllingArea
                                                           and _Node.CostCenterHierarchy = _Base.AllocationCostCenterHierarchy
                                                           and _Node.HierarchyNodeVal    = _Base.Allocation
{
      @Search: {
      defaultSearchElement: true,
      fuzzinessThreshold: 0.9,
      ranking: #HIGH }
  key Allocation,
      @Search: {
      defaultSearchElement: true,
      fuzzinessThreshold: 0.9,
      ranking: #LOW }
      AllocationName,
      case when Allocation is not initial
          then lpad( cast(Allocation as kostl), 10, '0' )
          else cast(Allocation as kostl)
      end as AllocationLong

}
where
  _Node.NodeType = 'N'
group by
  Allocation,
  AllocationName
