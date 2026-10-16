@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Department'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_IntercoDepartmentRule_M
  as select from ZI_IntercoDepartmentRule
  association to parent ZC_IntercoDepartment_M as _Department on _Department.Department = $projection.Department
{
  key Department,
  key Item,
      CompanyCode,
      Product,
      PAndLId,
      PAndLLevel,
      ProfitCenter,
      /* Composition */
      _Department,
      /* Associations */
      _CompanyCOde,
      _PandL,
      _Product,
      _ProfitCenter
}
