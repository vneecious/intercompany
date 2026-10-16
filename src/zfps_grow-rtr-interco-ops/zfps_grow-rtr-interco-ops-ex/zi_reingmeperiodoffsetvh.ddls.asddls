@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Offset Periodo Metrica'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING
@Search.searchable: true

define view entity ZI_ReingMePeriodOffsetVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZREING_ME_PERIOD_OFFSET' )
{
  @Search.defaultSearchElement: true
  key value_low       as MePeriodOffset,
      text            as MePeriodOffsetDesc
}
