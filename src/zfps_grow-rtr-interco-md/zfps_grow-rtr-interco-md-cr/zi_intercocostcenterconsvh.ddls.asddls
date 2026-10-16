@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Cost Center Consolidation'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoCostCenterConsVH
  as select from ZI_IntercoCostCenter as _Base
  association [0..1] to I_CostCenterHierarchyNode as _Node on  _Node.ControllingArea     = _Base.ControllingArea
                                                           and _Node.CostCenterHierarchy = _Base.AllocationCostCenterHierarchy
                                                           and _Node.HierarchyNodeVal    = _Base.Allocation
{
  key Consolidation,
      ConsolidationName,
      case when Consolidation is not initial
          then lpad( cast(Consolidation as kostl), 10, '0' )
          else cast(Consolidation as kostl)
      end as ConsolidationLong

}
where
  _Node.NodeType = 'N'
group by
  Consolidation,
  ConsolidationName
