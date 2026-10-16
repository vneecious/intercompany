@AbapCatalog: { sqlViewName: 'ZIFIJELITBROWS',
                compiler.compareFilter: true,
                preserveKey: true,
                buffering.status: #NOT_ALLOWED }
@AccessControl: {authorizationCheck: #NOT_REQUIRED,
                 personalData.blocking: #REQUIRED }
@EndUserText.label: 'Journal Entry Item Browser'
@VDM.viewType: #COMPOSITE
@ObjectModel: { representativeKey: 'LedgerGLLineItem',
                usageType.sizeCategory: #XXL,
                usageType.dataClass:  #TRANSACTIONAL,
                usageType.serviceQuality: #D,
                supportedCapabilities: [#ANALYTICAL_PROVIDER, #SQL_DATA_SOURCE, #CDS_MODELING_DATA_SOURCE],
                modelingPattern: #ANALYTICAL_CUBE }
@Analytics: { dataCategory: #CUBE,
              internalName: #LOCAL }
@ClientHandling.algorithm: #SESSION_VARIABLE
@Metadata: { ignorePropagatedAnnotations: true,  
             allowExtensions:true }


define view ZI_JournalEntryItemBrowser
    with parameters P_ClearingStatusSelection   : fis_clearingstatusselection 
as select from I_JournalEntryItemBrowser( P_ClearingStatusSelection: ' ' )     

{
@ObjectModel.foreignKey.association: '_SourceLedger'      
key SourceLedger,
@ObjectModel.foreignKey.association: '_CompanyCode'
key I_JournalEntryItemBrowser.CompanyCode,
@ObjectModel.foreignKey.association: '_FiscalYear'
key FiscalYear,
@ObjectModel.foreignKey.association: '_JournalEntry'
key AccountingDocument,
key LedgerGLLineItem,
@ObjectModel.foreignKey.association: '_Ledger'      
key I_JournalEntryItemBrowser.Ledger,

@ObjectModel.foreignKey.association: '_LedgerFiscalYearForVariant' //'_LedgerFiscalYear'
LedgerFiscalYear,
GLRecordType,
JrnlEntrAltvFYConsecutiveID,

//LedgerName,
//CompanyCodeName,

// Object which are dependent objects --> first
@ObjectModel.foreignKey.association: '_ChartOfAccounts'
ChartOfAccounts,
@ObjectModel.foreignKey.association: '_ControllingArea'
ControllingArea,
//ControllingAreaName,


///////////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_00  Unified Journal Entry: Transaction, Currencies, Units
///////////////////////////////////////////////////////////////////////////////
FinancialTransactionType,
BusinessTransactionCategory,
BusinessTransactionType,
ReferenceDocumentType,
LogicalSystem,
ReferenceDocumentContext,
ReferenceDocument,
ReferenceDocumentItem,
ReferenceDocumentItemGroup,
//SUBTA,
//@Semantics.booleanIndicator
IsReversal,
//@Semantics.booleanIndicator
IsReversed,
//XTRUEREV,
//AWTYP_REV,
ReversalReferenceDocumentCntxt,  
ReversalReferenceDocument,
//SUBTA_REV,
//@Semantics.booleanIndicator
IsSettlement,
//@Semantics.booleanIndicator
IsSettled,
PredecessorReferenceDocType,
PredecessorReferenceDocCntxt,  
PredecessorReferenceDocument,
PredecessorReferenceDocItem,
PrdcssrJournalEntryCompanyCode,
PrdcssrJournalEntryFiscalYear,
PredecessorJournalEntry,
PredecessorJournalEntryItem,
//PREC_SUBTA,

SourceReferenceDocumentType,
SourceLogicalSystem,
SourceReferenceDocumentCntxt,
SourceReferenceDocument,
SourceReferenceDocumentItem,
SourceReferenceDocSubitem,
//@Semantics.booleanIndicator
IsCommitment,   
JrnlEntryItemObsoleteReason,
OrganizationalChange,   

@ObjectModel.foreignKey.association: '_GLAccountInChartOfAccounts'
GLAccount,

//GLAccountName,
//GLAccountLongName,

////////////////////////////////////////////////////////////////////////////////////
// .INCLUDE  ACDOC_SI_GL_ACCAS Unified Journal Entry: G/L additional account assignments
////////////////////////////////////////////////////////////////////////////////////
@ObjectModel.foreignKey.association: '_CostCenter'
CostCenter,
//CostCenterName,
@ObjectModel.foreignKey.association: '_ProfitCenter'
ProfitCenter,
//ProfitCenterName,
@ObjectModel.foreignKey.association: '_FunctionalArea'
FunctionalArea,
//FunctionalAreaName,
@ObjectModel.foreignKey.association: '_BusinessArea'
BusinessArea,
//BusinessAreaName,
@ObjectModel.foreignKey.association: '_Segment'
Segment,
//SegmentName,
PartnerCostCenter,
PartnerProfitCenter,
PartnerFunctionalArea,
PartnerBusinessArea,
PartnerCompany,
PartnerSegment,


@ObjectModel.foreignKey.association: '_BalanceTransactionCurrency'
@Semantics.currencyCode:true
BalanceTransactionCurrency as BalanceTransactionCurrency,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'BalanceTransactionCurrency'} }  
AmountInBalanceTransacCrcy,

@ObjectModel.foreignKey.association: '_TransactionCurrency'
@Semantics.currencyCode:true
TransactionCurrency as TransactionCurrency,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'TransactionCurrency'} } 
AmountInTransactionCurrency,

@ObjectModel.foreignKey.association: '_CompanyCodeCurrency'
@Semantics.currencyCode:true
CompanyCodeCurrency as CompanyCodeCurrency,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }  
AmountInCompanyCodeCurrency,

@ObjectModel.foreignKey.association: '_GlobalCurrency'      
@Semantics.currencyCode:true
GlobalCurrency as GlobalCurrency,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  AmountInGlobalCurrency,

@ObjectModel.foreignKey.association: '_FunctionalCurrency'
@Semantics.currencyCode:true
FunctionalCurrency,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FunctionalCurrency'} }
AmountInFunctionalCurrency,  

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency1'      
@Semantics.currencyCode:true
FreeDefinedCurrency1 as FreeDefinedCurrency1,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency1'} }  AmountInFreeDefinedCurrency1,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency2'      
@Semantics.currencyCode:true
FreeDefinedCurrency2 as FreeDefinedCurrency2,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency2'} }  AmountInFreeDefinedCurrency2,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency3'      
@Semantics.currencyCode:true
FreeDefinedCurrency3 as FreeDefinedCurrency3,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency3'} }  AmountInFreeDefinedCurrency3,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency4'      
@Semantics.currencyCode:true
FreeDefinedCurrency4 as FreeDefinedCurrency4,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency4'} }  AmountInFreeDefinedCurrency4,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency5'      
@Semantics.currencyCode:true
FreeDefinedCurrency5 as FreeDefinedCurrency5,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency5'} }  AmountInFreeDefinedCurrency5,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency6'      
@Semantics.currencyCode:true
FreeDefinedCurrency6 as FreeDefinedCurrency6,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency6'} }  AmountInFreeDefinedCurrency6,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency7'      
@Semantics.currencyCode:true
FreeDefinedCurrency7 as FreeDefinedCurrency7,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency7'} }  AmountInFreeDefinedCurrency7,

@ObjectModel.foreignKey.association: '_FreeDefinedCurrency8'      
@Semantics.currencyCode:true
FreeDefinedCurrency8 as FreeDefinedCurrency8,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency8'} }  AmountInFreeDefinedCurrency8,
////////////////////////////////////


////////////////////////////////////
// NEW
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  FixedAmountInGlobalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  GrpValnFixedAmtInGlobCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  PrftCtrValnFxdAmtInGlobCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  TotalPriceVarcInGlobalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  GrpValnTotPrcVarcInGlobCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  PrftCtrValnTotPrcVarcInGlbCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  FixedPriceVarcInGlobalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  GrpValnFixedPrcVarcInGlobCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} }  PrftCtrValnFxdPrcVarcInGlbCrcy,

