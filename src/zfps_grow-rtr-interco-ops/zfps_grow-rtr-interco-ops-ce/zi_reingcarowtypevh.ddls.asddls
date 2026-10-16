//----------------------------------------------------------------------
// Created by     : Carlos Alexander Gonzalez Lopez (EXT_GONZALCA)
// Requirement N° :
// Date           : 07.07.2026
// Description    : Reintegro Gastos - Motor de Calculo IC - F6 delta: Value Help LineStatus/RowType
// Transport      : DS4K9B5XZC
// Reference      : 5000049390
//----------------------------------------------------------------------
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tipo de fila (UNION CDS)'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'RowType'
@Search.searchable: true
define view entity ZI_ReingCARowTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZREING_CA_ROW_TYPE' )
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key value_low as RowType,
      text      as RowTypeText
}
// Begin Insert V001 (10.09.2026 | EXT_GONZALCA) - language filter.
// DDCDS_CUSTOMER_DOMAIN_VALUE_T returns ONE ROW PER TRANSLATED LANGUAGE, so the
// declared key (value_low) is duplicated and the value help collapses to a single
// entry - the first one the framework happens to pick. Same defect ZI_ReingExrtTypeVH
// hit on 31.08.2026, latent here only while ZREING_CA_ROW_TYPE was maintained in one
// language. The domain is now translated (E + S), so the filter is required.
// RowType is also a key of ZI_ReingCALineAll since fixes-013, so a collapsed value
// help would break filtering on a field the app now exposes as part of the key.
where language = $session.system_language
// End Insert V001 (10.09.2026 | EXT_GONZALCA)
