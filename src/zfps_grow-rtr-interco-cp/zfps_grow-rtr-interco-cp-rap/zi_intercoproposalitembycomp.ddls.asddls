@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Item by Company Code (Cost Sharing)'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_IntercoProposalItemByComp
  as select from ZI_IntercoProposalItemAuxCS
{
  key Id,
  key RecipientCompanyCode,

      Product,
      ProductName,
      BaseCurrencyProfitCenter as BaseCurrencyComp,

      @Semantics.amount.currencyCode: 'BaseCurrencyComp'
      sum( case D4
             when '1' then cast( Amount as abap.dec(23,2) )
             else cast( 0 as abap.dec(23,2) )
           end )               as BaseAmountCompC,

      @Semantics.amount.currencyCode: 'BaseCurrencyComp'
      sum( case D4
             when '3' then cast( Amount as abap.dec(23,2) )
             else cast( 0 as abap.dec(23,2) )
           end )               as BaseAmountCompH,

      @Semantics.amount.currencyCode: 'BaseCurrencyComp'
      sum( case D4
             when '0' then cast( Amount as abap.dec(23,2) )
             else cast( 0 as abap.dec(23,2) )
           end )               as BaseAmountCompL
}
group by
  Id,
  RecipientCompanyCode,
  Product,
  ProductName,
  BaseCurrencyProfitCenter
