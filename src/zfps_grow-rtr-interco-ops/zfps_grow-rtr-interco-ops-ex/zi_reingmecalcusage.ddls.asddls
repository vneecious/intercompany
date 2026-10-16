@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ME - Uso de Insumos en Calculo'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #TRANSACTIONAL

define view entity ZI_ReingMECalcUsage
  as select from zreing_calcusage
{
  key usage_id          as UsageId,
      calc_run_id       as CalcRunId,
      line_num          as LineNum,
      insumo_type       as InsumoType,
      me_h_id           as MeHId,
      me_load_version   as MeLoadVersion,
      used_at           as UsedAt,
      libr_set_at       as LibrSetAt,
      libr_rev_at       as LibrRevAt
}
where insumo_type = 'ME'
