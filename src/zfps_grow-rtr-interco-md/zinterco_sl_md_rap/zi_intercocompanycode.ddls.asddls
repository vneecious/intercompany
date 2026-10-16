@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'INTERCO Master Data - Empresas contenidas Proceso INTERCO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@ObjectModel.resultSet.sizeCategory: #XS

define root view entity ZI_IntercoCompanyCode
  as select distinct from I_CompanyCode as _Company
    inner join            ZI_CompanyCodeAddlInformation on  ZI_CompanyCodeAddlInformation.CompanyCode               = _Company.CompanyCode
                                                        and ZI_CompanyCodeAddlInformation.CompanyCodeParameterType  = 'ZIC002'
                                                        and ZI_CompanyCodeAddlInformation.CompanyCodeParameterValue = 'X'
  association [1..*] to ZI_CompanyCodeAddlInformation as _AdditionalInfo on $projection.CompanyCode = _AdditionalInfo.CompanyCode


{
  key _Company.CompanyCode,
      _Company.CompanyCodeName,
      _Company.Country,
      _Company._Country._Text[ Language = $session.system_language ].CountryName,
      _AdditionalInfo[ CompanyCodeParameterType = 'ZIC001' ].CompanyCodeParameterValue    as SiteCode,
      _AdditionalInfo[ CompanyCodeParameterType = 'ZIC001' ]._CompanyCode.CompanyCodeName as SiteName,
      _AdditionalInfo[ CompanyCodeParameterType = 'ZIDMEL' ].CompanyCodeParameterValue    as InternalCode,
      _AdditionalInfo[ CompanyCodeParameterType = 'ZIDMEL' ]._CompanyCode.CompanyCodeName as InternalCodeName,
      _Company.Company,
      _Company.Currency,
      _Company.Language,
      _Company.ChartOfAccounts,
      _AdditionalInfo
}
