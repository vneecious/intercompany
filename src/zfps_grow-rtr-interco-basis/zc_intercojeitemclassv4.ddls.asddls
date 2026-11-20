/*
 * ZC_INTERCOJEITEMCLASSV4 - Clasificacion de JE Items (IC05).
 * Version optimizada de ZC_INTERCOJEITEMCLASSV3, con el mismo resultado.
 *
 * Para la sociedad / ledger / ejercicio / periodo / tipo de pago informados, devuelve:
 *   1) Periodo actual: todos los items de P_FiscalPeriod (B, N, E y '-').
 *   2) Base Acumulada: items de periodos anteriores del mismo ejercicio que todavia deben
 *      facturarse en el periodo actual (regla facturable, sin exencion y sin base de otro periodo).
 *
 * Estructura: UNION ALL de tres ramas disjuntas (por FiscalPeriod y por origen):
 *   - Rama 1: periodo actual, gastos (origen 02). ZR_IntercoJEItemClassV3.
 *   - Rama 2: periodo actual, ingresos (origen 01/45, ej. CMC). ZI_IntercoJEItemClassAccV4,
 *     conducida por ZINT_A_JEITEM_CI: solo los ingresos clasificados (los demas tienen
 *     PaymentType vacio y no se muestran), sin recorrer los millones de ingresos sin regla.
 *     Solo se ejecuta con P_WithRevenue = 'X' (feature REVENUE_LINES vigente para la sociedad
 *     y el periodo). El consumidor pasa el valor como literal: con '' HANA descarta la rama.
 *   - Rama 3: Base Acumulada, periodos anteriores. ZI_IntercoJEItemClassAccV4. Gastos (origen 02)
 *     siempre; ingresos (origen 01/45) solo con P_WithRevenue = 'X', igual que la rama 2.
 *
 * Rendimiento en TS4 (EBA / L1 / 2026 / 007, ~21,4 M items, misma ventana de ejecucion):
 *   V3 4 min 39 s -> V4 2 min 56 s. La Base Acumulada se resuelve en ~3 s.
 *
 * Mantenimiento:
 *   - Las dos ramas deben tener la misma lista de campos, en el mismo orden y con las mismas expresiones.
 *   - Las anotaciones de elementos se declaran solo en la rama 1.
 *   - Cualquier cambio de logica en ZR_IntercoJEItemClassV3 debe replicarse en ZI_IntercoJEItemClassAccV4.
 */
@AccessControl.authorizationCheck: #NOT_ALLOWED

@EndUserText.label: 'Interco JE Item Clasif V4 (tuning)'
@ObjectModel: { representativeKey: 'LedgerGLLineItem',
                usageType.sizeCategory: #XXL,
                usageType.dataClass:  #TRANSACTIONAL }
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZC_INTERCOJEITEMCLASSV4
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

    // 'X' = incluir rama 2 (ingresos). Lo decide el consumidor con la feature REVENUE_LINES
    // (respeta Validfrom) y lo pasa como LITERAL para que HANA elimine la rama del plan.
    P_WithRevenue  : abap_boolean,

    @Environment.systemField:#SYSTEM_DATE
    P_CreatedOn    : fdt_sydatum,

    @Environment.systemField:#SYSTEM_TIME
    P_CreatedAt    : syuzeit

  as select from ZR_IntercoJEItemClassV3
  association [1..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _IsBillableText on  _IsBillableText.domain_name = 'ZINT_BILLABLE_STATUS'
                                                                         and _IsBillableText.value_low   = $projection.IsBillable
                                                                         and _IsBillableText.language    = $session.system_language
  association [0..1] to Z_I_CAMPANA_API               as _Campana        on  _Campana.ChildSetID = $projection.CostCenterStandardHierArea
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
                departmentrule_Department
               else
                CurrentBasis_Department end as zint_depto )       as Department,
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
                departmentrule_description
               else
                CurrentBasis_DepartmentDescr end as zint_depto )  as DepartmentName,

      @ObjectModel.text.element: ['RuleName']
      ClassificationRuleExtID                                     as RuleID,
      RuleName,
      IsNotBillableFromMasterData,

      @ObjectModel.text.element: [ 'ConceptName' ]
      @UI.textArrangement: #TEXT_LAST
      Concept,
      ConceptName,

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

      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: ['DescriptionBase']
      @Semantics.uuid: true
      cast (IdBase as zint_basisid )                              as IdBase,
      DescriptionBase,
      IsReleased,
      cast (
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
}
// Rama 1 - Periodo actual, gastos (origen 02): todos los items de P_FiscalPeriod, cualquiera sea su clasificacion.
where
      CompanyCode      = $parameters.P_CompanyCode
  and Ledger           = $parameters.P_Ledger
  and SourceLedger     = $parameters.P_Ledger
  and FiscalYear       = $parameters.P_FiscalYear
  and FiscalPeriod     = $parameters.P_FiscalPeriod
  and OriginObjectType = '02'
  and PaymentType      = $parameters.P_PaymentType