////////////////////////////////////
 

@Semantics.currencyCode:true
ControllingObjectCurrency as ControllingObjectCurrency,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'ControllingObjectCurrency'} }  AmountInObjectCurrency,

@Semantics.currencyCode:true
GrantCurrency,
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GrantCurrency'} }
AmountInGrantCurrency,  


@ObjectModel.foreignKey.association: '_BaseUnit'
@Semantics.unitOfMeasure:true
BaseUnit as BaseUnit,
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'BaseUnit'} } Quantity,

@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'BaseUnit'} }  FixedQuantity,

@ObjectModel.foreignKey.association: '_CostSourceUnit'
@Semantics.unitOfMeasure:true
CostSourceUnit as CostSourceUnit,
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'CostSourceUnit'} }  ValuationQuantity,

@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'CostSourceUnit'} }  ValuationFixedQuantity,

@ObjectModel.foreignKey.association: '_AdditionalQuantity1Unit'
@Semantics.unitOfMeasure:true
AdditionalQuantity1Unit as AdditionalQuantity1Unit,
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'AdditionalQuantity1Unit'} }  AdditionalQuantity1,

@ObjectModel.foreignKey.association: '_AdditionalQuantity2Unit'
@Semantics.unitOfMeasure:true
AdditionalQuantity2Unit as AdditionalQuantity2Unit,
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'AdditionalQuantity2Unit'} } AdditionalQuantity2,

@ObjectModel.foreignKey.association: '_AdditionalQuantity3Unit'
@Semantics.unitOfMeasure:true
AdditionalQuantity3Unit as AdditionalQuantity3Unit,
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'AdditionalQuantity3Unit'} }  AdditionalQuantity3,

@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_IncmpltSummableValnQtyUnt'
@Semantics.unitOfMeasure:true
IncmpltSummableValnQtyUnt,       // IncompleteSummableValuationQuantityUnit
      
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'IncmpltSummableValnQtyUnt'} }
IncmpltSummableValnQty,                 // IncompleteSummableValuationQuantity
      
@DefaultAggregation: #SUM
@Semantics: { quantity : {unitOfMeasure: 'IncmpltSummableValnQtyUnt'} }
IncmpltSummableValnFxdQty,               // IncompleteSummableValuationFixQuantity


