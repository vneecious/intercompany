@EndUserText.label: 'CT V2 - GL Tipos de Operacion Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTGLOpType2
  as projection on ZI_ReingCTGLOpType2
{
  key CtUuid,
  key MatUuid,
  key GlUuid,
  key GlopUuid,
      OpType,
      OpTypeDescr,
      GlRole,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _GL       : redirected to parent ZC_ReingCTGL2,
      _Contract : redirected to ZC_ReingCTContract2
}
