@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interco Clasificación de los Lite Items'
@Metadata.ignorePropagatedAnnotations: false

@Analytics: { dataCategory: #CUBE }
@ObjectModel: {
                usageType: { sizeCategory: #XXL,
                dataClass:  #MIXED,
                serviceQuality: #D },
                supportedCapabilities: [#ANALYTICAL_PROVIDER, #SQL_DATA_SOURCE, #CDS_MODELING_DATA_SOURCE],
                modelingPattern: #ANALYTICAL_CUBE }

define view entity ZI_INTERCOJOURNALENTRYCLASS
  with parameters
    P_ClearingStatusSelection : fis_clearingstatusselection,
    P_FiscalPeriod            : fins_fiscalperiod,
    P_FiscalYear              : fis_gjahr_no_conv,
    P_CompanyCode             : zint_dte_bukrs,
    P_ledger                  : fins_ledger,
    P_PaymentType             : zint_dte_paymenttype
  as select from ZI_INTERCOJOURNALENTRYITEM_2( P_ClearingStatusSelection: $parameters.P_ClearingStatusSelection, P_FiscalYear : $parameters.P_FiscalYear, P_FiscalPeriod: $parameters.P_FiscalPeriod, P_CompanyCode: $parameters.P_CompanyCode, P_Ledger : $parameters.P_ledger , P_PaymentType : $parameters.P_PaymentType  )
  association [0..1] to ZI_INTERCOPRODRELPRODBIL_PROM  as _promo  on(
     $projection.CompanyCode        = _promo.ProviderCompanyCode
     and $projection.SubAreaId      = _promo.CostCenterSubArea
     and $projection.profitcenter_z = _promo.profitcenter
     and $projection.Allocation_id  = _promo.CostCenterAllocation
     and(
       _promo.PandLID               = $projection.PandLL5Id
       or _promo.PandLID            = $projection.PandLL4Id
       or _promo.PandLID            = $projection.PandLL3Id
       or _promo.PandLID            = $projection.PandLL2Id
       or _promo.PandLID            = $projection.PandLL1Id
       or _promo.PandLID            = $projection.PandLL0Id
     )
   )
  association [0..1] to ZI_INTERCOPRODRELPRODBIL_NOPRO as _noprom on(
    $projection.CompanyCode       = _noprom.ProviderCompanyCode
    and $projection.SubAreaId     = _noprom.CostCenterSubArea
    and $projection.ProfitCenter  = _noprom.ProfitCenter
    and $projection.Allocation_id = _noprom.CostCenterAllocation
    and(
      _noprom.PandLID             = $projection.PandLL5Id
      or _noprom.PandLID          = $projection.PandLL4Id
      or _noprom.PandLID          = $projection.PandLL3Id
      or _noprom.PandLID          = $projection.PandLL2Id
      or _noprom.PandLID          = $projection.PandLL1Id
      or _noprom.PandLID          = $projection.PandLL0Id
    )
  )
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
      profitcenter_z,
      IsNotBilable,
      SubAreaId,
      Allocation,
      Allocation_id,
      @ObjectModel.text.element:  [ 'ConceptName' ]
      @UI.textArrangement: #TEXT_LAST
      cast( case
      when _noprom(p_bukrs: $parameters.P_CompanyCode).Product <> '' then _noprom(p_bukrs: $parameters.p_CompanyCode).Product
      else
      _promo(p_bukrs: $parameters.P_CompanyCode).Product  end as zint_dte_concept ) as Concept,

      @Semantics.text: true
      case
      when _noprom(p_bukrs: $parameters.p_CompanyCode).Product <> '' then _noprom(p_bukrs: $parameters.p_CompanyCode).ProductName
      else
      _promo(p_bukrs: $parameters.p_CompanyCode).ProductName       end              as ConceptName,
      cast( case
       when _noprom(p_bukrs: $parameters.p_CompanyCode).Product <> '' then _noprom(p_bukrs: $parameters.p_CompanyCode).IsNotBilable
       else  case
      when _promo(p_bukrs: $parameters.p_CompanyCode).Product <> '' then _promo(p_bukrs: $parameters.p_CompanyCode).IsNotBilable
      else  IsNotBilable   end end as zint_dte_isnotbilable )                       as IsBillableFromMasterData,

1 as score
}