union all

// Rama 2 - Periodo actual, ingresos (origen 01/45, ej. CMC): solo items clasificados por el motor.
// Sin clasificacion su PaymentType queda vacio y nunca coincide con P_PaymentType, por eso se
// leen desde ZINT_A_JEITEM_CI y no pasan por la rama 1 (volumen alto de items sin regla).
select from ZI_IntercoJEItemClassAccV4
association [1..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _IsBillableText on  _IsBillableText.domain_name = 'ZINT_BILLABLE_STATUS'
                                                                       and _IsBillableText.value_low   = $projection.IsBillable
                                                                       and _IsBillableText.language    = $session.system_language
association [0..1] to Z_I_CAMPANA_API               as _Campana        on  _Campana.ChildSetID = $projection.CostCenterStandardHierArea
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

      AmountInTransactionCurrency,

      CompanyCodeCurrency,

      AmountInCompanyCodeCurrency,

      GlobalCurrency,

      AmountInGlobalCurrency,

      CostCenter,
      ProfitCenter,
      CreationDate,
      FiscalYearPeriod,
      PaymentType,

      PandLL0Id,
      PandLL0Name,

      PandLL1Id,
      PandLL1Name,

      PandLL2Id,
      PandLL2Name,

      PandLL3Id,
      PandLL3Name,

      PandLL4Id,
      PandLL4Name,

      PandLL5Id,
      PandLL5Name,

      CostCenterStandardHierArea,
      _Campana.SetID                                              as Campana,
      _Campana.CampanaDescripcion                                 as AREA,

      CCAllocation,
      CCConsolidation,
      PCConsolidation,
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
                departmentrule_Department
               else
                CurrentBasis_Department end as zint_depto )       as Department,
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
                departmentrule_description
               else
                CurrentBasis_DepartmentDescr end as zint_depto )  as DepartmentName,

      ClassificationRuleExtID                                     as RuleID,
      RuleName,
      IsNotBillableFromMasterData,

      Concept,
      ConceptName,

      ClassificationExemptionID,
      ClassificationExemptionExtID,
      IsNotBillableFromExemption,
      IsBillable,
      _IsBillableText(p_domain_name: 'ZINT_BILLABLE_STATUS').text as IsBillableText,
      IsBillableCriticality,

      cast (IdBase as zint_basisid )                              as IdBase,
      DescriptionBase,
      IsReleased,
      cast (
        case when IsBillable = 'B' and FiscalPeriod = $parameters.P_FiscalPeriod and ( CurrentBasis_CompanyCode is initial or CurrentBasis_DepartmentDescr is null ) then 'X'
        else '' end as zint_isdelta  )                            as IsDelta,

      IndexCompanyCode,
      IndexAllocation,
      IndexConsolidation,
      IndexArea                                                   as AREA_2,
      IndexBusinessUnit,
      IndexPYL0,
      IndexPYL1,
      IndexPYLCLASIFICADO,
      IndexCostCenter,
      IndexAccountNro,
      IndexMonth,
      IndexTotal,
      IndexFacturacion
}
where
      CompanyCode      =  $parameters.P_CompanyCode
  and Ledger           =  $parameters.P_Ledger
  and SourceLedger     =  $parameters.P_Ledger
  and FiscalYear       =  $parameters.P_FiscalYear
  and FiscalPeriod     =  $parameters.P_FiscalPeriod
  and OriginObjectType <> '02'
  and PaymentType      =  $parameters.P_PaymentType
  // Solo sociedades con feature REVENUE_LINES vigente para el periodo (decidido por el consumidor)
  and $parameters.P_WithRevenue = 'X'

union all

