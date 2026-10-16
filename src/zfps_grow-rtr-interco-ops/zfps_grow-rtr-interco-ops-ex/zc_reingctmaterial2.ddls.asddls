@EndUserText.label: 'CT V2 - Material IC Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

// Autor  : AGF
// Fecha  : 03.06.2026
// T3 - Ocultar campo Waers (Moneda) en Material (solo visible en cabecera contrato)

define view entity ZC_ReingCTMaterial2
  as projection on ZI_ReingCTMaterial2
{
  key CtUuid,
  key MatUuid,
      Matnr,
      MatDesc,
      Amount,
      @UI.hidden: true
      Waers,
      Kostl,
      Prctr,
      Saknr,
      @UI.hidden: true
      MatStatus,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      _Contract  : redirected to parent ZC_ReingCTContract2,
      _OpTypes   : redirected to composition child ZC_ReingCTOpType2,
      _Receivers : redirected to composition child ZC_ReingCTReceiver2,
      _Metrics   : redirected to composition child ZC_ReingCTMetric2,
      _GLLines   : redirected to composition child ZC_ReingCTGL2
}
