@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry Item Browser 2'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_INTERCOJOURNALENTRYITEM_2
  with parameters
    P_ClearingStatusSelection : fis_clearingstatusselection,
    P_FiscalYear              : fis_gjahr_no_conv,
    P_FiscalPeriod            : fins_fiscalperiod,
    P_CompanyCode             : zint_dte_bukrs,
    P_Ledger                  : fins_ledger,
    P_PaymentType             : zint_dte_paymenttype
  as select from ZI_INTERCOJOURNALENTRYITEM(P_ClearingStatusSelection: $parameters.P_ClearingStatusSelection , P_FiscalYear : $parameters.P_FiscalYear, P_Fiscalperiod : $parameters.P_FiscalPeriod, P_CompanyCode : $parameters.P_CompanyCode, P_Ledger : $parameters.P_Ledger , P_PaymentType : $parameters.P_PaymentType)
  association [1..1] to Z_PNL_MT005              as _mt005     on _mt005.zagrup_cuentas      = $projection.GLAccountHierarchyParent
                                                               and(
                                                                 (
                                                                   $projection.CostCenter                is not initial
                                                                   and _mt005.zconsolidation = $projection.CostCenterConsolidationNode
                                                                 )
                                                                 or(
                                                                   $projection.ProfitCenter              is not initial
                                                                   and _mt005.zconsolidation = $projection.ProfitCenterConsolidationNode
                                                                 )
                                                               )
  //  association [1..1] to zi_intercopandl_mt005    as _mt005     on  $projection.GLAccountHierarchyNode      = _mt005.zagrup_cuentas
  //                                                               and $projection.CostCenterConsolidationNode = _mt005.zconsolidation
  association [1..1] to zr_interco_subarea_codes as _subAreaId on $projection.CostCenter = _subAreaId.Kostl
  association [1..1] to Z_PNL_ALLOCATION         as _alloc     on $projection.CostCenter = _alloc.CostCenter
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
      GLAccountHierarchy,
      GLAccountHierarchyNode,
      GLAccountHierarchyParent,
      CostCenterConsolidationNode,
      ProfitCenterConsolidationNode,
      _mt005.IdL0                               as PandLL0Id,
      _mt005.L0                                 as PandLL0Name,
      _mt005.IdL1                               as PandLL1Id,
      _mt005.L1                                 as PandLL1Name,
      _mt005.IdL2                               as PandLL2Id,
      _mt005.L2                                 as PandLL2Name,
      _mt005.IdL3                               as PandLL3Id,
      _mt005.L3                                 as PandLL3Name,
      _mt005.IdL4                               as PandLL4Id,
      _mt005.L4                                 as PandLL4Name,
      _mt005.IdL5                               as PandLL5Id,
      _mt005.L5                                 as PandLL5Name,

      cast( case ProfitCenter
      when '0000000999' then ProfitCenter
      else '0000000000' end   as  prctr       ) as profitcenter_z,

      'X'                                       as IsNotBilable,

      @EndUserText.label: 'SubareaId'
      _subAreaId.Khinr                          as SubAreaId,
      @EndUserText.label: 'Allocation'
      _alloc.Allocation                         as Allocation,
      cast ( case
      when _alloc.Allocation = 'Local' then '10'
      else '20' end as kostl )                  as Allocation_id

}
