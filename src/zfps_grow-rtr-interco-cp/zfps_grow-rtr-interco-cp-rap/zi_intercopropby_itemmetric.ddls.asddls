@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Depreciated - Proposal Item Metric'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_INTERCOPROPBY_ITEMMETRIC as select from ZI_IntercoProposal
{
    key Id,
    FiscalYear,
    FiscalPeriod,
    Period,
    ProviderCompanyCode,
    ProviderCompanyCodeName
//    Product,
//    ProductName,
//    ProviderCountry,
//    Status,
//    StatusName,
//    StatusCriticality,
//    IntercoBasisId,
//    GlobalCurrency,
//    AmountInGlobalCurrency,
//    CreatedBy,
//    CreatedAt,
//    IsDeleted,
//    ChartOfAccounts,
//    SiteCode,
//    InternalCode,
//    Country,
//    Plant,
//    SalesOrganization,
//    PurchasingOrganization,
//    /* Associations */
//    _Basis,
//    _DocFlow,
//    _Items,
//    _ItemsByCebe,
//    _Product,
//    _ProposalDocs,
//    _ProviderCompanyCode
}
