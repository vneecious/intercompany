@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Items analizados proceso de InterCompany'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INTERCOJOURNALENTRYITEM
  with parameters
    P_ClearingStatusSelection : fis_clearingstatusselection,
    P_FiscalYear              : fis_gjahr_no_conv,
    P_Fiscalperiod            : fins_fiscalperiod,
    P_CompanyCode             : zint_dte_bukrs,
    P_Ledger                  : fins_ledger,
    P_PaymentType             : zint_dte_paymenttype
  as select from    ZI_JournalEntryItemBrowser( P_ClearingStatusSelection:$parameters.P_ClearingStatusSelection  ) as item

    left outer join I_GLAccountHierarchyNode                                                                       as _GLAccountHierarchyNode on  _GLAccountHierarchyNode.GLAccountHierarchy = 'H109/MLIB/ZBCE'
                                                                                                                                              and _GLAccountHierarchyNode.ChartOfAccounts    = item.ChartOfAccounts
                                                                                                                                              and _GLAccountHierarchyNode.GLAccount          = item.GLAccount

  association [1..1] to ZI_IntercoCompanyCode       as _IntercoCompanyCode        on  item.CompanyCode = _IntercoCompanyCode.CompanyCode

  association [0..1] to ZI_IntercoCostCenter        as _IntercoCostCenter         on  item.ControllingArea = _IntercoCostCenter.ControllingArea
                                                                                  and item.CostCenter      = _IntercoCostCenter.CostCenter
                                                                                  and item.CostCenter      is not initial

  association [0..1] to I_ProfitCenterHierarchyNode as _ProfitCenterHierarchyNode on  _ProfitCenterHierarchyNode.ProfitCenterHierarchy = 'H106/ML00/CONS_PC'
                                                                                  and _ProfitCenterHierarchyNode.ControllingArea       = item.ControllingArea
                                                                                  and _ProfitCenterHierarchyNode.ProfitCenter          = item.ProfitCenter
                                                                                  and item.ProfitCenter                                is not initial

{
  key item.SourceLedger,
  key item.CompanyCode,
  key item.FiscalYear,
  key item.FiscalPeriod,
  key item.AccountingDocument,
  key item.LedgerGLLineItem,
  key item.Ledger,
      item.GLAccount,
      item.ChartOfAccounts,
      item.Segment,
      item.AccountingDocumentType,
      item.AccountingDocumentItem,
      item.PostingDate,
      item.DebitCreditCode,
      item.AccountingDocumentCategory,
      item.LedgerFiscalYear,
      item.CreationDateTime,
      item.ClearingAccountingDocument,
      item.ClearingJournalEntry,
      item.ControllingArea,
      item.ClearingDate,
      item.ClearingDocFiscalYear,
      item.ClearingJournalEntryFiscalYear,
      item.IsOpenItemManaged,
      item.TransactionCurrency,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      item.AmountInTransactionCurrency,
      item.CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      item.AmountInCompanyCodeCurrency,
      item.GlobalCurrency,
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      item.AmountInGlobalCurrency,
      item.CostCenter,
      item.ProfitCenter,
      item.CreationDate,
      item.FiscalYearPeriod,
      _GLAccountHierarchyNode.GLAccountHierarchy,
      _GLAccountHierarchyNode.HierarchyNode as GLAccountHierarchyNode,
      _GLAccountHierarchyNode.ParentNode    as GLAccountHierarchyParent,
      _IntercoCostCenter.Consolidation      as CostCenterConsolidationNode,
      _IntercoCostCenter.Allocation         as Allocation,
      _ProfitCenterHierarchyNode.ParentNode as ProfitCenterConsolidationNode,
      //Associations
      _IntercoCompanyCode,
      _ProfitCenterHierarchyNode
}
where
           item.FiscalYear                                                     = $parameters.P_FiscalYear
  and      item.CompanyCode                                                    = $parameters.P_CompanyCode
  and      item.Ledger                                                         = $parameters.P_Ledger
  and(
    (
           $parameters.P_PaymentType                                           = 'I'
      and  item.OriginObjectType                                               = '01'
//      add type filers      
      and(
           item.GLAccountType                                                  = 'P'
        or item.GLAccountType                                                  = 'N'
        or item.GLAccountType                                                  = 'S'
      )      
// end add      
    )
    or(
           $parameters.P_PaymentType                                           = 'E'
      and  item.OriginObjectType                                               = '02'
      and(
           item.GLAccountType                                                  = 'P'
        or item.GLAccountType                                                  = 'N'
        or item.GLAccountType                                                  = 'S'
      )
    )
  )
  and(
           item.FiscalPeriod                                                   = $parameters.P_Fiscalperiod
    or(
           item.FiscalPeriod                                                   <> $parameters.P_Fiscalperiod
      and  cast( substring(  item.CreationDate , 5, 2 ) as fins_fiscalperiod ) <= $parameters.P_Fiscalperiod
    )
  )
