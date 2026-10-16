@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search help to Status for Calculation'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoPropStatusCalc_SH as select from ZI_DomainValuesText( p_domain_name: 'ZINT_DOM_CPIC_STATUS' )
{
    @ObjectModel.text.element:  [ 'StatusName' ]
    key DomainValue as Status,
    DomainText as StatusName
}where
  Language = $session.system_language
