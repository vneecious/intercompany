/**
 * This is the foundation of the Intercompany Basis Report.
 * This view is designed to display Journal Entry Items that are potentially relevant to the Intercompany Process.
 * Specifically, it includes:
 *   1 - Only entries for companies listed in ZI_IntercoCompanyCode.
 *   2 - Only entries GL Accounts of type P, N or S
 *   3 - Only OriginObjectType 01 or 02, where 01 = Income and 02 = Expense
 *
 * Any documents that do not meet these criteria will not be included in this view.
 *
 * Intercompany Basis View Hierarchy:
 * ZR_IntercoJEItemClass
 *  - ZI_IntercoJEItemClass
 *      - ZI_IntercoJEItemClassMatch
 *          - ZI_IntercoJEItemClassRule
 *              - ZI_IntercoJEItemPandL
 *                  - ZI_IntercoJEItem <------- CURRENT VIEW
 *
 */
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry Items Classification'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #XXL,
    dataClass: #MIXED
}
define view entity ZI_IntercoJEItem
  as select from I_JournalEntryItem as JournalEntryItem
  association [1..1] to ZI_IntercoCompanyCode        as _IntercoCompanyCode           on  _IntercoCompanyCode.CompanyCode = $projection.CompanyCode

  // CC ALLOC
  association [0..*] to I_CostCenterHierarchyNode    as _CCAllocationHierarchyNode    on  _CCAllocationHierarchyNode.CostCenterHierarchy = 'H101/ML00/ALLOC_CC'
                                                                                      and _CCAllocationHierarchyNode.ControllingArea     = $projection.ControllingArea
                                                                                      and _CCAllocationHierarchyNode.CostCenter          = $projection.CostCenter
                                                                                      and $projection.CostCenter                         is not initial
  association [0..*] to I_CostCenterHierarchyNode    as _CCAllocationParentNode       on  _CCAllocationParentNode.CostCenterHierarchy = $projection.CCAllocationHierarchy
                                                                                      and _CCAllocationParentNode.ControllingArea     = $projection.ControllingArea
                                                                                      and _CCAllocationParentNode.HierarchyNode       = $projection.CCAllocationParentNode
                                                                                      and $projection.CostCenter                      is not initial
  // CC CONS
  association [0..*] to I_CostCenterHierarchyNode    as _CCConsolidationHierarchyNode on  _CCConsolidationHierarchyNode.CostCenterHierarchy = 'H101/ML00/CONS_CC'
                                                                                      and _CCConsolidationHierarchyNode.ControllingArea     = $projection.ControllingArea
                                                                                      and _CCConsolidationHierarchyNode.CostCenter          = $projection.CostCenter
                                                                                      and $projection.CostCenter                            is not initial
  association [0..*] to I_CostCenterHierarchyNode    as _CCConsolidationParentNode    on  _CCConsolidationParentNode.CostCenterHierarchy = $projection.CCConsolidationHierarchy
                                                                                      and _CCConsolidationParentNode.ControllingArea     = $projection.ControllingArea
                                                                                      and _CCConsolidationParentNode.HierarchyNode       = $projection.CCConsolidationParentNode
                                                                                      and $projection.CostCenter                         is not initial

  // CC Standard
  association [0..*] to I_CostCenterHierarchyNode    as _CCStdHierarchyNode           on  _CCStdHierarchyNode.CostCenterHierarchy = '0101/ML00/ML00'
                                                                                      and _CCStdHierarchyNode.ControllingArea     = $projection.ControllingArea
                                                                                      and _CCStdHierarchyNode.CostCenter          = $projection.CostCenter
                                                                                      and $projection.CostCenter                  is not initial
  association [0..*] to I_CostCenterHierarchyNode    as _CCStdParentNode              on  _CCStdParentNode.CostCenterHierarchy = $projection.CCStdHierarchy
                                                                                      and _CCStdParentNode.ControllingArea     = $projection.ControllingArea
                                                                                      and _CCStdParentNode.HierarchyNode       = $projection.CCStdParentNode
                                                                                      and $projection.CostCenter               is not initial

  // PC CONS
  association [0..*] to I_ProfitCenterHierarchyNode  as _PCConsolidationHierarchyNode on  _PCConsolidationHierarchyNode.ProfitCenterHierarchy = 'H106/ML00/CONS_PC'
                                                                                      and _PCConsolidationHierarchyNode.ControllingArea       = $projection.ControllingArea
                                                                                      and _PCConsolidationHierarchyNode.ProfitCenter          = $projection.ProfitCenter
                                                                                      and $projection.ProfitCenter                            is not initial
  association [0..*] to I_ProfitCenterHierarchyNode  as _PCConsolidationParentNode    on  _PCConsolidationParentNode.ProfitCenterHierarchy = $projection.PCConsolidationHierarchy
                                                                                      and _PCConsolidationParentNode.ControllingArea       = $projection.ControllingArea
                                                                                      and _PCConsolidationParentNode.HierarchyNode         = $projection.PCConsolidationParentNode
                                                                                      and $projection.ProfitCenter                         is not initial


  // ZBCE
  association [0..*] to I_GLAccountHierarchyNode     as _GLAccountHierarchyNode       on  _GLAccountHierarchyNode.GLAccountHierarchy = 'H109/MLIB/ZBCE'
                                                                                      and _GLAccountHierarchyNode.ChartOfAccounts    = $projection.ChartOfAccounts
                                                                                      and _GLAccountHierarchyNode.GLAccount          = $projection.GLAccount
  association [0..*] to I_GLAccountHierarchyNode     as _GLAccountParentNode          on  _GLAccountParentNode.GLAccountHierarchy = $projection.GLAccountHierarchy
                                                                                      and _GLAccountParentNode.ChartOfAccounts    = $projection.ChartOfAccounts
                                                                                      and _GLAccountParentNode.HierarchyNode      = $projection.GLAccountParentNode
  // PC Standard
  association [0..*] to ZI_ProfitCenterHierarchyFlat as _PCHierarchyFlat              on  _PCHierarchyFlat.ControllingArea = $projection.ControllingArea
                                                                                      and _PCHierarchyFlat.ProfitCenter    = $projection.ProfitCenter
                                                                                      and _PCHierarchyFlat.ValidityEndDate >= $projection.PostingDate

