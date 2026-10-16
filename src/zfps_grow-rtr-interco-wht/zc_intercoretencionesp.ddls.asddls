@EndUserText.label: 'Maintain Interco   Retenciones por conce'
@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
define view entity ZC_IntercoRetencionesP
  as projection on ZI_IntercoRetencionesP
{
  key Land1,
  key Bukrs,
  key Lifnr,
  key Concepto,
  Witht,
  WtWithcd,
  @Consumption.hidden: true
  SingletonID,
  _IntercoRetencionAll : redirected to parent ZC_IntercoRetencionesP_S
  
}
