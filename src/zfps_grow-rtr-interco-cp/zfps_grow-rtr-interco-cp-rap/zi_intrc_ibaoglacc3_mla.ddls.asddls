@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Items Bases with GLAccounts, Ceco'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define root view entity ZI_INTRC_IBAOGLACC3_MLA
  as select from ZI_PROPOSALITEMBAOGL2_MLA
{
  key     id,
  key     item_id,
  key     itembasis_id,
  key     GlAccount,
  key     CostCenter,
          IntercoBasisId,
          recipientcompanycode,
          _Items.RecipientCountry,
          profitcenter,
          BaseCurrencyProfitCenter,
          @Semantics.amount.currencyCode : 'Basecurrencyprofitcenter'
          baseamountprofitcenter,
          Department,
          PandLL5ID,
          IDL2,
          IDL3,
          CostCenterD4,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          AmountByCeBeCeCo,
          PercentOfTotal,
          sharedrate,
          GlobalCurrency,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          AmountInGlobalCurrency,
          CompanyCodeCurrency,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          AmountInCompanyCodeCurrency,
          CompanyCurr,
          @Semantics.amount.currencyCode : 'CompanyCurr'
          AmountInCompanyCurr,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          AmountInTCurr,
          ExchangeRate,
          SharedRateUnit,
          @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
          cast( 1 as abap.dec( 9, 5 ) )  as base,
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
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          markupamount                   as MKUPAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          grossingupmarginamount         as GUpMAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          grossingupbaseamount           as GUpBAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          latepaymentinterestamount      as LPInAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          providergrossingupamount       as GUpPAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          TotalInGlobalAmount,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          markupamntinlocal              as MKUPAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          grossingupmarginamntinlocal    as GUpMAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          grossingupbaseamntinlocal      as GUpBAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          latepaymentinterestamntinlocal as LPInAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          providergrossingupamntinlocal  as GUpPAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          TotalInCompanyCodeAmount,
          transactioncurrency,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          MKUPAmntInTCurr                as markupamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          GUpMAmntInTCurr                as grossingupmarginamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          GUpBAmntInTCurr                as grossingupbaseamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          INTMAmntInTCurr                as latepaymentinterestamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          GUpPAmntInTCurr                as providergrossingupamount,
          InternalCode,
          ccconsolidation,
          Product,
          Plant,
          ProviderCompanyCode,
          ChartOfAccounts,
          ValuationClass,
          _BASE_GL.DebitGLAccount        as BASE_GL,
          _MKUP_GL.DebitGLAccount        as MKUP_GL,
          _GUPK_GL.DebitGLAccount        as GUPK_GL,
          _GUPB_GL.DebitGLAccount        as GUPB_GL,
          _INTM_GL.DebitGLAccount        as INTM_GL,
          _GUPP_GL.DebitGLAccount        as GUPP_GL,
          createdby,
          createdat,
          /* Associations */
          _ICBasisItem,
          _Items,
          _ItemsBasis,
          _ItemsOrGLAcct,
          _I_Proposal,
          _Valuation,
          _PandL,
          _BASE_GL,
          _MKUP_GL,
          _GUPK_GL,
          _GUPB_GL,
          _INTM_GL,
          _GUPP_GL
}
