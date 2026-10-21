/*
 * AGREGADO DS4K9B5URA - Materializacion por agrupadores:
 * Vista V3 reemplaza ~20 JOINs de jerarquias (CC/PC/GL/MT005) por 1 JOIN
 * a ZINT_A_JEITEM_AG (agrupadores pre-calculados en la clasificacion).
 * Para obtener la regla de clasificacion se lee directo desde ZINT_A_JEITEM_CI
 * (tabla fisica) en lugar del CDS view ZR_IntercoJEItemHelperClassItm.
 */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Basis: JE Item Clasif V3 (materializado)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define root view entity ZR_IntercoJEItemClassV3
  as select from I_JournalEntryItem
  // AGREGADO DS4K9B5URA: 1 JOIN a tabla materializada reemplaza 16 JOINs de jerarquias
    inner join zint_a_jeitem_ag                    as _ag                 on  _ag.companycode        = I_JournalEntryItem.CompanyCode
                                                                          and _ag.ledger             = I_JournalEntryItem.Ledger
                                                                          and _ag.sourceledger       = I_JournalEntryItem.SourceLedger
                                                                          and _ag.fiscalyear         = I_JournalEntryItem.FiscalYear
                                                                          and _ag.fiscalperiod       = I_JournalEntryItem.FiscalPeriod
                                                                          and _ag.accountingdocument = I_JournalEntryItem.AccountingDocument
                                                                          and _ag.ledgergllineitem   = I_JournalEntryItem.LedgerGLLineItem
    inner join ZI_IntercoCompanyCode               as _intercocompanycode on  _intercocompanycode.CompanyCode = I_JournalEntryItem.CompanyCode
    inner join I_CostCenter                        as _currentcostcenter  on  I_JournalEntryItem.ControllingArea   = _currentcostcenter.ControllingArea
                                                                          and I_JournalEntryItem.CostCenter        = _currentcostcenter.CostCenter
                                                                          and _currentcostcenter.ValidityStartDate <= $session.system_date
                                                                          and _currentcostcenter.ValidityEndDate   >= $session.system_date
    left outer join ZI_ProfitCenterHierarchyFlat   as _pchierarchyflat    on  _pchierarchyflat.ControllingArea =  I_JournalEntryItem.ControllingArea
                                                                          and _pchierarchyflat.ProfitCenter    =  I_JournalEntryItem.ProfitCenter
                                                                          and _pchierarchyflat.ValidityEndDate >= I_JournalEntryItem.PostingDate
    left outer join ZI_IntercoBasisItem            as _currentbasisitem   on  _currentbasisitem.Ledger              =       I_JournalEntryItem.Ledger
                                                                          and _currentbasisitem.Glaccount           =       I_JournalEntryItem.GLAccount
                                                                          and _currentbasisitem.Costcenter          =       I_JournalEntryItem.CostCenter
                                                                          and _currentbasisitem.Fiscalyear          =       I_JournalEntryItem.FiscalYear
                                                                          and _currentbasisitem.Fiscalperiod        =       I_JournalEntryItem.FiscalPeriod
                                                                          and _currentbasisitem.Providercompanycode =       I_JournalEntryItem.CompanyCode
                                                                          and _currentbasisitem.Profitcenter        =       I_JournalEntryItem.ProfitCenter
                                                                          and I_JournalEntryItem.CreationDateTime   between _currentbasisitem.MinDateTime and _currentbasisitem.MaxDateTime
                                                                          and _currentbasisitem.ExecutionStatus     =       'COMPLETED'
  // AGREGADO DS4K9B5URA: clasificacion desde tabla fisica ZINT_A_JEITEM_CI (en lugar del CDS view helper)
    left outer join zint_a_jeitem_ci               as _ci                 on  _ci.ledger                     = I_JournalEntryItem.Ledger
                                                                          and _ci.companycode                 = I_JournalEntryItem.CompanyCode
                                                                          and _ci.fiscalyear                  = I_JournalEntryItem.FiscalYear
                                                                          and _ci.fiscalperiod                = I_JournalEntryItem.FiscalPeriod
                                                                          and _ci.paymenttype                 = 'E'
                                                                          and _ci.pandll5id                   = _ag.pandll5id
                                                                          and _ci.ccconsolidation             = _ag.ccconsolidation
                                                                          and _ci.costcenterstandardhierarea  = _ag.costcenterstandardhierarea
                                                                          and _ci.ccallocation                = _ag.ccallocation
                                                                          and _ci.profitcenter                = I_JournalEntryItem.ProfitCenter
    left outer join ZI_IntercoClassificationRule   as _classificationrule on  _ci.ruleid = _classificationrule.RuleID
    left outer join ZR_INTERCOJEITEMHELPERCLASSEXE as _exemptions         on  _exemptions.Ledger       = I_JournalEntryItem.Ledger
                                                                          and _exemptions.CompanyCode  = I_JournalEntryItem.CompanyCode
                                                                          and _exemptions.FiscalYear   = I_JournalEntryItem.FiscalYear
                                                                          and _exemptions.FiscalPeriod = I_JournalEntryItem.FiscalPeriod
                                                                          and _exemptions.PaymentType  = 'E'
                                                                          and _exemptions.CostCenter   = I_JournalEntryItem.CostCenter
                                                                          and _exemptions.GLAccount    = I_JournalEntryItem.GLAccount
                                                                          and _exemptions.ProfitCenter = I_JournalEntryItem.ProfitCenter
  // AGREGADO DS4K9B5URA: regla de departamento unificada (antes CC/PC separados)
    left outer join ZI_IntercoDepartmentRule       as _departmentrule     on  _departmentrule.CompanyCode = I_JournalEntryItem.CompanyCode
                                                                          and _departmentrule.PAndLId     = _ag.pandll3id
                                                                          and _departmentrule.Product     = _classificationrule.Product
  // TEMP INDEX: resolucao de texto dos nos de hierarquia para IndexAllocation, IndexConsolidation e IndexArea
    left outer join I_CostCenterHierarchyNode      as _allocnodetext      on  _allocnodetext.CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
                                                                          and _allocnodetext.ControllingArea     = I_JournalEntryItem.ControllingArea
                                                                          and _allocnodetext.HierarchyNodeVal    = _ag.ccallocation
    left outer join I_CostCenterHierarchyNode      as _consnodetext       on  _consnodetext.CostCenterHierarchy  = 'H101/ML00/CONS_CC'
                                                                          and _consnodetext.ControllingArea      = I_JournalEntryItem.ControllingArea
                                                                          and _consnodetext.HierarchyNodeVal     = _ag.ccconsolidation
    left outer join I_CostCenterHierarchyNode      as _stdnodetext        on  _stdnodetext.CostCenterHierarchy   = '0101/ML00/ML00'
                                                                          and _stdnodetext.ControllingArea       = I_JournalEntryItem.ControllingArea
                                                                          and _stdnodetext.HierarchyNodeVal      = _ag.costcenterstandardhierarea
{
  key I_JournalEntryItem.SourceLedger,
  key I_JournalEntryItem.CompanyCode,
  key I_JournalEntryItem.FiscalYear,
  key I_JournalEntryItem.AccountingDocument,
  key I_JournalEntryItem.LedgerGLLineItem,
  key I_JournalEntryItem.Ledger,
  key I_JournalEntryItem.FiscalPeriod,
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
      // AGREGADO DS4K9B5URA: agrupadores desde tabla materializada
      _ag.paymenttype                                                       as PaymentType,
      _intercocompanycode.SiteCode,
      _intercocompanycode.SiteName,
      _ag.costcenterstandardhierarea                                        as CostCenterStandardHierArea,
      _ag.glaccountparentnode                                               as GLAccountParentNode,
      _ag.ccconsolidation                                                   as CCConsolidation,
      _ag.pcconsolidation                                                   as PCConsolidation,
      _ag.ccallocation                                                      as CCAllocation,
      // P&L directo desde tabla materializada (antes: CASE WHEN _mt005CC vs _mt005PC)
      _ag.pandll0id                                                         as PandLL0Id,
      _ag.pandll0name                                                       as PandLL0Name,
      _ag.pandll1id                                                         as PandLL1Id,
      _ag.pandll1name                                                       as PandLL1Name,
      _ag.pandll2id                                                         as PandLL2Id,
      _ag.pandll2name                                                       as PandLL2Name,
      _ag.pandll3id                                                         as PandLL3Id,
      _ag.pandll3name                                                       as PandLL3Name,
      _ag.pandll4id                                                         as PandLL4Id,
      _ag.pandll4name                                                       as PandLL4Name,
      _ag.pandll5id                                                         as PandLL5Id,
      _ag.pandll5name                                                       as PandLL5Name,
      // Classification Rule unificada (CC+PC)
      _classificationrule.ID                                                as ClassificationRuleID,
      cast( coalesce( _ci.ruleid, '0000000000' ) as zint_rule_id )         as ClassificationRuleExtID,
      _classificationrule.RuleName                                          as RuleName,

      case
        when _currentbasisitem.Id is not null
          then cast( coalesce( _currentbasisitem.Product, '--' ) as matnr )
        else
          case $projection.IsBillable
            when 'E' then '--'
            else cast( coalesce( _classificationrule.Product, '--' ) as matnr )
          end
      end                                                                   as Concept,

      case
        when $projection.DescriptionBase = '' or $projection.DescriptionBase is null
        then case $projection.IsBillable
               when 'E' then ''
               else _classificationrule._Product.ProductName
             end
        else _currentbasisitem._Product.ProductName
      end                                                                   as ConceptName,

      _classificationrule.IsNotBillable                                     as IsNotBillableFromMasterData,
      _classificationrule.Score                                             as ClassificationRuleScore,
      // Exemption
      _exemptions._ExemptionRule.ID                                         as ClassificationExemptionID,
      cast( coalesce( _exemptions.ExemptionID, '0000000000' ) as zint_exemption_id ) as ClassificationExemptionExtID,
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
      )                                                                     as IsBillable,

      case $projection.IsBillable
        when 'B' then 3
        when 'N' then 1
        when 'E' then 2
        else 0
      end                                                                   as IsBillableCriticality,
      _currentbasisitem.Id                                                  as IdBase,
      _currentbasisitem._header.Description                                 as DescriptionBase,
      _currentbasisitem._header.IsReleased                                  as IsReleased,
      _currentbasisitem._header.CompanyCode                                 as CurrentBasis_CompanyCode,
      _currentbasisitem._header.Ledger                                      as CurrentBasis_Ledger,
      _currentbasisitem._header.FiscalYear                                  as CurrentBasis_FiscalYear,
      _currentbasisitem._header.FiscalPeriod                                as CurrentBasis_FiscalPeriod,
      _currentbasisitem._header.PaymentType                                 as CurrentBasis_PaymentType,
      _currentbasisitem.Department                                          as CurrentBasis_Department,
      _currentbasisitem._Department.Description                             as CurrentBasis_DepartmentDescr,
      _departmentrule.Department                                            as departmentrule_Department,
      _departmentrule._Department.Description                               as departmentrule_description,
      // TEMP INDEX ->
      I_JournalEntryItem.CompanyCode                                        as IndexCompanyCode,
      _allocnodetext._Text[1: Language = $session.system_language].HierarchyNodeText as IndexAllocation,
      _consnodetext._Text[1: Language = $session.system_language].HierarchyNodeText  as IndexConsolidation,
      _stdnodetext._Text[1: Language = $session.system_language].HierarchyNodeText   as IndexArea,
      _pchierarchyflat._BusinessUnitText[1: Language = $session.system_language ].HierarchyNodeText as IndexBusinessUnit,
      $projection.PandLL0Name                                               as IndexPYL0,
      $projection.PandLL1Name                                               as IndexPYL1,
      $projection.PandLL2Name                                               as IndexPYLCLASIFICADO,
      I_JournalEntryItem.CostCenter                                         as IndexCostCenter,
      I_JournalEntryItem.GLAccount                                          as IndexAccountNro,
      concat(I_JournalEntryItem.FiscalYear, substring(I_JournalEntryItem.FiscalPeriod, 2, 2)) as IndexMonth,
      I_JournalEntryItem.AmountInGlobalCurrency                             as IndexTotal,
      $projection.ConceptName                                               as IndexFacturacion
      // TEMP INDEX <-
}
where
      I_JournalEntryItem.GLAccountType    = 'P'
   or I_JournalEntryItem.GLAccountType    = 'N'
   or I_JournalEntryItem.GLAccountType    = 'S'
