@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal - GL Accounts Origin (Consumption)'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define view entity ZC_IntercoProposalItemOrGLAcct
  as projection on ZI_IntercoProposalItemOrGLAcct
{
  key Id,
  key ItemId,
  key GlAccount,
  key CostCenter,
      Department,
      GlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      AmountInGlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      AmountInGlobalCurrencyH,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      AmountInGlobalCurrencyL,
      PercentOfTotal,
      PandLL5ID,
      CostCenterStdHierArea,
      CCAllocation,
      CCConsolidation,
      CostCenterD4,
      cebe_aux,
      RecipientCompanyCode,

      /* Associations */
      _Item     : redirected to parent ZC_IntercoProposalItemTP,
      _Proposal,
      _CostCenter,
      _PandL,
      _Department
}
