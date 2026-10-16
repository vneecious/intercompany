@AbapCatalog.sqlViewName: 'ZV_REINGREFPERVH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Periodo de Referencia IC'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING
@Search.searchable: true

define view ZI_ReingRefPeriodVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZREING_REF_PERIOD' )
{
  @Search.defaultSearchElement: true
  key value_low as RefPeriod,
      text      as RefPeriodDesc
}
