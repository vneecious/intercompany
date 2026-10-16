@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'teste'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_TestCostCenterHierarchyNode as select from I_CostCenterHierarchyNode
{
    key ControllingArea,
    key CostCenterHierarchy,
    key HierarchyNode,
    key ValidityEndDate,
    ParentNode,
    HierarchyVersion,
    ValidityStartDate,
    CostCenter,
    SequenceNumber,
    HierarchyNodeSequence,
    HierarchyNodeLevel,
    NodeType,
    HierarchyNodeVal,
    /* Associations */
    _ControllingArea,
    _ControllingAreaText,
    _CostCenter,
    _Hierarchy,
    _Text
}
