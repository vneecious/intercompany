@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: SH para Cost Center Area'
define view entity ZI_IntercoCostCenterArea_SH as select from ZI_IntercoCostCenterArea as _Area
    left outer join I_SetHeaderText            as _AreaText on _AreaText.SetID    = _Area.CostCenterArea
                                                           and _AreaText.Language = $session.system_language  

{
  key _Area.CostCenterArea,
  _AreaText.SetDescription as CostCenterAreaName 
} 
group by _Area.CostCenterArea, _AreaText.SetDescription
  
  
