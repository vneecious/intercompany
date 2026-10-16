@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal - GL Accounts Origin (from Calc Basis)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemOrGLAcct
  as select distinct from zfi_a_intrc_cpig       as ProposalItemOrigin
    inner join            ZI_IntercoProposalItem as ProposalItem on  ProposalItemOrigin.id      = ProposalItem.Id
                                                                 and ProposalItemOrigin.item_id = ProposalItem.Item_Id
    inner join            ZI_IntercoProposal     as Proposal     on Proposal.Id = ProposalItemOrigin.id
  association        to parent ZI_IntercoProposalItem as _Item       on  $projection.Id     = _Item.Id
                                                                     and $projection.ItemId = _Item.Item_Id

  association        to ZI_IntercoProposal            as _Proposal   on  $projection.Id = _Proposal.Id
  association        to ZI_IntercoBasisItem           as _BasisItem  on  _BasisItem.Id           = Proposal.IntercoBasisId
                                                                     and _BasisItem.Product      = Proposal.Product
                                                                     and _BasisItem.Profitcenter = ProposalItem.profitcenter
                                                                     and _BasisItem.Costcenter   = $projection.CostCenter
                                                                     and _BasisItem.Glaccount    = $projection.GlAccount
  association [0..1] to ZI_IntercoCostCenter          as _CostCenter on  _CostCenter.CostCenter      = $projection.CostCenter
                                                                     and _CostCenter.ControllingArea = 'ML00'
  association        to ZI_IntercoPandLHierFlattened  as _PandL      on  _PandL.ID = $projection.pandll5id
  association        to ZI_IntercoDepartment          as _Department on  _Department.Department = $projection.Department
{
  key ProposalItemOrigin.id                          as Id,
  key ProposalItemOrigin.item_id                     as ItemId,
  key ProposalItemOrigin.gl_account                  as GlAccount,
  key ProposalItemOrigin.cost_center                 as CostCenter,
      ProposalItemOrigin.depto                       as Department,
      ProposalItemOrigin.global_currency             as GlobalCurrency,
      //      ProposalItemOrigin.global_currency_h           as GlobalCurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      ProposalItemOrigin.amount_in_global_currency   as AmountInGlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      ProposalItemOrigin.amount_in_global_currency_h as AmountInGlobalCurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      ProposalItemOrigin.amount_in_global_currency_l as AmountInGlobalCurrencyL,
      ProposalItemOrigin.percent_of_total            as PercentOfTotal,
      _BasisItem.PandLL5ID,
      _BasisItem.CostCenterStdHierArea,
      _BasisItem.CCAllocation,
      _BasisItem.CCConsolidation,
      _BasisItem.CostCenterD4,
      right(ProposalItemOrigin.cost_center, 3)       as cebe_aux,
      _CostCenter,
      _Item,
      _Proposal,
      _PandL,
      _Item.recipientcompanycode                     as RecipientCompanyCode,
      _Department
}
