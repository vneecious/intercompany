@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Wrapper Totales apertura de agrupadores'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #D,
    sizeCategory: #XXL,
    dataClass: #MIXED
}

@OData.publish: true
define root view entity ZI_INTERCOSTATEMENTTOTAL_2
  with parameters
    P_PanLL0Id   : hrynode,
    P_Ledger     : fins_ledger,
    P_FiscalYear : gjahr
  as select from I_JournalEntryItem
{
  key CompanyCode
}
