@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - Modelo GL'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

// Autor  : AGF
// Fecha  : 18.06.2026
// P8 - Asociacion a ZI_ReingGLRoles para obtener Descr del rol contable

define view entity ZI_ReingCTGL2
  as select from zreing_ct2_gl_a
  association to parent ZI_ReingCTMaterial2 as _Material
    on  _Material.CtUuid  = $projection.CtUuid
    and _Material.MatUuid = $projection.MatUuid
  association [1]    to ZI_ReingCTContract2  as _Contract
    on _Contract.CtUuid = $projection.CtUuid
  composition [0..*] of ZI_ReingCTGLOpType2 as _OpTypes
  association [0..1] to ZI_ReingGLRoles      as _GlRole
    on _GlRole.GlRole = $projection.GlRole
{
  key ct_uuid     as CtUuid,
  key mat_uuid    as MatUuid,
  key gl_uuid     as GlUuid,
      gl_seq      as GlSeq,
      gl_role     as GlRole,
      saknr       as Saknr,
      op_type     as OpType,
      reclassify  as Reclassify,
      auto_determ as AutoDeterm,
      gl_status   as GlStatus,
      @Semantics.user.createdBy: true
      created_by  as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at  as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by  as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at  as ChangedAt,
      _Material,
      _Contract,
      _OpTypes,
      _GlRole
}
