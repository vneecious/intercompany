@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: BO Tax BR'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define root view entity ZC_IntercoTaxBRTP
  provider contract transactional_query
  as projection on ZR_IntercoTaxBRTP
{
  key DocumentType,
  key ProviderCompanyCode,
  key RecipientCompanyCode,
  key Product,
  key Department,
  key ValidFrom,
      ValidTo,
      IsDeleted,
      IsNotDeleted,
      Criticality,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LocalLastChangedAt,
      LastChangedBy,
      _Items : redirected to composition child ZC_IntercoTaxBRItemTP,
      /* Associations */
      _ProviderCompanyCode,
      _RecipientCompanyCode,
      _Product
}
