@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Basis related to Item'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
define view entity ZI_PROPOSALITEMBASIS_MLA
  as select from zfi_a_intrc_cpib
  association [1..1] to ZI_IntercoProposal                 as _Proposal             on  $projection.id = _Proposal.Id
  association        to exact one ZC_INTERCOPROPOSALITEMAQ as _ItemsAQ              on  $projection.id      = _ItemsAQ.Id
                                                                                    and $projection.item_id = _ItemsAQ.Item_Id
  association [0..1] to ZI_PROPOSALITEMBAOGL2_MLA          as _ItemsBaOGLAccAQ      on  $projection.id      = _ItemsBaOGLAccAQ.id
                                                                                    and $projection.item_id = _ItemsBaOGLAccAQ.item_id
  association [1..1] to ZI_PROPOSALITEM_MLA                as _Items                on  $projection.id      = _Items.Id
                                                                                    and $projection.item_id = _Items.Item_Id
  association [0..*] to ZI_PROPOSALITEMCALC_MLA            as _ItemsCalc            on  $projection.id           = _ItemsCalc.id
                                                                                    and $projection.item_id      = _ItemsCalc.item_id
                                                                                    and $projection.itembasis_id = _ItemsCalc.itembasis_id
  association [0..*] to ZI_PROPOSALITEMBAOGLAC_MLA         as _ProposalItemsBaOGlAc on  $projection.id           = _ProposalItemsBaOGlAc.id
                                                                                    and $projection.item_id      = _ProposalItemsBaOGlAc.item_id
                                                                                    and $projection.itembasis_id = _ProposalItemsBaOGlAc.itembasis_id

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
