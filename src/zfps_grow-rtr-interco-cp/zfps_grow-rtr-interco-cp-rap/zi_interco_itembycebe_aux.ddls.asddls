//@AbapCatalog.viewEnhancementCategory: [#NONE]
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Interco Aggregation by ProfitCenter'

//define view entity ZI_INTERCO_ITEMBYCEBE_AUX
//  as select from ZI_IntercoProposalItemAux
//{
//  key Id,
//  key ProfitCenter,
//  key Cebe_Aux,
//      BaseCurrencyProfitCenter,
//      @Aggregation.default: #SUM
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      sum(AmountInGlobalCurrency) as Baseamountprofitcenter
//}
//where
//  Cebe_Aux = right(ProfitCenter, 3)
//group by
//  Id,
//  ProfitCenter,
//  Cebe_Aux,
//  BaseCurrencyProfitCenter
//define view entity ZI_INTERCO_ITEMBYCEBE_AUX
//  as select from ZI_IntercoProposalItemAux
//{
//  key Id,
//  key ProfitCenter,
//  key Cebe_Aux
//      //      BaseCurrencyProfitCenter,
//      //      @Aggregation.default: #SUM
//      //      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      //      sum(AmountInGlobalCurrency) as Baseamountprofitcenter
//}
////where
////  Cebe_Aux = right(ProfitCenter, 3)
//group by
//  Id,
//  ProfitCenter,
//  Cebe_Aux
////  BaseCurrencyProfitCenter


define view entity ZI_INTERCO_ITEMBYCEBE_AUX
  as select from ZI_IntercoProposalItemAux
{
  key Id,
  key ProfitCenter,
  key Cebe_Aux
      //      BaseCurrencyProfitCenter,
      //      @Aggregation.default: #SUM
      //      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      //      sum(AmountInGlobalCurrency) as Baseamountprofitcenter
}
//where
//  Cebe_Aux = right(ProfitCenter, 3)
group by
  Id,
  ProfitCenter,
  Cebe_Aux
//  BaseCurrencyProfitCenter
