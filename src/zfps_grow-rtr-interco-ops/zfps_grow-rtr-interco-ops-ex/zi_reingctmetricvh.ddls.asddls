@AbapCatalog.sqlViewName: 'ZV_REINCTMETRVH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CT - Value Help Metricas Activas'
@Search.searchable: true

define view ZI_ReingCTMetricVH
  as select from zreing_mcv_a as v
  inner join   zreing_mc_a   as m on  m.metric_code = v.metric_code
                                  and m.mandt        = v.mandt
{
  @Search.defaultSearchElement: true
  @Search.ranking: #HIGH
  key v.metric_code    as MetricCode,
  // Begin Mod 01.09.2026 EXT_AGFAGINA - VersionNum pasa a formar parte de la key.
  // La key tecnica OData era solo MetricCode. Cuando una metrica tiene mas de una
  // version activa a la vez (caso real M-0004, versiones 002 y 003 con la misma
  // vigencia), la vista devuelve dos filas con el mismo key predicate y el modelo
  // OData V4 del front aborta la lectura completa de la lista con
  // "Duplicate key predicate: ('M-0004')". No es un problema de UI: la colision
  // ocurre en la cache del modelo, antes de llegar a cualquier control.
  // El consumo ya trataba VersionNum como parte de la identidad: la asociacion
  // _MetricVH de ZI_ReingCTMetric2 empareja por MetricCode Y VersionNum.
  key v.version_num    as VersionNum,
  // End Mod 01.09.2026 EXT_AGFAGINA
  @Search.defaultSearchElement: true
  @Search.ranking: #MEDIUM
      m.metric_desc    as MetricDesc,
      m.metric_type    as MetricType,
      v.valid_from     as ValidFrom,
      v.valid_to       as ValidTo,
      v.version_status as VersionStatus
}
where v.version_status = 'A'
  and v.valid_from     <= $session.system_date
  and v.valid_to       >= $session.system_date
