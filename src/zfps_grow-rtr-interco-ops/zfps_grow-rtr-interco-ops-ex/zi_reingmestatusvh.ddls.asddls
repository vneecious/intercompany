@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Estado de cabecera de carga de métricas'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.representativeKey: 'MeStatus'
@Search.searchable: true
define view entity ZI_ReingMEStatusVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZREING_ME_STATUS' )
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key value_low as MeStatus,
      text      as MeStatusText
}
