@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Department'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_IntercoDepartment_M
  as select from ZI_IntercoDepartment
  composition [0..*] of ZC_IntercoDepartmentRule_M as _Rules
{
  key Department,
      Description,
      IsDeleted,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      LocalLastChangedAt,
      LastChangedBy,
      /* Associations */
      _Rules
}
