@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT V2 - Tipos de Operacion'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

// Autor  : EXT_OSCUGALD
// Fecha  : 04.06.2026
// Cambio : OpUuid como key, composiciones restauradas

define view entity ZI_ReingCTOpType2
  as select from zreing_ct2_opt_a
  association     to parent ZI_ReingCTMaterial2 as _Material on  _Material.CtUuid  = $projection.CtUuid
                                                             and _Material.MatUuid = $projection.MatUuid
  association [1] to ZI_ReingCTContract2        as _Contract on  _Contract.CtUuid = $projection.CtUuid
  composition [0..*] of ZI_ReingCTCron2         as _Cron
  composition [0..*] of ZI_ReingCTOpRate2       as _OpRates
{
  key ct_uuid         as CtUuid,
  key mat_uuid        as MatUuid,
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_ReingOpTypesVH', element: 'OpType' }
      }]
  key op_type         as OpType,
  key op_uuid         as OpUuid,
      op_instance_num as OpInstanceNum,
      parent_instance_id as ParentInstanceId,
      op_type_descr   as OpTypeDescr,
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_ReingExrtTypeVH', element: 'ExchRateType' }
      }]
      exch_rate_type  as ExchRateType,
      exch_rate_descr as ExchRateDescr,
      op_subtype      as OpSubtype,
      defer_from      as DeferFrom,
      defer_to        as DeferTo,
      dist_type        as DistType,
      me_period_offset as MePeriodOffset,
      installments     as Installments,
      exch_type       as ExchType,
      exch_rate       as ExchRate,
      waers           as Waers,
      total_pct       as TotalPct,
      op_status       as OpStatus,
      @Semantics.user.createdBy: true
      created_by      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by      as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at      as ChangedAt,
      _Material,
      _Contract,
      _Cron,
      _OpRates
}
