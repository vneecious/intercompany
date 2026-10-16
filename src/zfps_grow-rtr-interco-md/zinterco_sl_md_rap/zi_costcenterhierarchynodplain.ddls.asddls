@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Cost Center Plain'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_CostCenterHierarchyNodPlain as select from I_CostCenterHierarchyNode as _Base

    left outer join I_CostCenterHierarchyNode as _Consolidation on  _Consolidation.ControllingArea  = _Base.ControllingArea
                                                                and _Consolidation.CostCenterHierarchy = ''

{
    key _Base.ControllingArea,
    key _Base.CostCenterHierarchy,
    key _Base.HierarchyNode,
    _Base.ValidityEndDate
    
}
where _Base.ValidityEndDate >= $session.user_date
  and _Base.CostCenterHierarchy = '0101/ML00/ML00'
  and _Base.ControllingArea = 'ML00'
