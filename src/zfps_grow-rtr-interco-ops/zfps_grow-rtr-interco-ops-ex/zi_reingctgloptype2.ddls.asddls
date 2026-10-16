@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - GL Tipos de Operacion'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED

define view entity ZI_ReingCTGLOpType2
  as select from zreing_glop_a
  association to parent ZI_ReingCTGL2 as _GL
    on  _GL.CtUuid  = $projection.CtUuid
    and _GL.MatUuid = $projection.MatUuid
    and _GL.GlUuid  = $projection.GlUuid
  association [1] to ZI_ReingCTContract2 as _Contract
    on _Contract.CtUuid = $projection.CtUuid
{
  key ct_uuid       as CtUuid,
  key mat_uuid      as MatUuid,
  key gl_uuid       as GlUuid,
  key glop_uuid     as GlopUuid,
      op_type       as OpType,
      op_type_descr as OpTypeDescr,
      gl_role       as GlRole,
      @Semantics.user.createdBy: true
      created_by    as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at    as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changed_by    as ChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changed_at    as ChangedAt,
      _GL,
      _Contract
}
