@EndUserText.label: 'Intercompany - Log Rel. Product'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity zc_intercorelproduct_log
  provider contract transactional_query
  as projection on zi_intercorelproduct_log
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
      _product : redirected to ZC_IntercoCompanyRelProduct
      //  key ChangeDocObjectClass,
      //  key ChangeDocObject,
      //  key ChangeDocument,
      //  key uuid,
      //  key ChangeDocDatabaseTableField,
      //  key ChangeDocItemChangeType,
      //      ChangeDocPreviousUnit,
      //      ChangeDocNewUnit,
      //      ChangeDocPreviousCurrency,
      //      ChangeDocNewCurrency,
      //      ChangeDocNewFieldValue,
      //      ChangeDocPreviousFieldValue,
      //      ChangeDocTextIsChanged,
      //      CreatedByUser,
      //      CreationDate,
      //      CreationTime,
      //      ChangeTransactionCode,
      //      ChangeDocChangeType,
      //      ChangeDocLanguage
}
