//@AbapCatalog.viewEnhancementCategory: [#NONE]
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'CT V2 - Tasas Manuales OP x Receptora'
//@ObjectModel.usageType.serviceQuality: #X
//@ObjectModel.usageType.sizeCategory: #S
//@ObjectModel.usageType.dataClass: #MIXED
//
//// Autor  : EXT_OSCUGALD
//// Fecha  : 04.06.2026
//// Cambio : OpInstanceNum quitado del ON condition del parent
//
//define view entity ZI_ReingCTOpRate2
//  as select from zreing_ct_o_r_a
//  association to parent ZI_ReingCTOpType2 as _OpType
//    on  _OpType.CtUuid  = $projection.CtUuid
//    and _OpType.MatUuid = $projection.MatUuid
//    and _OpType.OpType  = $projection.OpType
//  association [1] to ZI_ReingCTContract2 as _Contract
//    on _Contract.CtUuid = $projection.CtUuid
//{
//  key ct_uuid               as CtUuid,
//  key mat_uuid              as MatUuid,
//  key op_type               as OpType,
//  key op_instance_num       as OpInstanceNum,
//  key bukrs_recv            as BukrsRecv,
//      manual_exch_rate      as ManualExchRate,
//      local_last_changed_at as LocalLastChangedAt,
//      _OpType,
//      _Contract
//}
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - Tasas Manuales OP x Receptora'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTOpRate2
  as select from zreing_ct_o_r_a
  association to parent ZI_ReingCTOpType2 as _OpType
    on  _OpType.CtUuid  = $projection.CtUuid
    and _OpType.MatUuid = $projection.MatUuid
    and _OpType.OpType  = $projection.OpType
    and _OpType.OpUuid  = $projection.OpUuid
  association [1] to ZI_ReingCTContract2 as _Contract
    on _Contract.CtUuid = $projection.CtUuid
{
  key ct_uuid               as CtUuid,
  key mat_uuid              as MatUuid,
  key op_type               as OpType,
  key op_uuid               as OpUuid,
  key op_instance_num       as OpInstanceNum,
  key bukrs_recv            as BukrsRecv,
      manual_exch_rate      as ManualExchRate,
      local_last_changed_at as LocalLastChangedAt,
      _OpType,
      _Contract
}
