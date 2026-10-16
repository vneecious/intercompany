@EndUserText.label: 'CT V2 - Receptoras Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingCTReceiver2
  as projection on ZI_ReingCTReceiver2
{
  key CtUuid,
  key MatUuid,
  key RecUuid,
      RecBukrs,
      Prctr,
      Campana,
      RoleCategory,
      Allocation,
      Country,
      RecStatus,
      ValidFrom,
      ValidTo,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Material : redirected to parent ZC_ReingCTMaterial2,
      _Contract : redirected to ZC_ReingCTContract2
}
