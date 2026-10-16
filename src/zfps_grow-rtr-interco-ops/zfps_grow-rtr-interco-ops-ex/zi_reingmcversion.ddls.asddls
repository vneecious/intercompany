@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'MC - Metric Version Root View Entity'
@ObjectModel.semanticKey: ['MetricCode', 'VersionNum']
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #M
@ObjectModel.usageType.dataClass: #MIXED

define root view entity ZI_ReingMCVersion
  as select from zreing_mcv_a         as V
    inner join   ZI_ReingMCVersionMax as MX on  MX.MetricCode =  V.metric_code
                                            and V.version_num <> '000'
  association [1]    to ZI_ReingMCMetricInfo as _Metric        on  _Metric.MetricCode = V.metric_code
  association [0..*] to ZI_ReingMCVersion    as _OtherVersions on  _OtherVersions.MetricCode =  V.metric_code
                                                                and _OtherVersions.VersionNum <> V.version_num
  association [1]    to ZI_ReingMCVersionMax as _Max           on  _Max.MetricCode = V.metric_code
  // Begin Mod 04.09.2026 EXT_AGFAGINA - la solapa muestra los contratos de la
  // METRICA, no los de la version. Antes la asociacion emparejaba tambien por
  // VersionNum, y como las asignaciones de contrato NO se migran al crear una
  // version nueva, el contrato quedaba vinculado a la version vieja y desaparecia
  // de la vista de la nueva. Caso real: M-0004 asignada a IC-0003 en la v002;
  // parado en la v003 la solapa salia vacia.
  association [0..*] to ZI_ReingMCContracts  as _Contracts     on  _Contracts.MetricCode = V.metric_code
  // End Mod 04.09.2026 EXT_AGFAGINA
  association [0..1] to ZI_ReingMCVerStatus  as _VerStatus     on  _VerStatus.VersionStatus = V.version_status
  association [0..*] to ZI_ReingMCVerHist    as _History       on  _History.MetricCode = V.metric_code
                                                                and _History.VersionNum = V.version_num
{
  key V.metric_code            as MetricCode,
  key V.version_num            as VersionNum,
      V.version_status         as VersionStatus,
      V.data_source_ver        as DataSourceVer,
      V.change_reason          as ChangeReason,
      V.valid_from             as ValidFrom,
      V.valid_to               as ValidTo,
      V.var_pct_limit          as VarPctLimit,
      V.metric_desc            as MetricDesc,
      V.metric_type            as MetricType,
      V.data_source            as DataSource,
      V.responsible            as Responsible,
      V.isnewversion           as IsNewVersion,
      _Metric.Status           as MetricStatus,
      _Metric.LastVersNum      as LastVersNum,
      case when V.version_num = MX.MaxVersionNum
           then 'X' else ''
      end                      as IsLatestVersion,
      case V.version_status
        when 'A' then 3
        when 'D' then 5
        when 'I' then 2
        else 0
      end                      as StatusCriticality,
      V.created_by             as CreatedBy,
      V.created_at             as CreatedAt,
      V.changed_by             as ChangedBy,
      V.changed_at             as ChangedAt,
      V.version_status_txt     as VersionStatusText,
      V.metric_status_txt      as MetricStatusText,
      V.metric_type_txt        as MetricTypeText,
      _Metric,
      _OtherVersions,
      _Max,
      _Contracts,
      _VerStatus,
      _History
}
