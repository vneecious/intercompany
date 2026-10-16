@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Log Rel. Billable product'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
define view entity ZC_IntercoMDLog
  as select from ZI_CHANGEDOCUMENT2 
{
  key hextobin( uuid ) as ID,
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
      ChangeDocLanguage
}
