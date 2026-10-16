//@AbapCatalog.viewEnhancementCategory: [#NONE]
//@AccessControl.authorizationCheck: #CHECK
//@EndUserText.label: 'CT V2 - Cronograma Devengamiento'
//@ObjectModel.usageType.serviceQuality: #X
//@ObjectModel.usageType.sizeCategory: #S
//@ObjectModel.usageType.dataClass: #MIXED
//
//// Autor  : EXT_OSCUGALD
//// Fecha  : 04.06.2026
//// Cambio : OpInstanceNum como campo no-key, sin ON condition del parent
//
//define view entity ZI_ReingCTCron2
//  as select from zreing_ct2_crn_a
//  association to parent ZI_ReingCTOpType2 as _OpType
//    on  _OpType.CtUuid  = $projection.CtUuid
//    and _OpType.MatUuid = $projection.MatUuid
//    and _OpType.OpType  = $projection.OpType
//  association [1] to ZI_ReingCTContract2 as _Contract
//    on _Contract.CtUuid = $projection.CtUuid
//{
//  key ct_uuid         as CtUuid,
//  key mat_uuid        as MatUuid,
//  key op_type         as OpType,
//  key cron_year       as CronYear,
//  key cron_month      as CronMonth,
//      op_instance_num as OpInstanceNum,
//      percentage      as Percentage,
//      cron_status     as CronStatus,
//      @Semantics.user.createdBy: true
//      created_by      as CreatedBy,
//      @Semantics.systemDateTime.createdAt: true
//      created_at      as CreatedAt,
//      @Semantics.user.lastChangedBy: true
//      changed_by      as ChangedBy,
//      @Semantics.systemDateTime.lastChangedAt: true
//      changed_at      as ChangedAt,
//      _OpType,
//      _Contract
//}
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT V2 - Cronograma Devengamiento'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTCron2
  as select from zreing_ct2_crn_a
  association to parent ZI_ReingCTOpType2 as _OpType
    on  _OpType.CtUuid  = $projection.CtUuid
    and _OpType.MatUuid = $projection.MatUuid
    and _OpType.OpType  = $projection.OpType
    and _OpType.OpUuid  = $projection.OpUuid
  association [1] to ZI_ReingCTContract2 as _Contract
    on _Contract.CtUuid = $projection.CtUuid
{
  key ct_uuid         as CtUuid,
  key mat_uuid        as MatUuid,
  key op_type         as OpType,
  key op_uuid         as OpUuid,
  key cron_year       as CronYear,
  key cron_month      as CronMonth,
      op_instance_num as OpInstanceNum,
      percentage      as Percentage,
      cron_status     as CronStatus,
      @Semantics.user.createdBy: true
      created_by      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by      as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at      as ChangedAt,
      _OpType,
      _Contract
}
