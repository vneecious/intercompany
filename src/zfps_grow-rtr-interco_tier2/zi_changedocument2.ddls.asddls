@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Wrapper I_ChangeDocument'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_CHANGEDOCUMENT2
  as select from zI_ChangeDocumentItem
  association [1..1] to I_ChangeDocument as _changedocument on  $projection.ChangeDocObjectClass = _changedocument.ChangeDocObjectClass
                                                            and $projection.ChangeDocObject      = _changedocument.ChangeDocObject
                                                            and $projection.ChangeDocument       = _changedocument.ChangeDocument
{
  key ChangeDocObjectClass,
  key ChangeDocObject,
  key ChangeDocument,
  key cast( case
      when length(ltrim( ltrim(  cast( ChangeDocTableKey as abap.char( 35 ) ) , ' '  ),  '0' )) = 32 then ( ltrim( ltrim(  cast( ChangeDocTableKey as abap.char( 35 ) ) , ' '  ),  '0' ) )
      else ( substring( ltrim(  ltrim(  cast( ChangeDocTableKey as abap.char( 35 ) ) , ' ' ),  '0' ), 4, 33 ) ) end as abap.char(32) )  as uuid,
//  key ltrim( ltrim( cast(  substring( ChangeDocTableKey, 3, 33   )as abap.char( 32 )  ), '0'  ), ' ') as uuid,
  key ChangeDocDatabaseTableField,
  key ChangeDocItemChangeType,
      ChangeDocPreviousUnit,
      ChangeDocNewUnit,
      length(ChangeDocTableKey) as ltkey,
      ChangeDocPreviousCurrency,
      ChangeDocNewCurrency,
      ChangeDocNewFieldValue,
      ChangeDocPreviousFieldValue,
      ChangeDocTextIsChanged,
      _changedocument.CreatedByUser,
      _changedocument.CreationDate,
      _changedocument.CreationTime,
      _changedocument.ChangeTransactionCode,
      _changedocument.ChangeDocChangeType,
      _changedocument.ChangeDocLanguage
}
