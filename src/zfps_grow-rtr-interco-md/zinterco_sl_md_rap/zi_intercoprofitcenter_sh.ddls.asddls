@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help Intercompany ProfitCenter'
@Search.searchable: true
define view entity ZI_IntercoProfitCenter_SH
  as select from ZI_IntercoProfitCenter as _ProfitCenterSH
  association [0..1] to I_ProfitCenterText as _Text on  _ProfitCenterSH.ControllingArea = _Text.ControllingArea
                                                    and _ProfitCenterSH.ProfitCenter    = _Text.ProfitCenter
                                                    and _ProfitCenterSH.ValidityEndDate = _Text.ValidityEndDate
                                                    and _Text.Language                  = $session.system_language

{
      @Search: {
      defaultSearchElement: true,
      ranking: #HIGH,
      fuzzinessThreshold: 0.9
      }
  key ProfitCenter,
      @Search: {
        defaultSearchElement: true,
        ranking: #LOW,
        fuzzinessThreshold: 0.9
        }
      _Text.ProfitCenterName                   as ProfitCenterName,
      _ProfitCenterSH._ProfitCenter.Department as Department

}
group by
  ProfitCenter,
  _Text.ProfitCenterName,
  _ProfitCenterSH._ProfitCenter.Department
