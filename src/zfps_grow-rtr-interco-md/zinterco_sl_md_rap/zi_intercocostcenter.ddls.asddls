@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Cost Center'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoCostCenter
  as select from I_CostCenterHierarchyNode as _CostCenter

  association [0..*] to I_CostCenterHierarchyNode as _Consolidation on  _Consolidation.ControllingArea     = _CostCenter.ControllingArea
                                                                    and _Consolidation.CostCenterHierarchy = 'H101/ML00/CONS_CC'
                                                                    and _Consolidation.CostCenter          = _CostCenter.CostCenter
                                                                    and _Consolidation.NodeType            = 'N'
                                                                    and _Consolidation.ValidityEndDate     >= $session.user_date

  association [0..*] to I_CostCenterHierarchyNode as _Allocation    on  _Allocation.ControllingArea     = _CostCenter.ControllingArea
                                                                    and _Allocation.CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
                                                                    and _Allocation.CostCenter          = _CostCenter.CostCenter
                                                                    and _Allocation.NodeType            = 'N'
                                                                    and _Allocation.ValidityEndDate     >= $session.user_date

{
  key _CostCenter.ControllingArea                                                  as ControllingArea,
  key _CostCenter.CostCenterHierarchy                                              as CostCenterHierarchy,
  key _CostCenter.HierarchyNode                                                    as HierarchyNode,
      _CostCenter.CostCenter                                                       as CostCenter,
      _CostCenter._Text[Language = $session.system_language ]                      as CostCenterName,
      _CostCenter._CostCenter.CostCenterStandardHierArea,
      _Consolidation.ControllingArea                                               as ConsolidationControllingArea,
      _Consolidation.CostCenterHierarchy                                           as ConsolidationCostCenterHierac,
      _Consolidation.CostCenter                                                    as ConsolidationCostCenter,
      //   _Consolidation.HierarchyNodeVal as Consolidation,
      case
      when _Consolidation.HierarchyNodeVal is not initial then _Consolidation.HierarchyNodeVal
      else _Allocation.HierarchyNodeVal  end                                       as Consolidation,

      _Consolidation._Text[Language = $session.system_language ].HierarchyNodeText as ConsolidationName,
      _Allocation.ControllingArea                                                  as AllocationControllingArea,
      _Allocation.CostCenterHierarchy                                              as AllocationCostCenterHierarchy,
      _Allocation.CostCenter                                                       as AllocationCostCenter,
      _Allocation.HierarchyNodeVal                                                 as Allocation,
      lpad(_Allocation.HierarchyNodeVal, 10, '0')                                  as Allocationbase,
      _Allocation._Text[Language = $session.system_language ].HierarchyNodeText    as AllocationName,

      _Consolidation,
      _Allocation

}
where
      _CostCenter.ValidityEndDate     >= $session.user_date
  and _CostCenter.CostCenterHierarchy = '0101/ML00/ML00'
  and _CostCenter.ControllingArea     = 'ML00'
