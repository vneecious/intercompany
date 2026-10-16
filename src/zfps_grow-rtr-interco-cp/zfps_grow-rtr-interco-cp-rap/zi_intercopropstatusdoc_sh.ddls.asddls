@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search help to Status for Document'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INTERCOPROPSTATUSDOC_SH as select from ZI_DomainValuesText( p_domain_name: 'ZINT_DOM_CPID_STATUS' )
{
    @ObjectModel.text.element:  [ 'StatusName' ]
    key DomainValue as Status,
    @Semantics.text: true
    DomainText as StatusName,
    @Semantics.language: true
    Language
}
where Language = $session.system_language
