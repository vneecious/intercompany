@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - Historial de Cambios'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingC2Hist
  as select from zreing_c2_hist_a
  association to parent ZI_ReingCTContract2 as _Contract
    on _Contract.CtUuid = $projection.CtUuid
{
  key ct_uuid      as CtUuid,
  key hist_uuid    as HistUuid,
      changed_at   as ChangedAt,
      changed_by   as ChangedBy,
      entity_level as EntityLevel,
      entity_key   as EntityKey,
      action       as Action,
      field_name   as FieldName,
      value_old    as ValueOld,
      value_new    as ValueNew,
      _Contract
}
