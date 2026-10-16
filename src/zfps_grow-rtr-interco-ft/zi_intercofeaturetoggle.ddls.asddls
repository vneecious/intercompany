@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Feature Toggle'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoFeatureToggle
  as select from zint_a_feature
{
  key      company_code          as CompanyCode,
  key      feature               as Feature,
           enabled               as Enabled,
           validfrom             as Validfrom,
           product               as Product,
           pandlid               as PandLId,
           created_at            as CreatedAt,
           created_by            as CreatedBy,
           last_changed_at       as LastChangedAt,
           local_last_changed_at as LocalLastChangedAt,
           last_changed_by       as LastChangedBy
}
