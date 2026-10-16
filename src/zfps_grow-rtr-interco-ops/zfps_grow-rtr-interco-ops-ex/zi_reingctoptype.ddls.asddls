@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Tipos de Operacion'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTOpType
  as select from zreing_ct_opt_a
  association to parent ZI_ReingCTMaterial as _Material
    on  _Material.CtId  = $projection.CtId
    and _Material.Matnr = $projection.Matnr
  association [1] to ZI_ReingCTContract as _Contract
    on _Contract.CtId = $projection.CtId
  composition [0..*] of ZI_ReingCTCron as _Cron
{
  key ct_id        as CtId,
  key matnr        as Matnr,
  key op_type      as OpType,
      op_subtype   as OpSubtype,
      defer_from   as DeferFrom,
      defer_to     as DeferTo,
      dist_type    as DistType,
      installments as Installments,
      exch_type    as ExchType,
      exch_rate    as ExchRate,
      waers        as Waers,
      total_pct    as TotalPct,
      op_status    as OpStatus,
      created_by   as CreatedBy,
      created_at   as CreatedAt,
      changed_by   as ChangedBy,
      changed_at   as ChangedAt,
      _Material,
      _Contract,
      _Cron
}
