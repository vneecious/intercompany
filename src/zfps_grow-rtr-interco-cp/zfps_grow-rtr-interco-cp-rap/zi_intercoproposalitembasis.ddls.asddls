@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Basis related to Item'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
define view entity ZI_IntercoProposalItemBasis
  as select from zfi_a_intrc_cpib
  association              to exact one ZI_IntercoProposal           as _Proposal        on  $projection.id = _Proposal.Id
  association              to exact one ZC_INTERCOPROPOSALITEMAQ     as _ItemsAQ         on  $projection.id      = _ItemsAQ.Id
                                                                                         and $projection.item_id = _ItemsAQ.Item_Id
  association              to exact one zi_intercoproposalitembaogl2 as _ItemsBaOGLAccAQ on  $projection.id      = _ItemsBaOGLAccAQ.id
                                                                                         and $projection.item_id = _ItemsBaOGLAccAQ.item_id
  association              to parent ZI_IntercoProposalItem          as _Items           on  $projection.id      = _Items.Id
                                                                                         and $projection.item_id = _Items.Item_Id
  composition of exact one to many ZI_IntercoProposalItemCalc        as _ItemsCalc
  composition of exact one to one ZI_IntercoProposalItemBaOGlAc      as _ProposalItemsBaOGlAc

{
      @Semantics.uuid: true
  key id,
  key item_id,
  key itembasis_id,
      metric_id,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      sharedrate,
      cast( '%' as abap.unit( 3 ) ) as SharedRateUnit,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      sharedrate_h,
      cast( '%' as abap.unit( 3 ) ) as SharedRateUnitH,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      sharedrate_l,
      cast( '%' as abap.unit( 3 ) ) as SharedRateUnitL,
      exchangerate                  as ExchangeRate,
      exchangefactor                as ExchangeFactor,
      globalcurrency,
      @Semantics.amount.currencyCode : 'globalcurrency'
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then amountinglobalcurrency
      else abap.curr'0.00'
      end                           as amountinglobalcurrency,
      @Semantics.amount.currencyCode : 'globalcurrency'
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then amountinglobalcurrency
      else abap.curr'0.00'
      end                           as amountinglobalcurrency_c,
      @Semantics.amount.currencyCode : 'globalcurrency'
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then amountinglobalcurrency_h
      else abap.curr'0.00'
      end                           as amountinglobalcurrency_h,
      @Semantics.amount.currencyCode : 'globalcurrency'
      case
      when _Items.ProviderCountry <> _Items.RecipientCountry then amountinglobalcurrency_l
      else abap.curr'0.00'
      end                           as amountinglobalcurrency_l,
      companycodecurrency,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      case
      when _Items.ProviderCountry = _Items.RecipientCountry then amountincompanycodecurrency
      else abap.curr'0.00'
      end                           as amountincompanycodecurrency,
      createdat,
      createdby,
      //      amountincompanycodecurrency,
      /* Adicionales */
      //      _Proposal.ProviderCompanyCode,
      //      _Proposal.Product,
      //      _Items.recipientcompanycode,
      //      _Items.profitcenter,
      /* Associations */
      _Proposal,
      _Items,
      _ItemsAQ,
      _ItemsBaOGLAccAQ,
      _ItemsCalc,
      _ProposalItemsBaOGlAc
}
