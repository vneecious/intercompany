@EndUserText.label: 'Interco   Retenciones por concepto'
@AccessControl.authorizationCheck: #CHECK
define view entity ZI_IntercoRetencionesP
  as select from zinter_wht_zuonr
  association to parent ZI_IntercoRetencionesP_S as _IntercoRetencionAll on $projection.SingletonID = _IntercoRetencionAll.SingletonID
{
  key land1 as Land1,
  key bukrs as Bukrs,
  key lifnr as Lifnr,
  key concepto as Concepto,
  witht as Witht,
  wt_withcd as WtWithcd,
  1 as SingletonID,
  _IntercoRetencionAll
  
}
