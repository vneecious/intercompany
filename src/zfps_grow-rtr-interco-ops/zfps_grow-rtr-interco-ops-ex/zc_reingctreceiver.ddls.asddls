@EndUserText.label: 'CT - Sociedades Receptoras Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTReceiver
  as projection on ZI_ReingCTReceiver
{
  key CtId,
  key Matnr,
  key RecBukrs,
      Prctr,
      Country,
      RecStatus,
      ValidFrom,
      ValidTo,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial,
      _Contract : redirected to ZC_ReingCTContract
}
