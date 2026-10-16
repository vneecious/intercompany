@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Search Help Intercompany P&L'
define view entity ZI_IntercoPandL_SH as select from ZI_IntercoPandL
{
    key GLAccountHierarchy,
    key PandLId,
    PandLName
}
group by GLAccountHierarchy, PandLId, PandLName 
