@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Calc Rate ffor comapnies'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemBasisRat as select from ZI_IntercoProposalItemBasis
{
  key id,
  key _Proposal.Product           as Product,
  key _Items.ProviderCompanyCode  as ProviderCompanyCode,
  key _Items.ProfitCenter         as ProfitCenter,  
      sum ( sharedrate)           as totalRateApplyed
}
group by
  id,
  _Proposal.Product,
  _Items.ProviderCompanyCode,
  _Items.ProfitCenter
