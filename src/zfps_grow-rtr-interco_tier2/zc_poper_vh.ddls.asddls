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
define view entity zc_poper_vh   as select from I_FiscalYearPeriod
{
  key FiscalYear       as FiscalYear,
      @Search.defaultSearchElement: true
  key FiscalPeriod     as Poper
//      FiscalYearPeriod as Fiscyearper
}
where
  FiscalYearVariant = 'K0'
  
