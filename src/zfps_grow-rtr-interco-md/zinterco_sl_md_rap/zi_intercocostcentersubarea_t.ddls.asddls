@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany Cost center Sub Area Text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoCostCenterSubArea_T
  as select from    ZI_IntercoCostCenterSubArea as _SubArea
    left outer join I_SetHeaderText             as _SubAreaText on  _SubAreaText.SetID    = _SubArea.CostCenterSubArea
                                                                and _SubAreaText.Language = $session.system_language
    left outer join I_SetHeaderText             as _AreaText    on  _AreaText.SetID    = _SubArea.CostCenterArea
                                                                and _AreaText.Language = $session.system_language

{
  key _SubArea.CostCenterSubArea     as CostCenterSubArea,
      _SubAreaText.SetDescription    as CostCenterSubAreaName,
      _SubArea.HierarchyNode         as HierarchyNode,
      _SubArea.HierarchyNodeSequence as HierarchyNodeSequence,
      _SubArea.ParentNode            as ParentNode,
      _SubArea.CostCenterArea        as CostCenterArea,
      _AreaText.SetDescription       as CostCenterAreaName
}
