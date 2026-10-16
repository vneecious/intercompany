@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Feature Toggle'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_INTERCOFEATURETOGGLEEnabled
  with parameters
    P_CompanyCode : bukrs,
    P_Feature     : abap.char(25)
  as select from ZI_IntercoFeatureToggle as Specific
{
  key Specific.CompanyCode,
  key Specific.Feature,
      Specific.Enabled,
      Specific.Validfrom
}
where
      Specific.Feature     = $parameters.P_Feature
  and Specific.Enabled     = 'X'
  and Specific.CompanyCode = $parameters.P_CompanyCode

union all

(
  select from       ZI_IntercoFeatureToggle as Generic
    left outer join ZI_IntercoFeatureToggle as Specific on  Specific.Feature     = Generic.Feature
                                                        and Specific.CompanyCode = $parameters.P_CompanyCode
                                                        and Specific.Enabled     = 'X'
  {
    key $parameters.P_CompanyCode as CompanyCode,
    key Generic.Feature,
        Generic.Enabled,
        Generic.Validfrom
  }
  where
        Generic.Feature     = $parameters.P_Feature
    and Generic.Enabled     = 'X'
    and Generic.CompanyCode = ''
    and Specific.Feature    is null
);
