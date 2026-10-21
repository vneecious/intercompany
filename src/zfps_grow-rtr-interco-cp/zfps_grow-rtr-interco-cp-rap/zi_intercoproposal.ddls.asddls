@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Calc. Proposal Header'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
define root view entity ZI_IntercoProposal
  as select from zfi_a_intrc_cph
  association of exact one to one ZI_INTERCOBASIS                as _Basis               on $projection.IntercoBasisId = _Basis.Id
  association of exact one to one ZI_IntercoProduct              as _Product             on $projection.Product = _Product.Product
  association of exact one to one ZI_IntercoCompanyCode          as _ProviderCompanyCode on $projection.ProviderCompanyCode = _ProviderCompanyCode.CompanyCode
  //  association [0..1]       to ZI_IntercoProposalStatus_SH        as _Status              on $projection.Status = _Status.Status
  composition of exact one to many ZI_IntercoProposalItem        as _Items
  association of exact one to many ZI_IntercoProposalItemByCeBe  as _ItemsByProfitCenter on $projection.Id = _ItemsByProfitCenter.Id
  //  association of exact one to many ZI_IntercoProposalItemDoc     as _ProposalDocs        on  $projection.Id = _ProposalDocs.Id
  //  association of exact one to many zi_intercoproposalflow        as _DocFlow             on  $projection.Id = _DocFlow.Id
  association of exact one to many ZI_INTRC_CP_DOC               as _ProposalDocs        on $projection.Id = _ProposalDocs.Id
  //adicionales
  association of exact one to one ZR_IntercoCompanyCodeLogistics as _CompanyCodeLogistic on $projection.ProviderCompanyCode = _CompanyCodeLogistic.CompanyCode
  association of exact one to many ZI_INTERCOPROPOSALITEMAQ      as _ItemsAQ             on $projection.Id = _ItemsAQ.Id
  association of exact one to many ZC_INTERCOPROPOSALITEMAQ      as _ItemsBaOGLAccAQ     on $projection.Id = _ItemsBaOGLAccAQ.Id
  //  association of exact one to many ZC_INTERCOPROPOSALITEMAQ      as _ItemsAQ             on  $projection.Id = _ItemsAQ.Id
  //  association of exact one to many ZI_INTERCOPROPOSALITEMAQ      as _ItemsBaOGLAccAQ     on  $projection.Id = _ItemsBaOGLAccAQ.Id
  //  association [*]          to ZI_IntercoProposalDocCategory      as _DocFlowCategories   on 1 = 1
  association [0..1]       to ZI_IntercoProposalStatus           as _Status              on _Status.Status = $projection.Status
{
      @Semantics.uuid: true
  key id                                                                     as Id,
      @Semantics.calendar.year
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_FISCALYEAR1', element: 'FiscalYear' },
                                          distinctValues: true } ]
      fiscalyear                                                             as FiscalYear,
      @Semantics.calendar.month
      @Consumption.valueHelpDefinition: [ { entity: { name: 'zc_poper_vh', element: 'Poper' },
                                            useForValidation: true,
                                            additionalBinding: [ { element: 'FiscalYear',
                                                                   localElement: 'fiscalyear',
                                                                   usage: #FILTER_AND_RESULT } ]} ]
      fiscalperiod                                                           as FiscalPeriod,
      @Semantics.fiscal.yearPeriod: true
      cast( concat( fiscalyear,fiscalperiod ) as  zint_dte_periodyear )      as Period,
      //      @ObjectModel.text.element:  [ 'ProviderCompanyCodeName' ]
      providercompanycode                                                    as ProviderCompanyCode,
      _ProviderCompanyCode.CompanyCodeName                                   as ProviderCompanyCodeName,
      //      @ObjectModel.text.element:  [ 'ProductName' ]
      product                                                                as Product,
      _Product.ProductName                                                   as ProductName,
      _ProviderCompanyCode.Country                                           as ProviderCountry,
      @Consumption: {
          valueHelpDefinition: [{
              entity: {
                  name: 'ZI_IntercoProposalStatus_SH',
                  element: 'Status'
              }
          }]
      }
      @ObjectModel.text.element:  [ 'StatusName' ]
      status                                                                 as Status,
      _Status.StatusName,
      case status
        when ' '  then 2
        when 'V' then 2
        when 'C' then 2
        when 'I' then 3
        when 'E' then 1
        when 'O' then 1
        when 'F' then 1
        when 'J' then 3
        when 'H' then 1
        when 'G' then 3 // Concluido: verde (estado terminal exitoso) - Bermudas
        else 0
      end                                                                    as StatusCriticality,
      @Semantics.uuid: true
      @ObjectModel.text.element:  [ 'BasisDescription' ]
      intercobasisid                                                         as IntercoBasisId,
      _Basis.Description                                                     as BasisDescription,
      _Basis.Ledger                                                          as Ledger,
      globalcurrency                                                         as GlobalCurrency,
      @Semantics.amount.currencyCode : 'GlobalCurrency'
      amountinglobalcurrency                                                 as AmountInGlobalCurrency,
      // ── NUEVO ──────────────────────────────────────────────────────────────
      companycodecurrency                                                    as CompanyCodeCurrency,
      @Semantics.amount.currencyCode : 'CompanyCodeCurrency'
      amountincompanycodecurrency                                            as AmountInCompanyCodeCurrency,
      // ─────────────────────────────────────────────────────────────────────
      @Semantics.user.createdBy: true
      createdby                                                              as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      createdat                                                              as CreatedAt,
      @Consumption.filter.defaultValue: ''
      isdeleted                                                              as IsDeleted,
      case when isdeleted = 'X' then 1 else 3 end                            as IsDeletedCriticality,
      cast( case when isdeleted = 'X' then '' else 'X' end as abap_boolean ) as IsActive,
      // Datos Adicionales
      _ProviderCompanyCode.ChartOfAccounts,
      _ProviderCompanyCode.SiteCode,
      _ProviderCompanyCode.InternalCode,
      _ProviderCompanyCode.Country,
      _CompanyCodeLogistic.Plant,
      _CompanyCodeLogistic.SalesOrganization,
      _CompanyCodeLogistic.PurchasingOrganization,
      //      _Relationship.ProviderCustomer,
      //      _Relationship.ProviderVendor,
      //      _ProductValuationBasic.ValuationClass,
      //      Associations
      _Items,
      _Basis,
      _Product,
      _ProviderCompanyCode,
      _ProposalDocs,
      //      _DocFlow,
      _ItemsByProfitCenter,
      _ItemsAQ,
      _ItemsBaOGLAccAQ,
      _Status
      //      _ProductValuationBasic
}
