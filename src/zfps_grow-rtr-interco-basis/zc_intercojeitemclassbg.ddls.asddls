@AccessControl.authorizationCheck: #NOT_ALLOWED

@EndUserText.label: 'Intercompany journal Entry Class'
@ObjectModel: { representativeKey: 'LedgerGLLineItem',
                usageType.sizeCategory: #XXL,
                usageType.dataClass:  #TRANSACTIONAL }
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_INTERCO_JEITEM_CLASS'
define root view entity ZC_INTERCOJEITEMCLASSBG
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

    P_PaymentType  : zint_dte_paymenttype
  as select from ZI_IntercoJEItemClassBGResult
  association [1..1] to ZI_IntercoJEItemClassBG        as _Header           on  _Header.ID = ZI_IntercoJEItemClassBGResult.ID
  association [0..1] to ZI_INTERCOFEATURETOGGLEEnabled as _FeatureToggle    on  1 = 1
  association [0..1] to ZI_IntercoBasisItem            as _CurrentBasisItem on  _CurrentBasisItem.Ledger              = $projection.Ledger
                                                                            and _CurrentBasisItem.Glaccount           = $projection.Glaccount
                                                                            and _CurrentBasisItem.Costcenter          = $projection.Costcenter
                                                                            and _CurrentBasisItem.Fiscalyear          = $projection.Fiscalyear
                                                                            and _CurrentBasisItem.Fiscalperiod        = $projection.Fiscalperiod
                                                                            and _CurrentBasisItem.Providercompanycode = $projection.Companycode
                                                                            and _CurrentBasisItem.Profitcenter        = $projection.Profitcenter
                                                                            and $projection.Creationdatetime          between _CurrentBasisItem.MinDateTime and _CurrentBasisItem.MaxDateTime
                                                                            and _CurrentBasisItem.ExecutionStatus     =       'COMPLETED'
{
  key Sourceledger,
  key Companycode,
  key Fiscalyear,
  key Fiscalperiod,
  key Accountingdocument,
  key Ledgergllineitem,
  key Ledger,

      Glaccount,
      Chartofaccounts,
      Segment,
      Accountingdocumenttype,
      Accountingdocumentitem,
      Postingdate,
      Debitcreditcode,
      Accountingdocumentcategory,
      Ledgerfiscalyear,
      Creationdatetime,
      Clearingaccountingdocument,
      Clearingjournalentry,
      Controllingarea,
      Clearingdate,
      Clearingdocfiscalyear,
      Clearingjournalentryfiscalyear,
      Isopenitemmanaged,
      Transactioncurrency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Amountintransactioncurrency,

      Companycodecurrency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      Amountincompanycodecurrency,

      Globalcurrency,

      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      Amountinglobalcurrency,

      Costcenter,
      Profitcenter,
      Creationdate,
      Fiscalyearperiod,
      PaymentType,

      @ObjectModel.text.element: [ 'PandLL0Name' ]
      @UI.textArrangement: #TEXT_LAST
      Pandll0id,
      Pandll0name,

      @UI.textArrangement: #TEXT_LAST
      Pandll1id,
      Pandll1name,

      @ObjectModel.text.element: [ 'PandLL2Name' ]
      @UI.textArrangement: #TEXT_LAST
      Pandll2id,
      Pandll2name,

      @ObjectModel.text.element: [ 'PandLL3Name' ]
      @UI.textArrangement: #TEXT_LAST
      Pandll3id,
      Pandll3name,

      @ObjectModel.text.element: [ 'PandLL4Name' ]
      @UI.textArrangement: #TEXT_LAST
      Pandll4id,
      Pandll4name,

      @ObjectModel.text.element: [ 'PandLL5Name' ]
      @UI.textArrangement: #TEXT_LAST
      Pandll5id,
      Pandll5name,

      Costcenterstandardhierarea,
      @EndUserText.label: 'Campana'
      Campana,
      @EndUserText.label: 'AREA'
      Area,
      Ccallocation,
      Ccconsolidation,
      Pcconsolidation,
      @ObjectModel.text.element: [ 'DepartmentName' ]
      @UI.textArrangement: #TEXT_LAST
      Department,
      Departmentname,
      /**
      * Classification Rule
      **/
      @ObjectModel.text.element: ['RuleName']
      Ruleid,
      Rulename,
      Isnotbillablefrommasterdata,
      @ObjectModel.text.element: [ 'ConceptName' ]
      @UI.textArrangement: #TEXT_LAST
      Concept,
      Conceptname,
      Classificationexemptionid,
      Classificationexemptionextid,
      Isnotbillablefromexemption,
      @Consumption.valueHelpDefinition: [{
      entity: { name: 'ZI_DomainFixedValueVH', element: 'value_low' },
      additionalBinding: [{ element: 'domain_name', localConstant: 'ZINT_BILLABLE_STATUS', usage: #FILTER }],
      distinctValues: true
      }]
      @ObjectModel.text.element: [ 'IsBillableText' ]
      Isbillable,
      Isbillabletext,
      @ObjectModel.filter.enabled: false
      Isbillablecriticality,

      /**
      * Basis
      **/
      @UI.textArrangement: #TEXT_FIRST
      @ObjectModel.text.element: ['DescriptionBase']
      @Semantics.uuid: true
      _CurrentBasisItem.Id                  as IdBase,
      _CurrentBasisItem._header.Description as DescriptionBase,
      _CurrentBasisItem._header.IsReleased  as IsReleased,
      Isdelta,

      @UI.lineItem: [ { label: 'SAP Entity' } ]
      @ObjectModel.filter.enabled: false
      Indexcompanycode,
      @UI.lineItem: [ { label: 'Allocation' } ]
      @ObjectModel.filter.enabled: false
      Indexallocation,
      @UI.lineItem: [ { label: 'Consolidation' } ]
      @ObjectModel.filter.enabled: false
      Indexconsolidation,
      @UI.lineItem: [ { label: 'AREA 2' } ]
      @ObjectModel.filter.enabled: false
      area_2,
      @UI.lineItem: [ { label: 'Business Unit' } ]
      @ObjectModel.filter.enabled: false
      Indexbusinessunit,
      @UI.lineItem: [ { label: 'PYL 0' } ]
      @ObjectModel.filter.enabled: false
      Indexpyl0,
      @UI.lineItem: [ { label: 'PYL 1' } ]
      @ObjectModel.filter.enabled: false
      Indexpyl1,
      @UI.lineItem: [ { label: 'PYL CLASIFICADO' } ]
      @ObjectModel.filter.enabled: false
      Indexpylclasificado,
      @UI.lineItem: [ { label: 'Cost Center' } ]
      @ObjectModel.filter.enabled: false
      Indexcostcenter,
      @UI.lineItem: [ { label: 'Account Nro' } ]
      @ObjectModel.filter.enabled: false
      Indexaccountnro,
      @UI.lineItem: [ { label: 'Month' } ]
      @ObjectModel.filter.enabled: false
      Indexmonth,
      @Aggregation.default: #SUM
      @UI.lineItem: [ { label: 'Total' } ]
      @Semantics.amount.currencyCode: 'GlobalCurrency'
      @ObjectModel.filter.enabled: false
      Indextotal,
      @UI.lineItem: [ { label: 'Facturación' } ]
      @ObjectModel.filter.enabled: false
      Indexfacturacion
}
where
      _Header.Companycode  = $parameters.P_CompanyCode
  and _Header.Ledger       = $parameters.P_Ledger
  and _Header.Fiscalyear   = $parameters.P_FiscalYear
  and _Header.Fiscalperiod = $parameters.P_FiscalPeriod
  and _Header.PaymentType  = $parameters.P_PaymentType
