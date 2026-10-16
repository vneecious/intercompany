@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Version List per Metric (IBN)'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #MIXED
@Metadata.allowExtensions: true

define view entity ZI_ReingMCVersionList
  as select from zreing_mcv_a
  association [0..1] to ZI_ReingMCVerStatus as _VerStatus
    on _VerStatus.VersionStatus = zreing_mcv_a.version_status
{
  key metric_code    as MetricCode,
  key version_num    as VersionNum,

      @ObjectModel.text.association: '_VerStatus'
      version_status as VersionStatus,

      valid_from     as ValidFrom,
      valid_to       as ValidTo,
      change_reason  as ChangeReason,
      created_by     as CreatedBy,
      created_at     as CreatedAt,

      case version_status
        when 'A' then 3
        when 'D' then 5
        when 'I' then 0
        else 0
      end            as StatusCriticality,

      _VerStatus
}
