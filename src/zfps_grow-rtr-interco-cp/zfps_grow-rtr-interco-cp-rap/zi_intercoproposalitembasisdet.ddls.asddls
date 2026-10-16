@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item Details'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemBasisDet
  as select from ZI_IntercoProposalItemBaOGlAc as ProposalItemBasis
  association to ZI_IntercoProposalItem       as _ProposalItem        on  _ProposalItem.Id           = $projection.id
                                                                      and _ProposalItem.Item_Id      = $projection.item_id
                                                                      and _ProposalItem.ItemBasis_Id = $projection.itembasis_id
  association to ZI_IntercoProposalItemDetail as _ProposalItemDetails on  _ProposalItemDetails.Id      = $projection.id
                                                                      and _ProposalItemDetails.Item_Id = $projection.item_id
  association to ZI_IntercoProposalItemCalc   as _ProposalItemCalc    on  _ProposalItemCalc.id      = $projection.id
                                                                      and _ProposalItemCalc.item_id = $projection.item_id

{
  key id,
  key item_id,
  key itembasis_id,
  key _ProposalItemDetails.GLAccount                as GLAccount,
  key _ProposalItemDetails.CostCenter               as CostCenter,
      _ProposalItemDetails.Product,
      _ProposalItemDetails.profitcenter             as ProfitCenter,
      _ProposalItemDetails.PandLL5ID,
      _ProposalItemDetails.CostCenterStdHierArea,
      _ProposalItemDetails.CCAllocation,
      _ProposalItemDetails.CCConsolidation,
      _ProposalItemDetails.CostCenterD4,
      _ProposalItemDetails.Department,
      _ProposalItem.sharedrate                      as SharedRate,
      @Semantics.amount.currencyCode: 'Companycodecurrency'
      ProposalItemBasis.AmountInCompanyCodeCurrency as AmountInCompanyCodeCurrency,
      ProposalItemBasis.CompanyCodeCurrency         as CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'Globalcurrency'
      ProposalItemBasis.AmountInGlobalCurrency      as AmountInGlobalCurrency,
      _ProposalItemDetails.GlobalCurrency           as GlobalCurrency,
      _ProposalItemDetails.IntercoBasisId,
      _ProposalItemDetails._BasisItem,
      _ProposalItemDetails._PandLFlat,
      _ProposalItem,
      _ProposalItemCalc
}
