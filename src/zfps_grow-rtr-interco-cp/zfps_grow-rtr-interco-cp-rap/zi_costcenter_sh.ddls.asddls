@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cost Center Search Help'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_CostCenter_SH
  as select from I_CostCenter as _CostCenterSH
  association [0..1] to I_CostCenterText as _Text on  _CostCenterSH.ControllingArea = _Text.ControllingArea
                                                  and _CostCenterSH.CostCenter      = _Text.CostCenter
                                                  and _CostCenterSH.ValidityEndDate = _Text.ValidityEndDate
                                                  and _Text.Language = $session.system_language
{
  key CostCenter,
  _Text.CostCenterDescription as CostCenterDescription
}
where
      ControllingArea = 'ML00'
  and CostCenter <> ''
  and ValidityEndDate >= $session.user_date
group by
  CostCenter, _Text.CostCenterDescription
