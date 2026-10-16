@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Intercompany: Departament Rule'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZI_IntercoDepartmentRule
  as select from zint_a_md_dpi
  association to ZI_IntercoDepartment   as _Department   on  _Department.Department = $projection.Department
  association to ZI_IntercoProduct      as _Product      on  _Product.Product = $projection.Product
  association to ZI_IntercoCompanyCode  as _CompanyCOde  on  _CompanyCOde.CompanyCode = $projection.CompanyCode
  association to ZI_IntercoPandL        as _PandL        on  _PandL.GLAccountHierarchy = 'H109/MLIB/ZPYL'
                                                         and _PandL.PandLId            = $projection.PAndLId
  association to ZI_IntercoProfitCenter as _ProfitCenter on  _ProfitCenter.ControllingArea = 'ML00'
                                                         and _ProfitCenter.ProfitCenter    = $projection.ProfitCenter
{
  key dpto          as Department,
  key item          as Item,
      company_code  as CompanyCode,
      product       as Product,
      p_and_l_id    as PAndLId,
      p_and_l_level as PAndLLevel,
      profit_center as ProfitCenter,

      _Department,
      _ProfitCenter,
      _CompanyCOde,
      _Product,
      _PandL
}