/////////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_FIX  Unified Journal Entry: Mandatory fields for G/L
////////////////////////////////////////////////////////////////////////////
@ObjectModel.foreignKey.association: '_DebitCreditCode'
DebitCreditCode,
FiscalPeriod,
@ObjectModel.foreignKey.association: '_FiscalYearVariant'      
FiscalYearVariant,
FiscalYearPeriod,
PostingDate,
DocumentDate,
@ObjectModel.foreignKey.association: '_AccountingDocumentType'
AccountingDocumentType,
AccountingDocumentItem,
AssignmentReference,
AccountingDocumentCategory,
PostingKey,
TransactionTypeDetermination,
@ObjectModel.foreignKey.association: '_SubLedgerAccLineItemType'
SubLedgerAcctLineItemType,
AccountingDocCreatedByUser,
LastChangeDateTime,
CreationDateTime,
CreationDate,
EliminationProfitCenter,
OriginObjectType,
GLAccountType,
AlternativeGLAccount,
CountryChartOfAccounts,


/////////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_FINCS   Universal Journal Entry: Fields for Group Reporting
////////////////////////////////////////////////////////////////////////////
@ObjectModel.foreignKey.association: '_ConsolidationUnit'      
ConsolidationUnit,
@ObjectModel.foreignKey.association: '_PartnerConsolidationUnit'  
PartnerConsolidationUnit,
@ObjectModel.foreignKey.association: '_Company'  
Company, 
@ObjectModel.foreignKey.association: '_ConsolidationChartOfAccounts' 
ConsolidationChartOfAccounts,
@ObjectModel.foreignKey.association: '_CnsldtnFinancialStatementItem' 
CnsldtnFinancialStatementItem,
@ObjectModel.foreignKey.association: '_CnsldtnSubitemCategory' 
CnsldtnSubitemCategory,
@ObjectModel.foreignKey.association: '_CnsldtnSubitem' 
CnsldtnSubitem,  


///////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_GEN  Unified Journal Entry: Fields for several subledgers
//////////////////////////////////////////////////////////////////////////
InvoiceReference,
InvoiceReferenceFiscalYear,
FollowOnDocumentType,
InvoiceItemReference,
ReferencePurchaseOrderCategory,
PurchasingDocument,
PurchasingDocumentItem,
AccountAssignmentNumber,
DocumentItemText,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    'SalesDocument'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  'SalesDocument'
SalesOrder,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    'SalesDocumentItem'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  'SalesDocumentItem'
SalesOrderItem,
SalesDocument,
SalesDocumentItem,
@ObjectModel.foreignKey.association: '_Product'
Product,
@ObjectModel.foreignKey.association: '_ProductGroup_2'
ProductGroup,
@ObjectModel.foreignKey.association: '_Plant'
Plant,
Supplier,

//@ObjectModel.foreignKey.association: '_Customer'
Customer,
//@ObjectModel.readOnly:true
//@ObjectModel.virtualElement
//@ObjectModel.virtualElementCalculatedBy: 'ABAP:CL_BP_MULTI_ADDR_BF_CALC_EXIT'
//cast(' ' as fis_bpcustmultiaddr preserving type) as BPCustMultiAddrIsActive,

ServicesRenderedDate,
PerformancePeriodStartDate,
PerformancePeriodEndDate,

/////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_FI  Unified Journal Entry: Fields for FI subledgers
/////////////////////////////////////////////////////////////////////////
@ObjectModel.foreignKey.association: '_FinancialAccountType'
FinancialAccountType,
SpecialGLCode,
TaxCode,
HouseBank,
HouseBankAccount,
//@Semantics.booleanIndicator
IsOpenItemManaged,
ClearingDate,

@API.element.releaseState: #DEPRECATED
@API.element.successor:    'ClearingJournalEntry'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'ClearingJournalEntry' 
ClearingAccountingDocument,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    'ClearingJournalEntryFiscalYear'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'ClearingJournalEntryFiscalYear'
ClearingDocFiscalYear,

ClearingJournalEntry,
ClearingJournalEntryFiscalYear,

//@Semantics.booleanIndicator
//cast( ( case ClearingDate when '00000000' then cast( ' ' as abap.char(1))              
//                                          else cast( 'X' as abap.char(1))
//       end )
//as farp_xaugp ) as IsCleared,
cast( ( case ClearingDate when '00000000' then ' '               
                                          else 'X' 
       end )
as farp_xaugp preserving type ) as IsCleared,

ValueDate,
GeneralLedgerAgingScope,
GeneralLedgerAgingIncrement,

/////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_FAA  Unified Journal Entry: Fields for Asset Accounting
/////////////////////////////////////////////////////////////////////////
AssetDepreciationArea,
MasterFixedAsset,
FixedAsset,
AssetValueDate,
AssetTransactionType,
AssetAcctTransClassfctn,
DepreciationFiscalPeriod,
GroupMasterFixedAsset,
GroupFixedAsset,
AssetClass,


//////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_ML Unified Journal Entry: Fields for Material Ledger
//////////////////////////////////////////////////////////////////////////
CostEstimate,

@API.element.releaseState: #DEPRECATED
@API.element.successor:   'InvtrySpecialStockValnType_2'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'InvtrySpecialStockValnType_2'          
InventorySpecialStockValnType,   
@Analytics.internalName: #LOCAL            
InvtrySpecialStockValnType_2,

