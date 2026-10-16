@EndUserText.label: 'Empresas contenidas Proceso INTERCO'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define root view entity ZC_IntercoCompanyCode  provider contract transactional_query as projection on ZI_IntercoCompanyCode
{
    key CompanyCode,
    CompanyCodeName,
    Country,
    CountryName,
    SiteCode,
    SiteName,
    InternalCode,
    InternalCodeName,
    //Company,
    Currency,
    Language,
    /* Associations */
    _AdditionalInfo
}
