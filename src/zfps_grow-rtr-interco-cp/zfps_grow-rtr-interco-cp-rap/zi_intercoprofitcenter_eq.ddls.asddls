@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Profit Center Equivalente'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProfitCenter_EQ
  as select from I_ProfitCenterHierarchyNode
{
  key ControllingArea,
  key ProfitCenterHierarchy,
  key HierarchyNode,
  key ValidityEndDate,
      ValidityStartDate,
      NodeType,
      HierarchyNodeVal as Profitcenter,
      ParentNode       as Profitcenter_eq
}
where
      ProfitCenterHierarchy = 'H106/ML00/ZICEQP'
  and NodeType              = 'L'
  and ValidityEndDate       >= $session.system_date
  and ValidityStartDate     <= $session.system_date
