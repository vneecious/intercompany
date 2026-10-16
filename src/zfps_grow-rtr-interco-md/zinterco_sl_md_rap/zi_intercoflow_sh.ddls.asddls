@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Discontinuation Indicator Value Help'
define view entity ZI_IntercoFlow_SH as select from ZI_DomainValuesText (p_domain_name:'ZINTRC_FLOW')
{
      @ObjectModel.text.element:  [ 'FlowName' ]
  key DomainValue as Flow,
      DomainText  as FlowName
}
where
  Language = 'E'
