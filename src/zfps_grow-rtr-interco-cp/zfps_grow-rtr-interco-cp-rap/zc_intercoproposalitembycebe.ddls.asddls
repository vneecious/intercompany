//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Proposal Item by Profit Center'
//@Metadata.ignorePropagatedAnnotations: true
//@Metadata.allowExtensions: true
//
//define root view entity ZC_IntercoProposalItemByCeBe
//  as projection on ZI_IntercoProposalItemByCeBe
//{
//  key  Id,
//  key  ProfitCenter,
//       BaseCurrencyProfitCenter,
//       Product,
//       ProductName,
//       @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//       Baseamountprofitcenter,
//
//       @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//       BaseamountprofitcenterH,
//
//       @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
//       BaseamountprofitcenterL
//}
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Proposal Item by Profit Center'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true

define root view entity ZC_IntercoProposalItemByCeBe
  as projection on ZI_IntercoProposalItemByCeBe
{
  key  Id,
  key  ProfitCenter,
  key  Product,
       @Semantics.currencyCode: true
       BaseCurrencyProfitCenter,
       @EndUserText.label: 'Product'
       ProductName,

       GroupCode,
       GroupName,
       IsCostSharing,
       IsBermudas,
       @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
       Baseamountprofitcenter,

       @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
       BaseamountprofitcenterH,

       @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
       BaseamountprofitcenterL,

       // ── NUEVO ────────────────────────────────────────────────────────────
       @Semantics.currencyCode: true
       @UI.hidden: true
       CompanyCodeCurrency,

       @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
       AmountInCompanyCodeCurrencyC,

       @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
       AmountInCompanyCodeCurrencyH,

       @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
       AmountInCompanyCodeCurrencyL
       // ─────────────────────────────────────────────────────────────────────
}
