@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Domain Values Text'
define view entity ZI_DomainValuesText
  with parameters
    p_domain_name : sxco_ad_object_name --abap.char(30)
  as select from dd07t as _Domain

  // DDCDS_CUSTOMER_DOMAIN_VALUE_T ( p_domain_name: 'ZINTRC_FLOW2' )
{
      @Consumption.hidden: true
  key domname    as DomainName,
      @Consumption.hidden: true
      @Semantics.language: true
  key ddlanguage as Language,

  key domvalue_l as DomainValue,

      @Semantics.text: true
      ddtext     as DomainText
}
where
  domname = $parameters.p_domain_name
