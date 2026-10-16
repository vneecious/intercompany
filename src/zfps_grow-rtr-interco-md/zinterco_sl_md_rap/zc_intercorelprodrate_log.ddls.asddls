@EndUserText.label: 'Intercompany - Log Rel. Product Rate'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity zc_intercorelprodrate_log  as projection on ZI_INtERCORELPRODRATE_LOG
{
  key uuid,
  key ChangeDocObjectClass,
  key ChangeDocObject,
  key ChangeDocument,
  key ChangeDocDatabaseTableField,
  key ChangeDocItemChangeType,
      ChangeDocPreviousUnit,
      ChangeDocNewUnit,
      ChangeDocPreviousCurrency,
      ChangeDocNewCurrency,
      ChangeDocNewFieldValue,
      ChangeDocPreviousFieldValue,
      ChangeDocTextIsChanged,
      CreatedByUser,
      CreationDate,
      CreationTime,
      ChangeTransactionCode,
      ChangeDocChangeType,
      ChangeDocLanguage,
      _prodrate :redirected to ZC_IntercoCompanyRelProdRate
      //      CreatedByUser,
      //      CreationDate,
      //      CreationTime,
      //      ChangeTransactionCode,
      //      ChangeDocChangeType,
      //      ChangeDocLanguage
      //      /* Associations */
      //      _ChangeDocLanguage,
      //      _ChangeDocumentItem
}
