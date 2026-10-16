@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
@ObjectModel: { representativeKey: 'Item_Id',
                usageType.sizeCategory: #XXL,
                usageType.dataClass:  #MIXED }
define root view entity ZC_INTERCOPROPOSALITEMAQ
  //  as select from zfi_a_intrc_cpi
  //  association of exact one to one ZI_IntercoProposal             as _I_Proposal             on  $projection.Id = _I_Proposal.Id
  //  association of exact one to one ZC_IntercoProposalTP           as _Proposal             on  $projection.Id = _Proposal.Id
  //  association of exact one to one ZI_IntercoCompanyCode          as _RecipientCompanyCode on  zfi_a_intrc_cpi.recipientcompanycode = _RecipientCompanyCode.CompanyCode
  //  association of exact one to one ZI_IntercoProfitCenter_SH      as _ProfitCenter         on  $projection.profitcenter = _ProfitCenter.ProfitCenter
  //  association of exact one to many ZC_IntercoProposalItemBasisTP as _ProposalItemsBasis   on  $projection.Id      = _ProposalItemsBasis.id
  //                                                                                          and $projection.Item_Id = _ProposalItemsBasis.item_id
  //  association of exact one to many ZC_IntercoProposalItemCalcTP  as _ProposalItemsCalc    on  $projection.Id      = _ProposalItemsCalc.id
  //                                                                                          and $projection.Item_Id = _ProposalItemsCalc.item_id
  //  association of exact one to many ZI_IntercoProposalItemDoc     as _ProposalItemsDoc     on  $projection.Id      = _ProposalItemsDoc.id
  //                                                                                          and $projection.Item_Id = _ProposalItemsDoc.item_id
  //  association of exact one to one ZI_IntercoProposalBCLatest     as _BasisCalcLatest      on  zfi_a_intrc_cpi.id      = _BasisCalcLatest.Id
  //                                                                                          and zfi_a_intrc_cpi.item_id = _BasisCalcLatest.Item_Id
  //  association of exact one to many ZI_IntercoProposalItemBaOGlAc as _BaOGLAcc             on  $projection.Id = _BaOGLAcc.id
  //                                                                                          and $projection.Item_Id = _BaOGLAcc.item_id
  //                                                                                          and $projection.ItemBasis_Id = _BaOGLAcc.itembasis_id
  //  //adicionales
  //  association of exact one to one ZR_IntercoCompanyCodeLogistics as _CompanyCodeLogistic  on  $projection.recipientcompanycode = _CompanyCodeLogistic.CompanyCode
  as select from ZI_INTERCOPROPOSALITEMAQ
  association of exact one to one ZC_IntercoProposalTP           as _Proposal           on  $projection.Id = _Proposal.Id
  association of exact one to many ZC_IntercoProposalItemBasisTP as _ProposalItemsBasis on  $projection.Id      = _ProposalItemsBasis.id
                                                                                        and $projection.Item_Id = _ProposalItemsBasis.item_id
  association of exact one to many ZC_IntercoProposalItemCalcTP  as _ProposalItemsCalc  on  $projection.Id      = _ProposalItemsCalc.id
                                                                                        and $projection.Item_Id = _ProposalItemsCalc.item_id

{
      @Semantics.uuid: true
  key Id,
  key Item_Id,
      ItemBasis_Id,
      ItemCalc_Id,
      @ObjectModel.text.element:  [ 'ProviderCompanyName' ]
      ProviderCompanyCode,
      ProviderCompanyName,
      @ObjectModel.text.element:  [ 'RecipientCompanyName' ]
      recipientcompanycode,
      RecipientCompanyName,
      @ObjectModel.text.element:  [ 'ProductName' ]
      Product,
      ProductName,
      @ObjectModel.text.element:  [ 'ProfitCenterName' ]
      profitcenter,
      ProfitCenterName,
      _BaOGLAcc.GlAccount,
      _BaOGLAcc.CostCenter,
      Interdivisional,
      BaseCurrencyProfitCenter,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      @Aggregation.default: #AVG
      BaseAmountProfitCenter,
      // ** Proyectamos los nuevos campos con el sufijo 'H' Hispano**
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      @Aggregation.default: #AVG
      BaseAmountProfitCenterC,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      @Aggregation.default: #AVG
      BaseAmountProfitCenterH,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      @Aggregation.default: #AVG
      BaseAmountProfitCenterL,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      b_amountinglobalcurrencyC,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      b_amountinglobalcurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      b_amountinglobalcurrencyL,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      @Aggregation.default: #AVG
      _BaOGLAcc.AmountByCeBeCeCo,
      //D-{ Montos de la propuesta
      //      GlobalCurrency,
      //      @Semantics.amount.currencyCode : 'GlobalCurrency'
      //      @Aggregation.default: #SUM
      //      AmountInGlobalCurr,
      //D-} Montos de la propuesta
      SharedRateUnit,
      //      metric_id,
      //      @Aggregation.default: #SUM
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      sharedrate,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      SharedRateH,
      _BaOGLAcc.GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.AmountInGlobalCurrency,
      ExchangeRate,
      _BaOGLAcc.CompanyCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      _BaOGLAcc.AmountInCompanyCurr,
      _BaOGLAcc.transactioncurrency,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      _BaOGLAcc.AmountInTCurr,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      _BaOGLAcc.markup,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      _BaOGLAcc.grossingupmargin,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      _BaOGLAcc.grossingupbase,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      _BaOGLAcc.latepaymentinterest,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      @Aggregation.default: #AVG
      _BaOGLAcc.providergrossingup,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.MKUPAmountInGlobCurr,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.GUpMAmountInGlobCurr,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.GUpBAmountInGlobCurr,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.LPInAmountInGlobCurr,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.GUpPAmountInGlobCurr,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BaOGLAcc.TotalInGlobalAmount,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when ProviderCountry <> RecipientCountry then abap.curr'0.00'
      else _BaOGLAcc.MKUPAmountInCompCurr
      end as MKUPAmountInCompCurr,
      //      _BaOGLAcc.MKUPAmountInCompCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when ProviderCountry <> RecipientCountry then abap.curr'0.00'
      else _BaOGLAcc.GUpMAmountInCompCurr
      end as GUpMAmountInCompCurr,
      //      _BaOGLAcc.GUpMAmountInCompCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when ProviderCountry <> RecipientCountry then abap.curr'0.00'
      else _BaOGLAcc.GUpBAmountInCompCurr
      end as GUpBAmountInCompCurr,
      //      _BaOGLAcc.GUpBAmountInCompCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when ProviderCountry <> RecipientCountry then abap.curr'0.00'
      else _BaOGLAcc.LPInAmountInCompCurr
      end as LPInAmountInCompCurr,
      //      _BaOGLAcc.LPInAmountInCompCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when ProviderCountry <> RecipientCountry then abap.curr'0.00'
      else _BaOGLAcc.GUpPAmountInCompCurr
      end as GUpPAmountInCompCurr,
      //      _BaOGLAcc.GUpPAmountInCompCurr,
      @Semantics.amount.currencyCode : 'CompanyCurr'
      @Aggregation.default: #SUM
      case
      when ProviderCountry <> RecipientCountry then abap.curr'0.00'
      else _BaOGLAcc.TotalInCompanyCodeAmount
      end as TotalInCompanyCodeAmount,
      //      _BaOGLAcc.TotalInCompanyCodeAmount,
      _BaOGLAcc.BASE_GL,
      _BaOGLAcc.MKUP_GL,
      _BaOGLAcc.GUPK_GL,
      _BaOGLAcc.GUPB_GL,
      _BaOGLAcc.INTM_GL,
      _BaOGLAcc.GUPP_GL,
      _BaOGLAcc.createdat,
      _BaOGLAcc.createdby,
      Status,
      StatusCriticality,
      /* 05/15: mostrar los campos de metricas y tarifas a nivel de Items */
      /* Adicionales */
      //      _CompanyRelProduct.Flow,
      //      _I_Proposal.Plant                                                                                                                                                                 as ProviderPlant,
      //      _I_Proposal.ChartOfAccounts,
      //      _I_Proposal.ProviderCountry,
      //      _RecipientCompanyCode.SiteCode,
      //      _RecipientCompanyCode.InternalCode,
      //      _CompanyCodeLogistic.Plant,
      //      _CompanyCodeLogistic.SalesOrganization,
      //      _CompanyCodeLogistic.PurchasingOrganization,
      //      _Relationship.RecipientCustomer,
      //      _Relationship.RecipientVendor,
      /* Associations */
      _I_Proposal,
      _Proposal,
      _RecipientCompanyCode,
      _ProfitCenter,
      _ProposalItemsBasis,
      _ProposalItemsCalc,
      _ProposalItemsDoc,
      _BasisCalcLatest
      //      _ItemsBasis,
      //      _ItemsCalc,
      //      _CurrentProposalItemBasis,
      //      _CurrentProposalItemCalc
}
