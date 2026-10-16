@AccessControl.authorizationCheck: #NOT_ALLOWED

@EndUserText.label: 'Intercompany journal Entry Class'
@ObjectModel: { representativeKey: 'LedgerGLLineItem',
                usageType.sizeCategory: #XXL,
                usageType.dataClass:  #TRANSACTIONAL }
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_INTERCO_JEITEM_CLASS'
define root view entity ZC_INTERCOJEITEMCLASS
  with parameters
    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_intercoCompanyCodeVH', element: 'CompanyCode' } } ]
    P_CompanyCode  : zint_dte_bukrs,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'zi_ledger_sh', element: 'Rldnr' } } ]
    P_Ledger       : fins_ledger,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_FISCALYEAR1', element: 'FiscalYear' },
                                          distinctValues: true } ]
    P_FiscalYear   : fis_gjahr_no_conv,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'zc_poper_vh', element: 'Poper' },
                                          additionalBinding: [ { element: 'FiscalYear',
                                                                 localParameter: 'P_FiscalYear',
                                                                 usage: #FILTER_AND_RESULT } ] } ]

    P_FiscalPeriod : fins_fiscalperiod,

    @Consumption.valueHelpDefinition: [ { entity: { name: 'zi_read_dom_paymenttype', element: 'value' },
                                          distinctValues: true } ]

    P_PaymentType  : zint_dte_paymenttype,
    @Environment.systemField:#SYSTEM_DATE
    P_CreatedOn    : fdt_sydatum,
    @Environment.systemField:#SYSTEM_TIME
    P_CreatedAt    : syuzeit,
    P_BGProcessing : zint_bgprocessing
  as select from ZR_IntercoJEItemClassV2
  association [1..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T  as _IsBillableText on  _IsBillableText.domain_name = 'ZINT_BILLABLE_STATUS'
                                                                          and _IsBillableText.value_low   = $projection.IsBillable
                                                                          and _IsBillableText.language    = $session.system_language
  association [0..1] to ZI_INTERCOFEATURETOGGLEEnabled as _FeatureToggle  on  1 = 1
  association [0..1] to Z_I_CAMPANA_API                as _Campana        on  _Campana.ChildSetID = $projection.CostCenterStandardHierArea
{
  key SourceLedger,
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
  key AccountingDocument,
  key LedgerGLLineItem,
  key Ledger,

      GLAccount,
      ChartOfAccounts,
      Segment,
      AccountingDocumentType,
      AccountingDocumentItem,
      PostingDate,
      DebitCreditCode,
      AccountingDocumentCategory,
      LedgerFiscalYear,
      CreationDateTime,
      ClearingAccountingDocument,
      ClearingJournalEntry,
      ControllingArea,
      ClearingDate,
      ClearingDocFiscalYear,
      ClearingJournalEntryFiscalYear,
      IsOpenItemManaged,
      TransactionCurrency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      AmountInTransactionCurrency,

      CompanyCodeCurrency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      AmountInCompanyCodeCurrency,

      GlobalCurrency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      AmountInGlobalCurrency,

      CostCenter,
      ProfitCenter,
      CreationDate,
      FiscalYearPeriod,
      PaymentType,

      @ObjectModel.text.element: [ 'PandLL0Name' ]
      @UI.textArrangement: #TEXT_LAST
      PandLL0Id,
      PandLL0Name,

      @UI.textArrangement: #TEXT_LAST
      PandLL1Id,
      PandLL1Name,

      @ObjectModel.text.element: [ 'PandLL2Name' ]
      @UI.textArrangement: #TEXT_LAST
      PandLL2Id,
      PandLL2Name,

      @ObjectModel.text.element: [ 'PandLL3Name' ]
      @UI.textArrangement: #TEXT_LAST
      PandLL3Id,
      PandLL3Name,

      @ObjectModel.text.element: [ 'PandLL4Name' ]
      @UI.textArrangement: #TEXT_LAST
      PandLL4Id,
      PandLL4Name,

      @ObjectModel.text.element: [ 'PandLL5Name' ]
      @UI.textArrangement: #TEXT_LAST
      PandLL5Id,
      PandLL5Name,

      CostCenterStandardHierArea,
      @EndUserText.label: 'Campana'
      _Campana.SetID                                              as Campana,
      @EndUserText.label: 'AREA'
      _Campana.CampanaDescripcion                                 as AREA,

      CCAllocation,
      CCConsolidation,
      PCConsolidation,
      @ObjectModel.text.element: [ 'DepartmentName' ]
      @UI.textArrangement: #TEXT_LAST
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
      //                _DepartmentRule.Department
                departmentrule_Department
               else
      //                _CurrentBasisItem.Department end as zint_depto )              as Department,
                CurrentBasis_Department end as zint_depto )       as Department,
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
      //                _DepartmentRule._Department.Description
                departmentrule_description
               else
      //                _CurrentBasisItem._Department.Description end as zint_depto ) as DepartmentName,
                CurrentBasis_DepartmentDescr end as zint_depto )  as DepartmentName,
      /**
      * Classification Rule
      **/
      @ObjectModel.text.element: ['RuleName']
      ClassificationRuleExtID                                     as RuleID,
      RuleName,
      IsNotBillableFromMasterData,

      @ObjectModel.text.element: [ 'ConceptName' ]
      @UI.textArrangement: #TEXT_LAST
      Concept,
      ConceptName,

      /**
      * Exemption Rule
      **/
      ClassificationExemptionID,
      ClassificationExemptionExtID,
      IsNotBillableFromExemption,


      @Consumption.valueHelpDefinition: [{
      entity: { name: 'ZI_DomainFixedValueVH', element: 'value_low' },
      additionalBinding: [{ element: 'domain_name', localConstant: 'ZINT_BILLABLE_STATUS', usage: #FILTER }],
      distinctValues: true
      }]
      @ObjectModel.text.element: [ 'IsBillableText' ]
      IsBillable,
      _IsBillableText(p_domain_name: 'ZINT_BILLABLE_STATUS').text as IsBillableText,
      @ObjectModel.filter.enabled: false
      IsBillableCriticality,

      /**
      * Basis
      **/
      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: ['DescriptionBase']
      @Semantics.uuid: true
      cast (IdBase as zint_basisid )                              as IdBase,
      DescriptionBase,
      IsReleased,
      cast (
      //        case when IsBillable = 'B' and FiscalPeriod = $parameters.P_FiscalPeriod and ( _CurrentBasisItem._header.CompanyCode is initial or _CurrentBasisItem._header.CompanyCode is null ) then 'X'
        case when IsBillable = 'B' and FiscalPeriod = $parameters.P_FiscalPeriod and ( CurrentBasis_CompanyCode is initial or CurrentBasis_DepartmentDescr is null ) then 'X'
        else '' end as zint_isdelta  )                            as IsDelta,

      // temp INDEX ->
      @UI.lineItem: [ { label: 'SAP Entity' } ]
      @ObjectModel.filter.enabled: false
      IndexCompanyCode,
      @UI.lineItem: [ { label: 'Allocation' } ]
      @ObjectModel.filter.enabled: false
      IndexAllocation,
      @UI.lineItem: [ { label: 'Consolidation' } ]
      @ObjectModel.filter.enabled: false
      IndexConsolidation,
      @UI.lineItem: [ { label: 'AREA 2' } ]
      @ObjectModel.filter.enabled: false
      IndexArea                                                   as AREA_2,
      @UI.lineItem: [ { label: 'Business Unit' } ]
      @ObjectModel.filter.enabled: false
      IndexBusinessUnit,
      @UI.lineItem: [ { label: 'PYL 0' } ]
      @ObjectModel.filter.enabled: false
      IndexPYL0,
      @UI.lineItem: [ { label: 'PYL 1' } ]
      @ObjectModel.filter.enabled: false
      IndexPYL1,
      @UI.lineItem: [ { label: 'PYL CLASIFICADO' } ]
      @ObjectModel.filter.enabled: false
      IndexPYLCLASIFICADO,
      @UI.lineItem: [ { label: 'Cost Center' } ]
      @ObjectModel.filter.enabled: false
      IndexCostCenter,
      @UI.lineItem: [ { label: 'Account Nro' } ]
      @ObjectModel.filter.enabled: false
      IndexAccountNro,
      @UI.lineItem: [ { label: 'Month' } ]
      @ObjectModel.filter.enabled: false
      IndexMonth,
      @Aggregation.default: #SUM
      @UI.lineItem: [ { label: 'Total' } ]
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      @ObjectModel.filter.enabled: false
      IndexTotal,
      @UI.lineItem: [ { label: 'Facturación' } ]
      @ObjectModel.filter.enabled: false
      IndexFacturacion
      // temp INDEX <-
      //      _Basis,
      //      _BasisTP
}
where
                CompanyCode                  = $parameters.P_CompanyCode
  and           Ledger                       = $parameters.P_Ledger
  and           SourceLedger                 = $parameters.P_Ledger
  and           FiscalYear                   = $parameters.P_FiscalYear
  and(
    (
                FiscalPeriod                 = $parameters.P_FiscalPeriod
    )
    // Base Acumulada ->
    or(
      (
                FiscalPeriod                 < $parameters.P_FiscalPeriod
        // BUG FIX: Se separaron los casos de año posterior y año igual al Validfrom,
        // para evitar que el filtro de periodo se aplique incorrectamente en años siguientes.
        // and   FiscalPeriod             >= concat('0',substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 5,2))
        // and   FiscalYear               >= substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 1,4)
        and(
          (
                FiscalYear                   >  substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 1,4)
          )
          or(
                FiscalYear                   =  substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 1,4)
            and FiscalPeriod                 >= concat('0',substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 5,2))
          )
        )
      )
      and(
                CurrentBasis_CompanyCode     is initial
        or      CurrentBasis_CompanyCode     is null
        or(
                CurrentBasis_CompanyCode     = $parameters.P_CompanyCode
          and   CurrentBasis_Ledger          = $parameters.P_Ledger
          and   CurrentBasis_FiscalYear      = $parameters.P_FiscalYear
          and   CurrentBasis_FiscalPeriod    = $parameters.P_FiscalPeriod
          and   CurrentBasis_PaymentType     = $parameters.P_PaymentType
        )
      )
      and       IsNotBillableFromMasterData  is initial
      and(
                ClassificationExemptionExtID is null
        or      ClassificationExemptionExtID is initial
      )
    )
    // Base Acumulada <-
  )
  -- Ini Facturación Local CH/ARG EXT_OSCUGALD 07.10.2026 - C12n (7b): consumo por tipo resuelto E/L
  -- Filtro anterior por origen conservado como histórico.
  -- and(
  --   (
  --               $parameters.P_PaymentType    =  'E'
  --     and       OriginObjectType             =  '02'
  --   )
  --   or(
  --               $parameters.P_PaymentType    =  'I'
  --     and(
  --               OriginObjectType             =  '01'
  --       or      OriginObjectType             =  '45'
  --     )
  --   )
  -- )

  -- E/L se filtran por el resultado de clasificación; se conserva la ruta histórica I.
  and(
    (
      (
                $parameters.P_PaymentType    =  'E'
        or      $parameters.P_PaymentType    =  'L'
      )
      and       OriginObjectType             =  '02'
      and       PaymentType                  = $parameters.P_PaymentType
    )
    or(
                $parameters.P_PaymentType    =  'I'
      and(
                OriginObjectType             =  '01'
        or      OriginObjectType             =  '45'
      )
    )
  )
-- Fin EXT_OSCUGALD 07.10.2026 - C12n (7b)
