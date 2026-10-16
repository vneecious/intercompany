@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Cronograma Devengamiento'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTCron
  as select from zreing_ct_cron_a
  association to parent ZI_ReingCTOpType as _OpType
    on  _OpType.CtId   = $projection.CtId
    and _OpType.Matnr  = $projection.Matnr
    and _OpType.OpType = $projection.OpType
  association [1] to ZI_ReingCTContract as _Contract
    on _Contract.CtId = $projection.CtId
{
  key ct_id        as CtId,
  key matnr        as Matnr,
  key op_type      as OpType,
  key cron_year    as CronYear,
  key cron_month   as CronMonth,
      percentage   as Percentage,
      cron_status  as CronStatus,
      created_by   as CreatedBy,
      created_at   as CreatedAt,
      changed_by   as ChangedBy,
      changed_at   as ChangedAt,
      _OpType,
      _Contract
}
