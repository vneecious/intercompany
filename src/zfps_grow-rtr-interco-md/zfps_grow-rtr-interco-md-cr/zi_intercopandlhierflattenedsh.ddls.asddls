@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for ZI_IntercoPandLHierFlattened'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #M,
    dataClass: #MIXED
}
@Search.searchable: true
define view entity ZI_IntercoPandLHierFlattenedSH
  as select from ZI_IntercoPandLHierFlattened
{
      @UI.selectionField: [{ position: 10 }]
      @ObjectModel.text.element: [ 'Text' ]
      @Search: {
      defaultSearchElement: true,
      fuzzinessThreshold: 0.8,
      ranking: #LOW }
  key ID,
      @EndUserText.label: '{@i18n>PandLLevel}'
      @UI.selectionField: [{ position: 20 }]
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_DomainFixedValueVH', element: 'value_low' },
        additionalBinding: [{ element: 'domain_name', localConstant: 'ZINT_PANLLVL', usage: #FILTER }],
        distinctValues: true
      }]
      CustomerLevel,
      @UI.selectionField: [{ exclude: true }]
      @EndUserText.label: '{@i18n>PandLText}'
      @Search: {
      defaultSearchElement: true,
      fuzzinessThreshold: 0.9,
      ranking: #LOW }
      Text,
      @ObjectModel.text.association: '_L0'
      @UI.selectionField: [{ exclude: true }]
      @UI.hidden: true
      IDL0,
      @UI.selectionField: [{ exclude: true }]
      @ObjectModel.text.association: '_L1'
      @UI.hidden: true
      IDL1,
      @UI.selectionField: [{ exclude: true }]
      @ObjectModel.text.association: '_L2'
      @UI.hidden: true
      IDL2,
      @UI.selectionField: [{ exclude: true }]
      @ObjectModel.text.association: '_L3'
      @UI.hidden: true
      IDL3,
      @UI.selectionField: [{ exclude: true }]
      @ObjectModel.text.association: '_L4'
      @UI.hidden: true
      IDL4,
      @UI.selectionField: [{ exclude: true }]
      @ObjectModel.text.association: '_L5'
      @UI.hidden: true
      IDL5,
      /* Associations */
      _L0,
      _L1,
      _L2,
      _L3,
      _L4,
      _L5
}
