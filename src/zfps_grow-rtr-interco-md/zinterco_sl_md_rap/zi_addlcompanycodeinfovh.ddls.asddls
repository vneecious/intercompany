@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Companies Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel: { dataCategory: #VALUE_HELP,
                representativeKey: 'CompanyCodeParameterType',
                usageType.sizeCategory: #S,
                usageType.dataClass: #ORGANIZATIONAL,
                usageType.serviceQuality: #A,
                supportedCapabilities: [#VALUE_HELP_PROVIDER, #SEARCHABLE_ENTITY],
                modelingPattern: #VALUE_HELP_PROVIDER }
define view entity ZI_AddlCompanyCodeInfoVH
  as select distinct from I_AddlCompanyCodeInformation
{
      @UI.hidden: true
  key CompanyCodeParameterType,
      @Semantics.text: true
      @Search: { defaultSearchElement: true, fuzzinessThreshold: 0.8, ranking: #HIGH }
  key CompanyCodeParameterValue
}
