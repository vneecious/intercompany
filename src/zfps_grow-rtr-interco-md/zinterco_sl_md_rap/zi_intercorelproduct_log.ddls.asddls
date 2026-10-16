@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Log Rel. Product'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zi_intercorelproduct_log
  as select from ZI_CHANGEDOCUMENT2
  association to parent ZI_IntercoCompanyRelProduct as _product on $projection.uuid = _product.Id
{
  key  hextobin( uuid ) as uuid,
  key ChangeDocObjectClass,
  key ChangeDocObject,
  key ChangeDocument,
  key  ChangeDocDatabaseTableField,
  key  ChangeDocItemChangeType,
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
       _product
}
where
      ChangeDocObjectClass = 'ZINT_A_MD001_CH'
      and ChangeDocObject      = 'ZINT_A_MD001_CH';
