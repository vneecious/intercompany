@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Departament'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoDepartment
  as select from zint_a_md_dph
  association to ZI_IntercoDepartmentRule as _Rules on _Rules.Department = $projection.Department
{
  key depto                               as Department,
      description                         as Description,
      zint_a_md_dph.is_deleted            as IsDeleted,
      zint_a_md_dph.created_at            as CreatedAt,
      zint_a_md_dph.created_by            as CreatedBy,
      zint_a_md_dph.last_changed_at       as LastChangedAt,
      zint_a_md_dph.local_last_changed_at as LocalLastChangedAt,
      zint_a_md_dph.last_changed_by       as LastChangedBy,
      _Rules
}
