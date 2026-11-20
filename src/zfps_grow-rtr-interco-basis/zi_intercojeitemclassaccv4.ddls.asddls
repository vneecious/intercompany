/*
 * ZI_IntercoJEItemClassAccV4 - Base Acumulada de la clasificacion de JE Items (IC05).
 * Fuente de dos ramas de ZC_INTERCOJEITEMCLASSV4:
 *   - Rama 2: periodo actual, items de ingreso (origen 01/45).
 *   - Rama 3: Base Acumulada (periodos anteriores).
 *
 * Devuelve los mismos campos y expresiones que ZR_IntercoJEItemClassV3, pero solo para los
 * items clasificados por el motor:
 *   - Tabla conductora: ZINT_A_JEITEM_CI (resultado del motor: una fila por combinacion
 *     P&L L5 / Profit Center / Area CeCo / Allocation / Consolidation / periodo -> regla).
 *   - INNER JOIN con ZINT_A_JEITEM_AG (items); LEFT OUTER con ZI_IntercoClassificationRule.
 *   - Los items sin clasificacion no se leen: en ingresos su PaymentType queda vacio y nunca
 *     coincide con P_PaymentType (E/L); en la Base Acumulada no se incluyen.
 *   - CeCo: LEFT OUTER con I_CostCenter; con CeCo informado se exige CeCo vigente.
 *
 * Los JOIN usan las columnas de ZINT_A_JEITEM_AG (ledger, sociedad, ejercicio, periodo,
 * Profit Center, CeCo, cuenta), que tienen los mismos valores que I_JournalEntryItem para
 * cada item. I_JournalEntryItem se une por clave completa solo para los campos de documento,
 * importes, ControllingArea, PostingDate, CreationDateTime y GLAccountType.
 *
 * Mantenimiento: cualquier cambio de logica en ZR_IntercoJEItemClassV3 (campos, JOIN,
 * calculo de IsBillable / Concept / PaymentType) debe replicarse en esta vista.
 */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco JE Item Clasif Base Acum V4'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define view entity ZI_IntercoJEItemClassAccV4
  // Conductora: combinaciones clasificadas con regla (pocas filas por periodo)
  as select from    zint_a_jeitem_ci               as _ci
    // Items de la combinacion (materializacion de los agrupadores P&L)
    inner join      zint_a_jeitem_ag               as _ag                 on  _ag.ledger                     = _ci.ledger
                                                                          and _ag.companycode                = _ci.companycode
                                                                          and _ag.fiscalyear                 = _ci.fiscalyear
                                                                          and _ag.fiscalperiod               = _ci.fiscalperiod
                                                                          and _ag.pandll5id                  = _ci.pandll5id
                                                                          and _ag.ccconsolidation            = _ci.ccconsolidation
                                                                          and _ag.costcenterstandardhierarea = _ci.costcenterstandardhierarea
                                                                          and _ag.ccallocation               = _ci.ccallocation
                                                                          and _ag.profitcenter               = _ci.profitcenter
    // Regla de clasificacion (LEFT OUTER, igual que ZR_IntercoJEItemClassV3). La Base Acumulada
    // descarta las filas sin regla con el filtro IsNotBillableFromMasterData is initial de la ZC.
    left outer join ZI_IntercoClassificationRule   as _classificationrule on _classificationrule.RuleID = _ci.ruleid
    // Documento contable: clave completa, solo para campos de documento e importes
    inner join      I_JournalEntryItem                                    on  I_JournalEntryItem.SourceLedger       = _ag.sourceledger
                                                                          and I_JournalEntryItem.CompanyCode        = _ag.companycode
                                                                          and I_JournalEntryItem.FiscalYear         = _ag.fiscalyear
                                                                          and I_JournalEntryItem.AccountingDocument = _ag.accountingdocument
                                                                          and I_JournalEntryItem.LedgerGLLineItem   = _ag.ledgergllineitem
                                                                          and I_JournalEntryItem.Ledger             = _ag.ledger
    inner join      ZI_IntercoCompanyCode          as _intercocompanycode on _intercocompanycode.CompanyCode = _ag.companycode
    // CeCo vigente: LEFT OUTER + filtro en el WHERE, igual que ZR_IntercoJEItemClassV3
    // (las lineas de ingreso origen 01/45 no tienen CeCo)
    left outer join I_CostCenter                   as _currentcostcenter  on  _currentcostcenter.ControllingArea   = I_JournalEntryItem.ControllingArea
                                                                          and _currentcostcenter.CostCenter        = _ag.costcenter
                                                                          and _currentcostcenter.ValidityStartDate <= $session.system_date
                                                                          and _currentcostcenter.ValidityEndDate   >= $session.system_date
    left outer join ZI_ProfitCenterHierarchyFlat   as _pchierarchyflat    on  _pchierarchyflat.ControllingArea =  I_JournalEntryItem.ControllingArea
                                                                          and _pchierarchyflat.ProfitCenter    =  _ag.profitcenter
                                                                          and _pchierarchyflat.ValidityEndDate >= I_JournalEntryItem.PostingDate
    left outer join ZI_IntercoBasisItem            as _currentbasisitem   on  _currentbasisitem.Ledger              =       _ag.ledger
                                                                          and _currentbasisitem.Glaccount           =       _ag.glaccount
                                                                          and _currentbasisitem.Costcenter          =       _ag.costcenter
                                                                          and _currentbasisitem.Fiscalyear          =       _ag.fiscalyear
                                                                          and _currentbasisitem.Fiscalperiod        =       _ag.fiscalperiod
                                                                          and _currentbasisitem.Providercompanycode =       _ag.companycode
                                                                          and _currentbasisitem.Profitcenter        =       _ag.profitcenter
                                                                          and I_JournalEntryItem.CreationDateTime   between _currentbasisitem.MinDateTime and _currentbasisitem.MaxDateTime
                                                                          and _currentbasisitem.ExecutionStatus     =       'COMPLETED'
    left outer join ZR_INTERCOJEITEMHELPERCLASSEXE as _exemptions         on  _exemptions.Ledger       =  _ag.ledger
                                                                          and _exemptions.CompanyCode  =  _ag.companycode
                                                                          and _exemptions.FiscalYear   =  _ag.fiscalyear
                                                                          and _exemptions.FiscalPeriod =  _ag.fiscalperiod
                                                                          and _exemptions.CostCenter   =  _ag.costcenter
                                                                          and _exemptions.GLAccount    =  _ag.glaccount
                                                                          and _exemptions.ProfitCenter =  _ag.profitcenter
                                                                          and (
                                                                             (
                                                                               _ci.paymenttype             =  'E'
                                                                               and _exemptions.PaymentType =  'E'
                                                                             )
                                                                             or(
                                                                               _ci.paymenttype             =  'L'
                                                                               and _exemptions.PaymentType =  'L'
                                                                             )
                                                                             or(
                                                                               (
                                                                                 _ci.paymenttype           is null
                                                                                 or(
                                                                                   _ci.paymenttype         <> 'E'
                                                                                   and _ci.paymenttype     <> 'L'
                                                                                 )
                                                                               )
                                                                               and _exemptions.PaymentType =  _ag.paymenttype
                                                                             )
                                                                           )
    left outer join ZI_IntercoDepartmentRule       as _departmentrule     on  _departmentrule.CompanyCode = _ag.companycode
                                                                          and _departmentrule.PAndLId     = _ag.pandll3id
                                                                          and _departmentrule.Product     = _classificationrule.Product
    left outer join I_CostCenterHierarchyNode      as _allocnodetext      on  _allocnodetext.CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
                                                                          and _allocnodetext.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                          and _allocnodetext.HierarchyNodeVal    = _ag.ccallocation
    left outer join I_CostCenterHierarchyNode      as _consnodetext       on  _consnodetext.CostCenterHierarchy = 'H101/ML00/CONS_CC'
                                                                          and _consnodetext.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                          and _consnodetext.HierarchyNodeVal    = _ag.ccconsolidation
    left outer join I_CostCenterHierarchyNode      as _stdnodetext        on  _stdnodetext.CostCenterHierarchy = '0101/ML00/ML00'
                                                                          and _stdnodetext.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                          and _stdnodetext.HierarchyNodeVal    = _ag.costcenterstandardhierarea
{
  key _ag.sourceledger                                                                              as SourceLedger,
  key _ag.companycode                                                                               as CompanyCode,
  key _ag.fiscalyear                                                                                as FiscalYear,
  key _ag.accountingdocument                                                                        as AccountingDocument,
  key _ag.ledgergllineitem                                                                          as LedgerGLLineItem,
  key _ag.ledger                                                                                    as Ledger,
  key _ag.fiscalperiod                                                                              as FiscalPeriod,
      I_JournalEntryItem.Segment,
      I_JournalEntryItem.AccountingDocumentType,
      I_JournalEntryItem.AccountingDocumentItem,
      I_JournalEntryItem.DebitCreditCode,
      I_JournalEntryItem.AccountingDocumentCategory,
      I_JournalEntryItem.LedgerFiscalYear,
      I_JournalEntryItem.ClearingAccountingDocument,
      I_JournalEntryItem.ClearingJournalEntry,
      I_JournalEntryItem.ClearingDate,
      I_JournalEntryItem.ClearingDocFiscalYear,
      I_JournalEntryItem.ClearingJournalEntryFiscalYear,
      I_JournalEntryItem.IsOpenItemManaged,
      I_JournalEntryItem.TransactionCurrency,
      I_JournalEntryItem.AmountInTransactionCurrency,
      I_JournalEntryItem.CompanyCodeCurrency,
      I_JournalEntryItem.AmountInCompanyCodeCurrency,
      I_JournalEntryItem.GlobalCurrency,
      I_JournalEntryItem.AmountInGlobalCurrency,
      I_JournalEntryItem.CreationDate,
      I_JournalEntryItem.FiscalYearPeriod,
      I_JournalEntryItem.OriginObjectType,
      I_JournalEntryItem.GLAccount,
      I_JournalEntryItem.ChartOfAccounts,
      I_JournalEntryItem.PostingDate,
      I_JournalEntryItem.CreationDateTime,
      I_JournalEntryItem.ControllingArea,
      I_JournalEntryItem.CostCenter,
      I_JournalEntryItem.ProfitCenter,

      cast(
        case
          when _ci.paymenttype = 'E' then _ci.paymenttype
          when _ci.paymenttype = 'L' then _ci.paymenttype
          else _ag.paymenttype
        end
        as zint_dte_paymenttype preserving type
      )                                                                                             as PaymentType,

      _intercocompanycode.SiteCode,
      _intercocompanycode.SiteName,
      _ag.costcenterstandardhierarea                                                                as CostCenterStandardHierArea,
      _ag.glaccountparentnode                                                                       as GLAccountParentNode,
      _ag.ccconsolidation                                                                           as CCConsolidation,
      _ag.pcconsolidation                                                                           as PCConsolidation,
      _ag.ccallocation                                                                              as CCAllocation,
      _ag.pandll0id                                                                                 as PandLL0Id,
      _ag.pandll0name                                                                               as PandLL0Name,
      _ag.pandll1id                                                                                 as PandLL1Id,
      _ag.pandll1name                                                                               as PandLL1Name,
      _ag.pandll2id                                                                                 as PandLL2Id,
      _ag.pandll2name                                                                               as PandLL2Name,
      _ag.pandll3id                                                                                 as PandLL3Id,
      _ag.pandll3name                                                                               as PandLL3Name,
      _ag.pandll4id                                                                                 as PandLL4Id,
      _ag.pandll4name                                                                               as PandLL4Name,
      _ag.pandll5id                                                                                 as PandLL5Id,
      _ag.pandll5name                                                                               as PandLL5Name,
      _classificationrule.ID                                                                        as ClassificationRuleID,
      cast( coalesce( _ci.ruleid, '0000000000' ) as zint_rule_id )                                  as ClassificationRuleExtID,
      _classificationrule.RuleName                                                                  as RuleName,

      case
        when _currentbasisitem.Id is not null
          then cast( coalesce( _currentbasisitem.Product, '--' ) as matnr )
        else
          case $projection.IsBillable
            when 'E' then '--'
            else cast( coalesce( _classificationrule.Product, '--' ) as matnr )
          end
      end                                                                                           as Concept,

      case
        when $projection.DescriptionBase = '' or $projection.DescriptionBase is null
        then case $projection.IsBillable
               when 'E' then ''
               else _classificationrule._Product.ProductName
             end
        else _currentbasisitem._Product.ProductName
      end                                                                                           as ConceptName,

      _classificationrule.IsNotBillable                                                             as IsNotBillableFromMasterData,
      _classificationrule.Score                                                                     as ClassificationRuleScore,
      _exemptions._ExemptionRule.ID                                                                 as ClassificationExemptionID,
      cast( coalesce( _exemptions.ExemptionID, '0000000000' ) as zint_exemption_id )                as ClassificationExemptionExtID,
      _exemptions._ExemptionRule.ExemptionName,
      cast( case when _exemptions.ExemptionID is not initial then 'X' else '' end as abap_boolean ) as IsNotBillableFromExemption,

      cast(
        case
          when _exemptions.ExemptionID is not initial  then 'E'
          when _classificationrule.ID  is null         then '-'
          when _classificationrule.IsNotBillable = 'X' then 'N'
          else 'B'
        end
        as zint_billable_status
      )                                                                                             as IsBillable,

      case $projection.IsBillable
        when 'B' then 3
        when 'N' then 1
        when 'E' then 2
        else 0
      end                                                                                           as IsBillableCriticality,
      _currentbasisitem.Id                                                                          as IdBase,
      _currentbasisitem._header.Description                                                         as DescriptionBase,
      _currentbasisitem._header.IsReleased                                                          as IsReleased,
      _currentbasisitem._header.CompanyCode                                                         as CurrentBasis_CompanyCode,
      _currentbasisitem._header.Ledger                                                              as CurrentBasis_Ledger,
      _currentbasisitem._header.FiscalYear                                                          as CurrentBasis_FiscalYear,
      _currentbasisitem._header.FiscalPeriod                                                        as CurrentBasis_FiscalPeriod,
      _currentbasisitem._header.PaymentType                                                         as CurrentBasis_PaymentType,
      _currentbasisitem.Department                                                                  as CurrentBasis_Department,
      _currentbasisitem._Department.Description                                                     as CurrentBasis_DepartmentDescr,
      _departmentrule.Department                                                                    as departmentrule_Department,
      _departmentrule._Department.Description                                                       as departmentrule_description,
      // TEMP INDEX ->
      _ag.companycode                                                                               as IndexCompanyCode,
      _allocnodetext._Text[1: Language = $session.system_language].HierarchyNodeText                as IndexAllocation,
      _consnodetext._Text[1: Language = $session.system_language].HierarchyNodeText                 as IndexConsolidation,
      _stdnodetext._Text[1: Language = $session.system_language].HierarchyNodeText                  as IndexArea,
      _pchierarchyflat._BusinessUnitText[1: Language = $session.system_language ].HierarchyNodeText as IndexBusinessUnit,
      $projection.PandLL0Name                                                                       as IndexPYL0,
      $projection.PandLL1Name                                                                       as IndexPYL1,
      $projection.PandLL2Name                                                                       as IndexPYLCLASIFICADO,
      _ag.costcenter                                                                                as IndexCostCenter,
      _ag.glaccount                                                                                 as IndexAccountNro,
      concat(_ag.fiscalyear, substring(_ag.fiscalperiod, 2, 2))                                     as IndexMonth,
      I_JournalEntryItem.AmountInGlobalCurrency                                                     as IndexTotal,
      $projection.ConceptName                                                                       as IndexFacturacion
      // TEMP INDEX <-
}
where
  (
       I_JournalEntryItem.GLAccountType = 'P'
    or I_JournalEntryItem.GLAccountType = 'N'
    or I_JournalEntryItem.GLAccountType = 'S'
  )
  // CeCo vigente obligatorio solo para lineas con CeCo
  and(
       _currentcostcenter.CostCenter    is not null
    or _ag.costcenter                   =  ''
  )
