@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Items with totals by cebe, bases, valua'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_PROPOSALITEMBAOGL2_MLA
  as select from ZI_PROPOSALITEMBAOGLAC_MLA
  association [0..1] to ZI_TransactionTypeStdGLAcct as _BASE_GL            on  $projection.ChartOfAccounts           = _BASE_GL.ChartOfAccounts
                                                                           and $projection.valuationclass            = _BASE_GL.ValuationClass
                                                                           and _BASE_GL.TransactionTypeDetermination = 'ZIN'
                                                                           and _BASE_GL.ValuationAreaGroup           = 'BASE'
  association [0..1] to ZI_TransactionTypeStdGLAcct as _MKUP_GL            on  $projection.ChartOfAccounts           = _MKUP_GL.ChartOfAccounts
                                                                           and $projection.valuationclass            = _MKUP_GL.ValuationClass
                                                                           and _MKUP_GL.TransactionTypeDetermination = 'ZIN'
                                                                           and _MKUP_GL.ValuationAreaGroup           = 'MKUP'
  association [0..1] to ZI_TransactionTypeStdGLAcct as _GUPK_GL            on  $projection.ChartOfAccounts           = _GUPK_GL.ChartOfAccounts
                                                                           and $projection.valuationclass            = _GUPK_GL.ValuationClass
                                                                           and _GUPK_GL.TransactionTypeDetermination = 'ZIN'
                                                                           and _GUPK_GL.ValuationAreaGroup           = 'GUPK'
  association [0..1] to ZI_TransactionTypeStdGLAcct as _GUPB_GL            on  $projection.ChartOfAccounts           = _GUPB_GL.ChartOfAccounts
                                                                           and $projection.valuationclass            = _GUPB_GL.ValuationClass
                                                                           and _GUPB_GL.TransactionTypeDetermination = 'ZIN'
                                                                           and _GUPB_GL.ValuationAreaGroup           = 'GUPB'
  association [0..1] to ZI_TransactionTypeStdGLAcct as _INTM_GL            on  $projection.ChartOfAccounts           = _INTM_GL.ChartOfAccounts
                                                                           and $projection.valuationclass            = _INTM_GL.ValuationClass
                                                                           and _INTM_GL.TransactionTypeDetermination = 'ZIN'
                                                                           and _INTM_GL.ValuationAreaGroup           = 'INTM'
  association [0..1] to ZI_TransactionTypeStdGLAcct as _GUPP_GL            on  $projection.ChartOfAccounts           = _GUPP_GL.ChartOfAccounts
                                                                           and $projection.valuationclass            = _GUPP_GL.ValuationClass
                                                                           and _GUPP_GL.TransactionTypeDetermination = 'ZIN'
                                                                           and _GUPP_GL.ValuationAreaGroup           = 'GUPP'
  //Asociaciones para uso en de analitica por proyecciones

  association [1..1] to ZI_IntercoProposal          as _Proposal           on  $projection.id = _Proposal.Id
  association [0..*] to ZI_PROPOSALITEMBASIS_MLA    as _ProposalItemsBasis on  $projection.id      = _ProposalItemsBasis.id
                                                                           and $projection.item_id = _ProposalItemsBasis.item_id
  association [0..*] to ZI_PROPOSALITEMCALC_MLA     as _ProposalItemsCalc  on  $projection.id      = _ProposalItemsCalc.id
                                                                           and $projection.item_id = _ProposalItemsCalc.item_id
  //  association              to ZI_IntercoPandLHierFlattened       as _PandLFlat          on  _PandLFlat.ID = $projection.pandll5id

{
  key id,
  key item_id,
  key itembasis_id,
  key GlAccount,
  key CostCenter,
      IntercoBasisId,
      @ObjectModel.text.element:  [ 'RecipientCompanyName' ]
      recipientcompanycode,
      @ObjectModel.text.element:  [ 'ProfitCenterName' ]
      profitcenter,
      _Items._RecipientCompanyCode.CompanyCodeName                                                                  as RecipientCompanyName,
      _Items._ProfitCenter.ProfitCenterName                                                                         as ProfitCenterName,
      _Items.Interdivisional                                                                                        as Interdivisional,
      //      ValidFrom,
      //      ValidTo,
      BaseCurrencyProfitCenter,
      @Semantics.amount.currencyCode : 'Basecurrencyprofitcenter'
      @Aggregation.default: #AVG
      baseamountprofitcenter,
      Department,
      CostCenterD4,
      PandLL5ID,
      _PandL.IDL2,
      _PandL.IDL3,
      //      _ICBasisItem.pandll5id,
      //      _PandLFlat.IDL2,
      //      substring( _ICBasisItem.costcenter, 3, 1 )                                                                    as CostCenterD4,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #AVG
      AmountByCeBeCeCo,
      PercentOfTotal,
      SharedRateUnit,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #SUM
      sharedrate,
      GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      AmountInGlobalCurrency,
      _Items.ExchangeRate,
      CompanyCodeCurrency,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      AmountInCompanyCodeCurrency,
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then abap.cuky''
      else CompanyCodeCurrency
      end                                                                                                           as CompanyCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then abap.curr'0.00'
      else AmountInCompanyCodeCurrency
      end                                                                                                           as AmountInCompanyCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then AmountInGlobalCurrency
      else AmountInCompanyCodeCurrency
      end                                                                                                           as AmountInTCurr,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      markup,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      grossingupmargin,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      grossingupbase,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      latepaymentinterest,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      providergrossingup,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      markupamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      grossingupmarginamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      grossingupbaseamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      providergrossingupamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      ( AmountInGlobalCurrency + markupamount + grossingupmarginamount + grossingupbaseamount )                     as TotalInGlobalAmount,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      markupamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      providergrossingupamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      @Aggregation.default: #SUM
      ( AmountInCompanyCodeCurrency + markupamntinlocal + grossingupmarginamntinlocal + grossingupbaseamntinlocal ) as TotalInCompanyCodeAmount,
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then GlobalCurrency
      else CompanyCodeCurrency
      end                                                                                                           as transactioncurrency,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then markupamount
      else markupamntinlocal
      end                                                                                                           as MKUPAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then grossingupmarginamount
      else grossingupmarginamntinlocal
      end                                                                                                           as GUpMAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then grossingupbaseamount
      else grossingupbaseamntinlocal
      end                                                                                                           as GUpBAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then latepaymentinterestamount
      else latepaymentinterestamntinlocal
      end                                                                                                           as INTMAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then providergrossingupamount
      else providergrossingupamntinlocal
      end                                                                                                           as GUpPAmntInTCurr,
      InternalCode,
      _ICBasisItem.ccconsolidation,
      @ObjectModel.text.element:  [ 'ProductName' ]
      Product,
      _I_Proposal.ProductName                                                                                       as ProductName,
      Plant,
      @ObjectModel.text.element:  [ 'ProviderCompanyName' ]
      ProviderCompanyCode,
      _I_Proposal._ProviderCompanyCode.CompanyCodeName                                                              as ProviderCompanyName,
      ChartOfAccounts,
      _Valuation.ValuationClass,
      createdby,
      createdat,
      /* Associations */
      _ICBasisItem,
      _Items,
      _ItemsBasis,
      //      _ItemsByCeBe,
      _ItemsOrGLAcct,
      _I_Proposal,
      _Valuation,
      _PandL,
      _BASE_GL,
      _MKUP_GL,
      _GUPK_GL,
      _GUPB_GL,
      _INTM_GL,
      _GUPP_GL,
      _Proposal,
      _ProposalItemsBasis,
      _ProposalItemsCalc
}
