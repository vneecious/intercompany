@AbapCatalog.sqlViewName: 'ZV_REINGTXTYVH'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Tipo Impuesto IC'
@Search.searchable: true

define view ZI_ReingTXTypeDomVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZREING_TAX_TYPE' )
{
  @Search.defaultSearchElement: true
  key value_low as TaxType,
      text      as TaxTypeDesc
}
