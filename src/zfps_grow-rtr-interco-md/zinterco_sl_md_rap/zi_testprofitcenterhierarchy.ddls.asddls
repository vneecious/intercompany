@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'test I_ProfitCenterHierarchyNode'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_TestProfitCenterHierarchy as select from I_ProfitCenterHierarchyNode
{
   key ControllingArea,
   key ProfitCenterHierarchy,
   key HierarchyNode,
   key ValidityEndDate,
   ParentNode,
   HierarchyVersion,
   ValidityStartDate,
   ProfitCenter,
   SequenceNumber,
   HierarchyNodeSequence,
   HierarchyNodeLevel,
   NodeType,
   HierarchyNodeVal,
   /* Associations */
   _ControllingArea,
   _ControllingAreaText,
   _Hierarchy,
   _ProfitCenter,
   _Text 
}
where ValidityEndDate >= $session.user_date 
  and ControllingArea = 'ML00'
  and ProfitCenter <> ''
