@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Item Basis Org GlAccount'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_INTRCPROPOSALITEMBAOGL2_MLA
  as projection on ZI_INTRC_IBAOGLACC3_MLA
{
  key     id,
  key     item_id,
  key     itembasis_id,
  key     GlAccount,
  key     CostCenter,
          IntercoBasisId,
          recipientcompanycode,
          RecipientCountry,
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
          base,
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
          markupamount              as MKUPAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          grossingupmarginamount    as GUpMAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          grossingupbaseamount      as GUpBAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          latepaymentinterestamount as LPInAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          providergrossingupamount  as GUpPAmountInGlobCurr,
          @Semantics.amount.currencyCode : 'GlobalCurrency'
          TotalInGlobalAmount,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          MKUPAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          GUpMAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          GUpBAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          LPInAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          GUpPAmountInCompCurr,
          @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
          TotalInCompanyCodeAmount,
          transactioncurrency,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          markupamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          grossingupmarginamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          grossingupbaseamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          latepaymentinterestamount,
          @Semantics.amount.currencyCode : 'transactioncurrency'
          providergrossingupamount,
          InternalCode,
          ccconsolidation,
          @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_INTERCO_BRF_WHT'
          @EndUserText.label: 'Cost Center Code'
  virtual CostCenterCode : zde_cc_code,
          Product,
          Plant,
          ProviderCompanyCode,
          ChartOfAccounts,
          ValuationClass,
          BASE_GL,
          MKUP_GL,
          GUPK_GL,
          GUPB_GL,
          INTM_GL,
          GUPP_GL,
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