{
  key SourceLedger,
  key CompanyCode,
  key FiscalYear,
  key FiscalPeriod,
  key AccountingDocument,
  key LedgerGLLineItem,
  key Ledger,
      ProfitCenter,
      PostingDate,
      CreationDateTime,
      CostCenter,
      ControllingArea,
      Segment,
      AccountingDocumentType,
      AccountingDocumentItem,
      DebitCreditCode,
      AccountingDocumentCategory,
      LedgerFiscalYear,
      ClearingAccountingDocument,
      ClearingJournalEntry,
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
      CreationDate,
      FiscalYearPeriod,
      JournalEntryItem.OriginObjectType,
      -- Ini Facturación Local CH/ARG EXT_OSCUGALD 05.10.2026 - C04: normalizar PaymentType según OriginObjectType
      -- case JournalEntryItem.OriginObjectType when '02' then 'E' else 'I' end             as PaymentType,
      case JournalEntryItem.OriginObjectType when '02' then 'E' else '' end              as PaymentType,
      -- Fin EXT_OSCUGALD 05.10.2026 - C04
      JournalEntryItem._CurrentCostCenter.CostCenterStandardHierArea,
      // ZBCE
      JournalEntryItem.ChartOfAccounts,
      JournalEntryItem.GLAccount,
      _GLAccountHierarchyNode.GLAccountHierarchy                                         as GLAccountHierarchy,
      _GLAccountHierarchyNode.HierarchyNode                                              as GLAccountHierarchyNode,
      _GLAccountHierarchyNode.ParentNode                                                 as GLAccountParentNode,
      cast( cast( $projection.GLAccountParentNode as abap.int4 ) as abap.char(50))       as GLAccountParentNodeTEMP,
      length( $projection.GLAccountParentNodeTEMP )                                      as GLAccountParentNodeTEMPlen,
      // CONS_CC
      _CCConsolidationHierarchyNode.CostCenterHierarchy                                  as CCConsolidationHierarchy,
      _CCConsolidationHierarchyNode.HierarchyNode                                        as CCConsolidationHierarchyNode,
      _CCConsolidationHierarchyNode.ParentNode                                           as CCConsolidationParentNode,
      cast( cast( $projection.CCConsolidationParentNode as abap.int4 ) as abap.char(50)) as CCConsolidationParentNodeTEMP,
      // CC Std
      _CCStdHierarchyNode.CostCenterHierarchy                                            as CCStdHierarchy,
      _CCStdHierarchyNode.ParentNode                                                     as CCStdParentNode,
      // CONS_PC
      _PCConsolidationHierarchyNode.ProfitCenterHierarchy                                as PCConsolidationHierarchy,
      _PCConsolidationHierarchyNode.HierarchyNode                                        as PCConsolidationHierarchyNode,
      _PCConsolidationHierarchyNode.ParentNode                                           as PCConsolidationParentNode,
      cast( cast( $projection.PCConsolidationParentNode as abap.int4 ) as abap.char(50)) as PCConsolidationParentNodeTEMP,
      // PC Std
      _PCHierarchyFlat.BusinessUnit                                                      as PCBusinessUnit,
      _PCHierarchyFlat.SubBusinessUnitGroup                                              as PCSubBusinessUnitGroup,
      _PCHierarchyFlat.SubBusinessUnit                                                   as PCSubBusinessUnit,
      // ALLOC_CC
      _CCAllocationHierarchyNode.CostCenterHierarchy                                     as CCAllocationHierarchy,
      _CCAllocationHierarchyNode.HierarchyNode                                           as CCAllocationHierarchyNode,
      _CCAllocationHierarchyNode.ParentNode                                              as CCAllocationParentNode,
      // P&L
      _IntercoCompanyCode,
      _CCAllocationHierarchyNode,
      _CCConsolidationHierarchyNode,
      _PCConsolidationHierarchyNode,
      _GLAccountHierarchyNode,
      _CCAllocationParentNode,
      _CCConsolidationParentNode,
      _PCConsolidationParentNode,
      _CCStdHierarchyNode,
      _CCStdParentNode,
      _PCHierarchyFlat,
      _GLAccountParentNode,
      JournalEntryItem._CurrentProfitCenter,
      JournalEntryItem._CurrentCostCenter
}
where
  (
       JournalEntryItem.GLAccountType    = 'P'
    or JournalEntryItem.GLAccountType    = 'N'
    or JournalEntryItem.GLAccountType    = 'S'
  )
  and(
       JournalEntryItem.OriginObjectType = '01'
    or JournalEntryItem.OriginObjectType = '02'
    or JournalEntryItem.OriginObjectType = '45'
  )
