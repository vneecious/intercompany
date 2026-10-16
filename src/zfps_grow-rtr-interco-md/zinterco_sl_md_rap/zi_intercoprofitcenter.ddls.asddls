@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Profit Center'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProfitCenter as select from I_ProfitCenterHierarchyNode as _ProfitCenter
    association [0..1] to I_ProfitCenterHierarchyNode  as _ProfitCenterL2 on _ProfitCenterL2.ControllingArea = _ProfitCenter.ControllingArea
                                                                         and _ProfitCenterL2.ProfitCenterHierarchy = _ProfitCenter.ProfitCenterHierarchy
                                                                         and _ProfitCenterL2.HierarchyNode = _ProfitCenter.ParentNode
                                                                         
    association [0..1] to I_ProfitCenterHierarchyNode  as _ProfitCenterL1 on _ProfitCenterL1.ControllingArea = $projection.ControllingAreaL2
                                                                         and _ProfitCenterL1.ProfitCenterHierarchy = $projection.ProfitCenterHierarchyL2
                                                                         and _ProfitCenterL1.HierarchyNode = $projection.ParentNodeL2                                                                         
{
   key _ProfitCenter.ControllingArea,
   key _ProfitCenter.ProfitCenterHierarchy,
   key _ProfitCenter.HierarchyNode,
   key _ProfitCenter.ValidityEndDate,
   _ProfitCenter.ProfitCenter,
   _ProfitCenter._Text[Language = $session.system_language ] as ProfitCenterText,
   
   _ProfitCenterL2.ControllingArea as ControllingAreaL2,
   _ProfitCenterL2.ProfitCenterHierarchy as ProfitCenterHierarchyL2,
   _ProfitCenterL2.HierarchyNode as HierarchyNodeL2,
   _ProfitCenterL2.ProfitCenter as ProfitCenterL2,
   _ProfitCenterL2.ParentNode as ParentNodeL2,
   _ProfitCenterL2._Text[Language = $session.system_language ] as ProfitCenterL2Name,
   
   //_ProfitCenterL1.ControllingArea as ControllingAreaL1,
   //_ProfitCenterL1.ProfitCenterHierarchy as ProfitCenterHierarchyL1,
  // _ProfitCenterL1.HierarchyNode as HierarchyNodeL1,
  // _ProfitCenterL1.ProfitCenter as ProfitCenterL1,
  // _ProfitCenterL1.ParentNode as ParentNodeL1,
  // _ProfitCenterL1._Text[Language = $session.system_language ] as ProfitCenterL1Name,
   
   _ProfitCenter
}
where _ProfitCenter.ValidityEndDate >= $session.user_date 
  and _ProfitCenter.ControllingArea = 'ML00'
  and _ProfitCenter.ProfitCenter <> ''
  //and _ProfitCenter.ProfitCenterHierarchy = ''
