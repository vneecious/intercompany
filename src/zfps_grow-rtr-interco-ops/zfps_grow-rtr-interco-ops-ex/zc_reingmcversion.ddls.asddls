@EndUserText.label: 'MC - Metric Version Root Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define root view entity ZC_ReingMCVersion
  provider contract transactional_query
  as projection on ZI_ReingMCVersion
{
  key MetricCode,
  key VersionNum,
      MetricDesc,
      MetricType,
      DataSource,
      Responsible,
      VersionStatus,
      DataSourceVer,
      ChangeReason,
      ValidFrom,
      ValidTo,
      VarPctLimit,
      IsNewVersion,
      MetricStatus,
      LastVersNum,
      IsLatestVersion,
      StatusCriticality,
      CreatedBy,
      CreatedAt,
      ChangedBy,
      ChangedAt,
      VersionStatusText,
      MetricStatusText,
      MetricTypeText,
      _OtherVersions : redirected to ZC_ReingMCVersion,
      _Metric,
      _Max,
      _Contracts,
      _VerStatus,
      _History : redirected to ZC_ReingMCVerHist
}
