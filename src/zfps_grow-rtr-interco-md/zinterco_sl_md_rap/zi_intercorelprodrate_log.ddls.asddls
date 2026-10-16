@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Log Rel. Product Rate'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_INtERCORELPRODRATE_LOG
  as select from ZI_CHANGEDOCUMENT2
  association [0..1] to ZI_INTERCOCOMPANYRELPRODRATE as _prodrate on $projection.uuid = _prodrate.Uuid
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
       _prodrate
       //  key ChangeDocObjectClass,
       //  key ChangeDocObject,
       //  key ChangeDocument,
       //      CreatedByUser,
       //      CreationDate,
       //      CreationTime,
       //      ChangeTransactionCode,
       //      ChangeDocChangeType,
       //      ChangeDocLanguage,
       //      /* Associations */
       //      _ChangeDocLanguage,
       //      _ChangeDocumentItem
}
where
      ChangeDocObjectClass = 'ZINT_A_MD003_CH'
  and ChangeDocObject      = 'ZINT_A_MD003_CH';
