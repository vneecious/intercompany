@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Message table for Abap Cloud'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZR_T100_M as select from T100_M
{
    key sprsl,
    key arbgb,
    key msgnr,
    text
}// where sprsl = $session.system_language
