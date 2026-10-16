//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'CS Post-Metric: by recipient company'
//@Metadata.ignorePropagatedAnnotations: true
//
//define view entity ZI_IntercoProposalItemCS1B
//  as select from zfi_a_intrc_cpi   as Item
//    inner join   zfi_a_intrc_cph   as Header  on  Header.id     =  Item.id
//                                              and Header.status <> ''
//    inner join   ZI_IntercoProduct as Product on Product.Product  = Header.product
//                                              and(
//                                                Product.Metric    = 'IC'
//                                                or Product.Metric = 'CS'
//                                              )
//    inner join   I_CompanyCode     as Company on Company.CompanyCode = Item.recipientcompanycode
//{
//  key Item.id                       as Id,
//  key Item.recipientcompanycode     as ProfitCenter,
//
//      Header.product                as Product,
//      Product.ProductName           as ProductName,
//      Item.basecurrencyprofitcenter as BaseCurrencyProfitCenter,
//      Item.recipientcompanycode     as GroupCode,
//      Company.CompanyCodeName       as GroupName,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( Item.baseamountprofitcenter_c
//            as abap.dec(23,2) )     as Baseamountprofitcenter_c,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( Item.baseamountprofitcenter_h
//            as abap.dec(23,2) )     as Baseamountprofitcenter_h,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      cast( Item.baseamountprofitcenter_l
//            as abap.dec(23,2) )     as Baseamountprofitcenter_l
//}
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CS Post-Metric: by recipient company'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_IntercoProposalItemCS1B
  as select from zfi_a_intrc_cpi   as Item
    inner join   zfi_a_intrc_cph   as Header  on  Header.id     =  Item.id
                                              and Header.status <> ''
    inner join   ZI_IntercoProduct as Product on Product.Product  = Header.product
                                              and(
                                                Product.Metric    = 'IC'
                                                or Product.Metric = 'CS'
                                              )
    inner join   I_CompanyCode     as Company on Company.CompanyCode = Item.recipientcompanycode
{
  key Item.id                          as Id,
  key Item.recipientcompanycode        as ProfitCenter,

      Header.product                   as Product,
      Product.ProductName              as ProductName,
      Item.basecurrencyprofitcenter    as BaseCurrencyProfitCenter,
      Item.recipientcompanycode        as GroupCode,
      Company.CompanyCodeName          as GroupName,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      sum( cast( Item.baseamountprofitcenter_c
                 as abap.dec(23,2) ) ) as Baseamountprofitcenter_c,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      sum( cast( Item.baseamountprofitcenter_h
                 as abap.dec(23,2) ) ) as Baseamountprofitcenter_h,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      sum( cast( Item.baseamountprofitcenter_l
                 as abap.dec(23,2) ) ) as Baseamountprofitcenter_l,

      // ── NUEVO: moneda y monto local ──────────────────────────────────────
      Item.companycodecurrency         as CompanyCodeCurrency,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      sum( cast( Item.amountincompanycodecurrency_c
                 as abap.dec(23,2) ) ) as AmountInCompanyCodeCurrencyC,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      sum( cast( Item.amountincompanycodecurrency_h
                 as abap.dec(23,2) ) ) as AmountInCompanyCodeCurrencyH,

      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      sum( cast( Item.amountincompanycodecurrency_l
                 as abap.dec(23,2) ) ) as AmountInCompanyCodeCurrencyL
      // ─────────────────────────────────────────────────────────────────────
}
group by
  Item.id,
  Item.recipientcompanycode,
  Header.product,
  Product.ProductName,
  Item.basecurrencyprofitcenter,
  Item.companycodecurrency,
  Company.CompanyCodeName
