@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define root view entity ZC_IntercoProposalTP
  provider contract transactional_query
  as projection on ZI_IntercoProposal
{
  key Id,
      FiscalYear,
      FiscalPeriod,
      Period,
      @ObjectModel.text.element: [ 'ProviderCompanyCodeName' ]
      ProviderCompanyCode,
      ProviderCompanyCodeName,
      //      ProviderCompanyCode as RecipientCompanyCode,
      @ObjectModel.text.element: [ 'ProductName' ]
      Product,
      ProductName,
      @ObjectModel.text.element: [ 'StatusName' ]
      Status,
      StatusName,
      StatusCriticality,
      @ObjectModel.text.element: [ 'BasisDescription' ]
      IntercoBasisId,
      BasisDescription,
      Ledger,
      GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      AmountInGlobalCurrency,
      // ══ AJUSTE MON/MTO LOCAL CPH ══════════════════════════════════════════
      CompanyCodeCurrency,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      AmountInCompanyCodeCurrency,
      // ══════════════════════════════════════════════════════════════════════
      CreatedBy,
      CreatedAt,
      //      @Consumption.defaultValue: ''
      IsDeleted,
      IsDeletedCriticality,
      IsActive,
      /* Associations */
      _Items               : redirected to composition child ZC_IntercoProposalItemTP,
      _Basis,
      _Product,
      _ProviderCompanyCode,
      //      _ProposalDocs       : redirected to ZC_IntercoProposalItemDoc,
      _ProposalDocs        : redirected to ZC_INTRC_CPD,
      //      _DocFlow,
      _ItemsByProfitCenter : redirected to ZC_IntercoProposalItemByCeBe,
      _ItemsAQ,
      _ItemsBaOGLAccAQ,
      _Status
      //      _DocFlowCategories
}
