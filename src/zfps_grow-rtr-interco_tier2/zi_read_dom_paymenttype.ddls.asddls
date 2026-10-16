@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Read Domain PaymentType SH'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@ObjectModel.resultSet.sizeCategory: #XS   
@Search.searchable: true 
define view entity ZI_READ_DOM_PAYMENTTYPE
  as select from dd07t
{
       
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH 
      @ObjectModel.text.element:  [ 'Text' ]
      @UI.textArrangement: #TEXT_LAST
  key cast ( substring( domvalue_l, 1, 1 ) as zint_dte_paymenttype preserving type ) as value,

      @Semantics.text: true
      ddtext                                                                          as Text
      
}
where
      domname    = 'ZINT_DOM_PAYMENTTYPE'
  and ddlanguage = $session.system_language
  and as4local   = 'A'
  and as4vers    = '0000'
 