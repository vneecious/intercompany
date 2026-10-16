@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Log Rel. Billable product'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INtERCORELPRODBILL_LOG
  as select from ZI_CHANGEDOCUMENT2
  association to parent ZI_IntercoCompanyRelProdBill as _prodbill on $projection.uuid = _prodbill.Id
{
  key ChangeDocObjectClass,
  key ChangeDocObject,
  key ChangeDocument,
  key hextobin( uuid ) as uuid,
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
      _prodbill
}
where
      ChangeDocObjectClass = 'ZINT_A_MD002_CH'
  and ChangeDocObject      = 'ZINT_A_MD002_CH';
