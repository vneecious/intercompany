@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Historial de Cambios Version Projection'
@Metadata.allowExtensions: true

define view entity ZC_ReingMCVerHist
  provider contract transactional_query
  as projection on ZI_ReingMCVerHist
{
  key MetricCode,
  key VersionNum,
  key HistUuid,
      ChangedAt,
      ChangedBy,
      Action,
      FieldName,
      ValueOld,
      ValueNew
}
