@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Conceptos Facturables por Empresa Prestadora'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_IntercoCompanyRelProdBill
  provider contract transactional_query
  as projection on ZI_IntercoCompanyRelProdBill
{
  key Id,
      ValidFrom,
      ValidTo,
      @ObjectModel.text.element:  [ 'ProductName' ]
      Product,
      ProductName,
      @ObjectModel.text.element:  [ 'ProductTypeName' ]
      ProductType,
      ProductTypeName,
      @ObjectModel.text.element:  [ 'ProviderCompanyCodeName' ]
      ProviderCompanyCode,
      ProviderCompanyCodeName,
      @ObjectModel.text.element:  [ 'PandLName' ]
      PandLID,
      PandLName,
      @ObjectModel.text.element:  [ 'ProfitCenterName' ]
      ProfitCenter,
      ProfitCenterName,
      @ObjectModel.text.element:  [ 'CostCenterAreaName' ]
      CostCenterArea,
      CostCenterAreaName,
      @ObjectModel.text.element:  [ 'CostCenterSubAreaName' ]
      CostCenterSubArea,
      CostCenterSubAreaName,
      @ObjectModel.text.element:  [ 'CostCenterAllocationName' ]
      CostCenterAllocation,
      CostCenterAllocationName,
      IsNotBilable,
      IsDeleted,
      zindex,
      CreatedAt,
      CreatedBy,
      LastChangedAt,
      _log  : redirected to zc_intercorelprodbill_log
//      _atta : redirected to composition child ZC_INtERCORELPRODBILL_ATTA
}
