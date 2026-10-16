@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Estado de Contrato IC'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZI_REING_CT_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZREING_CT_STATUS' )
{
      @UI.hidden: true
      @Search.defaultSearchElement: true
  key value_low as CtStatus,

      @Semantics.text: true
      text       as StatusText
}

