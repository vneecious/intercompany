@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'IntercoExemption.IsValid Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoExemptionIsValidVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'Z001_DOM_PROCESS_STATUS' )
{
  key domain_name    as DomainName,
  key value_position as ValuePosition,
  key language       as Language,
      value_low      as FixedValue,
      text           as Description
}
where
  language = $session.system_language
