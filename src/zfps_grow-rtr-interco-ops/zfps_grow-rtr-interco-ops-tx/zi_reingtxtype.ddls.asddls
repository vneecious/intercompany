@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reglas Fiscales IC - Tipos Impositivos (Interface)'
define view entity ZI_ReingTXType
  as select from zreing_tx_type_c
{
  key tax_type         as TaxType,
      tax_type_desc    as TaxTypeDesc,
      tax_category     as TaxCategory,
      gross_up_default as GrossUpDefault,
      active           as Active
}
