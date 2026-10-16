@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Wrapper for I_ChangeDocumentItem'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity zI_ChangeDocumentItem as select from I_ChangeDocumentItem
{
    key ChangeDocObject,
    key ChangeDocObjectClass,
    key ChangeDocument,
    key DatabaseTable,
    key ChangeDocTableKey,
    key ChangeDocDatabaseTableField,
    key ChangeDocItemChangeType,
    ChangeDocPreviousUnit,
    ChangeDocNewUnit,
    ChangeDocPreviousCurrency,
    ChangeDocNewCurrency,
    ChangeDocNewFieldValue,
    ChangeDocPreviousFieldValue,
    ChangeDocTextIsChanged,
    /* Associations */
    _ChangeDocLongTableKey,
    _ChangeDocument,
    _ChangeDocumentItemExtension,
    _FieldTextDDIC,
    _FieldTextLabel,
    _FieldTextReplace,
    _FieldTextView,
    _TableTextDDIC,
    _TableTextView
}