//xobew,
InventorySpecialStockType,
InventorySpclStkSalesDocument, //  as InventorySpecialStockSalesDocument,
InventorySpclStkSalesDocItm, //  as InventorySpecialStockSalesDocumentItem,
@API.element.releaseState: #DEPRECATED
@API.element.successor:   'InvtrySpclStockWBSElmntIntID'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'InvtrySpclStockWBSElmntIntID'
cast( InventorySpclStockWBSElement as fis_invspstock_wbs_no_conv_dep preserving type ) as InventorySpclStockWBSElement,              //open again at 15.11.22
InvtrySpclStockWBSElmntIntID,
InventorySpecialStockSupplier,
InventoryValuationType,
ValuationArea,

////////////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_CFIN   Unified Journal Entry: Fields for Central Finance
//////////////////////////////////////////////////////////////////////////////
SenderGLAccount,
SenderAccountAssignment,
SenderAccountAssignmentType,



////////////////////////////////////////////////////////////////////////////
//  .INCLUDE  ACDOC_SI_CO  Unified Journal Entry: CO fields
///////////////////////////////////////////////////////////////////////////
ControllingObject,
CostOriginGroup,
OriginSenderObject,
ControllingDebitCreditCode,
ControllingObjectDebitType,
//@Semantics.booleanIndicator
QuantityIsIncomplete,
OffsettingAccount,
OffsettingAccountType,
OffsettingChartOfAccounts,
//@Semantics.booleanIndicator
LineItemIsCompleted,
PersonnelNumber,
BillableControl,  
ControllingObjectClass,
PartnerCompanyCode,
PartnerControllingObjectClass,
OriginCostCenter,
OriginProfitCenter,
OriginCostCtrActivityType,
OriginProduct,
VarianceOriginGLAccount,
AccountAssignment,
@Analytics.internalName: #LOCAL    
@ObjectModel.foreignKey.association: '_AccountAssignmentType'
AccountAssignmentType,  
CostCtrActivityType,
OrderID,
OrderCategory,
WBSElementInternalID,    
@API.element.releaseState: #DEPRECATED
@API.element.successor:   'WBSElementInternalID'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'WBSElementInternalID'
cast( WBSElement as fis_wbs_no_conv_depre preserving type ) as WBSElement,              //open again at 15.11.22
@ObjectModel.foreignKey.association: '_WorkPackage' 
WorkPackage,
ProjectInternalID,
@API.element.releaseState: #DEPRECATED
@API.element.successor:   'ProjectInternalID'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'ProjectInternalID'
cast( Project as fis_project_no_conv_depre preserving type ) as Project,              //open again at 15.11.22
OperatingConcern,
ProjectNetwork,
RelatedNetworkActivity,
BusinessProcess,
CostObject,
//bemot,
@ObjectModel.foreignKey.association: '_CostAnalysisResource'
CostAnalysisResource,
CustomerServiceNotification,
ServiceDocumentType,
ServiceDocument,
ServiceDocumentItem,
ServiceContract,
ServiceContractType,
ServiceContractItem,
BusinessSolutionOrder,
BusinessSolutionOrderItem,
@ObjectModel.foreignKey.association: '_ProviderContract'
ProviderContract,
@ObjectModel.foreignKey.association: '_ProviderContractItem'
ProviderContractItem,
RevenueAccountingContract,
PerformanceObligation, 
@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_TimeSheetOvertimeCat'
TimeSheetOvertimeCategory,  
PartnerServiceDocumentType,
PartnerServiceDocument,
PartnerServiceDocumentItem,
PartnerAccountAssignment,
PartnerAccountAssignmentType,
PartnerCostCtrActivityType,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    'PartnerOrder_2'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  'PartnerOrder_2'
PartnerOrder,
PartnerOrder_2,
PartnerOrderCategory,
@API.element.releaseState: #DEPRECATED
@API.element.successor:   'PartnerWBSElementInternalID'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'PartnerWBSElementInternalID'
cast( PartnerWBSElement as fis_partner_wbs_no_conv_depre preserving type ) as PartnerWBSElement,              //open again at 15.11.22
@API.element.releaseState: #DEPRECATED
@API.element.successor:   'PartnerProjectInternalID'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: 'PartnerProjectInternalID'
cast( PartnerProject as fis_part_project_no_conv_depre preserving type ) as PartnerProject,              //open again at 15.11.22
PartnerSalesDocument,
PartnerSalesDocumentItem,
PartnerProjectNetwork,
PartnerProjectNetworkActivity,
PartnerBusinessProcess,
PartnerCostObject,
PartnerProjectInternalID,
PartnerWBSElementInternalID,
@ObjectModel.foreignKey.association: '_WorkPackageWorkItem' 
WorkItem,
VarianceOriginGroup,

//////////////////////////////////////////////////////////////////////
//  .INCLUDE  ACDOC_SI_COPA  Unified Journal Entry: CO-PA fields
//////////////////////////////////////////////////////////////////////
BillingDocumentType,
SalesOrganization,
DistributionChannel,
OrganizationDivision,
//SoldMaterial,                                        //do not use any longer, use SoldProduct
@ObjectModel.foreignKey.association: '_SoldProduct'
SoldProduct, 
//@ObjectModel.foreignKey.association: '_MaterialGroup'
//MaterialGroup,                                       //do not use any longer, use SoldProduct
@ObjectModel.foreignKey.association: '_SoldProductGroup_2'
SoldProductGroup,
@ObjectModel.foreignKey.association: '_CustomerGroup'
CustomerGroup,

CustomerSupplierCountry,
CustomerSupplierIndustry,
SalesDistrict,
BillToParty,
ShipToParty,
CustomerSupplierCorporateGroup,

