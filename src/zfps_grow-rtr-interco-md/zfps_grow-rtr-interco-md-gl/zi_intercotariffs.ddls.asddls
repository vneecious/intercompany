@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tariffs'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoTariffs
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T(p_domain_name: 'ZINT_TARIFF_TYPE')
{
  key value_low as TariffType,
      text      as Description
}
where
  language = $session.system_language
