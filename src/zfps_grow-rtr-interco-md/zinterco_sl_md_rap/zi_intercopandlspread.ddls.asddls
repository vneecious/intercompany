@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Apertura de Agrupadores P&L'
@Metadata.ignorePropagatedAnnotations: false
@Analytics: { dataCategory: #CUBE,
              internalName: #LOCAL }
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #MIXED
}
define view entity ZI_IntercoPandLSpread
  as select from I_JournalEntryItem
  association [1..1] to ZI_IntercoCompanyCode       as _IntercoCompanyCode        on  _IntercoCompanyCode.CompanyCode = $projection.CompanyCode
  association [1..1] to I_CostCenterHierarchyNode   as _CostCenterHierarchyNode   on  _CostCenterHierarchyNode.CostCenterHierarchy = 'H101/ML00/CONS_CC'
                                                                                  and _CostCenterHierarchyNode.ControllingArea     = $projection.ControllingArea
                                                                                  and _CostCenterHierarchyNode.CostCenter          = $projection.CostCenter
                                                                                  and $projection.CostCenter                       is not initial
  association [1..1] to I_ProfitCenterHierarchyNode as _ProfitCenterHierarchyNode on  _ProfitCenterHierarchyNode.ProfitCenterHierarchy = 'H106/ML00/CONS_PC'
                                                                                  and _ProfitCenterHierarchyNode.ControllingArea       = $projection.ControllingArea
                                                                                  and _ProfitCenterHierarchyNode.ProfitCenter          = $projection.ProfitCenter
                                                                                  and $projection.ProfitCenter                         is not initial
  association [1..1] to I_GLAccountHierarchyNode    as _GLAccountHierarchyNode    on  _GLAccountHierarchyNode.GLAccountHierarchy = 'H109/MLIB/ZBCE'
                                                                                  and _GLAccountHierarchyNode.ChartOfAccounts    = $projection.ChartOfAccounts
                                                                                  and _GLAccountHierarchyNode.GLAccount          = $projection.GLAccount
  association [1..1] to Z_PNL_MT005                 as _MT005                     on  ( _MT005.zagrup_cuentas      = $projection.GLAccountParentNode or _MT005.temp_zagrup_cuentas = $projection.GLAccountParentNode )
                                                                                  and (
                                                                                     (
                                                                                       $projection.CostCenter    is not initial
                                                                                       and _MT005.zconsolidation = $projection.CostCenterParentNode
                                                                                     )
                                                                                     or(
                                                                                       $projection.CostCenter    is initial
                                                                                       and _MT005.zconsolidation = $projection.ProfitCenterParentNode
                                                                                     )
                                                                                   )

{
  key SourceLedger,
  key CompanyCode,
  key FiscalYear,
  key AccountingDocument,
  key LedgerGLLineItem,
  key Ledger,
      ControllingArea,
      _IntercoCompanyCode.SiteCode,
      _IntercoCompanyCode.CompanyCodeName,
      LedgerFiscalYear,
      FiscalPeriod,
      ChartOfAccounts,
      GLAccount,
      CostCenter,
      ProfitCenter,
      FunctionalArea,
      TransactionCurrency,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      AmountInTransactionCurrency,
      CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      AmountInCompanyCodeCurrency,
      GlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      AmountInGlobalCurrency,
      PostingDate,
      DocumentDate,
      _CostCenterHierarchyNode.CostCenterHierarchy,
      _CostCenterHierarchyNode.HierarchyNode   as CostCenterNode,
      _CostCenterHierarchyNode.ParentNode      as CostCenterParentNode,
      _ProfitCenterHierarchyNode.ProfitCenterHierarchy,
      _ProfitCenterHierarchyNode.HierarchyNode as ProfitCenterNode,
      _ProfitCenterHierarchyNode.ParentNode    as ProfitCenterParentNode,
      _GLAccountHierarchyNode.GLAccountHierarchy,
      _GLAccountHierarchyNode.HierarchyNode    as GLAccountNode,
      _GLAccountHierarchyNode.ParentNode       as GLAccountParentNode,
      _CostCenterHierarchyNode,
      _ProfitCenterHierarchyNode,
      _GLAccountHierarchyNode,
      _MT005,
      _IntercoCompanyCode,
      _CompanyCode
}