//////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_PS  Unified Journal Entry: Fields for Public Sector
/////////////////////////////////////////////////////////////////////
@ObjectModel.foreignKey.association: '_CashLedgerCompanyCode'
CashLedgerCompanyCode,

@ObjectModel.foreignKey.association: '_CashLedgerAccount'
CashLedgerAccount,

      @Consumption.valueHelpDefinition: [ 
        { entity:  { name:    'I_FinMgmtAreaStdVH',
                     element: 'FinancialManagementArea' }
        }]
//      @ObjectModel.text.association: '_FinancialManagementAreaText'
@ObjectModel.foreignKey.association: '_FinancialManagementArea'
FinancialManagementArea,

CommitmentItem,

      @Consumption.valueHelpDefinition: [ 
        { entity:  { name:    'I_FundsCenterStdVH',
                     element: 'FundsCenter' },
          additionalBinding: [{ localElement: 'FinancialManagementArea',
                                element: 'FinancialManagementArea' }]
        }]
@ObjectModel.foreignKey.association: '_FundsCenter'
FundsCenter,

@ObjectModel.foreignKey.association: '_FundedProgram'
FundedProgram,

      @Consumption.valueHelpDefinition: [ 
        { entity:  { name:    'I_FundStdVH',
                     element: 'Fund' },
          additionalBinding: [{ localElement: 'FinancialManagementArea',
                                element: 'FinancialManagementArea' }]
        }]
//      @ObjectModel.text.association: '_FundText'
@ObjectModel.foreignKey.association: '_Fund'
Fund,

@ObjectModel.foreignKey.association: '_Grant'
GrantID,

      @Consumption.valueHelpDefinition: [ 
        { entity:  { name:    'I_BudgetPeriodStdVH',
                     element: 'BudgetPeriod' }
        }]
//      @ObjectModel.text.association: '_BudgetPeriodText'
@ObjectModel.foreignKey.association: '_BudgetPeriod'
BudgetPeriod,

      @Consumption.valueHelpDefinition: [ 
        { entity:  { name:    'I_FundStdVH',
                     element: 'Fund' },
          additionalBinding: [{ localElement: 'FinancialManagementArea',
                                element: 'FinancialManagementArea' }]
        }]
//      @ObjectModel.text.association: '_PartnerFundText'
@ObjectModel.foreignKey.association: '_PartnerFund'
PartnerFund,

@ObjectModel.foreignKey.association: '_PartnerGrant'
PartnerGrant,

@ObjectModel.foreignKey.association: '_PartnerBudgetPeriod'
PartnerBudgetPeriod,

@ObjectModel.foreignKey.association: '_PubSecBudgetAccount'
PubSecBudgetAccount,

@ObjectModel.foreignKey.association: '_PubSecBudgetAccountCoCode'
PubSecBudgetAccountCoCode,

@ObjectModel.foreignKey.association: '_PubSecBudgetCnsmpnDate'
PubSecBudgetCnsmpnDate,

@ObjectModel.foreignKey.association: '_PubSecBudgetCnsmpnFsclPeriod'
PubSecBudgetCnsmpnFsclPeriod,

@ObjectModel.foreignKey.association: '_PubSecBudgetCnsmpnFsclYear'
PubSecBudgetCnsmpnFsclYear,
//@Semantics.booleanIndicator 
PubSecBudgetIsRelevant,

@ObjectModel.foreignKey.association: '_PubSecBudgetCnsmpnType'
PubSecBudgetCnsmpnType,

@ObjectModel.foreignKey.association: '_PubSecBudgetCnsmpnAmtType'
PubSecBudgetCnsmpnAmtType,

@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_SponsoredProgram'
SponsoredProgram,

@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_SponsoredClass'
SponsoredClass,

EarmarkedFundsDocument,
EarmarkedFundsDocumentItem, 


///////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_FS  Universal Journal Entry: Fields for Financial Services
//
// these 3 fields are not in C-View (24.04.23)
// get via datasource extension -> FK  gives VH 
// text.association has no effect -> ID+ Text in one column not possible
// with text.element 2 independent columns  ID and text , but not in 1 column ID+Text
////////////////////////////////////////////////////////////////////////////////////////
@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_FinServicesProductGroup'
@ObjectModel.text.association: '_FinServicesProductGroupText'
@ObjectModel.text.control: #ASSOCIATED_TEXT_UI_HIDDEN
FinancialServicesProductGroup,

@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_FinancialServicesBranch'
@ObjectModel.text.association: '_FinancialServicesBranchText'
@ObjectModel.text.control: #ASSOCIATED_TEXT_UI_HIDDEN
FinancialServicesBranch,

@Analytics.internalName: #LOCAL
@ObjectModel.foreignKey.association: '_FinancialDataSource'
@ObjectModel.text.association: '_FinancialDataSourceText'
@ObjectModel.text.control: #ASSOCIATED_TEXT_UI_HIDDEN
FinancialDataSource,


///////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_JVA  Unified Journal Entry: Fields for Joint Venture Accounting
///////////////////////////////////////////////////////////////////////
JointVenture,
JointVentureEquityGroup,
JointVentureCostRecoveryCode,
JointVenturePartner,
JointVentureBillingType,
JointVentureEquityType,
JointVentureProductionDate,
JointVentureBillingDate,
JointVentureOperationalDate,
CutbackRun,
JointVentureAccountingActivity,
PartnerVenture,
PartnerEquityGroup,
SenderCostRecoveryCode,
CutbackAccount,
CutbackCostObject, 

