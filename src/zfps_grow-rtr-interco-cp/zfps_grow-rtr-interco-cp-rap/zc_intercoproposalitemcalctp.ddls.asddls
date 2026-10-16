@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Metrics retaled to Item'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define view entity ZC_IntercoProposalItemCalcTP
  as projection on ZI_IntercoProposalItemCalc
{
  key id,
  key item_id,
  key itembasis_id,
  key itemcalc_id,
      @ObjectModel.text.element:  [ 'StatusName' ]
      commitstatus,
      _Status.StatusName,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      markup,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      grossingupmargin,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      grossingupbase,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      latepaymentinterest,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      providergrossingup,
      SharedRateUnit,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      markupamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      grossingupmarginamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      grossingupbaseamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      providergrossingupamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      TotalInGlobalAmount,
      CodeCurrency,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      markupamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      providergrossingupamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      c_TotalInCompanyCodeAmount,
      CodeCurrencyCompanyCode,
      createdat,
      createdby,
      /* Associations */
      _Proposal   : redirected to ZC_IntercoProposalTP,
      _Items      : redirected to ZC_IntercoProposalItemTP,
      _ItemsAQ,
      _ItemsBaOGLAccAQ,
      _ItemsBasis : redirected to parent ZC_IntercoProposalItemBasisTP,
      _ItemsDoc   : redirected to composition child ZC_IntercoProposalItemDoc,
      _Status
}
