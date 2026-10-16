@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Item sum amount by Profitcenter'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemPCAmount as select from ZI_IntercoProposalItem
{
    key Id,
    key ProfitCenter,
    key BaseCurrencyProfitCenter,
    @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
    sum ( BaseAmountProfitCenter ) as TotalAmountProfitCenter
}
group by Id, ProfitCenter, BaseCurrencyProfitCenter
