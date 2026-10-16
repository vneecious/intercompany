@AbapCatalog.viewEnhancementCategory: [#NONE] 
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Get data from zfi_cds_mt005 tier2'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
 
define root view entity ZI_CDS_MT005
  as select from ZFI_CDS_MT005
{
  key zagrup_cuentas,
  key zconsolidation,
      zpl5,
      displayName
}
