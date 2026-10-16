@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'CT - Modelo GL'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTGL
  as select from zreing_ct_gl_a
  association to parent ZI_ReingCTMaterial as _Material
    on  _Material.CtId  = $projection.CtId
    and _Material.Matnr = $projection.Matnr
  association [1] to ZI_ReingCTContract as _Contract
    on _Contract.CtId = $projection.CtId
{
  key ct_id       as CtId,
  key matnr       as Matnr,
  key gl_seq      as GlSeq,
      gl_role     as GlRole,
      saknr       as Saknr,
      op_type     as OpType,
      campaign    as Campaign,
      reclassify  as Reclassify,
      auto_determ as AutoDeterm,
      gl_status   as GlStatus,
      created_by  as CreatedBy,
      created_at  as CreatedAt,
      changed_by  as ChangedBy,
      changed_at  as ChangedAt,
      _Material,
      _Contract
}
