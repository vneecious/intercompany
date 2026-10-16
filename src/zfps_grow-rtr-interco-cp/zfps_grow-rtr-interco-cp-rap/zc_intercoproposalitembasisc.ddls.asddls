@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany - Current Item Basis'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZC_IntercoProposalItemBasisC
  as select from ZI_IntercoProposalItemBasis
  association [1..1] to ZC_IntercoProposalItemTP as _Item on  _Item.Id      = $projection.id
                                                          and _Item.Item_Id = $projection.item_id
{
  key id,
  key item_id,
      sharedrate,
      SharedRateUnit,
      ExchangeRate as ExchangeRate,
      case when globalcurrency is null or globalcurrency is initial then companycodecurrency
           when companycodecurrency is null or companycodecurrency is initial then globalcurrency
      end as ShareCurrency,
      @Semantics.amount.currencyCode : 'ShareCurrency'
      case when amountinglobalcurrency is null or amountinglobalcurrency is initial then amountincompanycodecurrency
           when amountincompanycodecurrency is null or amountincompanycodecurrency is initial then amountinglobalcurrency
      end as AmountInShareCurrency,
      createdat,
      createdby,
      _Item
}
