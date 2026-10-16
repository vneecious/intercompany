@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Plain version of the I_ProfitCenterHierarchyNode (5L)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_ProfitCenterNodePlain as select from I_ProfitCenterHierarchyNode as _Base
    
    left outer join I_ProfitCenterHierarchyNode as _BaseMinus1 on  _Base.ProfitCenterHierarchy  = _BaseMinus1.ProfitCenterHierarchy
                                                               and _BaseMinus1.HierarchyNode = _Base.ParentNode
    left outer join I_ProfitCenterHierarchyNode as _BaseMinus2 on  _BaseMinus1.ProfitCenterHierarchy = _BaseMinus2.ProfitCenterHierarchy
                                                            and _BaseMinus2.HierarchyNode      = _BaseMinus1.ParentNode
    left outer join I_ProfitCenterHierarchyNode as _BaseMinus3 on  _BaseMinus2.ProfitCenterHierarchy = _BaseMinus3.ProfitCenterHierarchy
                                                            and _BaseMinus3.HierarchyNode      = _BaseMinus2.ParentNode
    left outer join I_ProfitCenterHierarchyNode as _BaseMinus4 on  _BaseMinus3.ProfitCenterHierarchy = _BaseMinus4.ProfitCenterHierarchy
                                                            and _BaseMinus4.HierarchyNode      = _BaseMinus3.ParentNode
    left outer join I_ProfitCenterHierarchyNode as _BaseMinus5 on  _BaseMinus4.ProfitCenterHierarchy = _BaseMinus5.ProfitCenterHierarchy
                                                            and _BaseMinus5.HierarchyNode      = _BaseMinus4.ParentNode                                                           
{
    key _Base.ControllingArea,
    key _Base.ProfitCenterHierarchy,
    key _Base.HierarchyNode,
    key _Base.ValidityEndDate,
    _Base._Text[ Language = $session.system_language ].HierarchyNodeText as HierarchyNodeText,
    _Base.ProfitCenter,
        
    
      case
          when _Base.HierarchyNodeLevel = '000006' then _BaseMinus5.HierarchyNode
          when _Base.HierarchyNodeLevel = '000005' then _BaseMinus4.HierarchyNode
          when _Base.HierarchyNodeLevel = '000004' then _BaseMinus3.HierarchyNode
          when _Base.HierarchyNodeLevel = '000003' then _BaseMinus2.HierarchyNode
          when _Base.HierarchyNodeLevel = '000002' then _BaseMinus1.HierarchyNode
          when _Base.HierarchyNodeLevel = '000001' then _Base.HierarchyNode
          else ''
      end as HierarchyNodeL0,
      
      case
          when _Base.HierarchyNodeLevel = '000006' then _BaseMinus4.HierarchyNode
          when _Base.HierarchyNodeLevel = '000005' then _BaseMinus3.HierarchyNode
          when _Base.HierarchyNodeLevel = '000004' then _BaseMinus2.HierarchyNode
          when _Base.HierarchyNodeLevel = '000003' then _BaseMinus1.HierarchyNode
          when _Base.HierarchyNodeLevel = '000002' then _Base.HierarchyNode
          else ''
      end as HierarchyNodeL1,

      case
          when _Base.HierarchyNodeLevel = '000006' then _BaseMinus3.HierarchyNode
          when _Base.HierarchyNodeLevel = '000005' then _BaseMinus2.HierarchyNode
          when _Base.HierarchyNodeLevel = '000004' then _BaseMinus1.HierarchyNode
          when _Base.HierarchyNodeLevel = '000003' then _Base.HierarchyNode
          else ''
      end as HierarchyNodeL2,

      case
          when _Base.HierarchyNodeLevel = '000006' then _BaseMinus2.HierarchyNode
          when _Base.HierarchyNodeLevel = '000005' then _BaseMinus1.HierarchyNode
          when _Base.HierarchyNodeLevel = '000004' then _Base.HierarchyNode
          else ''
      end as HierarchyNodeL3,

      case
          when _Base.HierarchyNodeLevel = '000006' then _BaseMinus1.HierarchyNode
          when _Base.HierarchyNodeLevel = '000005' then _Base.HierarchyNode
          else ''
      end as HierarchyNodeL4,

      case
          when _Base.HierarchyNodeLevel = '000006' then _Base.HierarchyNode
          else ''
      end as HierarchyNodeL5
}
