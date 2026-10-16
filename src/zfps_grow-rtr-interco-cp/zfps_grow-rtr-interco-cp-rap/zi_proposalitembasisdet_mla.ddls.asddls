//@AbapCatalog.viewEnhancementCategory: [#NONE]
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Calculation Proposal Item Details'
//@Metadata.ignorePropagatedAnnotations: true
//@ObjectModel.usageType:{
//    serviceQuality: #X,
//    sizeCategory: #S,
//    dataClass: #MIXED
//}
//define view entity ZI_PROPOSALITEMBASISDET_MLA
//  as select from ZI_PROPOSALITEMBAOGLAC_MLA as ProposalItemBasis
//  association to ZI_PROPOSALITEM_MLA       as _ProposalItem        on  _ProposalItem.Id           = $projection.id
//                                                                   and _ProposalItem.Item_Id      = $projection.item_id
//                                                                   and _ProposalItem.ItemBasis_Id = $projection.itembasis_id
//  association to ZI_PROPOSALITEMDETAIL_MLA as _ProposalItemDetails on  _ProposalItemDetails.Id      = $projection.id
//                                                                   and _ProposalItemDetails.Item_Id = $projection.item_id
//  association to ZI_PROPOSALITEMCALC_MLA   as _ProposalItemCalc    on  _ProposalItemCalc.id      = $projection.id
//                                                                   and _ProposalItemCalc.item_id = $projection.item_id
//
//{
//  key id,
//  key item_id,
//  key itembasis_id,
//  key _ProposalItemDetails.GLAccount                as GLAccount,
//  key _ProposalItemDetails.CostCenter               as CostCenter,
//      _ProposalItemDetails.Product,
//      _ProposalItemDetails.profitcenter             as ProfitCenter,
//      _ProposalItemDetails.PandLL5ID,
//      _ProposalItemDetails.CostCenterStdHierArea,
//      _ProposalItemDetails.CCAllocation,
//      _ProposalItemDetails.CCConsolidation,
//      _ProposalItemDetails.CostCenterD4,
//      _ProposalItemDetails.Department,
//      _ProposalItem.sharedrate                      as SharedRate,
//      @Semantics.amount.currencyCode: 'Companycodecurrency'
//      ProposalItemBasis.AmountInCompanyCodeCurrency as AmountInCompanyCodeCurrency,
//      ProposalItemBasis.CompanyCodeCurrency         as CompanyCodeCurrency,
//      @Semantics.amount.currencyCode: 'Globalcurrency'
//      ProposalItemBasis.AmountInGlobalCurrency      as AmountInGlobalCurrency,
//      _ProposalItemDetails.GlobalCurrency           as GlobalCurrency,
//      _ProposalItemDetails.IntercoBasisId,
//      _ProposalItemDetails._BasisItem,
//      _ProposalItemDetails._PandLFlat,
//      _ProposalItem,
//      _ProposalItemCalc
//}
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item Basis Details'
define view entity ZI_PROPOSALITEMBASISDET_MLA
  as select from    ZI_PROPOSALITEMBAOGLAC_MLA  as ProposalItemBasis

  /* Unimos con la vista de Origen que ya tiene la lógica de normalización y CeBe 299 */
    left outer join ZI_PROPOSALITEMORGLACCT_MLA as _Data on  _Data.Id         = ProposalItemBasis.id
                                                         and _Data.ItemId     = ProposalItemBasis.item_id
                                                         and _Data.GlAccount  = ProposalItemBasis.GlAccount
                                                         and _Data.CostCenter = ProposalItemBasis.CostCenter

  association to ZI_PROPOSALITEM_MLA     as _ProposalItem     on  _ProposalItem.Id           = $projection.id
                                                              and _ProposalItem.Item_Id      = $projection.item_id
                                                              and _ProposalItem.ItemBasis_Id = $projection.itembasis_id
  association to ZI_PROPOSALITEMCALC_MLA as _ProposalItemCalc on  _ProposalItemCalc.id      = $projection.id
                                                              and _ProposalItemCalc.item_id = $projection.item_id
{
  key ProposalItemBasis.id,
  key ProposalItemBasis.item_id,
  key ProposalItemBasis.itembasis_id,

      /* Tomamos las llaves directamente de la base para evitar ambigüedad */
  key ProposalItemBasis.GlAccount                   as GLAccount,
  key ProposalItemBasis.CostCenter                  as CostCenter,

      /* Datos de P&L recuperados de la normalización */
      _Data.Product,
      _Data.cebe_aux                                as ProfitCenter,
      _Data.PandLL5ID,
      _Data.CostCenterStdHierArea,
      _Data.CCAllocation,
      _Data.CCConsolidation,
      _Data.CostCenterD4,
      _Data.Department,

      cast( '%' as abap.unit( 3 ) )                 as SharedRateUnit,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _ProposalItem.sharedrate                      as SharedRate,

      @Semantics.amount.currencyCode: 'Companycodecurrency'
      ProposalItemBasis.AmountInCompanyCodeCurrency as AmountInCompanyCodeCurrency,
      ProposalItemBasis.CompanyCodeCurrency         as CompanyCodeCurrency,

      @Semantics.amount.currencyCode: 'Globalcurrency'
      ProposalItemBasis.AmountInGlobalCurrency      as AmountInGlobalCurrency,

      _Data.GlobalCurrency                          as GlobalCurrency,

      /* Asociaciones requeridas por CALCDET */
      _Data._PandL                                  as _PandLFlat,
      _ProposalItem,
      _ProposalItemCalc
}
