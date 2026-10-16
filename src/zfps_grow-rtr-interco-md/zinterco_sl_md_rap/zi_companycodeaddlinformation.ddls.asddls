@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'INTERCO Master Data - Additional Information in Company Code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_CompanyCodeAddlInformation as select from I_AddlCompanyCodeInformation
    association [1..1] to I_CompanyCode as _CompanyCode on _CompanyCode.CompanyCode = $projection.CompanyCode
{
    key I_AddlCompanyCodeInformation.CompanyCode,
    key I_AddlCompanyCodeInformation.CompanyCodeParameterType,
    I_AddlCompanyCodeInformation.CompanyCodeParameterValue,
    _CompanyCode
    
}
