@EndUserText.label: 'Intercompany - Log Rel. Billable product'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity zc_intercorelprodbill_log
  //provider contract transactional_query
  as projection on ZI_INtERCORELPRODBILL_LOG
{
  key ChangeDocObjectClass,
  key ChangeDocObject,
  key ChangeDocument,
  key uuid,
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
      _prodbill : redirected to ZC_IntercoCompanyRelProdBill
}
