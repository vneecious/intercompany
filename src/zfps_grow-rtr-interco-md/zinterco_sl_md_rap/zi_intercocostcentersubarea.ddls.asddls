@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany Cost center Sub Area'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoCostCenterSubArea as select from I_CostCenterHierarchyNode

{
  key HierarchyNodeVal                        as CostCenterSubArea,
      HierarchyNode                           as HierarchyNode,
      HierarchyNodeSequence                   as HierarchyNodeSequence,
      ParentNode                              as ParentNode,
      
      case 
        when length(ParentNode) > 4 and left(ParentNode, 1) = '0' then right(ParentNode, length(ParentNode)-1)
        else ParentNode 
      end as CostCenterArea
}
where  ValidityEndDate  >= $session.user_date
  and CostCenterHierarchy = '0101/ML00/ML00'
  and ControllingArea = 'ML00'
  and NodeType = 'N'
