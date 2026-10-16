@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT V2 - Historial de Cambios Projection'
@Metadata.allowExtensions: true

define view entity ZC_ReingC2Hist
  as projection on ZI_ReingC2Hist
{
  key CtUuid,
  key HistUuid,
      ChangedAt,
      ChangedBy,
      EntityLevel,
      EntityKey,
      Action,
      FieldName,
      ValueOld,
      ValueNew,
      _Contract : redirected to parent ZC_ReingCTContract2
}
