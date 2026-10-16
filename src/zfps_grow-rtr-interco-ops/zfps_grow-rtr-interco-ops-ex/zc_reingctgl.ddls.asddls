@EndUserText.label: 'CT - Modelo GL Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTGL
  as projection on ZI_ReingCTGL
{
  key CtId,
  key Matnr,
  key GlSeq,
      GlRole,
      Saknr,
      OpType,
      Campaign,
      Reclassify,
      AutoDeterm,
      GlStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial,
      _Contract : redirected to ZC_ReingCTContract
}
