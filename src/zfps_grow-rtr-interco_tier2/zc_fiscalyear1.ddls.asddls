@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ayuda de busqueda Fiscal Year'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
 
@Search.searchable: true
@UI.presentationVariant: [{ sortOrder: [{ by: 'FiscalYear', direction: #DESC }] }]
define view entity ZC_FISCALYEAR1   as select from I_FiscalYear 
{
      @Semantics.calendar.year: true
      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key FiscalYear
}  
where
  FiscalYearVariant = 'K0' 
  
