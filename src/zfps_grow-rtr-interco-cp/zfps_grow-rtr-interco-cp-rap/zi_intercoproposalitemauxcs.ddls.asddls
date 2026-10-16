//@AbapCatalog.viewEnhancementCategory: [#NONE]
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Interco Aux Cost Sharing - GL Items by Company Code'
//@Metadata.ignorePropagatedAnnotations: true
//
//define view entity ZI_IntercoProposalItemAuxCS
//  as select from ZI_IntercoProposalItemOrGLAcct as OrGL
//{
//  key OrGL.Id,
//  key OrGL.ItemId,
//  key OrGL.RecipientCompanyCode,
//
//      OrGL._Proposal.Product      as Product,
//      OrGL._Proposal.ProductName  as ProductName,
//      OrGL.GlobalCurrency         as BaseCurrencyProfitCenter,
//      OrGL.CostCenterD4           as D4,
//      OrGL.PercentOfTotal,
//
//      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
//      OrGL.AmountInGlobalCurrency as Amount
//}
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Aux Cost Sharing - GL Items by Company Code'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_IntercoProposalItemAuxCS
  as select from ZI_IntercoProposalItemOrGLAcct as OrGL
    inner join   zfi_a_intrc_cph                as Header  on Header.id = OrGL.Id
    inner join   ZI_IntercoProduct              as Product on Product.Product  = Header.product
                                                           and(
                                                             Product.Metric    = 'IC'
                                                             or Product.Metric = 'CS'
                                                           )
    inner join   I_CompanyCode                  as Company on Company.CompanyCode = Header.providercompanycode
{
  key OrGL.Id,
  key OrGL.ItemId,
  key OrGL.RecipientCompanyCode,

      Header.status               as Status,
      Header.providercompanycode  as ProviderCompanyCode,
      Company.CompanyCodeName     as ProviderCompanyName,
      OrGL._Proposal.Product      as Product,
      OrGL._Proposal.ProductName  as ProductName,
      OrGL.GlobalCurrency         as BaseCurrencyProfitCenter,
      OrGL.CostCenterD4           as D4,
      OrGL.PercentOfTotal,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      OrGL.AmountInGlobalCurrency as Amount
}
