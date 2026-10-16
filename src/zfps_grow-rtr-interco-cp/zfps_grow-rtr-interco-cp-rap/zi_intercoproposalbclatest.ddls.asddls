@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Latest ID from Proposal Basis n Calc'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalBCLatest
  as select from ZI_IntercoProposalBasisLatest as _latest
{
  key _latest.Id,
  key _latest.Item_Id,
      _latest.Itembasis_Id,
      _latest.Itemcalc_Id,
      _b.metric_id,
      _b.sharedrate,
      _b.sharedrate_h,
      _b.sharedrate_l,
      _b.exchangerate,
      _b.exchangefactor,
      _b.globalcurrency,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _b.amountinglobalcurrency,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _b.amountinglobalcurrency_c,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _b.amountinglobalcurrency_h,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _b.amountinglobalcurrency_l,
      _b.companycodecurrency,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      _b.amountincompanycodecurrency,
      _b.createdat as BasisCreatedAt,
      _b.createdby as BasisCreatedBy,
      _c.commitstatus,
      _c.markup,
      _c.grossingupbase,
      _c.grossingupmargin,
      _c.latepaymentinterest,
      _c.providergrossingup,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _c.markupamount,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _c.grossingupbaseamount,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _c.grossingupmarginamount,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _c.latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'globalcurrency'
      _c.providergrossingupamount,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      _c.markupamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      _c.grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      _c.grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      _c.latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      _c.providergrossingupamntinlocal,
      _c.createdat as CalcCreatedAt,
      _c.createdby as CalcCreatedBy
}
