@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CS Pre-Metric: MLB total'
@Metadata.ignorePropagatedAnnotations: true

define view entity ZI_IntercoProposalItemCS1A
  as select from ZI_IntercoProposalItemOrGLAcct as OrGL
    inner join   zfi_a_intrc_cph                as Header  on  Header.id     = OrGL.Id
                                                           and Header.status = ''
    inner join   ZI_IntercoProduct              as Product on Product.Product  = Header.product
                                                           and(
                                                             Product.Metric    = 'IC'
                                                             or Product.Metric = 'CS'
                                                           )
    inner join   I_CompanyCode                  as Company on Company.CompanyCode = Header.providercompanycode
{
  key OrGL.Id,
  key Header.providercompanycode  as ProfitCenter,

      OrGL.ItemId, -- ← AGREGAR para el count distinct

      Header.product              as Product,
      OrGL._Proposal.ProductName  as ProductName,
      OrGL.GlobalCurrency         as BaseCurrencyProfitCenter,
      OrGL.CostCenterD4           as D4,
      Header.providercompanycode  as GroupCode,
      Company.CompanyCodeName     as GroupName,

      @Semantics.amount.currencyCode: 'BaseCurrencyProfitCenter'
      OrGL.AmountInGlobalCurrency as Amount
}