///////////////////////////////////////////////////////////////////////
// .INCLUDE ACDOC_SI_RE STRU  0 0 Unified Journal Entry: Fields for Real Estate
///////////////////////////////////////////////////////////////////////
REBusinessEntity,
RealEstateBuilding,
RealEstateProperty,
RERentalObject,
RealEstateContract,                        
REServiceChargeKey,
RESettlementUnitID,
SettlementReferenceDate,
REPartnerBusinessEntity,
RealEstatePartnerBuilding,
RealEstatePartnerProperty,
REPartnerRentalObject,
RealEstatePartnerContract,
REPartnerServiceChargeKey,
REPartnerSettlementUnitID,
PartnerSettlementReferenceDate,

 ///////////////////////////////////////////////////////////////////////
 // .INCLUDE ACDOC_SI_ACR STRU  0 0 Universal Journal Entry: Fields for Accrual object
 ///////////////////////////////////////////////////////////////////////     
//   AccrualObject      --(1:N)-->  AccrualSubobject  --(1:N)-->  Accrual(Subobject)Item (this field is not stored in ACDOCA)
//   AccrualObjectType                                            AccrualItemType  are the corresponding types 
//@ObjectModel.foreignKey.association: '_AccrualObjectType'
AccrualObjectType,
AccrualObjectLogicalSystem,
//@ObjectModel.foreignKey.association: '_AccrualObject'
AccrualObject,
//@ObjectModel.foreignKey.association: '_AccrualSubobject'
AccrualSubobject,
//@ObjectModel.foreignKey.association: '_AccrualItemType'
AccrualItemType, 
AccrualReferenceObject,
AccrualValueDate,


///////////////////////////////////////////////////////////////////////
 // .INCLUDE ACDOC_SI_VAL STRU  0 0 Universal Journal Entry: Fields for Fin. Valuation Object
 ///////////////////////////////////////////////////////////////////////    
FinancialValuationObjectType,
FinancialValuationObject,
FinancialValuationSubobject,
NetDueDate,
CreditRiskClass,


//////////////////////////////////////////////////////////////////////////
// .INCLUDE  ACDOC_SI_TECH:  Universal Journal Entry: Technical Fields  //
////////////////////////////////////////////////////////////////////////// 
JrnlEntryItemMigrationSource,


@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} } 
DebitAmountInCoCodeCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} } 
CreditAmountInCoCodeCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'TransactionCurrency'} } 
DebitAmountInTransCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'TransactionCurrency'} } 
CreditAmountInTransCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'BalanceTransactionCurrency'} } 
DebitAmountInBalanceTransCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'BalanceTransactionCurrency'} } 
CreditAmountInBalanceTransCrcy,


////////////////////////////////////
// NEW
@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} } 
DebitAmountInGlobalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'GlobalCurrency'} } 
CreditAmountInGlobalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FunctionalCurrency'} } 
DebitAmountInFunctionalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FunctionalCurrency'} } 
CreditAmountInFunctionalCrcy,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency1'} } 
DebitAmountInFreeDfndCrcy1 as DebitAmountInFreeDfndCrcy1,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency1'} } 
CreditAmountInFreeDfndCrcy1 as CreditAmountInFreeDfndCrcy1,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency2'} } 
DebitAmountInFreeDfndCrcy2 as DebitAmountInFreeDfndCrcy2,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency2'} } 
 CreditAmountInFreeDfndCrcy2,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency3'} } 
 DebitAmountInFreeDfndCrcy3,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency3'} } 
 CreditAmountInFreeDfndCrcy3,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency4'} }
 DebitAmountInFreeDfndCrcy4,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency4'} }
 CreditAmountInFreeDfndCrcy4,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency5'} }
 DebitAmountInFreeDfndCrcy5,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency5'} }
 CreditAmountInFreeDfndCrcy5,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency6'} }
 DebitAmountInFreeDfndCrcy6,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency6'} }
 CreditAmountInFreeDfndCrcy6,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency7'} }
 DebitAmountInFreeDfndCrcy7,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency7'} }
 CreditAmountInFreeDfndCrcy7,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency8'} }
 DebitAmountInFreeDfndCrcy8,

@DefaultAggregation: #SUM
@Semantics: { amount : {currencyCode: 'FreeDefinedCurrency8'} }
 CreditAmountInFreeDfndCrcy8,
//////////////////////////////////

  @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
