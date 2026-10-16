@EndUserText.label: 'ME - Cabecera Carga Metricas Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZC_ReingMEHeader
  provider contract transactional_query
  as projection on ZI_ReingMEHeader
{
  key MeHId,
      CtId,
      CtExtNum,
      Matnr,
      MatnrDesc,
      Proveedor,
      PeriodYear,
      PeriodMonth,
      LoadVersion,
      MeStatus,
      MetricCode,
      // Mod 25.09.2026 EXT_AGFAGINA - DF-554: nombre de la metrica, desde la
      // version exacta del Catalogo de Metricas. Solo lectura.
      _MetricVersion.MetricDesc as MetricDesc,
      MetVersion,
      TotalSharePct,
      ReleasedBy,
      ReleasedAt,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _Item  : redirected to composition child ZC_ReingMEItem,
      _Contract,
      //Begin Insert V001 (CC) - PA-ME-11
      _CalcUsage
      //End Insert V001 (CC) - PA-ME-11
}
