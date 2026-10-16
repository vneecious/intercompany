@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Companies Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel: { dataCategory: #VALUE_HELP,
                representativeKey: 'CompanyCode',
                usageType.sizeCategory: #S,
                usageType.dataClass: #ORGANIZATIONAL,
                usageType.serviceQuality: #A,
                supportedCapabilities: [#VALUE_HELP_PROVIDER, #SEARCHABLE_ENTITY],
                modelingPattern: #VALUE_HELP_PROVIDER }
define root view entity ZI_intercoCompanyCodeVH
  provider contract transactional_query
  as projection on ZI_IntercoCompanyCode
  association [0..1] to I_Currency as _Currency on $projection.Currency = _Currency.Currency
  association [0..1] to I_Country  as _Country  on $projection.Country = _Country.Country
  association [0..1] to I_Language as _Language on $projection.Language = _Language.Language
{
      @ObjectModel.text.element: ['CompanyCodeName']
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Search.ranking: #HIGH
  key CompanyCode,
      @Semantics.text: true
      @Search: { defaultSearchElement: true, fuzzinessThreshold: 0.8, ranking: #LOW }
      @UI.selectionField: [{ exclude: true }]
      CompanyCodeName,
      @Search: { defaultSearchElement: true, ranking: #LOW }
      @ObjectModel.foreignKey.association: '_Country'
      Country,
      @Search: { defaultSearchElement: true, ranking: #LOW }
      @UI.selectionField: [{ exclude: true }]
      CountryName,
      @Search: { defaultSearchElement: true, ranking: #MEDIUM }
      SiteCode,
      @Search: { defaultSearchElement: true, fuzzinessThreshold: 0.8, ranking: #MEDIUM }
      @UI.selectionField: [{ exclude: true }]
      SiteName,
      @Search: { defaultSearchElement: true, ranking: #LOW }
      @ObjectModel.foreignKey.association: '_Currency'
      @UI.selectionField: [{ exclude: true }]
      Currency,
      @ObjectModel.foreignKey.association: '_Language'
      @UI.selectionField: [{ exclude: true }]
      Language,
      /* Associations */
      @Consumption.hidden: true
      _AdditionalInfo,
      @Consumption.hidden: true
      _Country,
      @Consumption.hidden: true
      _Currency,
      @Consumption.hidden: true
      _Language
}
