@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ME - Item Carga Metricas View'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingMEItem
  as select from zreing_me_i_a as I
  left outer join I_CompanyCode as CC
    on CC.CompanyCode = I.bukrs
  association to parent ZI_ReingMEHeader as _Header
    on $projection.MeHId = _Header.MeHId
{
  key I.me_h_id                as MeHId,
  key I.me_i_id                as MeIId,
      I.bukrs                  as Bukrs,
      CC.Country               as Country,
      I.prctr                  as Prctr,
      I.campana                as Campana,
      I.role_category          as RoleCategory,
      I.allocation             as Allocation,
      I.me_value               as MeValue,
      I.prev_value             as PrevValue,
      I.prev2_value            as Prev2Value,
      I.share_pct              as SharePct,
      I.var_pct                as VarPct,
      I.var_pct2               as VarPct2,
      I.var_flag               as VarFlag,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      I.local_last_changed_at  as LocalLastChangedAt,
      _Header
}
