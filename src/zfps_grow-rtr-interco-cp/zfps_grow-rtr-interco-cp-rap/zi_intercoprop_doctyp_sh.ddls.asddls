@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help to Document Type'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_INTERCOPROP_DOCTYP_SH as select from zfi_a_intrc_dtyp
//composition of target_data_source_name as _association_name
{
    key dtyp_id as TypId,
    @Semantics.language: true
    key language_code as LanguageCode,
    @Semantics.text: true
    dtyp_name as TypName
//    _association_name // Make association public
}
where language_code = $session.system_language
