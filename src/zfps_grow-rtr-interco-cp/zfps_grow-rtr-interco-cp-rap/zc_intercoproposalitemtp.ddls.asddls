@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
define view entity ZC_IntercoProposalItemTP
  as projection on ZI_IntercoProposalItem
{
  key     Id,
  key     Item_Id,
          ItemBasis_Id,
          ItemCalc_Id,
          @ObjectModel.text.element:  [ 'ProviderCompanyName' ]
          _Proposal.ProviderCompanyCode                  as ProviderCompanyCode,
          _Proposal._ProviderCompanyCode.CompanyCodeName as ProviderCompanyName,
          @ObjectModel.text.element:  [ 'RecipientCompanyName' ]
          recipientcompanycode,
          _RecipientCompanyCode.CompanyCodeName          as RecipientCompanyName,
          @ObjectModel.text.element:  [ 'ProductName' ]
          _Proposal.Product                              as Product,
          _Proposal.ProductName                          as ProductName,
          @ObjectModel.text.element:  [ 'ProfitCenterName' ]
          profitcenter,
          _ProfitCenter.ProfitCenterName                 as ProfitCenterName,
          Interdivisional,
          BaseCurrencyProfitCenter,
          @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
          BaseAmountProfitCenter,
          SharedRateUnit,
          /*EXT_GEPURISA 05/15 DELETE BEGIN: mostrar los campos de metricas y tarifas a nivel de Items */
          ExchangeRate,
          RecipientCountry,
          ProviderCountry,
          _Proposal.GlobalCurrency                       as h_GlobalCurrency,
          @Semantics.amount.currencyCode : 'h_GlobalCurrency'
          _Proposal.AmountInGlobalCurrency               as h_AmountInGlobalCurr,
          /*EXT_GEPURISA 05/15 INSERT BEGING: mostrar los campos de metricas y tarifas a nivel de Items */
          metric_id,
          @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
          sharedrate                                     as SharedRate,
          GlobalCurrency                                 as globalcurrency,
          @Semantics.amount.currencyCode : 'globalcurrency'
          b_amountinglobalcurrency                       as amountinglobalcurrency,
          companycodecurrency,
          @Semantics.amount.currencyCode : 'companycodecurrency'
          b_amountincompanycodecurrency                  as amountincompanycodecurrency,
          transactioncurrency,
          amountintrasactioncurrency,
          commitstatus,
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
          @Semantics.amount.currencyCode : 'g_CodeCurrency'
          markupamount,
          @Semantics.amount.currencyCode : 'g_CodeCurrency'
          grossingupmarginamount,
          @Semantics.amount.currencyCode : 'g_CodeCurrency'
          grossingupbaseamount,
          @Semantics.amount.currencyCode : 'g_CodeCurrency'
          latepaymentinterestamount,
          @Semantics.amount.currencyCode : 'g_CodeCurrency'
          providergrossingupamount,
          @Semantics.amount.currencyCode : 'g_CodeCurrency'
          c_TotalInGlobalAmount,
          g_CodeCurrency,
          @Semantics.amount.currencyCode : 'c_CodeCurrency'
          markupamntinlocal,
          @Semantics.amount.currencyCode : 'c_CodeCurrency'
          grossingupmarginamntinlocal,
          @Semantics.amount.currencyCode : 'c_CodeCurrency'
          grossingupbaseamntinlocal,
          @Semantics.amount.currencyCode : 'c_CodeCurrency'
          latepaymentinterestamntinlocal,
          @Semantics.amount.currencyCode : 'c_CodeCurrency'
          providergrossingupamntinlocal,
          @Semantics.amount.currencyCode : 'c_CodeCurrency'
          c_TotalInCompanyCodeAmount,
          c_CodeCurrency,
          BasisCreatedAt,
          BasisCreatedBy,
          CalcCreatedAt,
          CalcCreatedBy,
          /*EXT_GEPURISA 05/15 INSERT END: mostrar los campos de metricas y tarifas a nivel de Items */
          /* Associations */
          _Proposal           : redirected to parent ZC_IntercoProposalTP,
          _RecipientCompanyCode,
          _ProfitCenter,
          _BasisCalcLatest,
          _ProposalItemsBasis : redirected to composition child ZC_IntercoProposalItemBasisTP,
          _ProposalItemsCalc  : redirected to ZC_IntercoProposalItemCalcTP,
          _ProposalItemsDoc   : redirected to ZC_IntercoProposalItemDoc
}
