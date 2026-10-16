@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Metric Type Determination Rule'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
define view entity ZI_IntercoMetricDetermination
  as select from zint_a_md_metric
{
  key id                    as ID,
      valid_from            as ValidFrom,
      valid_to              as ValidTo,
      provider_company_code as ProviderCompanyCode,
      product               as Product,
      payment_type          as PaymentType,
      metric                as Metric,
      is_deleted            as IsDeleted,
      created_at            as CreatedAt,
      created_by            as CreatedBy,
      last_changed_at       as LastChangedAt,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_by       as LastChangedBy
}
