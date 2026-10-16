@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item Details'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemDetail
  as select from ZI_IntercoProposalItem as ProposalItem
    inner join   ZI_IntercoProposal     as Proposal on Proposal.Id = ProposalItem.Id
  association to ZI_IntercoProposalItem       as _ProposalItem     on  _ProposalItem.Id      = $projection.Id
                                                                   and _ProposalItem.Item_Id = $projection.Item_Id
  association to ZI_IntercoProposalItemCalc   as _ProposalItemCalc on  _ProposalItemCalc.id      = $projection.Id
                                                                   and _ProposalItemCalc.item_id = $projection.Item_Id
  association to ZI_IntercoBasisItem          as _BasisItem        on  _BasisItem.Id           = Proposal.IntercoBasisId
                                                                   and _BasisItem.Product      = Proposal.Product
                                                                   and _BasisItem.Profitcenter = ProposalItem.profitcenter
  association to ZI_IntercoPandLHierFlattened as _PandLFlat        on  _PandLFlat.ID = $projection.pandll5id
{
  key       Proposal.Id                            as Id,
  key       ProposalItem.Item_Id                   as Item_Id,
  key       _BasisItem.Glaccount                   as GLAccount,
  key       _BasisItem.Costcenter                  as CostCenter,
            Proposal.Product,
            ProposalItem.profitcenter,
            _BasisItem.PandLL5ID,
            _BasisItem.CostCenterStdHierArea,
            _BasisItem.CCAllocation,
            _BasisItem.CCConsolidation,
            _BasisItem.CostCenterD4,
            _BasisItem.Department,
            @Semantics.amount.currencyCode: 'Companycodecurrency'
            _BasisItem.Amountincompanycodecurrency as AmountInCompanyCodeCurrency,
            _BasisItem.Companycodecurrency         as CompanyCodeCurrency,
            @Semantics.amount.currencyCode: 'Globalcurrency'
            _BasisItem.Amountinglobalcurrency      as AmountInGlobalCurrency,
            _BasisItem.Globalcurrency              as GlobalCurrency,
            Proposal.IntercoBasisId,
            _BasisItem,
            _PandLFlat,
            _ProposalItem
}
