@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'I_TransactionTypeStdGLAcct for cloud'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_TransactionTypeStdGLAcct
  as select from P_T030 //I_TransactionTypeStdGLAcct
{
  key ktopl as ChartOfAccounts,
  key ktosl as TransactionTypeDetermination,
  key bwmod as ValuationAreaGroup,
  key komok as GLAcctDetnDifferentiation,
  key bklas as ValuationClass,
      konts as DebitGLAccount,
      konth as CreditGLAccount
      /* Associations */
//      _StandardGLAcctDetnRule
      //    _association_name // Make association public
}
