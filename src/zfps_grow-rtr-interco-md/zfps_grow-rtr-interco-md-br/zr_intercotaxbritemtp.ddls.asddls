@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BO Tax BR Item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZR_IntercoTaxBRItemTP
  as select from ZI_IntercoTaxBRItem
  association to parent ZR_IntercoTaxBRTP as _Header on  _Header.DocumentType         = $projection.DocumentType
                                                     and _Header.ProviderCompanyCode  = $projection.ProviderCompanyCode
                                                     and _Header.RecipientCompanyCode = $projection.RecipientCompanyCode
                                                     and _Header.Product              = $projection.Product
                                                     and _Header.Department           = $projection.Department
                                                     and _Header.ValidFrom            = $projection.ValidFrom
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
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.createdBy: true
      CreatedBy,
      /* Associations */
      _Header,
      _GLAccount1,
      _GLAccount2
}
