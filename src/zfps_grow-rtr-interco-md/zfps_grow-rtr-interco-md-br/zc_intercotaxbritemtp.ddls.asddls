@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tax Br ITem'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define view entity ZC_IntercoTaxBRItemTP
  as projection on ZR_IntercoTaxBRItemTP
{
  key DocumentType,
  key ProviderCompanyCode,
  key RecipientCompanyCode,
  key Product,
  key Department,
  key ValidFrom,
  key TaxType,
      TaxRate,
      GLAccount1,
      GLAccount2,
      Classif,
      Contingency,
      CreatedAt,
      CreatedBy,
      /* Associations */
      _Header : redirected to parent ZC_IntercoTaxBRTP,
      _GLAccount1,
      _GLAccount2
}
