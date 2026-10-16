@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'TX - VH Tipos Impositivos'
@ObjectModel.resultSet.sizeCategory: #XS
@Search.searchable: true
define view entity ZI_ReingTXTypeVH
  as select from zreing_tx_type_c
{
      @UI.lineItem: [{ position: 10 }]
      @Search.defaultSearchElement: true
  key tax_type         as TaxType,
      @UI.lineItem: [{ position: 20 }]
      @Search.defaultSearchElement: true
      tax_type_desc    as TaxTypeDesc,
      @UI.lineItem: [{ position: 30 }]
      tax_category     as TaxCategory,
      gross_up_default as GrossUpDefault
}
where active = 'X'