//    case FinancialAccountType when 'S' then cast(DebitAmountInCoCodeCrcy as fis_sdr_hsl) 
//                                       else cast( cast( '0' as abap.curr( 23,2))  as fis_sdr_hsl)
//    end as GLDebitAmountInCoCodeCrcy,
    case FinancialAccountType when 'S' then cast( DebitAmountInCoCodeCrcy as fis_sdr_hsl preserving type )
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_sdr_hsl preserving type )
    end 
    as GLDebitAmountInCoCodeCrcy,    
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
//    case FinancialAccountType when 'A' then cast(DebitAmountInCoCodeCrcy as fis_adr_hsl) 
//                        else cast( cast( '0' as abap.curr( 23,2)) as fis_adr_hsl)
//    end as AssetDebitAmtInCoCodeCrcy,
    case FinancialAccountType when 'A' then cast( DebitAmountInCoCodeCrcy as fis_adr_hsl preserving type )
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_adr_hsl preserving type )
    end
    as AssetDebitAmtInCoCodeCrcy,    
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'M' then cast( DebitAmountInCoCodeCrcy as fis_mdr_hsl preserving type )
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_mdr_hsl preserving type )
    end
    as MaterialDebitAmtInCoCodeCrcy,
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'D' then cast( DebitAmountInCoCodeCrcy as fis_ddr_hsl preserving type )
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_ddr_hsl preserving type )
    end 
    as DebtorDebitAmtInCoCodeCrcy,
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'K' then cast( DebitAmountInCoCodeCrcy as fis_kdr_hsl preserving type ) 
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_kdr_hsl preserving type ) 
    end 
    as CreditorDebitAmtInCoCodeCrcy,

    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'S' then cast( CreditAmountInCoCodeCrcy as fis_scr_hsl preserving type ) 
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_scr_hsl preserving type ) 
    end
    as GLCreditAmountInCoCodeCrcy,
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'A' then cast( CreditAmountInCoCodeCrcy as fis_acr_hsl preserving type )  
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_acr_hsl preserving type )  
    end
    as AssetCreditAmtInCoCodeCrcy,
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'M' then cast( CreditAmountInCoCodeCrcy as fis_mcr_hsl preserving type ) 
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_mcr_hsl preserving type ) 
    end 
    as MaterialCreditAmtInCoCodeCrcy,
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'D' then cast( CreditAmountInCoCodeCrcy as fis_dcr_hsl preserving type )
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_dcr_hsl preserving type )
    end
    as DebtorCreditAmtInCoCodeCrcy,
    
    @DefaultAggregation: #SUM
    @Semantics: { amount : {currencyCode: 'CompanyCodeCurrency'} }
    case FinancialAccountType when 'K' then cast( CreditAmountInCoCodeCrcy as fis_kcr_hsl preserving type )   
                                       else cast( cast( 0 as abap.curr( 23,2) ) as fis_kcr_hsl preserving type )   
    end 
    as CreditorCreditAmtInCoCodeCrcy,

//@Semantics.booleanIndicator
IsStatisticalOrder,  
//@Semantics.booleanIndicator
IsStatisticalCostCenter,  
//@Semantics.booleanIndicator
IsStatisticalSalesDocument,
//@Semantics.booleanIndicator
WBSIsStatisticalWBSElement,  

@DefaultAggregation: #SUM
NumberOfItems, 

cast($parameters.P_ClearingStatusSelection as fis_clearingstatusselection preserving type ) as ClearingStatusSelection,


//$extension.*,

//_WBSElementInternalID,
//_WBSElementExternalID,
_WBSElementBasicData,
//_WBSElement,
//_ProjectInternalID,
//_ProjectExternalID,
_ProjectBasicData,
//_Project,

_JournalEntry,
_CompanyCode,
_FiscalYear,
_LedgerCompanyCodeCrcyRoles,
//_FiscalPeriod,
//_LedgerFiscalYear,
_FiscalYearVariant,
_FiscalPeriodForVariant,
_LedgerFiscalYearForVariant,
_ControllingArea,
_BalanceTransactionCurrency,
_TransactionCurrency,
_CompanyCodeCurrency,
_GlobalCurrency,
_FunctionalCurrency,
_FreeDefinedCurrency1,
_FreeDefinedCurrency2,
_FreeDefinedCurrency3,
_FreeDefinedCurrency4,
_FreeDefinedCurrency5,
_FreeDefinedCurrency6,
_FreeDefinedCurrency7,
_FreeDefinedCurrency8,
_BaseUnit,
_CostSourceUnit,
_AdditionalQuantity1Unit,
_AdditionalQuantity2Unit,
_AdditionalQuantity3Unit,
_IncmpltSummableValnQtyUnt,
_Segment,
_ProfitCenter,
_CurrentProfitCenter,
_CostCenter,
_CurrentCostCenter,
_CostAnalysisResource,
_AccountAssignmentType,
_BusinessArea,
_FunctionalArea,
_GLAccountInChartOfAccounts,
_GLAccountInCompanyCode,
_ChartOfAccounts,
_AccountingDocumentType,
_FinancialAccountType,
_DebitCreditCode, 
//_Material,
//_MaterialGroup,
_Product,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_ProductGroup_2'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_ProductGroup_2'
_ProductGroup,
_ProductGroup_2,
_Plant,
_WorkPackageWorkItem,
_WorkPackage,
_Ledger,
_SourceLedger,

_Customer,
_CustomerCompany,
_CustomerGroup,

_Supplier,
_SupplierCompany,

//_SalesOrder,
//_SalesOrderItem,
_SalesDocument,
_SalesDocumentItem,

_InternalOrder,
_Order,

@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_PersonWorkAgreement_1'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_PersonWorkAgreement_1'
_Employment,
_PersonWorkAgreement_1,
_BillableControl,

//_Extension  Extensions must be local

_FinancialTransactionType,
_BusinessTransactionCategory,
_BusinessTransactionType,
_ReferenceDocumentType,
_PredecessorReferenceDocType,

_PartnerCostCenter,
_PartnerProfitCenter,
_PartnerBusinessArea,
_PartnerFunctionalArea,
_PartnerCompanyCode,
_PartnerSegment,

_AccountingDocumentCategory,

_PostingKey,

_SubLedgerAccLineItemType,

