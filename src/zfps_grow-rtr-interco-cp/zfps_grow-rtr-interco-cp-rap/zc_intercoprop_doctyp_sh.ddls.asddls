@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document Type Search Help'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_INTERCOPROP_DOCTYP_SH
  provider contract transactional_query
  as projection on ZI_INTERCOPROP_DOCTYP_SH
{
  key TypId,
  key LanguageCode,
      TypName
}
