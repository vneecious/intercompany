@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Preparacion campo calculado MLA'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_PROPOSALITEMORGLACCT_PRE
  as select from    zfi_a_intrc_cpig               as ProposalItemOrigin
    left outer join ZI_PROPOSALITEM_MLA            as ProposalItem on  ProposalItemOrigin.id      = ProposalItem.Id
                                                                   and ProposalItemOrigin.item_id = ProposalItem.Item_Id
  //    left outer join ZI_INTERCO_SPLIT_CEBE_MLA as Matcher      on  ProposalItemOrigin.id      = Matcher.id
  //                                                              and ProposalItemOrigin.item_id = Matcher.item_id
  /* 1. Usamos la vista que tiene la jerarquía para detectar nulos */
    left outer join ZI_IntercoProposalItemOrGLAcct as OriginalHier on  ProposalItemOrigin.id              = OriginalHier.Id
                                                                   and ProposalItemOrigin.item_id         = OriginalHier.ItemId
                                                                   and OriginalHier.CostCenterStdHierArea is not initial
{
  key ProposalItemOrigin.id,
  key ProposalItemOrigin.item_id,
  key ProposalItemOrigin.gl_account,
  key ProposalItemOrigin.cost_center,
      ProposalItemOrigin.depto,

      -- Creamos estos alias para usarlos en el JOIN de la siguiente capa
      lpad(ProposalItemOrigin.gl_account, 10, '0')  as NormalizedGlAccount,
      lpad(ProposalItemOrigin.cost_center, 10, '0') as NormalizedCostCenter,

      -- Este es el campo de referencia
      ProposalItemOrigin.global_currency,

      @Semantics.amount.currencyCode: 'global_currency'
      ProposalItemOrigin.amount_in_global_currency,

      @Semantics.amount.currencyCode: 'global_currency'
      ProposalItemOrigin.amount_in_global_currency_h,

      @Semantics.amount.currencyCode: 'global_currency'
      ProposalItemOrigin.amount_in_global_currency_l,

      ProposalItemOrigin.percent_of_total,

      case
              when OriginalHier.Id is null then lpad('200', 10, '0') -- Es Génova, forzamos búsqueda en 200
              else lpad(ProposalItem.profitcenter, 10, '0')          -- Es original, usamos su CeBe
            end                                     as LookupProfitCenter,

      /* 3. CEBE VISUAL: Si no tiene jerarquía es el registro nuevo (Génova 299) */
      case
         when OriginalHier.Id is null then '299'                     -- Si el JOIN falló, es el nuevo
         else ProposalItem.profitcenter                              -- Si el JOIN funcionó, es el original (200)
      end                                           as cebe_aux
      //      /* LOOKUP: Siempre debe ser el '200' con ceros para que _BasisItem funcione */
      //      case
      //        when Matcher.id is not null then lpad('200', 10, '0')
      //        else lpad(ProposalItem.profitcenter, 10, '0')
      //      end                                           as LookupProfitCenter,
      //      /* CEBE VISUAL: Aquí es donde diferenciamos 299 de 200 */
      //      case
      //         when Matcher.id is not null then '299'         -- Si es nuevo/copiado, forzamos 299
      //         else ProposalItem.profitcenter                 -- Si es original, dejamos su 200
      //       end                                          as cebe_aux


}
