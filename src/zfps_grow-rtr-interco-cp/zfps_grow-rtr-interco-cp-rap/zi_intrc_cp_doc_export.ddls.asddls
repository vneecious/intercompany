@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CP Doc Export - GLAccount CostCenter'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_INTRC_CP_DOC_EXPORT
  as select from    zfi_a_intrc_cpd           as _CPDoc

    inner join      I_JournalEntryItem        as _JEI    on  _JEI.CompanyCode        = _CPDoc.companycode
                                                         and _JEI.FiscalYear         = _CPDoc.fiscalyear
                                                         and _JEI.AccountingDocument = left(
      _CPDoc.documentkey, 10
    )
                                                         and _JEI.Ledger             = '0L'

    inner join      zfi_a_intrc_cph           as _CPH    on _CPH.id = _CPDoc.id

    left outer join ZI_INTRC_CP_RECIPIENT_AGG as _CPIAgg on  _CPIAgg.Id          = _CPDoc.id
                                                         and _CPIAgg.Documentkey  = _CPDoc.documentkey

    left outer join I_GLAccountText           as _GLTxt  on  _GLTxt.ChartOfAccounts = _JEI.ChartOfAccounts
                                                         and _GLTxt.GLAccount       = _JEI.GLAccount
                                                         and _GLTxt.Language        = $session.system_language

    left outer join I_CostCenterText          as _CCTxt  on  _CCTxt.ControllingArea = _JEI.ControllingArea
                                                         and _CCTxt.CostCenter      = _JEI.CostCenter
                                                         and _CCTxt.Language        = $session.system_language

  association [0..1] to ZI_INTRC_CP_DOC          as _Doc          on  $projection.Id           = _Doc.Id
                                                                  and $projection.Documenttype = _Doc.Documenttype
                                                                  and $projection.Documentkey  = _Doc.Documentkey
                                                                  and $projection.CompanyCode  = _Doc.CompanyCode
                                                                  and $projection.FiscalYear   = _Doc.FiscalYear
  association [0..*] to ZI_INTERCOPROP_DOCTYP_SH as _DocTypeText  on  $projection.Documenttype = _DocTypeText.TypId
  association [0..*] to ZI_INTERCOPROP_DCAT_SH   as _CategoryText on  $projection.CatId = _CategoryText.CatId

{
      @Semantics.uuid: true
  key _CPDoc.id                     as Id,
      @ObjectModel.text.element: ['DocumentName']
  key _CPDoc.documenttype           as Documenttype,
  key _CPDoc.documentkey            as Documentkey,
  key _CPDoc.companycode            as CompanyCode,
  key _CPDoc.fiscalyear             as FiscalYear,
  key _JEI.LedgerGLLineItem         as LedgerGLLineItem,

      -- Document info
      _DocTypeText.TypName          as DocumentName,
      _CPDoc.cat_id                 as CatId,
      _CategoryText.CatName         as CategoryName,
      _CPDoc.parentdocumenttype     as ParentDocumentType,
      _CPDoc.parentdocumentkey      as ParentDocumentKey,
      _CPDoc.status                 as Status,
      _CPDoc.accountingdocumenttype as AccountingDocumentType,

      -- Provider / Recipient / Product
      _CPH.providercompanycode      as ProviderCompanyCode,
      _CPIAgg.RecipientCompanyCode  as RecipientCompanyCode,
      _CPH.product                  as Product,

      -- FI line item data (from I_JournalEntryItem)
      _JEI.Ledger,
      _JEI.GLAccount,
      _GLTxt.GLAccountLongName      as GLAccountName,
      _JEI.CostCenter,
      _CCTxt.CostCenterName         as CostCenterName,
      _JEI.PostingDate,
      _JEI.DebitCreditCode,
      _JEI.TransactionCurrency,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      _JEI.AmountInTransactionCurrency,
      _JEI.CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      _JEI.AmountInCompanyCodeCurrency,
      _JEI.GlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      _JEI.AmountInGlobalCurrency,
      _JEI.AccountingDocumentType   as FIDocumentType,
      _JEI.AssignmentReference,
      _JEI.ReferenceDocument,

      -- Associations
      _Doc,
      _DocTypeText,
      _CategoryText
}
where
  _CPDoc.documentkey not like 'DUMMY%'
