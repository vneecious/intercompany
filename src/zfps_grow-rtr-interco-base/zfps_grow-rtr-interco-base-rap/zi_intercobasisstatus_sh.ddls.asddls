@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany bases States Value Help'
define view entity ZI_INTERCOBASISSTATUS_SH
  as select from ZI_DomainValuesText (p_domain_name:'ZINT_DOM_ISRELEASE')
{
      @ObjectModel.text.element:  [ 'StatusDescription' ]
  key DomainValue as StatusId,
      DomainText  as StatusDescription
}
where
  Language = $session.system_language
