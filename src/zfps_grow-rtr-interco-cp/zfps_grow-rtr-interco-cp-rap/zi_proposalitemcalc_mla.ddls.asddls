@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculated Item'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_PROPOSALITEMCALC_MLA
  as select from zfi_a_intrc_cpic
  association [1..1] to ZI_IntercoProposal                 as _Proposal        on  $projection.id = _Proposal.Id
  //      association              to parent ZI_IntercoProposalItem  as _Items    on  $projection.id      = _Items.Id
  //                                                                              and $projection.item_id = _Items.Item_Id
  association [1..1] to ZI_PROPOSALITEM_MLA                as _Items           on  $projection.id      = _Items.Id
                                                                               and $projection.item_id = _Items.Item_Id
  association        to exact one ZC_INTERCOPROPOSALITEMAQ as _ItemsAQ         on  $projection.id      = _ItemsAQ.Id
                                                                               and $projection.item_id = _ItemsAQ.Item_Id
  association [0..1] to ZI_PROPOSALITEMBAOGL2_MLA          as _ItemsBaOGLAccAQ on  $projection.id      = _ItemsBaOGLAccAQ.id
                                                                               and $projection.item_id = _ItemsBaOGLAccAQ.item_id
  association        to parent ZI_PROPOSALITEMBASIS_MLA    as _ItemsBasis      on  $projection.id           = _ItemsBasis.id
                                                                               and $projection.item_id      = _ItemsBasis.item_id
                                                                               and $projection.itembasis_id = _ItemsBasis.itembasis_id
  //  composition of exact one to many ZI_IntercoProposalItemDoc     as _ItemsDoc
  association [0..*] to ZI_IntercoProposalItemDoc          as _ItemsDoc        on  $projection.id      = _ItemsDoc.id
                                                                               and $projection.item_id = _ItemsDoc.item_id
  association [0..1] to ZI_IntercoPropStatusCalc_SH        as _Status          on  $projection.commitstatus = _Status.Status
{
      @Semantics.uuid: true
  key id,
  key item_id,
  key itembasis_id,
  key itemcalc_id,
      @Consumption: {
        valueHelpDefinition: [{
            entity: {
                name: 'ZI_IntercoPropStatusCalc_SH',
                element: 'Status'
            }
        }]
      }
      commitstatus,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      markup,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      grossingupmargin,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      grossingupbase,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      latepaymentinterest,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      providergrossingup,
      cast( '%' as abap.unit( 3 ) )                                                                                             as SharedRateUnit,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      markupamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      grossingupmarginamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      grossingupbaseamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      providergrossingupamount,
      @Semantics.amount.currencyCode : 'CodeCurrency'
      ( _ItemsBasis.amountinglobalcurrency + markupamount + grossingupmarginamount + grossingupbaseamount  )                    as TotalInGlobalAmount,
      _ItemsBasis.globalcurrency                                                                                                as CodeCurrency,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      markupamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      providergrossingupamntinlocal,
      @Semantics.amount.currencyCode : 'CodeCurrencyCompanyCode'
      ( _ItemsBasis.amountincompanycodecurrency + markupamntinlocal + grossingupmarginamntinlocal + grossingupbaseamntinlocal ) as c_TotalInCompanyCodeAmount,
      _ItemsBasis.companycodecurrency                                                                                           as CodeCurrencyCompanyCode,
      createdat,
      createdby,
      /* Associations */
      _Proposal,
      _Items,
      _ItemsAQ,
      _ItemsBaOGLAccAQ,
      _ItemsBasis,
      _ItemsDoc,
      _Status
}
