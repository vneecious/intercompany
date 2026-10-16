//@AbapCatalog.viewEnhancementCategory: [#NONE]
//@AccessControl.authorizationCheck: #NOT_REQUIRED
//@EndUserText.label: 'Interco Aux con split de montos por D4'
//
//define view entity ZI_IntercoProposalItemAux
//  as select from ZI_IntercoProposalItemOrGLAcct as OrGL
//{
//  key OrGL.Id,
//  key OrGL.ItemId,
//  key OrGL.RecipientCompanyCode           as RecipientCompanyCode,
//      right( OrGL.CostCenter, 3 )         as Cebe_Aux_cc,
//      right( OrGL._Item.profitcenter, 3 ) as Cebe_Aux,
//      OrGL.GlobalCurrency                 as BaseCurrencyProfitCenter,
//      OrGL.CostCenterD4                   as D4,
//      OrGL._Item.profitcenter             as ProfitCenter,
//      //            cast( 1 as abap.int4 )              as Quantity,
//      OrGL.PercentOfTotal,
//      OrGL.AmountInGlobalCurrency         as Amount
//
//}

@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Aux con excepción MLA'

define view entity ZI_IntercoProposalItemAux
  as select from    ZI_IntercoProposalItemOrGLAcct as OrGL
  // El Left Join asegura que NO perdemos datos.
    left outer join ZI_Interco_Split_CEBE          as Matcher on  OrGL.Id                    = Matcher.Id
                                                              and OrGL.ItemId                = Matcher.ItemId
                                                              and OrGL.CostCenterStdHierArea = Matcher.CostCenterStdHierArea
{
  key OrGL.Id,
  key OrGL.ItemId,
  key OrGL.RecipientCompanyCode,
      OrGL._Proposal.Product,
      OrGL._Proposal.ProductName,

      case
        when Matcher.Id is not null then cast('299' as abap.char(3))
        else right( OrGL.CostCenter, 3 ) // Mantiene el valor original (200, 300, etc)
      end                         as Cebe_Aux_cc,

      case
        when Matcher.Id is not null then cast('299' as abap.char(3))
        else right( OrGL._Item.profitcenter, 3 ) // Mantiene el valor original
      end                         as Cebe_Aux,

      OrGL.GlobalCurrency         as BaseCurrencyProfitCenter,
      OrGL.CostCenterD4           as D4,

      //      // ── AJUSTE: ProfitCenter con los últimos 3 caracteres ──
      //      case
      //        when Matcher.Id is not null then cast('0000000299' as abap.char(10))
      //        else cast( right( OrGL._Item.profitcenter, 3 ) as abap.char(10) )
      //      end                         as ProfitCenter,
      //       ────────────────────────────────────────────────────────
      case
        when Matcher.Id is not null then cast('0000000299' as abap.char(10))
        else OrGL._Item.profitcenter // Mantiene el valor original
      end                         as ProfitCenter,

      OrGL.PercentOfTotal,
      OrGL.AmountInGlobalCurrency as Amount
}
