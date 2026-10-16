@EndUserText.label: 'CP Doc Export - GL Account / Cost Center'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define view entity ZC_INTRC_CP_DOC_EXPORT
  as select from ZI_INTRC_CP_DOC_EXPORT
{
  key Id,
  key Documenttype,
  key Documentkey,
  key CompanyCode,
  key FiscalYear,
  key LedgerGLLineItem,

      DocumentName,
      CatId,
      CategoryName,
      ParentDocumentType,
      ParentDocumentKey,
      Status,
      AccountingDocumentType,
      ProviderCompanyCode,
      RecipientCompanyCode,
      Product,
      Ledger,
      GLAccount,
      GLAccountName,
      CostCenter,
      CostCenterName,
      PostingDate,
      DebitCreditCode,
      TransactionCurrency,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      AmountInTransactionCurrency,
      CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      AmountInCompanyCodeCurrency,
      GlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      AmountInGlobalCurrency,
      FIDocumentType,
      AssignmentReference,
      ReferenceDocument
}
