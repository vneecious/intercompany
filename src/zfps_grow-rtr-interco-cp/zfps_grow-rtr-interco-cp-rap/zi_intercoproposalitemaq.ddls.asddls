@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Calculation Proposal Item'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
@ObjectModel: { representativeKey: 'Item_Id',
                usageType.sizeCategory: #XXL,
                usageType.dataClass:  #MIXED }
define root view entity ZI_INTERCOPROPOSALITEMAQ
  as select from zfi_a_intrc_cpi
  association of exact one to one ZI_IntercoProposal             as _I_Proposal           on  $projection.Id = _I_Proposal.Id
  association of exact one to one ZC_IntercoProposalTP           as _Proposal             on  $projection.Id = _Proposal.Id
  association of exact one to one ZI_IntercoCompanyCode          as _RecipientCompanyCode on  zfi_a_intrc_cpi.recipientcompanycode = _RecipientCompanyCode.CompanyCode
  association of exact one to one ZI_IntercoProfitCenter_SH      as _ProfitCenter         on  $projection.profitcenter = _ProfitCenter.ProfitCenter
  association of exact one to many ZC_IntercoProposalItemBasisTP as _ProposalItemsBasis   on  $projection.Id      = _ProposalItemsBasis.id
                                                                                          and $projection.Item_Id = _ProposalItemsBasis.item_id
  association of exact one to many ZC_IntercoProposalItemCalcTP  as _ProposalItemsCalc    on  $projection.Id      = _ProposalItemsCalc.id
                                                                                          and $projection.Item_Id = _ProposalItemsCalc.item_id
  association of exact one to many ZI_IntercoProposalItemDoc     as _ProposalItemsDoc     on  $projection.Id      = _ProposalItemsDoc.id
                                                                                          and $projection.Item_Id = _ProposalItemsDoc.item_id
  association of exact one to one ZI_IntercoProposalBCLatest     as _BasisCalcLatest      on  zfi_a_intrc_cpi.id      = _BasisCalcLatest.Id
                                                                                          and zfi_a_intrc_cpi.item_id = _BasisCalcLatest.Item_Id
  association of exact one to many ZI_INTRC_IBaOGLAcc3           as _BaOGLAcc             on  $projection.Id           = _BaOGLAcc.id
                                                                                          and $projection.Item_Id      = _BaOGLAcc.item_id
                                                                                          and $projection.ItemBasis_Id = _BaOGLAcc.itembasis_id
  //adicionales
  association of exact one to one ZR_IntercoCompanyCodeLogistics as _CompanyCodeLogistic  on  $projection.recipientcompanycode = _CompanyCodeLogistic.CompanyCode
  // Asociacion a la vista que calcula el semaforo
  association              to ZI_IntercoDocCriticality           as _DocCriticality       on  $projection.Id      = _DocCriticality.id
                                                                                          and $projection.Item_Id = _DocCriticality.item_id

  // Asociación que lee los datos que tu ABAP está actualizando
  //composition of exact one to many ZI_IntercoProposalItemBasis as _ItemBasis

{
      @Semantics.uuid: true
  key id                                                                                                                                                            as Id,
  key item_id                                                                                                                                                       as Item_Id,
      _BasisCalcLatest.Itembasis_Id                                                                                                                                 as ItemBasis_Id,
      _BasisCalcLatest.Itemcalc_Id                                                                                                                                  as ItemCalc_Id,
      @ObjectModel.text.element:  [ 'ProviderCompanyName' ]
      _I_Proposal.ProviderCompanyCode                                                                                                                               as ProviderCompanyCode,
      _I_Proposal._ProviderCompanyCode.CompanyCodeName                                                                                                              as ProviderCompanyName,
      @ObjectModel.text.element:  [ 'RecipientCompanyName' ]
      recipientcompanycode,
      _RecipientCompanyCode.CompanyCodeName                                                                                                                         as RecipientCompanyName,
      _RecipientCompanyCode.Country                                                                                                                                 as RecipientCountry,
      @ObjectModel.text.element:  [ 'ProfitCenterName' ]
      profitcenter,
      _ProfitCenter.ProfitCenterName                                                                                                                                as ProfitCenterName,
      interdivisional                                                                                                                                               as Interdivisional,

      basecurrencyprofitcenter                                                                                                                                      as BaseCurrencyProfitCenter,
      //      Total importe base + hispano
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter                                                                                                                                        as BaseAmountProfitCenter,
      //      Importe Base
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter_c                                                                                                                                      as BaseAmountProfitCenterC,
      //      Importe Base Hispano
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter_h                                                                                                                                      as BaseAmountProfitCenterH,
      //      Importe Base Local
      @Semantics.amount.currencyCode : 'BaseCurrencyProfitCenter'
      baseamountprofitcenter_l                                                                                                                                      as BaseAmountProfitCenterL,
      @ObjectModel.text.element:  [ 'ProductName' ]
      _I_Proposal.Product                                                                                                                                           as Product,
      _I_Proposal.ProductName                                                                                                                                       as ProductName,
      _I_Proposal.GlobalCurrency                                                                                                                                    as GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _I_Proposal.AmountInGlobalCurrency                                                                                                                            as AmountInGlobalCurr,
      cast( '%' as abap.unit( 3 ) )                                                                                                                                 as SharedRateUnit,
      /* 05/15: mostrar los campos de metricas y tarifas a nivel de Items */
      _BasisCalcLatest.metric_id,
      //      @Aggregation.default: #SUM
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.sharedrate,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.sharedrate_h                                                                                                                                 as SharedRateH,
      @Semantics.quantity.unitOfMeasure: 'SharedRateUnit'
      _BasisCalcLatest.sharedrate_l                                                                                                                                 as SharedRateL,
      //      case
      //        when $projection.providercountry = $projection.RecipientCountry then _BasisCalcLatest.exchangerate
      //        else abap.dec'0.00'
      //      end                                                                                                                                                           as ExchangeRate,
      _BasisCalcLatest.exchangerate                                                                                                                                 as ExchangeRate,
      @Semantics.amount.currencyCode : 'globalcurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.amountinglobalcurrency                                                                                                                       as b_amountinglobalcurrency,
      @Semantics.amount.currencyCode : 'globalcurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.amountinglobalcurrency_c                                                                                                                     as b_amountinglobalcurrencyC,
      @Semantics.amount.currencyCode : 'globalcurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.amountinglobalcurrency_h                                                                                                                     as b_amountinglobalcurrencyH,
      @Semantics.amount.currencyCode : 'globalcurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.amountinglobalcurrency_l                                                                                                                     as b_amountinglobalcurrencyL,
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.cuky''
      else _BasisCalcLatest.companycodecurrency
      end                                                                                                                                                           as companycodecurrency,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry = $projection.RecipientCountry then _BasisCalcLatest.amountincompanycodecurrency
      else abap.curr'0.00'
      end                                                                                                                                                           as b_amountincompanycodecurrency,
      case
      when $projection.providercountry <> $projection.RecipientCountry then _I_Proposal.GlobalCurrency
      else _BasisCalcLatest.companycodecurrency
      end                                                                                                                                                           as transactioncurrency,
      @Semantics.amount.currencyCode : 'transactioncurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then _BasisCalcLatest.amountinglobalcurrency
      else _BasisCalcLatest.amountincompanycodecurrency
      end                                                                                                                                                           as amountintrasactioncurrency,
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
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.markupamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.grossingupmarginamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.grossingupbaseamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.latepaymentinterestamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      _BasisCalcLatest.providergrossingupamount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      ( _BasisCalcLatest.amountinglobalcurrency + _BasisCalcLatest.markupamount + _BasisCalcLatest.grossingupmarginamount + _BasisCalcLatest.grossingupbaseamount ) as c_TotalInGlobalAmount,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      cast(
        (
        cast ( _BasisCalcLatest.amountinglobalcurrency_c as abap.dec( 23, 2 ))
        + ( cast( _BasisCalcLatest.amountinglobalcurrency_c as abap.dec( 23, 2 )) * ( _BasisCalcLatest.markup / 100 ) )
        + (( cast( _BasisCalcLatest.amountinglobalcurrency_c as abap.dec( 23, 2 ))
            / ( 1 - ( _BasisCalcLatest.grossingupbase / 100 )))
          - cast( _BasisCalcLatest.amountinglobalcurrency_c as abap.dec( 23, 2 )))
        + ((( cast( _BasisCalcLatest.amountinglobalcurrency_c as abap.dec( 23, 2 )) * ( _BasisCalcLatest.markup / 100 ))
            / ( 1 - ( _BasisCalcLatest.grossingupmargin / 100 )))
          - ( cast( _BasisCalcLatest.amountinglobalcurrency_c as abap.dec( 23, 2 ) ) * ( _BasisCalcLatest.markup / 100 )))
         )
         as abap.curr( 23, 2 )
      )                                                                                                                                                             as c_TotalInGlobalAmountC,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      cast(
        (
        cast ( _BasisCalcLatest.amountinglobalcurrency_h as abap.dec( 23, 2 ))
        + ( cast( _BasisCalcLatest.amountinglobalcurrency_h as abap.dec( 23, 2 )) * ( _BasisCalcLatest.markup / 100 ) )
        + (( cast( _BasisCalcLatest.amountinglobalcurrency_h as abap.dec( 23, 2 ))
            / ( 1 - ( _BasisCalcLatest.grossingupbase / 100 )))
          - cast( _BasisCalcLatest.amountinglobalcurrency_h as abap.dec( 23, 2 )))
        + ((( cast( _BasisCalcLatest.amountinglobalcurrency_h as abap.dec( 23, 2 )) * ( _BasisCalcLatest.markup / 100 ))
            / ( 1 - ( _BasisCalcLatest.grossingupmargin / 100 )))
          - ( cast( _BasisCalcLatest.amountinglobalcurrency_h as abap.dec( 23, 2 ) ) * ( _BasisCalcLatest.markup / 100 )))
        )
        as abap.curr( 23, 2 )
      )                                                                                                                                                             as c_TotalInGlobalAmountH,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      @Aggregation.default: #SUM
      cast(
         (
              cast ( _BasisCalcLatest.amountinglobalcurrency_l as abap.dec( 23, 2 ))
              + ( cast( _BasisCalcLatest.amountinglobalcurrency_l as abap.dec( 23, 2 )) * ( _BasisCalcLatest.markup / 100 ) )
              + (( cast( _BasisCalcLatest.amountinglobalcurrency_l as abap.dec( 23, 2 ))
                  / ( 1 - ( _BasisCalcLatest.grossingupbase / 100 )))
                - cast( _BasisCalcLatest.amountinglobalcurrency_l as abap.dec( 23, 2 )))
              + ((( cast( _BasisCalcLatest.amountinglobalcurrency_l as abap.dec( 23, 2 )) * ( _BasisCalcLatest.markup / 100 ))
                  / ( 1 - ( _BasisCalcLatest.grossingupmargin / 100 )))
                - ( cast( _BasisCalcLatest.amountinglobalcurrency_l as abap.dec( 23, 2 ) ) * ( _BasisCalcLatest.markup / 100 )))
          )
          as abap.curr( 23, 2 )
            )                                                                                                                                                       as c_TotalInGlobalAmountL,
      //      _BasisCalcLatest.globalcurrency as g_CodeCurrency,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.curr'0.00'
      else _BasisCalcLatest.markupamntinlocal
      end                                                                                                                                                           as markupamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.curr'0.00'
      else _BasisCalcLatest.grossingupmarginamntinlocal
      end                                                                                                                                                           as grossingupmarginamntinlocal,
      //      _BasisCalcLatest.grossingupmarginamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.curr'0.00'
      else _BasisCalcLatest.grossingupbaseamntinlocal
      end                                                                                                                                                           as grossingupbaseamntinlocal,
      //      _BasisCalcLatest.grossingupbaseamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.curr'0.00'
      else _BasisCalcLatest.latepaymentinterestamntinlocal
      end                                                                                                                                                           as latepaymentinterestamntinlocal,
      //      _BasisCalcLatest.latepaymentinterestamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.curr'0.00'
      else _BasisCalcLatest.providergrossingupamntinlocal
      end                                                                                                                                                           as providergrossingupamntinlocal,
      //      _BasisCalcLatest.providergrossingupamntinlocal,
      @Semantics.amount.currencyCode : 'companycodecurrency'
      @Aggregation.default: #SUM
      case
      when $projection.providercountry <> $projection.RecipientCountry then abap.curr'0.00'
      else ( _BasisCalcLatest.amountincompanycodecurrency + _BasisCalcLatest.markupamntinlocal + _BasisCalcLatest.grossingupmarginamntinlocal + _BasisCalcLatest.grossingupbaseamntinlocal )
      end                                                                                                                                                           as c_TotalInCompanyCodeAmount,
      //      ( _BasisCalcLatest.amountincompanycodecurrency + _BasisCalcLatest.markupamntinlocal + _BasisCalcLatest.grossingupmarginamntinlocal + _BasisCalcLatest.grossingupbaseamntinlocal ) as c_TotalInCompanyCodeAmount,
      //      _BasisCalcLatest.companycodecurrency as c_CodeCurrency,
      _BasisCalcLatest.BasisCreatedAt                                                                                                                               as BasisCreatedAt,
      _BasisCalcLatest.BasisCreatedBy                                                                                                                               as BasisCreatedBy,
      _BasisCalcLatest.CalcCreatedAt                                                                                                                                as CalcCreatedAt,
      _BasisCalcLatest.CalcCreatedBy                                                                                                                                as CalcCreatedBy,
      //      _ProposalItemsDoc.Status                                                                                                                                      as Status,
      /* Se agrega campo calculado para determinar semaforo de status de los documentos */
      // Proyecta el campo de la vista de ayuda
      _DocCriticality.StatusCriticality                                                                                                                             as StatusCriticality,
      case _DocCriticality.StatusCriticality
      when 1 then 'E' // Si la criticidad es 1 (Error) el status es 'E'
      when 3 then 'C' // Si la criticidad es 3 (Creado) el status es 'C'
      else 'W'  // Si la criticidad es 2 (Advertencia) el status es 'W'
      end                                                                                                                                                           as Status,
      /* 05/15: mostrar los campos de metricas y tarifas a nivel de Items */
      /* Adicionales */
      //      _CompanyRelProduct.Flow,
      _I_Proposal.Plant                                                                                                                                             as ProviderPlant,
      _I_Proposal.ChartOfAccounts,
      _I_Proposal.ProviderCountry,
      _RecipientCompanyCode.SiteCode,
      _RecipientCompanyCode.InternalCode,
      _CompanyCodeLogistic.Plant,
      _CompanyCodeLogistic.SalesOrganization,
      _CompanyCodeLogistic.PurchasingOrganization,
      //      _Relationship.RecipientCustomer,
      //      _Relationship.RecipientVendor,
      /* Associations */
      _I_Proposal,
      _Proposal,
      _RecipientCompanyCode,
      _ProfitCenter,
      _ProposalItemsBasis,
      _ProposalItemsCalc,
      _ProposalItemsDoc,
      _BasisCalcLatest,
      _BaOGLAcc
      //      _ItemsBasis,
      //      _ItemsCalc,
      //      _CurrentProposalItemBasis,
      //      _CurrentProposalItemCalc

}
