@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intrecompany: Tax BR Item'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoTaxBRItem
  as select from zint_a_md_taxbri
  association to ZI_IntercoTaxBR              as _Header     on  _Header.ProviderCompanyCode  = $projection.ProviderCompanyCode
                                                             and _Header.RecipientCompanyCode = $projection.RecipientCompanyCode
                                                             and _Header.Product              = $projection.Product
                                                             and _Header.Department           = $projection.Department
                                                             and _Header.ValidFrom            = $projection.ValidFrom
  association to I_GLAccountInChartOfAccounts as _GLAccount1 on  _GLAccount1.ChartOfAccounts = 'MLIB'
                                                             and _GLAccount1.GLAccount       = $projection.GLAccount1
  association to I_GLAccountInChartOfAccounts as _GLAccount2 on  _GLAccount2.ChartOfAccounts = 'MLIB'
                                                             and _GLAccount2.GLAccount       = $projection.GLAccount2

{
  key doctype              as DocumentType,
  key providercompanycode  as ProviderCompanyCode,
  key recipientcompanycode as RecipientCompanyCode,
  key product              as Product,
  key depto                as Department,
  key valid_from           as ValidFrom,
  key taxtype              as TaxType,
      taxrate              as TaxRate,
      gl_account1          as GLAccount1,
      gl_account2          as GLAccount2,
      classif              as Classif,
      contingency          as Contingency,
      created_at           as CreatedAt,
      created_by           as CreatedBy,
      _Header,
      _GLAccount1,
      _GLAccount2
}
