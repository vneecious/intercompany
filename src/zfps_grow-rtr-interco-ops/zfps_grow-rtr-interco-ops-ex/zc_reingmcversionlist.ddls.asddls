@EndUserText.label: 'MC - Metric Version List (IBN)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZC_ReingMCVersionList
  as select from ZI_ReingMCVersionList
{
  key MetricCode,
  key VersionNum,
      VersionStatus,
      ValidFrom,
      ValidTo,
      ChangeReason,
      CreatedBy,
      CreatedAt,
      case VersionStatus
        when 'A' then 3
        when 'D' then 2
        when 'I' then 1
        else 0
      end as StatusCriticality
}
