@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'MC - Value Help Estado Version'
@ObjectModel.usageType.serviceQuality: #X
@ObjectModel.usageType.sizeCategory: #S
@ObjectModel.usageType.dataClass: #CUSTOMIZING

define view entity ZI_ReingMCVerStatus
  as select distinct from zreing_mcv_a
{
  key version_status as VersionStatus,

  case version_status
    when 'A' then 'Activa'
    when 'I' then 'Inactiva'
    when 'D' then 'Draft'
    else version_status
  end                as VersionStatusText
}