// Rama 3 - Base Acumulada: items de periodos anteriores pendientes de facturar
// (ingresos origen 01/45 solo con P_WithRevenue = 'X').
// ZI_IntercoJEItemClassAccV4 ya excluye los items sin regla (INNER JOIN con ZINT_A_JEITEM_CI).
select from ZI_IntercoJEItemClassAccV4
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

      AmountInTransactionCurrency,

      CompanyCodeCurrency,

      AmountInCompanyCodeCurrency,

      GlobalCurrency,

      AmountInGlobalCurrency,

      CostCenter,
      ProfitCenter,
      CreationDate,
      FiscalYearPeriod,
      PaymentType,

      PandLL0Id,
      PandLL0Name,

      PandLL1Id,
      PandLL1Name,

      PandLL2Id,
      PandLL2Name,

      PandLL3Id,
      PandLL3Name,

      PandLL4Id,
      PandLL4Name,

      PandLL5Id,
      PandLL5Name,

      CostCenterStandardHierArea,
      _Campana.SetID                                              as Campana,
      _Campana.CampanaDescripcion                                 as AREA,

      CCAllocation,
      CCConsolidation,
      PCConsolidation,
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
                departmentrule_Department
               else
                CurrentBasis_Department end as zint_depto )       as Department,
      cast (
              case when DescriptionBase is initial or DescriptionBase is null then
                departmentrule_description
               else
                CurrentBasis_DepartmentDescr end as zint_depto )  as DepartmentName,

      ClassificationRuleExtID                                     as RuleID,
      RuleName,
      IsNotBillableFromMasterData,

      Concept,
      ConceptName,

      ClassificationExemptionID,
      ClassificationExemptionExtID,
      IsNotBillableFromExemption,
      IsBillable,
      _IsBillableText(p_domain_name: 'ZINT_BILLABLE_STATUS').text as IsBillableText,
      IsBillableCriticality,

      cast (IdBase as zint_basisid )                              as IdBase,
      DescriptionBase,
      IsReleased,
      cast (
        case when IsBillable = 'B' and FiscalPeriod = $parameters.P_FiscalPeriod and ( CurrentBasis_CompanyCode is initial or CurrentBasis_DepartmentDescr is null ) then 'X'
        else '' end as zint_isdelta  )                            as IsDelta,

      IndexCompanyCode,
      IndexAllocation,
      IndexConsolidation,
      IndexArea                                                   as AREA_2,
      IndexBusinessUnit,
      IndexPYL0,
      IndexPYL1,
      IndexPYLCLASIFICADO,
      IndexCostCenter,
      IndexAccountNro,
      IndexMonth,
      IndexTotal,
      IndexFacturacion
}
where
          CompanyCode                  = $parameters.P_CompanyCode
  and     Ledger                       = $parameters.P_Ledger
  and     SourceLedger                 = $parameters.P_Ledger
  and     FiscalYear                   = $parameters.P_FiscalYear
  // Solo periodos anteriores del mismo ejercicio
  and     FiscalPeriod                 < $parameters.P_FiscalPeriod
  // Feature toggle ACCRUED_BASE: se acumula desde el mes de activacion (Validfrom = AAAAMMDD).
  //   - Ejercicio posterior al de activacion: todos los periodos anteriores.
  //   - Mismo ejercicio de activacion: solo desde el mes de activacion (periodo = '0' + MM).
  //   - Toggle inexistente o inactivo: Validfrom nulo, la rama no devuelve items.
  and(
    (
          FiscalYear                   >  substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 1,4)
    )
    or(
          FiscalYear                   =  substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 1,4)
      and FiscalPeriod                 >= concat('0',substring(_FeatureToggle(P_CompanyCode: $parameters.P_CompanyCode, P_Feature: 'ACCRUED_BASE' ).Validfrom, 5,2))
    )
  )
  // Item sin base, o incluido en la base del periodo / tipo de pago actual
  and(
          CurrentBasis_CompanyCode     is initial
    or    CurrentBasis_CompanyCode     is null
    or(
          CurrentBasis_CompanyCode     = $parameters.P_CompanyCode
      and CurrentBasis_Ledger          = $parameters.P_Ledger
      and CurrentBasis_FiscalYear      = $parameters.P_FiscalYear
      and CurrentBasis_FiscalPeriod    = $parameters.P_FiscalPeriod
      and CurrentBasis_PaymentType     = $parameters.P_PaymentType
    )
  )
  // Regla facturable (no marcada como no facturable en datos maestros) y sin exencion
  and     IsNotBillableFromMasterData  is initial
  and(
          ClassificationExemptionExtID is null
    or    ClassificationExemptionExtID is initial
  )
  and     PaymentType                  = $parameters.P_PaymentType
  // EXT_VINBARRI 20.11.2026: ingresos (origen 01/45) de periodos anteriores solo con
  // REVENUE_LINES vigente, igual que la rama 2; sin la feature solo gastos (origen 02).
  and(
          OriginObjectType             = '02'
    or    $parameters.P_WithRevenue    = 'X'
  )
