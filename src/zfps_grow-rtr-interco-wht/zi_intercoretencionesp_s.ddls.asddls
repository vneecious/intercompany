@EndUserText.label: 'Interco   Retenciones por concept Single'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define root view entity ZI_IntercoRetencionesP_S
  as select from I_Language
    left outer join I_CstmBizConfignLastChgd on I_CstmBizConfignLastChgd.ViewEntityName = 'ZI_INTERCORETENCIONESP'
  composition [0..*] of ZI_IntercoRetencionesP as _IntercoRetencionesP
{
  key 1 as SingletonID,
  _IntercoRetencionesP,
  I_CstmBizConfignLastChgd.LastChangedDateTime as LastChangedAtMax,
  cast( '' as sxco_transport) as TransportRequestID,
  cast( 'X' as abap_boolean preserving type) as HideTransport
  
}
where I_Language.Language = $session.system_language
