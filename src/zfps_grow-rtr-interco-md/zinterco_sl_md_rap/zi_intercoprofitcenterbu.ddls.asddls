@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Profit Center - Business Unit'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INTERCOPROFITCENTERBU
  as select distinct from I_ProfitCenterHierarchyNode as _ProfitCenter
  //      association [0..1] to I_ProfitCenterHierarchyNode as _ProfitCenterL2 on  _ProfitCenterL2.ControllingArea       = _ProfitCenter.ControllingArea
  //                                                                           and _ProfitCenterL2.ProfitCenterHierarchy = _ProfitCenter.ProfitCenterHierarchy
  //                                                                           and _ProfitCenterL2.HierarchyNode         = _ProfitCenter.ParentNode
    inner join            I_ProfitCenterHierarchyNode as _ProfitCenterL2 on  _ProfitCenterL2.ControllingArea       = _ProfitCenter.ControllingArea
                                                                         and _ProfitCenterL2.ProfitCenterHierarchy = _ProfitCenter.ProfitCenterHierarchy
                                                                         and _ProfitCenterL2.HierarchyNode         = _ProfitCenter.ParentNode


  //    association [0..1] to I_ProfitCenterHierarchyNode as _ProfitCenterL1 on  _ProfitCenterL1.ControllingArea       = $projection.ControllingAreaL2
  //                                                                         and _ProfitCenterL1.ProfitCenterHierarchy = $projection.ProfitCenterHierarchyL2
  //                                                                         and _ProfitCenterL1.HierarchyNode         = $projection.ParentNodeL2
    inner join            I_ProfitCenterHierarchyNode as _ProfitCenterL1 on  _ProfitCenterL1.ControllingArea       = _ProfitCenterL2.ControllingArea
                                                                         and _ProfitCenterL1.ProfitCenterHierarchy = _ProfitCenterL2.ProfitCenterHierarchy
                                                                         and _ProfitCenterL1.HierarchyNode         = _ProfitCenterL2.ParentNode
  //    association [0..1] to I_ProfitCenterHierarchyNode as _ProfitCenterL3 on  _ProfitCenterL2.ControllingArea       = _ProfitCenterL3.ControllingArea
  //                                                                         and _ProfitCenterL2.ProfitCenterHierarchy = _ProfitCenterL3.ProfitCenterHierarchy
  //                                                                         and _ProfitCenterL2.ParentNode            = _ProfitCenterL3.HierarchyNode
    inner join            I_ProfitCenterHierarchyNode as _ProfitCenterL3 on  _ProfitCenterL2.ControllingArea       = _ProfitCenterL3.ControllingArea
                                                                         and _ProfitCenterL2.ProfitCenterHierarchy = _ProfitCenterL3.ProfitCenterHierarchy
                                                                         and _ProfitCenterL2.ParentNode            = _ProfitCenterL3.HierarchyNode
{
  key _ProfitCenter.ProfitCenter,
      _ProfitCenterL3.ParentNode                               as SubBu,
      //         _ProfitCenterL3._Text[Language = $session.system_language ].HierarchyNodeText as SubBuName,
      _ProfitCenterL3._Text[Language = 'S' ].HierarchyNodeText as SubBuName,
      _ProfitCenterL2.ParentNode                               as BusinessUnit,
      //         _ProfitCenterL2._Text[Language = $session.system_language ].HierarchyNodeText as BusinessUnitName
      _ProfitCenterL2._Text[Language = 'S' ].HierarchyNodeText as BusinessUnitName
}
where
      _ProfitCenter.ProfitCenterHierarchy =  '0106/ML00/MLIB'
  and _ProfitCenter.NodeType              =  'L'
  and _ProfitCenter.ValidityEndDate       >= $session.user_date
  and _ProfitCenter.ControllingArea       =  'ML00'
  and _ProfitCenter.ProfitCenter          <> ''
  and _ProfitCenterL3.ParentNode          <> ''
