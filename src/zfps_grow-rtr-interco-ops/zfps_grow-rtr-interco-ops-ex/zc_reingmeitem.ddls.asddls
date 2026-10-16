@EndUserText.label: 'ME - Item Carga Metricas Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingMEItem
  as projection on ZI_ReingMEItem
{
  key MeHId,
  key MeIId,
      Bukrs,
      Country,
      Prctr,
      Campana,
      RoleCategory,
      Allocation,
      MeValue,
      PrevValue,
      Prev2Value,
      SharePct,
      VarPct,
      VarPct2,
      VarFlag,
      LocalLastChangedAt,
      _Header : redirected to parent ZC_ReingMEHeader
}
