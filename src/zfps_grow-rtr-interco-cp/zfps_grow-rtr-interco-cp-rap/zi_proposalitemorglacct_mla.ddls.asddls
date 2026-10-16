@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal - GL Accounts Origin (from Calc Basis)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_PROPOSALITEMORGLACCT_MLA
  as select from    ZI_PROPOSALITEMORGLACCT_PRE as Prep
    left outer join ZI_IntercoProposal          as Proposal     on Proposal.Id = Prep.id

    left outer join ZI_PROPOSALITEM_MLA         as ProposalItem on  Prep.id      = ProposalItem.Id
                                                                and Prep.item_id = ProposalItem.Item_Id

  association        to parent ZI_PROPOSALITEM_MLA   as _Item       on  $projection.Id     = _Item.Id
                                                                    and $projection.ItemId = _Item.Item_Id

  association        to ZI_IntercoProposal           as _Proposal   on  $projection.Id = _Proposal.Id
  association        to ZI_IntercoBasisItem          as _BasisItem  on  _BasisItem.Id           = Proposal.IntercoBasisId
                                                                    and _BasisItem.Product      = Proposal.Product
                                                                    and _BasisItem.Profitcenter = Prep.LookupProfitCenter
  //                                                                    and _BasisItem.Costcenter   = Prep.cost_center
  //                                                                    and _BasisItem.Glaccount    = Prep.gl_account
                                                                    and _BasisItem.Costcenter   = Prep.NormalizedCostCenter
                                                                    and _BasisItem.Glaccount    = Prep.NormalizedGlAccount
  association [0..1] to ZI_IntercoCostCenter         as _CostCenter on  _CostCenter.CostCenter      = Prep.cost_center
                                                                    and _CostCenter.ControllingArea = 'ML00'
  association        to ZI_IntercoPandLHierFlattened as _PandL      on  _PandL.ID = $projection.pandll5id
  association        to ZI_IntercoDepartment         as _Department on  _Department.Department = $projection.Department
{
  key Prep.id                          as Id,
  key Prep.item_id                     as ItemId,
  key Prep.gl_account                  as GlAccount,
  key Prep.cost_center                 as CostCenter,
      Prep.depto                       as Department,
      Prep.global_currency             as GlobalCurrency,
      //      ProposalItemOrigin.global_currency_h           as GlobalCurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      Prep.amount_in_global_currency   as AmountInGlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      Prep.amount_in_global_currency_h as AmountInGlobalCurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      Prep.amount_in_global_currency_l as AmountInGlobalCurrencyL,
      Prep.percent_of_total            as PercentOfTotal,

      /* 1. CEBE VISUAL: Viene de la lógica de la PRE (299 para nuevos, 200 para viejos) */
      Prep.cebe_aux                    as cebe_aux,

      /* 2. LOOKUP: El túnel interno hacia el 200 para las asociaciones */
      Prep.LookupProfitCenter,

      /* 3. PRODUCTO: Usamos la asociación _Proposal para obtener el MATNR real del Header */
      _Proposal.Product                as Product,

      //      _Proposal.Product                as Product,
      _BasisItem.PandLL5ID,
      _BasisItem.CostCenterStdHierArea,
      _BasisItem.CCAllocation,
      _BasisItem.CCConsolidation,
      _BasisItem.CostCenterD4,
      //      right(ProposalItemOrigin.cost_center, 3)       as cebe_aux,
      _CostCenter,
      _Item,
      _Proposal,
      _PandL,
      _Item.recipientcompanycode       as RecipientCompanyCode,
      _Department
}