_User,

_EliminationProfitCenter,

_ControllingObject,

_GLAccountType,
_AlternativeGLAccount,
//_SenderGLAccount,
_CountryChartOfAccounts,

_PurchasingDocument,
_PurchasingDocumentItem,

_SpecialGLCode,
_TaxCode,

_HouseBank,

_ClearingJrnlEntryFiscalYear,
_ClearingJournalEntry,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_ClearingJournalEntry'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: '_ClearingJournalEntry'
_ClearingAccountingDocument,

_MasterFixedAsset,
_GroupMasterFixedAsset,
_FixedAsset,
_GroupFixedAsset,

@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_InventorySpclStockValnType'
@VDM.lifecycle.status:    #DEPRECATED
@VDM.lifecycle.successor: '_InventorySpclStockValnType'
_InventorySpecialStockValnType,
_InventorySpclStockValnType, 

_InventorySpecialStockType,
_InventorySpclStkSalesDocument,
_InventorySpclStkSalesDocItm,
//_InventorySpclStockWBSElement,
_InvtrySpclStkWBSElmntBscData,
_InventorySpecialStockSupplier,
_InventoryValuationType,
_OriginSenderObject,
_ControllingObjectClass,
_PartnerControllingObjectClass,
_OriginCostCenter,
_OriginProfitCenter,
_CostCtrActivityType,
_OriginCostCtrActivityType,
_OrderCategory,
//_RelatedNetworkActivity,
//_PartnerProjectNetworkActivity,

_BusinessProcess,
_PartnerCostCtrActivityType,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_PartnerOrder_2'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_PartnerOrder_2'
_PartnerOrder,
_PartnerOrder_2,
_PartnerOrderCategory,
_PartnerWBSElementBasicData,
//_PartnerWBSElement,
_PartnerProjectBasicData,
//_PartnerProject,
_PartnerSalesDocument,
_PartnerSalesDocumentItem,
_PartnerBusinessProcess,

_BillingDocumentType,

_SalesOrganization,
_DistributionChannel,

_SoldProduct,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_SoldProductGroup_2'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_SoldProductGroup_2'
_SoldProductGroup,
_SoldProductGroup_2,

_Fund,
_PartnerFund,
_FundsCenter,

_MovementCategory,
_AssetTransactionType,

_BudgetPeriod,

_CostOriginGroup,

_FinancialManagementArea,
//_FundedProgram

_HouseBankAccount,

_LogicalSystem,

_OperatingConcern,

_PartnerCompany,

_ProjectNetwork,

_PurReqValuationArea,
_OffsettingAccountType,
_OffsettingChartOfAccounts,
_OffsettingAccount,
_OffsettingAccountWithBP,
_LedgerText,
_DebitCreditCodeText,
_FunctionalAreaText,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_ProfitCenterTxt'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_ProfitCenterTxt'
_ProfitCenterText,
_ProfitCenterTxt,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_CostCenterTxt'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_CostCenterTxt'
_CostCenterText,
_CostCenterTxt,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_GLAccountTxt'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_GLAccountTxt'
_GLAccountText,
_GLAccountTxt,
_BusinessAreaText,
_SegmentText,
_AccountingDocumentTypeText,
_SupplierText,
_ControllingAreaText,
_CustomerText,
_CompanyCodeText,
_OffsettingAccountText,
_MasterFixedAssetText,
@API.element.releaseState: #DEPRECATED
@API.element.successor:    '_PartnerOrderText_2'
@VDM.lifecycle.status:     #DEPRECATED
@VDM.lifecycle.successor:  '_PartnerOrderText_2'
_PartnerOrderText,
_PartnerOrderText_2,
_GroupMasterFixedAssetText,

//_ProjectText,
_ServiceDocumentType,
_ServiceDocument,
_ServiceDocumentItem,
_ServiceContract,
_ServiceContractType,
_ServiceContractItem,
_TimeSheetOvertimeCat,
_PartnerServiceDocumentType,
_PartnerServiceDocument,
_PartnerServiceDocumentItem,

//_PartnerProjectBasicDataText,
//_PartnerWBSElemntBasicDataText,

_AccrualObjectType,
_AccrualObject,
_AccrualSubobject,
_AccrualItemType,

_CreditRiskClass,
_FinValuationObjectType,

_CashLedgerCompanyCode,
_CashLedgerAccount,
_FundedProgram,
_Grant,
_PartnerGrant,
_PartnerBudgetPeriod,
_PubSecBudgetAccountCoCode,
_PubSecBudgetAccount,
_PubSecBudgetCnsmpnDate,
_PubSecBudgetCnsmpnFsclPeriod,
_PubSecBudgetCnsmpnFsclYear,
_PubSecBudgetCnsmpnType,
_PubSecBudgetCnsmpnAmtType,
_SponsoredProgram,
_SponsoredClass,

_ConsolidationUnit,
_PartnerConsolidationUnit,
_Company,
_ConsolidationChartOfAccounts,
_CnsldtnFinancialStatementItem,
_CnsldtnSubitemCategory,
_CnsldtnSubitem, 

_ProviderContract,
_ProviderContractItem,

_FinServicesProductGroup,
_FinServicesProductGroupText,
_FinancialServicesBranch,
_FinancialServicesBranchText,
_FinancialDataSource,
_FinancialDataSourceText,
_CustomerSupplierIndustry,
_CustomerSupplierCountry  

}
