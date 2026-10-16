@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Basis retaled to Item'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define view entity ZC_IntercoProposalItemBasisTP
  as projection on ZI_IntercoProposalItemBasis
{
  key id,
  key item_id,
  key itembasis_id,
      sharedrate,
      sharedrate_h,
      sharedrate_l,
      SharedRateUnit,
      globalcurrency,
      @Semantics.amount.currencyCode : 'globalcurrency'
      amountinglobalcurrency,
      companycodecurrency,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      amountincompanycodecurrency,
      createdat,
      createdby,
      /* Associations */
      _Proposal  : redirected to ZC_IntercoProposalTP,
      _Items     : redirected to parent ZC_IntercoProposalItemTP,
      _ItemsAQ,
      _ItemsBaOGLAccAQ,
      _ItemsCalc : redirected to composition child ZC_IntercoProposalItemCalcTP
}
