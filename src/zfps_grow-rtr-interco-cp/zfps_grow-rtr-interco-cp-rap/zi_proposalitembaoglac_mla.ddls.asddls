@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ZI_IntercoProposalItemBaOGlAc'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_PROPOSALITEMBAOGLAC_MLA
  as select from zfi_a_intrc_cpbg
  association [1..1]       to ZI_IntercoProposal              as _I_Proposal    on  $projection.id = _I_Proposal.Id
  association [1..1]       to ZI_PROPOSALITEM_MLA             as _Items         on  $projection.id      = _Items.Id
                                                                                and $projection.item_id = _Items.Item_Id
  association [0..1]       to ZI_PROPOSALITEMORGLACCT_MLA     as _ItemsOrGLAcct on  $projection.id         = _ItemsOrGLAcct.Id
                                                                                and $projection.item_id    = _ItemsOrGLAcct.ItemId
                                                                                and $projection.GlAccount  = _ItemsOrGLAcct.GlAccount
                                                                                and $projection.CostCenter = _ItemsOrGLAcct.CostCenter
  association [0..1]       to zfi_a_intrc_bi                  as _ICBasisItem   on  $projection.intercobasisid = _ICBasisItem.id
                                                                                and $projection.Product        = _ICBasisItem.product
                                                                                and $projection.profitcenter   = _ICBasisItem.profitcenter
                                                                                and $projection.GlAccount      = _ICBasisItem.glaccount
                                                                                and $projection.CostCenter     = _ICBasisItem.costcenter
  association of exact one to one I_ProductValuationBasic     as _Valuation     on  $projection.Product             = _Valuation.Product
                                                                                and $projection.Plant               = _Valuation.ValuationArea
                                                                                and $projection.ProviderCompanyCode = _Valuation.CompanyCode
  association              to parent ZI_PROPOSALITEMBASIS_MLA as _ItemsBasis    on  $projection.id           = _ItemsBasis.id
                                                                                and $projection.item_id      = _ItemsBasis.item_id
                                                                                and $projection.itembasis_id = _ItemsBasis.itembasis_id
  association [0..1]       to ZI_IntercoCostCenter            as _CostCenter    on  _CostCenter.CostCenter      = $projection.CostCenter
                                                                                and _CostCenter.ControllingArea = 'ML00'
  association              to ZI_IntercoDepartment            as _Department    on  _Department.Department = $projection.department
  //    association to ZI_IntercoPandLHierFlattened as _PandLFlat        on  _PandLFlat.ID = $projection.pandll5id
{
  key id,
  key item_id,
  key itembasis_id,
  key gl_account                            as GlAccount,
  key cost_center                           as CostCenter,
      _I_Proposal.IntercoBasisId,
      _Items.recipientcompanycode,
      _Items.profitcenter,
      //      cast( concat(concat(_Proposal.FiscalYear, right(_Proposal.FiscalPeriod,2)),'01') as abap.dats )                                                     as ValidFrom,
      //      dats_add_days(dats_add_months(cast( concat(concat(_Proposal.FiscalYear, right(_Proposal.FiscalPeriod,2)),'01') as abap.dats ),1, 'FAIL'),-1,'FAIL') as ValidTo,
      _Items.BaseCurrencyProfitCenter,
      @Semantics.amount.currencyCode : 'Basecurrencyprofitcenter'
      _Items.baseamountprofitcenter,
      _ItemsOrGLAcct.Department,
      _ItemsOrGLAcct.CCAllocation,
      _ItemsOrGLAcct.CCConsolidation,
      _ItemsOrGLAcct.CostCenterStdHierArea,
      _ItemsOrGLAcct.CostCenterD4,
      _ItemsOrGLAcct.PandLL5ID,
      //      _ICBasisItem.pandll5id,
      //      substring( _ICBasisItem.costcenter, 3, 1 ) as CostCenterD4,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      _ItemsOrGLAcct.AmountInGlobalCurrency as AmountByCeBeCeCo,
      _ItemsOrGLAcct.PercentOfTotal,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _Items.sharedrate,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _Items.SharedRateH,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _Items.SharedRateL,
      globalcurrency                        as GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      amountinglobalcurrency                as AmountInGlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      amountinglobalcurrency_c              as AmountInGlobalCurrencyC,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      amountinglobalcurrency_h              as AmountInGlobalCurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      amountinglobalcurrency_l              as AmountInGlobalCurrencyL,
      companycodecurrency                   as CompanyCodeCurrency,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      amountincompanycodecurrency           as AmountInCompanyCodeCurrency,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      amountincompanycodecurrency_c         as AmountInCompanyCodeCurrencyC,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      amountincompanycodecurrency_h         as AmountInCompanyCodeCurrencyH,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      amountincompanycodecurrency_l         as AmountInCompanyCodeCurrencyL,
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
      cast( '%' as abap.unit( 3 ) )         as SharedRateUnit,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      markupamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      grossingupmarginamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      grossingupbaseamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      providergrossingupamount,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      markupamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      providergrossingupamntinlocal,
      _Items.InternalCode,
      _I_Proposal.Product                   as Product,
      _I_Proposal.Plant                     as Plant,
      _I_Proposal.ProviderCompanyCode       as ProviderCompanyCode,
      _I_Proposal.ChartOfAccounts,
      zfi_a_intrc_cpbg.createdby,
      zfi_a_intrc_cpbg.createdat,
      _I_Proposal,
      _Items,
      _ItemsBasis,
      //      _ItemsByCeBe,
      _ItemsOrGLAcct,
      _ItemsOrGLAcct._PandL,
      _ICBasisItem,
      _Valuation,
      _CostCenter,
      _Department
}
