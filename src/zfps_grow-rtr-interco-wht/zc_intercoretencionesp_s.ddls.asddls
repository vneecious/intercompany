@EndUserText.label: 'Maintain Interco   Retenciones por conce'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'SingletonID' ]
define root view entity ZC_IntercoRetencionesP_S
  provider contract transactional_query
  as projection on ZI_IntercoRetencionesP_S
{
  key SingletonID,
  LastChangedAtMax,
  TransportRequestID,
  HideTransport,
  _IntercoRetencionesP : redirected to composition child ZC_IntercoRetencionesP
  
}
