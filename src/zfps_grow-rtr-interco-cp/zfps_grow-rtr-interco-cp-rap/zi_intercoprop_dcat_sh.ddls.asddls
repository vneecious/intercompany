@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help to Document Category'
@Metadata.ignorePropagatedAnnotations: false
define root view entity ZI_INTERCOPROP_DCAT_SH as select from zfi_a_intrc_dcat
//composition of target_data_source_name as _association_name
{
    key cat_id as CatId,
    @Semantics.language: true
    key language_code as LanguageCode,
    @Semantics.text: true
    cat_name as CatName,
    col_pos as ColPos
//    _association_name // Make association public
}
where language_code = $session.system_language
