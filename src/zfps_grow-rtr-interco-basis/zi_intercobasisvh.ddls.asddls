@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for ZI_intercoBasisFlat'
@AbapCatalog.viewEnhancementCategory: [#NONE]
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #L,
    dataClass: #MIXED
}
@Search.searchable: true
define view entity ZI_IntercoBasisVH
  as select distinct from ZI_INTERCOBASIS
{

      @Semantics.uuid: true
      @ObjectModel.text.element: ['Description']
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key Id,
      @Consumption.filter.multipleSelections: false
      @Consumption.filter.selectionType: #SINGLE
      @UI.selectionField: [{ position: 10 }]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_intercoCompanyCodeVH', element: 'CompanyCode' } } ]
      @Search.fuzzinessThreshold: 0.8
  key CompanyCode                                                              as CompanyCode,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_FISCALYEAR1', element: 'FiscalYear' },
                                              distinctValues: true } ]
      @Consumption.filter.multipleSelections: false
      @Consumption.filter.selectionType: #SINGLE
      @UI.selectionField: [{ position: 20 }]
  key FiscalYear,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'zc_poper_vh', element: 'Poper' },
                                              additionalBinding: [ { element: 'FiscalYear',
                                                                     localElement: 'Fiscalyear',
                                                                     usage: #FILTER_AND_RESULT } ] } ]
      @Consumption.filter.multipleSelections: false
      @Consumption.filter.selectionType: #SINGLE
      @UI.selectionField: [{ position: 30 }]
  key FiscalPeriod,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'zi_ledger_sh', element: 'Rldnr' } } ]
      @Consumption.filter.multipleSelections: false
      @Consumption.filter.selectionType: #SINGLE
      @UI.selectionField: [{ position: 40 }]
  key Ledger,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'zi_read_dom_paymenttype', element: 'value' },
                                          distinctValues: true } ]
      @Consumption.filter.multipleSelections: false
      @Consumption.filter.selectionType: #SINGLE
      @UI.selectionField: [{ position: 50 }]
  key PaymentType,
      @UI.selectionField: [{exclude: true}]
      @UI.lineItem: [{ exclude: true }]
      @Consumption.filter.multipleSelections: false
      @EndUserText.label: '{@i18n>IsReleased}'
      IsReleased,
      @UI.selectionField: [{ position: 60 }]
      @Consumption.filter.defaultValue: 'X'
      @Consumption.filter.multipleSelections: false
      @EndUserText.label: '{@i18n>IsPending}'
      cast( case when IsReleased = 'X' then ' ' else 'X' end as abap_boolean ) as IsPending,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Search.fuzzinessThreshold: 0.8
      Description
}
where
  ExecutionStatus = 'COMPLETED'
