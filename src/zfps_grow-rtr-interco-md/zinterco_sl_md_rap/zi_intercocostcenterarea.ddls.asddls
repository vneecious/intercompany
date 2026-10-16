@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Cost Center Area'
define view entity ZI_IntercoCostCenterArea as select from I_CostCenterHierarchyNode as _Node
{
  key case 
        when length(_Node.ParentNode) > 4 and left(_Node.ParentNode, 1) = '0' 
        then right(_Node.ParentNode, length(_Node.ParentNode)-1)
        else _Node.ParentNode 
      end as CostCenterArea,
      _Node.ParentNode as ParentNode 
}
where _Node.ValidityEndDate  >= $session.user_date
  and _Node.CostCenterHierarchy = '0101/ML00/ML00'
  and _Node.ControllingArea = 'ML00'
  and _Node.NodeType = 'N'
