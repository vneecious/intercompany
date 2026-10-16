@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
//@ObjectModel.usageType:{
//    serviceQuality: #X,
//    sizeCategory: #L,
//    dataClass: #MIXED
//}
define view entity ZI_PROPOSALITEM_MLA
  as select from zfi_a_intrc_cpi
  association              to parent ZI_IntercoProposal          as _Proposal             on  $projection.Id = _Proposal.Id
  association [0..1]       to ZI_IntercoCompanyCode              as _RecipientCompanyCode on  zfi_a_intrc_cpi.recipientcompanycode = _RecipientCompanyCode.CompanyCode
  association [0..*]       to ZI_PROPOSALITEMORGLACCT_MLA        as _ProposalItemsDetails on  $projection.Id      = _ProposalItemsDetails.Id
                                                                                          and $projection.Item_Id = _ProposalItemsDetails.ItemId
  association [0..1]       to ZI_IntercoProfitCenter_SH          as _ProfitCenter         on  $projection.profitcenter = _ProfitCenter.ProfitCenter
  association [0..*]       to ZI_PROPOSALITEMBASIS_MLA           as _ProposalItemsBasis   on  $projection.Id      = _ProposalItemsBasis.id
                                                                                          and $projection.Item_Id = _ProposalItemsBasis.item_id

  association of exact one to one ZI_IntercoProposalBCLatest     as _BasisCalcLatest      on  zfi_a_intrc_cpi.id      = _BasisCalcLatest.Id
                                                                                          and zfi_a_intrc_cpi.item_id = _BasisCalcLatest.Item_Id
  //  association of exact one to one zfi_a_intrc_cpib               as _ItemsBasis               on  zfi_a_intrc_cpi.id       = _ItemsBasis.id
  //                                                                                              and zfi_a_intrc_cpi.item_id  = _ItemsBasis.item_id
  //                                                                                              and $projection.ItemBasis_Id = _ItemsBasis.itembasis_id
  //    association of exact one to one zfi_a_intrc_cpic               as _ItemsCalc                on  zfi_a_intrc_cpi.id           = _ItemsCalc.id
  //                                                                                                and zfi_a_intrc_cpi.item_id      = _ItemsCalc.item_id
  //                                                                                                and $projection.ItemBasis_Id = _ItemsCalc.itembasis_id
  //                                                                                                and $projection.ItemCalc_Id  = _ItemsCalc.itemcalc_id
  association of exact one to many ZI_PROPOSALITEMCALC_MLA       as _ProposalItemsCalc    on  $projection.Id      = _ProposalItemsCalc.id
                                                                                          and $projection.Item_Id = _ProposalItemsCalc.item_id
  association of exact one to many ZI_IntercoProposalItemDoc     as _ProposalItemsDoc     on  $projection.Id      = _ProposalItemsDoc.id
                                                                                          and $projection.Item_Id = _ProposalItemsDoc.item_id
  //adicionales
  association of exact one to one ZR_IntercoCompanyCodeLogistics as _CompanyCodeLogistic  on  $projection.recipientcompanycode = _CompanyCodeLogistic.CompanyCode
  association of exact one to one ZI_IntercoRelationship         as _Relationship         on  $projection.recipientcompanycode = _Relationship.RecipientCompanyCode
                                                                                          and $projection.ProviderCompanyCode  = _Relationship.ProviderCompanyCode

  association [0..1]       to ZI_IntercoProfitCenter_EQ          as _ProfitCenterEQ       on  $projection.profitcenter = _ProfitCenterEQ.Profitcenter
  //  association of exact one to one ZI_IntercoCompanyRelProduct    as _CompanyRelProduct    on  $projection.ProviderCompanyCode  = _CompanyRelProduct.ProviderCompanyCode
  //                                                                                          and $projection.recipientcompanycode = _CompanyRelProduct.RecipientCompanyCode
  //                                                                                          and $projection.Product              = _CompanyRelProduct.Product
  //                                                                                          and $projection.profitcenter         = _CompanyRelProduct.ProfitCenter
  //  association [1..1]       to ZC_IntercoProposalItemBasisC       as _CurrentProposalItemBasis on  $projection.Id      = _CurrentProposalItemBasis.id
  //                                                                                              and $projection.Item_Id = _CurrentProposalItemBasis.item_id
  //  association [1..1]       to ZI_IntercoProposalItemCalc         as _CurrentProposalItemCalc  on  $projection.Id                        = _CurrentProposalItemCalc.id
  //                                                                                              and $projection.Item_Id                   = _CurrentProposalItemCalc.item_id
  //                                                                                              and _CurrentProposalItemCalc.itembasis_id = 1
  //                                                                                              and _CurrentProposalItemCalc.itemcalc_id  = 1
  association              to ZI_IntercoDocCriticality           as _DocCriticality       on  $projection.Id      = _DocCriticality.id
                                                                                          and $projection.Item_Id = _DocCriticality.item_id
{
      @Semantics.uuid: true
  key id                                                                                                                                                                                as Id,
  key item_id                                                                                                                                                                           as Item_Id,
      _BasisCalcLatest.Itembasis_Id                                                                                                                                                     as ItemBasis_Id,
      _BasisCalcLatest.Itemcalc_Id                                                                                                                                                      as ItemCalc_Id,
      _Proposal.ProviderCompanyCode                                                                                                                                                     as ProviderCompanyCode,
      _Proposal._ProviderCompanyCode.CompanyCodeName                                                                                                                                    as ProviderCompanyName,
      recipientcompanycode,
      _RecipientCompanyCode.CompanyCodeName                                                                                                                                             as RecipientCompanyName,
      _RecipientCompanyCode.Country                                                                                                                                                     as RecipientCountry,
      profitcenter,
      _ProfitCenter.ProfitCenterName                                                                                                                                                    as ProfitCenterName,
      right(profitcenter,3)                                                                                                                                                             as cebe_aux,
      right(_ProfitCenterEQ.Profitcenter_eq,3)                                                                                                                                          as ProfitCenterEQ,
      interdivisional                                                                                                                                                                   as Interdivisional,

      basecurrencyprofitcenter                                                                                                                                                          as BaseCurrencyProfitCenter,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter,
      // *** Nuevos campos con el sufijo 'H' Hispano***
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter_c                                                                                                                                                          as BaseAmountProfitCenterC,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter_h                                                                                                                                                          as BaseAmountProfitCenterH,
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter_l                                                                                                                                                          as BaseAmountProfitCenterL,
      // *** Fin de los nuevos campos ***                                                                                                                                                       as BaseAmountProfitCenter,
      _Proposal.Product                                                                                                                                                                 as Product,
      _Proposal.ProductName                                                                                                                                                             as ProductName,
      _Proposal.GlobalCurrency                                                                                                                                                          as GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      _Proposal.AmountInGlobalCurrency                                                                                                                                                  as AmountInGlobalCurr,
      cast( '%' as abap.unit( 3 ) )                                                                                                                                                     as SharedRateUnit,
      /* 05/15: mostrar los campos de metricas y tarifas a nivel de Items */
      _BasisCalcLatest.metric_id,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.sharedrate,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.sharedrate_h                                                                                                                                                     as SharedRateH,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.sharedrate_l                                                                                                                                                     as SharedRateL,

      //      case
      //        when $projection.providercountry = $projection.RecipientCountry then _BasisCalcLatest.exchangerate
      //        else abap.dec'0.00'
      //      end                                                                                                                                                                               as ExchangeRate,
      _BasisCalcLatest.exchangerate                                                                                                                                                     as ExchangeRate,
      _BasisCalcLatest.exchangefactor                                                                                                                                                   as ExchangeFactor,

      @Semantics.amount.currencyCode : 'globalcurrency'
      //      case
      //      when $projection.providercountry <> $projection.RecipientCountry then _BasisCalcLatest.amountinglobalcurrency
      //      else abap.curr'0.00'
      //      end                                            as b_amountinglobalcurrency,
      _BasisCalcLatest.amountinglobalcurrency                                                                                                                                           as b_amountinglobalcurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      //      @Aggregation.default: #SUM
      _BasisCalcLatest.amountinglobalcurrency_c                                                                                                                                         as b_amountinglobalcurrencyC,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      _BasisCalcLatest.amountinglobalcurrency_h                                                                                                                                         as b_amountinglobalcurrencyH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      _BasisCalcLatest.amountinglobalcurrency_l                                                                                                                                         as b_amountinglobalcurrencyL,
      _BasisCalcLatest.companycodecurrency,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      case
      when $projection.providercountry = $projection.RecipientCountry then _BasisCalcLatest.amountincompanycodecurrency
      else abap.curr'0.00'
      end                                                                                                                                                                               as b_amountincompanycodecurrency,
      case
      when $projection.providercountry <> $projection.RecipientCountry then _Proposal.GlobalCurrency
      else _BasisCalcLatest.companycodecurrency
      end                                                                                                                                                                               as transactioncurrency,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then _BasisCalcLatest.amountinglobalcurrency
      else _BasisCalcLatest.amountincompanycodecurrency
      end                                                                                                                                                                               as amountintrasactioncurrency,
      @Consumption: {
        valueHelpDefinition: [{
            entity: {
                name: 'ZI_IntercoPropStatusCalc_SH',
                element: 'Status'
            }
        }]
      }
      _BasisCalcLatest.commitstatus,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.markup,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.grossingupmargin,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.grossingupbase,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.latepaymentinterest,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.providergrossingup,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      _BasisCalcLatest.markupamount,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      _BasisCalcLatest.grossingupmarginamount,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      _BasisCalcLatest.grossingupbaseamount,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      _BasisCalcLatest.latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      _BasisCalcLatest.providergrossingupamount,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      ( _BasisCalcLatest.amountinglobalcurrency + _BasisCalcLatest.markupamount + _BasisCalcLatest.grossingupmarginamount + _BasisCalcLatest.grossingupbaseamount )                     as c_TotalInGlobalAmount,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      ( _BasisCalcLatest.amountinglobalcurrency_c + _BasisCalcLatest.markupamount + _BasisCalcLatest.grossingupmarginamount + _BasisCalcLatest.grossingupbaseamount )                   as c_TotalInGlobalAmountC,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      ( _BasisCalcLatest.amountinglobalcurrency_h + _BasisCalcLatest.markupamount + _BasisCalcLatest.grossingupmarginamount + _BasisCalcLatest.grossingupbaseamount )                   as c_TotalInGlobalAmountH,
      @Semantics.amount.currencyCode : 'g_CodeCurrency'
      ( _BasisCalcLatest.amountinglobalcurrency_l + _BasisCalcLatest.markupamount + _BasisCalcLatest.grossingupmarginamount + _BasisCalcLatest.grossingupbaseamount )                   as c_TotalInGlobalAmountL,
      _BasisCalcLatest.globalcurrency                                                                                                                                                   as g_CodeCurrency,
      @Semantics.amount.currencyCode : 'c_CodeCurrency'
      _BasisCalcLatest.markupamntinlocal,
      @Semantics.amount.currencyCode : 'c_CodeCurrency'
      _BasisCalcLatest.grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'c_CodeCurrency'
      _BasisCalcLatest.grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'c_CodeCurrency'
      _BasisCalcLatest.latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'c_CodeCurrency'
      _BasisCalcLatest.providergrossingupamntinlocal,
      @Semantics.amount.currencyCode : 'c_CodeCurrency'
      ( _BasisCalcLatest.amountincompanycodecurrency + _BasisCalcLatest.markupamntinlocal + _BasisCalcLatest.grossingupmarginamntinlocal + _BasisCalcLatest.grossingupbaseamntinlocal ) as c_TotalInCompanyCodeAmount,
      _BasisCalcLatest.companycodecurrency                                                                                                                                              as c_CodeCurrency,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then $projection.markupamount
      else $projection.markupamntinlocal
      end                                                                                                                                                                               as MKUPAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then $projection.grossingupmarginamount
      else $projection.grossingupmarginamntinlocal
      end                                                                                                                                                                               as GUpMAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then $projection.grossingupbaseamount
      else $projection.grossingupbaseamntinlocal
      end                                                                                                                                                                               as GUpBAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then $projection.latepaymentinterestamount
      else $projection.latepaymentinterestamntinlocal
      end                                                                                                                                                                               as INTMAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then $projection.providergrossingupamount
      else $projection.providergrossingupamntinlocal
      end                                                                                                                                                                               as GUpPAmntInTCurr,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      case
      when $projection.providercountry <> $projection.RecipientCountry then $projection.c_TotalInGlobalAmount
      else $projection.c_TotalInCompanyCodeAmount
      end                                                                                                                                                                               as TotalInTCurrAmount,
      _BasisCalcLatest.BasisCreatedAt                                                                                                                                                   as BasisCreatedAt,
      _BasisCalcLatest.BasisCreatedBy                                                                                                                                                   as BasisCreatedBy,
      _BasisCalcLatest.CalcCreatedAt                                                                                                                                                    as CalcCreatedAt,
      _BasisCalcLatest.CalcCreatedBy                                                                                                                                                    as CalcCreatedBy,
      /* Se agrega campo calculado para determinar semaforo de status de los documentos */
      _DocCriticality.StatusCriticality                                                                                                                                                 as StatusCriticality,
      case _DocCriticality.StatusCriticality
      when 1 then 'E' // Si la criticidad es 1 (Error) el status es 'E'
      when 3 then 'C' // Si la criticidad es 3 (Creado) el status es 'C'
      else 'W'  // Si la criticidad es 2 (Advertencia) el status es 'W'
      end                                                                                                                                                                               as Status,
      /* 05/15: mostrar los campos de metricas y tarifas a nivel de Items */
      /* Adicionales */
      //      _CompanyRelProduct.Flow,
      _Proposal.Plant                                                                                                                                                                   as ProviderPlant,
      _Proposal.ChartOfAccounts,
      _Proposal.ProviderCountry,
      _RecipientCompanyCode.SiteCode,
      _RecipientCompanyCode.InternalCode,
      _CompanyCodeLogistic.Plant,
      _CompanyCodeLogistic.SalesOrganization,
      _CompanyCodeLogistic.PurchasingOrganization,
      //      _Relationship.RecipientCustomer,
      //      _Relationship.RecipientVendor,
      /* Associations */
      _Proposal,
      _RecipientCompanyCode,
      _ProfitCenter,
      _ProfitCenterEQ,
      _ProposalItemsDetails,
      _ProposalItemsBasis,
      _ProposalItemsCalc,
      _ProposalItemsDoc,
      _BasisCalcLatest,
      _Relationship
      //      _ItemsBasis,
      //      _ItemsCalc,
      //      _CurrentProposalItemBasis,
      //      _CurrentProposalItemCalc


}
