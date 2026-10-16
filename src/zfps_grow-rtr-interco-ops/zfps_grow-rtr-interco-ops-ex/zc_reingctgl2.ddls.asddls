@EndUserText.label: 'CT V2 - Modelo GL Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

// Autor  : AGF
// Fecha  : 18.06.2026
// P8 - Exponer GlRoleDescr (descripcion del rol contable)

define view entity ZC_ReingCTGL2
  as projection on ZI_ReingCTGL2
{
  key CtUuid,
  key MatUuid,
  key GlUuid,
      GlRole,
      _GlRole.Descr as GlRoleDescr,
      Saknr,
      OpType,
      Reclassify,
      _GlRole.RoleReclas as RoleReclas,
      AutoDeterm,
      GlStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial2,
      _Contract : redirected to ZC_ReingCTContract2,
      _OpTypes  : redirected to composition child ZC_ReingCTGLOpType2,
      _GlRole
}
