@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Wrapper I_ChangeDocument'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_ChangeDocument
  as select from I_ChangeDocument
  association [0..*] to zI_ChangeDocumentItem as _ChangeDocumentItem on  $projection.ChangeDocObjectClass = _ChangeDocumentItem.ChangeDocObjectClass
                                                                     and $projection.ChangeDocObject      = _ChangeDocumentItem.ChangeDocObject
                                                                     and $projection.ChangeDocument       = _ChangeDocumentItem.ChangeDocument
{
  key ChangeDocObjectClass,
  key ChangeDocObject,
  key ChangeDocument,
      CreatedByUser,
      CreationDate,
      CreationTime,
      ChangeTransactionCode,
      ChangeDocChangeType,
      ChangeDocLanguage,
      /* Associations */
      _ChangeDocLanguage,
      _ChangeDocumentItem
}
